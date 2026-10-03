/**
 * Cloud Function aiProxy : relais sécurisé vers RodiumAI.
 *
 * Cette fonction garde la clé API RodiumAI côté serveur (dans un secret Firebase)
 * et relaie les requêtes de l'app Flutter vers l'API RodiumAI.
 *
 * Variables d'environnement (dans functions/.env) :
 *   RODIUMAI_BASE_URL : URL de base de l'API (défaut : https://api.rodiumai.io/v1)
 *   RODIUMAI_CHAT_MODEL : modèle principal (défaut : google/gemini-2.5-flash)
 *   RODIUMAI_CHAT_MODEL_FALLBACK : modèle de repli quand le principal échoue
 *     (défaut : anthropic/claude-haiku-4-5-20251001)
 *
 * Secret (à configurer une fois) :
 *   firebase functions:secrets:set RODIUMAI_API_KEY
 */

// `fetch` global de Node 20 (le fetch de node-fetch v2 ne gère pas FormData
// et n'est pas interceptable par les tests, qui mockent global.fetch).
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

const DEFAULT_BASE_URL = 'https://api.rodiumai.io/v1';
const DEFAULT_CHAT_MODEL = 'google/gemini-2.5-flash';
const DEFAULT_FALLBACK_MODEL = 'anthropic/claude-haiku-4-5-20251001';
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

  // Modèles : le principal, et un repli utilisé uniquement en cas d'échec.
  const primaryModel = process.env.RODIUMAI_CHAT_MODEL || DEFAULT_CHAT_MODEL;
  const fallbackModel =
    process.env.RODIUMAI_CHAT_MODEL_FALLBACK || DEFAULT_FALLBACK_MODEL;

  const payload = {
    messages,
    temperature: temp,
    max_tokens: tokens,
    ...(language ? { language: String(language).slice(0, 8) } : {}),
  };

  // Jamais le contenu des messages ni les images dans les journaux.
  async function callModel(model) {
    return fetch(getChatUrl(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({ ...payload, model }),
    });
  }

  try {
    let response = await callModel(primaryModel);

    // Le repli ne se déclenche que si le modèle principal échoue et que
    // ce n'est pas déjà le modèle de repli.
    if (!response.ok && fallbackModel !== primaryModel) {
      console.warn(
        `RodiumAI ${response.status} sur ${primaryModel}, `
        + `tentative avec ${fallbackModel}.`,
      );

      response = await callModel(fallbackModel);
    }

    if (!response.ok) {
      console.error(`RodiumAI ${response.status} après repli.`);
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

exports.aiProxy = functions.https.onCall(CALL_OPTIONS, handleAiProxy);
