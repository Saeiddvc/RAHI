import 'package:latlong2/latlong.dart';

import '../../data/models/map_route.dart';
import '../../data/models/place.dart';

abstract class MapService {
  Future<List<Place>> search({
    required String term,
    required LatLng center,
  });

  Future<String?> reverse(LatLng point);

  Future<List<MapRoute>> direction({
    required LatLng origin,
    required LatLng destination,
    required String type,
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
