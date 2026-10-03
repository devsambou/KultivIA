import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Réplique une écriture Firestore vers la copie Supabase.
///
/// ## Source de vérité
///
/// Firestore. Supabase reçoit une **copie**, alimentée après coup. Aucune lecture
/// de l'application ne va encore vers Supabase.
///
/// ## Contrat : best-effort, jamais bloquant
///
/// [mirrorUser] et [mirrorDiagnosis] ne lèvent **jamais**. Un utilisateur dont
/// le téléphone est hors ligne, dont le jeton a expiré ou dont Supabase est
/// indisponible doit voir son enregistrement Firestore réussir normalement.
/// C'est la raison d'être de cette classe : absorber l'échec ici plutôt que de
/// le propager aux écrans.
///
/// Conséquence assumée : une écriture faite hors ligne atteint Firestore mais
/// jamais Supabase. Le backfill (`tools/backfill.mjs`) rattrape cet écart.
/// Voir plans/double-ecriture-supabase.md.
///
/// ## Pourquoi un Edge Function et non un appel direct
///
/// Les politiques RLS de Supabase reposent sur `auth.uid()`, qui ne lit que les
/// jetons Supabase. Or les utilisateurs de KultivIA se connectent avec Firebase :
/// `auth.uid()` serait toujours null et toute écriture directe serait refusée.
/// Le téléphone appelle donc `sync-write`, qui vérifie lui-même le jeton et
/// utilise la clé `service_role` côté serveur.
///
/// ## Extensibilité
///
/// [fetch] et [idToken] sont injectables pour les tests : le test vérifie que
/// l'échec réseau ne bloque pas Firestore sans dépendre de Supabase.
class SupabaseMirror {
  SupabaseMirror({
    http.Client? client,
    Future<String?> Function()? idToken,
    Duration? timeout,
  })  : _clientOverride = client,
        _idTokenOverride = idToken,
        _timeout = timeout ?? _defaultTimeout;

  final http.Client? _clientOverride;
  final Future<String?> Function()? _idTokenOverride;
  final Duration _timeout;

  /// Délai court : la réplication ne doit pas retenir une ressource Flutter.
  /// Au-delà, on abandonne et le backfill rattrapera.
  static const Duration _defaultTimeout = Duration(seconds: 10);

  static const _defaultUrl = 'https://hyvhwsclfjnnbrpdsypt.supabase.co';

  /// `dotenv.env` lève une exception si le fichier n'a pas été chargé. Sans ce
  /// garde-fou, la réplication échouerait silencieusement dans ce cas au lieu de
  /// signaler une configuration incomplète.
  String get _supabaseUrl => _env('SUPABASE_URL') ?? _defaultUrl;

  String get _anonKey => _env('SUPABASE_ANON_KEY') ?? '';

  String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }

  http.Client get _client => _clientOverride ?? http.Client();

  /// Jeton de l'utilisateur connecté, Supabase d'abord puis Firebase.
  ///
  /// Même ordre que [RodiumAiService] : les deux fournisseurs sont acceptés, et
  /// les Edge Functions savent vérifier les deux.
  Future<String?> _accessToken() async {
    final injected = _idTokenOverride;
    if (injected != null) return injected();

    final supabaseToken =
        Supabase.instance.client.auth.currentSession?.accessToken;

    if (supabaseToken != null && supabaseToken.isNotEmpty) {
      return supabaseToken;
    }

    try {
      if (Firebase.apps.isEmpty) return null;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (_) {
      // Firebase peut ne pas être initialisé (voir main.dart).
      return null;
    }
  }

  /// Envoie une collection à `sync-write`. Ne lève jamais.
  ///
  /// Retourne `true` si Supabase a écrit la ligne, `false` dans tous les autres
  /// cas (écart ignoré par la règle de conflit, ou échec). Les deux sont
  /// acceptables : Firestore reste la référence.
  Future<bool> _send(String collection, Map<String, dynamic> data) async {
    try {
      final token = await _accessToken();

      if (token == null || token.isEmpty) {
        debugPrint(
          'Miroir Supabase ignoré ($collection) : pas de jeton.',
        );
        return false;
      }

      final response = await _client
          .post(
            Uri.parse('$_supabaseUrl/functions/v1/sync-write'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'apikey': _anonKey,
            },
            body: jsonEncode({'collection': collection, 'data': data}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          'Miroir Supabase ignoré ($collection) : HTTP ${response.statusCode}.',
        );
        return false;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map || decoded['ok'] != true) {
        return false;
      }

      // `ignored: true` n'est pas une erreur : c'est la règle de conflit qui a
      // rejeté une écriture plus ancienne que celle déjà présente.
      if (decoded['ignored'] == true) {
        debugPrint('Miroir Supabase : écriture plus ancienne ignorée ($collection).');
      }

      return true;
    } catch (error) {
      // Filet de sécurité : aucune réplication ne doit remonter à l'appelant.
      debugPrint('Miroir Supabase indisponible ($collection) : $error');
      return false;
    }
  }

  /// Réplique un profil. Ne lève jamais.
  ///
  /// [data] doit être **exactement** la carte écrite dans Firestore, et non un
  /// `toMap()` recalculé ici : `toMap()` regénère `updatedAt`, et le réplica
  /// porterait alors un horodatage différent de sa source. La règle
  /// last-write-wins compare ces horodatages, donc la copie doit reproduire
  /// celui de la source, pas celui de l'envoi.
  Future<bool> mirrorUser(Map<String, dynamic> data) => _send('user', data);

  /// Réplique un diagnostic. Ne lève jamais.
  Future<bool> mirrorDiagnosis(Map<String, dynamic> data) =>
      _send('diagnosis', data);
}