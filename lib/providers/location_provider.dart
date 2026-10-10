import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/services/gnss_bridge.dart';

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

class LocationMotion {
  final LatLng location;
  final double headingDegrees;
  final double speedMetersPerSecond;
  final DateTime timestamp;

  const LocationMotion({
    required this.location,
    required this.headingDegrees,
    required this.speedMetersPerSecond,
    required this.timestamp,
  });

  bool get hasUsableHeading =>
      headingDegrees.isFinite &&
      headingDegrees >= 0 &&
      headingDegrees < 360 &&
      speedMetersPerSecond.isFinite &&
      speedMetersPerSecond >= 1.5;
}

final locationMotionProvider = StateProvider<LocationMotion?>((ref) => null);

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

  DateTime? _lastAcceptedTimestamp;
  double? _lastAcceptedAccuracy;
  GnssSnapshot? _lastGnssSnapshot;
  Position? _bestFusedObserved;
  NativeGnssFix? _bestNativeObserved;
  bool _wentToSettings = false;

  static const Duration _maxFixAge = Duration(seconds: 25);
  static const Duration _acquisitionWindow = Duration(seconds: 20);
  static const double _maxFusedAccuracyMeters = 50;
  static const double _maxDegradedFusedAccuracyMeters = 180;
  static const double _maxNativeGnssAccuracyMeters = 120;
  static const int _minimumSatellitesUsed = 4;

  static LocationSettings get _fusedCurrentLocationSettings {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: false,
        timeLimit: const Duration(seconds: 12),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 12),
    );
  }

  static LocationSettings get _liveLocationSettings {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  bool get hasFreshUsableFix {
    if (state == null ||
        _lastAcceptedTimestamp == null ||
        _lastAcceptedAccuracy == null) {
      return false;
    }

    final age = DateTime.now().toUtc().difference(
          _lastAcceptedTimestamp!.toUtc(),
        );

    return age.abs() <= _maxFixAge;
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
        await _stopLiveUpdates();
        _clearAcceptedFix();
        _setStatus(
          LocationAccessStatus.serviceDisabled,
          error: 'سرویس موقعیت مکانی خاموش است.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && requestIfDenied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await _stopLiveUpdates();
        _clearAcceptedFix();
        _setStatus(
          LocationAccessStatus.deniedForever,
          error: 'مجوز موقعیت مکانی برای برنامه مسدود شده است.',
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        await _stopLiveUpdates();
        _clearAcceptedFix();
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        return;
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        await _stopLiveUpdates();
        _clearAcceptedFix();
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        return;
      }

      if (!kIsWeb) {
        final accuracyStatus = await Geolocator.getLocationAccuracy();
        if (accuracyStatus == LocationAccuracyStatus.reduced) {
          await _stopLiveUpdates();
          _clearAcceptedFix();
          _setStatus(
            LocationAccessStatus.reducedAccuracy,
            error:
                'برای مسیریابی دقیق، Precise location را برای راهی فعال کنید.',
          );
          return;
        }
      }

      _setStatus(LocationAccessStatus.granted);
      await _acquireBestFix();
      _startLiveUpdates();
    } catch (_) {
      if (!hasFreshUsableFix) {
        _clearAcceptedFix();
      }
      _setError('موقعیت فعلی هنوز در دسترس نیست.');
    }
  }

  Future<void> _acquireBestFix() async {
    _bestFusedObserved = null;
    _bestNativeObserved = null;
    _lastGnssSnapshot = null;

    final completer = Completer<void>();
    final timer = Timer(
      _acquisitionWindow + const Duration(seconds: 2),
      () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    void finishIfAccepted(bool accepted) {
      if (accepted && !completer.isCompleted) {
        completer.complete();
      }
    }

    unawaited(
      Geolocator.getCurrentPosition(
        locationSettings: _fusedCurrentLocationSettings,
      ).then((position) {
        _recordBestFused(position);
        finishIfAccepted(_acceptFusedPosition(position));
      }).catchError((Object _) {}),
    );

    unawaited(
      GnssBridge.acquireGpsFix(timeout: _acquisitionWindow).then((fix) {
        if (fix == null) return;

        _recordBestNative(fix);
        _lastGnssSnapshot = fix.snapshot;
        finishIfAccepted(_acceptNativeFix(fix));
      }),
    );

    await completer.future;
    timer.cancel();

    if (hasFreshUsableFix) {
      _setError(null);
      return;
    }

    // Do not deadlock routing when GNSS is temporarily unavailable (indoors,
    // urban canyon, cold start). If Android has a fresh fused fix with
    // moderate accuracy, accept it as a degraded startup origin and keep the
    // live stream running so a better GNSS/fused fix can replace it.
    final degradedFused = _bestFusedObserved;
    if (degradedFused != null &&
        _isBasicPositionValid(degradedFused) &&
        degradedFused.accuracy <= _maxDegradedFusedAccuracyMeters) {
      _acceptFix(
        location: LatLng(
          degradedFused.latitude,
          degradedFused.longitude,
        ),
        accuracyMeters: degradedFused.accuracy,
        timestamp: degradedFused.timestamp.toUtc(),
        headingDegrees: degradedFused.heading,
        speedMetersPerSecond: degradedFused.speed,
      );
      _setError(
        'موقعیت اولیه با دقت تقریبی '
        '${degradedFused.accuracy.round()} متر پذیرفته شد؛ '
        'راهی با دریافت Fix بهتر آن را اصلاح می‌کند.',
      );
      return;
    }

    _lastGnssSnapshot ??= await GnssBridge.snapshot();
    _clearAcceptedFix();
    _setError(_buildAcquisitionError());
  }

  void _startLiveUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _liveLocationSettings,
    ).listen(
      (position) {
        _recordBestFused(position);
        if (_acceptFusedPosition(position)) {
          return;
        }

        if (!hasFreshUsableFix) {
          state = null;
        }
      },
      onError: (_) {
        if (!hasFreshUsableFix) {
          state = null;
        }
        _setError('جریان زنده موقعیت مکانی قطع شد.');
      },
    );
  }

  Future<void> _stopLiveUpdates() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _recordBestFused(Position position) {
    if (!_isBasicPositionValid(position)) return;

    final current = _bestFusedObserved;
    if (current == null || position.accuracy < current.accuracy) {
      _bestFusedObserved = position;
    }
  }

  void _recordBestNative(NativeGnssFix fix) {
    if (!_isBasicNativeValid(fix)) return;

    final current = _bestNativeObserved;
    if (current == null || fix.accuracyMeters < current.accuracyMeters) {
      _bestNativeObserved = fix;
    }
  }

  bool _acceptFusedPosition(Position position) {
    if (!_isBasicPositionValid(position)) {
      return false;
    }

    final isRouteGrade =
        position.accuracy <= _maxFusedAccuracyMeters;

    final currentAccuracy = _lastAcceptedAccuracy;
    final improvesDegradedFix =
        currentAccuracy != null &&
        currentAccuracy > _maxFusedAccuracyMeters &&
        position.accuracy < currentAccuracy &&
        position.accuracy <= _maxDegradedFusedAccuracyMeters;

    if (!isRouteGrade && !improvesDegradedFix) {
      return false;
    }

    final accepted = _acceptFix(
      location: LatLng(position.latitude, position.longitude),
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp.toUtc(),
      headingDegrees: position.heading,
      speedMetersPerSecond: position.speed,
    );

    if (isRouteGrade) {
      _setError(null);
    }

    return accepted;
  }

  bool _acceptNativeFix(NativeGnssFix fix) {
    if (!_isBasicNativeValid(fix)) return false;

    final enoughSatellites =
        fix.snapshot.satellitesUsedInFix >= _minimumSatellitesUsed;
    final accurateEnough =
        fix.accuracyMeters <= _maxNativeGnssAccuracyMeters;

    if (!enoughSatellites || !accurateEnough) {
      return false;
    }

    return _acceptFix(
      location: fix.location,
      accuracyMeters: fix.accuracyMeters,
      timestamp: fix.timestamp,
      headingDegrees: fix.headingDegrees,
      speedMetersPerSecond: fix.speedMetersPerSecond,
    );
  }

  bool _acceptFix({
    required LatLng location,
    required double accuracyMeters,
    required DateTime timestamp,
    required double headingDegrees,
    required double speedMetersPerSecond,
  }) {
    _lastAcceptedTimestamp = timestamp.toUtc();
    _lastAcceptedAccuracy = accuracyMeters;
    state = location;

    _ref.read(locationMotionProvider.notifier).state = LocationMotion(
      location: location,
      headingDegrees: headingDegrees,
      speedMetersPerSecond: speedMetersPerSecond,
      timestamp: timestamp.toUtc(),
    );

    _setStatus(LocationAccessStatus.granted);
    return true;
  }

  bool _isBasicPositionValid(Position position) {
    if (position.isMocked) return false;

    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      return false;
    }

    if (!position.accuracy.isFinite || position.accuracy <= 0) {
      return false;
    }

    return _isFresh(position.timestamp);
  }

  bool _isBasicNativeValid(NativeGnssFix fix) {
    if (fix.mocked ||
        !fix.location.latitude.isFinite ||
        !fix.location.longitude.isFinite ||
        !fix.accuracyMeters.isFinite ||
        fix.accuracyMeters <= 0) {
      return false;
    }

    return _isFresh(fix.timestamp);
  }

  bool _isFresh(DateTime timestamp) {
    final age = DateTime.now().toUtc().difference(timestamp.toUtc());
    return age.abs() <= _maxFixAge;
  }

  String _buildAcquisitionError() {
    final fused = _bestFusedObserved;
    final native = _bestNativeObserved;
    final snapshot = _lastGnssSnapshot;

    final parts = <String>[];

    if (fused != null) {
      parts.add('ترکیبی: ${fused.accuracy.round()}م');
    }

    if (native != null) {
      parts.add('GNSS: ${native.accuracyMeters.round()}م');
    }

    if (snapshot != null) {
      parts.add(
        'ماهواره: ${snapshot.satellitesUsedInFix}/'
        '${snapshot.totalSatellites}',
      );

      if (snapshot.constellations.isNotEmpty) {
        parts.add(snapshot.constellationSummary);
      }
    }

    if (parts.isEmpty) {
      return 'موقعیت دقیق فعلی هنوز در دسترس نیست.';
    }

    return 'Fix قابل اعتماد برای مسیریابی به دست نیامد '
        '(${parts.join(' | ')}). چند لحظه در فضای باز بمانید و دوباره تلاش کنید.';
  }

  Future<LatLng?> acquireFreshLocation() async {
    if (hasFreshUsableFix) {
      return state;
    }

    await _checkAndRequestPermission();

    if (!hasFreshUsableFix) {
      return null;
    }

    return state;
  }

  void markWentToSettings() {
    _wentToSettings = true;
  }

  Future<void> onAppResumed() async {
    if (_wentToSettings) {
      _wentToSettings = false;
    }

    await _checkAndRequestPermission(requestIfDenied: false);
  }

  Future<void> refresh() async {
    await _checkAndRequestPermission();
  }

  void _clearAcceptedFix() {
    _lastAcceptedTimestamp = null;
    _lastAcceptedAccuracy = null;
    _ref.read(locationMotionProvider.notifier).state = null;
    state = null;
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
