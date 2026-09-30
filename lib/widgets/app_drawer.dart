// Menu latéral (drawer). Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/system/app_state.dart';
import '../services/auth/firebase_service.dart';
import '../core/theme/theme.dart';

/// Menu latéral : donne accès à tous les écrans depuis la conversation.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.onNewChat});

  final VoidCallback? onNewChat;

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.read<FirebaseService>();
    final user = fb.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? 'Utilisateur';

    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, size: 40) : null,
            ),
            accountName: Text(displayName),
            accountEmail: Text(user?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Nouvelle conversation'),
            onTap: () {
              Navigator.pop(context);
              onNewChat?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historique'),
            onTap: () => _go(context, '/history'),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil'),
            onTap: () => _go(context, '/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Marketplace'),
            onTap: () => _go(context, '/marketplace'),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Vendeurs'),
            onTap: () => _go(context, '/vendors'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Alertes météo'),
            onTap: () => _go(context, '/weather'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Communauté'),
            onTap: () => _go(context, '/community'),
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: const Text('Santé exploitation'),
            onTap: () => _go(context, '/health-dashboard'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Paramètres'),
            onTap: () => _go(context, '/language'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: () async {
              await fb.signOut();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}
