import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class RouteProjection {
  final LatLng snappedPoint;
  final double distanceToRouteMeters;
  final double distanceAlongPolylineMeters;
  final double totalPolylineMeters;
  final int segmentIndex;
  final double segmentFraction;

  const RouteProjection({
    required this.snappedPoint,
    required this.distanceToRouteMeters,
    required this.distanceAlongPolylineMeters,
    required this.totalPolylineMeters,
    required this.segmentIndex,
    required this.segmentFraction,
  });

  double get remainingPolylineMeters =>
      math.max(0, totalPolylineMeters - distanceAlongPolylineMeters);

  double get progressFraction {
    if (totalPolylineMeters <= 0) return 0;
    return (distanceAlongPolylineMeters / totalPolylineMeters)
        .clamp(0.0, 1.0);
  }
}

class RouteProgressMatcher {
  RouteProgressMatcher._();

  static const double defaultBacktrackToleranceMeters = 35;

  static RouteProjection? project(
    LatLng point,
    List<LatLng> route, {
    double? previousDistanceAlongMeters,
    double backtrackToleranceMeters = defaultBacktrackToleranceMeters,
  }) {
    if (route.isEmpty) return null;

    const distance = Distance();

    if (route.length == 1) {
      final distanceToPoint = distance.as(
        LengthUnit.Meter,
        point,
        route.first,
      );

      return RouteProjection(
        snappedPoint: route.first,
        distanceToRouteMeters: distanceToPoint,
        distanceAlongPolylineMeters: 0,
        totalPolylineMeters: 0,
        segmentIndex: 0,
        segmentFraction: 0,
      );
    }

    final segmentLengths = <double>[];
    var totalLength = 0.0;

    for (var index = 0; index < route.length - 1; index++) {
      final length = distance.as(
        LengthUnit.Meter,
        route[index],
        route[index + 1],
      );
      segmentLengths.add(length);
      totalLength += length;
    }

    _Candidate? bestGlobal;
    _Candidate? bestContinuous;
    var distanceBeforeSegment = 0.0;

    for (var index = 0; index < route.length - 1; index++) {
      final segmentLength = segmentLengths[index];
      final segment = _projectToSegment(
        point,
        route[index],
        route[index + 1],
      );

      final distanceAlong =
          distanceBeforeSegment + (segmentLength * segment.fraction);

      final candidate = _Candidate(
        snappedPoint: segment.snappedPoint,
        distanceToRouteMeters: segment.distanceMeters,
        distanceAlongPolylineMeters: distanceAlong,
        segmentIndex: index,
        segmentFraction: segment.fraction,
      );

      bestGlobal = _preferCandidate(
        current: bestGlobal,
        candidate: candidate,
        previousDistanceAlongMeters: null,
      );

      final previous = previousDistanceAlongMeters;
      final continuityAllowed = previous == null ||
          distanceAlong >= previous - backtrackToleranceMeters;

      if (continuityAllowed) {
        bestContinuous = _preferCandidate(
          current: bestContinuous,
          candidate: candidate,
          previousDistanceAlongMeters: previous,
        );
      }

      distanceBeforeSegment += segmentLength;
    }

    final selected = bestContinuous ?? bestGlobal;
    if (selected == null) return null;

    return RouteProjection(
      snappedPoint: selected.snappedPoint,
      distanceToRouteMeters: selected.distanceToRouteMeters,
      distanceAlongPolylineMeters:
          selected.distanceAlongPolylineMeters.clamp(0.0, totalLength),
      totalPolylineMeters: totalLength,
      segmentIndex: selected.segmentIndex,
      segmentFraction: selected.segmentFraction,
    );
  }

  static _Candidate _preferCandidate({
    required _Candidate? current,
    required _Candidate candidate,
    required double? previousDistanceAlongMeters,
  }) {
    if (current == null) return candidate;

    const distanceTieMeters = 8.0;

    if (candidate.distanceToRouteMeters <
        current.distanceToRouteMeters - distanceTieMeters) {
      return candidate;
    }

    if ((candidate.distanceToRouteMeters -
                current.distanceToRouteMeters)
            .abs() >
        distanceTieMeters) {
      return current;
    }

    final previous = previousDistanceAlongMeters;
    if (previous != null) {
      final candidateDelta =
          (candidate.distanceAlongPolylineMeters - previous).abs();
      final currentDelta =
          (current.distanceAlongPolylineMeters - previous).abs();

      if (candidateDelta < currentDelta) {
        return candidate;
      }

      if (currentDelta < candidateDelta) {
        return current;
      }
    }

    if (candidate.distanceToRouteMeters < current.distanceToRouteMeters) {
      return candidate;
    }

    return current;
  }

  static _SegmentProjection _projectToSegment(
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
        (endX * endX) + (endY * endY);

    var fraction = 0.0;

    if (segmentLengthSquared > 0) {
      fraction =
          ((px * endX) + (py * endY)) / segmentLengthSquared;
      fraction = fraction.clamp(0.0, 1.0);
    }

    final projectedX = fraction * endX;
    final projectedY = fraction * endY;
    final deltaX = px - projectedX;
    final deltaY = py - projectedY;

    final snappedPoint = LatLng(
      start.latitude +
          ((end.latitude - start.latitude) * fraction),
      start.longitude +
          ((end.longitude - start.longitude) * fraction),
    );

    return _SegmentProjection(
      snappedPoint: snappedPoint,
      distanceMeters: math.sqrt(
        (deltaX * deltaX) + (deltaY * deltaY),
      ),
      fraction: fraction,
    );
  }
}

class _SegmentProjection {
  final LatLng snappedPoint;
  final double distanceMeters;
  final double fraction;

  const _SegmentProjection({
    required this.snappedPoint,
    required this.distanceMeters,
    required this.fraction,
  });
}

class _Candidate {
  final LatLng snappedPoint;
  final double distanceToRouteMeters;
  final double distanceAlongPolylineMeters;
  final int segmentIndex;
  final double segmentFraction;

  const _Candidate({
    required this.snappedPoint,
    required this.distanceToRouteMeters,
    required this.distanceAlongPolylineMeters,
    required this.segmentIndex,
    required this.segmentFraction,
  });
}
