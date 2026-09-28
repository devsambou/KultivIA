// Menu latéral (drawer). Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/system/app_state.dart';
import '../core/theme/theme.dart';

/// Menu latéral : donne accès à tous les écrans depuis la conversation.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.onNewChat});

  final VoidCallback? onNewChat;

  void _go(BuildContext context, String route) {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AppDrawer')),
      body: const Center(child: Text('AppDrawer - à implémenter')),
    );
  }
}
