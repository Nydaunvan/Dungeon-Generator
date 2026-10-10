-- Dungeon Generator — rôle « super admin » : parties de test et statistiques de toute la partie en ligne (étape 6c).
--
-- Sécurité : la table `admins` n'a AUCUNE politique (illisible et inscriptible depuis le jeu : personne ne peut s'y ajouter). Le rôle
-- ne s'accorde que par SQL depuis le tableau de bord Supabase :  insert into public.admins (player_id) values ('<uuid du joueur>');
-- Toutes les fonctions ci-dessous revérifient le rôle CÔTÉ SERVEUR (`is_super_admin()`) : un jeu modifié n'obtient rien.
-- Les courriels et les journaux d'actions des parties ne sont jamais renvoyés.

-- ───────────────────────────── Rôle ─────────────────────────────

create table public.admins (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  granted_at timestamptz not null default now()
);
alter table public.admins enable row level security;       -- aucune politique : invisible depuis l'API

-- Vrai si le joueur connecté est super admin. Le jeu s'en sert seulement pour AFFICHER le menu ; le serveur refuse de toute façon.
create function public.is_super_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admins where player_id = (select auth.uid()))
$$;
revoke all on function public.is_super_admin() from public, anon;
grant execute on function public.is_super_admin() to authenticated;

-- ───────────────────────────── Parties de test ─────────────────────────────

-- Une partie de test se rejoue comme les autres (le vérificateur calcule le vrai résultat) mais : n'utilise pas l'essai du jour,
-- n'apparaît dans aucun classement, ne donne ni expérience ni badge, ne ferme pas un mois en retard.
alter table public.ranked_runs add column test boolean not null default false;

create function public.admin_start_ranked_run(p_difficulty text, p_game_version text, p_kind text default 'difficulty') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  m public.ranked_modes%rowtype;
  new_seed text := replace(gen_random_uuid()::text, '-', '');
  prm jsonb;
  rid uuid;
  per_name text := to_char(now() at time zone 'Europe/Paris', 'YYYY-MM');
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  if p_game_version is null or char_length(p_game_version) not between 1 and 20 then
    raise exception 'version_invalide';
  end if;
  if p_kind = 'difficulty' then
    select * into m from public.ranked_modes where difficulty = p_difficulty;
    if not found then
      raise exception 'mode_inconnu';
    end if;
    prm := jsonb_build_object('levels', m.levels, 'width', m.width, 'height', m.height, 'difficulty', m.difficulty, 'mods', '[]'::jsonb);
    insert into public.ranked_runs (player_id, difficulty, seed, params, game_version, test)
    values ((select auth.uid()), m.difficulty, new_seed, prm, p_game_version, true)
    returning id into rid;
    return jsonb_build_object('run_id', rid, 'seed', new_seed, 'params', prm, 'test', true);
  elsif p_kind = 'hardcore_month' then
    -- réglages du Hardcore du mois, mais graine tirée au hasard : la vraie graine du mois n'est jamais révélée
    prm := jsonb_build_object('levels', 5, 'width', 15, 'height', 13, 'difficulty', 'hardcore', 'mods', '[]'::jsonb);
    insert into public.ranked_runs (player_id, difficulty, seed, params, game_version, kind, period, test)
    values ((select auth.uid()), 'hardcore', new_seed, prm, p_game_version, 'hardcore_month', per_name, true)
    returning id into rid;
    return jsonb_build_object('run_id', rid, 'seed', new_seed, 'params', prm, 'period', per_name, 'test', true);
  end if;
  raise exception 'mode_inconnu';
end $$;
revoke all on function public.admin_start_ranked_run(text, text, text) from public, anon;
grant execute on function public.admin_start_ranked_run(text, text, text) to authenticated;

