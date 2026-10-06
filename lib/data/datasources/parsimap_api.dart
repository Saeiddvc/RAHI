import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/secrets.dart';
import '../../core/services/map_service.dart';
import '../../core/services/parsimap_tile_resolver.dart';
import '../models/map_route.dart';
import '../models/place.dart';

class ParsimapApi implements MapService {
  final Dio _dio;
  final ParsimapTileResolver _tileResolver;

  ParsimapApi([Dio? dio, ParsimapTileResolver? tileResolver])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.parsimapBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
              ),
            ),
        _tileResolver = tileResolver ?? ParsimapTileResolver();

  @override
  String get displayName => 'پارسی‌مپ (Parsimap)';

  // Routing remains disabled until a documented route geometry/polyline
  // response is confirmed. A straight line must not be presented as a route.
  @override
  Set<RouteType> get supportedRouteTypes => const {};

  @override
  Future<List<Place>> search({
    required String term,
    required LatLng center,
  }) async {
    _requireServiceToken();

    final normalizedTerm = term.trim();
    if (normalizedTerm.isEmpty) return const [];

    try {
      final response = await _dio.get(
        '/geocode/forward',
        queryParameters: {
          'key': Secrets.parsimapServiceToken,
          'search_text': normalizedTerm,
          'district': '${center.longitude},${center.latitude}',
        },
      );

      final data = _asMap(response.data);
      final rawItems = data['results'];
      if (rawItems is! List) return const [];

      final places = <Place>[];
      for (final raw in rawItems.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final geoLocation = _asMap(item['geo_location']);
        final location = _asMap(geoLocation['center']);

        final longitude = (location['lng'] as num?)?.toDouble();
        final latitude = (location['lat'] as num?)?.toDouble();

        if (latitude == null || longitude == null) continue;

        places.add(
          Place(
            title: geoLocation['title']?.toString() ??
                item['title']?.toString() ??
                item['description']?.toString() ??
                '',
            address: item['description']?.toString() ??
                item['address']?.toString() ??
                '',
            location: LatLng(latitude, longitude),
          ),
        );
      }

      return places;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  @override
  Future<String?> reverse(LatLng point) async {
    _requireServiceToken();

    try {
      final response = await _dio.get(
        AppConstants.parsimapReversePath,
        queryParameters: {
          'key': Secrets.parsimapServiceToken,
          'location': '${point.longitude},${point.latitude}',
          'local_address': false,
          'approx_address': false,
          'subdivision': false,
          'plate': false,
          'request_id': false,
        },
      );

      final data = _asMap(response.data);
      return data['address']?.toString() ??
          data['formatted_address']?.toString();
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  @override
  Future<List<MapRoute>> direction({
    required LatLng origin,
    required LatLng destination,
    required RouteType type,
  }) {
    throw const MapServiceException(
      'مسیریابی پارسی‌مپ تا تأیید Endpoint رسمی geometry/polyline در RAHI غیرفعال است.',
    );
  }

  @override
  String get tileUrlTemplate => AppConstants.parsimapTileUrl;

  @override
  Map<String, String> get tileUrlParams => {
        if (Secrets.parsimapMapToken.isNotEmpty)
          'key': Secrets.parsimapMapToken,
      };

  @override
  Future<String?> resolveTileUrlTemplate() => _tileResolver.resolve();

  void _requireServiceToken() {
    if (Secrets.parsimapServiceToken.isEmpty) {
      throw const MapServiceException(
        'PARSIMAP_SERVICE_TOKEN برای این Build تنظیم نشده است.',
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  MapServiceException _mapDioError(DioException error) {
    final code = error.response?.statusCode;

    if (code == 401) {
      return const MapServiceException('توکن سرویس پارسی‌مپ نامعتبر است.');
    }
    if (code == 403) {
      return const MapServiceException(
        'دسترسی به سرویس پارسی‌مپ مجاز نیست.',
      );
    }
    if (code == 404) {
      return const MapServiceException('سرویس پارسی‌مپ یافت نشد.');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const MapServiceException('ارتباط با پارسی‌مپ Timeout شد.');
    }

    final suffix = code == null ? '' : ' ($code)';
    return MapServiceException('خطا در ارتباط با پارسی‌مپ$suffix.');
  }
}
