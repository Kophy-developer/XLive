class ApiConfig {
  const ApiConfig({
    this.authBaseUrl = 'https://creative.flowfly.dev/dev',
    this.apiBaseUrl = 'https://store-x-live.4tqepo.easypanel.host',
    this.cloudinaryCloudName = 'dlfzn6m9q',
    this.giphyApiKey = 'UQsln13lcUzYUqvYeRUmj8BdLvFgPRl2',
  });

  final String authBaseUrl;
  final String apiBaseUrl;
  final String cloudinaryCloudName;
  final String giphyApiKey;

  static const ApiConfig staging = ApiConfig();
}
