import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
  Position? _lastAcceptedPosition;
  Position? _bestObservedPosition;
  bool _wentToSettings = false;

  static const Duration _maxFixAge = Duration(seconds: 20);
  static const Duration _acquisitionWindow = Duration(seconds: 20);

  // A fused/network fix is accepted only when it is already very accurate.
  // A wider radius is allowed only when Android reports real GNSS satellite
  // participation in the fix.
  static const double _maxFusedAccuracyMeters = 60;
  static const double _maxSatelliteBackedAccuracyMeters = 120;
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

  static LocationSettings get _gpsAcquisitionSettings {
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
    final position = _lastAcceptedPosition;
    return position != null && _isRouteUsable(position);
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
    _bestObservedPosition = null;

    final completer = Completer<void>();
    StreamSubscription<Position>? gpsSubscription;
    Timer? timer;

    void finish() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    void consider(Position position) {
      _recordBestObserved(position);
      if (_acceptPosition(position)) {
        finish();
      }
    }

    try {
      // Start a real LocationManager/GNSS stream first. It is allowed to warm
      // up for several seconds so the first coarse fix does not prematurely
      // end acquisition.
      gpsSubscription = Geolocator.getPositionStream(
        locationSettings: _gpsAcquisitionSettings,
      ).listen(
        consider,
        onError: (_) {},
      );

      // In parallel, request Android's fused position. Fused location combines
      // GNSS with Wi-Fi/cell/sensor signals and can be excellent when already
      // well calibrated.
      unawaited(
        Geolocator.getCurrentPosition(
          locationSettings: _fusedCurrentLocationSettings,
        ).then(consider).catchError((Object _) {}),
      );

      timer = Timer(_acquisitionWindow, finish);
      await completer.future;
    } finally {
      timer?.cancel();
      await gpsSubscription?.cancel();
    }

    if (hasFreshUsableFix) {
      _setError(null);
      return;
    }

    _clearAcceptedFix();

    final best = _bestObservedPosition;
    if (best == null) {
      _setError('موقعیت دقیق فعلی هنوز در دسترس نیست.');
      return;
    }

    final satellites = _satellitesUsed(best);
    final satelliteText =
        satellites == null ? 'نامشخص' : satellites.toString();

    _setError(
      'دقت موقعیت فعلی کافی نیست '
      '(${best.accuracy.round()} متر، ماهواره‌های استفاده‌شده: '
      '$satelliteText). چند لحظه در فضای باز بمانید و دوباره تلاش کنید.',
    );
  }

  void _startLiveUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _liveLocationSettings,
    ).listen(
      (position) {
        _recordBestObserved(position);
        if (_acceptPosition(position)) {
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

  void _recordBestObserved(Position position) {
    if (!_isBasicValid(position)) return;

    final current = _bestObservedPosition;
    if (current == null || _candidateScore(position) < _candidateScore(current)) {
      _bestObservedPosition = position;
    }
  }

  double _candidateScore(Position position) {
    var score = position.accuracy;

    final satellites = _satellitesUsed(position);
    if (satellites != null && satellites > 0) {
      score -= satellites.clamp(0, 12) * 2.0;
    }

    final ageSeconds = DateTime.now()
        .toUtc()
        .difference(position.timestamp.toUtc())
        .inMilliseconds
        .abs() /
        1000.0;
    score += ageSeconds * 0.5;

    return score;
  }

  bool _acceptPosition(Position position) {
    if (!_isRouteUsable(position)) {
      return false;
    }

    _lastAcceptedPosition = position;
    final location = LatLng(position.latitude, position.longitude);
    state = location;
    _ref.read(locationMotionProvider.notifier).state = LocationMotion(
      location: location,
      headingDegrees: position.heading,
      speedMetersPerSecond: position.speed,
      timestamp: position.timestamp.toUtc(),
    );
    _setStatus(LocationAccessStatus.granted);
    return true;
  }

  bool _isRouteUsable(Position position) {
    if (!_isBasicValid(position)) return false;

    if (position.accuracy <= _maxFusedAccuracyMeters) {
      return true;
    }

    final satellites = _satellitesUsed(position);
    return satellites != null &&
        satellites >= _minimumSatellitesUsed &&
        position.accuracy <= _maxSatelliteBackedAccuracyMeters;
  }

  bool _isBasicValid(Position position) {
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

    final age = DateTime.now().toUtc().difference(
          position.timestamp.toUtc(),
        );

    if (age.isNegative) {
      return age.abs() <= _maxFixAge;
    }

    return age <= _maxFixAge;
  }

  int? _satellitesUsed(Position position) {
    if (position is AndroidPosition) {
      final satellites = position.satellitesUsedInFix;
      if (!satellites.isFinite || satellites < 0) {
        return null;
      }
      return satellites.round();
    }
    return null;
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
    _lastAcceptedPosition = null;
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
