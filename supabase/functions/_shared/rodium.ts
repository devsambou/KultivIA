/**
 * Module partagé par les Edge Functions IA de KultivIA.
 *
 * Rôle : garder la clé RodiumAI côté serveur, refuser les appels anonymes
// et renvoyer des erreurs propres. La clé n'est jamais envoyée au téléphone.
 */

// `jose` est la référence pour vérifier une signature RS256 en Deno : elle gère
// l'import du JWK, la rotation des clés et le cache. Elle remplace le code
// maison qui refusait des jetons pourtant parfaitement valides (voir
// « Vérification jeton Firebase » plus bas).
import { createRemoteJWKSet, jwtVerify } from 'npm:jose';

// ---------------------------------------------------------------- Configuration

export const RODIUMAI_BASE_URL =
    Deno.env.get('RODIUMAI_BASE_URL') ?? 'https://api.rodiumai.io/v1';

// Modèles autorisés Flufithon '26 (voir kultivia-modeles-ia.md).
export const CHAT_MODEL =
    Deno.env.get('RODIUMAI_CHAT_MODEL') ?? 'google/gemini-2.5-flash';

export const CHAT_FALLBACK_MODEL =
    Deno.env.get('RODIUMAI_CHAT_MODEL_FALLBACK') ??
    'anthropic/claude-haiku-4-5-20251001';

// Gemini Flash TTS est obligatoire : openai/tts-1 ne parle ni wolof ni lingala.
export const TTS_MODEL =
    Deno.env.get('RODIUMAI_TTS_MODEL') ?? 'google/gemini-2.5-flash-tts';

export const TTS_VOICE = Deno.env.get('RODIUMAI_TTS_VOICE') ?? 'nova';

export const STT_MODEL =
    Deno.env.get('RODIUMAI_STT_MODEL') ?? 'google/gemini-3.5-transcribe';

/** Modèle TTS dédié à une langue (WO, LN...), sinon le modèle par défaut. */
export function ttsModelFor(languageCode: string): string {
  const code = languageCode.trim().toUpperCase();

  if (/^[A-Z]{2,8}$/.test(code)) {
    const dedicated = Deno.env.get(`RODIUMAI_TTS_MODEL_${code}`);

    if (dedicated) return dedicated;
  }

  return TTS_MODEL;
}

// ------------------------------------------------------------------- Erreurs

/** Erreur portant un code HTTP, renvoyée telle quelle au client. */
export class HttpError extends Error {
  constructor(
      readonly status: number,
      message: string,
  ) {
    super(message);
  }
}

// --------------------------------------------------------- Authentification

/**
 * Vérifie que l'appel vient bien d'un utilisateur connecté.
 *
 * L'application supporte DEUX fournisseurs d'identité (voir ISSUES.md, lot D) :
 * l'utilisateur peut être connecté avec Firebase Auth ou avec Supabase Auth.
 * On accepte donc les deux types de jetons :
 *
 * - un jeton Supabase, vérifié en ligne via `/auth/v1/user` ;
 * - un jeton Firebase, vérifié localement : signature RS256 contre les
 *   clés publiques (JWK) de Google, puis contrôle de `iss`, `aud` et `exp`.
 *
 * Renvoie une HttpError 401 si l'appel est anonyme ou le jeton expiré.
 */
export async function requireUser(request: Request): Promise<string> {
  const header = request.headers.get('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';

  if (!token) {
    throw new HttpError(401, 'Connexion requise.');
  }

  const supabaseUserId = await verifySupabaseToken(token);

  if (supabaseUserId) return supabaseUserId;

  const firebaseUserId = await verifyFirebaseIdToken(token).catch((error) => {
    console.error('Vérification Firebase impossible :', error);
    return null;
  });

  if (firebaseUserId) return firebaseUserId;

  throw new HttpError(401, 'Session expirée, reconnectez-vous.');
}

/** Vérifie un jeton Supabase. Renvoie null si ce n'en est pas un. */
async function verifySupabaseToken(token: string): Promise<string | null> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');

  if (!supabaseUrl || !anonKey) return null;

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: anonKey,
    },
  }).catch(() => null);

  if (!response?.ok) return null;

  const user = (await response.json()) as { id?: string };

  return user.id ?? null;
}

// ------------------------------------------------- Vérification jeton Firebase

// Clés publiques de signature Firebase au format JWK : directement
// importables dans WebCrypto (contrairement aux certificats X.509).
const FIREBASE_JWKS_URL =
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

/**
 * Identifiant du projet Firebase attendu dans `iss` et `aud`.
 *
 * Ce n'est PAS un secret : il est déjà dans le .env embarqué dans l'APK. La
 * variable d'environnement reste prioritaire pour cibler un autre projet.
 *
 * `||` et NON `??` : Deno.env.get() renvoie la chaîne vide si la variable
 * existe mais est vide, et `??` ne rattrape pas ce cas. Avec `??`, une
 * variable vide donnait `iss` attendu = « https://securetoken.google.com/ »,
 * et TOUS les jetons étaient rejetés — sans message d'erreur exploitable.
 */
