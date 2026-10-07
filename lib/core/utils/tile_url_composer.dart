class TileUrlComposer {
  TileUrlComposer._();

  static String compose(
    String template,
    Map<String, String> params,
  ) {
    if (template.isEmpty || params.isEmpty) return template;

    final existingNames = <String>{};
    final question = template.indexOf('?');

    if (question >= 0 && question + 1 < template.length) {
      final query = template.substring(question + 1);
      for (final part in query.split('&')) {
        if (part.isEmpty) continue;
        final equals = part.indexOf('=');
        final rawName = equals < 0 ? part : part.substring(0, equals);
        try {
          existingNames.add(
            Uri.decodeQueryComponent(rawName).toLowerCase(),
          );
        } catch (_) {
          existingNames.add(rawName.toLowerCase());
        }
      }
    }

    final encoded = params.entries
        .where(
          (entry) =>
              !existingNames.contains(entry.key.toLowerCase()),
        )
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    if (encoded.isEmpty) return template;
    return '$template${template.contains('?') ? '&' : '?'}$encoded';
  }
}
