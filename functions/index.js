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
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const fetch = require('node-fetch');
const { assessRisks, alertMessage } = require('./weather_rules');

admin.initializeApp();

const RODIUMAI_BASE = 'https://api.rodiumai.io/v1';
const GEOCODING_URL = 'https://geocoding-api.open-meteo.com/v1/search';
const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';
const ALERT_COOLDOWN_MS = 3 * 24 * 60 * 60 * 1000; // pas plus d'une alerte météo tous les 3 jours
const MAX_SPEECH_CHARS = 600;
// Langues sans code ISO reconnu par les modèles de transcription : on les guide par le prompt.
// Pour ajouter une langue locale, ajoutez son code ici et un prompt dans aiTranscribe.
const PROMPT_ONLY_LANGUAGES = new Set(['wo']);
const MAX_AUDIO_BASE64_CHARS = 6000000; // ~4,5 Mo d'audio
const ALERTS_TOPIC = 'alerts';

// Ré-exports des Cloud Functions (chaque fonction a son propre fichier dans src/)
exports.aiProxy = require('./src/aiProxy').aiProxy;

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

// Open-Meteo : gratuit, sans clé. La localité saisie au paramétrage est
// convertie en coordonnées (Sénégal d'abord, puis monde entier).
async function geocodeLocality(name) {
  for (const country of ['&countryCode=SN', '']) {
    const url = `${GEOCODING_URL}?name=${encodeURIComponent(name)}&count=1&language=fr&format=json${country}`;
    const res = await fetch(url);
    if (!res.ok) continue;
    const json = await res.json();
    const hit = json.results && json.results[0];
    if (hit) return { lat: hit.latitude, lng: hit.longitude };
  }
  return null;
}

async function fetchDailyForecast(lat, lng) {
  const url =
    `${FORECAST_URL}?latitude=${lat}&longitude=${lng}` +
    '&daily=precipitation_probability_max,relative_humidity_2m_max,temperature_2m_max' +
    '&forecast_days=3&timezone=auto';
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Open-Meteo ${res.status}`);
  return (await res.json()).daily;
}

exports.dailyWeatherRisk = onSchedule(
    {
      schedule: 'every day 06:00',
      timeZone: 'Africa/Dakar',
      timeoutSeconds: 300,
      memory: '256MB',
    },
    async () => {
    const db = admin.firestore();
    const snap = await db.collection('users').where('notificationsEnabled', '==', true).get();

    // Un seul appel météo par localité, même s'il y a beaucoup d'utilisateurs.
    const byLocality = new Map();
    for (const doc of snap.docs) {
      const u = doc.data();
      const locality = String(u.locality || '').trim();
      if (!locality || !u.fcmToken) continue;
      const last = u.lastWeatherAlertAt && u.lastWeatherAlertAt.toMillis ? u.lastWeatherAlertAt.toMillis() : 0;
      if (Date.now() - last < ALERT_COOLDOWN_MS) continue;
      const key = locality.toLowerCase();
      if (!byLocality.has(key)) byLocality.set(key, { name: locality, docs: [] });
      byLocality.get(key).docs.push(doc);
    }

    let sent = 0;
    for (const { name, docs } of byLocality.values()) {
      try {
        const geo = await geocodeLocality(name);
        if (!geo) {
          console.warn(`Localité introuvable : ${name}`);
          continue;
        }
        const risks = assessRisks(await fetchDailyForecast(geo.lat, geo.lng));
        if (!risks.fungal && !risks.heat) continue;

        for (const doc of docs) {
          const user = doc.data();
          const msg = alertMessage(risks, user.languageCode);
          try {
            await admin.messaging().send({
              token: user.fcmToken,
              notification: { title: msg.title, body: msg.body },
              data: { type: 'weather_risk' },
              android: { priority: 'high' },
            });
            await doc.ref.update({ lastWeatherAlertAt: admin.firestore.FieldValue.serverTimestamp() });
            sent++;
          } catch (e) {
            console.error(`Envoi impossible à ${doc.id} : ${e.code || e.message}`);
            if (e.code === 'messaging/registration-token-not-registered') {
              await doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
            }
          }
        }
      } catch (e) {
        console.error(`Alerte météo impossible pour ${name} : ${e.message}`);
      }
    }
      console.log(`Alertes météo envoyées : ${sent}`);
    },
  );

exports.notifyNewReport = onDocumentCreated(
  { document: 'signalements/{postId}' },
  async (event) => {
    const report = event.data?.data() || {};
    const disease = String(report.disease || 'une maladie').slice(0, 80);
    await admin.messaging().send({
      topic: ALERTS_TOPIC,
      notification: {
        title: 'Nouveau signalement',
        body: `Une maladie a été signalée par la communauté : ${disease}.`,
      },
      data: { type: 'community_report', postId: event.params.postId },
    });
  },
);
