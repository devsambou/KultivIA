import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/conversation.dart';
import '../../models/diagnosis.dart';
import '../../repositories/conversation_repository.dart';
import '../../repositories/diagnosis_repository.dart';
import '../../services/data/conversation_history.dart';
import '../../services/system/app_state.dart';
import '../../services/ai/avatar_intents.dart' show looksLikeCameraRequest, cameraReply;
import '../../services/auth/firebase_service.dart';
import '../../services/system/notification_service.dart';
import '../../services/ai/rodium_ai_service.dart' show RodiumAiService;
import '../../services/ui/voice_service.dart';
import '../../widgets/app_drawer.dart';
import 'composer.dart' show Composer, showAttachSheet;
import 'empty_state.dart';
import 'message_view.dart';
import 'typing_dots.dart';

/// Écran principal : conversation avec l'IA, sur le modèle de l'app mobile
/// Claude (réponses sans bulle, saisie arrondie avec « + » pour joindre une
/// photo, micro, bouton d'envoi, menu latéral).
///
/// Les widgets visuels (état vide, bulles de message, composer, feuille de
/// pièce jointe, indicateur « en train d'écrire ») vivent dans
/// lib/screens/home_ai/ — ce fichier ne garde que l'état et la logique de
/// conversation.
class HomeAiScreen extends StatefulWidget {
  const HomeAiScreen({super.key});

  @override
  State<HomeAiScreen> createState() => _HomeAiScreenState();
}

class _HomeAiScreenState extends State<HomeAiScreen> {
  final _messages = <ChatEntry>[];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _voice = VoiceService();
  final _picker = ImagePicker();
  StreamSubscription<String>? _pushSub;

  String? _pendingImagePath;
  bool _thinking = false;
  bool _listening = false;

  /// Conversation en cours. `null` tant que la reprise n'a pas été tentée.
  Conversation? _current;

  /// Vrai pendant la relecture Firestore : évite d'afficher l'état d'accueil
  /// une fraction de seconde avant de le remplacer par la conversation
  /// précédente, ce qui ferait clignoter les suggestions.
  bool _restoring = true;

