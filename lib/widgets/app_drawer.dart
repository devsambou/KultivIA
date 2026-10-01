// Menu latéral (drawer). Issue GitHub : C5
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/system/app_state.dart';
import '../services/auth/firebase_service.dart';

/// Menu latéral : donne accès à tous les écrans depuis la conversation.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onNewChat});

  final VoidCallback onNewChat;

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }

  Widget _item(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => _go(context, route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    final user = context.read<FirebaseService>().currentUser;
    final authPhoto = user?.photoURL;
    final profilePhoto = profile?.photoUrl;
    final name = profile?.displayName.trim() ?? user?.displayName ?? 'Utilisateur';
    final locality = profile?.locality ?? '';
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    final String? photo = (profilePhoto != null && profilePhoto.isNotEmpty)
        ? profilePhoto
        : (authPhoto != null && authPhoto.isNotEmpty ? authPhoto : null);

    return Drawer(
      child: Column(
        children: [
          // En haut : profil cliquable
          InkWell(
            onTap: () => _go(context, '/profile'),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, mq.padding.top + 16, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null
                        ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (locality.isNotEmpty)
                          Text(
                            locality,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),

          // Entrées du menu
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('Nouvelle conversation'),
                  onTap: () {
                    Navigator.pop(context);
                    onNewChat();
                  },
                ),
                _item(context, Icons.history, 'Historique', '/history'),
                _item(context, Icons.health_and_safety_outlined,
                    'Santé exploitation', '/health-dashboard'),
                _item(context, Icons.cloud_outlined, 'Alertes météo', '/weather'),
                _item(context, Icons.store_outlined,
                    'Points de vente d\'intrants', '/vendors'),
                _item(context, Icons.people_outline, 'Communauté', '/community'),
                _item(context, Icons.storefront_outlined, 'Marketplace',
                    '/marketplace'),
                const Divider(),
                ListTile(
                  leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                  title: const Text('Mode sombre / clair'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: implémenter le toggle thème
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Toggle thème à implémenter')),
                    );
                  },
                ),
                _item(context, Icons.settings, 'Paramètres', '/settings'),
              ],
            ),
          ),

          // En bas : logo seul
          Container(
            width: double.infinity,
            color: cs.primary,
            padding: EdgeInsets.fromLTRB(16, 16, 16, mq.padding.bottom + 16),
            child: Center(
              child: Image.asset(
                'assets/icon/icon.png',
                height: 72,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}