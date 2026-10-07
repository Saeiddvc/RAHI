import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/map_service.dart';
import '../data/datasources/neshan_api.dart';
import '../data/datasources/parsimap_api.dart';

enum MapProviderKind { neshan, parsimap }

final selectedMapProviderProvider =
    StateProvider<MapProviderKind>((ref) => MapProviderKind.neshan);

final mapServiceProvider = Provider<MapService>((ref) {
  final selected = ref.watch(selectedMapProviderProvider);

  return switch (selected) {
    MapProviderKind.neshan => NeshanApi(),
    MapProviderKind.parsimap => ParsimapApi(),
  };
});

final searchServiceProvider = Provider<MapService>((ref) {
  return ParsimapApi();
});
