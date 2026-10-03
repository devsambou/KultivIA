-- Le cache de schéma de PostgREST n'a pas été rechargé après la création des
-- fonctions de réplication : `supabase db push` applique le SQL mais ne
-- signale pas le changement à PostgREST.
--
-- Conséquence observée : un appel à /rest/v1/rpc/sync_user_lww renvoyait
-- PGRST202 « function not found in schema cache », donc TOUTE réplication
-- échouait même avec un jeton valide.
--
-- NOTIFY pgrst, 'reload schema' est le mécanisme officiel de rechargement.

notify pgrst, 'reload schema';