import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../core/services/gnss_bridge.dart';

class NativeMotionProbeApp extends StatelessWidget {
  const NativeMotionProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NativeMotionProbeScreen(),
    );
  }
}

class NativeMotionProbeScreen extends StatefulWidget {
  const NativeMotionProbeScreen({super.key});

  @override
  State<NativeMotionProbeScreen> createState() =>
      _NativeMotionProbeScreenState();
}

class _NativeMotionProbeScreenState
    extends State<NativeMotionProbeScreen> {
  final Distance _distance = const Distance();

  StreamSubscription<NativeGnssFix>? _streamSubscription;
  Timer? _pollTimer;

  NativeGnssFix? _lastStreamFix;
  NativeGnssFix? _firstStreamFix;
  NativeGnssFix? _lastPollFix;

  int _streamSamples = 0;
  int _pollSamples = 0;
  double _streamCumulativeMeters = 0;
  double _streamFromStartMeters = 0;
  double _lastStreamDeltaMeters = 0;
  String? _streamError;
  String? _pollError;
  bool _pollInFlight = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _start() {
    _streamSubscription?.cancel();
    _pollTimer?.cancel();

    _streamSubscription = GnssBridge.gpsFixStream.listen(
      _onStreamFix,
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _streamError = error.toString());
      },
    );

    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_pollOnce()),
    );

    unawaited(_pollOnce());
  }

  void _onStreamFix(NativeGnssFix fix) {
    final previous = _lastStreamFix;
    final first = _firstStreamFix ?? fix;

    var delta = 0.0;
    if (previous != null) {
      delta = _meters(previous.location, fix.location);
    }

    final fromStart = _meters(first.location, fix.location);

    if (!mounted) return;
    setState(() {
      _firstStreamFix ??= fix;
      _lastStreamFix = fix;
      _streamSamples += 1;
      _lastStreamDeltaMeters = delta;
      _streamCumulativeMeters += delta;
      _streamFromStartMeters = fromStart;
      _streamError = null;
    });
  }

  Future<void> _pollOnce() async {
    if (_pollInFlight) return;

    _pollInFlight = true;
    try {
      final fix = await GnssBridge.acquireGpsFix(
        timeout: const Duration(seconds: 4),
      );

      if (!mounted) return;

      if (fix == null) {
        setState(() => _pollError = 'no native poll fix');
        return;
      }

      setState(() {
        _lastPollFix = fix;
        _pollSamples += 1;
        _pollError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _pollError = error.toString());
    } finally {
      _pollInFlight = false;
    }
  }

  double _meters(LatLng a, LatLng b) {
    return _distance.as(LengthUnit.Meter, a, b);
  }

  String _age(DateTime? timestamp) {
    if (timestamp == null) return '-';
    final seconds = DateTime.now()
            .toUtc()
            .difference(timestamp.toUtc())
            .inMilliseconds /
        1000;
    return '${seconds.toStringAsFixed(1)} s';
  }

  String _fixText(NativeGnssFix? fix) {
    if (fix == null) return '-';

    return [
      'lat: ${fix.location.latitude.toStringAsFixed(7)}',
      'lng: ${fix.location.longitude.toStringAsFixed(7)}',
      'accuracy: ${fix.accuracyMeters.toStringAsFixed(1)} m',
      'speed: ${fix.speedMetersPerSecond.toStringAsFixed(1)} m/s',
      'heading: ${fix.headingDegrees.toStringAsFixed(1)}°',
      'age: ${_age(fix.timestamp)}',
      'satellites: ${fix.snapshot.satellitesUsedInFix}/'
          '${fix.snapshot.totalSatellites}',
      'avg C/N0: ${fix.snapshot.averageCn0DbHz.toStringAsFixed(1)} dB-Hz',
      'constellations: ${fix.snapshot.constellationSummary}',
      'mocked: ${fix.mocked}',
    ].join('\n');
  }

  String get _report {
    return [
      'RAHI Native Motion Probe',
      '',
      'STREAM',
      'samples: $_streamSamples',
      'last delta: ${_lastStreamDeltaMeters.toStringAsFixed(1)} m',
      'from start: ${_streamFromStartMeters.toStringAsFixed(1)} m',
      'cumulative: ${_streamCumulativeMeters.toStringAsFixed(1)} m',
      'error: ${_streamError ?? '-'}',
      _fixText(_lastStreamFix),
      '',
      'POLL',
      'samples: $_pollSamples',
      'error: ${_pollError ?? '-'}',
      _fixText(_lastPollFix),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RAHI Native Motion Probe'),
        actions: [
          IconButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: _report),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('گزارش کپی شد'),
                ),
              );
            },
            icon: const Icon(Icons.copy_all_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              title: 'Native EventChannel stream',
              text: [
                'samples: $_streamSamples',
                'last delta: ${_lastStreamDeltaMeters.toStringAsFixed(1)} m',
                'from start: ${_streamFromStartMeters.toStringAsFixed(1)} m',
                'cumulative: ${_streamCumulativeMeters.toStringAsFixed(1)} m',
                'error: ${_streamError ?? '-'}',
                '',
                _fixText(_lastStreamFix),
              ].join('\n'),
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'Native direct poll',
              text: [
                'samples: $_pollSamples',
                'error: ${_pollError ?? '-'}',
                '',
                _fixText(_lastPollFix),
              ].join('\n'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pollInFlight ? null : _pollOnce,
              icon: const Icon(Icons.gps_fixed_rounded),
              label: const Text('Poll once'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _lastStreamFix = null;
                  _firstStreamFix = null;
                  _lastPollFix = null;
                  _streamSamples = 0;
                  _pollSamples = 0;
                  _streamCumulativeMeters = 0;
                  _streamFromStartMeters = 0;
                  _lastStreamDeltaMeters = 0;
                  _streamError = null;
                  _pollError = null;
                });
                _start();
              },
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset and restart'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String text;

  const _Card({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              text,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
