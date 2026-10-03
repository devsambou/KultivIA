import '../models/conversation.dart';

/// Interface pour la persistance des conversations avec l'avatar.
///
/// Séparée de [DiagnosisRepository] : un diagnostic est un résultat à
/// consulter, une conversation est un échange à relire. Les deux partagent la
/// source (Firestore) mais pas le rythme de vie — un diagnostic est figé après
/// coup, une conversation est réécrite à chaque échange.
abstract class ConversationRepository {
  /// Observe les conversations de l'utilisateur connecté, de la plus récente à
  /// la plus ancienne. Retourne un flux vide si non connecté.
  Stream<List<Conversation>> watchConversations();

  /// Relit une seule fois la conversation la plus récente.
  ///
  /// Distinct de [watchConversations] parce que l'écran d'accueil a besoin du
  /// contenu **immédiatement** à l'ouverture : un flux est asynchrone, et
  /// l'écran afficherait le vide une fraction de seconde avant de se remplir,
  /// assez pour faire clignoter l'état d'accueil à tort.
  Future<Conversation?> loadMostRecent();

  /// Enregistre (ou remplace) une conversation.
  Future<void> saveConversation(Conversation conversation);

  /// Supprime définitivement une conversation.
  Future<void> deleteConversation(String conversationId);

  /// Nettoie les ressources.
  Future<void> dispose();
}