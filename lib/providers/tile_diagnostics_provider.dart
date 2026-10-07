import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/tile_diagnostics.dart';

class TileDiagnosticsRequest {
  final String activeUrlTemplate;
  final bool usingFallback;

  const TileDiagnosticsRequest({
    required this.activeUrlTemplate,
    required this.usingFallback,
  });

  @override
  bool operator ==(Object other) {
    return other is TileDiagnosticsRequest &&
        other.activeUrlTemplate == activeUrlTemplate &&
        other.usingFallback == usingFallback;
  }

  @override
  int get hashCode => Object.hash(activeUrlTemplate, usingFallback);
}

final tileDiagnosticsProvider = FutureProvider.autoDispose
    .family<TileDiagnosticsReport, TileDiagnosticsRequest>(
  (ref, request) {
    return TileDiagnostics.run(
      activeUrlTemplate: request.activeUrlTemplate,
      usingFallback: request.usingFallback,
    );
  },
);
