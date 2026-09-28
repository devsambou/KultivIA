// Écran de démarrage (redirection intelligente). Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoRoute());
  }

  Future<void> _tryAutoRoute() async {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GateScreen')),
      body: const Center(child: Text('GateScreen - à implémenter')),
    );
  }
}
