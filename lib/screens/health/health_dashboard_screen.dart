import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/system/app_state.dart';
import '../widgets/k_components.dart';
import '../core/theme/theme.dart';

/// Fonctionnalité 5.3 : score de santé de l'exploitation. Agrège
/// l'historique des diagnostics de l'utilisateur pour donner une vue
/// d'ensemble, au-delà du diagnostic ponctuel.
///
/// Le calcul se fait ici côté client à partir de `AppState.history`
/// (déjà alimenté depuis Firestore par home_ai_screen.dart) : pas besoin
/// d'appel IA supplémentaire pour cet écran.
class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().historyList;

    final total = history.length;
    final healthy = history.where((d) => d.disease.toLowerCase().contains('indéterminé') || d.confidence < 0.3).length;
    final sick = total - healthy;
    final score = total == 0 ? 100 : (100 * (1 - sick / total)).round();
    final tone = KultivTheme.status(context).forScore(score);
    final scoreLabel = score >= 80 ? 'Bon état' : (score >= 50 ? 'À surveiller' : 'Critique');

    final byDisease = <String, int>{};
    for (final d in history) {
      if (d.confidence >= 0.3) {
        byDisease[d.disease] = (byDisease[d.disease] ?? 0) + 1;
      }
    }
    final sortedDiseases = byDisease.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Score de santé de l\'exploitation')),
      body: total == 0
          ? const Center(child: Text('Pas encore de diagnostic enregistré.'))
          : ListView(
              padding: const EdgeInsets.all(KSpace.lg),
              children: [
                KCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('$score / 100',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: tone.fg)),
                        const SizedBox(height: KSpace.sm),
                        StatusChip(label: scoreLabel, tone: tone),
                        const SizedBox(height: KSpace.sm),
                        Text('$total diagnostic(s) au total, dont $sick avec une maladie identifiée'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (sortedDiseases.isNotEmpty) ...[
                  Text('Maladies les plus fréquentes', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final entry in sortedDiseases.take(5))
                    KCard(
                      child: ListTile(
                        leading: const Icon(Icons.bug_report_outlined),
                        title: Text(entry.key),
                        trailing: Text('${entry.value}×'),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
