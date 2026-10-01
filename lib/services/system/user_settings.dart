// RÃƒÂ©glages utilisateur. Issue GitHub : #TODO
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../languages/registry.dart';

/// RÃƒÂ©glages utilisateur qui changent rarement (langue, voix).
class UserSettings extends ChangeNotifier {
  static Map<String, String> get supportedLanguages => {
        for (final pack in languagePacks) pack.code: pack.name,
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
