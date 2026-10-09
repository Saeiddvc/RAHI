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
  bool _wentToSettings = false;

  static const Duration _maxFixAge = Duration(seconds: 20);
  static const double _maxAcceptedAccuracyMeters = 80;

  static LocationSettings get _primaryCurrentLocationSettings {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true,
        timeLimit: const Duration(seconds: 18),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 18),
    );
  }

  static const LocationSettings _fallbackCurrentLocationSettings =
      LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
    timeLimit: Duration(seconds: 12),
  );

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

  bool get hasFreshUsableFix {
    final position = _lastAcceptedPosition;
    return position != null && _isUsable(position);
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
        await _positionSubscription?.cancel();
        _positionSubscription = null;
        _lastAcceptedPosition = null;
        _ref.read(locationMotionProvider.notifier).state = null;
        state = null;
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
        await _positionSubscription?.cancel();
        _positionSubscription = null;
        _lastAcceptedPosition = null;
        _ref.read(locationMotionProvider.notifier).state = null;
        state = null;
        _setStatus(
          LocationAccessStatus.deniedForever,
          error: 'مجوز موقعیت مکانی برای برنامه مسدود شده است.',
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        await _positionSubscription?.cancel();
        _positionSubscription = null;
        _lastAcceptedPosition = null;
        _ref.read(locationMotionProvider.notifier).state = null;
        state = null;
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        return;
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        await _positionSubscription?.cancel();
        _positionSubscription = null;
        _lastAcceptedPosition = null;
        _ref.read(locationMotionProvider.notifier).state = null;
        state = null;
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        return;
      }

      if (!kIsWeb) {
        final accuracyStatus = await Geolocator.getLocationAccuracy();
        if (accuracyStatus == LocationAccuracyStatus.reduced) {
          await _positionSubscription?.cancel();
          _positionSubscription = null;
          _lastAcceptedPosition = null;
          state = null;
          _setStatus(
            LocationAccessStatus.reducedAccuracy,
            error: 'برای مسیریابی دقیق، Precise location را برای راهی فعال کنید.',
          );
          return;
        }
      }

      _setStatus(LocationAccessStatus.granted);
      await _loadFreshPosition();
      _startLiveUpdates();
    } catch (_) {
      if (!hasFreshUsableFix) {
        state = null;
      }
      _setError('موقعیت فعلی هنوز در دسترس نیست.');
    }
  }

  Future<void> _loadFreshPosition() async {
    Position? position;

    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: _primaryCurrentLocationSettings,
      );
    } catch (_) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: _fallbackCurrentLocationSettings,
        );
      } catch (_) {
        position = null;
      }
    }

    if (position != null && _acceptPosition(position)) {
      return;
    }

    if (!hasFreshUsableFix) {
      state = null;
    }

    if (position != null && position.accuracy.isFinite) {
      _setError(
        'دقت موقعیت فعلی کافی نیست (${position.accuracy.round()} متر). '
        'چند لحظه در فضای باز بمانید و دوباره تلاش کنید.',
      );
    } else {
      _setError('موقعیت دقیق فعلی هنوز در دسترس نیست.');
    }
  }

  void _startLiveUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _streamLocationSettings,
    ).listen(
      (position) {
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

  bool _acceptPosition(Position position) {
    if (!_isUsable(position)) {
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

  bool _isUsable(Position position) {
    if (position.isMocked) return false;

    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      return false;
    }

    if (!position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > _maxAcceptedAccuracyMeters) {
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
