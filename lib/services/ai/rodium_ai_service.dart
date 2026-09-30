import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';

import '../system/user_settings.dart';

/// Encapsule tous les appels à l'IA (RodiumAI) pour KultivIA :
/// - diagnostic à partir d'une photo (vision)
/// - diagnostic à partir d'une description texte ou vocale
/// - conversation libre avec l'avatar
///
/// IMPORTANT — sécurité : cette classe n'appelle JAMAIS RodiumAI
/// directement depuis le téléphone (la clé serait extractible de l'APK).
/// Tout passe par la Cloud Function `aiProxy` (voir functions/index.js),
/// qui garde la clé côté serveur.
class RodiumAiService {
  RodiumAiService({FirebaseFunctions? functions}) : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;
  FirebaseFunctions get _functions => _functionsOverride ?? FirebaseFunctions.instance;

  static String _languageName(String code) => UserSettings.supportedLanguages[code] ?? code;

  /// Consignes communes : les réponses sont LUES À VOIX HAUTE à des
  /// utilisateurs qui ne savent parfois pas lire.
  static String _spokenStyle(String languageCode) => '''
Tes réponses seront lues à voix haute : phrases courtes, mots simples, pas de
symboles, pas de listes, pas de markdown, pas d'emoji. Écris les unités en
toutes lettres (litre, gramme, jour).${languageCode == 'wo' ? '''
Écris en wolof courant (alphabet latin officiel). Si tu n'es pas sûr d'un mot
technique en wolof, garde le mot français plutôt que d'inventer.''' : ''}
''';

  static String _diagnosisPrompt(String languageCode) => '''
Tu es l'avatar conversationnel de KultivIA, une application qui aide les
petits agriculteurs à diagnostiquer les maladies de leurs cultures.
Réponds toujours en te limitant STRICTEMENT à un objet JSON valide, sans texte
autour, avec les clés suivantes :
{
  "maladie": "nom de la maladie identifiée, ou 'Indéterminé'",
  "confiance": 0.0 à 1.0,
  "traitement": "conseil de traitement clair et actionnable, en langage simple",
  "reponse_avatar": "phrase courte, chaleureuse, à afficher à l'agriculteur"
}
Rédige "traitement" et "reponse_avatar" en ${_languageName(languageCode)}.
"reponse_avatar" résume à l'oral, en deux ou trois phrases, la maladie et
la première chose à faire.
${_spokenStyle(languageCode)}Si l'image ou la description est insuffisante, demande une précision dans
"reponse_avatar" et mets "maladie": "Indéterminé".
''';

  static String _chatPrompt(String languageCode) => '''
Tu es l'avatar de KultivIA, assistant des petits agriculteurs. Réponds en
${_languageName(languageCode)}, en trois phrases simples et chaleureuses au
maximum, sans markdown. Si l'utilisateur décrit un symptôme de plante,
invite-le à ajouter une photo (bouton +) ou à dire « diagnostiquer » pour
lancer l'analyse.
${_spokenStyle(languageCode)}''';

  Future<String> _callProxy({
    required List<dynamic> messages,
    double temperature = 0.3,
    int maxTokens = 500,
    String? language,
  }) async {
    final callable = _functions.httpsCallable('aiProxy');
    final result = await callable.call({
      'messages': messages,
      'temperature': temperature,
      'maxTokens': maxTokens,
      if (language != null) 'language': language,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['content'] ?? '').toString();
  }

  /// Synthèse vocale (RodiumAI, via la Cloud Function `aiSpeech`).
  /// Renvoie les octets d'un fichier mp3 prêt à être lu.
  Future<Uint8List> synthesizeSpeech({required String text, String languageCode = 'fr'}) async {
    final callable = _functions.httpsCallable(
      'aiSpeech',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
    );
    final result = await callable.call({'text': text, 'language': languageCode});
    final data = Map<String, dynamic>.from(result.data as Map);
    return base64Decode((data['audio'] ?? '').toString());
  }

  /// Reconnaissance vocale (RodiumAI, via la Cloud Function `aiTranscribe`).
  Future<String> transcribeAudio({
    required Uint8List bytes,
    String mime = 'audio/mp4',
    String languageCode = 'fr',
  }) async {
    final callable = _functions.httpsCallable(
      'aiTranscribe',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
    );
    final result = await callable.call({
      'audio': base64Encode(bytes),
      'mime': mime,
      'language': languageCode,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['text'] ?? '').toString();
  }

  /// Diagnostic à partir d'une photo + description optionnelle.
  Future<Map<String, dynamic>> diagnoseFromImage({
    required File imageFile,
    String description = '',
    String languageCode = 'fr',
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = imageFile.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    final messages = [
      {'role': 'system', 'content': _diagnosisPrompt(languageCode)},
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text': description.isEmpty
                ? 'Diagnostique cette culture à partir de la photo.'
                : 'Diagnostique cette culture. Description de l\'agriculteur : $description',
          },
          {
            'type': 'image_url',
            'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
          },
        ],
      },
    ];

    final content = await _callProxy(messages: messages, language: languageCode);
    return parseAiJsonResponse(content);
  }

  /// Diagnostic à partir d'une description texte ou vocale (déjà transcrite),
  /// sans photo.
  Future<Map<String, dynamic>> diagnoseFromText({
    required String description,
    String languageCode = 'fr',
  }) async {
    final messages = [
      {'role': 'system', 'content': _diagnosisPrompt(languageCode)},
      {'role': 'user', 'content': description},
    ];
    final content = await _callProxy(messages: messages, language: languageCode);
    return parseAiJsonResponse(content);
  }

  /// Conversation libre avec l'avatar. [history] : messages précédents au
  /// format `{'role': 'user'|'assistant', 'content': '...'}`, le dernier
  /// étant le message de l'utilisateur.
  Future<String> chatWithAvatar({
    required List<Map<String, String>> history,
    String languageCode = 'fr',
  }) async {
    final messages = [
      {'role': 'system', 'content': _chatPrompt(languageCode)},
      ...history,
    ];
    return _callProxy(messages: messages, temperature: 0.6, maxTokens: 300, language: languageCode);
  }
}

/// Extrait un objet JSON de la réponse texte de l'IA. Exposée au niveau
/// module (et non privée) pour être testable unitairement — voir
/// test/rodium_ai_service_test.dart.
Map<String, dynamic> parseAiJsonResponse(String raw) {
  try {
    final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final decoded = jsonDecode(cleaned);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'reponse_avatar': raw};
  } catch (_) {
    return {'reponse_avatar': raw, 'maladie': 'Indéterminé', 'confiance': 0.0};
  }
}