import 'dart:convert';
import 'dart:io';
import '../../core/config/app_config.dart';
import '../../languages/registry.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Encapsule tous les appels à l'IA (RodiumAI) pour KultivIA :
/// - diagnostic à partir d'une photo (vision)
/// - diagnostic à partir d'une description texte ou vocale
/// - conversation libre avec l'avatar
///
/// IMPORTANT — sécurité : cette classe n'appelle JAMAIS RodiumAI
/// directement depuis le téléphone (la clé serait extractible de l'APK).
/// Tout passe par une fonction serveur qui garde la clé côté serveur.
///
/// Deux backends possibles :
/// - Supabase Edge Functions (par défaut, gratuit) : supabase/functions/
/// - Firebase Cloud Functions (secours, exige le plan Blaze)
class RodiumAiService {
  RodiumAiService({FirebaseFunctions? functions, http.Client? client})
      : _functionsOverride = functions,
        _clientOverride = client;

  final FirebaseFunctions? _functionsOverride;
  final http.Client? _clientOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  /// Utiliser les Cloud Functions Firebase au lieu des Edge Functions Supabase.
  /// Utile si Supabase est indisponible ; le déploiement Firebase exige
  /// le plan Blaze.
  static bool get useFirebaseBackend =>
      AppConfig.aiBackend.toLowerCase() == 'firebase';

  // ------------------------------------------------------------- Transport

  String get _supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://hyvhwsclfjnnbrpdsypt.supabase.co';

  String get _anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  http.Client get _client => _clientOverride ?? http.Client();

  /// Jeton de session de l'utilisateur connecté. Sans lui, les Edge
  /// Functions refusent l'appel : la clé RodiumAI reste protégée.
  ///
  /// L'application accepte deux fournisseurs d'identité. On essaie d'abord
  /// Supabase ; si l'utilisateur s'est connecté avec Firebase (cas le plus
  /// fréquent aujourd'hui), on renvoie son jeton Firebase, que les Edge
  /// Functions savent aussi vérifier.
  Future<String?> _accessToken() async {
    final supabaseToken =
        Supabase.instance.client.auth.currentSession?.accessToken;

    if (supabaseToken != null && supabaseToken.isNotEmpty) {
      return supabaseToken;
    }

    return _firebaseIdToken();
  }

