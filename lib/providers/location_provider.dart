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
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
    timeLimit: Duration(seconds: 8),
  );

  static const LocationSettings _streamLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 10,
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
        _setStatus(
          LocationAccessStatus.serviceDisabled,
          error: 'سرویس موقعیت مکانی خاموش است.',
        );
        _positionSubscription?.cancel();
        state = null;
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
        state = null;
        return;
      }

      if (permission == LocationPermission.denied) {
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        _positionSubscription?.cancel();
        state = null;
        return;
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _setStatus(
          LocationAccessStatus.denied,
          error: 'مجوز موقعیت مکانی داده نشد.',
        );
        _positionSubscription?.cancel();
        state = null;
        return;
      }

      _setStatus(LocationAccessStatus.granted);
      await _loadInitialPosition();
      _startLiveUpdates();
    } catch (_) {
      _setError('دریافت موقعیت مکانی با خطا مواجه شد.');
      state = null;
    }
  }

  Future<void> _loadInitialPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _currentLocationSettings,
      );

      state = LatLng(position.latitude, position.longitude);
      _setError(null);
      return;
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();

        if (lastKnown != null) {
          state = LatLng(lastKnown.latitude, lastKnown.longitude);
          _setError(null);
        } else {
          state = null;
          _setError('موقعیت فعلی هنوز در دسترس نیست.');
        }
      } catch (_) {
        state = null;
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
