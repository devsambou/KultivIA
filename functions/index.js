/**
 * Cloud Functions KultivIA.
 *
 * - aiProxy : relaie les appels à RodiumAI en gardant la clé côté serveur
 *   (elle ne doit JAMAIS être dans l'app Flutter).
 * - aiSpeech : synthèse vocale (texte -> audio mp3) via RodiumAI, pour que
 *   l'avatar parle aux utilisateurs qui ne lisent pas.
 * - aiTranscribe : reconnaissance vocale (audio -> texte) via RodiumAI, utilisée
 *   pour le wolof (le moteur natif du téléphone ne le gère pas).
 * - dailyWeatherRisk : chaque matin, prévient les utilisateurs (notifications
 *   activées) dont la localité a un risque de maladie ou de forte chaleur.
 * - notifyNewReport : envoie une notification push à tous les abonnés du
 *   topic « alerts » quand un signalement communautaire est publié.
 *
 * Configuration de la clé (une seule fois, côté serveur) :
 *   firebase functions:secrets:set RODIUMAI_API_KEY
 *
 * Modèles audio (optionnels, fichier functions/.env) :
 *   RODIUMAI_TTS_MODEL=openai/tts-1            RODIUMAI_TTS_VOICE=nova
 *   RODIUMAI_TTS_MODEL_WO=...                  (modèle dédié au wolof, si vous en avez un)
 *   RODIUMAI_STT_MODEL=google/gemini-2.5-flash
 *
 * Déploiement :
 *   cd functions && npm install && npm run deploy
 */

const functions = require('firebase-functions');
const { dailyWeatherAlerts } = require('./src/weatherAlerts');

const admin = require('firebase-admin');
const fetch = require('node-fetch');


admin.initializeApp();

const RODIUMAI_BASE = 'https://api.rodiumai.io/v1';
const MAX_SPEECH_CHARS = 600;
// Langues sans code ISO reconnu par les modèles de transcription : on les guide par le prompt.
// Pour ajouter une langue locale, ajoutez son code ici et un prompt dans aiTranscribe.
const PROMPT_ONLY_LANGUAGES = new Set(['wo']);
const MAX_AUDIO_BASE64_CHARS = 6000000; // ~4,5 Mo d'audio
const ALERTS_TOPIC = 'alerts';

// Ré-exports des Cloud Functions (chaque fonction a son propre fichier dans src/)
exports.aiProxy = require('./src/aiProxy').aiProxy;
exports.notifyNewReport = require('./src/notifyReport').notifyReport;
exports.dailyWeatherAlerts = dailyWeatherAlerts;

function requireAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Connexion requise.');
  }
  const apiKey = process.env.RODIUMAI_API_KEY;
  if (!apiKey) {
    throw new functions.https.HttpsError('failed-precondition', 'Clé RodiumAI non configurée côté serveur.');
  }
  return apiKey;
}

exports.aiSpeech = functions.https.onCall(
  { secrets: ['RODIUMAI_API_KEY'], timeoutSeconds: 60 },
  async (data, context) => {
    const apiKey = requireAuth(context);

    const text = String((data && data.text) || '').trim();
    const language = String((data && data.language) || 'fr').slice(0, 8);
    if (!text || text.length > MAX_SPEECH_CHARS) {
      throw new functions.https.HttpsError('invalid-argument', `Le champ "text" doit contenir 1 à ${MAX_SPEECH_CHARS} caractères.`);
    }

    const defaultModel = process.env.RODIUMAI_TTS_MODEL || 'openai/tts-1';
    // Modèle dédié à une langue : RODIUMAI_TTS_MODEL_<CODE> (ex. RODIUMAI_TTS_MODEL_WO).
    const perLanguage = /^[a-z]{2,3}$/i.test(language) ? process.env[`RODIUMAI_TTS_MODEL_${language.toUpperCase()}`] : undefined;
    const model = perLanguage || defaultModel;

    const response = await fetch(`${RODIUMAI_BASE}/audio/speech`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model,
        input: text,
        voice: process.env.RODIUMAI_TTS_VOICE || 'nova',
        response_format: 'mp3',
        speed: 0.95,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`RodiumAI speech ${response.status}: ${errText}`);
      throw new functions.https.HttpsError('internal', `Erreur du service vocal (${response.status}).`);
    }

    const audio = await response.buffer();
    return { audio: audio.toString('base64'), mime: 'audio/mpeg' };
  },
);

const AUDIO_EXTENSIONS = {
  'audio/mp4': 'm4a',
  'audio/m4a': 'm4a',
  'audio/aac': 'aac',
  'audio/mpeg': 'mp3',
  'audio/wav': 'wav',
  'audio/webm': 'webm',
};

exports.aiTranscribe = functions.https.onCall(
  { secrets: ['RODIUMAI_API_KEY'], timeoutSeconds: 60, memory: '512MB' },
  async (data, context) => {
    const apiKey = requireAuth(context);

    const audioB64 = String((data && data.audio) || '');
    const mime = String((data && data.mime) || 'audio/mp4');
    const language = String((data && data.language) || 'fr').slice(0, 8);
    if (!audioB64 || audioB64.length > MAX_AUDIO_BASE64_CHARS) {
      throw new functions.https.HttpsError('invalid-argument', 'Audio manquant ou trop volumineux.');
    }

    const bytes = Buffer.from(audioB64, 'base64');
    const form = new FormData();
    form.append('file', new Blob([bytes], { type: mime }), `audio.${AUDIO_EXTENSIONS[mime] || 'm4a'}`);
    form.append('model', process.env.RODIUMAI_STT_MODEL || 'google/gemini-2.5-flash');
    form.append('response_format', 'json');
    if (PROMPT_ONLY_LANGUAGES.has(language)) {
      // Pas d'indice de langue ISO fiable : on guide le modèle par le prompt.
      const names = { wo: 'wolof' };
      form.append(
        'prompt',
        `Transcris fidèlement en ${names[language] || language} (alphabet latin). Vocabulaire agricole : mildiou, mil, arachide, niébé, tomate, oignon, feuilles, pluie.`,
      );
    } else {
      form.append('language', language);
    }

    // fetch global de Node 20 (le fetch de node-fetch v2 ne gère pas FormData).
    const response = await globalThis.fetch(`${RODIUMAI_BASE}/audio/transcriptions`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}` },
      body: form,
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`RodiumAI transcription ${response.status}: ${errText}`);
      throw new functions.https.HttpsError('internal', `Erreur de transcription (${response.status}).`);
    }

    const json = await response.json();
    return { text: String(json.text || '').trim() };
  },
);
