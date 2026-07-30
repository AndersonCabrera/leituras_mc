class AppConfig {
  static const String cloudVisionApiKey = String.fromEnvironment(
    'CLOUD_VISION_API_KEY',
    defaultValue: '',
  );

  static const String vercelApiUrl =
      String.fromEnvironment('VERCEL_API_URL', defaultValue: 'https://leituras-mc.vercel.app/api');
}
