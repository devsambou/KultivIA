import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';
import '../../services/system/user_settings.dart';
import '../../services/ui/voice_service.dart';
import '../../models/user_profile.dart';
import '../../screens/setup/setup_controller.dart';
import '../../core/theme/theme.dart';
import '../../widgets/k_components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  bool _locating = false;
  final _nameController = TextEditingController();
  final _localityController = TextEditingController();

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _detectLocality() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _toast('Autorisez la localisation dans les réglages.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      // Geocoding inverse simple via Open-Meteo
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&accept-language=fr',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final city = data['address']?['city'] ??
            data['address']?['town'] ??
            data['address']?['village'] ??
            data['address']?['county'] ??
            '';
        if (city.isNotEmpty) {
          _localityController.text = city;
          setState(() {});
        }
      }
    } catch (e) {
      _toast('Impossible de détecter la ville : $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

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
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final profile = app.profile;
    if (profile != null) {
      _nameController.text = profile.displayName;
      _localityController.text = profile.locality;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _localityController.dispose();
    super.dispose();
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
          // Avatar + Nom
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Votre nom',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (profile != null)
            Text(
              [
                profile.roleLabel,
                if (profile.locality.isNotEmpty) profile.locality
              ].join(' · '),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          const SizedBox(height: 24),

          // Rôle
          Text('Rôle', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in UserProfile.roles.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: profile?.role == e.key,
                  onSelected: (_) {
                    if (profile != null) {
                      final updated = profile.copyWith(role: e.key);
                      context.read<AppState>().setProfile(updated);
                      context.read<FirebaseService>().saveProfile(updated);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Ville + GPS
          Text('Ville / Région', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _localityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Village, ville ou région',
                    hintText: 'Ex. Thiès',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _locating ? null : _detectLocality,
                icon: _locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                tooltip: 'Détecter ma ville',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Cultures
          Text('Cultures', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in SetupController.cropOptionsList)
                FilterChip(
                  label: Text(c),
                  selected: profile?.crops.contains(c) ?? false,
                  onSelected: (on) {
                    if (profile != null) {
                      final crops = Set<String>.from(profile.crops);
                      if (on) {
                        crops.add(c);
                      } else {
                        crops.remove(c);
                      }
                      final updated = profile.copyWith(crops: crops.toList()..sort());
                      context.read<AppState>().setProfile(updated);
                      context.read<FirebaseService>().saveProfile(updated);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),

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
          const Divider(height: 32),

          // Déconnexion
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
