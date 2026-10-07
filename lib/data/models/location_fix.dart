import 'package:latlong2/latlong.dart';

enum LocationSource {
  gps,
  lastKnown,
  unknown,
}

/// A location sample together with the metadata needed to decide whether it
/// is safe to use as a routing origin.
class LocationFix {
  final LatLng location;
  final DateTime timestamp;
  final double accuracyMeters;
  final LocationSource source;
  final bool isMocked;
  final double? satelliteCount;
  final double? satellitesUsedInFix;

  const LocationFix({
    required this.location,
    required this.timestamp,
    required this.accuracyMeters,
    required this.source,
    this.isMocked = false,
    this.satelliteCount,
    this.satellitesUsedInFix,
  });

  Duration get age {
    final value = DateTime.now().toUtc().difference(timestamp.toUtc());
    return value.isNegative ? Duration.zero : value;
  }

  int get ageSeconds => age.inSeconds;

  bool get isGps => source == LocationSource.gps;

  bool isFresh({
    Duration maxAge = const Duration(seconds: 30),
  }) {
    return age <= maxAge;
  }

  bool isAccurate({double maxMeters = 50}) {
    return accuracyMeters > 0 && accuracyMeters <= maxMeters;
  }

  bool hasTrustedGnss({
    bool requireSatelliteEvidence = false,
    double minSatellitesUsed = 4,
  }) {
    if (!isGps || isMocked) return false;
    if (!requireSatelliteEvidence) return true;

    final used = satellitesUsedInFix;
    return used != null && used >= minSatellitesUsed;
  }

  @override
  String toString() {
    return 'LocationFix('
        'lat: ${location.latitude}, '
        'lng: ${location.longitude}, '
        'age: ${ageSeconds}s, '
        'accuracy: ${accuracyMeters}m, '
        'source: $source, '
        'mocked: $isMocked, '
        'satellites: ${satellitesUsedInFix ?? "-"}/${satelliteCount ?? "-"}'
        ')';
  }
}