-- Les tests sont exclus des récompenses, de la clôture des mois et des classements.
create or replace function public.award_run(p_run_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  r public.ranked_runs%rowtype;
  mult numeric;
  xp int;
begin
  select * into r from public.ranked_runs where id = p_run_id and status = 'verified' and not test;
  if not found then
    return;
  end if;
  mult := case r.difficulty when 'easy' then 1 when 'normal' then 1.5 when 'hard' then 2 else 3 end;
  xp := floor(40 * r.score * mult)::int;
  if xp > 0 then
    perform public._give_xp(r.player_id, 'partie', r.id::text, xp);
  end if;
  if r.kind = 'hardcore_month' then
    perform public._give_xp(r.player_id, 'hardcore_essai', r.id::text, 50);
    perform public._give_badge(r.player_id, 'hc_participant', '');
    if r.score >= 3 then perform public._give_badge(r.player_id, 'hc_profondeur_3', ''); perform public._give_xp(r.player_id, 'hardcore_palier3', '', 150); end if;
    if r.score >= 5 then perform public._give_badge(r.player_id, 'hc_profondeur_5', ''); perform public._give_xp(r.player_id, 'hardcore_palier5', '', 400); end if;
    if r.score >= 8 then perform public._give_badge(r.player_id, 'hc_profondeur_8', ''); perform public._give_xp(r.player_id, 'hardcore_palier8', '', 1000); end if;
  end if;
end $$;

create or replace function public.close_period(p_kind text, p_period text) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
  top_pct int;
  b record;
begin
  if not exists (select 1 from public.ranked_periods where kind = p_kind and period = p_period and closed_at is null) then
    return 0;
  end if;
  select count(distinct player_id) into n
    from public.ranked_runs
    where kind = p_kind and period = p_period and status = 'verified' and score > 0 and not test;
  top_pct := greatest(1, ceil(n * 0.10)::int);
  if p_kind = 'hardcore_month' then
    for b in
      select player_id, row_number() over (order by score desc, seconds asc, verified_at asc) as rk
      from (
        select distinct on (player_id) player_id, score, seconds, verified_at
        from public.ranked_runs
        where kind = p_kind and period = p_period and status = 'verified' and score > 0 and not test
        order by player_id, score desc, seconds asc, verified_at asc
      ) t
    loop
      if b.rk = 1 then perform public._give_badge(b.player_id, 'hc_champion', p_period); end if;
      if b.rk = 2 then perform public._give_badge(b.player_id, 'hc_podium_2', p_period); end if;
      if b.rk = 3 then perform public._give_badge(b.player_id, 'hc_podium_3', p_period); end if;
      if b.rk <= 10 then perform public._give_badge(b.player_id, 'hc_top_10', p_period); end if;
      if b.rk <= top_pct then perform public._give_badge(b.player_id, 'hc_top_10pct', p_period); end if;
      perform public._give_xp(b.player_id, 'hardcore_rang', p_period,
        case when b.rk = 1 then 1500 when b.rk = 2 then 1000 when b.rk = 3 then 700 when b.rk <= 10 then 300 when b.rk <= top_pct then 150 else 50 end);
    end loop;
  end if;
  update public.ranked_periods set closed_at = now() where kind = p_kind and period = p_period;
  return n;
end $$;

create or replace function public.close_due_periods() returns int
language plpgsql security definer set search_path = '' as $$
declare
  p record;
  total int := 0;
begin
  for p in select kind, period from public.ranked_periods
           where closed_at is null and ends_at + interval '2 days' < now()
             and not exists (select 1 from public.ranked_runs r where r.kind = ranked_periods.kind and r.period = ranked_periods.period and r.status = 'submitted' and not r.test)
  loop
    total := total + public.close_period(p.kind, p.period);
  end loop;
  return total;
end $$;

create or replace view public.classement_periode as
select distinct on (r.kind, r.period, r.player_id)
  r.kind, r.period, r.player_id, p.pseudo, r.score, r.seconds, r.metrics, r.verified_at as achieved_at,
  (select title_fr from public.badges where id = c.title_badge) as title_fr,
  (select title_en from public.badges where id = c.title_badge) as title_en,
  (select frame from public.badges where id = c.frame_badge) as frame,
  (select color from public.badges where id = c.color_badge) as color,
  public.account_level(coalesce((select sum(amount) from public.xp_log x where x.player_id = r.player_id), 0)) as level
from public.ranked_runs r
join public.profiles p on p.id = r.player_id
left join public.player_cosmetics c on c.player_id = r.player_id
where r.status = 'verified' and r.score > 0 and r.kind <> 'difficulty' and not r.test
order by r.kind, r.period, r.player_id, r.score desc, r.seconds asc, r.verified_at asc;

create or replace view public.classement_difficulte as
select distinct on (r.difficulty, r.player_id)
  r.difficulty, r.player_id, p.pseudo, r.score, r.seconds, r.metrics, r.verified_at as achieved_at,
  (select title_fr from public.badges where id = c.title_badge) as title_fr,
  (select title_en from public.badges where id = c.title_badge) as title_en,
  (select frame from public.badges where id = c.frame_badge) as frame,
  (select color from public.badges where id = c.color_badge) as color,
  public.account_level(coalesce((select sum(amount) from public.xp_log x where x.player_id = r.player_id), 0)) as level
from public.ranked_runs r
join public.profiles p on p.id = r.player_id
left join public.player_cosmetics c on c.player_id = r.player_id
where r.status = 'verified' and r.score > 0 and r.kind = 'difficulty' and not r.test
order by r.difficulty, r.player_id, r.score desc, r.seconds asc, r.verified_at asc;

-- ───────────────────────────── Statistiques (lecture seule, super admin) ─────────────────────────────

-- Vue d'ensemble de toute la partie en ligne.
create function public.admin_overview() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  paris_day date := (now() at time zone 'Europe/Paris')::date;
  per text := to_char(now() at time zone 'Europe/Paris', 'YYYY-MM');
  day_start timestamptz := ((now() at time zone 'Europe/Paris')::date)::timestamp at time zone 'Europe/Paris';
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return jsonb_build_object(
    'generated_at', now(),
    'players', jsonb_build_object(
      'total', (select count(*) from public.profiles),
      'new_24h', (select count(*) from public.profiles where created_at > now() - interval '24 hours'),
      'new_7d', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
      'active_24h', (select count(distinct player_id) from public.ranked_runs where not test and started_at > now() - interval '24 hours'),
      'active_7d', (select count(distinct player_id) from public.ranked_runs where not test and started_at > now() - interval '7 days'),
      'admins', (select count(*) from public.admins)),
    'runs', jsonb_build_object(
      'total', (select count(*) from public.ranked_runs where not test),
      'tests', (select count(*) from public.ranked_runs where test),
      'today', (select count(*) from public.ranked_runs where not test and started_at >= day_start),
      'by_status', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb)
                      from (select status, count(*) as n from public.ranked_runs where not test group by status) s),
      'by_mode', (select coalesce(jsonb_agg(jsonb_build_object('mode', mode, 'runs', runs, 'verified', verified,
                                   'avg_score', avg_score, 'best_score', best, 'avg_seconds', avg_s) order by mode), '[]'::jsonb)
                    from (select case when kind = 'difficulty' then difficulty else kind end as mode,
                                 count(*) as runs, count(*) filter (where status = 'verified') as verified,
                                 round(avg(score) filter (where status = 'verified'), 2) as avg_score,
                                 max(score) filter (where status = 'verified') as best,
                                 round(avg(seconds) filter (where status = 'verified'))::int as avg_s
                            from public.ranked_runs where not test group by 1) m),
      'by_version', (select coalesce(jsonb_agg(jsonb_build_object('version', game_version, 'runs', n) order by n desc), '[]'::jsonb)
                       from (select game_version, count(*) as n from public.ranked_runs where not test group by game_version) v),
      'reject_reasons', (select coalesce(jsonb_agg(jsonb_build_object('reason', reason, 'n', n) order by n desc), '[]'::jsonb)
                           from (select coalesce(reject_reason, '?') as reason, count(*) as n from public.ranked_runs
                                  where status = 'rejected' and not test group by 1 order by n desc limit 10) rr)),
    'queue', jsonb_build_object(
      'submitted', (select count(*) from public.ranked_runs where status = 'submitted'),
      'oldest_seconds', (select extract(epoch from now() - min(submitted_at))::int from public.ranked_runs where status = 'submitted'),
      'in_progress', (select count(*) from public.ranked_runs where status = 'started' and started_at > now() - interval '2 hours')),
    'hardcore', jsonb_build_object(
      'period', per,
      'attempts_today', (select count(*) from public.ranked_runs where kind = 'hardcore_month' and day = paris_day and not test),
      'attempts_month', (select count(*) from public.ranked_runs where kind = 'hardcore_month' and period = per and not test),
      'players_month', (select count(distinct player_id) from public.ranked_runs where kind = 'hardcore_month' and period = per and not test),
      'verified_month', (select count(*) from public.ranked_runs where kind = 'hardcore_month' and period = per and status = 'verified' and not test),
      'best_month', (select max(score) from public.ranked_runs where kind = 'hardcore_month' and period = per and status = 'verified' and not test),
      'closed_at', (select closed_at from public.ranked_periods where kind = 'hardcore_month' and period = per)),
    'rewards', jsonb_build_object(
      'xp_total', (select coalesce(sum(amount), 0) from public.xp_log),
      'xp_entries', (select count(*) from public.xp_log),
      'badges_awarded', (select count(*) from public.player_badges),
      'badges', (select coalesce(jsonb_agg(jsonb_build_object('badge', badge_id, 'n', n) order by n desc), '[]'::jsonb)
                   from (select badge_id, count(*) as n from public.player_badges group by badge_id) b),
      'cosmetics_equipped', (select count(*) from public.player_cosmetics)),
    'other', jsonb_build_object(
      'dungeons', (select count(*) from public.dungeons),
      'dungeons_public', (select count(*) from public.dungeons where is_public),
      'dungeon_reports', (select count(*) from public.dungeon_reports),
      'challenges', (select count(*) from public.challenges),
      'declared_scores', (select count(*) from public.scores),
      'replay_runs', (select count(*) from public.runs))
  );
