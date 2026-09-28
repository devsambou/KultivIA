// Écran principal de conversation avec l'IA. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/diagnosis.dart';
import '../../repositories/diagnosis_repository.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';
import '../../services/ai/rodium_ai_service.dart';
import '../../services/ui/voice_service.dart';
import '../../widgets/app_drawer.dart';
import 'composer.dart';
import 'empty_state.dart';
import 'message_view.dart';
import 'typing_dots.dart';

class HomeAiScreen extends StatefulWidget {
  const HomeAiScreen({super.key});

  @override
  State<HomeAiScreen> createState() => _HomeAiScreenState();
}

class _HomeAiScreenState extends State<HomeAiScreen> {
  void _newChat() {
    throw UnimplementedError();
  }

  Future<void> _send({bool viaVoice = false}) async {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HomeAiScreen')),
      body: const Center(child: Text('HomeAiScreen - à implémenter')),
    );
  }
}
