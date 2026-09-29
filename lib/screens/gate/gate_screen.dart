import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';

/// Écran de démarrage : décide où envoyer l'utilisateur.
///  - pas connecté            → onboarding → connexion
///  - connecté, profil vide   → paramétrage de première connexion (/setup)
///  - connecté, profil rempli → conversation (/home)
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoRoute());
  }

  Future<void> _tryAutoRoute() async {
    final fb = context.read<FirebaseService>();
    final app = context.read<AppState>();

    // Avec mock auth, currentUser fonctionne même sans Firebase configuré
    if (fb.currentUser != null) {
      try {
        final profile = await fb.fetchProfile();
        if (profile != null && profile.completed) {
          app.setProfile(profile);
          app.bindHistory();
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/setup');
        }
      } catch (_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
    // Si pas d'utilisateur connecté → on affiche l'écran d'accueil avec bouton "Commencer"
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 220,
              errorBuilder: (_, __, ___) => Icon(Icons.eco, size: 72, color: cs.primary),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Commencer'),
              onPressed: () => Navigator.of(context).pushNamed('/onboarding'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Créez votre compte ou connectez-vous pour commencer.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}