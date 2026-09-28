import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/services/rodium_ai_service.dart';

void main() {
  group('parseAiJsonResponse', () {
    test('parse un JSON valide simple', () {
      final result = parseAiJsonResponse(
        '{"maladie": "Mildiou", "confiance": 0.82, "traitement": "Traiter au cuivre", "reponse_avatar": "Voici le résultat"}',
      );
      expect(result['maladie'], 'Mildiou');
      expect(result['confiance'], 0.82);
    });

    test('retire les balises ```json``` autour de la réponse', () {
      final result = parseAiJsonResponse(
        '```json\n{"maladie": "Rouille", "confiance": 0.5}\n```',
      );
      expect(result['maladie'], 'Rouille');
    });

    test('retombe sur un résultat par défaut si le JSON est invalide', () {
      final result = parseAiJsonResponse('Réponse en texte libre, pas du JSON.');
      expect(result['maladie'], 'Indéterminé');
      expect(result['reponse_avatar'], contains('texte libre'));
    });
  });
}
