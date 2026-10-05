import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/core/services/composite_map_service.dart';
import 'package:rahi/core/services/map_service.dart';
import 'package:rahi/data/models/map_route.dart';
import 'package:rahi/data/models/place.dart';

void main() {
  group('CompositeMapService', () {
    test('delegates Search and Reverse to Parsimap', () async {
      final parsimap = _FakeMapService(
        displayName: 'Parsimap',
        tileUrlTemplate: 'https://api.parsimap.ir/tile/{z}/{x}/{y}',
        tileUrlParams: const {'key': 'map-token'},
      );
      final neshan = _FakeMapService(
        displayName: 'Neshan',
        supportedRouteTypes: const {
          RouteType.car,
          RouteType.motorcycle,
        },
      );
      final service = CompositeMapService(
        parsimap: parsimap,
        neshan: neshan,
      );

      final center = LatLng(35.6892, 51.3890);
      final results = await service.search(
        term: 'میدان آزادی',
        center: center,
      );
      final reverse = await service.reverse(center);

      expect(results, hasLength(1));
      expect(reverse, 'Parsimap reverse');
      expect(parsimap.searchCalls, 1);
      expect(parsimap.reverseCalls, 1);
      expect(neshan.searchCalls, 0);
      expect(neshan.reverseCalls, 0);
    });

    test('delegates Direction and supportedRouteTypes to Neshan', () async {
      final parsimap = _FakeMapService(displayName: 'Parsimap');
      final neshan = _FakeMapService(
        displayName: 'Neshan',
        supportedRouteTypes: const {
          RouteType.car,
          RouteType.motorcycle,
        },
      );
      final service = CompositeMapService(
        parsimap: parsimap,
        neshan: neshan,
      );

      final routes = await service.direction(
        origin: LatLng(35.6892, 51.3890),
        destination: LatLng(35.6997, 51.3379),
        type: RouteType.car,
      );

      expect(routes, hasLength(1));
      expect(neshan.directionCalls, 1);
      expect(parsimap.directionCalls, 0);
      expect(
        service.supportedRouteTypes,
        const {RouteType.car, RouteType.motorcycle},
      );
    });

    test('uses Parsimap tile contract', () {
      final parsimap = _FakeMapService(
        displayName: 'Parsimap',
        tileUrlTemplate:
            'https://api.parsimap.ir/tile/parsimap-streets-v11-raster/{z}/{x}/{y}',
        tileUrlParams: const {'key': 'map-token'},
      );
      final service = CompositeMapService(
        parsimap: parsimap,
        neshan: _FakeMapService(displayName: 'Neshan'),
      );

      expect(service.displayName.toLowerCase(), contains('hybrid'));
      expect(service.tileUrlTemplate, contains('parsimap.ir'));
      expect(
        service.tileUrlTemplate,
        contains('parsimap-streets-v11-raster'),
      );
      expect(service.tileUrlParams['key'], 'map-token');
    });
  });
}

class _FakeMapService implements MapService {
  _FakeMapService({
    required this.displayName,
    this.supportedRouteTypes = const {},
    this.tileUrlTemplate = '',
    this.tileUrlParams = const {},
  });

  @override
  final String displayName;

  @override
  final Set<RouteType> supportedRouteTypes;

  @override
  final String tileUrlTemplate;

  @override
  final Map<String, String> tileUrlParams;

  int searchCalls = 0;
  int reverseCalls = 0;
  int directionCalls = 0;

  @override
  Future<List<Place>> search({
    required String term,
    required LatLng center,
  }) async {
    searchCalls++;
    return [
      Place(
        title: term,
        address: 'Parsimap result',
        location: center,
      ),
    ];
  }

  @override
  Future<String?> reverse(LatLng point) async {
    reverseCalls++;
    return 'Parsimap reverse';
  }

  @override
  Future<List<MapRoute>> direction({
    required LatLng origin,
    required LatLng destination,
    required RouteType type,
  }) async {
    directionCalls++;
    return [
      MapRoute(
        points: [origin, destination],
        distanceMeters: 1000,
        durationSeconds: 120,
      ),
    ];
  }
}
