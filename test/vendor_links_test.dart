import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/services/external/vendor_links.dart';

void main() {
  // ---------- vendorPhoneDigits ----------

  group('vendorPhoneDigits', () {
    test('null → null', () {
      expect(vendorPhoneDigits(null), isNull);
    });

    test('vide → null', () {
      expect(vendorPhoneDigits(''), isNull);
    });

    test('9 chiffres → 221 + 9 chiffres (sénégalais)', () {
      expect(vendorPhoneDigits('772008031'), '221772008031');
    });

    test('avec espaces et + → nettoyé', () {
      expect(vendorPhoneDigits('+221 77 200 80 31'), '221772008031');
    });

    test('moins de 11 chiffres → null', () {
      expect(vendorPhoneDigits('123'), isNull);
      expect(vendorPhoneDigits('1234567890'), isNull); // 10 chiffres
    });

    test('11 chiffres → gardé tel quel', () {
      expect(vendorPhoneDigits('221772008031'), '221772008031');
    });
  });

  // ---------- vendorTelUri ----------

  group('vendorTelUri', () {
    test('mobile → tel:+221...', () {
      final uri = vendorTelUri('+221 77 200 80 31');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'tel');
      expect(uri.path, '+221772008031');
    });

    test('null → null', () {
      expect(vendorTelUri(null), isNull);
    });

    test('court → null', () {
      expect(vendorTelUri('12'), isNull);
    });
  });

  // ---------- vendorWhatsAppUri ----------

  group('vendorWhatsAppUri', () {
    test('mobile 77 → wa.me/22177...', () {
      final uri = vendorWhatsAppUri('+221 77 200 80 31');
      expect(uri, isNotNull);
      expect(uri!.host, 'wa.me');
      expect(uri.path, '/221772008031');
    });

    test('mobile 78 → ok', () {
      expect(vendorWhatsAppUri('+221 78 186 74 87'), isNotNull);
    });

    test('fixe 33 → null (pas de WhatsApp)', () {
      expect(vendorWhatsAppUri('+221 33 822 84 64'), isNull);
    });

    test('9 chiffres (77...) → 221 préfixé, WhatsApp ok', () {
      expect(vendorWhatsAppUri('772008031'), isNotNull);
    });

    test('court → null', () {
      expect(vendorWhatsAppUri('12'), isNull);
    });

    test('avec message → ?text=...', () {
      final uri = vendorWhatsAppUri('+221 77 200 80 31',
          message: 'Bonjour, je vous contacte depuis KultivIA.');
      expect(uri, isNotNull);
      expect(uri!.queryParameters['text'],
          'Bonjour, je vous contacte depuis KultivIA.');
    });

    test('sans message → pas de query', () {
      final uri = vendorWhatsAppUri('+221 77 200 80 31');
      expect(uri, isNotNull);
      expect(uri!.queryParameters, isEmpty);
    });
  });

  // ---------- vendorDirectionsUri ----------

  group('vendorDirectionsUri', () {
    test('coordonnées → maps/dir/?api=1&destination=lat,lng', () {
      final uri = vendorDirectionsUri(14.67, -17.43);
      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '14.67,-17.43');
    });

    test('latitude manquante → null', () {
      expect(vendorDirectionsUri(null, -17.43), isNull);
    });

    test('longitude manquante → null', () {
      expect(vendorDirectionsUri(14.67, null), isNull);
    });

    test('les deux manquantes → null', () {
      expect(vendorDirectionsUri(null, null), isNull);
    });
  });
}
