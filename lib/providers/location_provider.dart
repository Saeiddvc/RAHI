import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/models/location_fix.dart';

enum LocationAccessStatus {
  unknown,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  reducedAccuracy,
}

final locationAccessProvider = StateProvider<LocationAccessStatus>(
  (ref) => LocationAccessStatus.unknown,
);

final locationErrorProvider = StateProvider<String?>((ref) => null);

/// Metadata-rich fix used for routing quality decisions.
final locationFixProvider = StateProvider<LocationFix?>((ref) => null);

/// Current route-safe position.
///
/// Low-quality and last-known fixes remain available through
/// [locationFixProvider] for diagnostics, but are never exposed as the user's
/// live position or used as a routing origin.
final locationProvider =
    StateNotifierProvider<LocationNotifier, LatLng?>((ref) {
  return LocationNotifier(ref);
});

class LocationNotifier extends StateNotifier<LatLng?> {
  LocationNotifier(this._ref) : super(null) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<Position>? _positionSubscription;
  bool _wentToSettings = false;

  static const Duration routeFreshMaxAge = Duration(seconds: 30);
  static const double routeMaxAccuracyMeters = 50;
  static const double displayMaxAccuracyMeters = 100;
  static const Duration acquisitionTimeout = Duration(seconds: 15);
  static const double minimumGnssSatellitesUsed = 4;

