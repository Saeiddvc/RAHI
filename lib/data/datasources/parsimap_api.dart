import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/secrets.dart';
import '../../core/services/map_service.dart';
import '../models/map_route.dart';
import '../models/place.dart';

class ParsimapApi implements MapService {
  final Dio _dio;

  ParsimapApi([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.parsimap.ir',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

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
        '/geocode/search',
        queryParameters: {
          'key': Secrets.parsimapServiceToken,
          'address': normalizedTerm,
          'location': '${center.longitude},${center.latitude}',
        },
      );

      final data = _asMap(response.data);
      final rawItems = data['results'] ?? data['items'];
      if (rawItems is! List) return const [];

      final places = <Place>[];
      for (final raw in rawItems.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final geometry = _asMap(item['geometry']);
        final rawLocation = item['location'] ?? geometry['location'];
        final location = _asMap(rawLocation);

        final longitude =
            (location['x'] as num?)?.toDouble() ??
                (location['lng'] as num?)?.toDouble();
        final latitude =
            (location['y'] as num?)?.toDouble() ??
                (location['lat'] as num?)?.toDouble();

        if (latitude == null || longitude == null) continue;

        places.add(
          Place(
            title: item['title']?.toString() ??
                item['address']?.toString() ??
                '',
            address: item['address']?.toString() ?? '',
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
        '/geocode/reverse',
        queryParameters: {
          'key': Secrets.parsimapServiceToken,
          'location': '${point.longitude},${point.latitude}',
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
  String get tileUrlTemplate =>
      'https://api.parsimap.ir/tile/parsimap/{z}/{x}/{y}';

  @override
  Map<String, String> get tileUrlParams => {
        if (Secrets.parsimapMapToken.isNotEmpty)
          'key': Secrets.parsimapMapToken,
      };

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
      return const MapServiceException('دسترسی به سرویس پارسی‌مپ مجاز نیست.');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const MapServiceException('ارتباط با پارسی‌مپ Timeout شد.');
    }
    return MapServiceException(
      'خطا در ارتباط با پارسی‌مپ${code == null ? '' : ' (' + code.toString() + ')'}.',
    );
  }
}