  bool get _canSend => !_thinking && (_textController.text.trim().isNotEmpty || _pendingImagePath != null);

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
    if (context.read<FirebaseService>().isReady) {
      _pushSub = context.read<NotificationService>().foregroundTexts.listen(_toast);
    }
    unawaited(_restoreLastConversation());
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _voice.stopSpeaking();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)));
  }

  // ------------------------------------------------- historique de discussion

  /// Reprend la dernière conversation de l'utilisateur à l'ouverture de
  /// l'écran. Une coupure réseau ici n'a aucune conséquence : on démarre sur
  /// une conversation vierge, exactement comme avant.
  Future<void> _restoreLastConversation() async {
    Conversation? latest;

    try {
      final repo = context.read<ConversationRepository>();
      context.read<ConversationHistory>().bind();
      latest = await repo.loadMostRecent();
    } catch (e) {
      debugPrint("Reprise de la conversation impossible : $e");
    }

    if (!mounted) return;

    if (latest == null || latest.turns.isEmpty) {
      setState(() {
        _current = Conversation.start();
        _restoring = false;
      });
      return;
    }

    // `final` pour que Dart propage le type non nul jusqu'ici : la promotion
    // disparait à l'intérieur de la closure `setState` sur une variable simple.
    final restored = latest;

    setState(() {
      _current = restored;
      _messages.addAll(_rehydrate(restored));
      _restoring = false;
    });
    _scrollToBottom();
  }

  /// Reconstitruit les bulles à partir des tours enregistrés, en rattachant à
  /// chaque tour le diagnostic correspondant s'il est toujours dans
  /// l'historique. Sans ce rattachement, une conversation relue perdrait les
  /// cartes de diagnostic — c'est-à-dire le résultat le plus utile.
  List<ChatEntry> _rehydrate(Conversation conversation) {
    final byId = <String, Diagnosis>{
      for (final d in context.read<AppState>().historyList) d.id: d,
    };

    return [
      for (final turn in conversation.turns) turn.toChatEntry(diagnosis: byId[turn.diagnosisId]),
    ];
  }

  /// Ouvre une conversation du tiroir. L'écran n'en montrait qu'une à la fois :
  /// celle-ci la remplace, et l'utilisateur peut revenir avec le tiroir.
  void _openConversation(Conversation conversation) {
    _voice.stopSpeaking();
    _textController.clear();

    setState(() {
      _current = conversation;
      _messages
        ..clear()
        ..addAll(_rehydrate(conversation));
      _pendingImagePath = null;
      _thinking = false;
    });

    _scrollToBottom();
  }

  /// Enregistre l'échange courant dans Firestore.
  ///
  /// Appelé **après** chaque réponse de l'avatar, donc une écriture par
  /// échange et jamais à chaque frappe. L'écriture est déléguée à
  /// [ConversationHistory.save], qui ne lève pas : un échec réseau n'interrompt
  /// jamais la conversation en cours.
  void _persist() {
    if (!mounted) return;

    final conversation = (_current ?? Conversation.start()).withEntries(_messages);
    _current = conversation;

    unawaited(context.read<ConversationHistory>().save(conversation));
  }

  // ---------------------------------------------------------------- actions

  void _newChat() {
    _voice.stopSpeaking();
    _textController.clear();
    setState(() {
      _messages.clear();
      _pendingImagePath = null;
      _current = Conversation.start();
    });
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1280);
      if (picked == null || !mounted) return;
      setState(() => _pendingImagePath = picked.path);
    } catch (e) {
      debugPrint('Sélection photo impossible : $e');
      _toast("Impossible d'accéder à la photo. Vérifiez les autorisations de l'application.");
    }
  }

  void _showAttachSheet() {
    showAttachSheet(
      context,
      onCamera: () => _pick(ImageSource.camera),
      onGallery: () => _pick(ImageSource.gallery),
    );
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }
    // L'avatar se tait pour ne pas s'entendre lui-même dans le micro.
    await _voice.stopSpeaking();
    if (!mounted) return;
    setState(() => _listening = true);
    final lang = context.read<AppState>().languageCode;
    String? text;
    try {
      text = await _voice.listenOnce(languageCode: lang);
    } catch (e) {
      debugPrint('Écoute impossible : $e');
    }
    if (!mounted) return;
    setState(() => _listening = false);
    if (text != null && text.trim().isNotEmpty) {
      _textController.text = text.trim();
      // Question posée à l'oral : la réponse est lue à voix haute.
      await _send(viaVoice: true);
    } else {
      _toast("Je n'ai rien entendu. Vérifiez l'autorisation du micro et la connexion, puis réessayez.");
    }
  }

  Future<void> _toggleVoiceReplies() async {
    final app = context.read<AppState>();
    final fb = context.read<FirebaseService>();
    final on = !app.voiceReplies;
    app.setVoiceReplies(on);
    if (!on) unawaited(_voice.stopSpeaking());
    _toast(on ? 'Les réponses seront lues à voix haute.' : 'Réponses vocales désactivées.');
    final profile = app.profile;
    if (fb.isReady && profile != null) {
      try {
        await fb.saveProfile(profile);
      } catch (_) {
        // Non bloquant : le réglage reste appliqué localement.
      }
    }
  }

  /// Lit la réponse de l'avatar si la question était orale ou si l'utilisateur
  /// a activé les réponses parlées.
  void _maybeSpeak(String text, {required bool viaVoice}) {
    final app = context.read<AppState>();
    if (!viaVoice && !app.voiceReplies) return;
    unawaited(_voice
        .speak(text, languageCode: app.languageCode)
        .catchError((Object e) => debugPrint('Voix indisponible : $e')));
  }

  List<Map<String, String>> _history() {
    final recent = _messages.where((m) => m.text.trim().isNotEmpty).toList();
    final tail = recent.length > 12 ? recent.sublist(recent.length - 12) : recent;
    return [
      for (final m in tail) {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
    ];
  }

  /// Regroupe ce que l'utilisateur a décrit dans la conversation, pour que
  /// le diagnostic tienne compte de tous les symptômes déjà évoqués.
  String _symptomContext() {
    final texts = _messages.where((m) => m.fromUser && m.text.trim().isNotEmpty).map((m) => m.text.trim()).toList();
    final tail = texts.length > 5 ? texts.sublist(texts.length - 5) : texts;
    return tail.join('. ');
  }

  Future<void> _send({bool viaVoice = false}) async {
    if (!_canSend) return;
    unawaited(_voice.stopSpeaking());
    final text = _textController.text.trim();
    final image = _pendingImagePath;
    _textController.clear();

    // « photo », « caméra »... : l'avatar ouvre l'appareil photo sans appeler l'IA.
    if (image == null && looksLikeCameraRequest(text)) {
      final reply = cameraReply(context.read<AppState>().languageCode);
      setState(() {
        _messages.add(ChatEntry(fromUser: true, text: text));
        _messages.add(ChatEntry(fromUser: false, text: reply));
      });
      _persist();
      _scrollToBottom();
      _maybeSpeak(reply, viaVoice: viaVoice);
      await _pick(ImageSource.camera);
      return;
    }

    setState(() {
      _pendingImagePath = null;
      _messages.add(ChatEntry(fromUser: true, text: text, imagePath: image));
      _thinking = true;
    });
    _scrollToBottom();

    final ai = context.read<RodiumAiService>();
    final app = context.read<AppState>();
    final repo = context.read<DiagnosisRepository>();
    final lang = app.languageCode;

    try {
      if (image != null || text.toLowerCase().contains('diagnostic')) {
        final description = _symptomContext();
        final json = image != null
            ? await ai.diagnoseFromImage(imageFile: File(image), description: description, languageCode: lang)
            : await ai.diagnoseFromText(description: description, languageCode: lang);

        final diagnosis = Diagnosis.fromAiJson(
          json,
          inputText: description,
          imagePath: image,
          rawAiResponse: json.toString(),
        );
        app.addDiagnosis(diagnosis);
        _save(repo, diagnosis);

        final identified = diagnosis.disease.toLowerCase() != 'indéterminé';
        if (!mounted) return;
        final avatarText = (json['reponse_avatar'] ?? 'Diagnostic terminé, voici le résultat.').toString();
        setState(() {
          _messages.add(ChatEntry(
            fromUser: false,
            text: avatarText,
            diagnosis: identified ? diagnosis : null,
          ));
        });
        _persist();
        _maybeSpeak(avatarText, viaVoice: viaVoice);
      } else {
        final reply = await ai.chatWithAvatar(history: _history(), languageCode: lang);
        if (!mounted) return;
        setState(() => _messages.add(ChatEntry(fromUser: false, text: reply)));
        _persist();
        _maybeSpeak(reply, viaVoice: viaVoice);
      }
    } catch (e) {
      debugPrint('Erreur IA : $e');
      if (mounted) {
        setState(() {
          _messages.add(ChatEntry(
            fromUser: false,
            text: "Je n'ai pas pu joindre l'IA. Vérifiez votre connexion, puis réessayez.",
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  void _save(DiagnosisRepository repo, Diagnosis d) {
    unawaited(repo.saveDiagnosis(d).catchError((Object e) => debugPrint('Sauvegarde du diagnostic impossible : $e')));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _runPrompt(String prompt) {
    _textController.text = prompt;
    _send();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AppState>().profile?.firstName;
    final lang = context.watch<AppState>().languageCode;
    final voiceReplies = context.watch<AppState>().voiceReplies;

    return Scaffold(
      drawer: AppDrawer(onNewChat: _newChat, onOpenConversation: _openConversation),
      appBar: AppBar(
        title: const Text('KultivIA', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(voiceReplies ? Icons.volume_up : Icons.volume_off_outlined),
            tooltip: voiceReplies ? 'Désactiver les réponses vocales' : 'Écouter les réponses',
            onPressed: _toggleVoiceReplies,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Nouvelle conversation',
            onPressed: _restoring || _messages.isEmpty ? null : _newChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _restoring
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? EmptyState(
              name: name,
              listening: _listening,
              onMic: _toggleListening,
              onCamera: () => _pick(ImageSource.camera),
              onPrompt: _runPrompt,
              onWeather: () => Navigator.of(context).pushNamed('/weather'),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) return const TypingDots();
                final m = _messages[i];
                return MessageView(
                  entry: m,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: m.text));
                    _toast('Copié');
                  },
                  onSpeak: () => _voice.speak(m.text, languageCode: lang),
                );
              },
            ),
          ),
          Composer(
            controller: _textController,
            imagePath: _pendingImagePath,
            listening: _listening,
            canSend: _canSend,
            thinking: _thinking,
            onAttach: _showAttachSheet,
            onRemoveImage: () => setState(() => _pendingImagePath = null),
            onMic: _toggleListening,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}