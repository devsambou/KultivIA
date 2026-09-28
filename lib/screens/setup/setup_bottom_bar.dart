import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme.dart';
import '../../widgets/k_components.dart';
import 'setup_controller.dart';

/// Barre de navigation en bas de l'écran de setup (Retour / Suivant / Terminer)
class SetupBottomBar extends StatelessWidget {
  const SetupBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SetupController>();
    final isLast = controller.step == controller.stepCount - 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          children: [
            if (controller.step > 0)
              TextButton(
                onPressed: controller.saving ? null : controller.previous,
                child: const Text('Retour'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: controller.saving ? null : () => controller.next(context),
              child: controller.saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isLast ? 'Terminer' : 'Suivant'),
            ),
          ],
        ),
      ),
    );
  }
}