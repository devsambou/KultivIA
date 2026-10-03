import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/conversation.dart';
import '../../repositories/conversation_repository.dart';

/// Historique des conversations avec l'avatar.
///
/// Volontairement distinct de `DiagnosisHistory` : un diagnostic est un
/// résultat à consulter, une conversation est un échange à relire.
///
/// ## Contrat : enregistrer une conversation n'est jamais bloquant
///
/// [save] et [delete] ne lèvent **jamais**. L'historique est un confort, pas une
/// fonction métier : un agriculteur hors ligne doit pouvoir diagnostiquer sans
/// que l'échec d'écriture interrompe ou fasse planter la conversation. L'échec
/// est journalisé et la liste en mémoire reste cohérente grâce à la mise à jour
/// optimiste.
class ConversationHistory extends ChangeNotifier {
  ConversationHistory(this._repository);

  final ConversationRepository _repository;
  final List<Conversation> _conversations = [];
  StreamSubscription<List<Conversation>>? _sub;

  /// Dernière erreur du flux, pour un éventuel affichage. Non bloquant.
  Object? streamError;

  /// Les plus récentes d'abord.
  List<Conversation> get conversations => List.unmodifiable(_conversations);

  bool get isEmpty => _conversations.isEmpty;

  /// Abonne le flux Firestore. Idempotent : appeler [bind] deux fois ne crée
  /// qu'un abonnement.
  void bind() {
    _sub ??= _repository.watchConversations().listen(
          (list) {
            _conversations
              ..clear()
              ..addAll(list);
            _sort();
            streamError = null;
            notifyListeners();
          },
          onError: (Object error) {
            // Le tiroir affiche simplement une liste vide : pas de dialogue
            // d'erreur pour une fonction secondaire.
            streamError = error;
            notifyListeners();
          },
        );
  }

  /// La conversation la plus récente. `null` si l'utilisateur n'en a jamais eu.
  Conversation? get latest => _conversations.isEmpty ? null : _conversations.first;

  /// Enregistre [conversation]. Ne lève jamais.
  Future<void> save(Conversation conversation) async {
    // Mise à jour optimiste : le tiroir réagit immédiatement, l'écriture
    // Firestore suit derrière.
    final index = _conversations.indexWhere((c) => c.id == conversation.id);

    if (index == -1) {
      _conversations.add(conversation);
    } else {
      _conversations[index] = conversation;
    }

    _sort();
    notifyListeners();

    try {
      await _repository.saveConversation(conversation);
    } catch (error) {
      debugPrint("Enregistrement de la conversation impossible : $error");
    }
  }

  /// Supprime [conversationId]. Ne lève jamais.
  Future<void> delete(String conversationId) async {
    _conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();

    try {
      await _repository.deleteConversation(conversationId);
    } catch (error) {
      debugPrint("Suppression de la conversation impossible : $error");
    }
  }

  /// Vide l'état local. Utilisé à la déconnexion : les conversations de
  /// l'utilisateur précédent ne doivent pas rester visibles pour le suivant.
  void clear() {
    _conversations.clear();
    streamError = null;
    notifyListeners();
  }

  void _sort() {
    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}