export const FIREBASE_PROJECT =
    (Deno.env.get('FIREBASE_PROJECT_ID') ?? '').trim() || 'kultivia-875cf';

/**
 * Jeu de clés publiques Google, mis en cache 1 h.
 *
 * jose gère l'import du JWK et la rotation des clés. C'est précisément ce que
 * le code précédent faisait à la main avec `crypto.subtle.importKey`, et
 * c'est ce code-là qui renvoyait 401 pour un jeton dont la signature RS256
 * était pourtant valide et dont le `kid` était bien présent dans le JWKS
 * (reproduit le 03/10/2026, puis corrigé — voir tools/repro-verify.mjs).
 */
let firebaseJwks: ReturnType<typeof createRemoteJWKSet> | null = null;

function firebasePublicKeys(): ReturnType<typeof createRemoteJWKSet> {
  if (!firebaseJwks) {
    firebaseJwks = createRemoteJWKSet(new URL(FIREBASE_JWKS_URL), {
      cacheMaxAge: 60 * 60 * 1000,
      cooldownDuration: 30 * 1000,
      timeoutDuration: 10 * 1000,
    });
  }

  return firebaseJwks;
}

/**
 * Vérifie un jeton Firebase ID.
 *
 * Deux temps : des contrôles gratuits sur l'en-tête et les claims (alg, iss,
 * aud, exp) qui évitent un appel réseau quand le jeton est manifestement
 * inutilisable, puis la vérification de signature par jose.
 *
 * Renvoie l'uid, ou null si le jeton n'est pas un jeton Firebase valide.
 */
async function verifyFirebaseIdToken(token: string): Promise<string | null> {
  const parts = token.split('.');

  if (parts.length !== 3) return null;

  let header: { alg?: string };
  let payload: { iss?: string; aud?: string; exp?: number };

  try {
    header = decodeJwtSegment(parts[0]) as { alg?: string };
    payload = decodeJwtSegment(parts[1]) as {
      iss?: string;
      aud?: string;
      exp?: number;
    };
  } catch {
    return null;
  }

  if (header.alg !== 'RS256') return null;

  // Un jeton Firebase est émis par Google pour CE projet, et pour ce projet
  // uniquement. Ces deux contrôles empêchent qu'un jeton d'un autre projet
  // Firebase (ou d'un autre émetteur) soit accepté ici.
  const expectedIssuer = `https://securetoken.google.com/${FIREBASE_PROJECT}`;

  if (payload.iss !== expectedIssuer) return null;
  if (payload.aud !== FIREBASE_PROJECT) return null;
  if (!payload.exp || payload.exp * 1000 <= Date.now()) return null;

  try {
    const { payload: verified } = await jwtVerify(token, firebasePublicKeys(), {
      issuer: expectedIssuer,
      audience: FIREBASE_PROJECT,
      algorithms: ['RS256'],
    });

    return verified.sub ?? null;
  } catch {
    return null;
  }
}

/**
 * Décode du base64url en octets. Le type de retour explicite
 * `Uint8Array<ArrayBuffer>` est exigé par WebCrypto (BufferSource).
 */
function base64UrlToBytes(value: string): Uint8Array<ArrayBuffer> {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padding = (4 - (base64.length % 4)) % 4;
  const binary = atob(base64 + '='.repeat(padding));
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));

  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }

  return bytes;
}

function decodeJwtSegment(segment: string): unknown {
  return JSON.parse(
      new TextDecoder().decode(base64UrlToBytes(segment)),
  );
}

/** Renvoie la clé RodiumAI ou une erreur claire. */
export function requireRodiumApiKey(): string {
  const key = Deno.env.get('RODIUMAI_API_KEY');

  if (!key) {
    throw new HttpError(
        500,
        'Clé RodiumAI non configurée côté serveur.',
    );
  }

  return key;
}

// ------------------------------------------------------------------ Réponses

export function corsHeaders(): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers':
        'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

export function jsonResponse(
    body: unknown,
    status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(),
      'Content-Type': 'application/json',
    },
  });
}

/**
 * Réponse d'erreur : le message est générique, pour ne jamais laisser
 * fuir le détail de l'appel au fournisseur.
 */
export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) {
    return jsonResponse({ error: error.message }, error.status);
  }

  console.error('Erreur inattendue :', error);

  return jsonResponse({ error: 'Service indisponible.' }, 500);
}

export function methodNotAllowed(): Response {
  return jsonResponse({ error: 'Méthode non autorisée.' }, 405);
}

/** Réponse à la requête OPTIONS de preflight CORS. */
export function preflight(request: Request): Response | null {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() });
  }

  return null;
}

/** Nettoie un code langue : 2 à 8 caractères, français par défaut. */
export function normalizeLanguage(value: unknown): string {
  const raw = String(value ?? '').trim();

  if (!raw) return 'fr';

  return raw.slice(0, 8);
}