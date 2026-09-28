import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/system/app_state.dart';
import '../core/theme/theme.dart';

/// Menu latéral (comme la barre latérale de Claude) : donne accès à tous
/// les écrans depuis la conversation.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.onNewChat});

  final VoidCallback? onNewChat;

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    final name = profile?.displayName.trim() ?? '';
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Image.asset(
                'assets/images/logo.png',
                height: 32,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => Row(
                  children: [
                    Icon(Icons.eco, color: cs.primary, size: 28),
                    const SizedBox(width: 10),
                    Text('KultivIA',
                        style: const TextStyle(fontFamilyFallback: KultivTheme.serif, fontSize: 24, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Nouvelle conversation'),
              onTap: () {
                Navigator.of(context).pop();
                onNewChat?.call();
              },
            ),
            const Divider(height: 24),
            ListTile(leading: const Icon(Icons.history), title: const Text('Historique'), onTap: () => _go(context, '/history')),
            ListTile(leading: const Icon(Icons.dashboard_outlined), title: const Text("Santé de l'exploitation"), onTap: () => _go(context, '/health-dashboard')),
            ListTile(leading: const Icon(Icons.cloud_outlined), title: const Text('Alertes météo'), onTap: () => _go(context, '/weather')),
            ListTile(leading: const Icon(Icons.storefront_outlined), title: const Text("Points de vente d'intrants"), onTap: () => _go(context, '/vendors')),
            ListTile(leading: const Icon(Icons.groups_outlined), title: const Text('Communauté'), onTap: () => _go(context, '/community')),
            ListTile(leading: const Icon(Icons.sell_outlined), title: const Text('Marketplace'), onTap: () => _go(context, '/marketplace')),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(backgroundColor: cs.primaryContainer, child: Text(initial)),
              title: Text(name.isEmpty ? 'Mon profil' : name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: profile == null || profile.locality.isEmpty ? null : Text(profile.locality),
              onTap: () => _go(context, '/profile'),
            ),
          ],
        ),
      ),
    );
  }
}
