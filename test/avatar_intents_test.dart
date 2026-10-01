import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/services/ai/avatar_intents.dart';

void main() {
  test('reconnaît une demande d\'appareil photo', () {
    for (final t in ['photo', 'Je veux prendre une photo', 'ouvre la caméra', 'camera', 'foto', 'appareil photo', 'Mets une PHOTO']) {
      expect(looksLikeCameraRequest(t), isTrue, reason: t);
    }
  });

  test('ne se déclenche pas sur d\'autres mots', () {
    for (final t in ['Comment marche la photosynthèse ?', 'Mes feuilles jaunissent', 'diagnostiquer']) {
      expect(looksLikeCameraRequest(t), isFalse, reason: t);
    }
  });

  test('une réponse existe pour chaque langue', () {
    for (final code in ['fr', 'en', 'wo', 'xx']) {
      expect(cameraReply(code), isNotEmpty);
    }
  });
}