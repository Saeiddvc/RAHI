import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/secrets.dart';
import '../../core/services/map_service.dart';
import '../models/map_route.dart';
import '../models/place.dart';

class NeshanApi implements MapService {
  final Dio _dio;

  NeshanApi([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.neshanBaseUrl,
                headers: {
                  'Api-Key': Secrets.neshanApiKey,
                  'Content-Type': 'application/json',
                },
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  @override
  Set<RouteType> get supportedRouteTypes =>
      const {RouteType.car, RouteType.motorcycle};

  @override
  Future<List<Place>> search({
    required String term,
    required LatLng center,
  }) async {
    _requireApiKey();
    final normalizedTerm = term.trim();
    if (normalizedTerm.isEmpty) return const [];

    try {
      final query = jsonEncode({
        'term': normalizedTerm,
        'center': {
          'latitude': center.latitude,
          'longitude': center.longitude,
        },
      });

      final response = await _dio.get(
        AppConstants.neshanSearchPath,
        queryParameters: {'q': query},
      );

      final data = _asMap(response.data);
      final items = data['items'];
      if (items is! List) return const [];

      return items
          .whereType<Map>()
          .map((item) => Place.fromNeshanJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  @override
  Future<String?> reverse(LatLng point) async {
    _requireApiKey();
    try {
      final response = await _dio.get(
        AppConstants.neshanReversePath,
        queryParameters: {
          'lat': point.latitude,
          'lng': point.longitude,
        },
      );

      final data = _asMap(response.data);
      return data['formatted_address']?.toString();
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  @override
  Future<List<MapRoute>> direction({
    required LatLng origin,
    required LatLng destination,
    required RouteType type,
  }) async {
    _requireApiKey();

    if (!supportedRouteTypes.contains(type)) {
      throw MapServiceException(
        'نوع مسیر ${type.name} توسط سرویس مسیریابی ترافیکی نشان پشتیبانی نمی‌شود.',
      );
    }

    try {
      final response = await _dio.get(
        AppConstants.neshanDirectionPath,
        queryParameters: {
          'type': type.apiValue,
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'alternative': true,
        },
      );

      final data = _asMap(response.data);
      final routes = data['routes'];
      if (routes is! List) return const [];

      final result = <MapRoute>[];
      for (final rawRoute in routes.whereType<Map>()) {
        final route = Map<String, dynamic>.from(rawRoute);
        final legs = route['legs'];
        if (legs is! List || legs.isEmpty || legs.first is! Map) continue;

        final leg = Map<String, dynamic>.from(legs.first as Map);
        final overview = route['overview_polyline'];
        final overviewMap =
            overview is Map ? Map<String, dynamic>.from(overview) : const <String, dynamic>{};
        final encoded = overviewMap['points']?.toString() ?? '';

        final distance = leg['distance'];
        final duration = leg['duration'];
        final distanceMap =
            distance is Map ? Map<String, dynamic>.from(distance) : const <String, dynamic>{};
        final durationMap =
            duration is Map ? Map<String, dynamic>.from(duration) : const <String, dynamic>{};

        result.add(
          MapRoute(
            points: _decodePolyline(encoded),
            distanceMeters:
                (distanceMap['value'] as num?)?.toDouble() ?? 0,
            durationSeconds:
                (durationMap['value'] as num?)?.round() ?? 0,
            summary: leg['summary']?.toString(),
          ),
        );
      }

      return result;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  @override
  String get tileUrlTemplate => AppConstants.osmTileUrl;

  @override
  Map<String, String> get tileUrlParams => const {};

  void _requireApiKey() {
    if (Secrets.neshanApiKey.isEmpty) {
      throw const MapServiceException(
        'NESHAN_API_KEY برای این Build تنظیم نشده است.',
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
    if (code == 480 || code == 401) {
      return const MapServiceException('کلید API نشان نامعتبر است.');
    }
    if (code == 481 || code == 482) {
      return const MapServiceException('سقف یا نرخ مجاز درخواست‌های نشان رد شده است.');
    }
    if (code == 483 || code == 484 || code == 485) {
      return const MapServiceException('مجوز کلید نشان برای این سرویس معتبر نیست.');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const MapServiceException('ارتباط با نشان Timeout شد.');
    }
    final suffix = code == null ? '' : ' ($code)';
    return MapServiceException('خطا در ارتباط با نشان$suffix.');
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return const [];

    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;

      do {
        if (index >= encoded.length) return points;
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        if (index >= encoded.length) return points;
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }

    return points;
  }
}
