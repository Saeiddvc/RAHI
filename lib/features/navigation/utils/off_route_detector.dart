import 'package:latlong2/latlong.dart';

import 'route_progress_matcher.dart';

class OffRouteDetector {
  OffRouteDetector._();

  static const double offRouteThresholdMeters = 50;

  static double distanceToRoute(
    LatLng point,
    List<LatLng> route,
  ) {
    return RouteProgressMatcher.project(
          point,
          route,
        )?.distanceToRouteMeters ??
        double.infinity;
  }
}
