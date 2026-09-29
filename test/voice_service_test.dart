import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/services/ui/voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('prepareSpeechText', () {
    test('retire la mise en forme markdown et les espaces en trop', () {
      expect(
        prepareSpeechText('**Mildiou** :\n\n  traitez  la plante'),
        'Mildiou : traitez la plante',
      );
    });

    test('nettoie les marqueurs markdown', () {
      expect(
        prepareSpeechText('# Conseil *important* `agriculture`'),
        'Conseil important agriculture',
      );
    });

    test('ne modifie pas un texte court', () {
      const text = 'Arrosez vos cultures le matin.';
      expect(prepareSpeechText(text), text);
    });

    test('coupe en fin de phrase quand le texte est trop long', () {
      final long = '${'Arrosez le matin. ' * 60}Fin sans point';

      final out = prepareSpeechText(long);

      expect(out.length, lessThanOrEqualTo(maxSpeechChars));
      expect(out.endsWith('.'), isTrue);
    });

    test(
        'fait une coupure stricte à 600 caractères si aucune phrase '
        'suffisamment longue n’est disponible', () {
      final long = 'A' * 700;

      final out = prepareSpeechText(long);

      expect(out.length, maxSpeechChars);
    });

    test('un texte vide reste vide', () {
      expect(prepareSpeechText('  *  '), '');
    });
  });

  group('VoiceService', () {
    test('utilise une instance singleton', () {
      final first = VoiceService();
      final second = VoiceService();

      expect(identical(first, second), isTrue);
    });

    test('chaque langue gérée a une phrase d’accueil', () {
      for (final code in ['fr', 'en', 'wo']) {
        expect(VoiceService.greetings[code], isNotNull);
        expect(VoiceService.greetings[code], isNotEmpty);
      }
    });

    test('les langues cloud contiennent le wolof', () {
      expect(VoiceService.cloudLanguages.contains('wo'), isTrue);
    });
  });
}
