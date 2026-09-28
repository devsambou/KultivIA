// Contrôleur pour l'écran de setup. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../repositories/diagnosis_repository.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';

class SetupController extends ChangeNotifier {
  SetupController({
    required AppState appState,
    required FirebaseService firebaseService,
    required NotificationService notificationService,
    required DiagnosisRepository diagnosisRepository,
  });

  int get step => throw UnimplementedError();
  int get stepCount => throw UnimplementedError();
  String get role => throw UnimplementedError();
  String get language => throw UnimplementedError();
  bool get notifications => throw UnimplementedError();
  bool get voiceReplies => throw UnimplementedError();
  bool get saving => throw UnimplementedError();
  bool get editing => throw UnimplementedError();
  TextEditingController get nameController => throw UnimplementedError();
  TextEditingController get localityController => throw UnimplementedError();
  Set<String> get crops => throw UnimplementedError();
  List<String> get cropOptions => throw UnimplementedError();

  void goTo(int step) {
    throw UnimplementedError();
  }

  void next(BuildContext context) {
    throw UnimplementedError();
  }

  Future<void> finish(BuildContext context) async {
    throw UnimplementedError();
  }

  void setRole(String role) {
    throw UnimplementedError();
  }

  void setLanguage(String language) {
    throw UnimplementedError();
  }

  void setVoiceReplies(bool value) {
    throw UnimplementedError();
  }

  void setNotifications(bool value) {
    throw UnimplementedError();
  }

  void toggleCrop(String crop) {
    throw UnimplementedError();
  }

  void previous() {
    throw UnimplementedError();
  }
}