end $$;

-- Liste des joueurs (sans courriel). Recherche facultative dans le pseudo.
create function public.admin_players(p_search text default '', p_limit int default 50, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t)) from (
      select p.id, p.pseudo, p.created_at,
             coalesce(x.xp, 0)::int as xp,
             public.account_level(coalesce(x.xp, 0)) as level,
             (select count(*) from public.ranked_runs r where r.player_id = p.id and not r.test) as runs,
             (select count(*) from public.ranked_runs r where r.player_id = p.id and not r.test and r.status = 'verified') as verified,
             (select max(r.score) from public.ranked_runs r where r.player_id = p.id and not r.test and r.status = 'verified') as best_score,
             (select max(r.started_at) from public.ranked_runs r where r.player_id = p.id and not r.test) as last_run_at,
             (select count(*) from public.player_badges b where b.player_id = p.id) as badges,
             exists (select 1 from public.admins a where a.player_id = p.id) as admin
        from public.profiles p
        left join (select player_id, sum(amount) as xp from public.xp_log group by player_id) x on x.player_id = p.id
       where coalesce(p_search, '') = '' or position(lower(p_search) in lower(p.pseudo)) > 0
       order by p.created_at desc
       limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)
    ) t), '[]'::jsonb);
end $$;

-- Dernières parties (sans le journal d'actions). Filtres facultatifs : statut, tests seulement / sans les tests.
create function public.admin_runs(p_status text default null, p_tests text default 'all', p_limit int default 50, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t)) from (
      select r.id, p.pseudo, r.difficulty, r.kind, r.period, r.day, r.status, r.score, r.seconds, r.game_version,
             r.reject_reason, r.started_at, r.submitted_at, r.verified_at, r.test,
             case when r.log is null then null else jsonb_array_length(r.log) end as actions
        from public.ranked_runs r join public.profiles p on p.id = r.player_id
       where (p_status is null or p_status = '' or r.status = p_status)
         and (p_tests = 'all' or (p_tests = 'only' and r.test) or (p_tests = 'none' and not r.test))
       order by r.started_at desc
       limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)
    ) t), '[]'::jsonb);
end $$;

-- Supprime les parties de test (les seules qu'un super admin puisse effacer). Renvoie leur nombre.
create function public.admin_purge_tests() returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  with d as (delete from public.ranked_runs where test returning 1)
  select count(*) into n from d;
  return n;
end $$;

revoke all on function public.admin_overview(), public.admin_players(text, int, int), public.admin_runs(text, text, int, int),
  public.admin_purge_tests() from public, anon;
grant execute on function public.admin_overview(), public.admin_players(text, int, int), public.admin_runs(text, text, int, int),
  public.admin_purge_tests() to authenticated;
