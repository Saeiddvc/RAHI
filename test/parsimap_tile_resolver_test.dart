import 'package:flutter_test/flutter_test.dart';
import 'package:rahi/core/services/parsimap_tile_resolver.dart';

void main() {
  group('ParsimapTileResolver.extractTileTemplate', () {
    test('prefers composite tile template and preserves it exactly', () {
      final result = ParsimapTileResolver.extractTileTemplate({
        'sources': {
          'other': {
            'tiles': ['https://other.example/{z}/{x}/{y}'],
          },
          'composite': {
            'tiles': [
              'https://tiles.parsimap.ir/{z}/{x}/{y}?key=secret&foo=bar',
            ],
          },
        },
      });

      expect(
        result,
        'https://tiles.parsimap.ir/{z}/{x}/{y}?key=secret&foo=bar',
      );
    });

    test('falls back to first source with tiles', () {
      final result = ParsimapTileResolver.extractTileTemplate({
        'sources': {
          'vector': {'type': 'vector'},
          'raster': {
            'tiles': ['https://tiles.parsimap.ir/{z}/{x}/{y}'],
          },
        },
      });

      expect(
        result,
        'https://tiles.parsimap.ir/{z}/{x}/{y}',
      );
    });

    test('returns null for malformed style payload', () {
      expect(
        ParsimapTileResolver.extractTileTemplate({'sources': {}}),
        isNull,
      );
      expect(
        ParsimapTileResolver.extractTileTemplate(null),
        isNull,
      );
    });
  });
}
