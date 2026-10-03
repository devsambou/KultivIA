/**
 * Réplication Firestore → Supabase.
 *
 * Écrit dans la copie Supabase ce que Firestore a déjà accepté. Firestore
 * reste la source de vérité : cet appel est déclench APRÈS l'écriture
 * Firestore, et son échec n'a aucune conséquence sur l'utilisateur.
 *
 * Pourquoi une Edge Function plutôt que le client : les politiques RLS de
 * Supabase s'appuient sur `auth.uid()`, qui ne lit que les jetons Supabase.
 * Les utilisateurs de KultivIA se connectent avec Firebase, donc `auth.uid()`
 * renverrait null et toute écriture directe serait refusée. On utilise donc la
 * clé `service_role` (qui contourne RLS) tout en vérifiant soi-même le jeton
 * Firebase de l'appelant.
 *
 * Les règles de conflit vivent dans des fonctions SQL (`sync_user_lww`,
 * `sync_diagnosis_append`) et non ici : la comparaison et l'écriture doivent
 * être atomiques, sinon deux réplications concurrentes pourraient passer le
 * test et la dernière écraserait la première.
 */

import {
  HttpError,
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  preflight,
  requireUser,
} from '../_shared/rodium.ts';

/** Clé de service : contourne RLS. Ne doit jamais quitter le serveur. */
function serviceRoleKey(): string {
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!key) {
    throw new HttpError(500, 'Configuration serveur incomplète.');
  }

  return key;
}

function supabaseUrl(): string {
  const url = Deno.env.get('SUPABASE_URL');

  if (!url) {
    throw new HttpError(500, 'Configuration serveur incomplète.');
  }

  return url;
}

/** Appelle une fonction SQL de réplication avec la clé de service. */
async function callSyncFunction(
  fn: string,
  payload: Record<string, unknown>,
): Promise<boolean> {
  const response = await fetch(`${supabaseUrl()}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: serviceRoleKey(),
      Authorization: `Bearer ${serviceRoleKey()}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const detail = await response.text();

    // Le détail reste dans les logs : il peut contenir des noms de colonnes.
    console.error(
      `Échec ${fn} :`,
      response.status,
      detail.slice(0, 500),
    );

    throw new HttpError(502, 'Réplication indisponible.');
  }

  // Les fonctions renvoient `true` si la ligne a été écrite, `false` si la
  // garde de conflit l'a ignorée. Ce n'est pas une erreur : c'est le
  // last-write-wins qui fait son travail.
  return (await response.json()) === true;
}

// ------------------------------------------------------------ Normalisation

function asString(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

function asOptionalString(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function asBool(value: unknown): boolean {
  return value === true;
}

/** Borne la confiance entre 0 et 1, comme le fait le modèle Dart. */
function asConfidence(value: unknown): number {
  const n = typeof value === 'number' ? value : Number(value);

  if (!Number.isFinite(n)) return 0;

  return Math.min(1, Math.max(0, n));
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];

  return value.filter((v): v is string => typeof v === 'string');
}

/** Date ISO valide, ou null. Un timestamp invalide ferait échouer l'appel. */
function asIsoDate(value: unknown): string | null {
  const raw = asString(value);

  if (!raw) return null;

  const parsed = Date.parse(raw);

  return Number.isNaN(parsed) ? null : new Date(parsed).toISOString();
}

// -------------------------------------------------------------- Collections

async function syncUser(uid: string, data: Record<string, unknown>) {
  const sourceUpdatedAt = asIsoDate(data.updatedAt);

  // Sans timestamp source, impossible d'arbitrer : refuser vaut mieux que
  // risquer d'écraser une ligne plus récente.
  if (!sourceUpdatedAt) {
    throw new HttpError(400, 'Horodatage source manquant.');
  }

  const written = await callSyncFunction('sync_user_lww', {
    p_uid: uid,
    p_display_name: asString(data.displayName),
    p_photo_url: asOptionalString(data.photoUrl),
    p_role: asString(data.role, 'farmer'),
    p_locality: asString(data.locality),
    p_crops: asStringArray(data.crops),
    p_language_code: asString(data.languageCode, 'fr'),
    p_ai_language_code: asString(data.aiLanguageCode, 'fr'),
    p_notifications_enabled: asBool(data.notificationsEnabled),
    p_voice_replies: asBool(data.voiceReplies),
    p_theme_mode: typeof data.themeMode === 'number' ? data.themeMode : 0,
    p_phone_number: asString(data.phoneNumber),
    p_phone_country_code: asString(data.phoneCountryCode, '+221'),
    p_profile_completed: asBool(data.profileCompleted),
    p_source_updated_at: sourceUpdatedAt,
  });

  return { written, ignored: !written };
}

async function syncDiagnosis(uid: string, data: Record<string, unknown>) {
  const id = asString(data.id);
  const date = asIsoDate(data.date);

  if (!id) {
    throw new HttpError(400, 'Diagnostic sans identifiant.');
  }

  if (!date) {
    throw new HttpError(400, 'Diagnostic sans date valide.');
  }

  const written = await callSyncFunction('sync_diagnosis_append', {
    p_id: id,
    p_uid: uid,
    p_date: date,
    p_image_path: asOptionalString(data.imagePath),
    p_input_text: asString(data.inputText),
    p_disease: asString(data.disease, 'Indéterminé'),
    p_confidence: asConfidence(data.confidence),
    p_advice: asString(data.advice),
    p_source_updated_at: asIsoDate(data.updatedAt) ?? date,
  });

  return { written, ignored: !written };
}

// ------------------------------------------------------------------ Handler

Deno.serve(async (request: Request) => {
  const cors = preflight(request);

  if (cors) return cors;

  if (request.method !== 'POST') return methodNotAllowed();

  try {
    // Vérifie le jeton Firebase (ou Supabase) et renvoie l'uid. C'est ce
    // contrôle qui remplace les politiques RLS, inutilisables ici.
    const uid = await requireUser(request);

    const body = (await request.json().catch(() => null)) as Record<
      string,
      unknown
    > | null;

    const collection = asString(body?.collection);

    if (collection !== 'user' && collection !== 'diagnosis') {
      throw new HttpError(400, 'Collection inconnue.');
    }

    const data = (body?.data ?? {}) as Record<string, unknown>;

    const result = collection === 'user'
      ? await syncUser(uid, data)
      : await syncDiagnosis(uid, data);

    return jsonResponse({ ok: true, collection, ...result });
  } catch (error) {
    return errorResponse(error);
  }
});