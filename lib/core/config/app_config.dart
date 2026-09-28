/// Configuration de l'application.
class AppConfig {
  AppConfig._();

  static const bool enableDebugMode = true;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = true;
  
  static const String defaultLanguage = 'fr';
  static const List<String> supportedLanguages = ['fr', 'en'];
}
