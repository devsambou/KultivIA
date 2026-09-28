import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/services/voice_service.dart';

void main() {
  group('prepareSpeechText', () {
    test('retire la mise en forme markdown et les espaces en trop', () {
      expect(prepareSpeechText('**Mildiou** :\n\n  traitez  la plante'), 'Mildiou : traitez la plante');
    });

    test('coupe en fin de phrase quand le texte est trop long', () {
      final long = '${'Arrosez le matin. ' * 60}Fin sans point';
      final out = prepareSpeechText(long);
      expect(out.length, lessThanOrEqualTo(maxSpeechChars));
      expect(out.endsWith('.'), isTrue);
    });

    test('un texte vide reste vide', () {
      expect(prepareSpeechText('  *  '), '');
    });
  });

  test('chaque langue gérée a une phrase d\'accueil', () {
    for (final code in ['fr', 'en', 'wo']) {
      expect(VoiceService.greetings[code], isNotEmpty);
    }
  });
}
