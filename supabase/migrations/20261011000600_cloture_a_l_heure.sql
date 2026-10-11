-- Parties classées en une seule fois (2 h maximum, sans sauvegarde ni reprise) et clôture des périodes dès que tout est vérifié.
--  * une partie « started » depuis plus de 2 h 10 (2 h de jeu + 10 min pour l'envoi) est abandonnée (« expired ») ;
--  * un journal arrivé après ce délai est refusé ;
--  * une période (semaine, mois) est clôturée dès son échéance passée, quand plus aucune partie de la période n'est en cours (récente)
--    ni en attente de vérification : plus de marge fixe de 2 jours ;
--  * la relance de sécurité (toutes les minutes) lance le vérificateur seulement quand il y a vraiment quelque chose à faire.

create or replace function public.expire_stale_ranked_runs() returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  with u as (update public.ranked_runs set status = 'expired'
              where status = 'started' and started_at < now() - interval '2 hours 10 minutes' returning 1)
  select count(*) into n from u;
  return n;
end $$;
revoke all on function public.expire_stale_ranked_runs() from public, anon, authenticated;

create or replace function public.submit_ranked_run(p_run_id uuid, p_log jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if p_log is null or jsonb_typeof(p_log) <> 'array' or jsonb_array_length(p_log) = 0 then
    raise exception 'journal_invalide';
  end if;
  if octet_length(p_log::text) > 500000 then
    raise exception 'journal_trop_gros';
  end if;
  update public.ranked_runs
     set log = p_log, status = 'submitted', submitted_at = now()
   where id = p_run_id and player_id = uid and status = 'started'
     and started_at > now() - interval '2 hours 10 minutes';
  if not found then
    raise exception 'partie_introuvable';
  end if;
end $$;
revoke all on function public.submit_ranked_run(uuid, jsonb) from public, anon;
grant execute on function public.submit_ranked_run(uuid, jsonb) to authenticated;

-- Périodes échues dont plus aucune partie n'est en cours ni à vérifier.
create or replace function public.periods_ready_to_close() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.ranked_periods p
     where p.closed_at is null and p.ends_at < now()
       and not exists (select 1 from public.ranked_runs r
                        where r.kind = p.kind and r.period = p.period and not r.test
                          and (r.status = 'submitted'
                               or (r.status = 'started' and r.started_at > now() - interval '2 hours 10 minutes'))));
$$;
revoke all on function public.periods_ready_to_close() from public, anon, authenticated;

create or replace function public.close_due_periods() returns int
language plpgsql security definer set search_path = '' as $$
declare
  p record;
  total int := 0;
begin
  perform public.expire_stale_ranked_runs();
  for p in select kind, period from public.ranked_periods
           where closed_at is null and ends_at < now()
             and not exists (select 1 from public.ranked_runs r
                              where r.kind = ranked_periods.kind and r.period = ranked_periods.period and not r.test
                                and (r.status = 'submitted'
                                     or (r.status = 'started' and r.started_at > now() - interval '2 hours 10 minutes')))
  loop
    total := total + public.close_period(p.kind, p.period);
  end loop;
  return total;
end $$;

select cron.unschedule('verifier-relance') where exists (select 1 from cron.job where jobname = 'verifier-relance');
select cron.schedule('verifier-relance', '* * * * *',
  $$select public.expire_stale_ranked_runs();
    select public.kick_verifier() where exists (select 1 from public.ranked_runs where status = 'submitted' and submitted_at < now() - interval '90 seconds')
       or public.periods_ready_to_close()$$);
