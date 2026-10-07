import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_constants.dart';
import '../constants/secrets.dart';
import '../services/parsimap_tile_resolver.dart';
import '../utils/tile_url_composer.dart';

class TileProbeResult {
  final String label;
  final String host;
  final bool dnsOk;
  final int? statusCode;
  final String? contentType;
  final int? byteLength;
  final int elapsedMs;
  final String? error;

  const TileProbeResult({
    required this.label,
    required this.host,
    required this.dnsOk,
    required this.statusCode,
    required this.contentType,
    required this.byteLength,
    required this.elapsedMs,
    required this.error,
  });

  String get compactSummary {
    if (error != null) {
      return '$label: DNS ${dnsOk ? "OK" : "FAIL"} | ERR ${_short(error!)}';
    }

    final type = contentType == null || contentType!.isEmpty
        ? '-'
        : contentType!.split(';').first;
    final bytes = byteLength == null ? '-' : '${byteLength! ~/ 1024}KB';
    return '$label: DNS ${dnsOk ? "OK" : "FAIL"} | '
        'HTTP ${statusCode ?? "-"} | $type | $bytes | ${elapsedMs}ms';
  }

  static String _short(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 44) return normalized;
    return '${normalized.substring(0, 44)}…';
  }
}

class TileDiagnosticsReport {
  final bool usingFallback;
  final String activeHost;
  final TileProbeResult style;
  final TileProbeResult parsimapTile;
  final TileProbeResult osmTile;
  final TileProbeResult activeTile;

  const TileDiagnosticsReport({
    required this.usingFallback,
    required this.activeHost,
    required this.style,
    required this.parsimapTile,
    required this.osmTile,
    required this.activeTile,
  });

  List<String> get lines => [
        'mode: ${usingFallback ? "OSM FALLBACK" : "RESOLVED TILE"}',
        'active host: $activeHost',
        style.compactSummary,
        parsimapTile.compactSummary,
        osmTile.compactSummary,
        activeTile.compactSummary,
      ];
}

class TileDiagnostics {
  TileDiagnostics._();

  static const LatLng _probeCenter = LatLng(
    AppConstants.defaultLat,
    AppConstants.defaultLng,
  );
  static const int _probeZoom = 13;
  static const Duration _timeout = Duration(seconds: 5);

  static Future<TileDiagnosticsReport> run({
    required String activeUrlTemplate,
    required bool usingFallback,
  }) async {
    // Start independent probes together so a bad host does not make the
    // debug overlay wait through several sequential timeout windows.
    final styleFuture = _probeParsimapStyle();
    final osmFuture = _probeTile(
      'osm',
      AppConstants.osmTileUrl,
    );
    final activeFuture = _probeTile(
      'active',
      activeUrlTemplate,
    );

    final styleOutcome = await styleFuture;

    String? resolvedParsimapTemplate;
    if (styleOutcome.responseData != null) {
      resolvedParsimapTemplate =
          ParsimapTileResolver.extractTileTemplate(
        styleOutcome.responseData,
      );
    }

    final parsimapUrl = resolvedParsimapTemplate ?? '';

    final parsimapFuture = parsimapUrl.isEmpty
        ? Future<TileProbeResult>.value(
            const TileProbeResult(
              label: 'parsi tile',
              host: '-',
              dnsOk: false,
              statusCode: null,
              contentType: null,
              byteLength: null,
              elapsedMs: 0,
              error: 'no template from style',
            ),
          )
        : _probeTile('parsi tile', parsimapUrl);

    final osmTile = await osmFuture;
    final activeTile = await activeFuture;
    final parsimapTile = await parsimapFuture;

    return TileDiagnosticsReport(
      usingFallback: usingFallback,
      activeHost: _hostOf(activeUrlTemplate),
      style: styleOutcome.result,
      parsimapTile: parsimapTile,
      osmTile: osmTile,
      activeTile: activeTile,
    );
  }

