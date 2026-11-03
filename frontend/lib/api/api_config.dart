/// How the app reaches the API, from `--dart-define`s.
class ApiConfig {
  const ApiConfig({required this.baseUrl, this.mode = ApiMode.live});

  /// Reads `API_BASE_URL` and `API_MODE` (`live` or `mock`).
  factory ApiConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      // Override with --dart-define=API_BASE_URL=... for local development.
      defaultValue: 'https://unirent.siddharths.me',
    );
    const mode = String.fromEnvironment('API_MODE', defaultValue: 'live');
    return const ApiConfig(
      baseUrl: baseUrl,
      mode: mode == 'mock' ? ApiMode.mock : ApiMode.live,
    );
  }

  final String baseUrl;
  final ApiMode mode;
}

enum ApiMode {
  /// Real HTTP requests to [ApiConfig.baseUrl].
  live,

  /// Answered in-process from fixtures; no network.
  mock,
}
