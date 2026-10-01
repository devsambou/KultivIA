import '../../languages/registry.dart';

/// Vrai si le message demande d'ouvrir l'appareil photo (« photo »,
/// « caméra », « foto »...). « photosynthèse » ne compte pas.
bool looksLikeCameraRequest(String text) {
  final normalized = text.toLowerCase().trim();
  if (normalized.isEmpty) return false;

  for (final pack in languagePacks) {
    for (final word in pack.cameraWords) {
      final pattern = RegExp(
        r'(?<!\p{L})' + RegExp.escape(word.toLowerCase()) + r'(?!\p{L})',
        caseSensitive: false,
        unicode: true,
      );
      if (pattern.hasMatch(normalized)) return true;
    }
  }
  return false;
}

/// Ce que dit l'avatar avant d'ouvrir l'appareil photo.
/// Le wolof est à faire relire par un locuteur natif.
String cameraReply(String languageCode) {
  return languagePackFor(languageCode).cameraReply;
}
