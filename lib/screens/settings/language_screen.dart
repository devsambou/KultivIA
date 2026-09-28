// Écran de sélection de langue. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  Future<void> _select(BuildContext context, String code) async {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LanguageScreen')),
      body: const Center(child: Text('LanguageScreen - à implémenter')),
    );
  }
}
