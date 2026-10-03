import 'package:latlong2/latlong.dart';

enum ManeuverType {
  depart,
  arrive,
  turnLeft,
  turnRight,
  turnSlightLeft,
  turnSlightRight,
  turnSharpLeft,
  turnSharpRight,
  uTurn,
  straight,
  roundabout,
  merge,
  fork,
  onRamp,
  offRamp,
  unknown,
}

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final int durationSeconds;
  final ManeuverType maneuver;
  final LatLng location;
  final String? roadName;

  /// Raw Neshan maneuver type, e.g. "turn", "depart", "exit rotary".
  final String? rawType;

  /// Raw Neshan modifier, e.g. "left", "slight-right", "straight".
  final String? rawModifier;

  /// Encoded geometry for this individual step, when the provider supplies it.
  final String? encodedPolyline;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuver,
    required this.location,
    this.roadName,
    this.rawType,
    this.rawModifier,
    this.encodedPolyline,
  });

  static RouteStep? tryFromNeshanJson(Map<String, dynamic> json) {
    final instruction = json['instruction']?.toString().trim() ?? '';
    final location = _parseNeshanStartLocation(json['start_location']);

    if (instruction.isEmpty || location == null) {
      return null;
    }

    final rawType = json['type']?.toString();
    final rawModifier = json['modifier']?.toString();

    return RouteStep(
      instruction: instruction,
      distanceMeters: _metricValue(json['distance']),
      durationSeconds: _metricValue(json['duration']).round(),
      maneuver: parseManeuver(
        type: rawType,
        modifier: rawModifier,
      ),
      location: location,
      roadName: _nullableText(json['name']),
      rawType: _nullableText(rawType),
      rawModifier: _nullableText(rawModifier),
      encodedPolyline: _nullableText(json['polyline']),
    );
  }

  static ManeuverType parseManeuver({
    dynamic type,
    dynamic modifier,
  }) {
    final normalizedType = _normalize(type);
    final normalizedModifier = _normalize(modifier);

    if (normalizedType == 'depart') return ManeuverType.depart;
    if (normalizedType == 'arrive') return ManeuverType.arrive;

    if (normalizedModifier == 'uturn' ||
        normalizedModifier == 'u turn') {
      return ManeuverType.uTurn;
    }

    if (normalizedType.contains('roundabout') ||
        normalizedType.contains('rotary')) {
      return ManeuverType.roundabout;
    }

    if (normalizedType == 'merge') return ManeuverType.merge;
    if (normalizedType == 'fork') return ManeuverType.fork;
    if (normalizedType == 'on ramp' || normalizedType == 'onramp') {
      return ManeuverType.onRamp;
    }
    if (normalizedType == 'off ramp' || normalizedType == 'offramp') {
      return ManeuverType.offRamp;
    }

    if (_isSlightLeft(normalizedModifier)) {
      return ManeuverType.turnSlightLeft;
    }
    if (_isSlightRight(normalizedModifier)) {
      return ManeuverType.turnSlightRight;
    }
    if (_isSharpLeft(normalizedModifier)) {
      return ManeuverType.turnSharpLeft;
    }
    if (_isSharpRight(normalizedModifier)) {
      return ManeuverType.turnSharpRight;
    }
    if (normalizedModifier == 'left') return ManeuverType.turnLeft;
    if (normalizedModifier == 'right') return ManeuverType.turnRight;
    if (normalizedModifier == 'straight') return ManeuverType.straight;

    if (normalizedType == 'continue' ||
        normalizedType == 'new name' ||
        normalizedType == 'notification') {
      return ManeuverType.straight;
    }

    return ManeuverType.unknown;
  }

  static double _metricValue(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is Map) {
      final value = raw['value'];
      if (value is num) return value.toDouble();
    }
    return 0;
  }

  static LatLng? _parseNeshanStartLocation(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      final longitude = raw[0];
      final latitude = raw[1];

      if (longitude is num && latitude is num) {
        return LatLng(latitude.toDouble(), longitude.toDouble());
      }
    }

    if (raw is Map) {
      final latitude = raw['lat'] ?? raw['latitude'];
      final longitude =
          raw['lng'] ?? raw['lon'] ?? raw['longitude'];

      if (latitude is num && longitude is num) {
        return LatLng(latitude.toDouble(), longitude.toDouble());
      }
    }

    return null;
  }

  static String _normalize(dynamic value) {
    return value
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ') ??
        '';
  }

  static bool _isSlightLeft(String value) =>
      value == 'slight left';

  static bool _isSlightRight(String value) =>
      value == 'slight right';

  static bool _isSharpLeft(String value) =>
      value == 'sharp left';

  static bool _isSharpRight(String value) =>
      value == 'sharp right';

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
