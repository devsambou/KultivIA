// Réglages utilisateur. Issue GitHub : #TODO
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../languages/registry.dart';

/// Réglages utilisateur qui changent rarement (langue UI, langue IA, voix, thème).
class UserSettings extends ChangeNotifier {
  static Map<String, String> get supportedLanguages => {
        for (final pack in languagePacks) pack.code: pack.name,
      };

  String _languageCode = 'fr';
  String _aiLanguageCode = 'fr';
  bool _voiceReplies = false;
  ThemeMode _themeMode = ThemeMode.system;

  String get languageCode => _languageCode;
  String get aiLanguageCode => _aiLanguageCode;
  bool get voiceReplies => _voiceReplies;
  ThemeMode get themeMode => _themeMode;

  /// Change la langue de l'interface.
  void setLanguage(String code) {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
  }

  /// Change la langue de discussion avec l'IA.
  void setAiLanguage(String code) {
    if (_aiLanguageCode == code) return;
    _aiLanguageCode = code;
    notifyListeners();
  }

  void setVoiceReplies(bool on) {
    if (_voiceReplies == on) return;
    _voiceReplies = on;
    notifyListeners();
  }

  /// Change le mode de thème (clair, sombre, système).
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  /// Applique les settings depuis le profil chargé (inscription / profil).
  void applyFromProfile(UserProfile profile) {
    _languageCode = profile.languageCode;
    _aiLanguageCode = profile.aiLanguageCode;
    _voiceReplies = profile.voiceReplies;
    _themeMode = profile.themeMode;
    notifyListeners();
  }

  /// Exporte les settings pour les persister dans users/{uid}.
  Map<String, dynamic> toProfileMap() => {
        'languageCode': _languageCode,
        'aiLanguageCode': _aiLanguageCode,
        'voiceReplies': _voiceReplies,
        'themeMode': _themeMode.index,
      };
}
