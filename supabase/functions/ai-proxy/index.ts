/**
 * Edge Function Supabase : ai-proxy
 *
 * Relais sécurisé vers RodiumAI pour le diagnostic photo et la conversation
 * avec l'avatar. La clé RodiumAI reste côté serveur : elle n'est jamais
 * envoyée au téléphone.
 *
 * Modèles : google/gemini-2.5-flash, avec repli
 * anthropic/claude-haiku-4-5-20251001 si le principal échoue.
 */

import {
  CHAT_FALLBACK_MODEL,
  CHAT_MODEL,
  HttpError,
  RODIUMAI_BASE_URL,
  errorResponse,
  jsonResponse,
  methodNotAllowed,
  normalizeLanguage,
  preflight,
  requireRodiumApiKey,
  requireUser,
} from '../_shared/rodium.ts';

const MAX_MESSAGES = 20;
const MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5 Mo

function validateMessages(messages: unknown): Record<string, unknown>[] {
  if (!Array.isArray(messages) || messages.length === 0) {
    throw new HttpError(
      400,
      `Le champ "messages" doit être un tableau de 1 à ${MAX_MESSAGES} éléments.`,
    );
  }

  if (messages.length > MAX_MESSAGES) {
    throw new HttpError(
      400,
      `Le champ "messages" doit être un tableau de 1 à ${MAX_MESSAGES} éléments.`,
    );
  }

  for (const message of messages) {
    if (message === null || typeof message !== 'object') {
      throw new HttpError(400, 'Chaque message doit être un objet.');
    }

    const content = (message as Record<string, unknown>).content;

    // Les images arrivent dans content sous forme de parties.
    if (Array.isArray(content)) {
      for (const part of content) {
        if (
          part !== null &&
          typeof part === 'object' &&
          (part as Record<string, unknown>).type === 'image_url'
        ) {
          const imageUrl = ((part as Record<string, unknown>).image_url ?? {}) as
            | Record<string, unknown>;

          const url = String(imageUrl.url ?? '');

          if (url.startsWith('data:')) {
            const base64Part = url.split(',')[1] ?? '';

            if (base64Part.length > MAX_IMAGE_SIZE) {
              throw new HttpError(
                400,
                "L'image est trop volumineuse (max 5 Mo).",
              );
            }
          }
        }
      }
    }
  }

  return messages as Record<string, unknown>[];
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

    const messages = validateMessages(body.messages);

    const temperature = Number(body.temperature ?? 0.3);

    if (Number.isNaN(temperature) || temperature < 0 || temperature > 1) {
      throw new HttpError(
        400,
        'Le champ "temperature" doit être entre 0 et 1.',
      );
    }

    const maxTokens = Number(body.maxTokens ?? 500);

    if (Number.isNaN(maxTokens) || maxTokens < 1 || maxTokens > 800) {
      throw new HttpError(
        400,
        'Le champ "maxTokens" doit être entre 1 et 800.',
      );
    }

    // jsonMode demande une sortie structurée. RodiumAI est compatible
    // OpenAI, mais rien ne garantit que TOUS les modèles le fassent :
    // si le fournisseur refuse le parametre, on rejoue sans (voir plus bas)
    // plutot que de perdre le diagnostic entier.
    const jsonMode = body.jsonMode === true;

    const payload: Record<string, unknown> = {
      messages,
      temperature,
      max_tokens: maxTokens,
    };

    if (jsonMode) {
      payload.response_format = { type: 'json_object' };
    }

    const language = normalizeLanguage(body.language);

    if (language) {
      payload.language = language;
    }

    // Jamais le contenu des messages ni les images dans les journaux.
    async function callModel(
      model: string,
      structured: boolean,
    ): Promise<Response> {
      // Type explicite : `{ ...payload, model }` se déduit en
      // `{ model: string }`, et `delete body.response_format` devient
      // alors une erreur TS2339.
      const callBody: Record<string, unknown> = { ...payload, model };

      if (!structured) delete callBody.response_format;

      return await fetch(`${RODIUMAI_BASE_URL}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify(callBody),
      });
    }

    let response = await callModel(CHAT_MODEL, jsonMode);

    // Le fournisseur ne supporte pas response_format : on retire le
    // parametre et on recommence, plutot que de renvoyer une erreur.
    if (!response.ok && jsonMode && (response.status === 400 || response.status === 422)) {
      console.warn(
        `RodiumAI ${response.status} sur response_format, nouvelle tentative sans.`,
      );

      response = await callModel(CHAT_MODEL, false);
    }

    // Le repli ne se déclenche que si le principal échoue.
    if (!response.ok && CHAT_FALLBACK_MODEL !== CHAT_MODEL) {
      console.warn(
        `RodiumAI ${response.status} sur ${CHAT_MODEL}, tentative avec ${CHAT_FALLBACK_MODEL}.`,
      );

      response = await callModel(CHAT_FALLBACK_MODEL, jsonMode);
    }

    if (!response.ok) {
      console.error(`RodiumAI ${response.status} après repli.`);

      throw new HttpError(502, 'Service IA indisponible.');
    }

    const json = await response.json();
    const choices = (json as {
      choices?: { message?: { content?: string }; finish_reason?: string }[];
      usage?: { prompt_tokens?: number; completion_tokens?: number };
    }).choices;

    const choice = choices?.[0];
    const content = choice?.message?.content ?? '';
    const finishReason = choice?.finish_reason ?? '';

    // `length` = le modele a epuise le budget de tokens et n'a pas fini sa
    // reponse. Pour un diagnostic c'est fatal : le JSON arrive tronque au
    // milieu d'une chaine, donc illisible. On remonte l'information au
    // client plutot que de lui livrer une phrase coupee en silence.
    const truncated = finishReason === 'length';

    if (truncated) {
      console.warn(
        `Reponse tronquee par le fournisseur (finish_reason=length, ` +
          `${json.usage?.completion_tokens ?? '?'} tokens de completion, ` +
          `modele=${(json as { model?: string }).model ?? '?'}).`,
      );
    }

    return jsonResponse({
      content,
      truncated,
      finishReason,
      completionTokens: json.usage?.completion_tokens ?? null,
    });
  } catch (error) {
    return errorResponse(error);
  }
});