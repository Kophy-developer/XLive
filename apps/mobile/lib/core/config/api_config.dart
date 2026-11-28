class ApiConfig {
  const ApiConfig({
    this.authBaseUrl = 'https://creative.flowfly.dev/dev',
    // Override per build: flutter run --dart-define=XLIVE_API_BASE_URL=http://10.0.2.2:8080
    // Auth now uses `$apiBaseUrl/api/x-live/auth/*` (see AuthRepository).
    this.apiBaseUrl = const String.fromEnvironment(
      'XLIVE_API_BASE_URL',
      defaultValue: 'https://xlive-app-bcqre.ondigitalocean.app',
    ),
    this.webAppBaseUrl = 'https://www.xlive.ng',
    this.cloudinaryCloudName = 'dlfzn6m9q',
    this.giphyApiKey = 'UQsln13lcUzYUqvYeRUmj8BdLvFgPRl2',
  });

  final String authBaseUrl;
  final String apiBaseUrl;
  final String webAppBaseUrl;
  final String cloudinaryCloudName;
  final String giphyApiKey;

  static const ApiConfig staging = ApiConfig();
}
