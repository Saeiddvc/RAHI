import 'package:latlong2/latlong.dart';

import '../../data/datasources/neshan_api.dart';
import '../../data/datasources/parsimap_api.dart';
import '../../data/models/map_route.dart';
import '../../data/models/place.dart';
import 'map_service.dart';

/// Hybrid map service for RAHI.
///
/// Search, reverse geocoding and raster tiles are delegated to Parsimap.
/// Routing and supported route types are delegated to Neshan.
class CompositeMapService implements MapService, AsyncTileTemplateService {
  final MapService _parsimap;
  final MapService _neshan;

  CompositeMapService({
    MapService? parsimap,
    MapService? neshan,
  })  : _parsimap = parsimap ?? ParsimapApi(),
        _neshan = neshan ?? NeshanApi();

  @override
  String get displayName => 'Hybrid (Parsimap + Neshan)';

  @override
  Set<RouteType> get supportedRouteTypes => _neshan.supportedRouteTypes;

  @override
  Future<List<Place>> search({
    required String term,
    required LatLng center,
  }) {
    return _parsimap.search(term: term, center: center);
  }

  @override
  Future<String?> reverse(LatLng point) {
    return _parsimap.reverse(point);
  }

  @override
  Future<List<MapRoute>> direction({
    required LatLng origin,
    required LatLng destination,
    required RouteType type,
  }) {
    return _neshan.direction(
      origin: origin,
      destination: destination,
      type: type,
    );
  }

  @override
  String get tileUrlTemplate => _parsimap.tileUrlTemplate;

  @override
  Map<String, String> get tileUrlParams => _parsimap.tileUrlParams;

  @override
  Future<String?> resolveTileUrlTemplate() {
    final service = _parsimap;
    if (service is AsyncTileTemplateService) {
      return service.resolveTileUrlTemplate();
    }
    return Future<String?>.value(service.tileUrlTemplate);
  }
}
