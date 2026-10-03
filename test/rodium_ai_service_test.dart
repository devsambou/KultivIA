import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/services/ai/rodium_ai_service.dart';

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

    // Les cas suivants reprennent MOT POUR MOT des réponses capturées en
    // production via tools/probe-json-diagnostic.mjs. C'est ce que
    // l'agriculteur voyait à l'écran.

    test('isole le JSON entouré de texte du modèle', () {
      final result = parseAiJsonResponse(
        'Voici mon analyse :\n'
        '{"maladie": "Rouille", "confiance": 0.7, "traitement": "Soufre"}\n'
        'N\'h\'esite pas si tu as d\'autres questions.',
      );
      expect(result['maladie'], 'Rouille');
      expect(result['traitement'], 'Soufre');
    });

    test('répare un JSON coupé par le fournisseur en cours de génération', () {
      // finish_reason = "length" : la réponse s'arrête au milieu de
      // "confiance" (47 caractères), tel que observé en production.
      final result = parseAiJsonResponse(
        '{\n  "maladie": "Indéterminé",\n  "confiance": 0.',
      );
      // Le champ déjà écrit doit être sauvé plutôt que perdu.
      expect(result['maladie'], 'Indéterminé');
    });

    test('répare un JSON coupé au milieu d\'une chaîne', () {
      final result = parseAiJsonResponse(
        '{"maladie": "Helminthosporiose", "traitement": "Enlevez les feuil',
      );
      expect(result['maladie'], 'Helminthosporiose');
      expect(result['traitement'], contains('Enlevez'));
    });

    test("ne confond pas une accolade située dans une chaîne", () {
      final result = parseAiJsonResponse(
        '{"maladie": "Mildiou", "traitement": "Pulvériser du {cuivre} matin"}',
      );
      expect(result['maladie'], 'Mildiou');
      expect(result['traitement'], contains('cuivre'));
    });

    test("n'affiche jamais de JSON brut à l'agriculteur", () {
      // Piège : une réponse illisible ne doit surtout pas être renvoyée
      // telle quelle, sinon l'écran affiche les accolades du modèle.
      const responses = <String>[
        '{"maladie": "Rouille", "confiance": 0.',
        '```json\n{"maladie": "Mildiou"',
        '{{{{',
        '{"maladie": }}}',
      ];

      for (final raw in responses) {
        final result = parseAiJsonResponse(raw);
        final displayed = '${result['reponse_avatar']}';

        expect(
          displayed.trim().startsWith('{'),
          isFalse,
          reason: 'JSON brut renvoyé pour : $raw',
        );
        expect(displayed, isNotEmpty);
      }
    });

    test("une réponse vide reste gérable", () {
      final result = parseAiJsonResponse('');
      expect(result['maladie'], 'Indéterminé');
      expect(result['reponse_avatar'], isNotEmpty);
    });
  });
}