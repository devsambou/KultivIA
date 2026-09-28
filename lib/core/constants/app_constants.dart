/// Constantes globales de l'application KultivIA.
class AppConstants {
  AppConstants._();

  static const String appName = 'KultivIA';
  static const String appVersion = '1.0.0';
  
  // Durées et timeouts
  static const int defaultTimeout = 30000; // 30 secondes
  static const int animationDuration = 300; // ms
  
  // Limites
  static const int maxRetryAttempts = 3;
  static const int maxMessageLength = 1000;
}
