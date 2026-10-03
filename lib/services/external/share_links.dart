/// Partage d'un diagnostic par WhatsApp (issue B7).
///
/// Comme [vendor_links.dart] : uniquement des fonctions pures, donc testables
/// sans téléphone et sans plugin. L'ouverture se fait côté écran avec
/// `url_launcher`.
///
/// Choix de rédaction, à connaître avant de modifier :
///
/// - Le message est **court** et en texte brut, sans émoji : il doit survivre à
///   un copier-coller dans un SMS ou une note, et rester lisible dans une
///   discussion de groupe. L'usage visé est de prévenir un conseiller agricole
///   ou un voisin, pas de transmettre un rapport.
/// - **Pas de date.** Le paysan partage le diagnostic du jour, la date
///   n'apporte rien, et son formatage devrait être traduit (issue D7).
/// - Le traitement est tronqué : l'IA peut répondre sur un paragraphe entier,
///   et 2 000 caractères ne sont plus partageables.
library;

import '../../models/diagnosis.dart';

/// Longueur maximale du nom de la maladie repris dans le message.
const int shareDiseaseMaxChars = 120;

/// Longueur maximale du traitement repris dans le message.
///
/// Gabarit ≈ 70 caractères + 120 + 600 ⇒ le message ne dépasse jamais ~800
/// caractères, très en dessous du plafond de 4 096 caractères de WhatsApp.
/// Un test verrouille cette borne ; inutile de re-contrôler à chaque appel.
const int shareAdviceMaxChars = 600;

/// Met les espaces et sauts de ligne sur une seule ligne.
///
/// Un traitement renvoyé par l'IA arrive souvent en Markdown ou en liste à
/// puces. Coller ces sauts dans un message WhatsApp produit un pavé illisible.
String _collapseWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Tronque sans jamais couper un surrogate pair (un emoji compte pour deux
/// `char` mais un seul `rune`) : un caractère isolé s'afficherait en carré.
String _truncate(String value, int maxChars) {
  final runes = value.runes.toList();
  if (runes.length <= maxChars) return value;
  return '${String.fromCharCodes(runes.take(maxChars)).trimRight()}…';
}

/// Message à partager pour un diagnostic.
///
/// Ne lève jamais : un diagnostic incomplet (maladie vide, conseil absent)
/// donne un message plus court, jamais une exception. Le paysan a déjà le
/// diagnostic sous les yeux, il ne doit pas échouer à le transmettre.
String diagnosisShareText(Diagnosis d) {
  final disease =
      _truncate(_collapseWhitespace(d.disease), shareDiseaseMaxChars);
  final advice =
      _truncate(_collapseWhitespace(d.advice), shareAdviceMaxChars);
  // Même bornage que l'écran de résultat : un message ne doit pas annoncer
  // « 214 % » parce que la confiance est arrivée en 2,14 depuis l'IA.
  final confidence = (d.confidence.clamp(0.0, 1.0) * 100).round();

  final lines = <String>[
    'Diagnostic KultivIA',
    'Maladie : ${disease.isEmpty ? 'non déterminée' : disease}',
    'Confiance : $confidence %',
  ];

  if (advice.isNotEmpty) {
    lines
      ..add('Traitement conseillé :')
      ..add(advice);
  }

  lines.add('Envoyé depuis KultivIA');

  return lines.join('\n');
}

/// Lien de partage WhatsApp du diagnostic.
///
/// `https://wa.me/?text=…` ouvre d'abord le sélecteur de contact : c'est le
/// seul lien stable documenté par WhatsApp et il n'exige aucun numéro.
/// `Uri.https` encode la query, donc un traitement contenant des accents, des
/// espaces ou un « & » arrive intact chez le destinataire.
Uri diagnosisWhatsAppUri(Diagnosis d) =>
    Uri.https('wa.me', '/', {'text': diagnosisShareText(d)});