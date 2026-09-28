import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('toMap / fromMap conservent les données', () {
      const p = UserProfile(
        displayName: 'Awa Diop',
        role: 'vendor',
        locality: 'Thiès',
        crops: ['Mil', 'Tomate'],
        languageCode: 'wo',
        notificationsEnabled: true,
        voiceReplies: true,
        completed: true,
      );
      final back = UserProfile.fromMap(p.toMap());
      expect(back.displayName, 'Awa Diop');
      expect(back.role, 'vendor');
      expect(back.crops, ['Mil', 'Tomate']);
      expect(back.languageCode, 'wo');
      expect(back.voiceReplies, isTrue);
      expect(back.completed, isTrue);
    });

    test('un document incomplet donne un profil non terminé', () {
      final p = UserProfile.fromMap({'displayName': 'Moussa'});
      expect(p.completed, isFalse);
      expect(p.languageCode, 'fr');
      expect(p.firstName, 'Moussa');
      expect(p.voiceReplies, isFalse);
    });
  });
}
