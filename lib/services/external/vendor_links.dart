/// Liens de contact d'un point de vente : appel, WhatsApp, itinéraire.
/// Fonctions pures (testables) ; l'ouverture se fait avec `url_launcher`.

/// Numéro au format international sans « + » (ex. `221772008031`), ou `null`.
/// Un numéro à 9 chiffres est considéré comme sénégalais.
String? vendorPhoneDigits(String? phone) {
  if (phone == null) return null;
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  if (d.length == 9) d = '221$d';
  return d.length >= 11 ? d : null;
}

Uri? vendorTelUri(String? phone) {
  final d = vendorPhoneDigits(phone);
  return d == null ? null : Uri.parse('tel:+$d');
}

/// WhatsApp n'existe que sur mobile : au Sénégal, les mobiles commencent par
/// 7 (70, 75, 76, 77, 78). Les fixes (33...) n'ont pas de lien WhatsApp.
Uri? vendorWhatsAppUri(String? phone, {String message = ''}) {
  final d = vendorPhoneDigits(phone);
  if (d == null || !d.startsWith('221') || d.length < 12 || !d.substring(3).startsWith('7')) return null;
  return Uri.https('wa.me', '/$d', message.isEmpty ? null : {'text': message});
}

Uri? vendorDirectionsUri(num? latitude, num? longitude) {
  if (latitude == null || longitude == null) return null;
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
  });
}