  static Future<_StyleProbeOutcome> _probeParsimapStyle() async {
    if (Secrets.parsimapMapToken.isEmpty) {
      return const _StyleProbeOutcome(
        result: TileProbeResult(
          label: 'style',
          host: 'api.parsimap.ir',
          dnsOk: false,
          statusCode: null,
          contentType: null,
          byteLength: null,
          elapsedMs: 0,
          error: 'map token missing',
        ),
        responseData: null,
      );
    }

    final url = TileUrlComposer.compose(
      '${AppConstants.parsimapBaseUrl}'
      '${AppConstants.parsimapRasterStylePath}',
      {'key': Secrets.parsimapMapToken},
    );

    final probe = await _probe(
      label: 'style',
      url: url,
      responseType: ResponseType.json,
    );

    return _StyleProbeOutcome(
      result: probe.result,
      responseData: probe.responseData,
    );
  }

  static Future<TileProbeResult> _probeTile(
    String label,
    String template,
  ) async {
    if (template.isEmpty) {
      return TileProbeResult(
        label: label,
        host: '-',
        dnsOk: false,
        statusCode: null,
        contentType: null,
        byteLength: null,
        elapsedMs: 0,
        error: 'empty template',
      );
    }

    final sample = sampleTileUrl(
      template,
      center: _probeCenter,
      zoom: _probeZoom,
    );

    final probe = await _probe(
      label: label,
      url: sample,
      responseType: ResponseType.bytes,
    );
    return probe.result;
  }

  static Future<_ProbeOutcome> _probe({
    required String label,
    required String url,
    required ResponseType responseType,
  }) async {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';

    if (uri == null || !uri.hasScheme || host.isEmpty) {
      return _ProbeOutcome(
        result: TileProbeResult(
          label: label,
          host: host.isEmpty ? '-' : host,
          dnsOk: false,
          statusCode: null,
          contentType: null,
          byteLength: null,
          elapsedMs: 0,
          error: 'invalid URL',
        ),
        responseData: null,
      );
    }

    var dnsOk = false;
    final watch = Stopwatch()..start();

    try {
      final addresses = await InternetAddress.lookup(host).timeout(_timeout);
      dnsOk = addresses.isNotEmpty;

      final dio = Dio(
        BaseOptions(
          connectTimeout: _timeout,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          headers: {'User-Agent': AppConstants.userAgent},
          validateStatus: (_) => true,
        ),
      );

      final response = await dio.getUri<dynamic>(
        uri,
        options: Options(responseType: responseType),
      );

      watch.stop();

      return _ProbeOutcome(
        result: TileProbeResult(
          label: label,
          host: host,
          dnsOk: dnsOk,
          statusCode: response.statusCode,
          contentType: response.headers.value(Headers.contentTypeHeader),
          byteLength: _bodyLength(response.data),
          elapsedMs: watch.elapsedMilliseconds,
          error: null,
        ),
        responseData: response.data,
      );
    } catch (error) {
      watch.stop();
      return _ProbeOutcome(
        result: TileProbeResult(
          label: label,
          host: host,
          dnsOk: dnsOk,
          statusCode: null,
          contentType: null,
          byteLength: null,
          elapsedMs: watch.elapsedMilliseconds,
          error: error.runtimeType.toString(),
        ),
        responseData: null,
      );
    }
  }

  static int? _bodyLength(dynamic data) {
    if (data is List<int>) return data.length;
    if (data is String) return data.length;
    if (data is Map || data is List) {
      return data.toString().length;
    }
    return null;
  }

  static String _hostOf(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return '-';
    return uri.host;
  }

  static String sampleTileUrl(
    String template, {
    required LatLng center,
    required int zoom,
  }) {
    final lat = center.latitude.clamp(-85.05112878, 85.05112878);
    final n = math.pow(2.0, zoom).toDouble();
    final x = ((center.longitude + 180.0) / 360.0 * n).floor();

    final latRad = lat * math.pi / 180.0;
    final y = ((1.0 -
                math.log(
                      math.tan(latRad) + 1 / math.cos(latRad),
                    ) /
                    math.pi) /
            2.0 *
            n)
        .floor();

    return template
        .replaceAll('{z}', zoom.toString())
        .replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString())
        .replaceAll('{s}', 'a')
        .replaceAll('{r}', '');
  }
}

class _ProbeOutcome {
  final TileProbeResult result;
  final dynamic responseData;

  const _ProbeOutcome({
    required this.result,
    required this.responseData,
  });
}

class _StyleProbeOutcome {
  final TileProbeResult result;
  final dynamic responseData;

  const _StyleProbeOutcome({
    required this.result,
    required this.responseData,
  });
}
