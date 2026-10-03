/**
 * Cloud Functions KultivIA.
 *
 * Ce fichier ne contient QUE des ré-exports. Chaque fonction a son propre
 * fichier dans src/, afin que chaque lot puisse modifier la sienne sans
 * risque de conflit (voir l'issue A2 de docs/ISSUES.md).
 *
 * - aiProxy        : relaie les appels chat/vision vers RodiumAI en gardant
 *                    la clé côté serveur (elle ne doit JAMAIS être dans
 *                    l'app Flutter).
 * - aiSpeech       : synthèse vocale (texte -> audio mp3), pour les langues
 *                    que le téléphone ne sait pas parler (wolof, lingala).
 * - aiTranscribe   : reconnaissance vocale (audio -> texte), pour dicter
 *                    dans ces mêmes langues.
 * - dailyWeatherAlerts : chaque matin à 06h00 (Africa/Dakar), prévient les
 *                    utilisateurs dont la localité présente un risque de
 *                    maladie fongique ou de forte chaleur.
 * - notifyNewReport : envoie une notification push au topic « alerts » quand
 *                    un signalement communautaire est publié.
 *
 * Configuration de la clé (une seule fois, côté serveur) :
 *   firebase functions:secrets:set RODIUMAI_API_KEY
 *
 * Modèles et URL (dans functions/.env, jamais commité) :
 *   RODIUMAI_BASE_URL=https://api.rodiumai.io/v1
 *   RODIUMAI_CHAT_MODEL=google/gemini-2.5-flash
 *   RODIUMAI_TTS_MODEL=google/gemini-2.5-flash-tts
 *   RODIUMAI_STT_MODEL=google/gemini-3.5-transcribe
 *
 * Déploiement :
 *   cd functions && npm install && npm run deploy
 */

const admin = require('firebase-admin');

admin.initializeApp();

// Ré-exports des Cloud Functions (chaque fonction a son propre fichier dans src/)
exports.aiProxy = require('./src/aiProxy').aiProxy;
exports.aiSpeech = require('./src/aiSpeech').aiSpeech;
exports.aiTranscribe = require('./src/aiTranscribe').aiTranscribe;
exports.notifyNewReport = require('./src/notifyReport').notifyReport;
exports.dailyWeatherAlerts =
  require('./src/weatherAlerts').dailyWeatherAlerts;
