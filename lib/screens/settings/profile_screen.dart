// Écran de profil utilisateur. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _toggleNotifications(bool on) async {
    throw UnimplementedError();
  }

  Future<void> _logout() async {
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ProfileScreen')),
      body: const Center(child: Text('ProfileScreen - à implémenter')),
    );
  }
}
