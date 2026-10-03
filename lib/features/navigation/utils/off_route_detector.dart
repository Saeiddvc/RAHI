import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class OffRouteDetector {
  OffRouteDetector._();

  static const double offRouteThresholdMeters = 50;

  static double distanceToRoute(
    LatLng point,
    List<LatLng> route,
  ) {
    if (route.isEmpty) return double.infinity;

    if (route.length == 1) {
      return const Distance().as(
        LengthUnit.Meter,
        point,
        route.first,
      );
    }

    var minimumDistance = double.infinity;

    for (var index = 0; index < route.length - 1; index++) {
      final distance = _distanceToSegment(
        point,
        route[index],
        route[index + 1],
      );

      if (distance < minimumDistance) {
        minimumDistance = distance;
      }
    }

    return minimumDistance;
  }

  static double _distanceToSegment(
    LatLng point,
    LatLng start,
    LatLng end,
  ) {
    const metersPerDegreeLatitude = 111320.0;

    final referenceLatitudeRadians =
        ((start.latitude + end.latitude) / 2) * math.pi / 180;
    final metersPerDegreeLongitude =
        metersPerDegreeLatitude * math.cos(referenceLatitudeRadians);

    double toX(double longitude) =>
        (longitude - start.longitude) * metersPerDegreeLongitude;

    double toY(double latitude) =>
        (latitude - start.latitude) * metersPerDegreeLatitude;

    final px = toX(point.longitude);
    final py = toY(point.latitude);
    final endX = toX(end.longitude);
    final endY = toY(end.latitude);

    final segmentLengthSquared =
        endX * endX + endY * endY;

    if (segmentLengthSquared == 0) {
      return math.sqrt(px * px + py * py);
    }

    var projection =
        (px * endX + py * endY) / segmentLengthSquared;
    projection = projection.clamp(0.0, 1.0);

    final projectedX = projection * endX;
    final projectedY = projection * endY;

    final deltaX = px - projectedX;
    final deltaY = py - projectedY;

    return math.sqrt(deltaX * deltaX + deltaY * deltaY);
  }
}
