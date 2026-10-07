import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/map_service.dart';
import '../data/datasources/neshan_api.dart';
import '../data/datasources/parsimap_api.dart';

/// RAHI provider policy:
/// - Parsimap: primary place search / geocoding service.
/// - Neshan: direction engine where Parsimap routing is not yet verified.
/// - OSM: raster map fallback, exposed by NeshanApi.tileUrlTemplate.
///
/// Keep these responsibilities explicit. UI must never switch routing/search
/// behavior implicitly.
final searchServiceProvider = Provider<MapService>((ref) {
  return ParsimapApi();
});

final reverseServiceProvider = Provider<MapService>((ref) {
  return ParsimapApi();
});

final routingServiceProvider = Provider<MapService>((ref) {
  return NeshanApi();
});
