-- Fonctions de réplication appelées par l'Edge Function `sync-write`.
--
-- Pourquoi en SQL plutôt qu'en Deno : le last-write-wins doit être ATOMIQUE.
-- Lire la ligne, comparer en JavaScript, puis écrire laisserait une fenêtre
-- pendant laquelle deux réplications concurrentes passeraient toutes deux le
-- test et la dernière écraserait la première. La comparaison et l'écriture
-- doivent être une seule opération.

-- ---------------------------------------------------------------- users (LWW)

-- Écrit le profil seulement si la source est plus récente que l'existant.
--
-- `where users.source_updated_at <= excluded.source_updated_at` est la garde :
-- si une réplication arrive en retard (téléphone hors ligne puis backfill),
-- elle est ignorée au lieu d'écraser une modification plus récente déjà
-- présente. Retourne true si la ligne a été écrite, false si ignorée.
create or replace function sync_user_lww(
  p_uid                  text,
  p_display_name         text,
  p_photo_url            text,
  p_role                 text,
  p_locality             text,
  p_crops                text[],
  p_language_code        text,
  p_ai_language_code     text,
  p_notifications_enabled boolean,
  p_voice_replies        boolean,
  p_theme_mode           integer,
  p_phone_number         text,
  p_phone_country_code   text,
  p_profile_completed    boolean,
  p_source_updated_at    timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into users as t (
    uid, display_name, photo_url, role, locality, crops,
    language_code, ai_language_code, notifications_enabled,
    voice_replies, theme_mode, phone_number, phone_country_code,
    profile_completed, source_updated_at, synced_at
  )
  values (
    p_uid, p_display_name, p_photo_url, p_role, p_locality, p_crops,
    p_language_code, p_ai_language_code, p_notifications_enabled,
    p_voice_replies, p_theme_mode, p_phone_number, p_phone_country_code,
    p_profile_completed, p_source_updated_at, now()
  )
  on conflict (uid) do update
    set display_name          = excluded.display_name,
        photo_url             = excluded.photo_url,
        role                  = excluded.role,
        locality              = excluded.locality,
        crops                 = excluded.crops,
        language_code         = excluded.language_code,
        ai_language_code      = excluded.ai_language_code,
        notifications_enabled = excluded.notifications_enabled,
        voice_replies         = excluded.voice_replies,
        theme_mode            = excluded.theme_mode,
        phone_number          = excluded.phone_number,
        phone_country_code    = excluded.phone_country_code,
        profile_completed     = excluded.profile_completed,
        source_updated_at     = excluded.source_updated_at,
        synced_at             = now()
    where t.source_updated_at <= excluded.source_updated_at;

  -- `insert` renvoie 0 ligne si la garde a bloqué la mise à jour.
  return found;
end;
$$;

-- -------------------------------------------------------- diagnoses (append)

-- Les diagnostics ne sont jamais réécrits : `id` est un timestamp en
-- microsecondes. `on conflict do nothing` rend donc l'appel idempotent, ce qui
-- est exactement ce qu'il faut pour un backfill rejouable.
create or replace function sync_diagnosis_append(
  p_id                text,
  p_uid               text,
  p_date              timestamptz,
  p_image_path        text,
  p_input_text        text,
  p_disease           text,
  p_confidence        double precision,
  p_advice            text,
  p_source_updated_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into diagnoses as t (
    id, uid, date, image_path, input_text, disease,
    confidence, advice, source_updated_at, synced_at
  )
  values (
    p_id, p_uid, p_date, p_image_path, p_input_text, p_disease,
    p_confidence, p_advice, p_source_updated_at, now()
  )
  on conflict (id) do nothing;

  return found;
end;
$$;

-- ------------------------------------------------------------------ Droits

-- `security definer` fait que ces fonctions s'exécutent avec les droits du
-- propriétaire et ignorent les politiques RLS. C'est volontaire et c'est
-- pourquoi l'Edge Function doit vérifier le jeton de l'appelant avant de les
-- appeler : ces fonctions ne doivent jamais être appelées par le rôle public.
revoke execute on function sync_user_lww from anon, authenticated;
revoke execute on function sync_diagnosis_append from anon, authenticated;

grant execute on function sync_user_lww to service_role;
grant execute on function sync_diagnosis_append to service_role;

-- La vue de contrôle n'est lisible que par la clé de service.
revoke select on sync_gap from anon, authenticated;
grant select on sync_gap to service_role;