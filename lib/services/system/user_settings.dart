// Réglages utilisateur. Issue GitHub : #TODO
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../languages/registry.dart';

/// Réglages utilisateur qui changent rarement (langue, voix).
class UserSettings extends ChangeNotifier {
  static Map<String, String> get supportedLanguages => {
        for (final pack in languagePacks) pack.code: pack.name,
      };

  String _languageCode = 'fr';
  bool _voiceReplies = false;

  String get languageCode => _languageCode;
  bool get voiceReplies => _voiceReplies;

  /// Change la langue de l'interface et de l'avatar.
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

  /// Applique les settings depuis le profil chargé (inscription / profil).
  void applyFromProfile(UserProfile profile) {
    _languageCode = profile.languageCode;
    _voiceReplies = profile.voiceReplies;
    notifyListeners();
  }

  /// Exporte les settings pour les persister dans users/{uid}.
  Map<String, dynamic> toProfileMap() => {
        'languageCode': _languageCode,
        'voiceReplies': _voiceReplies,
      };
}
