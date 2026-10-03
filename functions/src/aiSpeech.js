/**
 * Cloud Function aiSpeech : synthèse vocale (texte -> audio mp3) via RodiumAI.
 *
 * Utilisée pour les langues que le téléphone ne sait pas parler
 * (wolof, lingala). Pour le français et l anglais, l'app utilise
 * le moteur natif et n'appelle jamais cette fonction.
 *
 * Variables d'environnement (dans functions/.env) :
 *   RODIUMAI_BASE_URL    : URL de base de l'API RodiumAI
 *   RODIUMAI_TTS_MODEL   : modèle TTS par défaut
 *   RODIUMAI_TTS_MODEL_<CODE> : modèle dédié à une langue (ex. _WO, _LN)
 *   RODIUMAI_TTS_VOICE   : voix à utiliser
 *
 * Secret (à configurer une fois) :
 *   firebase functions:secrets:set RODIUMAI_API_KEY
 */

const functions = require('firebase-functions');

/**
 * Options de déploiement.
 *
 * Firebase Secrets exige le plan Blaze. Sur le plan gratuit (Spark), la clé
 * est simplement lue depuis functions/.env, chargé automatiquement par le
 * SDK juste après ce require. On ne déclare donc le secret que s'il est
 * réellement disponible : sinon le déploiement échoue au démarrage de la
 * fonction.
 *
 * À basculer sur `secrets` dès que le plan Blaze est actif.
 */
const CALL_OPTIONS = process.env.RODIUMAI_API_KEY
  ? { timeoutSeconds: 60, memory: '512MB' }
  : {
      secrets: ['RODIUMAI_API_KEY'],
      timeoutSeconds: 60,
      memory: '512MB',
    };

const MAX_SPEECH_CHARS = 600;
const TIMEOUT_MS = 45_000;

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

function getTtsModel(language) {
  const defaultModel = process.env.RODIUMAI_TTS_MODEL;

  if (!defaultModel) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Modèle TTS non configuré.',
    );
  }

  if (/^[a-z]{2,8}$/i.test(language)) {
    const languageModel =
      process.env[`RODIUMAI_TTS_MODEL_${language.toUpperCase()}`];

    if (languageModel) {
      return languageModel;
    }
  }

  return defaultModel;
}

async function handleAiSpeech(data, context) {
  requireAuth(context);

  const text = String((data && data.text) || '').trim();

  if (!text || text.length > MAX_SPEECH_CHARS) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Le champ "text" doit contenir 1 à ${MAX_SPEECH_CHARS} caractères.`,
    );
  }

  const language = getLanguage(data);
  const model = getTtsModel(language);
  const { apiKey, baseUrl } = getConfig();

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const response = await fetch(`${baseUrl}/audio/speech`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        input: text,
        voice: process.env.RODIUMAI_TTS_VOICE || 'nova',
        response_format: 'mp3',
        speed: 0.95,
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      throw new Error('RodiumAI TTS request failed');
    }

    const audioBuffer = Buffer.from(await response.arrayBuffer());

    if (audioBuffer.length === 0) {
      throw new Error('RodiumAI TTS returned empty audio');
    }

    return {
      audio: audioBuffer.toString('base64'),
    };
  } catch (error) {
    throw new functions.https.HttpsError(
      'internal',
      'Le service de synthèse vocale est indisponible.',
    );
  } finally {
    clearTimeout(timeout);
  }
}

exports.handleAiSpeech = handleAiSpeech;
exports.MAX_SPEECH_CHARS = MAX_SPEECH_CHARS;

exports.aiSpeech = functions.https.onCall(CALL_OPTIONS, handleAiSpeech);