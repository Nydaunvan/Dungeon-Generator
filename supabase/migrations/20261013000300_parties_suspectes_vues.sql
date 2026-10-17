-- Dungeon Generator — parties suspectes « vues » : un super admin peut marquer une partie (ou toute la liste) comme vue.
-- Une partie vue disparaît de l'onglet Suspectes ET du rappel d'ouverture du jeu (le compteur `admin_queue_counts` s'appuie sur la liste).
-- La partie n'est pas supprimée : elle reste dans les classements, l'historique du joueur et le journal ; « Réafficher » annule tout.
-- Une NOUVELLE partie suspecte (même du même joueur) apparaît normalement.

create table public.suspect_seen (
  run_id uuid primary key references public.ranked_runs (id) on delete cascade,
  seen_by uuid references public.profiles (id) on delete set null,
  seen_at timestamptz not null default now()
);
alter table public.suspect_seen enable row level security;      -- aucune politique : invisible depuis l'API

-- Même liste qu'avant, sans les parties déjà vues. Le calcul de « récidive » compte toujours toutes les parties rejetées.
create or replace function public.admin_suspect_runs(p_days int default 14, p_limit int default 60) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    with base as (
      select r.id, r.player_id, r.difficulty, r.status, r.score, r.seconds, r.reject_reason, r.log is not null as has_log,
             coalesce(r.submitted_at, r.started_at) as at
        from public.ranked_runs r
       where not r.test and r.status in ('verified', 'rejected')
         and coalesce(r.submitted_at, r.started_at) > now() - make_interval(days => least(greatest(p_days, 1), 90))
    ),
    med as (
      select difficulty, score, percentile_cont(0.5) within group (order by seconds) as m
        from public.ranked_runs where status = 'verified' and not test and seconds is not null
       group by difficulty, score having count(*) >= 5
    ),
    rej as (select player_id, count(*) as n from base where status = 'rejected' group by player_id),
    flagged as (
      select b.*, p.pseudo,
             case when md.m is not null and md.m > 0 and b.seconds is not null then round((b.seconds / md.m)::numeric, 2) end as ratio,
             array_remove(array[
               case when b.status = 'rejected' then 'rejected' end,
               case when b.status = 'verified' and md.m is not null and md.m > 0 and b.seconds < 0.3 * md.m then 'fast' end,
               case when coalesce(rj.n, 0) >= 3 then 'repeat' end], null) as flags
        from base b
        join public.profiles p on p.id = b.player_id
        left join med md on md.difficulty = b.difficulty and md.score = b.score
        left join rej rj on rj.player_id = b.player_id
       where not exists (select 1 from public.suspect_seen s where s.run_id = b.id)
    )
    select jsonb_agg(jsonb_build_object('run_id', f.id, 'player_id', f.player_id, 'pseudo', f.pseudo, 'difficulty', f.difficulty,
             'status', f.status, 'score', f.score, 'seconds', f.seconds, 'reject_reason', f.reject_reason, 'flags', to_jsonb(f.flags),
             'ratio', f.ratio, 'at', f.at, 'has_log', f.has_log) order by f.at desc)
      from (select * from flagged where cardinality(flags) > 0 order by at desc limit least(greatest(p_limit, 1), 200)) f
  ), '[]'::jsonb);
end $$;

-- Marque UNE partie comme vue.
create function public.admin_suspect_seen(p_run uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  pid uuid;
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  select player_id into pid from public.ranked_runs where id = p_run;
  if not found then
    raise exception 'partie_introuvable';
  end if;
  insert into public.suspect_seen (run_id, seen_by) values (p_run, (select auth.uid())) on conflict do nothing;
  perform public._staff_log_add('suspect_seen', pid, jsonb_build_object('run', p_run));
end $$;

-- Marque comme vues TOUTES les parties actuellement listées (période en jours) ; renvoie leur nombre.
create function public.admin_suspect_clear(p_days int default 14) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  with ins as (
    insert into public.suspect_seen (run_id, seen_by)
    select (e ->> 'run_id')::uuid, (select auth.uid())
      from jsonb_array_elements(public.admin_suspect_runs(p_days, 200)) e
    on conflict do nothing
    returning 1)
  select count(*) into n from ins;
  perform public._staff_log_add('suspect_clear', null, jsonb_build_object('count', n, 'days', p_days));
  return n;
end $$;

-- Réaffiche toutes les parties marquées comme vues ; renvoie leur nombre.
create function public.admin_suspect_restore() returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  with del as (delete from public.suspect_seen where true returning 1)   -- "where true" : pg_safeupdate refuse un DELETE sans WHERE
  select count(*) into n from del;
  perform public._staff_log_add('suspect_restore', null, jsonb_build_object('count', n));
  return n;
end $$;

-- Nombre de parties marquées comme vues (pour le bouton « Réafficher »).
create function public.admin_suspect_seen_count() returns int
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return (select count(*) from public.suspect_seen);
end $$;

do $$
declare f text;
begin
  foreach f in array array['admin_suspect_runs(int,int)', 'admin_suspect_seen(uuid)', 'admin_suspect_clear(int)', 'admin_suspect_restore()', 'admin_suspect_seen_count()']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
