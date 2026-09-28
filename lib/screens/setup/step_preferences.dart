import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/system/user_settings.dart';
import '../../services/ui/voice_service.dart';
import '../../widgets/k_components.dart';
import 'setup_controller.dart';
import 'step_identity.dart';

/// Étape 3 : Préférences (langue, voix, notifications)
class StepPreferences extends StatelessWidget {
  const StepPreferences({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SetupController>();

    return SetupPage(
      title: 'Vos préférences',
      subtitle: 'Vous pourrez les modifier à tout moment dans votre profil.',
      children: [
        Text('Langue', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final e in UserSettings.supportedLanguages.entries)
          KCard(
            child: RadioListTile<String>(
              title: Text(e.value),
              // Touchez le haut-parleur pour entendre la langue (utile si on ne lit pas).
              secondary: IconButton(
                icon: const Icon(Icons.volume_up_outlined),
                tooltip: 'Écouter',
                onPressed: () => VoiceService().speak(VoiceService.greetings[e.key] ?? '', languageCode: e.key),
              ),
              value: e.key,
              groupValue: controller.language,
              onChanged: (v) => controller.setLanguage(v ?? controller.language),
            ),
          ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Écouter les réponses'),
          subtitle: const Text("L'assistant vous parle à voix haute. Pratique si vous lisez difficilement."),
          value: controller.voiceReplies,
          onChanged: controller.setVoiceReplies,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Alertes et notifications'),
          subtitle: const Text('Risque de maladie selon la météo, signalements près de chez vous.'),
          value: controller.notifications,
          onChanged: controller.setNotifications,
        ),
      ],
    );
  }
}