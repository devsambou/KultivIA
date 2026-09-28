import 'dart:async';
import 'package:flutter/material.dart';
import '../models/diagnosis.dart';
import '../models/user_profile.dart';
import 'user_settings.dart';
import 'diagnosis_history.dart';

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

  // --- Delegation vers UserSettings ---

  String get languageCode => settings.languageCode;
  bool get voiceReplies => settings.voiceReplies;

  void setLanguage(String code) => settings.setLanguage(code);
  void setVoiceReplies(bool on) => settings.setVoiceReplies(on);

  // --- Profil utilisateur ---

  void setProfile(UserProfile p) {
    profile = p;
    settings.applyFromProfile(p);
    notifyListeners();
  }

  // --- Delegation vers DiagnosisHistory ---

  List<Diagnosis> get historyList => history.history;

  void addDiagnosis(Diagnosis d) => history.addDiagnosis(d);

  /// Synchronise l'historique avec le repository (appelé au login).
  void bindHistory() => history.bindHistory();

  /// À appeler à la déconnexion.
  Future<void> clear() async {
    history.clear();
    profile = null;
    settings
      ..setLanguage('fr')
      ..setVoiceReplies(false);
    notifyListeners();
  }

  @override
  void dispose() {
    settings.dispose();
    history.dispose();
    super.dispose();
  }
}
