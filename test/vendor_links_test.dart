import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/data/vendors_seed.dart';
import 'package:kultivia/services/vendor_links.dart';

void main() {
  group('liens de contact', () {
    test('appel : numéro au format international', () {
      expect(vendorTelUri('+221 77 200 80 31').toString(), 'tel:+221772008031');
      expect(vendorTelUri('77 200 80 31').toString(), 'tel:+221772008031');
      expect(vendorTelUri(''), isNull);
      expect(vendorTelUri(null), isNull);
    });

    test('WhatsApp seulement pour les mobiles', () {
      final mobile = vendorWhatsAppUri('+221 77 200 80 31', message: 'Bonjour');
      expect(mobile.toString(), 'https://wa.me/221772008031?text=Bonjour');
      expect(vendorWhatsAppUri('+221 33 822 84 64'), isNull);
    });

    test('itinéraire vers les coordonnées', () {
      final uri = vendorDirectionsUri(14.67, -17.43)!;
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['destination'], '14.67,-17.43');
      expect(vendorDirectionsUri(null, 1), isNull);
    });
  });

  test('chaque point de vente intégré a un nom, des coordonnées et un téléphone valide', () {
    final names = <String>{};
    for (final v in vendorsSeed) {
      expect(names.add(v['name'] as String), isTrue, reason: 'nom en double : ${v['name']}');
      expect(v['latitude'], isA<num>());
      expect(v['longitude'], isA<num>());
      expect(vendorTelUri(v['phone'] as String), isNotNull, reason: v['name'] as String);
    }
  });
}
