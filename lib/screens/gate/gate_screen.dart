import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme.dart';
import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import 'farm_scene.dart';
// import 'widgets/scan_scene.dart'; // version 1 : fermier fixe, à échanger avec KultivFarmScene plus bas

/// Écran de démarrage : décide où envoyer l'utilisateur.
///  - pas connecté            -> onboarding -> connexion
///  - connecté, profil vide   -> paramétrage de première connexion (/setup)
///  - connecté, profil rempli -> conversation (/home)
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> with SingleTickerProviderStateMixin {
  // Une seule animation d'entrée, découpée en trois temps : logo, texte + scène, bouton.
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  late final Animation<double> _logoScale =
      CurvedAnimation(parent: _anim, curve: const Interval(0, 0.55, curve: Curves.elasticOut));
  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _anim, curve: const Interval(0, 0.3, curve: Curves.easeOut));
  late final Animation<double> _tagline =
      CurvedAnimation(parent: _anim, curve: const Interval(0.45, 0.8, curve: Curves.easeOut));
  late final Animation<double> _cta =
      CurvedAnimation(parent: _anim, curve: const Interval(0.7, 1, curve: Curves.easeOut));

  // Vrai tant qu'on vérifie le profil d'un utilisateur déjà connecté :
  // on affiche alors un indicateur au lieu du bouton « Commencer ».
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checking = context.read<FirebaseService>().currentUser != null;
    _anim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoRoute());
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _tryAutoRoute() async {
    if (!_checking) return; // pas d'utilisateur connecté -> on reste sur l'accueil
    final fb = context.read<FirebaseService>();
    final app = context.read<AppState>();

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: KSpace.xxl),
            ScaleTransition(
              scale: _logoScale,
              child: FadeTransition(
                opacity: _logoFade,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 220,
                  errorBuilder: (_, __, ___) => Icon(Icons.eco, size: 72, color: cs.primary),
                ),
              ),
            ),
            const SizedBox(height: KSpace.md),
            FadeTransition(
              opacity: _tagline,
              child: Text(
                'Vos cultures, en bonne santé',
                style: tt.titleMedium?.copyWith(color: KultivTheme.muted(context)),
                textAlign: TextAlign.center,
              ),
            ),
            // La scène occupe toute la largeur, sans cadre ni coins arrondis.
            // KultivFarmScene (v2) ou KultivScanScene (v1).
            Expanded(
              child: FadeTransition(
                opacity: _tagline,
                child: const Center(child: KultivFarmScene()),
              ),
            ),
            FadeTransition(
              opacity: _cta,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _checking
                        ? const Center(child: CircularProgressIndicator(key: ValueKey('loading')))
                        : FilledButton.icon(
                            key: const ValueKey('cta'),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Visiter'),
                            onPressed: () => Navigator.of(context).pushNamed('/onboarding'),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
