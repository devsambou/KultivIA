import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/conversation.dart';
import 'conversation_repository.dart';

/// Implémentation Firestore de [ConversationRepository].
///
/// Les conversations vivent dans `users/{uid}/conversations/{id}`. Une
/// sous-collection, donc les règles Firestore les cloisonnent déjà par
/// utilisateur, et une suppression de compte les emporte sans code
/// supplémentaire.
///
/// **Note sur les index** : `orderBy` sur un champ seul ne demande aucun index
/// composite — Firestore crée automatiquement les index monochamps. C'est
/// `where` + `orderBy` qui en exige un. D'où les tris ci-dessous, tous sur un
/// champ unique.
class FirebaseConversationRepository implements ConversationRepository {
  FirebaseConversationRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authOverride = auth,
        _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  bool get _isReady => Firebase.apps.isNotEmpty;

  String? get _currentUid => _isReady ? _auth.currentUser?.uid : null;

  /// Combien de conversations on garde en mémoire pour le tiroir. Au-delà, le
  /// tiroir n'affiche que les 6 premières : le reste reste dans Firestore.
  static const int _maxListed = 50;

  CollectionReference<Map<String, dynamic>> _conversationsCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('conversations');

  @override
  Stream<List<Conversation>> watchConversations() {
    final uid = _currentUid;
    if (uid == null) return const Stream.empty();

    return _conversationsCol(uid)
        .orderBy('updatedAt', descending: true)
        .limit(_maxListed)
        .snapshots()
        .map((snap) => [
              for (final doc in snap.docs) Conversation.fromMap(doc.data()),
            ]);
  }

  @override
  Future<Conversation?> loadMostRecent() async {
    final uid = _currentUid;
    if (uid == null) return null;

    final snap = await _conversationsCol(uid)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return Conversation.fromMap(snap.docs.first.data());
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    final uid = _currentUid;
    if (uid == null) return; // pas connecté → rien à persister

    await _conversationsCol(uid).doc(conversation.id).set(conversation.toMap());
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final uid = _currentUid;
    if (uid == null) return;

    await _conversationsCol(uid).doc(conversationId).delete();
  }

  @override
  Future<void> dispose() async {
    // Rien à libérer : les flux sont gérés par l'appelant (ConversationHistory).
  }
}