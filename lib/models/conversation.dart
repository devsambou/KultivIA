import 'diagnosis.dart';

/// Un tour de conversation dans sa forme **persistable**.
///
/// Elle se distingue de [ChatEntry] (l'affichage) sur deux points :
///
/// - la photo n'est pas rejouée. [ChatEntry.imagePath] pointe vers un fichier du
///   téléphone choisi par `ImagePicker` : ce chemin n'a plus de sens après un
///   redémarrage. On mémorise seulement qu'il y avait une photo, [hadPhoto].
/// - le diagnostic n'est pas embarqué, seulement référencé par [diagnosisId].
///   Il est déjà stocké une fois dans l'historique des diagnostics ; le recopier
///   ici créerait un second endroit où il pourrait se désynchroniser.
class ConversationTurn {
  const ConversationTurn({
    required this.fromUser,
    required this.text,
    this.hadPhoto = false,
    this.diagnosisId,
  });

  final bool fromUser;
  final String text;
  final bool hadPhoto;
  final String? diagnosisId;

  factory ConversationTurn.fromChatEntry(ChatEntry entry) => ConversationTurn(
        fromUser: entry.fromUser,
        text: entry.text,
        hadPhoto: entry.imagePath != null,
        diagnosisId: entry.diagnosis?.id,
      );

  /// Reconstruit l'entrée d'affichage. [diagnosis] est retrouvé par
  /// [diagnosisId] dans l'historique des diagnostics ; s'il a été supprimé, la
  /// bulle s'affiche sans la carte, ce qui reste lisible.
  ChatEntry toChatEntry({Diagnosis? diagnosis}) => ChatEntry(
        fromUser: fromUser,
        text: text,
        diagnosis: diagnosis,
      );

  Map<String, dynamic> toMap() => {
        'fromUser': fromUser,
        'text': text,
        'hadPhoto': hadPhoto,
        'diagnosisId': diagnosisId,
      };

  factory ConversationTurn.fromMap(Map<String, dynamic> map) {
    final id = map['diagnosisId'] as String?;
    return ConversationTurn(
      fromUser: map['fromUser'] == true,
      text: (map['text'] as String?) ?? '',
      hadPhoto: map['hadPhoto'] == true,
      diagnosisId: (id == null || id.isEmpty) ? null : id,
    );
  }
}

/// Une conversation entière avec l'avatar, telle qu'enregistrée dans
/// `users/{uid}/conversations/{id}`.
///
/// Toute la conversation tient dans un document : un échange est un aller-retour
/// de quelques kilo-octets, très loin de la limite Firestore d'un document
/// (1 Mio). Cela évite d'écrire un document par message.
class Conversation {
  const Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.title,
    required this.turns,
  });

  /// Nombre maximal de tours conservés dans un document.
  ///
  /// Au-delà, on ne garde que les derniers : ce sont ceux que l'utilisateur
  /// relit, et cela borne la taille du document même si une session reste
  /// ouverte plusieurs jours.
  static const int maxStoredTurns = 100;

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final List<ConversationTurn> turns;

  /// Nouvelle conversation vide, prête à recevoir des tours.
  ///
  /// Le titre est **volontairement vide** : c'est le premier [withEntries] qui
  /// le déduit du premier message. Le pré-remplir ici figerait « Nouvelle
  /// conversation » comme titre définitif.
  factory Conversation.start() {
    final now = DateTime.now();
    return Conversation(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      updatedAt: now,
      title: '',
      turns: const [],
    );
  }

  /// Titre à afficher. Jamais vide, même pour une conversation jamais démarrée.
  String get displayTitle => title.isEmpty ? _untitled : title;

  static const String _untitled = 'Nouvelle conversation';

  /// Copie de cette conversation portant [entries] comme tours.
  ///
  /// [createdAt] et le titre sont conservés : une conversation qui se poursuit
  /// ne doit pas changer d'identité ni de libellé sous les yeux de
  /// l'utilisateur dans le tiroir.
  Conversation withEntries(List<ChatEntry> entries) {
    final kept = entries.length > maxStoredTurns
        ? entries.sublist(entries.length - maxStoredTurns)
        : entries;

    return Conversation(
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      title: title.isEmpty ? titleFor(entries) : title,
      turns: [for (final entry in kept) ConversationTurn.fromChatEntry(entry)],
    );
  }

  /// Dernier texte échangé, pour la liste du tiroir.
  ///
  /// Une photo seule n'a pas de texte : on affiche alors « Photo de la culture »
  /// plutôt qu'une ligne vide.
  String get preview {
    if (turns.isEmpty) return displayTitle;

    final last = turns.last;
    final text = last.text.trim();

    if (text.isNotEmpty) return _ellipsis(text, 60);
    return last.hadPhoto ? 'Photo de la culture' : displayTitle;
  }

  /// Libellé du tiroir : le premier message de l'utilisateur, parce que c'est
  /// ce qui identifie la conversation (« taches jaunes sur les feuilles »).
  static String titleFor(List<ChatEntry> entries, {int maxLength = 48}) {
    for (final entry in entries) {
      if (!entry.fromUser) continue;

      final text = entry.text.trim();
      if (text.isNotEmpty) return _ellipsis(text, maxLength);
      if (entry.imagePath != null) return 'Photo de la culture';
    }

    return _untitled;
  }

  static String _ellipsis(String value, int maxLength) => value.length <= maxLength
      ? value
      : '${value.substring(0, maxLength - 1).trimRight()}…';

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'title': title,
        'turns': [for (final turn in turns) turn.toMap()],
      };

  factory Conversation.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    final id = (map['id'] as String?) ?? '';
    final rawTurns = map['turns'];

    return Conversation(
      id: id.isEmpty ? now.microsecondsSinceEpoch.toString() : id,
      createdAt: _parseDate(map['createdAt']) ?? now,
      updatedAt: _parseDate(map['updatedAt']) ?? now,
      title: (map['title'] as String?) ?? titleFor(const []),
      turns: rawTurns is List
          ? [
              for (final raw in rawTurns)
                if (raw is Map) ConversationTurn.fromMap(Map<String, dynamic>.from(raw)),
            ]
          : const [],
    );
  }

  /// Une date illisible ne doit pas faire tomber toute la conversation : on
  /// retombe sur l'heure du moment, ce qui ne fait que décaler l'ordre du
  /// tiroir.
  static DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}