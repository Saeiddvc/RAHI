import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/composite_map_service.dart';
import '../core/services/map_service.dart';
import '../data/datasources/neshan_api.dart';
import '../data/datasources/parsimap_api.dart';

enum MapProviderKind { hybrid, parsimap, neshan }

final selectedMapProviderProvider =
    StateProvider<MapProviderKind>((ref) => MapProviderKind.hybrid);

final mapServiceProvider = Provider<MapService>((ref) {
  final selected = ref.watch(selectedMapProviderProvider);

  return switch (selected) {
    MapProviderKind.hybrid => CompositeMapService(),
    MapProviderKind.parsimap => ParsimapApi(),
    MapProviderKind.neshan => NeshanApi(),
  };
});
