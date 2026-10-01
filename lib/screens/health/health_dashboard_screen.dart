import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/diagnosis.dart';
import '../../services/system/app_state.dart';
import '../../widgets/k_components.dart';
import '../../core/theme/theme.dart';

/// Score de santé de l'exploitation (0 à 100).
///
/// Règle : un diagnostic est « sain » si la maladie contient « indéterminé »
/// OU si la confiance est < 0.3. score = 100 × (1 − malades / total),
/// arrondi. 100 s'il n'y a aucun diagnostic.
class HealthScore {
  const HealthScore._();

  /// Calcule le score de santé à partir d'une liste de diagnostics.
  static int compute(List<Diagnosis> history) {
    final total = history.length;
    if (total == 0) return 100;
    final sick = history
        .where((d) => !(d.disease.toLowerCase().contains('indéterminé') ||
            d.confidence < 0.3))
        .length;
    return (100 * (1 - sick / total)).round();
  }

  /// Libellé du score selon les seuils.
  static String label(int score) =>
      score >= 80 ? 'Bon état' : (score >= 50 ? 'À surveiller' : 'Critique');

  /// Nombre de diagnostics « malades » (maladie identifiée, confiance ≥ 0.3).
  static int sickCount(List<Diagnosis> history) => history
      .where((d) =>
          d.confidence >= 0.3 &&
          !d.disease.toLowerCase().contains('indéterminé'))
      .length;

  /// Maladies les plus fréquentes (confiance ≥ 0.3), triées par fréquence.
  static List<MapEntry<String, int>> topDiseases(List<Diagnosis> history) {
    final counts = <String, int>{};
    for (final d in history) {
      if (d.confidence >= 0.3 &&
          !d.disease.toLowerCase().contains('indéterminé')) {
        counts[d.disease] = (counts[d.disease] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }
}

/// Écran de présentation du score de santé de l'exploitation.
class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().historyList;
    final total = history.length;
    final score = HealthScore.compute(history);
    final tone = KultivTheme.status(context).forScore(score);
    final sick = HealthScore.sickCount(history);
    final top = HealthScore.topDiseases(history);

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
                        Text(
                          '$score / 100',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: tone.fg,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: KSpace.sm),
                        StatusChip(label: HealthScore.label(score), tone: tone),
                        const SizedBox(height: KSpace.sm),
                        Text(
                          '$total diagnostic(s) au total, dont $sick avec une maladie identifiée',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (top.isNotEmpty) ...[
                  Text(
                    'Maladies les plus fréquentes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final entry in top.take(5))
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
