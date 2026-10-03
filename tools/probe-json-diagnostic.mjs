/**
 * Test de bout en bout du MODE JSON STRUCTURE de ai-proxy.
 *
 * Pourquoi : l'utilisateur voyait du JSON brut a l'ecran. Deux causes
 * cumulatives, toutes deux corrigees :
 *   1. le proxy ne demandait pas de sortie structuree — le modele pouvait
 *      entourer l'objet de texte libre ou de fenced blocks ```json ;
 *   2. le budget de tokens (500) etait trop juste : la reponse etait
 *      tronquee en plein milieu de l'objet, donc invalide.
 *
 * Ce script rejoue EXACTEMENT l'appel que fait
 * RodiumAiService.diagnoseFromText() (meme prompt, meme temperature,
 * meme maxTokens) avec un jeton Firebase reellement emis, puis verifie
 * que `content` se parse en JSON et contient les quatre cles attendues
 * par Diagnosis.fromAiJson.
 *
 * Il rejoue aussi le comportement SANS jsonMode, pour montrer la
 * difference. C'est cette comparaison qui prouve que le correctif
 * fonctionne, pas seulement qu'il est deployed.
 *
 * Lancement : node tools/probe-json-diagnostic.mjs
 */

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import admin from 'firebase-admin';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');

const SUPABASE_URL = 'https://hyvhwsclfjnnbrpdsypt.supabase.co';
const ANON_KEY = 'sb_publishable_5A_mapSPKReSrngmluNfbA_a-gQAONP';
const FIREBASE_PROJECT_ID = 'kultivia-875cf';

const EXPECTED_KEYS = ['maladie', 'confiance', 'traitement', 'reponse_avatar'];

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

// --- Jeton Firebase reel ----------------------------------------------------

const custom = await admin.auth().createCustomToken('probe-json-diagnostic-uid');
const res = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: custom, returnSecureToken: true }),
  },
);
if (!res.ok) throw new Error(`Echange impossible (${res.status}) : ${await res.text()}`);
const { idToken } = await res.json();

// --- Prompt identique a RodiumAiService._diagnosisPrompt('fr') -------------

const SYSTEM = `Tu es l'avatar conversationnel de KultivIA, une application qui aide les
petits agriculteurs à diagnostiquer les maladies de leurs cultures.
Réponds toujours en te limitant STRICTEMENT à un objet JSON valide, sans texte
autour, avec les clés suivantes :
{
  "maladie": "nom de la maladie identifiée, ou 'Indéterminé'",
  "confiance": 0.0 à 1.0,
  "traitement": "conseil de traitement clair et actionnable, en langage simple",
  "reponse_avatar": "phrase courte, chaleureuse, à afficher à l'agriculteur"
}
Rédige "traitement" et "reponse_avatar" en Français.
"reponse_avatar" résume à l'oral, en deux ou trois phrases, la maladie et
la première chose à faire.
Tes réponses seront lues À VOIX HAUTE à des
utilisateurs qui ne savent parfois pas lire.
Phrases courtes, mots simples, pas de
symboles, pas de listes, pas de markdown, pas d'emoji. Écris les unités en
toutes lettres (litre, gramme, jour).
Si l'image ou la description est insuffisante, demande une précision dans
"reponse_avatar" et mets "maladie": "Indéterminé".`;

const USER_TEXT =
  'Mes feuilles de mil ont des taches brunes qui s elargissent et jaunissent les bords depuis trois jours.';

async function call(jsonMode, maxTokens) {
  const call = await fetch(`${SUPABASE_URL}/functions/v1/ai-proxy`, {
    method: 'POST',
    headers: {
      apikey: ANON_KEY,
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({
      messages: [
        { role: 'system', content: SYSTEM },
        { role: 'user', content: USER_TEXT },
      ],
      temperature: 0.3,
      maxTokens,
      language: 'fr',
      ...(jsonMode ? { jsonMode: true } : {}),
    }),
  });
  return { status: call.status, raw: await call.text() };
}

function tryParse(text) {
  try {
    return { ok: true, value: JSON.parse(text) };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

// --- 1. Sans jsonMode (l'ancien comportement) -------------------------------

console.log('=== 1. SANS jsonMode (ancien comportement) ===');
const legacy = await call(false, 500);
console.log('HTTP     :', legacy.status);
if (legacy.status !== 200) {
  console.log('CORPS    :', legacy.raw.slice(0, 400));
} else {
  const { content } = JSON.parse(legacy.raw);
  const parsed = tryParse(content);
  console.log('longueur :', content.length);
  console.log('JSON pur :', parsed.ok ? 'OUI' : 'NON — ' + parsed.error);
  console.log('extrait  :', JSON.stringify(content.slice(0, 160)));
}

// --- 2. Avec jsonMode (le correctif) ----------------------------------------

console.log('\n=== 2. AVEC jsonMode, maxTokens 800 (nouveau) ===');
const structured = await call(true, 800);
console.log('HTTP     :', structured.status);
if (structured.status !== 200) {
  console.log('CORPS    :', structured.raw.slice(0, 400));
  process.exit(1);
}

const { content } = JSON.parse(structured.raw);
console.log('longueur :', content.length);
console.log('recu     :', content.slice(0, 300));

const parsed = tryParse(content);
console.log('\nJSON pur :', parsed.ok ? 'OUI' : 'NON — ' + parsed.error);

if (!parsed.ok) {
  console.log('\nECHEC : le modele a encore produit autre chose que du JSON.');
  console.log('        parseAiJsonResponse() le rattraperait cote Dart,');
  console.log('        mais la carte de diagnostic ne serait pas garantie.');
  process.exit(1);
}

const obj = parsed.value;
console.log('type     :', Array.isArray(obj) ? 'tableau' : typeof obj);

const missing = EXPECTED_KEYS.filter((k) => !(k in obj));
console.log('\n=== 3. Verifications ===');
for (const k of EXPECTED_KEYS) {
  console.log(
    `  ${missing.includes(k) ? 'MANQUE' : 'ok    '} ${k} :`,
    missing.includes(k) ? '-' : JSON.stringify(obj[k])?.slice(0, 90),
  );
}

const conf = Number(obj.confiance);
console.log(
  '  confiance numerique :',
  Number.isFinite(conf) && conf >= 0 && conf <= 1 ? 'ok' : 'HORS BORNES',
);

if (missing.length > 0) {
  console.log(`\nECHEC : cles manquantes -> ${missing.join(', ')}`);
  process.exit(1);
}

console.log('\n=== Lecture ===');
console.log('  La reponse est un JSON valide et complet.');
console.log('  Diagnosis.fromAiJson peut donc remplir la carte.');
console.log('  La phrase a dire a voix haute est reponse_avatar.');
console.log('  Compare avec le bloc 1 : c est la que le JSON brut\xe9tait visible.');