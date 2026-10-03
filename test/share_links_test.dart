import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/models/diagnosis.dart';
import 'package:kultivia/services/external/share_links.dart';

/// Détecte un caractère UTF-16 orphelin : signe d'une troncature faite au
/// milieu d'une paire de substitution, qui s'affiche en carré noir sur le
/// téléphone du destinataire.
bool _hasLoneSurrogate(String s) {
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    if (c >= 0xD800 && c <= 0xDBFF) {
      final next = i + 1 < units.length ? units[i + 1] : 0;
      if (next < 0xDC00 || next > 0xDFFF) return true;
      i++; // paire valide : on saute la basse
    } else if (c >= 0xDC00 && c <= 0xDFFF) {
      return true; // basse orpheline
    }
  }
  return false;
}

Diagnosis _diagnosis({
  String disease = 'Mildiou de la pomme de terre',
  double confidence = 0.87,
  String advice = 'Enlevez les feuilles atteintes et pulvérisez.',
}) {
  return Diagnosis(
    id: 'd1',
    date: DateTime(2026, 10, 3),
    inputText: 'photo',
    disease: disease,
    confidence: confidence,
    advice: advice,
    rawAiResponse: '',
  );
}

void main() {
  group('diagnosisShareText — contenu', () {
    test('reprend maladie, confiance, traitement et la signature', () {
      final text = diagnosisShareText(_diagnosis());
      expect(text, contains('Diagnostic KultivIA'));
      expect(text, contains('Maladie : Mildiou de la pomme de terre'));
      expect(text, contains('Confiance : 87 %'));
      expect(text, contains('Traitement conseillé :'));
      expect(text, contains('Enlevez les feuilles atteintes'));
      expect(text.trim(), endsWith('Envoyé depuis KultivIA'));
    });

    test('confiance arrondie en pourcentage entier', () {
      expect(diagnosisShareText(_diagnosis(confidence: 0.874)), contains('Confiance : 87 %'));
      expect(diagnosisShareText(_diagnosis(confidence: 0.5)), contains('Confiance : 50 %'));
      expect(diagnosisShareText(_diagnosis(confidence: 0.0)), contains('Confiance : 0 %'));
    });

    test('confiance hors bornes bornée : jamais « 214 % »', () {
      // L'IA a déjà renvoyé des confidences en pourcentage (87) et d'autres
      // fois en fraction (0,87). Le message ne doit pas amplifier l'erreur.
      expect(diagnosisShareText(_diagnosis(confidence: 2.14)), contains('Confiance : 100 %'));
      expect(diagnosisShareText(_diagnosis(confidence: -0.5)), contains('Confiance : 0 %'));
    });

    test('maladie vide → « non déterminée » plutôt qu’une ligne creuse', () {
      expect(diagnosisShareText(_diagnosis(disease: '')), contains('Maladie : non déterminée'));
      expect(diagnosisShareText(_diagnosis(disease: '   ')), contains('Maladie : non déterminée'));
    });

    test('traitement vide → pas de ligne « Traitement conseillé »', () {
      final text = diagnosisShareText(_diagnosis(advice: ''));
      expect(text, isNot(contains('Traitement conseillé')));
      expect(text, contains('Maladie :')); // le reste du message tient
      expect(text.trim(), endsWith('Envoyé depuis KultivIA'));
    });

    test('traitement en plusieurs lignes réduit à une seule', () {
      final text = diagnosisShareText(_diagnosis(
        advice: 'Première ligne.\n\n- deuxième point\n- troisième point',
      ));
      // Le libellé est sur sa propre ligne ; c'est le traitement qui doit être
      // réduit à une seule ligne, pas l'ensemble du message.
      expect(
        text,
        contains('Traitement conseillé :\n'
            'Première ligne. - deuxième point - troisième point'),
      );
      expect(text.split('\n').where((l) => l.contains('deuxième')).length, 1);
    });

    test('espaces multiples écrasés', () {
      expect(
        diagnosisShareText(_diagnosis(disease: 'Mildiou    de   la  tomate')),
        contains('Maladie : Mildiou de la tomate'),
      );
    });

    test('ne lève jamais sur un diagnostic entièrement vide', () {
      final text = diagnosisShareText(
        _diagnosis(disease: '', advice: '', confidence: 0),
      );
      expect(text, contains('Maladie : non déterminée'));
      expect(text, contains('Confiance : 0 %'));
      expect(text, contains('Envoyé depuis KultivIA'));
    });
  });

  group('diagnosisShareText — troncature', () {
    test('traitement très long coupé et marqué', () {
      final text = diagnosisShareText(_diagnosis(advice: 'a' * 5000));
      expect(text, contains('…'));
      final adviceLine =
          text.split('\n').firstWhere((l) => l.startsWith('aaaaaaaaaa'));
      expect(adviceLine.length, shareAdviceMaxChars + 1); // 600 + « … »
    });

    test('maladie très longue coupée', () {
      final text = diagnosisShareText(_diagnosis(disease: 'b' * 900));
      expect(text, contains('…'));
      expect(text, isNot(contains('b' * 901)));
    });

    test('troncature ne coupe jamais un caractère UTF-16 au milieu', () {
      // 119 lettres, puis un émoji (2 unités UTF-16, 1 rune), puis du texte :
      // une troncation naïve au caractère 120 isolerait la moitié de l'emoji.
      final text = diagnosisShareText(
        _diagnosis(disease: '${'a' * 119}🌾${'b' * 40}'),
      );
      expect(text, contains('🌾'));
      expect(text, contains('…'));
      expect(_hasLoneSurrogate(text), isFalse);
    });

    test('le message complet reste très sous le plafond WhatsApp (4 096)', () {
      // L'invariant qui dispense d'un garde-fou de longueur dans le code.
      final text = diagnosisShareText(
        _diagnosis(disease: 'c' * 5000, advice: 'd' * 5000),
      );
      expect(text.length, lessThan(900));
    });
  });

  group('diagnosisWhatsAppUri', () {
    test('cible wa.me avec le message en query', () {
      final d = _diagnosis();
      final uri = diagnosisWhatsAppUri(d);
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], diagnosisShareText(d));
    });

    test('aucun numéro de destinataire dans le lien', () {
      // wa.me/?text=… ouvre le sélecteur de contact : c'est ce qui permet de
      // partager sans avoir coughé le numéro de quelqu'un.
      final uri = diagnosisWhatsAppUri(_diagnosis());
      expect(uri.path, '/');
    });

    test('accents, esperluettes et sauts de ligne survivent au voyage', () {
      final d = _diagnosis(
        disease: 'Mildiou & Phytophthora',
        advice: 'Pulvériser à 100 % ? Vérifier #travail\nPuis surveiller.',
      );
      final uri = diagnosisWhatsAppUri(d);
      final raw = uri.toString();

      // Le « & » et le « # » DOIVENT être encodés : bruts, le premier couperait
      // le message en deux paramètres et le second le réduirait à une ancre
      // dans le navigateur — le destinataire ne verrait plus que « Maladie : ».
      expect(raw, contains('%26'));
      expect(raw, contains('%23'));
      // Aucun espace ni saut de ligne brut dans la query.
      expect(raw, isNot(contains(' ')));
      expect(raw, isNot(contains('\n')));
      // Et le texte décodé est exactement celui qu'on voulait partager.
      expect(uri.queryParameters['text'], diagnosisShareText(d));
    });

    test('un diagnostic vide produit quand même un lien exploitable', () {
      final uri = diagnosisWhatsAppUri(_diagnosis(disease: '', advice: ''));
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], isNotEmpty);
    });
  });
}