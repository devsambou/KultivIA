// Bandeau hors-ligne affiché en haut de l'application. Issue GitHub : #C6
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme.dart';
import '../services/system/connectivity_service.dart';

/// Hôte du bandeau, posé **une seule fois** dans `MaterialApp.builder`
/// (voir `lib/main.dart`) :
///
/// ```dart
/// builder: (context, child) => OfflineHost(child: child!),
/// ```
///
/// Il enveloppe le `Navigator`, donc les 13 routes sont couvertes sans qu'un
/// seul écran ait à connaître l'existence du bandeau.
class OfflineHost extends StatelessWidget {
  const OfflineHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `isKnown` évite un clignotement : tant que la première lecture n'a pas
    // abouti, le bandeau reste caché plutôt que d'annoncer une panne.
    final isOffline = context.select<ConnectivityService, bool>(
      (c) => c.isKnown && !c.isOnline,
    );

    // Le bandeau se place sous la barre d'état plutôt que par-dessus, et les
    // écrans conservent leur propre `MediaQuery.padding.top`. Retirer ce
    // padding ici créerait un espace fantôme de la hauteur du statut bar
    // quand le bandeau est masqué, et décalerait chaque AppBar quand il est
    // visible.
    return Column(
      children: [
        AnimatedSize(
          duration: _duration,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: isOffline
              ? const OfflineBanner()
              : const SizedBox(width: double.infinity, height: 0),
        ),
        Expanded(child: child),
      ],
    );
  }

  static const _duration = Duration(milliseconds: 220);
}

/// Barre d'alerte : « Vous êtes hors connexion… »
///
/// Nulle part en ligne, elle rend exactement zéro pixel. Les couleurs viennent
/// du jeton sémantique `warning` du thème, jamais en dur.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  static const message =
      'Vous êtes hors connexion. Vos derniers diagnostics restent disponibles.';

  @override
  Widget build(BuildContext context) {
    final tone = KultivTheme.status(context).warning;

    return ColoredBox(
      color: tone.bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.lg,
          vertical: KSpace.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 18, color: tone.fg),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: tone.fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}