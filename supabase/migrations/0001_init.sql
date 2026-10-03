-- Réplica Supabase de `users` et `diagnoses`.
--
-- Firestore reste la source de vérité : ces tables sont une copie, alimentée
-- par l'Edge Function `sync-write`. Rien ne les lit encore côté application.
--
-- Voir plans/double-ecriture-supabase.md pour la justification.

-- ---------------------------------------------------------------- users

create table if not exists users (
  uid                  text primary key,
  display_name         text        not null default '',
  photo_url            text,
  role                 text        not null default 'farmer',
  locality             text        not null default '',
  crops                text[]      not null default '{}',
  language_code        text        not null default 'fr',
  ai_language_code     text        not null default 'fr',
  notifications_enabled boolean    not null default false,
  voice_replies        boolean     not null default false,
  theme_mode           integer     not null default 0,
  phone_number         text        not null default '',
  phone_country_code   text        not null default '+221',
  profile_completed    boolean     not null default false,

  -- Arbitre les conflits last-write-wins : une écriture Firestore ancienne
  -- ne doit jamais écraser une réplication plus récente.
  source_updated_at    timestamptz not null default now(),
  synced_at            timestamptz not null default now(),

  constraint users_role_check
    check (role in ('farmer', 'vendor', 'advisor'))
);

-- ------------------------------------------------------------ diagnoses

create table if not exists diagnoses (
  -- microsecondsSinceEpoch : jamais réécrit, donc pas de conflit possible.
  id                  text primary key,
  uid                 text        not null,
  date                timestamptz not null,
  image_path          text,
  input_text          text        not null default '',
  disease             text        not null default 'Indéterminé',
  confidence          double precision not null default 0,
  advice              text        not null default '',

  source_updated_at   timestamptz not null default now(),
  synced_at           timestamptz not null default now(),

  constraint diagnoses_confidence_check
    check (confidence >= 0 and confidence <= 1)
);

-- L'historique est trié par date décroissante côté Firestore : cet index sert
-- le même tri ici, pour le jour où l'application lira cette table.
create index if not exists diagnoses_uid_date_idx
  on diagnoses (uid, date desc);

-- Permet de lister les lignes non répliquées ou obsolètes (voir sync_gap).
create index if not exists users_synced_at_idx
  on users (synced_at);

create index if not exists diagnoses_synced_at_idx
  on diagnoses (synced_at);

-- ------------------------------------------------------------------ RLS

-- La clé `service_role` contourne ces politiques. Le rôle public n'a aucun
-- accès direct : la réplication passe obligatoirement par `sync-write`, qui
-- vérifie le jeton Firebase de l'appelant.
--
-- Raison : `auth.uid()` ne lit que les jetons Supabase, alors que les
-- utilisateurs de KultivIA se connectent avec Firebase. Une politique basée
-- sur `auth.uid()` renverrait toujours null et refuserait tout.
alter table users      enable row level security;
alter table diagnoses  enable row level security;

-- Aucune policy n'est créée volontairement : sans policy, RLS refuse tout
-- accès au rôle public. Toute régressionfuture de GRANT se voit ici.

-- ------------------------------------------------------------- sync_gap

-- Ce que le backfill doit rattraper : lignes dont la copie Supabase est plus
-- ancienne que ce que Firestore contient, et lignes jamais répliquées.
--
-- À interroger avant de basculer la lecture vers Supabase.
create or replace view sync_gap as
  select
    'diagnosis'::text  as record_type,
    d.uid,
    d.id               as record_id,
    d.source_updated_at,
    d.synced_at
  from diagnoses d
  where d.source_updated_at > d.synced_at

  union all

  select
    'user'::text       as record_type,
    u.uid,
    u.uid              as record_id,
    u.source_updated_at,
    u.synced_at
  from users u
  where u.source_updated_at > u.synced_at;

comment on view sync_gap is
  'Lignes dont la copie Supabase est plus ancienne que la source Firestore. '
  'Doit être vide avant de faire lire l''application à Supabase.';