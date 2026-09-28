import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// Réglages utilisateur qui changent rarement (langue, voix).
/// Séparé de [AppState] pour éviter les rebuilds en cascade.
class UserSettings extends ChangeNotifier {
  static const supportedLanguages = <String, String>{
    'fr': 'Français',
    'en': 'English',
    'wo': 'Wolof',
    // 'bm': 'Bambara',
    // 'ln': 'Lingala',
  };

  String _languageCode = 'fr';
  bool _voiceReplies = false;

  String get languageCode => _languageCode;
  bool get voiceReplies => _voiceReplies;

  void setLanguage(String code) {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
  }

  void setVoiceReplies(bool on) {
    if (_voiceReplies == on) return;
    _voiceReplies = on;
    notifyListeners();
  }

  /// Applique les réglages depuis un profil (ex: au login).
  void applyFromProfile(UserProfile profile) {
    bool changed = false;
    if (supportedLanguages.containsKey(profile.languageCode)) {
      _languageCode = profile.languageCode;
      changed = true;
    }
    if (_voiceReplies != profile.voiceReplies) {
      _voiceReplies = profile.voiceReplies;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Retourne une copie des réglages pour persistance (profil Firestore).
  Map<String, dynamic> toProfileMap() => {
        'languageCode': _languageCode,
        'voiceReplies': _voiceReplies,
      };
}