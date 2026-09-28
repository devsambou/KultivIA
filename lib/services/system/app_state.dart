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

  void setLanguage(String code) {
    throw UnimplementedError();
  }

  void setVoiceReplies(bool on) {
    throw UnimplementedError();
  }

  void setProfile(UserProfile p) {
    throw UnimplementedError();
  }

  List<Diagnosis> get historyList => history.history;

  void addDiagnosis(Diagnosis d) {
    throw UnimplementedError();
  }

  void bindHistory() {
    throw UnimplementedError();
  }

  Future<void> clear() {
    throw UnimplementedError();
  }

  @override
  void dispose() {
    throw UnimplementedError();
  }
}
