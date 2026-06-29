class BackendConfig {
  static const String _rawBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue:
        'https://camel-pharmaceutical-reservation-desktops.trycloudflare.com',
  );

  static String get baseUrl => _rawBaseUrl.replaceFirst(RegExp(r'/+$'), '');

  static String get apiBaseUrl => '$baseUrl/api';

  static Uri uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters,
    );
  }

  static Uri apiUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return uri('/api$normalizedPath', queryParameters: queryParameters);
  }
}
