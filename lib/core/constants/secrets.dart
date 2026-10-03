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