  static LocationSettings get _currentLocationSettings {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true,
        timeLimit: const Duration(seconds: 10),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 10),
    );
  }

  static LocationSettings get _streamLocationSettings {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  LocationFix? get currentFix => _ref.read(locationFixProvider);

  bool isFixUsableForRoute([LocationFix? candidate]) {
    final fix = candidate ?? currentFix;
    if (fix == null) return false;

    final requireSatelliteEvidence =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (!fix.hasTrustedGnss(
      requireSatelliteEvidence: requireSatelliteEvidence,
      minSatellitesUsed: minimumGnssSatellitesUsed,
    )) {
      return false;
    }

    if (!fix.isFresh(maxAge: routeFreshMaxAge)) return false;
    if (!fix.isAccurate(maxMeters: routeMaxAccuracyMeters)) return false;
    return true;
  }

  Future<void> _init() async {
    await _checkAndRequestPermission();
  }

  Future<void> _checkAndRequestPermission({
    bool requestIfDenied = true,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setStatus(
          LocationAccessStatus.serviceDisabled,
          error: 'سرویس موقعیت مکانی خاموش است.',
        );
        await _positionSubscription?.cancel();
        _clearFix();
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && requestIfDenied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _setStatus(
          LocationAccessStatus.deniedForever,
          error: 'مجوز موقعیت مکانی برای برنامه مسدود شده است.',
        );
        await _positionSubscription?.cancel();
        _clearFix();
        return;
      }

      if (permission == LocationPermission.denied) {
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        await _positionSubscription?.cancel();
        _clearFix();
        return;
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        await _positionSubscription?.cancel();
        _clearFix();
        return;
      }

      final accuracyStatus = await Geolocator.getLocationAccuracy();
      if (accuracyStatus == LocationAccuracyStatus.reduced) {
        _setStatus(
          LocationAccessStatus.reducedAccuracy,
          error: 'برای مسیریابی دقیق، Precise location را فعال کنید.',
        );
        await _positionSubscription?.cancel();
        _clearFix();
        return;
      }

      _setStatus(LocationAccessStatus.granted);
      await _loadInitialPosition();
      _startLiveUpdates();
    } catch (_) {
      _setError('دریافت موقعیت مکانی با خطا مواجه شد.');
      _clearFix();
    }
  }

  Future<void> _loadInitialPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _currentLocationSettings,
      );

      _setFix(position, LocationSource.gps);
      if (isFixUsableForRoute()) {
        _setError(null);
      } else {
        _setError('موقعیت دریافت شد اما هنوز Fix ماهواره‌ای قابل‌اعتماد نیست.');
      }
      return;
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );

        if (lastKnown != null) {
          _setFix(lastKnown, LocationSource.lastKnown);
          _setError(
            'موقعیت فعلی هنوز در دسترس نیست؛ آخرین موقعیت ذخیره‌شده موجود است.',
          );
        } else {
          _clearFix();
          _setError('موقعیت فعلی هنوز در دسترس نیست.');
        }
      } catch (_) {
        _clearFix();
        _setError('موقعیت فعلی هنوز در دسترس نیست.');
      }
    }
  }

  void _startLiveUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _streamLocationSettings,
    ).listen(
      (position) {
        _setFix(position, LocationSource.gps);
        _setStatus(LocationAccessStatus.granted);
      },
      onError: (_) {
        _setError('جریان زنده موقعیت مکانی قطع شد.');
      },
    );
  }

  /// Waits for a fresh route-grade GNSS fix.
  ///
  /// On Android the LocationManager is forced and a fix is accepted only when
  /// the platform reports real GNSS satellite participation. This prevents a
  /// Wi-Fi/cell fused fix with a misleadingly small accuracy radius from being
  /// used as the route origin.
  Future<LocationFix?> acquireUsableRouteFix({
    Duration timeout = acquisitionTimeout,
  }) async {
    final existing = currentFix;
    if (isFixUsableForRoute(existing)) {
      return existing;
    }

    await _checkAndRequestPermission();
    if (_ref.read(locationAccessProvider) != LocationAccessStatus.granted) {
      return null;
    }

    final refreshed = currentFix;
    if (isFixUsableForRoute(refreshed)) {
      return refreshed;
    }

    final completer = Completer<LocationFix?>();
    StreamSubscription<Position>? subscription;
    Timer? timer;

    void finish(LocationFix? fix) {
      if (!completer.isCompleted) {
        completer.complete(fix);
      }
    }

    try {
      subscription = Geolocator.getPositionStream(
        locationSettings: _streamLocationSettings,
      ).listen(
        (position) {
          _setFix(position, LocationSource.gps);
          final fix = currentFix;
          if (isFixUsableForRoute(fix)) {
            _setError(null);
            finish(fix);
          }
        },
        onError: (_) => finish(null),
      );

      timer = Timer(timeout, () => finish(null));
      return await completer.future;
    } finally {
      timer?.cancel();
      await subscription?.cancel();
    }
  }

  void _setFix(Position position, LocationSource requestedSource) {
    final androidPosition =
        position is AndroidPosition ? position : null;

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final satellitesUsed = androidPosition?.satellitesUsedInFix;
    final hasGnssEvidence =
        !isAndroid ||
        (satellitesUsed != null &&
            satellitesUsed >= minimumGnssSatellitesUsed);

    final effectiveSource =
        requestedSource == LocationSource.lastKnown
            ? LocationSource.lastKnown
            : (hasGnssEvidence
                ? LocationSource.gps
                : LocationSource.unknown);

    final fix = LocationFix(
      location: LatLng(position.latitude, position.longitude),
      timestamp: position.timestamp.toUtc(),
      accuracyMeters: position.accuracy,
      source: effectiveSource,
      isMocked: position.isMocked,
      satelliteCount: androidPosition?.satelliteCount,
      satellitesUsedInFix: satellitesUsed,
    );

    _ref.read(locationFixProvider.notifier).state = fix;

    final displayable =
        isFixUsableForRoute(fix) ||
        (effectiveSource == LocationSource.gps &&
            !fix.isMocked &&
            fix.isFresh(maxAge: routeFreshMaxAge) &&
            fix.isAccurate(maxMeters: displayMaxAccuracyMeters));

    if (displayable) {
      state = fix.location;
    } else if (state == null ||
        requestedSource == LocationSource.lastKnown) {
      state = null;
    }
  }

  void _clearFix() {
    _ref.read(locationFixProvider.notifier).state = null;
    state = null;
  }

  void markWentToSettings() {
    _wentToSettings = true;
  }

  Future<void> onAppResumed() async {
    if (!_wentToSettings) return;

    _wentToSettings = false;
    await _checkAndRequestPermission(requestIfDenied: false);
  }

  Future<void> refresh() async {
    await _checkAndRequestPermission();
  }

  void _setStatus(
    LocationAccessStatus status, {
    String? error,
  }) {
    _ref.read(locationAccessProvider.notifier).state = status;
    _setError(error);
  }

  void _setError(String? message) {
    _ref.read(locationErrorProvider.notifier).state = message;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
