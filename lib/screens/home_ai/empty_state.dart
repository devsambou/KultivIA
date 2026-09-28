import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Écran vide (avant le premier message) : gros bouton micro utilisable
/// sans savoir lire, plus quelques suggestions rapides.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.name,
    required this.listening,
    required this.onMic,
    required this.onCamera,
    required this.onPrompt,
    required this.onWeather,
  });

  final String? name;
  final bool listening;
  final VoidCallback onMic;
  final VoidCallback onCamera;
  final ValueChanged<String> onPrompt;
  final VoidCallback onWeather;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final greeting = (name == null || name!.isEmpty) ? 'Bonjour' : 'Bonjour, $name';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, size: 44, color: cs.primary),
            const SizedBox(height: 16),
            Text(greeting,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamilyFallback: KultivTheme.serif, fontSize: 32, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Que voulez-vous vérifier aujourd\'hui ?',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: KultivTheme.muted(context))),
            const SizedBox(height: 28),
            // Gros bouton pour parler : utilisable sans savoir lire.
            Semantics(
              button: true,
              label: listening ? 'Arrêter la dictée' : 'Parler à Kultivia',
              child: Material(
                color: listening ? KultivTheme.status(context).danger.fg : cs.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onMic,
                  child: Padding(
                    padding: const EdgeInsets.all(KSpace.xl),
                    child: Icon(listening ? Icons.stop : Icons.mic, size: 44, color: cs.onPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: KSpace.sm),
            Text(listening ? 'Je vous écoute…' : 'Appuyez et parlez',
                style: TextStyle(fontSize: 14, color: KultivTheme.muted(context))),
            const SizedBox(height: KSpace.xl),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Photographier une plante'),
                  onPressed: onCamera,
                ),
                ActionChip(
                  avatar: const Icon(Icons.grass, size: 18),
                  label: const Text('Mes feuilles jaunissent'),
                  onPressed: () => onPrompt('Les feuilles de mes plants jaunissent, que faire ?'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.cloud_outlined, size: 18),
                  label: const Text('Risque météo'),
                  onPressed: onWeather,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
