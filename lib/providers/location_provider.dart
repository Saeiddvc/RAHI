import 'dart:async';

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
}

final locationAccessProvider = StateProvider<LocationAccessStatus>(
  (ref) => LocationAccessStatus.unknown,
);

final locationErrorProvider = StateProvider<String?>((ref) => null);

/// Metadata-rich fix used for routing quality decisions.
///
/// This is intentionally separate from [locationProvider] so existing callers
/// can keep using the LatLng provider and its notifier API.
final locationFixProvider = StateProvider<LocationFix?>((ref) => null);

/// Backward-compatible current-position provider.
///
/// Only a GPS fix is exposed as the current position. A last-known fallback is
/// kept in [locationFixProvider] for an explicit user-confirmed routing choice,
/// but is not shown as the live/current position.
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
  static const double routeMaxAccuracyMeters = 150;

  static const LocationSettings _currentLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
    timeLimit: Duration(seconds: 8),
  );

  static const LocationSettings _streamLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 10,
  );

  LocationFix? get currentFix => _ref.read(locationFixProvider);

  bool isFixUsableForRoute([LocationFix? candidate]) {
    final fix = candidate ?? currentFix;
    if (fix == null) return false;
    if (!fix.isGps) return false;
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
        _positionSubscription?.cancel();
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
        _positionSubscription?.cancel();
        _clearFix();
        return;
      }

      if (permission == LocationPermission.denied) {
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        _positionSubscription?.cancel();
        _clearFix();
        return;
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        _positionSubscription?.cancel();
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
      _setError(null);
      return;
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();

        if (lastKnown != null) {
          _setFix(lastKnown, LocationSource.lastKnown);
          _setError('موقعیت فعلی هنوز در دسترس نیست؛ آخرین موقعیت ذخیره‌شده موجود است.');
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

  void _setFix(Position position, LocationSource source) {
    final fix = LocationFix(
      location: LatLng(position.latitude, position.longitude),
      timestamp: position.timestamp.toUtc(),
      accuracyMeters: position.accuracy,
      source: source,
    );

    _ref.read(locationFixProvider.notifier).state = fix;

    // Do not expose last-known data as the user's live/current location.
    state = source == LocationSource.gps ? fix.location : null;
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
