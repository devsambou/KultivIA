import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../core/theme/theme.dart';
import '../../widgets/k_components.dart';
import 'setup_controller.dart';

/// Étape 1 : Identité (nom, rôle)
class StepIdentity extends StatelessWidget {
  const StepIdentity({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SetupController>();

    return SetupPage(
      title: 'Faisons connaissance',
      subtitle: 'Ces informations personnalisent vos conseils.',
      children: [
        TextField(
          controller: controller.nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom complet', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        Text('Vous êtes…', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in UserProfile.roles.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: controller.role == e.key,
                onSelected: (_) => controller.setRole(e.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// Page de base pour les étapes du setup
class SetupPage extends StatelessWidget {
  const SetupPage({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, title, subtitle),
          ...children,
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontFamilyFallback: KultivTheme.serif, fontSize: 30, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 16, color: KultivTheme.muted(context))),
          ],
        ),
      );
}