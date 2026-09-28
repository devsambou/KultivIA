// Réglages utilisateur. Issue GitHub : #TODO
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';

/// Réglages utilisateur qui changent rarement (langue, voix).
class UserSettings extends ChangeNotifier {
  static const supportedLanguages = <String, String>{
    'fr': 'Français',
    'en': 'English',
    'wo': 'Wolof',
  };

  String _languageCode = 'fr';
  bool _voiceReplies = false;

  String get languageCode => _languageCode;
  bool get voiceReplies => _voiceReplies;

  void setLanguage(String code) {
    throw UnimplementedError();
  }

  void setVoiceReplies(bool on) {
    throw UnimplementedError();
  }

  void applyFromProfile(UserProfile profile) {
    throw UnimplementedError();
  }

  Map<String, dynamic> toProfileMap() {
    throw UnimplementedError();
  }
}