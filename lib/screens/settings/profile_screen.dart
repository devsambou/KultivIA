// Écran de profil utilisateur. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';
import '../../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final fb = context.read<FirebaseService>();
    final profile = await fb.fetchProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool on) async {
    if (_profile != null) {
      final updated = _profile!.copyWith(notificationsEnabled: on);
      final fb = context.read<FirebaseService>();
      await fb.saveProfile(updated);
      setState(() => _profile = updated);
    }
  }

  Future<void> _logout() async {
    final fb = context.read<FirebaseService>();
    await fb.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.read<FirebaseService>();
    final user = fb.currentUser;
    final photoUrl = _profile?.photoUrl ?? user?.photoURL;
    final displayName = _profile?.displayName ?? user?.displayName ?? 'Utilisateur';
    final email = user?.email ?? '';

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? const Icon(Icons.person, size: 50) : null,
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: SwitchListTile(
              title: const Text('Notifications'),
              subtitle: const Text('Recevoir des alertes et notifications'),
              value: _profile?.notificationsEnabled ?? false,
              onChanged: _toggleNotifications,
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Réponses vocales'),
              subtitle: const Text('L\'IA lit les réponses à voix haute'),
              value: _profile?.voiceReplies ?? false,
              onChanged: (value) async {
                if (_profile != null) {
                  final updated = _profile!.copyWith(voiceReplies: value);
                  final fb = context.read<FirebaseService>();
                  await fb.saveProfile(updated);
                  setState(() => _profile = updated);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Langue'),
              trailing: Text(_profile?.languageCode.toUpperCase() ?? 'FR'),
              onTap: () => Navigator.pushNamed(context, '/language'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Localité'),
              subtitle: Text(_profile?.locality ?? 'Non définie'),
            ),
          ),
          if (_profile?.crops.isNotEmpty == true)
            Card(
              child: ListTile(
                leading: const Icon(Icons.agriculture),
                title: const Text('Cultures'),
                subtitle: Text(_profile!.crops.join(', ')),
              ),
            ),
        ],
      ),
    );
  }
}
