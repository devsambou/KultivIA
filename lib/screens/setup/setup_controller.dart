import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../repositories/diagnosis_repository.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';
import '../../services/ui/voice_service.dart';

/// Contrôleur pour l'écran de paramétrage (SetupScreen).
/// Gère l'état du formulaire, la validation et la persistance.
class SetupController extends ChangeNotifier {
  static const _cropOptions = [
    'Mil', 'Maïs', 'Riz', 'Arachide', 'Niébé', 'Sorgho', 'Tomate', 'Oignon', 'Manioc', 'Pastèque',
  ];
  static const _stepCount = 3;

  final AppState _appState;
  final FirebaseService _firebaseService;
  final NotificationService _notificationService;
  final DiagnosisRepository _diagnosisRepository;

  final _nameController = TextEditingController();
  final _localityController = TextEditingController();
  final _crops = <String>{};

  int _step = 0;
  String _role = 'farmer';
  String _language = 'fr';
  bool _notifications = true;
  bool _voiceReplies = false;
  bool _saving = false;
  late final bool _editing;

  SetupController({
    required AppState appState,
    required FirebaseService firebaseService,
    required NotificationService notificationService,
    required DiagnosisRepository diagnosisRepository,
  })  : _appState = appState,
        _firebaseService = firebaseService,
        _notificationService = notificationService,
        _diagnosisRepository = diagnosisRepository {
    _initialize();
  }

  // Getters
  int get step => _step;
  int get stepCount => _stepCount;
  String get role => _role;
  String get language => _language;
  bool get notifications => _notifications;
  bool get voiceReplies => _voiceReplies;
  bool get saving => _saving;
  bool get editing => _editing;
  TextEditingController get nameController => _nameController;
  TextEditingController get localityController => _localityController;
  Set<String> get crops => _crops;
  List<String> get cropOptions => _cropOptions;

  void _initialize() {
    final profile = _appState.profile;
    _editing = profile?.completed ?? false;
    _language = _appState.languageCode;
    if (profile != null) {
      _nameController.text = profile.displayName;
      _role = profile.role;
      _localityController.text = profile.locality;
      _crops.addAll(profile.crops);
      _notifications = profile.notificationsEnabled;
      _voiceReplies = profile.voiceReplies;
    } else {
      // Google/Apple fournissent souvent le nom : on le préremplit.
      _nameController.text = _firebaseService.currentUser?.displayName ?? '';
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void goTo(int step) {
    if (step < 0 || step >= _stepCount) return;
    _step = step;
    notifyListeners();
  }

  void next(BuildContext context) {
    if (_step == 0 && _nameController.text.trim().length < 2) {
      _toast(context, 'Indiquez votre nom pour continuer.');
      return;
    }
    if (_step < _stepCount - 1) {
      goTo(_step + 1);
    } else {
      finish(context);
    }
  }

  Future<void> finish(BuildContext context) async {
    if (_saving) return;
    _saving = true;
    notifyListeners();

    try {
      var notificationsOn = false;
      if (_notifications && _firebaseService.isReady) {
        final uid = _firebaseService.currentUser?.uid;
        if (uid != null) notificationsOn = await _notificationService.enable(uid);
      }

      final profile = UserProfile(
        displayName: _nameController.text.trim(),
        role: _role,
        locality: _localityController.text.trim(),
        crops: _crops.toList()..sort(),
        languageCode: _language,
        notificationsEnabled: notificationsOn,
        voiceReplies: _voiceReplies,
        completed: true,
      );

      await _firebaseService.saveProfile(profile);
      _appState.setProfile(profile);

      if (!context.mounted) return;

      if (_editing) {
        Navigator.of(context).pop();
      } else {
        _appState.bindHistory();
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    } catch (e) {
      debugPrint('Enregistrement du profil impossible : $e');
      if (context.mounted) {
        _toast(context, "Impossible d'enregistrer votre profil. Vérifiez votre connexion et réessayez.");
      }
    } finally {
      if (context.mounted) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  void setRole(String role) {
    _role = role;
    notifyListeners();
  }

  void setLanguage(String language) {
    _language = language;
    notifyListeners();
  }

  void setVoiceReplies(bool value) {
    _voiceReplies = value;
    notifyListeners();
  }

  void setNotifications(bool value) {
    _notifications = value;
    notifyListeners();
  }

  void toggleCrop(String crop) {
    if (_crops.contains(crop)) {
      _crops.remove(crop);
    } else {
      _crops.add(crop);
    }
    notifyListeners();
  }

  void previous() {
    if (_step > 0) {
      goTo(_step - 1);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _localityController.dispose();
    super.dispose();
  }
}