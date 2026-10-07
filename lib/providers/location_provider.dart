import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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

  static const LocationSettings _currentLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
    timeLimit: Duration(seconds: 15),
  );

  static const LocationSettings _streamLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 5,
  );

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
        state = null;
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        return;
      }

      _setStatus(LocationAccessStatus.granted);
      await _loadFreshPosition();
      _startLiveUpdates();
    } catch (_) {
      state = null;
      _setError('موقعیت فعلی هنوز در دسترس نیست.');
    }
  }

  Future<void> _loadFreshPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _currentLocationSettings,
      );

      state = LatLng(position.latitude, position.longitude);
      _setStatus(LocationAccessStatus.granted);
    } catch (_) {
      // Deliberately do not fall back to getLastKnownPosition().
      // A stale fix must never become the origin of a new route.
      state = null;
      _setError('موقعیت فعلی هنوز در دسترس نیست.');
    }
  }

  void _startLiveUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _streamLocationSettings,
    ).listen(
      (position) {
        state = LatLng(position.latitude, position.longitude);
        _setStatus(LocationAccessStatus.granted);
      },
      onError: (_) {
        _setError('جریان زنده موقعیت مکانی قطع شد.');
      },
    );
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
