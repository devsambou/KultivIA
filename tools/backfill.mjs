/**
 * Backfill Firestore → Supabase.
 *
 * ## Pourquoi
 *
 * La double écriture (`SupabaseMirror`) ne réplique que ce qui est écrit
 * *après* son activation. Deux catégories de données manquent donc :
 *
 *  1. l'historique antérieur à l'activation ;
 *  2. les écritures faites hors ligne, où Firestore a accepté mais où
 *     l'appel réseau vers Supabase a échoué.
 *
 * Ce script rattrape les deux en relisant Firestore et en réinjectant dans
 * Supabase.
 *
 * ## Idempotence
 *
 * Le script peut être relancé autant de fois que nécessaire : les règles de
 * conflit vivent en base et rendent chaque écriture sûre.
 *
 * - `users` : last-write-wins sur `source_updated_at`. Une écriture plus
 *   ancienne que la copie existante est ignorée, pas écrasée.
 * - `diagnoses` : `on conflict do nothing` sur `id`, qui est un timestamp en
 *   microsecondes et n'est donc jamais réécrit.
 *
 * Un backfill ne peut donc pas dégrader le réplica, seulement le compléter.
 *
 * ## Prérequis
 *
 * Deux secrets, tous deux obtenables depuis les dashboards Firebase et
 * Supabase.
 *
 * **1. La clé de compte de service Firebase**
 * (Firebase console → Paramètres du projet → Comptes de service →
 * « Générer une nouvelle clé privée »). C'est un fichier JSON.
 *
 * Déposez-le dans `tools/secrets/service-account.json`. Ce dossier est ignoré
 * par git, le dépôt reste propre, et le script le trouve sans configuration.
 *
 * À défaut, `GOOGLE_APPLICATION_CREDENTIALS` reste honoré, ainsi que les
 * identifiants par défaut de la machine (`gcloud auth application-default
 * login`).
 *
 * **2. La clé `service_role` Supabase**
 * (dashboard Supabase → Project Settings → API → `service_role`).
 *
 * Collez-la dans `tools/secrets/supabase.env` sous la forme
 * `SUPABASE_SERVICE_ROLE_KEY=eyJ...`. Ce fichier est ignoré par git.
 *
 * Elle contourne RLS : elle ne doit jamais être commitée ni laissée dans un
 * `.env` versionné. `SUPABASE_SERVICE_ROLE_KEY` en variable
 * d'environnement prend le pas si elle est définie.
 *
 * ## Usage
 *
 *   node tools/backfill.mjs --dry-run   # compte, n'écrit rien
 *   node tools/backfill.mjs             # écrit
 *   node tools/backfill.mjs --users     # profils seuls
 *
 * Le `--dry-run` n'a besoin **que** des identifiants Firebase : il compte sans
 * jamais contacter Supabase.
 */

