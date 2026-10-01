/// Intentions simples que l'avatar comprend sans appeler l'IA.

final _cameraWords = RegExp(
  r'(?<!\p{L})(photos?|foto|cam[eé]ra|kamera|nataal|pictures?)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

/// Vrai si le message demande d'ouvrir l'appareil photo (« photo »,
/// « caméra », « foto »...). « photosynthèse » ne compte pas.
bool looksLikeCameraRequest(String text) => _cameraWords.hasMatch(text);

/// Ce que dit l'avatar avant d'ouvrir l'appareil photo.
/// Le wolof est à faire relire par un locuteur natif.
String cameraReply(String languageCode) {
  switch (languageCode) {
    case 'en':
      return 'Okay, opening the camera. Take a picture of the sick leaf or plant.';
    case 'wo':
      return 'Waaw, dinaa ubbi kamera bi. Jël foto ci xob wi.';
    default:
      return "D'accord, j'ouvre l'appareil photo. Prenez la feuille ou la plante malade en photo.";
  }
}