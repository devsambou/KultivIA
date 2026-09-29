const functions = require('firebase-functions');

const MAX_AUDIO_BYTES = 10 * 1024 * 1024;
const TIMEOUT_MS = 45_000;

const PROMPT_ONLY_LANGUAGES = new Set([
  'wo',
  'ln',
]);

const LANGUAGE_NAMES = {
  wo: 'wolof',
  ln: 'lingala',
};

function getConfig() {
  const apiKey = process.env.RODIUMAI_API_KEY;
  const baseUrl = process.env.RODIUMAI_BASE_URL;

  if (!apiKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configuration serveur incomplète.',
    );
  }

  if (!baseUrl) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configuration serveur incomplète.',
    );
  }

  return {
    apiKey,
    baseUrl: baseUrl.replace(/\/+$/, ''),
  };
}

function requireAuth(context) {
  if (!context || !context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Connexion requise.',
    );
  }
}

function getLanguage(data) {
  const language = String((data && data.language) || 'fr').trim();

  if (!language) {
    return 'fr';
  }

  return language.slice(0, 8);
}

function isValidMime(mime) {
  return /^audio\/[^/\s]+$/i.test(mime);
}

function decodeBase64Audio(audio) {
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(audio)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Format audio invalide.',
    );
  }

  try {
    const buffer = Buffer.from(audio, 'base64');

    if (buffer.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Audio vide.',
      );
    }

    if (buffer.length > MAX_AUDIO_BYTES) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Audio trop volumineux.',
      );
    }

    return buffer;
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'invalid-argument',
      'Format audio invalide.',
    );
  }
}

function getFileExtension(mime) {
  const extensionMap = {
    'audio/mp4': 'm4a',
    'audio/m4a': 'm4a',
    'audio/aac': 'aac',
    'audio/mpeg': 'mp3',
    'audio/wav': 'wav',
    'audio/webm': 'webm',
    'audio/ogg': 'ogg',
    'audio/flac': 'flac',
  };

  return extensionMap[mime.toLowerCase()] || 'audio';
}

function appendLanguage(form, language) {
  if (PROMPT_ONLY_LANGUAGES.has(language.toLowerCase())) {
    const languageName =
      LANGUAGE_NAMES[language.toLowerCase()] || language;

    form.append(
      'prompt',
      `Transcris fidèlement en ${languageName}, ` +
        `sans traduire. Utilise l'alphabet latin. ` +
        `Vocabulaire agricole : mildiou, mil, arachide, ` +
        `niébé, tomate, oignon, feuilles, pluie.`,
    );

    return;
  }

  form.append('language', language);
}

async function handleAiTranscribe(data, context) {
  requireAuth(context);

  const audio = String((data && data.audio) || '');
  const mime = String((data && data.mime) || '').trim();
  const language = getLanguage(data);

  if (!audio) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Audio manquant.',
    );
  }

  if (!isValidMime(mime)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Le type MIME doit être de la forme audio/...',
    );
  }

  const audioBuffer = decodeBase64Audio(audio);

  const { apiKey, baseUrl } = getConfig();

  const form = new FormData();

  form.append(
    'file',
    new Blob([audioBuffer], { type: mime }),
    `audio.${getFileExtension(mime)}`,
  );

  const model = process.env.RODIUMAI_STT_MODEL;

  if (!model) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Modèle STT non configuré.',
    );
  }

  form.append('model', model);
  form.append('response_format', 'json');

  appendLanguage(form, language);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const response = await fetch(
      `${baseUrl}/audio/transcriptions`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
        },
        body: form,
        signal: controller.signal,
      },
    );

    if (!response.ok) {
      throw new Error('RodiumAI STT request failed');
    }

    const json = await response.json();
    const text = String(json.text || '').trim();

    return {
      text,
    };
  } catch (error) {
    throw new functions.https.HttpsError(
      'internal',
      'Le service de transcription est indisponible.',
    );
  } finally {
    clearTimeout(timeout);
  }
}

exports.handleAiTranscribe = handleAiTranscribe;
exports.PROMPT_ONLY_LANGUAGES = PROMPT_ONLY_LANGUAGES;
exports.MAX_AUDIO_BYTES = MAX_AUDIO_BYTES;