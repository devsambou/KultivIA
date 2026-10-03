import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';
import '../../services/system/user_settings.dart';
import '../../services/ui/voice_service.dart';
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
    final l10n = AppLocalizations.of(context)!;
    if (profile == null || uid == null) return;

    setState(() => _busy = true);
    try {
      final enabled = on ? await notif.enable(uid) : false;
      if (!on) await notif.disable();
      final updated = profile.copyWith(notificationsEnabled: enabled);
      await fb.saveProfile(updated);
      app.setProfile(updated);
      if (on && !enabled) {
        _toast(l10n.notificationsPermission);
      }
    } catch (e) {
      debugPrint('Changement de notifications impossible : $e');
      _toast(l10n.notificationsEnableError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Langues supportées pour l'interface (seulement FR/EN)
  static const _uiLanguages = {'fr': 'Français', 'en': 'English'};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.profile;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          // Langues (pliable)
          ExpansionTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.language),
            initiallyExpanded: true,
            children: [
              // Langue de l'application (FR/EN seulement)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(l10n.appLanguage, style: Theme.of(context).textTheme.titleSmall),
              ),
              for (final e in _uiLanguages.entries)
                KCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: RadioListTile<String>(
                    title: Text(e.value),
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
              const SizedBox(height: 16),

              // Langue de l'assistant IA (toutes les langues)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(l10n.aiLanguage, style: Theme.of(context).textTheme.titleSmall),
              ),
              for (final e in UserSettings.supportedLanguages.entries)
                KCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: RadioListTile<String>(
                    title: Text(e.value),
                    secondary: IconButton(
                      icon: const Icon(Icons.volume_up_outlined),
                      tooltip: l10n.listenAdvice,
                      onPressed: () => VoiceService().speak(
                        VoiceService.greetings[e.key] ?? '',
                        languageCode: e.key,
                      ),
                    ),
                    value: e.key,
                    groupValue: app.aiLanguageCode,
                    onChanged: (v) {
                      if (v != null) {
                        app.setAiLanguage(v);
                        if (profile != null) {
                          final updated = profile.copyWith(aiLanguageCode: v);
                          context.read<FirebaseService>().saveProfile(updated);
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Apparence (pliable)
          ExpansionTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.appearance),
            initiallyExpanded: true,
            children: [
              KCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text(l10n.themeLight),
                      subtitle: Text(l10n.themeLightDesc),
                      value: ThemeMode.light,
                      groupValue: app.themeMode,
                      onChanged: (v) {
                        if (v != null) {
                          app.setThemeMode(v);
                          if (profile != null) {
                            final updated = profile.copyWith(themeMode: v);
                            context.read<FirebaseService>().saveProfile(updated);
                          }
                        }
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text(l10n.themeDark),
                      subtitle: Text(l10n.themeDarkDesc),
                      value: ThemeMode.dark,
                      groupValue: app.themeMode,
                      onChanged: (v) {
                        if (v != null) {
                          app.setThemeMode(v);
                          if (profile != null) {
                            final updated = profile.copyWith(themeMode: v);
                            context.read<FirebaseService>().saveProfile(updated);
                          }
                        }
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text(l10n.themeSystem),
                      subtitle: Text(l10n.themeSystemDesc),
                      value: ThemeMode.system,
                      groupValue: app.themeMode,
                      onChanged: (v) {
                        if (v != null) {
                          app.setThemeMode(v);
                          if (profile != null) {
                            final updated = profile.copyWith(themeMode: v);
                            context.read<FirebaseService>().saveProfile(updated);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Notifications
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l10n.notifications),
            subtitle: Text(l10n.notificationsDesc),
            value: profile?.notificationsEnabled ?? false,
            onChanged: _busy || profile == null ? null : _toggleNotifications,
          ),
          const SizedBox(height: 8),

          // Voix
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.voiceReplies),
            subtitle: Text(l10n.voiceRepliesDesc),
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