import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../core/services/gnss_bridge.dart';

void runLocationDeviceGate() {
  runApp(const LocationDeviceGateApp());
}

class LocationDeviceGateApp extends StatelessWidget {
  const LocationDeviceGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RAHI Location Device Gate',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazirmatn',
      ),
      home: const LocationDeviceGateScreen(),
    );
  }
}

class LocationDeviceGateScreen extends StatefulWidget {
  const LocationDeviceGateScreen({super.key});

  @override
  State<LocationDeviceGateScreen> createState() =>
      _LocationDeviceGateScreenState();
}

class _LocationDeviceGateScreenState
    extends State<LocationDeviceGateScreen> {
  static const _gateDuration = Duration(seconds: 20);
  static const _maxFreshAge = Duration(seconds: 25);

  bool _busy = false;
  bool _serviceEnabled = false;
  bool _precise = false;
  String _status = 'آماده';
  String _permission = '-';
  String _accuracyMode = '-';
  String? _fusedError;
  String? _nativeError;

  Position? _fused;
  NativeGnssFix? _native;
  GnssSnapshot? _snapshotBefore;
  GnssSnapshot? _snapshotAfter;

  final List<Position> _liveSamples = <Position>[];
  StreamSubscription<Position>? _liveSubscription;

  Future<void> _runGate() async {
    if (_busy) return;

    await _liveSubscription?.cancel();
    _liveSamples.clear();

    setState(() {
      _busy = true;
      _status = 'در حال آماده‌سازی Device Gate...';
      _serviceEnabled = false;
      _precise = false;
      _permission = '-';
      _accuracyMode = '-';
      _fused = null;
      _native = null;
      _snapshotBefore = null;
      _snapshotAfter = null;
      _fusedError = null;
      _nativeError = null;
    });

    try {
      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_serviceEnabled) {
        _status = 'Location Service خاموش است.';
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      _permission = permission.name;

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _status = 'مجوز Location کافی نیست.';
        return;
      }

      final accuracy = await Geolocator.getLocationAccuracy();
      _accuracyMode = accuracy.name;
      _precise = accuracy == LocationAccuracyStatus.precise;

      if (!_precise) {
        _status = 'Precise location فعال نیست.';
        return;
      }

      _snapshotBefore = await GnssBridge.snapshot();

      _liveSubscription = Geolocator.getPositionStream(
        locationSettings: const AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: Duration(seconds: 1),
        ),
      ).listen(
        (position) {
          _liveSamples.add(position);
          if (mounted) {
            setState(() {
              _status =
                  'در حال نمونه‌برداری... ${_liveSamples.length} sample';
            });
          }
        },
        onError: (Object error) {
          if (mounted) {
            setState(() {
              _status = 'Live stream error: $error';
            });
          }
        },
      );

      final fusedFuture = Geolocator.getCurrentPosition(
        locationSettings: const AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: false,
          timeLimit: Duration(seconds: 15),
        ),
      ).then((position) {
        _fused = position;
      }).catchError((Object error) {
        _fusedError = error.toString();
      });

      final nativeFuture = GnssBridge.acquireGpsFix(
        timeout: _gateDuration,
      ).then((fix) {
        _native = fix;
        if (fix == null) {
          _nativeError = 'Native GNSS returned no fix.';
        }
      }).catchError((Object error) {
        _nativeError = error.toString();
      });

      await Future.wait<void>([
        Future<void>.delayed(_gateDuration),
        fusedFuture,
        nativeFuture,
      ]);

      await _liveSubscription?.cancel();
      _liveSubscription = null;
      _snapshotAfter = await GnssBridge.snapshot();
      _status = overallPass ? 'DEVICE GATE PASS' : 'DEVICE GATE FAIL';
    } catch (error) {
      _status = 'Gate error: $error';
    } finally {
      await _liveSubscription?.cancel();
      _liveSubscription = null;
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  bool _isFresh(DateTime timestamp) {
    final age = DateTime.now().toUtc().difference(timestamp.toUtc()).abs();
    return age <= _maxFreshAge;
  }

  bool get accessPass =>
      _serviceEnabled &&
      (_permission == LocationPermission.whileInUse.name ||
          _permission == LocationPermission.always.name) &&
      _precise;

  bool get fusedPass {
    final fix = _fused;
    return fix != null &&
        !fix.isMocked &&
        fix.accuracy.isFinite &&
        fix.accuracy > 0 &&
        fix.accuracy <= 50 &&
        _isFresh(fix.timestamp);
  }

  bool get nativePass {
    final fix = _native;
    return fix != null &&
        !fix.mocked &&
        fix.accuracyMeters.isFinite &&
        fix.accuracyMeters > 0 &&
        fix.accuracyMeters <= 120 &&
        fix.snapshot.satellitesUsedInFix >= 4 &&
        _isFresh(fix.timestamp);
  }

  bool get livePass {
    if (_liveSamples.length < 5) return false;
    final valid = _liveSamples.where(
      (sample) =>
          !sample.isMocked &&
          sample.accuracy.isFinite &&
          sample.accuracy > 0 &&
          sample.accuracy <= 50 &&
          _isFresh(sample.timestamp),
    );
    return valid.isNotEmpty;
  }

  bool get overallPass => accessPass && fusedPass && nativePass && livePass;

  double? get _distanceBetweenInitialFixes {
    final fused = _fused;
    final native = _native;
    if (fused == null || native == null) return null;

    return Geolocator.distanceBetween(
      fused.latitude,
      fused.longitude,
      native.location.latitude,
      native.location.longitude,
    );
  }

  double? get _bestLiveAccuracy {
    if (_liveSamples.isEmpty) return null;
    return _liveSamples
        .map((sample) => sample.accuracy)
        .where((accuracy) => accuracy.isFinite && accuracy > 0)
        .fold<double?>(
          null,
          (best, value) => best == null || value < best ? value : best,
        );
  }

  String _age(DateTime timestamp) {
    final ms = DateTime.now()
        .toUtc()
        .difference(timestamp.toUtc())
        .abs()
        .inMilliseconds;
    return '${(ms / 1000).toStringAsFixed(1)} s';
  }

  String _pass(bool value) => value ? 'PASS' : 'FAIL';

  String _snapshotText(GnssSnapshot? snapshot) {
    if (snapshot == null) return 'No GNSS snapshot';

    return [
      'satellites used/visible: '
          '${snapshot.satellitesUsedInFix}/${snapshot.totalSatellites}',
      'avg C/N0: ${snapshot.averageCn0DbHz.toStringAsFixed(1)} dB-Hz',
      'constellations: ${snapshot.constellationSummary}',
      'GPS provider: ${snapshot.gpsProviderEnabled}',
      'Network provider: ${snapshot.networkProviderEnabled}',
    ].join('\n');
  }

  String _reportText() {
    final fused = _fused;
    final native = _native;
    final distance = _distanceBetweenInitialFixes;
    final bestLive = _bestLiveAccuracy;

    return [
      'RAHI Location Device Gate',
      'Overall: ${_pass(overallPass)}',
      'Access: ${_pass(accessPass)}',
      'Fused: ${_pass(fusedPass)}',
      'Native GNSS: ${_pass(nativePass)}',
      'Live stream: ${_pass(livePass)}',
      '',
      'serviceEnabled: $_serviceEnabled',
      'permission: $_permission',
      'accuracyMode: $_accuracyMode',
      '',
      if (fused != null) ...[
        'FUSED',
        'lat/lng: ${fused.latitude.toStringAsFixed(7)}, '
            '${fused.longitude.toStringAsFixed(7)}',
        'accuracy: ${fused.accuracy.toStringAsFixed(1)} m',
        'age: ${_age(fused.timestamp)}',
        'speed: ${fused.speed.toStringAsFixed(1)} m/s',
        'heading: ${fused.heading.toStringAsFixed(1)} deg',
        'mocked: ${fused.isMocked}',
      ] else
        'FUSED: no fix (${_fusedError ?? "unknown"})',
      '',
      if (native != null) ...[
        'NATIVE GNSS',
        'lat/lng: ${native.location.latitude.toStringAsFixed(7)}, '
            '${native.location.longitude.toStringAsFixed(7)}',
        'accuracy: ${native.accuracyMeters.toStringAsFixed(1)} m',
        'age: ${_age(native.timestamp)}',
        'speed: ${native.speedMetersPerSecond.toStringAsFixed(1)} m/s',
        'heading: ${native.headingDegrees.toStringAsFixed(1)} deg',
        'mocked: ${native.mocked}',
        _snapshotText(native.snapshot),
      ] else
        'NATIVE GNSS: no fix (${_nativeError ?? "unknown"})',
      '',
      'LIVE',
      'samples: ${_liveSamples.length}',
      'best accuracy: '
          '${bestLive == null ? "-" : "${bestLive.toStringAsFixed(1)} m"}',
      'fused/native distance: '
          '${distance == null ? "-" : "${distance.toStringAsFixed(1)} m"}',
      '',
      'GNSS SNAPSHOT AFTER',
      _snapshotText(_snapshotAfter ?? _snapshotBefore),
    ].join('\n');
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(ClipboardData(text: _reportText()));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('گزارش Device Gate کپی شد.')),
    );
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fused = _fused;
    final native = _native;
    final distance = _distanceBetweenInitialFixes;
    final bestLive = _bestLiveAccuracy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RAHI — Location Device Gate'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _runGate,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(
                _busy ? 'در حال تست ۲۰ ثانیه‌ای...' : 'اجرای Device Gate',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _copyReport,
              icon: const Icon(Icons.copy),
              label: const Text('کپی گزارش کامل'),
            ),
            const SizedBox(height: 16),
            _GateCard(
              title: 'نتیجه',
              lines: [
                'Status: $_status',
                'Overall: ${_pass(overallPass)}',
                'Access + Precise: ${_pass(accessPass)}',
                'Fused <= 50m: ${_pass(fusedPass)}',
                'Native GNSS <= 120m + >=4 sats: ${_pass(nativePass)}',
                'Live stream: ${_pass(livePass)}',
              ],
            ),
            const SizedBox(height: 12),
            _GateCard(
              title: 'سیستم',
              lines: [
                'Location service: $_serviceEnabled',
                'Permission: $_permission',
                'Accuracy mode: $_accuracyMode',
              ],
            ),
            const SizedBox(height: 12),
            _GateCard(
              title: 'Fused',
              lines: fused == null
                  ? ['No fix', if (_fusedError != null) _fusedError!]
                  : [
                      'lat: ${fused.latitude.toStringAsFixed(7)}',
                      'lng: ${fused.longitude.toStringAsFixed(7)}',
                      'accuracy: ${fused.accuracy.toStringAsFixed(1)} m',
                      'age: ${_age(fused.timestamp)}',
                      'speed: ${fused.speed.toStringAsFixed(1)} m/s',
                      'heading: ${fused.heading.toStringAsFixed(1)} deg',
                      'mocked: ${fused.isMocked}',
                    ],
            ),
            const SizedBox(height: 12),
            _GateCard(
              title: 'Native GNSS',
              lines: native == null
                  ? ['No fix', if (_nativeError != null) _nativeError!]
                  : [
                      'lat: ${native.location.latitude.toStringAsFixed(7)}',
                      'lng: ${native.location.longitude.toStringAsFixed(7)}',
                      'accuracy: '
                          '${native.accuracyMeters.toStringAsFixed(1)} m',
                      'age: ${_age(native.timestamp)}',
                      'speed: '
                          '${native.speedMetersPerSecond.toStringAsFixed(1)} m/s',
                      'heading: '
                          '${native.headingDegrees.toStringAsFixed(1)} deg',
                      'mocked: ${native.mocked}',
                      'satellites used/visible: '
                          '${native.snapshot.satellitesUsedInFix}/'
                          '${native.snapshot.totalSatellites}',
                      'avg C/N0: '
                          '${native.snapshot.averageCn0DbHz.toStringAsFixed(1)}',
                      'constellations: '
                          '${native.snapshot.constellationSummary}',
                    ],
            ),
            const SizedBox(height: 12),
            _GateCard(
              title: 'Live stream',
              lines: [
                'samples: ${_liveSamples.length}',
                'best accuracy: '
                    '${bestLive == null ? "-" : "${bestLive.toStringAsFixed(1)} m"}',
                'fused/native distance: '
                    '${distance == null ? "-" : "${distance.toStringAsFixed(1)} m"}',
              ],
            ),
            const SizedBox(height: 12),
            _GateCard(
              title: 'GNSS snapshot',
              lines: _snapshotText(_snapshotAfter ?? _snapshotBefore)
                  .split('\n'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GateCard extends StatelessWidget {
  const _GateCard({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          [title, ...lines].join('\n'),
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
