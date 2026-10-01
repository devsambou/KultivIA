import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/models/diagnosis.dart';
import 'package:kultivia/screens/health/health_dashboard_screen.dart';

Diagnosis _diag(String disease, double confidence) => Diagnosis(
      id: '$disease-$confidence',
      date: DateTime(2026, 1, 1),
      inputText: disease,
      disease: disease,
      confidence: confidence,
      advice: '',
      rawAiResponse: '',
    );

void main() {
  group('HealthScore.compute', () {
    test('liste vide → 100', () {
      expect(HealthScore.compute([]), 100);
    });

    test('tous sains (indéterminé) → 100', () {
      final h = [_diag('Indéterminé', 0.9), _diag('Indéterminé', 0.5)];
      expect(HealthScore.compute(h), 100);
    });

    test('tous sains (confiance < 0.3) → 100', () {
      final h = [_diag('Mildiou', 0.2), _diag('Rouille', 0.1)];
      expect(HealthScore.compute(h), 100);
    });

    test('tous malades → 0', () {
      final h = [_diag('Mildiou', 0.9), _diag('Rouille', 0.8)];
      expect(HealthScore.compute(h), 0);
    });

    test('mélange 1 sain / 3 malades → 25', () {
      final h = [
        _diag('Indéterminé', 0.9),
        _diag('Mildiou', 0.9),
        _diag('Rouille', 0.8),
        _diag('Oïdium', 0.7),
      ];
      expect(HealthScore.compute(h), 25);
    });

    test('seuil de confiance 0.3 : 0.3 est malade, 0.29 est sain', () {
      final exactly03 = _diag('Mildiou', 0.3);
      final justBelow = _diag('Mildiou', 0.29);
      expect(HealthScore.compute([exactly03]), 0);
      expect(HealthScore.compute([justBelow]), 100);
    });

    test('arrondi : 2 sains / 3 → 67', () {
      final h = [
        _diag('Indéterminé', 0.9),
        _diag('Indéterminé', 0.9),
        _diag('Mildiou', 0.9),
      ];
      // 100 × (1 - 1/3) = 66.66 → 67
      expect(HealthScore.compute(h), 67);
    });
  });

  group('HealthScore.label', () {
    test('≥ 80 → Bon état', () {
      expect(HealthScore.label(80), 'Bon état');
      expect(HealthScore.label(100), 'Bon état');
    });

    test('≥ 50 → À surveiller', () {
      expect(HealthScore.label(50), 'À surveiller');
      expect(HealthScore.label(79), 'À surveiller');
    });

    test('< 50 → Critique', () {
      expect(HealthScore.label(49), 'Critique');
      expect(HealthScore.label(0), 'Critique');
    });
  });

  group('HealthScore.sickCount', () {
    test('compte uniquement les maladies identifiées', () {
      final h = [
        _diag('Indéterminé', 0.9),
        _diag('Mildiou', 0.9),
        _diag('Faible confiance', 0.2),
      ];
      expect(HealthScore.sickCount(h), 1);
    });
  });

  group('HealthScore.topDiseases', () {
    test('trie par fréquence décroissante', () {
      final h = [
        _diag('Mildiou', 0.9),
        _diag('Rouille', 0.8),
        _diag('Mildiou', 0.9),
        _diag('Oïdium', 0.7),
        _diag('Mildiou', 0.9),
      ];
      final top = HealthScore.topDiseases(h);
      expect(top[0].key, 'Mildiou');
      expect(top[0].value, 3);
      expect(top[1].key, 'Rouille');
      expect(top[1].value, 1);
      expect(top[2].key, 'Oïdium');
      expect(top[2].value, 1);
    });

    test('exclut les diagnostics indéterminés', () {
      final h = [_diag('Indéterminé', 0.9), _diag('Mildiou', 0.9)];
      expect(HealthScore.topDiseases(h).length, 1);
    });
  });
}