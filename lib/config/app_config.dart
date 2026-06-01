class AppConfig {
  // Lê a variável injetada no build.
  // Se não encontrar, retorna string vazia (app não trava, mas IA falha graciosamente).
  static const String cloudVisionApiKey = String.fromEnvironment(
    'CLOUD_VISION_API_KEY',
    defaultValue: '',
  );
}
