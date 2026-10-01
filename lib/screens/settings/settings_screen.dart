import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';
import '../../services/system/user_settings.dart';
import '../../services/ui/voice_service.dart';
import '../../models/user_profile.dart';
import '../../core/theme/theme.dart';
import '../../widgets/k_components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          // Langue
          Text('Langue', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final e in UserSettings.supportedLanguages.entries)
            KCard(
              child: RadioListTile<String>(
                title: Text(e.value),
                secondary: IconButton(
                  icon: const Icon(Icons.volume_up_outlined),
                  tooltip: 'Écouter',
                  onPressed: () => VoiceService().speak(
                    VoiceService.greetings[e.key] ?? '',
                    languageCode: e.key,
                  ),
                ),
                value: e.key,
                groupValue: app.languageCode,
                onChanged: (v) {
                  if (v != null) {
                    app.setLanguage(v);
                    if (profile != null) {
                      final updated = profile.copyWith(languageCode: v);
                      context.read<FirebaseService>().saveProfile(updated);
                    }
                  }
                },
              ),
            ),
          const SizedBox(height: 24),

          // Notifications
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Alertes météo et signalements'),
            value: profile?.notificationsEnabled ?? false,
            onChanged: _busy || profile == null ? null : _toggleNotifications,
          ),
          const SizedBox(height: 8),

          // Voix
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Écouter les réponses'),
            subtitle: const Text("L'assistant vous parle à voix haute"),
            value: profile?.voiceReplies ?? false,
            onChanged: (on) {
              if (profile != null) {
                app.setVoiceReplies(on);
                final updated = profile.copyWith(voiceReplies: on);
                context.read<FirebaseService>().saveProfile(updated);
              }
            },
          ),
        ],
      ),
    );
  }
}