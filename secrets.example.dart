// Non-secret template used by local development and CI.
// Copy this file to lib/core/constants/secrets.dart when working locally.

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
}
