import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rahi/data/models/place.dart';
import 'package:rahi/features/map/utils/search_result_ranker.dart';

void main() {
  group('SearchResultRanker', () {
    const center = LatLng(35.7000, 51.4000);

    test('nearby POI queries prefer the closest result', () {
      const far = Place(
        title: 'پمپ بنزین شرکتی',
        address: 'دور',
        location: LatLng(35.7800, 51.4000),
      );
      const near = Place(
        title: 'جایگاه سوخت محلی',
        address: 'نزدیک',
        location: LatLng(35.7010, 51.4000),
      );

      final ranked = SearchResultRanker.mergeAndRank(
        query: 'پمپ بنزین شرکتی',
        center: center,
        primary: const [far],
        secondary: const [near],
      );

      expect(ranked.first.title, 'جایگاه سوخت محلی');
    });

    test('duplicate provider results are collapsed', () {
      const a = Place(
        title: 'کافه تست',
        address: 'آدرس ۱',
        location: LatLng(35.7000, 51.4000),
      );
      const b = Place(
        title: 'کافه تست',
        address: 'آدرس ۲',
        location: LatLng(35.7001, 51.4000),
      );

      final ranked = SearchResultRanker.mergeAndRank(
        query: 'کافه',
        center: center,
        primary: const [a],
        secondary: const [b],
      );

      expect(ranked, hasLength(1));
    });

    test('ordinary address search preserves provider relevance order', () {
      const first = Place(
        title: 'میدان آزادی',
        address: 'تهران',
        location: LatLng(35.6990, 51.3370),
      );
      const second = Place(
        title: 'خیابان آزادی',
        address: 'تهران',
        location: LatLng(35.7000, 51.3900),
      );

      final ranked = SearchResultRanker.mergeAndRank(
        query: 'میدان آزادی تهران',
        center: center,
        primary: const [first, second],
        secondary: const [],
      );

      expect(ranked.first.title, 'میدان آزادی');
    });
  });
}
