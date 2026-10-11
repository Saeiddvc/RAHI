import 'package:latlong2/latlong.dart';

import '../../../data/models/place.dart';

class SearchResultRanker {
  SearchResultRanker._();

  static const _nearbyIntentTerms = <String>[
    'پمپ بنزین',
    'جایگاه سوخت',
    'بنزین',
    'رستوران',
    'کافه',
    'بیمارستان',
    'درمانگاه',
    'هتل',
    'پارکینگ',
    'بانک',
    'خودپرداز',
    'سوپرمارکت',
    'داروخانه',
  ];

  static List<Place> mergeAndRank({
    required String query,
    required LatLng center,
    required List<Place> primary,
    required List<Place> secondary,
  }) {
    final merged = <Place>[];

    for (final place in [...primary, ...secondary]) {
      if (!_hasUsableLocation(place)) continue;

      final duplicate = merged.any(
        (existing) => _isDuplicate(existing, place),
      );

      if (!duplicate) {
        merged.add(place);
      }
    }

    final nearbyIntent = _isNearbyIntent(query);

    if (nearbyIntent) {
      merged.sort(
        (a, b) => _distanceMeters(center, a.location)
            .compareTo(_distanceMeters(center, b.location)),
      );
    }

    return List<Place>.unmodifiable(merged);
  }

  static bool _isNearbyIntent(String query) {
    final normalized = _normalize(query);
    return _nearbyIntentTerms.any(normalized.contains);
  }

  static bool _hasUsableLocation(Place place) {
    final lat = place.location.latitude;
    final lng = place.location.longitude;

    return lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        !(lat == 0 && lng == 0);
  }

  static bool _isDuplicate(Place a, Place b) {
    final sameTitle =
        _normalize(a.title) == _normalize(b.title);

    final distance = _distanceMeters(
      a.location,
      b.location,
    );

    if (distance <= 40) return true;
    return sameTitle && distance <= 180;
  }

  static double _distanceMeters(
    LatLng from,
    LatLng to,
  ) {
    return const Distance().as(
      LengthUnit.Meter,
      from,
      to,
    );
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
