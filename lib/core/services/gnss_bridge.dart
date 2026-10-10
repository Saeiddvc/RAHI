import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class GnssSnapshot {
  final int totalSatellites;
  final int satellitesUsedInFix;
  final double averageCn0DbHz;
  final Map<String, int> constellations;
  final bool gpsProviderEnabled;
  final bool networkProviderEnabled;

  const GnssSnapshot({
    required this.totalSatellites,
    required this.satellitesUsedInFix,
    required this.averageCn0DbHz,
    required this.constellations,
    required this.gpsProviderEnabled,
    required this.networkProviderEnabled,
  });

  factory GnssSnapshot.fromMap(Map<Object?, Object?> map) {
    final rawConstellations = map['constellations'];
    final constellations = <String, int>{};

    if (rawConstellations is Map) {
      for (final entry in rawConstellations.entries) {
        final value = entry.value;
        if (value is num) {
          constellations[entry.key.toString()] = value.round();
        }
      }
    }

    return GnssSnapshot(
      totalSatellites: (map['totalSatellites'] as num?)?.round() ?? 0,
      satellitesUsedInFix:
          (map['satellitesUsedInFix'] as num?)?.round() ?? 0,
      averageCn0DbHz:
          (map['averageCn0DbHz'] as num?)?.toDouble() ?? 0,
      constellations: constellations,
      gpsProviderEnabled: map['gpsProviderEnabled'] == true,
      networkProviderEnabled: map['networkProviderEnabled'] == true,
    );
  }

  String get constellationSummary {
    if (constellations.isEmpty) return '—';

    final entries = constellations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((entry) => '${entry.key}:${entry.value}').join(' ');
  }
}

class NativeGnssFix {
  final LatLng location;
  final double accuracyMeters;
  final DateTime timestamp;
  final double speedMetersPerSecond;
  final double headingDegrees;
  final bool mocked;
  final GnssSnapshot snapshot;

  const NativeGnssFix({
    required this.location,
    required this.accuracyMeters,
    required this.timestamp,
    required this.speedMetersPerSecond,
    required this.headingDegrees,
    required this.mocked,
    required this.snapshot,
  });

  factory NativeGnssFix.fromMap(Map<Object?, Object?> map) {
    final latitude = (map['latitude'] as num).toDouble();
    final longitude = (map['longitude'] as num).toDouble();

    return NativeGnssFix(
      location: LatLng(latitude, longitude),
      accuracyMeters: (map['accuracy'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestampMillis'] as num).round(),
        isUtc: true,
      ),
      speedMetersPerSecond: (map['speed'] as num?)?.toDouble() ?? 0,
      headingDegrees: (map['bearing'] as num?)?.toDouble() ?? 0,
      mocked: map['mocked'] == true,
      snapshot: GnssSnapshot.fromMap(map),
    );
  }
}

class GnssBridge {
  GnssBridge._();

  static const MethodChannel _channel = MethodChannel('rahi/gnss');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<NativeGnssFix?> acquireGpsFix({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!_supported) return null;

    try {
      final result = await _channel.invokeMethod<Object?>(
        'acquireGpsFix',
        <String, Object?>{
          'timeoutMs': timeout.inMilliseconds,
        },
      );

      if (result is! Map || result['available'] != true) {
        return null;
      }

      return NativeGnssFix.fromMap(result);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<GnssSnapshot?> snapshot() async {
    if (!_supported) return null;

    try {
      final result =
          await _channel.invokeMethod<Object?>('getGnssSnapshot');

      if (result is! Map) return null;
      return GnssSnapshot.fromMap(result);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
