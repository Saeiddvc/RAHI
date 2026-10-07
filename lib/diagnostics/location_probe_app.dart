import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationProbeApp extends StatelessWidget {
  const LocationProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RAHI Location Probe',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazirmatn',
      ),
      home: const LocationProbeScreen(),
    );
  }
}

class LocationProbeScreen extends StatefulWidget {
  const LocationProbeScreen({super.key});

  @override
  State<LocationProbeScreen> createState() => _LocationProbeScreenState();
}

class _LocationProbeScreenState extends State<LocationProbeScreen> {
  bool _busy = false;
  String _status = 'آماده';
  String _permission = '-';
  String _accuracyMode = '-';
  Position? _fused;
  Position? _gnss;

  Future<void> _runProbe() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _status = 'در حال بررسی مجوز و GPS...';
      _fused = null;
      _gnss = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _status = 'Location Service خاموش است.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      setState(() => _permission = permission.name);

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _status = 'مجوز Location کافی نیست.');
        return;
      }

      final accuracyStatus = await Geolocator.getLocationAccuracy();
      setState(() => _accuracyMode = accuracyStatus.name);

      setState(() => _status = 'مرحله 1/2: Fused high accuracy...');
      final fused = await Geolocator.getCurrentPosition(
        locationSettings: const AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: false,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _fused = fused;
        _status = 'مرحله 2/2: Android LocationManager / GNSS...';
      });

      final gnss = await Geolocator.getCurrentPosition(
        locationSettings: const AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: true,
          timeLimit: Duration(seconds: 20),
        ),
      );

      setState(() {
        _gnss = gnss;
        _status = 'تست کامل شد.';
      });
    } catch (error) {
      setState(() => _status = 'خطا: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = _distanceBetween(_fused, _gnss);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RAHI — Raw Location Probe'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _runProbe,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed),
              label: const Text('اجرای تست خام Location'),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'وضعیت سیستم',
              lines: [
                'Status: $_status',
                'Permission: $_permission',
                'Accuracy mode: $_accuracyMode',
              ],
            ),
            const SizedBox(height: 12),
            _PositionCard(
              title: 'FusedLocationProvider',
              position: _fused,
            ),
            const SizedBox(height: 12),
            _PositionCard(
              title: 'Android LocationManager / GNSS',
              position: _gnss,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'مقایسه',
              lines: [
                if (distance == null)
                  'Distance between fixes: -'
                else
                  'Distance between fixes: ${distance.toStringAsFixed(1)} m',
                'مختصات هر دو بخش را با موقعیت واقعی در Google Maps مقایسه کن.',
              ],
            ),
          ],
        ),
      ),
    );
  }

  double? _distanceBetween(Position? a, Position? b) {
    if (a == null || b == null) return null;

    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.title,
    required this.position,
  });

  final String title;
  final Position? position;

  @override
  Widget build(BuildContext context) {
    final p = position;
    if (p == null) {
      return _InfoCard(
        title: title,
        lines: const ['No fix yet'],
      );
    }

    final android = p is AndroidPosition ? p : null;

    return _InfoCard(
      title: title,
      lines: [
        'lat: ${p.latitude.toStringAsFixed(7)}',
        'lng: ${p.longitude.toStringAsFixed(7)}',
        'accuracy: ${p.accuracy.toStringAsFixed(1)} m',
        'altitude: ${p.altitude.toStringAsFixed(1)} m',
        'speed: ${p.speed.toStringAsFixed(1)} m/s',
        'heading: ${p.heading.toStringAsFixed(1)}°',
        'timestamp: ${p.timestamp.toIso8601String()}',
        'isMocked: ${p.isMocked}',
        if (android != null)
          'satellites used/visible: '
              '${_formatSatellite(android.satellitesUsedInFix)}/'
              '${_formatSatellite(android.satelliteCount)}',
      ],
    );
  }

  String _formatSatellite(double? value) {
    if (value == null) return '-';
    return value.round().toString();
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
          [
            title,
            ...lines,
          ].join('\n'),
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
