import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration de l'application.
class AppConfig {
  AppConfig._();

  static bool get enableDebugMode => dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = true;
  
  static const String defaultLanguage = 'fr';
  static const List<String> supportedLanguages = ['fr', 'en'];
  
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static String get providerPriority => dotenv.env['PROVIDER_PRIORITY'] ?? 'supabase,firebase';
  static String get activeProviders => dotenv.env['ACTIVE_PROVIDERS'] ?? 'supabase,firebase';
  static bool get simultaneousWrites => dotenv.env['SIMULTANEOUS_WRITES']?.toLowerCase() == 'true';
}
