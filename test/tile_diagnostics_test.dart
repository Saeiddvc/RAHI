import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/core/services/tile_diagnostics.dart';
import 'package:rahi/core/utils/tile_url_composer.dart';

void main() {
  group('TileUrlComposer', () {
    test('appends parameters without duplicating an existing key', () {
      expect(
        TileUrlComposer.compose(
          'https://tiles.example/{z}/{x}/{y}?foo=bar',
          const {'key': 'secret', 'foo': 'new'},
        ),
        'https://tiles.example/{z}/{x}/{y}?foo=bar&key=secret',
      );
    });
  });

  group('TileDiagnostics.sampleTileUrl', () {
    test('replaces XYZ placeholders with numeric coordinates', () {
      final url = TileDiagnostics.sampleTileUrl(
        'https://tiles.example/{z}/{x}/{y}.png',
        center: const LatLng(35.6892, 51.3890),
        zoom: 13,
      );

      expect(url, startsWith('https://tiles.example/13/'));
      expect(url, isNot(contains('{z}')));
      expect(url, isNot(contains('{x}')));
      expect(url, isNot(contains('{y}')));
    });
  });
}
