import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('سرویس موقعیت مکانی خاموش است.');
        state = null;
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setError('مجوز موقعیت مکانی داده نشد.');
        state = null;
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setError('مجوز موقعیت مکانی برای برنامه مسدود شده است.');
        state = null;
        return;
      }

      _setError(null);
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
      return;
    } catch (_) {
      final lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null) {
        state = LatLng(lastKnown.latitude, lastKnown.longitude);
        _setError(null);
      } else {
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
        _setError(null);
      },
      onError: (_) {
        _setError('جریان زنده موقعیت مکانی قطع شد.');
      },
    );
  }

  Future<void> refresh() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('سرویس موقعیت مکانی خاموش است.');
        state = null;
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _currentLocationSettings,
      );

      state = LatLng(position.latitude, position.longitude);
      _setError(null);
    } catch (_) {
      _setError('به‌روزرسانی موقعیت مکانی انجام نشد.');
    }
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
