/**
 * Edge Function Supabase : ai-speech
 *
 * Synthèse vocale (texte -> audio mp3) via RodiumAI, pour les langues que le
 * téléphone ne sait pas parler : wolof et lingala. Le français et l'anglais
 * utilisent le moteur natif et n'arrivent jamais ici.
 *
 * Modèle : google/gemini-2.5-flash-tts. C'est indispensable, car
 * openai/tts-1 ne sait ni produire de wolof ni de lingala.
 */

import {
  HttpError,
  RODIUMAI_BASE_URL,
  TTS_VOICE,
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  normalizeLanguage,
  preflight,
  requireRodiumApiKey,
  requireUser,
  ttsModelFor,
} from '../_shared/rodium.ts';

const MAX_SPEECH_CHARS = 600;

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

    const text = String(body.text ?? '').trim();

    if (!text || text.length > MAX_SPEECH_CHARS) {
      throw new HttpError(
        400,
        `Le champ "text" doit contenir 1 à ${MAX_SPEECH_CHARS} caractères.`,
      );
    }

    const language = normalizeLanguage(body.language);
    const model = ttsModelFor(language);

    const response = await fetch(`${RODIUMAI_BASE_URL}/audio/speech`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        input: text,
        voice: TTS_VOICE,
        response_format: 'mp3',
        speed: 0.95,
      }),
    });

    if (!response.ok) {
      // Jamais le détail du fournisseur au client.
      console.error(`RodiumAI TTS ${response.status} (modèle ${model}).`);

      throw new HttpError(
        502,
        'Le service de synthèse vocale est indisponible.',
      );
    }

    const audio = new Uint8Array(await response.arrayBuffer());

    if (audio.length === 0) {
      throw new HttpError(
        502,
        'Le service de synthèse vocale est indisponible.',
      );
    }

    // Base64 : le transport JSON de Supabase ne gère pas le binaire brut.
    let binary = '';

    for (const byte of audio) {
      binary += String.fromCharCode(byte);
    }

    return jsonResponse({
      audio: btoa(binary),
      mime: 'audio/mpeg',
    });
  } catch (error) {
    return errorResponse(error);
  }
});