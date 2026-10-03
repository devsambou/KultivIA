# Architecture KultivIA

## Vue d'ensemble

KultivIA est une application mobile Flutter qui aide les petits agriculteurs à diagnostiquer les maladies de leurs cultures via une IA conversationnelle multimodale (vision, texte, audio).

## Structure du projet

```
lib/
├── core/                    # Cœur de l'application
│   ├── constants/           # Constantes globales
│   │   └── app_constants.dart
│   ├── config/              # Configuration de l'app
│   │   └── app_config.dart
│   ├── errors/              # Exceptions personnalisées
│   │   └── app_exceptions.dart
│   ├── json/                # Sérialiseurs JSON
│   │   └── json_serializers.dart
│   └── theme/               # Design system
│       └── theme.dart
├── data/                    # Données statiques
│   └── vendors_seed.dart
├── models/                  # Modèles de données
│   ├── conversation.dart
│   ├── diagnosis.dart
│   └── user_profile.dart
├── repositories/            # Pattern Repository (abstraction data)
│   ├── conversation_repository.dart
│   ├── diagnosis_repository.dart
│   ├── firebase_conversation_repository.dart
│   ├── firebase_diagnosis_repository.dart
│   └── mirrored_diagnosis_repository.dart
├── screens/                 # Écrans de l'application
│   ├── auth/                # Authentification
│   │   └── auth_screen.dart
│   ├── community/           # Partage communautaire
│   │   └── community_screen.dart
│   ├── health/              # Diagnostic et santé
│   │   ├── diagnosis_result_screen.dart
│   │   └── health_dashboard_screen.dart
│   ├── market/              # Marketplace et vendeurs
│   │   ├── marketplace_screen.dart
│   │   └── vendors_map_screen.dart
│   ├── settings/            # Paramètres utilisateur
│   │   ├── language_screen.dart
│   │   ├── profile_screen.dart
│   │   └── settings_screen.dart
│   ├── weather/             # Alertes météo
│   │   └── weather_alerts_screen.dart
│   ├── onboarding/          # Première utilisation
│   │   └── onboarding_screen.dart
│   ├── home_ai/             # Écran principal IA (sous-composants)
│   │   ├── composer.dart
│   │   ├── empty_state.dart
│   │   ├── home_ai_screen.dart
│   │   ├── message_view.dart
│   │   └── typing_dots.dart
│   ├── setup/               # Configuration initiale
│   │   ├── setup_bottom_bar.dart
│   │   ├── setup_controller.dart
│   │   ├── setup_screen.dart
│   │   ├── step_exploitation.dart
│   │   ├── step_identity.dart
│   │   └── step_preferences.dart
│   ├── gate/                # Écran de démarrage
│   │   ├── farm_scene.dart
│   │   ├── gate_screen.dart
│   │   ├── scan_scene.dart
│   │   └── scene_kit.dart
│   └── history/             # Historique des diagnostics
│       └── history_screen.dart
├── services/                # Services métier
│   ├── auth/                # Firebase Auth
│   │   └── firebase_service.dart
│   ├── ai/                  # RodiumAI (vision, chat, TTS, STT)
│   │   ├── avatar_intents.dart
│   │   └── rodium_ai_service.dart
│   ├── data/                # Gestion des données
│   │   ├── conversation_history.dart
│   │   └── diagnosis_history.dart
│   ├── sync/                # Réplication Firestore → Supabase
│   │   └── supabase_mirror.dart
│   ├── ui/                  # Services UI (voix)
│   │   └── voice_service.dart
│   ├── external/            # APIs externes (météo, vendeurs)
│   │   ├── vendor_links.dart
│   │   └── weather_service.dart
│   └── system/              # Services système (état, notifications)
│       ├── app_state.dart
│       ├── notification_service.dart
│       └── user_settings.dart
├── widgets/                 # Composants UI réutilisables
│   ├── app_drawer.dart
│   └── k_components.dart
└── main.dart                # Point d'entrée
```

## Architecture technique

### Design System
- **Tokens** : KSpace (espacements), KRadius (rayons), KStatus (couleurs sémantiques)
- **Thème** : Adaptatif clair/sombre, extension ThemeExtension pour KStatus
- **Composants** : KCard, KButton, etc. dans `widgets/k_components.dart`

### Pattern Repository
- `DiagnosisRepository` (interface) → `FirebaseDiagnosisRepository` (implémentation)
- `MirroredDiagnosisRepository` décore `FirebaseDiagnosisRepository` pour
  ajouter la réplication Supabase, sans modifier le dépôt d'origine
- `ConversationRepository` (interface) → `FirebaseConversationRepository`
- Abstraction pour faciliter les tests et le changement d'implémentation

### Profil : un point de sortie unique
Les huit écrans qui modifient le profil passent tous par
`FirebaseService.saveProfile()`. La réplication y est branchée, ce qui évite de
toucher chaque écran et garantit qu'aucune écriture de profil ne soit
oubliée.

