import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../constants/secrets.dart';
import '../utils/api_call.dart';

/// Resolves Parsimap's actual raster XYZ template from its Style API.
///
/// The style response is the source of truth. The sanitized template is cached
/// only in memory because returned URLs may contain credential-like query
/// parameters.
class ParsimapTileResolver {
  ParsimapTileResolver([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.parsimapBaseUrl,
                connectTimeout: ApiCall.defaultTimeout,
                sendTimeout: ApiCall.defaultTimeout,
                receiveTimeout: ApiCall.defaultTimeout,
              ),
            );

  final Dio _dio;

  static const Duration _ttl = Duration(hours: 24);

  String? _cachedTemplate;
  DateTime? _cachedAt;

  Future<String?> resolve() async {
    final cached = _cachedTemplate;
    final cachedAt = _cachedAt;

    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _ttl) {
      return cached;
    }

    if (Secrets.parsimapMapToken.isEmpty) {
      return null;
    }

    try {
      final response = await ApiCall.withResilience<Response<dynamic>>(
        call: () => _dio.get(
          AppConstants.parsimapRasterStylePath,
          queryParameters: {'key': Secrets.parsimapMapToken},
        ),
      );

      final template = extractTileTemplate(response.data);
      if (template == null || template.isEmpty) {
        return null;
      }

      _cachedTemplate = template;
      _cachedAt = DateTime.now();
      return template;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? extractTileTemplate(dynamic raw) {
    if (raw is! Map) return null;

    final sources = raw['sources'];
    if (sources is! Map) return null;

    dynamic target = sources['composite'];

    if (target is! Map || target['tiles'] is! List) {
      target = null;
      for (final value in sources.values) {
        if (value is Map &&
            value['tiles'] is List &&
            (value['tiles'] as List).isNotEmpty) {
          target = value;
          break;
        }
      }
    }

    if (target is! Map) return null;

    final tiles = target['tiles'];
    if (tiles is! List || tiles.isEmpty) return null;

    final first = tiles.first;
    if (first is! String || first.trim().isEmpty) return null;

    return _stripKeyQueryParameter(first.trim());
  }

  static String _stripKeyQueryParameter(String template) {
    final question = template.indexOf('?');
    if (question < 0) return template;

    final base = template.substring(0, question);
    final query = template.substring(question + 1);

    final kept = <String>[];
    for (final part in query.split('&')) {
      if (part.isEmpty) continue;

      final equals = part.indexOf('=');
      final rawName = equals < 0 ? part : part.substring(0, equals);

      String name;
      try {
        name = Uri.decodeQueryComponent(rawName).toLowerCase();
      } catch (_) {
        name = rawName.toLowerCase();
      }

      if (name == 'key') continue;
      kept.add(part);
    }

    if (kept.isEmpty) return base;
    return '$base?${kept.join('&')}';
  }
}
