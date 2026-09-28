import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/system/app_state.dart';
import '../services/auth/firebase_service.dart';
import '../services/system/notification_service.dart';
import '../repositories/diagnosis_repository.dart';
import 'setup/setup_controller.dart';
import 'setup/step_identity.dart';
import 'setup/step_exploitation.dart';
import 'setup/step_preferences.dart';
import 'setup/setup_bottom_bar.dart';

/// Paramétrage de la première connexion, en 3 étapes :
///   1. Qui êtes-vous ? (nom, profil)
///   2. Votre exploitation (localité, cultures)
///   3. Préférences (langue, notifications)
/// Aussi utilisé depuis Profil → « Modifier mon profil » (mode édition).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onStepChanged(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Le controller est fourni par le provider dans main.dart
    final controller = context.watch<SetupController>();

    // Synchroniser le PageController avec l'état du controller
    if (controller.step != _pageController.page?.round()) {
      _onStepChanged(controller.step);
    }

    final isLast = controller.step == controller.stepCount - 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: controller.editing,
        title: Text('Étape ${controller.step + 1} sur ${controller.stepCount}', style: const TextStyle(fontSize: 14)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                value: (controller.step + 1) / controller.stepCount,
                minHeight: 6,
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                StepIdentity(),
                StepExploitation(),
                StepPreferences(),
              ],
            ),
          ),
          const SetupBottomBar(),
        ],
      ),
    );
  }
}
