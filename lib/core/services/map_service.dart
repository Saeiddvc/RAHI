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

/// Optional capability for map services whose raster tile template must be
/// resolved asynchronously before it can be consumed by flutter_map.
abstract interface class AsyncTileTemplateService {
  Future<String?> resolveTileUrlTemplate();
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
}

class MapServiceException implements Exception {
  final String message;

  const MapServiceException(this.message);

  @override
  String toString() => message;
}
