// Écran de paramétrage (setup). Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';
import '../../repositories/diagnosis_repository.dart';
import 'setup_controller.dart';
import 'step_identity.dart';
import 'step_exploitation.dart';
import 'step_preferences.dart';
import 'setup_bottom_bar.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SetupScreen')),
      body: const Center(child: Text('SetupScreen - à implémenter')),
    );
  }
}
