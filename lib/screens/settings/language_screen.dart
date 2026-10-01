import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/system/app_state.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/system/user_settings.dart';
import '../../services/ui/voice_service.dart';
import '../../widgets/k_components.dart';
import '../../core/theme/theme.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  Future<void> _select(BuildContext context, String code) async {
    final app = context.read<AppState>();
    final fb = context.read<FirebaseService>();
    app.setLanguage(code);
    final profile = app.profile;
    if (fb.isReady && profile != null) {
      try {
        await fb.saveProfile(profile);
      } catch (_) {
        // Non bloquant : la langue reste appliquée localement.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Langue')),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          for (final entry in UserSettings.supportedLanguages.entries)
            KCard(
              child: RadioListTile<String>(
                title: Text(entry.value),
                secondary: IconButton(
                  icon: const Icon(Icons.volume_up_outlined),
                  tooltip: 'Écouter',
                  onPressed: () => VoiceService().speak(VoiceService.greetings[entry.key] ?? '', languageCode: entry.key),
                ),
                value: entry.key,
                groupValue: appState.languageCode,
                onChanged: (code) {
                  if (code != null) _select(context, code);
                },
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.sm),
            child: Text(
              'Touchez le haut-parleur pour écouter chaque langue. Vous pouvez parler à l\'assistant : '
                  'il vous répond dans la langue choisie. En wolof, la voix nécessite une connexion internet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }
}