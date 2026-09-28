// Service IA RodiumAI. Issue GitHub : #TODO
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';

import '../system/user_settings.dart';

/// Encapsule tous les appels à l'IA (RodiumAI) pour KultivIA.
class RodiumAiService {
  RodiumAiService({FirebaseFunctions? functions}) : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;
  FirebaseFunctions get _functions => _functionsOverride ?? FirebaseFunctions.instance;

  Future<String> _callProxy({
    required List<dynamic> messages,
    double temperature = 0.3,
    int maxTokens = 500,
    String? language,
  }) {
    throw UnimplementedError();
  }

  Future<Uint8List> synthesizeSpeech({required String text, String languageCode = 'fr'}) {
    throw UnimplementedError();
  }

  Future<String> transcribeAudio({
    required Uint8List bytes,
    String mime = 'audio/mp4',
    String languageCode = 'fr',
  }) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> diagnoseFromImage({
    required String imagePath,
    String description = '',
    String languageCode = 'fr',
  }) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> diagnoseFromText({
    required String description,
    String languageCode = 'fr',
  }) {
    throw UnimplementedError();
  }

  Future<String> chatWithAvatar({
    required List<Map<String, String>> history,
    String languageCode = 'fr',
  }) {
    throw UnimplementedError();
  }
}

/// Extrait un objet JSON de la réponse texte de l'IA.
Map<String, dynamic> parseAiJsonResponse(String raw) {
  throw UnimplementedError();
}
