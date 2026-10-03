
/**
 * Test de bout en bout du jeton Firebase contre l'Edge Function ai-proxy.
 *
 * Pourquoi : la sonde HTTP precedente prouvait que la fonction s'execute et
 * qu'elle refuse correctement un jeton forged. Elle ne prouve PAS qu'elle
 * accepte un jeton Firebase reel. Ce script en fabrique un vrai, l'envoie,
 * et affiche ce que le serveur voit reellement.
 *
 * Etapes :
 *   1. forge un custom token avec le service account (firebase-admin)
 *   2. l'echange contre un ID token via signInWithCustomToken
 *   3. decode l'ID token : on compare iss / aud / alg / kid a ce que
 *      verifyFirebaseIdToken() attend (supabase/functions/_shared/rodium.ts)
 *   4. verifie que les cles publiques Google sont bien telechargeables
 *   5. POST ai-proxy avec le vrai jeton et affiche le statut + le corps
 *
 * Lancement : node tools/probe-firebase-token.mjs
 */

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import admin from 'firebase-admin';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');

const SUPABASE_URL =
  'https://hyvhwsclfjnnbrpdsypt.supabase.co';
const ANON_KEY = 'sb_publishable_5A_mapSPKReSrngmluNfbA_a-gQAONP';
const FIREBASE_PROJECT_ID = 'kultivia-875cf';
const JWK_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

function readEnv(path) {
  if (!existsSync(path)) return {};
  const out = {};
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const i = t.indexOf('=');
    if (i < 1) continue;
    out[t.slice(0, i).trim()] = t.slice(i + 1).trim();
  }
  return out;
}

const env = readEnv(join(root, '.env'));
const apiKey = env.FIREBASE_API_KEY;
const saPath = join(root, 'tools', 'secrets', 'service-account.json');

if (!apiKey) throw new Error('FIREBASE_API_KEY absent de .env');
if (!existsSync(saPath)) throw new Error(`Service account introuvable : ${saPath}`);

admin.initializeApp({
  credential: admin.credential.cert(saPath),
  projectId: FIREBASE_PROJECT_ID,
});

// --- 3. Decode --------------------------------------------------------------

function decodeSegment(seg) {
  return JSON.parse(Buffer.from(seg.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString());
}

// --- 1 + 2. Un vrai ID token ------------------------------------------------

// Un uid factice : la verification porte sur la SIGNATURE et les claims,
// pas sur l'existence du compte. Personne ne peut se connecter avec.
const TEST_UID = 'probe-end-to-end-uid';

const custom = await admin.auth().createCustomToken(TEST_UID);
const res = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: custom, returnSecureToken: true }),
  },
);

if (!res.ok) {
  throw new Error(`Echange impossible (${res.status}) : ${await res.text()}`);
}

const { idToken } = await res.json();
const [h, p] = idToken.split('.');

const header = decodeSegment(h);
const payload = decodeSegment(p);

console.log('=== 2. ID token Firebase reellement emis ===');
console.log('alg      :', header.alg,        '| attendu RS256');
console.log('kid      :', header.kid);
console.log('iss      :', payload.iss,      '| attendu', `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`);
console.log('aud      :', payload.aud,      '| attendu', FIREBASE_PROJECT_ID);
console.log('sub      :', payload.sub);
console.log('exp      :', payload.exp, '->', new Date(payload.exp * 1000).toISOString());
console.log('expire ? :', payload.exp * 1000 <= Date.now() ? 'EXPIRE' : 'valide');

// --- 4. Cles publiques Google ----------------------------------------------

console.log('\n=== 4. Telechargement des cles publiques Google ===');
try {
  const jwksRes = await fetch(JWK_URL);
  console.log('HTTP     :', jwksRes.status);
  if (!jwksRes.ok) {
    console.log('CORPS    :', (await jwksRes.text()).slice(0, 300));
  } else {
    const { keys } = await jwksRes.json();
    console.log('nombre   :', keys.length);
    console.log('kids     :', keys.map((k) => k.kid).join(', '));
    console.log('notre kid:', header.kid, '->', keys.some((k) => k.kid === header.kid) ? 'PRESENT' : 'ABSENT');
  }
} catch (e) {
  console.log('ECHEC    :', e.message);
}

// --- 5. Appel reel ---------------------------------------------------------

console.log('\n=== 5. POST ai-proxy avec le VRAI jeton ===');

const call = await fetch(`${SUPABASE_URL}/functions/v1/ai-proxy`, {
  method: 'POST',
  headers: {
    apikey: ANON_KEY,
    'Content-Type': 'application/json',
    Authorization: `Bearer ${idToken}`,
  },
  body: JSON.stringify({
    messages: [{ role: 'user', content: 'ping' }],
    maxTokens: 20,
  }),
});

console.log('HTTP     :', call.status);
console.log('CORPS    :', (await call.text()).slice(0, 600));

console.log('\n=== Lecture ===');
if (call.status === 200) {
  console.log('  Le jeton Firebase est accepte et RodiumAI repond.');
  console.log('  Si l applique echoue quand meme, le probleme est COTE TELEPHONE.');
} else if (call.status === 401) {
  console.log('  Le serveur refuse un jeton Firebase parfaitement valide.');
  console.log('  Le suspect n 1 : FIREBASE_PROJECT_ID pose sur l Edge Function');
  console.log('  avec une valeur vide. Deno.env.get renvoie "" (pas undefined),');
  console.log('  donc le repli ?? de rodium.ts:134 ne se declenche jamais.');
} else {
  console.log('  L auth passe, le reste echoue : cle RodiumAI ou quotas.');
}