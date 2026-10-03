// Déclarations minimales de l'API Deno.
//
// Nécessaires uniquement pour que les éditeurs (IntelliJ, VS Code) qui ne
// lisent pas `deno.json` ne signalent pas « Cannot find name 'Deno' ».
// Le vrai runtime Deno fournit ces fonctions à l'exécution.
//
// Si le plugin Deno est installé dans l'éditeur, ce fichier est ignoré.

declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
  }

  export const env: Env;

  export function serve(
    handler: (request: Request) => Response | Promise<Response>,
    options?: unknown,
  ): void;
}

// ---------------------------------------------------------------------------
// `npm:jose`
//
// Le runtime Deno résout le préfixe `npm:` sans effort (c'est lui qui
// télécharge la bibliothèque) et la Edge Function fonctionne — vérifié en
// production, HTTP 200. Mais TypeScript, lui, ne connaît pas ce
// « pseudo-scheme » : sans cette déclaration, il signale TS2307
// « Cannot find module 'npm:jose' ».
//
// Les types ci-dessous ne décrivent que ce que rodium.ts utilise réellement.
// Ils sont volontairement stricts : une déclaration en `any` masquerait
// aussi les vraies erreurs de typage.
// ---------------------------------------------------------------------------

declare module 'npm:jose' {
  export interface JWTPayload {
    iss?: string;
    sub?: string;
    aud?: string | string[];
    exp?: number;
    nbf?: number;
    iat?: number;
    jti?: string;
    [claim: string]: unknown;
  }

  export interface JWTVerifyOptions {
    issuer?: string | string[];
    audience?: string | string[];
    subject?: string;
    algorithms?: string[];
    clockTolerance?: string | number;
    maxTokenAge?: string | number;
  }

  export interface JWTVerifyResult {
    payload: JWTPayload;
    protectedHeader: Record<string, unknown>;
  }

  export interface RemoteJWKSetOptions {
    cacheMaxAge?: number;
    cooldownDuration?: number;
    timeoutDuration?: number;
  }

  /** JWK distant (JWKS) : gère le cache et la rotation des clés. */
  export function createRemoteJWKSet(
    url: URL,
    options?: RemoteJWKSetOptions,
  ): unknown;

  /** Vérifie signature, issuer, audience et expiration. Lève si invalide. */
  export function jwtVerify(
    token: string,
    key: unknown,
    options?: JWTVerifyOptions,
  ): Promise<JWTVerifyResult>;
}