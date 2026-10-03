/// Compile-time API configuration for RAHI.
///
/// This file is intentionally tracked in Git because it contains no secret
/// values. Real values are injected at build time with --dart-define.
///
/// Without dart-defines the values remain empty. Provider implementations
/// must surface a controlled "not configured" error instead of inventing data.
class Secrets {
  Secrets._();

  static const String neshanApiKey = String.fromEnvironment(
    'NESHAN_API_KEY',
    defaultValue: '',
  );

  static const String parsimapServiceToken = String.fromEnvironment(
    'PARSIMAP_SERVICE_TOKEN',
    defaultValue: '',
  );

  static const String parsimapMapToken = String.fromEnvironment(
    'PARSIMAP_MAP_TOKEN',
    defaultValue: '',
  );

  static bool get hasNeshanKey => neshanApiKey.isNotEmpty;

  static bool get hasParsimapKeys =>
      parsimapServiceToken.isNotEmpty && parsimapMapToken.isNotEmpty;
}
