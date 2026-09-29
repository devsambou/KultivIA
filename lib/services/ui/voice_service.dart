import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ai/rodium_ai_service.dart';

/// Longueur maximale d'un texte lu à voix haute
/// (la Cloud Function refuse au-delà).
const maxSpeechChars = 600;

/// Nettoie un texte avant de le lire : retire la mise en forme markdown,
/// réduit les espaces et coupe proprement en fin de phrase si c'est trop long.
String prepareSpeechText(String text) {
  var t = text
      .replaceAll(RegExp(r'[*_#`>~|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (t.length > maxSpeechChars) {
    final cut = t.lastIndexOf(RegExp(r'[.!?]'), maxSpeechChars - 1);
    t = cut > 200 ? t.substring(0, cut + 1) : t.substring(0, maxSpeechChars);
  }

  return t;
}

/// Voix de l'avatar : il écoute et il parle.
///
/// - Français et anglais : moteurs natifs du téléphone.
/// - Wolof : RodiumAI via les Cloud Functions.
/// - Si la synthèse cloud échoue, repli sur la voix française du téléphone.
///
/// Instance unique : une seule voix à la fois dans toute l'application.
class VoiceService {
  factory VoiceService() => _instance;

  VoiceService._();

  static final VoiceService _instance = VoiceService._();

  /// Langues servies par RodiumAI plutôt que par le moteur du téléphone.
  static const cloudLanguages = {'wo', 'ln'};

  /// Phrase d'accueil dans chaque langue.
  static const greetings = <String, String>{
    'fr': 'Bonjour, je suis Kultivia. Je vous aide à soigner vos cultures.',
    'en': "Hello, I'm Kultivia. I help you take care of your crops.",
    'wo': 'Nanga def ! Maa ngi tudd Kultivia. Dinaa la dimbali ci sa toolu.',
    'ln':
        'Mbote ! Kombo na ngai ezali Kultivia. Nakosalisa yo kobatela milona na yo.',
  };

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  late final AudioPlayer _player = AudioPlayer();
  late final AudioRecorder _recorder = AudioRecorder();
  late final RodiumAiService _cloud = RodiumAiService();

  bool _sttReady = false;
  bool _cloudRecording = false;

  Completer<void>? _playback;

  /// Numéro de génération de la lecture.
  ///
  /// Il permet d'annuler une synthèse cloud qui serait encore en cours
  /// avant que l'audio n'arrive.
  int _speechGeneration = 0;

  bool get isListening => _cloudRecording || _stt.isListening;

  // ---------------------------------------------------------------- écoute

  /// Écoute l'utilisateur et renvoie ce qu'il a dit.
  ///
  /// Retourne null si rien n'a été compris.
  Future<String?> listenOnce({String languageCode = 'fr'}) {
    if (cloudLanguages.contains(languageCode)) {
      return _listenCloud(languageCode);
    }

    return _listenNative(languageCode == 'en' ? 'en_US' : 'fr_FR');
  }

  /// Arrête l'écoute en cours.
  Future<void> stopListening() async {
    _cloudRecording = false;

    if (_stt.isListening) {
      await _stt.stop();
    }
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
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
      onResult: (r) {
        result = r.recognizedWords;

        if (r.finalResult && !completer.isCompleted) {
          completer.complete(result.isEmpty ? null : result);
        }
      },
    );

    // Filet de sécurité si le moteur n'envoie jamais de résultat final.
    Future.delayed(const Duration(seconds: 21), () {
      if (!completer.isCompleted) {
        completer.complete(result.isEmpty ? null : result);
      }
    });

    return completer.future;
  }

  // --------------------------------------------------------- écoute cloud

  /// Enregistre le micro jusqu'à un silence puis envoie l'audio
  /// à RodiumAI pour transcription.
  ///
  /// Règles D2 :
  /// - permission micro obligatoire ;
  /// - fichier temporaire .m4a ;
  /// - vérification amplitude toutes les 200 ms ;
  /// - parole si amplitude > -35 dB ;
  /// - arrêt après 1,6 s de silence ;
  /// - arrêt après 20 s maximum ;
  /// - null si aucune parole ;
  /// - suppression systématique du fichier temporaire.
  Future<String?> _listenCloud(String languageCode) async {
    if (!await _recorder.hasPermission()) {
      return null;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/kultivia_${DateTime.now().millisecondsSinceEpoch}.m4a';

    var recordingStarted = false;

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      recordingStarted = true;
      _cloudRecording = true;

      var heardSpeech = false;
      var silentTicks = 0;
      var ticks = 0;

      // 200 ms × 8 = 1,6 seconde.
      while (_cloudRecording && ticks < 100) {
        await Future<void>.delayed(const Duration(milliseconds: 200));

        ticks++;

        try {
          final amp = await _recorder.getAmplitude();

          if (amp.current > -35) {
            heardSpeech = true;
            silentTicks = 0;
          } else if (heardSpeech) {
            silentTicks++;
          }
        } catch (_) {
          // On continue l'enregistrement si la lecture de l'amplitude
          // échoue ponctuellement.
        }

        if (heardSpeech && silentTicks >= 8) {
          break;
        }
      }

      _cloudRecording = false;

      final recordedPath = await _recorder.stop();
      recordingStarted = false;

      if (recordedPath == null || !heardSpeech) {
        return null;
      }

      final file = File(recordedPath);

      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();

      final text = await _cloud.transcribeAudio(
        bytes: bytes,
        mime: 'audio/mp4',
        languageCode: languageCode,
      );

      final clean = text.trim();

      return clean.isEmpty ? null : clean;
    } finally {
      _cloudRecording = false;

      // Sécurité : si une exception survient pendant l'enregistrement,
      // on arrête le recorder avant de quitter.
      if (recordingStarted) {
        try {
          await _recorder.stop();
        } catch (_) {}
      }

      // Suppression garantie du fichier temporaire.
      try {
        final tempFile = File(path);

        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('Impossible de supprimer le fichier temporaire : $e');
      }
    }
  }

  // ---------------------------------------------------------------- voix

  /// Lit [text] à voix haute et rend la main quand c'est terminé.
  Future<void> speak(
    String text, {
    String languageCode = 'fr',
  }) async {
    final clean = prepareSpeechText(text);

    if (clean.isEmpty) {
      return;
    }

    // Chaque nouvelle lecture invalide la précédente.
    final generation = ++_speechGeneration;

    await stopSpeaking(incrementGeneration: false);

    if (generation != _speechGeneration) {
      return;
    }

    if (cloudLanguages.contains(languageCode)) {
      try {
        await _speakCloud(
          clean,
          languageCode,
          generation,
        );

        return;
      } catch (e) {
        // Repli demandé par D2 : voix française native.
        debugPrint(
          'Synthèse RodiumAI indisponible, '
          'repli sur la voix native : $e',
        );

        if (generation != _speechGeneration) {
          return;
        }
      }
    }

    if (generation != _speechGeneration) {
      return;
    }

    await _speakNative(clean, languageCode);
  }

  /// Arrête toute synthèse vocale.
  ///
  /// Le paramètre interne évite d'incrémenter deux fois la génération
  /// lorsqu'une nouvelle lecture appelle stopSpeaking().
  Future<void> stopSpeaking({
    bool incrementGeneration = true,
  }) async {
    if (incrementGeneration) {
      _speechGeneration++;
    }

    try {
      await _tts.stop();
    } catch (_) {}

    try {
      await _player.stop();
    } catch (_) {}

    final playback = _playback;

    if (playback != null && !playback.isCompleted) {
      playback.complete();
    }
  }

  /// Synthèse vocale cloud puis lecture du MP3 reçu.
  Future<void> _speakCloud(
    String text,
    String languageCode,
    int generation,
  ) async {
    final bytes = await _cloud.synthesizeSpeech(
      text: text,
      languageCode: languageCode,
    );

    if (bytes.isEmpty) {
      throw StateError('Audio vide');
    }

    // stopSpeaking() peut avoir été appelé pendant l'appel réseau.
    if (generation != _speechGeneration) {
      return;
    }

    final done = Completer<void>();
    _playback = done;

    final subscription = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) {
        done.complete();
      }
    });

    try {
      if (generation != _speechGeneration) {
        return;
      }

      await _player.play(BytesSource(bytes));

      await done.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {},
      );
    } finally {
      await subscription.cancel();

      if (identical(_playback, done)) {
        _playback = null;
      }
    }
  }

  /// Synthèse vocale native du téléphone.
  Future<void> _speakNative(
    String text,
    String languageCode,
  ) async {
    await _tts.awaitSpeakCompletion(true);

    await _tts.setLanguage(
      languageCode == 'en' ? 'en-US' : 'fr-FR',
    );

    await _tts.setSpeechRate(0.45);

    await _tts.speak(text);
  }
}
