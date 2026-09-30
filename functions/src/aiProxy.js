/**
 * Cloud Function aiProxy : relais sécurisé vers RodiumAI.
 *
 * Cette fonction garde la clé API RodiumAI côté serveur (dans un secret Firebase)
 * et relaie les requêtes de l'app Flutter vers l'API RodiumAI.
 *
 * Variables d'environnement (optionnelles, dans functions/.env) :
 *   RODIUMAI_BASE_URL : URL de base de l'API (défaut : https://api.rodiumai.io/v1)
 *   RODIUMAI_CHAT_MODEL : modèle à utiliser (défaut : auto)
 *
 * Secret (à configurer une fois) :
 *   firebase functions:secrets:set RODIUMAI_API_KEY
 */

// `fetch` global de Node 20 (le fetch de node-fetch v2 ne gère pas FormData
// et n'est pas interceptable par les tests, qui mockent global.fetch).
const functions = require('firebase-functions');

const DEFAULT_BASE_URL = 'https://api.rodiumai.io/v1';
const MAX_MESSAGES = 20;

// Lu à chaque appel, et non au chargement du module : les variables
// d'environnement Firebase ne sont pas toujours defined au moment du require.
function getChatUrl() {
  const baseUrl = process.env.RODIUMAI_BASE_URL || DEFAULT_BASE_URL;
  return `${baseUrl.replace(/\/+$/, '')}/chat/completions`;
}
const MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5 Mo

/**
 * Fonction appelable aiProxy.
 *
 * Entrée :
 *   { messages: [...], temperature?: number, maxTokens?: number, language?: string }
 *   - messages : tableau de messages (max 20)
 *   - temperature : 0 à 1 (défaut 0.3)
 *   - maxTokens : 1 à 800 (défaut 500)
 *   - language : code langue (optionnel)
 *
 * Sortie :
 *   { content: "<texte de la réponse>" }
 *
 * Erreurs :
 *   - unauthenticated : utilisateur non connecté
 *   - failed-precondition : clé API non configurée
 *   - invalid-argument : paramètres invalides
 *   - internal : erreur du service RodiumAI
 */
// Handler nu, exporté pour être testé directement (voir test/aiProxy.test.js).
async function handleAiProxy(data, context) {
// Authentification requise
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Connexion requise.');
  }

  // Vérifier que la clé API est configurée
  const apiKey = process.env.RODIUMAI_API_KEY;
  if (!apiKey) {
    throw new functions.https.HttpsError('failed-precondition', 'Clé RodiumAI non configurée côté serveur.');
  }

  // Validation des entrées
  const { messages, temperature = 0.3, maxTokens = 500, language } = data || {};

  if (!Array.isArray(messages) || messages.length === 0 || messages.length > MAX_MESSAGES) {
    throw new functions.https.HttpsError('invalid-argument', `Le champ "messages" doit être un tableau de 1 à ${MAX_MESSAGES} éléments.`);
  }

  const temp = Number(temperature);
  if (isNaN(temp) || temp < 0 || temp > 1) {
    throw new functions.https.HttpsError('invalid-argument', 'Le champ "temperature" doit être entre 0 et 1.');
  }

  const tokens = Number(maxTokens);
  if (isNaN(tokens) || tokens < 1 || tokens > 800) {
    throw new functions.https.HttpsError('invalid-argument', 'Le champ "maxTokens" doit être entre 1 et 800.');
  }

  // Vérifier la taille des images dans les messages (data: URL)
  for (const msg of messages) {
    if (msg.content && Array.isArray(msg.content)) {
      for (const part of msg.content) {
        if (part.type === 'image_url' && part.image_url && part.image_url.url) {
          const url = part.image_url.url;
          if (url.startsWith('data:')) {
            const base64Part = url.split(',')[1];
            if (base64Part && base64Part.length > MAX_IMAGE_SIZE) {
              throw new functions.https.HttpsError('invalid-argument', 'L\'image est trop volumineuse (max 5 Mo).');
            }
          }
        }
      }
    }
  }

  // Appel à l'API RodiumAI
  try {
    const response = await fetch(getChatUrl(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: process.env.RODIUMAI_CHAT_MODEL || 'auto',
        messages,
        temperature: temp,
        max_tokens: tokens,
        ...(language ? { language: String(language).slice(0, 8) } : {}),
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`RodiumAI ${response.status}: ${errText}`);
      throw new functions.https.HttpsError('internal', 'Service IA indisponible.');
    }

    const json = await response.json();
    return { content: json.choices?.[0]?.message?.content ?? '' };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Erreur aiProxy:', error);
    throw new functions.https.HttpsError('internal', 'Service IA indisponible.');
  }
}

exports.handleAiProxy = handleAiProxy;

exports.aiProxy = functions.https.onCall(
  { secrets: ['RODIUMAI_API_KEY'], timeoutSeconds: 60, memory: '512MB' },
  handleAiProxy,
);
