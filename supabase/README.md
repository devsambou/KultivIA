# Edge Functions Supabase - KultivIA

Relais serveur vers RodiumAI : diagnostic photo, conversation, synthèse
vocale et dictée. La clé RodiumAI **ne quitte jamais le serveur**.

## Pourquoi Supabase et pas Firebase

Les Cloud Functions Firebase exigent le plan **Blaze (pay-as-you-go)**,
même pour un projet de hackathon. Les Edge Functions Supabase ont un quota
généreux gratuit (500 000 invocations/mois) et se déploient sans carte
bancaire.

Le code Firebase (`functions/`) est conservé et fonctionne toujours, mais
son déploiement nécessite Blaze. Le backend actif se choisit avec la
variable `AI_BACKEND` dans `.env` (`supabase` par défaut, `firebase` sinon).

## Les trois fonctions

| Fonction | Rôle | Modèle |
|----------|------|--------|
| `ai-proxy` | Diagnostic photo/texte et chat avec l'avatar | `google/gemini-2.5-flash`, repli `anthropic/claude-haiku-4-5-20251001` |
| `ai-speech` | Synthèse vocale (wolof, lingala) | `google/gemini-2.5-flash-tts` |
| `ai-transcribe` | Dictée (wolof, lingala) | `google/gemini-3.5-transcribe` |

> Le TTS est **indispensable** pour les langues locales : `openai/tts-1` ne
> produit ni wolof ni lingala. C'est ce qui bloque l'issue D8 si on garde ce
> modèle par défaut.

## Déploiement

### 1. Installer la CLI Supabase

```bash
npm install -g supabase
supabase login
```

### 2. Relier le projet (déjà fait si `supabase/config.toml` est présent)

```bash
supabase link --project-ref hyvhwsclfjnnbrpdsypt
```

### 3. Poser les secrets

```bash
supabase secrets set RODIUMAI_API_KEY=rd_sk_prod_votre_cle
```

Les modèles ont déjà des valeurs par défaut dans `_shared/rodium.ts`. Pour
les changer sans toucher au code :

```bash
supabase secrets set \
  RODIUMAI_BASE_URL=https://api.rodiumai.io/v1 \
  RODIUMAI_CHAT_MODEL=google/gemini-2.5-flash \
  RODIUMAI_TTS_MODEL=google/gemini-2.5-flash-tts \
  RODIUMAI_TTS_MODEL_WO=google/gemini-2.5-flash-tts \
  RODIUMAI_TTS_MODEL_LN=google/gemini-2.5-flash-tts \
  RODIUMAI_STT_MODEL=google/gemini-3.5-transcribe
```

### 4. Déployer

```bash
supabase functions deploy ai-proxy
supabase functions deploy ai-speech
supabase functions deploy ai-transcribe
```

### 5. Tester

```bash
flutter run
```

Dans l'app : profil → langue Wolof → micro → dicter une phrase → écouter.

## Sécurité

- `requireUser()` lit le header `Authorization` et valide le token auprès de
  `/auth/v1/user`. Sans session valide, réponse **401** avant tout appel.
- `verify_jwt = false` dans `config.toml` est **délibéré** : l'app supporte
  deux fournisseurs d'authentification (Supabase *et* Firebase). Un
  utilisateur connecté via Firebase n'a pas de session Supabase, et la
  vérification automatique de la passerelle le rejetterait à tort. La
  vérification stricte est donc faite dans le code, avant tout accès à la
  clé.
- Les erreurs du fournisseur ne sont jamais renvoyées au client : le message
  est générique, le détail va dans les journaux serveur.
- Aucun contenu de message ni image n'est journalisé.

## Ajouter une langue

Pour ajouter une langue cloud (dictée + voix), voir
[`docs/AJOUTER_UNE_LANGUE.md`](../docs/AJOUTER_UNE_LANGUE.md). Côté serveur,
il faut aussi :
1. ajouter le code dans `PROMPT_ONLY_LANGUAGES` (ai-transcribe) si la langue
   n'a pas de code ISO reconnu ;
2. ajouter un `LANGUAGE_NAMES[code]` pour nommer la langue dans le prompt ;
3. poser `RODIUMAI_TTS_MODEL_<CODE>` si un modèle dédié est nécessaire.

## Tester en local

```bash
supabase functions serve ai-proxy --env-file .env
```

L'émulateur recharge le code à chaque requête, sans redéploiement.