  /// Jeton Firebase de l'utilisateur connecté, ou null s'il n'y en a pas.
  Future<String?> _firebaseIdToken() async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (_) {
      // Firebase peut ne pas être initialisé (voir main.dart) : dans ce
      // cas l'appel IA est refusé plus bas avec un message clair.
      return null;
    }
  }

  /// Appel à une Edge Function Supabase, avec le jeton d'authentification.
  Future<Map<String, dynamic>> _invokeSupabase(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final token = await _accessToken();

    if (token == null || token.isEmpty) {
      throw StateError('Connexion requise.');
    }

    final uri = Uri.parse(
      '$_supabaseUrl/functions/v1/$functionName',
    );

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'apikey': _anonKey,
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Connexion requise.');
    }

    if (response.statusCode != 200) {
      throw StateError('Service IA indisponible.');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw StateError('Réponse invalide du service IA.');
    }

    // Les erreurs applicatives sont renvoyées en JSON avec un statut 4xx/5xx.
    if (decoded['error'] != null) {
      throw StateError(decoded['error'].toString());
    }

    return Map<String, dynamic>.from(decoded);
  }

  /// Appel à une Cloud Function Firebase (secours).
  Future<Map<String, dynamic>> _invokeFirebase(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final callable = _functions.httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
    );

    final result = await callable.call(body);

    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Route l'appel vers le bon backend.
  Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) {
    if (useFirebaseBackend) {
      return _invokeFirebase(functionName, body);
    }

    return _invokeSupabase(functionName, body);
  }

  static String _languageName(String code) => languagePackFor(code).name;

  /// Consignes communes : les réponses sont LUES À VOIX HAUTE à des
  /// utilisateurs qui ne savent parfois pas lire.
  static String _spokenStyle(String languageCode) => '''
Tes réponses seront lues À VOIX HAUTE à des
utilisateurs qui ne savent parfois pas lire.
Phrases courtes, mots simples, pas de
symboles, pas de listes, pas de markdown, pas d'emoji. Écris les unités en
toutes lettres (litre, gramme, jour).
${languagePackFor(languageCode).spokenStyleHint}
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
    bool jsonMode = false,
    bool allowRetry = true,
  }) async {
    final data = await _invoke('ai-proxy', {
      'messages': messages,
      'temperature': temperature,
      'maxTokens': maxTokens,
      if (language != null) 'language': language,
      if (jsonMode) 'jsonMode': true,
    });

    final content = (data['content'] ?? '').toString();

    // ai-proxy signale `truncated: true` quand le fournisseur a coupe la
    // generation (finish_reason = "length"). Constate en production : la
    // reponse s'arretait vers 50 caracteres, au milieu du JSON, sans
    // rapport avec le budget demande — et de facon aleatoire.
    //
    // Relancer une fois est efficace : le meme appel peut aboutir entier.
    // On ne boucle pas : au-dela, c'est un panne du fournisseur, et
    // farmer une reponse qui met 2 minutes a s'afficher est pire que
    // d'afficher la reponse tronquee, que parseAiJsonResponse() sait
    // reparer.
    if (data['truncated'] == true && allowRetry) {
      debugPrint(
        'IA : reponse tronquee (finishReason=${data['finishReason']}), '
        'une nouvelle tentative est lancee.',
      );

      return _callProxy(
        messages: messages,
        temperature: temperature,
        maxTokens: maxTokens,
        language: language,
        jsonMode: jsonMode,
        allowRetry: false,
      );
    }

    if (data['truncated'] == true) {
      debugPrint(
        'IA : reponse toujours tronquee apres relance '
        '(finishReason=${data['finishReason']}), retour au parseur repare.',
      );
    }

    return content;
  }

  /// Synthèse vocale (RodiumAI). Renvoie les octets d'un fichier mp3 prêt
  /// à être lu. Utilisée pour le wolof et le lingala, que le téléphone ne
  /// sait pas produire.
  Future<Uint8List> synthesizeSpeech(
      {required String text, String languageCode = 'fr'}) async {
    final data = await _invoke('ai-speech', {
      'text': text,
      'language': languageCode,
    });

    return base64Decode((data['audio'] ?? '').toString());
  }

  /// Reconnaissance vocale (RodiumAI). Utilisée pour dicter en wolof ou en
  /// lingala, que le téléphone ne sait pas écouter.
  Future<String> transcribeAudio({
    required Uint8List bytes,
    String mime = 'audio/mp4',
    String languageCode = 'fr',
  }) async {
    final data = await _invoke('ai-transcribe', {
      'audio': base64Encode(bytes),
      'mime': mime,
      'language': languageCode,
    });

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
    final mimeType = imageFile.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

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

    // 800 tokens : le plafond de ai-proxy. À 500, Gemini « pense » puis écrit
    // le traitement et se fait couper au milieu de l'objet JSON — la réponse
    // est alors illisible et l'agriculteur voit du JSON brut.
    final content = await _callProxy(
      messages: messages,
      language: languageCode,
      jsonMode: true,
      maxTokens: 800,
    );
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
    final content = await _callProxy(
      messages: messages,
      language: languageCode,
      jsonMode: true,
      maxTokens: 800,
    );
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
    return _callProxy(
        messages: messages,
        temperature: 0.6,
        maxTokens: 300,
        language: languageCode);
  }
}

/// Extrait un objet JSON de la réponse texte de l'IA. Exposée au niveau
/// module (et non privée) pour être testable unitairement — voir
/// test/rodium_ai_service_test.dart.
///
/// La version d'origine faisait `jsonDecode(cleaned)` et, en cas d'échec,
/// renvoyait le texte BRUT. L'agriculteur voyait donc le JSON lui-même à
/// l'écran : `{"maladie":"Mildiou","confiance":0.8,...}`. C'est arrivé en
/// production, et deux causes étaient possibles — du texte autour du JSON, ou
/// un JSON tronqué par la limite de tokens.
///
/// D'où les trois tentatives ci-dessous, de la plus stricte à la plus
/// tolérante. Le dernier recours ne montre plus jamais de JSON brut.
Map<String, dynamic> parseAiJsonResponse(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'```json', caseSensitive: false), '')
      .replaceAll('```', '')
      .trim();

  final direct = _tryDecodeObject(cleaned);
  if (direct != null) return direct;

  final extracted = _extractFirstJsonObject(cleaned);
  if (extracted != null) {
    final parsed = _tryDecodeObject(extracted);
    if (parsed != null) return parsed;
  }

  // Objet coupé en plein milieu : on récupère les paires "clé": "valeur"
  // telles qu'elles ont pu être écrites. Le guillemet fermant est OPTIONNEL
  // dans le motif : c'est ce qui permet de sauver une valeur tronquée, par
  // exemple le champ "traitement" coupé après quelques mots — encore
  // parfaitement utile à l'agriculteur.
  final salvaged = _salvageKeyValues(cleaned);
  if (salvaged != null) return salvaged;

  // Sinon on tente de refermer l'objet.
  final repaired = _repairTruncatedJson(cleaned);
  if (repaired != null) {
    final parsed = _tryDecodeObject(repaired);
    if (parsed != null) return parsed;
  }

  return {
    'reponse_avatar': _humanReadableFallback(raw),
    'maladie': 'Indéterminé',
    'confiance': 0.0,
  };
}

/// Récupère les paires `"clé": "valeur"` d'une réponse éventuellement
/// tronquée. Les guillemets de fin sont facultatifs pour ne pas perdre le
/// dernier champ écrit à moitié.
Map<String, dynamic>? _salvageKeyValues(String source) {
  final pattern = RegExp(r'"([^"\\]+)"\s*:\s*"((?:[^"\\]|\\.)*)"?');
  final result = <String, dynamic>{};

  for (final match in pattern.allMatches(source)) {
    final value = match
        .group(2)!
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', '\n')
        .trim();

    if (value.isNotEmpty) result[match.group(1)!] = value;
  }

  return result.isEmpty ? null : result;
}

Map<String, dynamic>? _tryDecodeObject(String source) {
  try {
    final decoded = jsonDecode(source);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Premier objet `{...}` équilibré, en ignorant les accolades situées dans les
/// chaînes. Gère les accolades imbriquées (un objet dans "traitement").
String? _extractFirstJsonObject(String source) {
  final start = source.indexOf('{');
  if (start < 0) return null;

  var depth = 0;
  var inString = false;
  var escaped = false;

  for (var i = start; i < source.length; i++) {
    final c = source[i];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }

    if (c == '"') {
      inString = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }

  return null;
}

/// Referme un objet coupé en cours de génération : on ferme la chaîne en
/// cours, puis on empile les accolades manquantes.
String? _repairTruncatedJson(String source) {
  final start = source.indexOf('{');
  if (start < 0) return null;

  var depth = 0;
  var inString = false;
  var escaped = false;

  // Index juste après la dernière virgule de premier niveau, et la
  // profondeur à cet endroit.
  var cutAt = -1;
  var depthAtCut = 0;

  for (var i = start; i < source.length; i++) {
    final c = source[i];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }

    if (c == '"') {
      inString = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
    } else if (c == ',' && depth == 1) {
      // Index de la virgule ELLE-MÊME : la couper en deux laisserait une
      // virgule orpheline et {"maladie": "X",} reste du JSON invalide.
      cutAt = i;
      depthAtCut = depth;
    }
  }

  if (depth == 0) return null;

  // On coupe au dernier endroit sûr — une virgule de premier niveau est
  // forcément hors chaîne — ce qui ne conserve que des paires clé/valeur
  // complètes. Refermer sur une valeur incomplète ne suffit pas :
  // {"maladie": "Rouille", "confiance": 0.  fermé en 0."}  échoue encore.
  // Ici, on garde "maladie" et on abandonne le champ coupé.
  if (cutAt > start) {
    return '${source.substring(start, cutAt)}${'}' * depthAtCut}';
  }

  return '${source.substring(start)}${inString ? '"' : ''}${'}' * depth}';
}

/// Dernier filet : plus aucun JSON brut ne doit atteindre l'écran. On ne garde
/// que la première ligne utile, et on masque les accolades.
String _humanReadableFallback(String raw) {
  final text = raw
      .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
      .replaceAll('```', '')
      .trim();

  if (text.isEmpty) return 'Je n\'ai pas pu comprendre la réponse.';

  // Une réponse qui sent encore le JSON ne doit jamais être affichée telle
  // quelle — même TRONQUÉE, donc même sans accolade fermante. Le test
  // d'origine exigeait `endsWith('}')`, ce qui laissait précisément passer le
  // cas rencontré par l'agriculteur : une réponse coupée net.
  if (text.contains('{') || text.contains('":')) {
    return "Je n'ai pas pu terminer l'analyse. "
        "Pouvez-vous recommencer avec une photo plus nette de la feuille ?";
  }

  return text;
}
