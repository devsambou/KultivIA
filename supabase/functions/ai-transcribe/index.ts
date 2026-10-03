/**
 * Edge Function Supabase : ai-transcribe
 *
 * Reconnaissance vocale (audio -> texte) via RodiumAI, pour dicter en wolof
 * ou en lingala. Le français et l'anglais utilisent le moteur natif du
 * téléphone et n'arrivent jamais ici.
 *
 * Modèle : google/gemini-3.5-transcribe (modèle dédié, plus fiable qu'un
 * modèle de chat).
 */

import {
  HttpError,
  RODIUMAI_BASE_URL,
  STT_MODEL,
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  normalizeLanguage,
  preflight,
  requireRodiumApiKey,
  requireUser,
} from '../_shared/rodium.ts';

const MAX_AUDIO_BYTES = 10 * 1024 * 1024; // 10 Mo

/**
 * Langues sans code ISO reconnu par les modèles de transcription : on les
 * guide par le prompt plutôt que par le paramètre `language`.
 *
 * C'est ce qui fait fonctionner le wolof et le lingala.
 */
const PROMPT_ONLY_LANGUAGES = new Set(['wo', 'ln']);

const LANGUAGE_NAMES: Record<string, string> = {
  wo: 'wolof',
  ln: 'lingala',
};

function isValidMime(mime: string): boolean {
  return /^audio\/[^/\s]+$/i.test(mime);
}

/**
 * Le type de retour explicite `Uint8Array<ArrayBuffer>` est exigé par
 * `Blob` (BlobPart) avec les versions récentes de TypeScript/Deno.
 */
function decodeBase64Audio(audio: string): Uint8Array<ArrayBuffer> {
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(audio)) {
    throw new HttpError(400, 'Format audio invalide.');
  }

  let bytes: Uint8Array<ArrayBuffer>;

  try {
    const binary = atob(audio);

    bytes = new Uint8Array(new ArrayBuffer(binary.length));

    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
  } catch {
    // atob() échoue sur une chaîne qui n'est pas du base64 valide.
    throw new HttpError(400, 'Format audio invalide.');
  }

  if (bytes.length === 0) {
    throw new HttpError(400, 'Audio vide.');
  }

  if (bytes.length > MAX_AUDIO_BYTES) {
    throw new HttpError(400, 'Audio trop volumineux.');
  }

  return bytes;
}

function fileExtension(mime: string): string {
  const extensions: Record<string, string> = {
    'audio/mp4': 'm4a',
    'audio/m4a': 'm4a',
    'audio/aac': 'aac',
    'audio/mpeg': 'mp3',
    'audio/wav': 'wav',
    'audio/webm': 'webm',
    'audio/ogg': 'ogg',
    'audio/flac': 'flac',
  };

  return extensions[mime.toLowerCase()] ?? 'audio';
}

Deno.serve(async (request: Request) => {
  const cors = preflight(request);

  if (cors) return cors;

  if (request.method !== 'POST') return methodNotAllowed();

  try {
    await requireUser(request);

    const apiKey = requireRodiumApiKey();

    let body: Record<string, unknown>;

    try {
      body = await request.json();
    } catch {
      throw new HttpError(400, 'Corps de requête JSON invalide.');
    }

    const audio = String(body.audio ?? '');
    const mime = String(body.mime ?? '').trim();
    const language = normalizeLanguage(body.language);

    if (!audio) {
      throw new HttpError(400, 'Audio manquant.');
    }

    if (!isValidMime(mime)) {
      throw new HttpError(
          400,
          'Le type MIME doit être de la forme audio/...',
      );
    }

    const audioBytes = decodeBase64Audio(audio);

    const form = new FormData();

    form.append(
        'file',
        new Blob([audioBytes], { type: mime }),
        `audio.${fileExtension(mime)}`,
    );

    form.append('model', STT_MODEL);
    form.append('response_format', 'json');

    const lower = language.toLowerCase();

    if (PROMPT_ONLY_LANGUAGES.has(lower)) {
      const name = LANGUAGE_NAMES[lower] ?? language;

      form.append(
          'prompt',
          `Transcris fidèlement en ${name}, sans traduire. ` +
          `Utilise l'alphabet latin. ` +
          `Vocabulaire agricole : mildiou, mil, arachide, niébé, tomate, ` +
          `oignon, feuilles, pluie.`,
      );
    } else {
      form.append('language', language);
    }

    const response = await fetch(
        `${RODIUMAI_BASE_URL}/audio/transcriptions`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
          },
          body: form,
        },
    );

    if (!response.ok) {
      console.error(`RodiumAI STT ${response.status}.`);

      throw new HttpError(502, 'Le service de transcription est indisponible.');
    }

    const json = (await response.json()) as { text?: string };

    return jsonResponse({ text: String(json.text ?? '').trim() });
  } catch (error) {
    return errorResponse(error);
  }
});