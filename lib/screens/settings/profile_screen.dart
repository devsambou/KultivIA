import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/system/app_state.dart';
import '../services/auth/firebase_service.dart';
import '../services/system/notification_service.dart';
import '../services/system/user_settings.dart';
import '../core/theme/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggleNotifications(bool on) async {
    final app = context.read<AppState>();
    final fb = context.read<FirebaseService>();
    final notif = context.read<NotificationService>();
    final profile = app.profile;
    final uid = fb.currentUser?.uid;
    if (profile == null || uid == null) return;

    setState(() => _busy = true);
    try {
      final enabled = on ? await notif.enable(uid) : false;
      if (!on) await notif.disable();
      final updated = profile.copyWith(notificationsEnabled: enabled);
      await fb.saveProfile(updated);
      app.setProfile(updated);
      if (on && !enabled) {
        _toast('Autorisez les notifications dans les réglages du téléphone.');
      }
    } catch (e) {
      debugPrint('Changement de notifications impossible : $e');
      _toast('Impossible de modifier ce réglage pour le moment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    final app = context.read<AppState>();
    final fb = context.read<FirebaseService>();
    final notif = context.read<NotificationService>();
    if (fb.isReady) {
      await notif.disable();
      await fb.signOut();
    }
    await app.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.profile;
    final name = profile?.displayName.trim() ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: cs.primaryContainer,
              child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 12),
          if (profile != null) ...[
            Text(name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            Text(
              [profile.roleLabel, if (profile.locality.isNotEmpty) profile.locality].join(' · '),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Modifier mon profil'),
            subtitle: profile == null || profile.crops.isEmpty ? null : Text('Cultures : ${profile.crops.join(', ')}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/setup'),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Langue'),
            subtitle: Text(UserSettings.supportedLanguages[app.languageCode] ?? app.languageCode),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/language'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Alertes météo et signalements'),
            value: profile?.notificationsEnabled ?? false,
            onChanged: _busy || profile == null ? null : _toggleNotifications,
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
