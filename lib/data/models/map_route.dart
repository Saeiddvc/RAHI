import 'package:latlong2/latlong.dart';

class MapRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
  final String? trafficStatus;
  final String? summary;

  const MapRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.trafficStatus,
    this.summary,
  });

  MapRoute copyWith({
    List<LatLng>? points,
    double? distanceMeters,
    int? durationSeconds,
    String? trafficStatus,
    String? summary,
  }) {
    return MapRoute(
      points: points ?? this.points,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      trafficStatus: trafficStatus ?? this.trafficStatus,
      summary: summary ?? this.summary,
    );
  }
}
