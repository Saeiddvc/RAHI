import 'package:latlong2/latlong.dart';

import '../../data/models/map_route.dart';
import '../../data/models/place.dart';

enum RouteType {
  car('car'),
  motorcycle('motorcycle'),
  pedestrian('pedestrian'),
  bicycle('bicycle');

  const RouteType(this.apiValue);

  final String apiValue;
}

abstract class MapService {
  String get displayName;

  Set<RouteType> get supportedRouteTypes;

  Future<List<Place>> search({
    required String term,
    required LatLng center,
  });

  Future<String?> reverse(LatLng point);

  Future<List<MapRoute>> direction({
    required LatLng origin,
    required LatLng destination,
    required RouteType type,
  });

  String get tileUrlTemplate;

  Map<String, String> get tileUrlParams;

  /// Resolves the final raster tile template. Providers that need an
  /// asynchronous style lookup can override this; others use the synchronous
  /// tile contract by default.
  Future<String?> resolveTileUrlTemplate() async => tileUrlTemplate;
}

class MapServiceException implements Exception {
  final String message;

  const MapServiceException(this.message);

  @override
  String toString() => message;
}