### State Management
- **Provider** pour l'état global
- Services principaux : `AppState`, `UserSettings`, `DiagnosisHistory`,
  `ConversationHistory`
- `SetupController` pour le flux de configuration

### Services IA (RodiumAI)
- **Sécurité** : la clé RodiumAI n'existe que côté serveur. Le mobile
  n'appelle jamais `api.rodium.ai` directement.
- **Fonctions** : `supabase/functions/`
  - `ai-proxy` : diagnostic vision + chat
  - `ai-speech` : synthèse vocale
  - `ai-transcribe` : reconnaissance vocale
  - `sync-write` : réplication Firestore → Supabase
- Les trois premières partagent `_shared/rodium.ts`, qui vérifie le jeton de
  l'appelant avant de joindre RodiumAI.
- `functions/` conserve l'implémentation Firebase précédente. Elle n'est plus
  déployée : le quota gratuit du plan Spark est insuffisant pour les Cloud
  Functions, ce qui est une des raisons de la migration vers Supabase.

### Firebase
- **Auth** : Email/Google/Apple/Téléphone - **seule identité de l'application**
- **Firestore** : Profils, diagnostics, signalements, marketplace, discussions

## Historique des discussions

Avant, une conversation vivait en mémoire : fermer l'application ou toucher
« Nouvelle conversation » effaçait tout l'échange. L'historique est désormais
persisté dans Firestore, sous `users/{uid}/conversations/{id}`.

### Ce qui est stocké, et ce qui ne l'est pas

Un tour (`ConversationTurn`) est une version *persistable* de `ChatEntry`, et deux
champs sont volontairement dégradés :

| Stocké | Non stocké | Pourquoi |
|---|---|---|
| `hadPhoto` (booléen) | `imagePath` | Un chemin de fichier ne survit pas à un redémarrage : le tiroir rouvrirait une image cassée. |
| `diagnosisId` | le `Diagnosis` complet | Un diagnostic est déjà dans sa propre collection ; le dupliquer gonflerait chaque relecture et créerait deux vérités contradictoires. |

À la relecture, `_rehydrate()` rattache chaque `diagnosisId` au `Diagnosis` vivant
issu de l'historique. Un diagnostic supprimé donne une bulle texte seule, pas une
carte vide.

### Décisions de conception

- **Le titre est déduit, pas saisi.** Il vient du premier message de
  l'utilisateur, et il est **figé** dès qu'il existe : sinon l'entrée du tiroir
  se déplacerait sous le doigt de l'utilisateur. `Conversation.start()` crée
  donc une conversation au titre vide, et `displayTitle` est le filet de sécurité
  de l'affichage.
- **Troncature à 100 tours.** Au-delà, seuls les plus récents sont conservés.
- **Écrire est un confort, pas une fonction métier.** Comme `SupabaseMirror`,
  `ConversationHistory.save()` ne lève jamais : la liste est mise à jour de façon
  optimiste et l'échec Firestore est journalisé. Un agriculteur hors ligne doit
  pouvoir discuter.
- **L'ordre est celui de `updatedAt`, pas celui des appels.** C'est la date du
  dernier échange qui décide, pour que le tiroir reste juste même si le flux
  Firestore arrive dans le désordre.
- **100 % Firestore, pour l'instant.** Les discussions ne sont pas répliquées
  vers Supabase : le périmètre de la double écriture reste `users` et
  `diagnoses`. Les ajouter demanderait une règle de conflit - un échange se
  poursuit, alors qu'un profil est un état courant - qui n'a pas été décidée.

### Cycle de vie

`HomeAiScreen` restaure la dernière conversation au lancement et la recharge
avec ses cartes de diagnostic. `ConversationHistory.clear()` est appelé à la
déconnexion pour qu'un utilisateur ne voie jamais les discussions du précédent.

## Flux utilisateur principal

1. **GateScreen** : Redirection selon état (onboarding → auth → setup → home)
2. **Onboarding** : Présentation de l'app
3. **Auth** : Connexion/inscription
4. **Setup** : Configuration profil (identité, exploitation, préférences)
5. **Home AI** : Conversation avec l'avatar (photo + texte + voix)
6. **Diagnostic** : Résultat avec traitement + actions (community, marketplace, health)

## Fonctionnalités clés

### 1. Diagnostic IA
- Photo de culture + description optionnelle
- Analyse via modèle vision de RodiumAI
- Réponse structurée : maladie, confiance, traitement, message avatar
- Support multilingue (fr, en, wo)

### 2. Conversation multimodale
- Texte, photo, voix
- **Historique de discussions** persisté, restauré au lancement, listé dans le
  tiroir (voir « Historique des discussions »)
- Synthèse vocale des réponses
- Reconnaissance vocale des entrées

### 3. Écosystème agriculteur
- **Community** : Signalements épidémiques locaux
- **Marketplace** : Vente de cultures saines
- **Vendors** : Points de vente d'intrants
- **Weather** : Alertes météo historiques
- **Health Dashboard** : Score de santé de l'exploitation

