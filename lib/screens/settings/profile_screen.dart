import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../models/user_profile.dart';
import '../../core/theme/theme.dart';
import '../../widgets/k_components.dart';
import '../../screens/setup/setup_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  bool _locating = false;
  bool _uploadingPhoto = false;
  final _nameController = TextEditingController();
  final _localityController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+221';
  File? _pickedImage;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _loadProfile() async {
    final app = context.read<AppState>();
    final fb = context.read<FirebaseService>();
    if (app.profile == null) {
      final profile = await fb.fetchProfile();
      if (profile != null && mounted) {
        app.setProfile(profile);
      }
    }
    final profile = app.profile;
    if (profile != null) {
      _nameController.text = profile.displayName;
      _localityController.text = profile.locality;
      _phoneController.text = profile.phoneNumber;
      _selectedCountryCode = profile.phoneCountryCode;
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
      await _uploadPhoto();
    }
  }

  Future<void> _uploadPhoto() async {
    if (_pickedImage == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final fb = context.read<FirebaseService>();
      final profile = context.read<AppState>().profile;
      if (profile == null) return;

      // Upload vers Firebase Storage
      final uid = fb.currentUser?.uid;
      if (uid == null) throw Exception('Utilisateur non connecté');

      final ref = fb.storageRef().child('profile_photos/$uid.jpg');
      await ref.putFile(_pickedImage!);
      final downloadUrl = await ref.getDownloadURL();

      final updated = (context.read<AppState>().profile)!.copyWith(photoUrl: downloadUrl);
      await fb.saveProfile(updated);
      context.read<AppState>().setProfile(updated);

      _toast('Photo de profil mise à jour');
    } catch (e) {
      debugPrint('Erreur upload photo : $e');
      _toast('Erreur upload : $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    final app = context.read<AppState>();
    final fb = context.read<FirebaseService>();
    final profile = app.profile;
    if (profile == null) return;

    setState(() => _busy = true);
    try {
      final updated = profile.copyWith(
        displayName: _nameController.text.trim(),
        locality: _localityController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        phoneCountryCode: _selectedCountryCode,
      );
      await fb.saveProfile(updated);
      app.setProfile(updated);
      _toast('Profil mis à jour');
    } catch (e) {
      debugPrint('Mise à jour profil impossible : $e');
      _toast('Impossible de sauvegarder : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
    final photoUrl = profile?.photoUrl;
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
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: cs.primaryContainer,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(
                              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontSize: 32),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
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

          // Ville / Région
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

          // Téléphone
          Text('Téléphone', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              // Indicatif pays
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    items: UserProfile.countryCodes.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text('${e.key} ${e.value}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCountryCode = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Numéro
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: 'Ex. 77 123 45 67',
                    border: OutlineInputBorder(),
                  ),
                ),
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

          // Bouton sauvegarder
          FilledButton(
            onPressed: _busy ? null : _saveProfile,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