import { cert, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// --------------------------------------------------------------- Configuration

const HERE = fileURLToPath(new URL('.', import.meta.url));
const SECRETS = join(HERE, 'secrets');

const SUPABASE_URL =
  process.env.SUPABASE_URL ?? 'https://hyvhwsclfjnnbrpdsypt.supabase.co';

const args = new Set(process.argv.slice(2));
const DRY_RUN = args.has('--dry-run');
const ONLY_USERS = args.has('--users');
const ONLY_DIAGNOSES = args.has('--diagnoses');

/**
 * Lit `KEY=valeur` dans un fichier `.env` minimal. Suffisant ici : une seule
 * clé, pas d'échappement, pas de multiligne.
 */
function readKeyFile(path, key) {
  if (!existsSync(path)) return null;

  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (match?.[1] === key) return match[2].replace(/^["']|["']$/g, '');
  }

  return null;
}

const SERVICE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ??
  readKeyFile(join(SECRETS, 'supabase.env'), 'SUPABASE_SERVICE_ROLE_KEY');

// Le dry-run n'écrit rien, il n'a donc aucune raison d'exiger la clé
// service_role : c'est le moyen de vérifier l'accès à Firestore avant de
// toucher à Supabase.
if (!SERVICE_KEY && !DRY_RUN) {
  console.error(
    'Clé service_role Supabase introuvable.\n' +
      '\n' +
      'Créez tools/secrets/supabase.env contenant une seule ligne :\n' +
      '\n' +
      '  SUPABASE_SERVICE_ROLE_KEY=eyJ...\n' +
      '\n' +
      'Dashboard Supabase → Project Settings → API → service_role.\n' +
      'Cette clé contourne RLS : tools/secrets/ est ignoré par git.\n' +
      '\n' +
      'Pour juste compter, sans rien écrire : node tools/backfill.mjs --dry-run',
  );
  process.exit(1);
}

// ------------------------------------------------------------ Firebase Admin

/**
 * Cherche la clé de compte de service là où l'utilisateur l'a mise, plutôt que
 * de l'obliger à définir une variable d'environnement : une session de
 * terminal est trop fragile pour garder un `set` d'une commande à l'autre.
 */
function resolveFirebaseCredential() {
  const explicit = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (explicit) return { kind: 'cert', source: explicit };

  const conventional = join(SECRETS, 'service-account.json');
  if (existsSync(conventional)) return { kind: 'cert', source: conventional };

  // Identifiants par défaut de la machine (`gcloud auth application-default
  // login`). firebase-admin les trouve seul ; s'ils manquent, l'erreur
  // ci-dessous est plus parlante que celle de google-auth-library.
  return { kind: 'adc', source: null };
}

const credential = resolveFirebaseCredential();

if (credential.kind === 'adc' && DRY_RUN) {
  // `applicationDefault()` n'échoue qu'à la première requête. On peut donc
  // tenter, et seulement si Firestore refuse, expliquer quoi faire.
  console.log(
    "Aucune clé de compte de service trouvée, essai des identifiants par défaut.",
  );
}

const app = initializeApp({
  // `cert()` attend un CHEMIN, pas le contenu du fichier. Lui passer le texte
  // fait réinterpréter le JSON lui-même comme un nom de fichier.
  credential:
    credential.kind === 'cert' ? cert(credential.source) : applicationDefault(),
});

const firestore = getFirestore(app);

/**
 * Message d'erreur orienté quand Firestore refuse l'accès.
 *
 * La session `firebase login` ne suffit pas : le CLI range ses identifiants dans
 * sa propre configuration, que firebase-admin ne lit pas. La clé de compte de
 * service reste donc nécessaire.
 */
function explainAuthFailure(error) {
  console.error(
    `\nLecture de Firestore refusée : ${error.message}\n` +
      '\n' +
      'La session `firebase login` ne suffit pas : le CLI range ses\n' +
      'identifiants dans sa propre configuration, que firebase-admin ne lit pas.\n' +
      'Il faut une clé de compte de service.\n' +
      '\n' +
      '  1. console.firebase.google.com → Paramètres du projet →\n' +
      '     Comptes de service → « Générer une nouvelle clé private»\n' +
      '  2. Déposer le fichier téléchargé dans tools/secrets/service-account.json\n' +
      '  3. Relancer : node tools/backfill.mjs --dry-run\n' +
      '\n' +
      "tools/secrets/ est ignoré par git : le dépôt reste propre.",
  );
}

// ------------------------------------------------------------------ Supabase

async function callRpc(fn, payload) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const detail = (await response.text()).slice(0, 300);
    throw new Error(`${fn} -> HTTP ${response.status} : ${detail}`);
  }

  return (await response.json()) === true;
}

const asString = (v, fallback = '') => (typeof v === 'string' ? v : fallback);
const asBool = (v) => v === true;

/** Date ISO exploitable par Postgres, ou null si la valeur est illisible. */
function asIsoDate(value) {
  const raw = typeof value === 'string' ? value : null;
  if (!raw) return null;

  const parsed = Date.parse(raw);
  if (Number.isNaN(parsed)) return null;

  return new Date(parsed).toISOString();
}

/**
 * `updatedAt` a été ajouté à `UserProfile.toMap()` au moment de l'activation de
 * la double écriture. Les profils plus anciens n'en ont pas.
 *
 * On retombe alors sur `createTime` du document Firestore : c'est au plus la
 * date de la dernière écriture connue, donc une borne basse. Le last-write-wins
 * garantit qu'un profil réellement modifié depuis ne sera pas écrasé par cette
 * approximation.
 *
 * Renvoie `null` si rien n'est exploitable. Écrire l'époque Unix (1970) serait
 * pire que l'ignorer : le last-write-wins ferait perdre ce profil contre
 * n'importe quelle copie existante, et l'échec resterait silencieux.
 */
function sourceUpdatedAt(doc) {
  const explicit = asIsoDate(doc.data()?.updatedAt);
  if (explicit) return explicit;

  const createTime = doc.createTime?.toDate?.();
  return createTime ? createTime.toISOString() : null;
}

// ------------------------------------------------------------------ Profils