### 4. Accessibilité
- Interface vocale (pour non-lecteurs)
- Support wolof (alphabet latin)
- Design simple et intuitif
- Réponses audio pour tous les diagnostics

## Persistance : double écriture Firestore → Supabase

Supabase (Postgres) reçoit une **copie** de deux collections Firestore :
`users` et `diagnoses`. Firestore reste la source de vérité.

### Pourquoi ce n'est pas une synchronisation à double sens

Aucune lecture de l'application ne va vers Supabase. Le flux est à sens
unique : Firestore → Supabase. Cela évite d'avoir à arbitrer qui gagne quand
les deux bases sont modifiées, tout en permettant de basculer la lecture plus
tard sans migration de données.

### Chemin d'une écriture

1. L'écran écrit dans Firestore, comme avant.
2. Après l'écriture **confirmée**, `SupabaseMirror` appelle l'Edge Function
   `sync-write`.
3. `sync-write` vérifie le jeton de l'appelant puis appelle une fonction SQL
   qui applique la règle de conflit.

Le client n'attend pas la réponse (`unawaited`) et **aucune erreur de
réplication ne remonte à l'utilisateur**. Un téléphone hors ligne ou un incident
Supabase ne doit jamais faire échouer l'enregistrement d'un profil ou d'un
diagnostic.

### Règles de conflit

| Collection | Règle | Raison |
|---|---|---|
| `users` | **Last-write-wins** sur `source_updated_at` | Un profil est un état courant, pas un historique. |
| `diagnoses` | **Append-only** (`on conflict do nothing`) | `id` est un timestamp en microsecondes, jamais réécrit. |

Ces règles vivent en SQL (`sync_user_lww`, `sync_diagnosis_append`) et **pas**
dans l'Edge Function : lire, comparer puis écrire en JavaScript laisserait une
fenêtre pendant laquelle deux réplications concurrentes passeraient toutes
les deux le test, et la dernière écraserait la première.

### Pourquoi une Edge Function et non un appel direct

Les politiques RLS de Supabase reposent sur `auth.uid()`, qui ne lit que les
jetons **Supabase**. Or les utilisateurs de KultivIA se connectent avec
**Firebase** : `auth.uid()` serait toujours `null` et toute écriture directe
serait refusée. `sync-write` vérifie donc lui-même le jeton (Firebase ou
Supabase) et utilise la clé `service_role` côté serveur.

Les tables ont RLS activé **sans aucune policy** : le rôle public n'a aucun
accès, et la réplication passe obligatoirement par `sync-write`.

### Activation

`SIMULTANEOUS_WRITES=false` (défaut) désactive toute la réplication :
l'application se comporte alors exactement comme avant. Passer à `true` dans
`.env` l'active.

### Défaut connu : le hors-ligne

Une écriture faite hors ligne **est** enregistrée dans Firestore mais
**n'atteint jamais** Supabase, puisque l'appel réseau échoue. Rien n'est mis en
file d'attente côté client (aucune dépendance de stockage local n'a été
ajoutée).

Ce décalage est invisible tant que l'application lit Firestore. Il devient réel
le jour où la lecture bascule vers Supabase. Deux remèdes :

- `tools/backfill.mjs` relit Firestore et réinjecte dans Supabase ; il est
  idempotent et peut être rejoué.
- La vue `sync_gap` liste ce qui reste à rattraper. Elle doit être vide avant
  toute bascule de la lecture.

Les suppressions ne sont pas répliquées : un diagnostic effacé chez
l'utilisateur ne doit pas réapparaître dans le réplica.

### Périmètre

`vendors`, les signalements communautaires et les discussions accèdent
directement à Firestore par leurs écrans, sans passer par un dépôt. Ils ne sont
pas répliqués.

## Stack technique

- **Framework** : Flutter (Dart)
- **Backend** : Firebase (Auth, Firestore) - source de vérité
- **Réplique** : Supabase / Postgres (tables `users`, `diagnoses`)
- **Fonctions serveur** : Supabase Edge Functions (IA + réplication)
- **IA** : RodiumAI (vision, langage, audio)
- **State** : Provider
- **Navigation** : MaterialApp avec routes nommées
- **Localisation** : Support multilingue (fr, en, wo)

## Sécurité

- Clés API IA jamais exposées côté client
- Proxy via Supabase Edge Functions, qui vérifie le jeton avant tout appel
- Tables `users` et `diagnoses` sous RLS sans aucune policy : le rôle public
  n'a aucun accès, la réplication passe par la clé `service_role` côté serveur
- Firestore : `users/{uid}/conversations` n'est lisible et modifiable que par son
  propriétaire (`request.auth.uid == userId`), comme le reste de `users/{uid}`
- Validation des entrées utilisateur
- Gestion des erreurs avec exceptions personnalisées
