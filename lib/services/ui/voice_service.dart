import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'rodium_ai_service.dart';

/// Longueur maximale d'un texte lu à voix haute (la Cloud Function refuse au-delà).
const maxSpeechChars = 600;

/// Nettoie un texte avant de le lire : retire la mise en forme markdown,
/// réduit les espaces et coupe proprement en fin de phrase si c'est trop long.
String prepareSpeechText(String text) {
  var t = text.replaceAll(RegExp(r'[*_#`>~|]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length > maxSpeechChars) {
    final cut = t.lastIndexOf(RegExp(r'[.!?]'), maxSpeechChars - 1);
    t = cut > 200 ? t.substring(0, cut + 1) : t.substring(0, maxSpeechChars);
  }
  return t;
}

/// Voix de l'avatar : il écoute et il parle, pour les utilisateurs qui ne
/// savent pas lire.
///
/// - Français et anglais : moteurs natifs du téléphone (gratuits, rapides).
/// - Wolof ([cloudLanguages]) : le téléphone ne le gère pas, on passe par
///   RodiumAI (Cloud Functions `aiTranscribe` et `aiSpeech`). Si la synthèse
///   cloud échoue (pas de réseau...), repli sur la voix française du téléphone.
///
/// Instance unique : une seule voix à la fois dans toute l'app.
class VoiceService {
  factory VoiceService() => _instance;
  VoiceService._();
  static final VoiceService _instance = VoiceService._();

  /// Langues servies par RodiumAI plutôt que par le moteur du téléphone.
  static const cloudLanguages = {'wo'};

  /// Phrase d'accueil dans chaque langue (écran de choix de la langue).
  /// À faire relire par un locuteur natif pour le wolof.
  static const greetings = <String, String>{
    'fr': 'Bonjour, je suis Kultivia. Je vous aide à soigner vos cultures.',
    'en': "Hello, I'm Kultivia. I help you take care of your crops.",
    'wo': 'Nanga def ! Maa ngi tudd Kultivia. Dinaa la dimbali ci sa toolu.',
  };

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  late final AudioPlayer _player = AudioPlayer();
  late final AudioRecorder _recorder = AudioRecorder();
  late final RodiumAiService _cloud = RodiumAiService();

  bool _sttReady = false;
  bool _cloudRecording = false;
  Completer<void>? _playback;

  bool get isListening => _cloudRecording || _stt.isListening;

  // ---------------------------------------------------------------- écoute

  /// Écoute l'utilisateur et renvoie ce qu'il a dit, ou `null` si rien
  /// n'a été compris. Peut lever une exception (réseau) pour les langues cloud.
  Future<String?> listenOnce({String languageCode = 'fr'}) {
    if (cloudLanguages.contains(languageCode)) return _listenCloud(languageCode);
    return _listenNative(languageCode == 'en' ? 'en_US' : 'fr_FR');
  }

  Future<void> stopListening() async {
    _cloudRecording = false; // la boucle d'enregistrement s'arrête au prochain tick
    if (_stt.isListening) await _stt.stop();
  }

  Future<bool> _ensureSttReady() async {
    if (_sttReady) return true;
    _sttReady = await _stt.initialize(
      onError: (e) => debugPrint('STT error: $e'),
      onStatus: (s) => debugPrint('STT status: $s'),
    );
    return _sttReady;
  }

  Future<String?> _listenNative(String localeId) async {
    if (!await _ensureSttReady()) return null;

    var result = '';
    final completer = Completer<String?>();

    await _stt.listen(
      localeId: localeId,
      onResult: (r) {
        result = r.recognizedWords;
        if (r.finalResult && !completer.isCompleted) completer.complete(result);
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
    );

    // Filet de sécurité si le moteur n'envoie jamais de résultat final.
    Future.delayed(const Duration(seconds: 21), () {
      if (!completer.isCompleted) completer.complete(result.isEmpty ? null : result);
    });

    return completer.future;
  }

  /// Enregistre le micro jusqu'à un silence (ou 20 s), puis envoie l'audio à
  /// RodiumAI pour transcription.
  Future<String?> _listenCloud(String languageCode) async {
    if (!await _recorder.hasPermission()) return null;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/kultivia_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1),
      path: path,
    );
    _cloudRecording = true;

    var heardSpeech = false;
    var silentTicks = 0;
    var ticks = 0;
    final done = Completer<void>();
    final timer = Timer.periodic(const Duration(milliseconds: 200), (t) async {
      ticks++;
      try {
        final amp = await _recorder.getAmplitude();
        if (amp.current > -35) {
          heardSpeech = true;
          silentTicks = 0;
        } else if (heardSpeech) {
          silentTicks++;
        }
      } catch (_) {}
      // Fin : 1,6 s de silence après la parole, 20 s max, ou arrêt manuel.
      if ((heardSpeech && silentTicks >= 8) || ticks >= 100 || !_cloudRecording) {
        t.cancel();
        if (!done.isCompleted) done.complete();
      }
    });
    await done.future;
    timer.cancel();

    final recorded = await _recorder.stop();
    _cloudRecording = false;
    if (recorded == null) return null;

    final file = File(recorded);
    try {
      if (!heardSpeech) return null;
      final bytes = await file.readAsBytes();
      final text = await _cloud.transcribeAudio(bytes: bytes, mime: 'audio/mp4', languageCode: languageCode);
      final clean = text.trim();
      return clean.isEmpty ? null : clean;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  // ------------------------------------------------------------------ voix

  /// Lit [text] à voix haute et rend la main quand c'est fini.
  Future<void> speak(String text, {String languageCode = 'fr'}) async {
    final clean = prepareSpeechText(text);
    if (clean.isEmpty) return;
    await stopSpeaking();

    if (cloudLanguages.contains(languageCode)) {
      try {
        await _speakCloud(clean, languageCode);
        return;
      } catch (e) {
        // Repli : voix française du téléphone (prononciation approximative).
        debugPrint('Synthèse RodiumAI indisponible, repli sur la voix native : $e');
      }
    }
    await _speakNative(clean, languageCode);
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    final p = _playback;
    if (p != null && !p.isCompleted) p.complete();
  }

  Future<void> _speakCloud(String text, String languageCode) async {
    final bytes = await _cloud.synthesizeSpeech(text: text, languageCode: languageCode);
    if (bytes.isEmpty) throw StateError('Audio vide');

    final done = Completer<void>();
    _playback = done;
    final sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await _player.play(BytesSource(bytes));
      await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _speakNative(String text, String languageCode) async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage(languageCode == 'en' ? 'en-US' : 'fr-FR');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }
}
