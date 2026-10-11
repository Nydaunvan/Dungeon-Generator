-- Vérification rapide des parties classées.
-- Jusqu'ici le vérificateur (workflow GitHub « verify-runs ») ne tournait que sur le cron de GitHub, très irrégulier (plusieurs heures).
-- Désormais, dès qu'une partie passe à « submitted », la base demande à GitHub de lancer le workflow tout de suite (≈ 1 à 3 minutes
-- jusqu'au résultat). Un filet de sécurité relance toutes les 3 minutes tant qu'une partie attend depuis plus de 90 secondes.
--
-- Prérequis (à faire UNE fois, par le propriétaire du dépôt, jamais dans le dépôt ni dans le jeu) : un jeton GitHub « fine-grained »
-- limité au dépôt Nydaunvan/Dungeon-Generator avec la seule permission « Actions : Read and write », enregistré dans Supabase Vault :
--     select vault.create_secret('<le jeton>', 'github_dispatch_token');
-- Sans ce secret, la fonction ne fait rien (le cron GitHub habituel continue de fonctionner).

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

create or replace function public.kick_verifier() returns void
language plpgsql security definer set search_path = public, extensions, vault as $$
declare
  tok text;
begin
  select decrypted_secret into tok from vault.decrypted_secrets where name = 'github_dispatch_token' limit 1;
  if tok is null then
    return;
  end if;
  perform net.http_post(
    url := 'https://api.github.com/repos/Nydaunvan/Dungeon-Generator/actions/workflows/verify-runs.yml/dispatches',
    headers := jsonb_build_object('Authorization', 'Bearer ' || tok, 'Accept', 'application/vnd.github+json',
                                  'X-GitHub-Api-Version', '2022-11-28', 'User-Agent', 'dungeon-verifier', 'Content-Type', 'application/json'),
    body := '{"ref":"main"}'::jsonb);
exception when others then
  null;   -- un échec de notification ne doit jamais bloquer l'envoi d'une partie
end $$;
revoke all on function public.kick_verifier() from public, anon, authenticated;

create or replace function public.trg_kick_verifier() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.kick_verifier();
  return null;
end $$;
revoke all on function public.trg_kick_verifier() from public, anon, authenticated;

drop trigger if exists ranked_runs_kick on public.ranked_runs;
create trigger ranked_runs_kick after update of status on public.ranked_runs
  for each row when (new.status = 'submitted' and old.status is distinct from 'submitted')
  execute function public.trg_kick_verifier();

select cron.unschedule('verifier-relance') where exists (select 1 from cron.job where jobname = 'verifier-relance');
select cron.schedule('verifier-relance', '*/3 * * * *',
  $$select public.kick_verifier() where exists (select 1 from public.ranked_runs where status = 'submitted' and submitted_at < now() - interval '90 seconds')$$);
