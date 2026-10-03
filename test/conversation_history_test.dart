import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/models/conversation.dart';
import 'package:kultivia/models/diagnosis.dart';
import 'package:kultivia/repositories/conversation_repository.dart';
import 'package:kultivia/services/data/conversation_history.dart';

void main() {
  group('Conversation (modèle)', () {
    ChatEntry user(String text) => ChatEntry(fromUser: true, text: text);
    ChatEntry bot(String text) => ChatEntry(fromUser: false, text: text);

    Diagnosis diagnosis(String id) => Diagnosis(
          id: id,
          date: DateTime(2026, 3, 1),
          inputText: 'feuilles jaunes',
          disease: 'Rouille',
          confidence: 0.8,
          advice: 'Fongicide',
          rawAiResponse: '',
        );

    test('le titre reprend le premier message de l\'utilisateur', () {
      final title = Conversation.titleFor([
        user('Taches jaunes sur les feuilles'),
        bot('C\'est une rouille.'),
      ]);

      expect(title, 'Taches jaunes sur les feuilles');
    });

    test('le titre ignore la réponse de l\'avatar', () {
      // L'avatar parle en premier seulement si l'utilisateur a demandé une
      // photo : dans ce cas, le titre doit rester explicite.
      final title = Conversation.titleFor([
        user('   '),
        bot('Je prends une photo.'),
      ]);

      expect(title, 'Nouvelle conversation');
    });

    test('une photo seule donne un titre explicite', () {
      final title = Conversation.titleFor([
        ChatEntry(fromUser: true, text: '', imagePath: '/tmp/a.jpg'),
      ]);

      expect(title, 'Photo de la culture');
    });

    test('un titre long est tronqué', () {
      final long = 'a' * 120;

      final title = Conversation.titleFor([user(long)]);

      expect(title.length, 48);
      expect(title, endsWith('…'));
    });

    test('withEntries conserve l\'identité et la date de création', () {
      final start = Conversation.start();
      final updated = start.withEntries([user('Bonjour')]);

      expect(updated.id, start.id);
      expect(updated.createdAt, start.createdAt);
      expect(updated.turns.length, 1);
    });

    test('withEntries fige le titre dès le premier échange', () {
      // Le titre ne doit pas changer quand l'utilisateur poursuit : sinon
      // l'entrée du tiroir se déplacerait sous son doigt.
      final first = Conversation.start().withEntries([user('Feuilles brunes')]);
      final second = first.withEntries([user('Feuilles brunes'), bot('Rouille')]);

      expect(second.title, 'Feuilles brunes');
    });

    test('une conversation jamais démarrée affiche quand même un titre', () {
      // Le titre est déduit du premier message : il est donc vide tant que
      // l'utilisateur n'a rien dit. `displayTitle` est le filet de sécurité
      // utilisé par le tiroir, sinon il afficherait une ligne sans nom.
      final start = Conversation.start();

      expect(start.title, isEmpty);
      expect(start.displayTitle, 'Nouvelle conversation');
    });

    test('le premier message donne le titre, même après un avatar silencieux', () {
      // L'avatar parle en premier quand l'utilisateur demande une photo : le
      // titre ne doit pas se figer sur ce message technique.
      final conversation = Conversation.start().withEntries([
        bot('Je prends une photo.'),
        ChatEntry(fromUser: true, text: '', imagePath: '/tmp/a.jpg'),
      ]);

      expect(conversation.title, 'Photo de la culture');
    });

    test('withEntries ne stocke que les derniers tours', () {
      final entries = [for (var i = 0; i < Conversation.maxStoredTurns + 10; i++) user('message $i')];

      final conversation = Conversation.start().withEntries(entries);

      expect(conversation.turns.length, Conversation.maxStoredTurns);
      // Les plus anciens sont perdus, les plus récents gardés.
      expect(conversation.turns.last.text, 'message ${Conversation.maxStoredTurns + 9}');
    });

    test('le tour retient qu\'il y avait une photo, pas son chemin', () {
      // Le chemin est un fichier du téléphone : il ne survivrait pas à un
      // redémarrage et ferait afficher une image cassée.
      final turn = ConversationTurn.fromChatEntry(
        ChatEntry(fromUser: true, text: '', imagePath: '/storage/emulated/0/x.jpg'),
      );

      expect(turn.hadPhoto, isTrue);
      expect(turn.toMap().containsKey('imagePath'), isFalse);
    });

    test('le tour retient l\'identifiant du diagnostic, pas son contenu', () {
      final turn = ConversationTurn.fromChatEntry(
        ChatEntry(fromUser: false, text: 'Rouille probable', diagnosis: diagnosis('d1')),
      );

      expect(turn.diagnosisId, 'd1');
      expect(turn.toMap()['diagnosisId'], 'd1');
      expect(turn.toMap().containsKey('disease'), isFalse);
    });

    test('un tour relu se rattache au diagnostic retrouvé', () {
      final turn = ConversationTurn.fromMap({'fromUser': false, 'text': 'Rouille', 'diagnosisId': 'd1'});

      final entry = turn.toChatEntry(diagnosis: diagnosis('d1'));

      expect(entry.diagnosis?.disease, 'Rouille');
    });

    test('un diagnostic supprimé donne une bulle sans carte', () {
      final turn = ConversationTurn.fromMap({'fromUser': false, 'text': 'Rouille', 'diagnosisId': 'd1'});

      final entry = turn.toChatEntry(diagnosis: null);

      expect(entry.text, 'Rouille');
      expect(entry.diagnosis, isNull);
    });

    test('aller-retour toMap / fromMap conserve tout', () {
      final original = Conversation.start().withEntries([
        user('Taches jaunes'),
        ChatEntry(fromUser: false, text: 'Rouille', diagnosis: diagnosis('d1')),
      ]);

      final restored = Conversation.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.turns.length, 2);
      expect(restored.turns[1].diagnosisId, 'd1');
      expect(restored.updatedAt, original.updatedAt);
    });

    test('un document sans tours ne fait pas tomber la lecture', () {
      final restored = Conversation.fromMap({'id': 'x'});

      expect(restored.turns, isEmpty);
      expect(restored.id, 'x');
    });

    test('un document avec des dates illisibles reste lisible', () {
      final restored = Conversation.fromMap({
        'id': 'x',
        'createdAt': 'pas une date',
        'updatedAt': null,
        'turns': [
          'pas une map',
          {'fromUser': true, 'text': 'bonjour'},
        ],
      });

      expect(restored.turns.length, 1);
      expect(restored.turns.first.text, 'bonjour');
    });
  });

  group('ConversationHistory', () {
    late FakeConversationRepository repo;
    late ConversationHistory history;

    setUp(() {
      repo = FakeConversationRepository();
      history = ConversationHistory(repo);
    });

    tearDown(() => history.dispose());

    Conversation conversationAt(DateTime when, {String id = 'c1'}) => Conversation(
          id: id,
          createdAt: when,
          updatedAt: when,
          title: 'Sujet $id',
          turns: const [],
        );

    test('la liste est vide tant que rien n\'est arrivé', () {
      expect(history.isEmpty, isTrue);
      expect(history.latest, isNull);
    });

    test('bind remplit la liste depuis le flux', () async {
      history.bind();
      repo.emit([conversationAt(DateTime(2026, 3, 1))]);
      await pumpEventQueue();

      expect(history.conversations.length, 1);
      expect(history.latest?.id, 'c1');
    });

    test('les conversations les plus récentes viennent en premier', () async {
      history.bind();
      // Le flux arrive dans le désordre : c'est l'historique qui range, pas
      // Firestore, pour ne pas dépendre de l'ordre de lecture d'un index.
      repo.emit([
        conversationAt(DateTime(2026, 3, 1), id: 'ancien'),
        conversationAt(DateTime(2026, 3, 5), id: 'recent'),
      ]);
      await pumpEventQueue();

      expect(history.conversations.map((c) => c.id), ['recent', 'ancien']);
    });

    test('bind est idempotent : deux appels ne font pas deux abonnements', () async {
      history.bind();
      history.bind();
      repo.emit([conversationAt(DateTime(2026, 3, 1))]);
      await pumpEventQueue();

      expect(repo.listenCount, 1);
    });

    test('save insère immédiatement, avant même l\'écriture', () async {
      repo.failWrites = true;

      await history.save(conversationAt(DateTime(2026, 3, 1)));

      // Mise à jour optimiste : le tiroir réagit sans attendre Firestore.
      expect(history.conversations.length, 1);
    });

    test('save ne lève jamais quand l\'écriture échoue', () async {
      repo.failWrites = true;

      // Un agriculteur hors ligne doit pouvoir discuter ; l'échec doit être
      // journalisé, pas remonté à l'écran.
      await expectLater(history.save(conversationAt(DateTime(2026, 3, 1))), completes);
    });

    test('save remplace la conversation plutôt que de la dupliquer', () async {
      await history.save(conversationAt(DateTime(2026, 3, 1)));
      await history.save(conversationAt(DateTime(2026, 3, 2)));

      expect(history.conversations.length, 1);
      expect(repo.saved.length, 2);
    });

    test('save range selon updatedAt, pas selon l\'ordre des appels', () async {
      // C'est la date du dernier échange qui décide de l'ordre du tiroir :
      // une conversation enregistrée en second mais plus ancienne reste
      // derrière, même si elle vient d'être écrite.
      await history.save(conversationAt(DateTime(2026, 3, 1), id: 'a'));
      await history.save(conversationAt(DateTime(2026, 3, 5), id: 'b'));

      expect(history.conversations.map((c) => c.id), ['b', 'a']);
    });

    test('relire une conversation la fait remonter en tête', () async {
      await history.save(conversationAt(DateTime(2026, 3, 1), id: 'a'));
      await history.save(conversationAt(DateTime(2026, 3, 2), id: 'b'));
      await history.save(conversationAt(DateTime(2026, 3, 9), id: 'a'));

      expect(history.conversations.map((c) => c.id), ['a', 'b']);
      // Et toujours sans doublon : c'est la même entrée qui s'est déplacée.
      expect(history.conversations.length, 2);
    });

    test('delete retire la conversation sans lever', () async {
      repo.failWrites = true;
      await history.save(conversationAt(DateTime(2026, 3, 1)));

      await expectLater(history.delete('c1'), completes);
      expect(history.isEmpty, isTrue);
    });

    test('une erreur de flux ne casse pas l\'écran', () async {
      // Les règles Firestore peuvent refuser la lecture (compte supprimé,
      // session expirée). L'historique est un confort : on perd la liste,
      // pas l'application.
      repo.failStream = true;
      history.bind();
      await pumpEventQueue();

      expect(history.conversations, isEmpty);
      expect(history.streamError, isNotNull);
    });

    test('clear vide l\'état', () {
      history.save(conversationAt(DateTime(2026, 3, 1)));
      history.clear();

      expect(history.isEmpty, isTrue);
      expect(history.streamError, isNull);
    });
  });
}

/// Dépôt de test, sans Firebase : on vérifie le comportement de
/// [ConversationHistory] lui-même, pas celui de Firestore.
class FakeConversationRepository implements ConversationRepository {
  final _controller = StreamController<List<Conversation>>.broadcast();
  final List<Conversation> saved = [];

  int listenCount = 0;
  bool failWrites = false;
  bool failStream = false;

  @override
  Stream<List<Conversation>> watchConversations() {
    listenCount++;
    if (failStream) {
      return Stream<List<Conversation>>.error(StateError('règles refusées'));
    }
    return _controller.stream;
  }

  void emit(List<Conversation> list) => _controller.add(list);

  @override
  Future<Conversation?> loadMostRecent() async => null;

  @override
  Future<void> saveConversation(Conversation conversation) async {
    if (failWrites) throw StateError('réseau indisponible');
    saved.add(conversation);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    if (failWrites) throw StateError('réseau indisponible');
  }

  @override
  Future<void> dispose() => _controller.close();
}