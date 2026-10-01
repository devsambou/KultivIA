// État global de l'app. Issue GitHub : #TODO
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/diagnosis.dart';
import '../../models/user_profile.dart';
import 'user_settings.dart';
import '../data/diagnosis_history.dart';

/// État global de l'app : délègue à [UserSettings] et [DiagnosisHistory]
/// pour éviter les rebuilds en cascade.
class AppState extends ChangeNotifier {
  final UserSettings settings;
  final DiagnosisHistory history;
  UserProfile? profile;

  AppState({
    required this.settings,
    required this.history,
  });

  String get languageCode => settings.languageCode;
  bool get voiceReplies => settings.voiceReplies;

  /// Change la langue de l'interface et de l'avatar, et la persiste dans le profil
  /// si un profil est chargé.
  void setLanguage(String code) {
    if (settings.languageCode == code) return;

    settings.setLanguage(code);
    final p = profile;
    if (p != null && p.languageCode != code) {
      profile = p.copyWith(languageCode: code);
    }
    notifyListeners();
  }

  void setVoiceReplies(bool on) {
    settings.setVoiceReplies(on);
    final p = profile;
    if (p != null && p.voiceReplies != on) {
      profile = p.copyWith(voiceReplies: on);
    }
    notifyListeners();
  }

  void setProfile(UserProfile p) {
    profile = p;
    settings.applyFromProfile(p);
    notifyListeners();
  }

  List<Diagnosis> get historyList => history.history;

  void addDiagnosis(Diagnosis d) {
    history.addDiagnosis(d);
    notifyListeners();
  }

  void bindHistory() {
    history.bindHistory();
    notifyListeners();
  }

  Future<void> clear() async {
    profile = null;
    history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    settings.dispose();
    history.dispose();
    super.dispose();
  }
}