async function backfillUsers() {
  const snapshot = await firestore.collection('users').get();

  let written = 0;
  let ignored = 0;
  let skipped = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data() ?? {};

    // Pas de `const sourceUpdatedAt` ici : ce nom masquerait la fonction et
    // lèverait « Cannot access before initialization ».
    const sourceAt = sourceUpdatedAt(doc);

    if (!sourceAt) {
      console.warn(`  ${doc.id} : horodatage illisible, ignoré.`);
      skipped += 1;
      continue;
    }

    if (DRY_RUN) {
      written += 1;
      continue;
    }

    const applied = await callRpc('sync_user_lww', {
      p_uid: doc.id,
      p_display_name: asString(data.displayName),
      p_photo_url: typeof data.photoUrl === 'string' ? data.photoUrl : null,
      p_role: asString(data.role, 'farmer'),
      p_locality: asString(data.locality),
      p_crops: Array.isArray(data.crops)
        ? data.crops.filter((c) => typeof c === 'string')
        : [],
      p_language_code: asString(data.languageCode, 'fr'),
      p_ai_language_code: asString(data.aiLanguageCode, 'fr'),
      p_notifications_enabled: asBool(data.notificationsEnabled),
      p_voice_replies: asBool(data.voiceReplies),
      p_theme_mode: typeof data.themeMode === 'number' ? data.themeMode : 0,
      p_phone_number: asString(data.phoneNumber),
      p_phone_country_code: asString(data.phoneCountryCode, '+221'),
      p_profile_completed: asBool(data.profileCompleted),
      p_source_updated_at: sourceAt,
    });

    if (applied) written += 1;
    else ignored += 1;
  }

  console.log(
    `Profils : ${written} écrit(s), ${ignored} ignoré(s) comme plus ancien(s)` +
      `${skipped > 0 ? `, ${skipped} illisible(s)` : ''}.`,
  );
}

// --------------------------------------------------------------- Diagnostics

async function backfillDiagnoses() {
  // Pas de `orderBy` : le tri n'apporte rien à une réplication, et Firestore
  // exigerait pour cela un index COLLECTION_GROUP_DESC qui n'est pas déployé.
  const snapshot = await firestore.collectionGroup('diagnoses').get();

  let written = 0;
  let alreadyThere = 0;
  let skipped = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data() ?? {};
    const uid = doc.ref.parent.parent?.id;

    if (!uid) {
      console.warn(`  ${doc.id} : document hors de users/{uid}/diagnoses.`);
      skipped += 1;
      continue;
    }

    // `id` est un timestamp en microsecondes : jamais réécrit, donc
    // `on conflict do nothing` suffit à rendre cette opération idempotente.
    const id = asString(data.id, doc.id);
    const date = asIsoDate(data.date) ?? asIsoDate(doc.createTime?.toDate?.());

    if (!id || !date) {
      console.warn(`  ${doc.id} : identifiant ou date illisible, ignoré.`);
      skipped += 1;
      continue;
    }

    if (DRY_RUN) {
      written += 1;
      continue;
    }

    const confidence = Number(data.confidence);
    const clamped = Number.isFinite(confidence)
      ? Math.min(1, Math.max(0, confidence))
      : 0;

    const applied = await callRpc('sync_diagnosis_append', {
      p_id: id,
      p_uid: uid,
      p_date: date,
      p_image_path: typeof data.imagePath === 'string' ? data.imagePath : null,
      p_input_text: asString(data.inputText),
      p_disease: asString(data.disease, 'Indéterminé'),
      p_confidence: clamped,
      p_advice: asString(data.advice),
      p_source_updated_at: asIsoDate(data.updatedAt) ?? date,
    });

    if (applied) written += 1;
    else alreadyThere += 1;
  }

  console.log(
    `Diagnostics : ${written} écrit(s), ${alreadyThere} déjà présent(s)` +
      `${skipped > 0 ? `, ${skipped} illisible(s)` : ''}.`,
  );
}

// --------------------------------------------------------------------- Main

async function main() {
  console.log(DRY_RUN ? 'Simulation (--dry-run).' : 'Backfill en cours.');

  if (!ONLY_DIAGNOSES) await backfillUsers();
  if (!ONLY_USERS) await backfillDiagnoses();

  console.log('Terminé. Vérifier l\'écart restant :');
  console.log('  select * from sync_gap;   -- doit renvoyer 0 ligne');
}

main().catch((error) => {
  // Un refus d'authentification mérite une explication, pas un simple code de
  // sortie. « Unable to detect a Project Id » est la forme que prend
  // l'absence d'identifiants par défaut sur cette machine.
  const authFailure =
    /credential|default credentials|UNAUTHENTICATED|PERMISSION_DENIED|permission|Project Id|environment/i.test(
      error.message,
    );

  if (authFailure) {
    explainAuthFailure(error);
  } else {
    console.error('Échec du backfill :', error.message);
  }

  process.exit(1);
});