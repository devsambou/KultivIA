// Écran d'historique des diagnostics. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/system/app_state.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HistoryScreen')),
      body: const Center(child: Text('HistoryScreen - à implémenter')),
    );
  }
}
