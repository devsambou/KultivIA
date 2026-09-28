// Écran score de santé de l'exploitation. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/system/app_state.dart';
import '../../widgets/k_components.dart';
import '../../core/theme/theme.dart';

class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HealthDashboardScreen')),
      body: const Center(child: Text('HealthDashboardScreen - à implémenter')),
    );
  }
}
