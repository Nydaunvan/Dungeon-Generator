-- Défi du jour : un petit défi par jour (heure de Paris), sans classement, pour un peu d'expérience et des badges de régularité.
--  * le donjon du jour : 2 niveaux 13×11 « normal », avec la règle du jour (rotation sur les 8 règles de base du Défi de la semaine) ;
--    graine tirée par le serveur à la première partie de la journée, essais illimités ;
--  * expérience : 30 XP dès un niveau franchi, +60 XP en terminant les 2 niveaux, une seule fois par jour ;
--  * badges : 7, 30 puis 100 jours réussis au total (+300 XP au 30e jour, +1000 XP au 100e) ;
--  * pas de classement : aucune entrée dans le hall des légendes.

alter table public.ranked_runs drop constraint ranked_runs_kind_check, add constraint ranked_runs_kind_check check (kind in ('difficulty', 'hardcore_month', 'weekly', 'daily'));
alter table public.ranked_periods drop constraint ranked_periods_kind_check, add constraint ranked_periods_kind_check check (kind in ('hardcore_month', 'weekly', 'daily')),
  drop constraint ranked_periods_period_check, add constraint ranked_periods_period_check check (period ~ '^[0-9]{4}-([0-9]{2}|W[0-9]{2}|[0-9]{2}-[0-9]{2})$');
alter table public.ranked_runs drop constraint ranked_runs_periode_coherente, add constraint ranked_runs_periode_coherente check (
  (kind = 'difficulty' and period is null and day is null)
  or (kind = 'weekly' and period is not null and day is null)
  or (kind = 'daily' and period is not null and day is null)
  or (kind = 'hardcore_month' and period is not null and (day is not null or test)));

insert into public.badges (id, icon, rarity, label_fr, label_en, desc_fr, desc_en, title_fr, title_en, frame, color, sort_order) values
  ('day_7',   '🌄', 1, 'Habitué', 'Regular', 'Réussir 7 Défis du jour.', 'Clear 7 daily challenges.', 'Habitué', 'Regular', 'bronze', null, 140),
  ('day_30',  '🌞', 3, 'Inlassable', 'Tireless', 'Réussir 30 Défis du jour.', 'Clear 30 daily challenges.', 'Inlassable', 'Tireless', 'argent', null, 141),
  ('day_100', '🏺', 5, 'Centenaire', 'Centurion', 'Réussir 100 Défis du jour.', 'Clear 100 daily challenges.', 'Centenaire', 'Centurion', 'or', '#ffd24a', 142)
on conflict (id) do nothing;

-- Défi du jour en cours (lecture publique). Rotation sur les règles de base : 8 règles à score « niveaux » sans réglage propre.
create or replace function public.daily_current() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  d date := (now() at time zone 'Europe/Paris')::date;
  n int := greatest((select count(*) from public.weekly_rules where metric = 'levels' and params = '{}'::jsonb), 1);
  idx int := ((((d - date '2026-10-05')) % n) + n) % n;
  r public.weekly_rules%rowtype;
begin
  select * into r from (select * from public.weekly_rules where metric = 'levels' and params = '{}'::jsonb order by slot offset idx limit 1) x;
  return jsonb_build_object(
    'period', to_char(d, 'YYYY-MM-DD'),
    'starts_at', (d::timestamp at time zone 'Europe/Paris'),
    'ends_at', ((d + 1)::timestamp at time zone 'Europe/Paris'),
    'rule', jsonb_build_object('rule_id', r.rule_id, 'icon', r.icon, 'label_fr', r.label_fr, 'label_en', r.label_en,
                               'desc_fr', r.desc_fr, 'desc_en', r.desc_en, 'mods', r.mods, 'metric', 'levels'),
    'levels', 2, 'width', 13, 'height', 11, 'difficulty', 'normal');
end $$;
revoke all on function public.daily_current() from public;
grant execute on function public.daily_current() to anon, authenticated;

create or replace function public._daily_params() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('levels', (w->>'levels')::int, 'width', (w->>'width')::int, 'height', (w->>'height')::int,
                            'difficulty', w->>'difficulty', 'mods', w->'rule'->'mods', 'rule', w->'rule'->>'rule_id', 'metric', 'levels')
  from (select public.daily_current() as w) t
$$;
revoke all on function public._daily_params() from public, anon, authenticated;

-- Nombre de jours où le joueur a terminé le Défi du jour (parties vérifiées).
create or replace function public.daily_completed(p_player uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(distinct period)::int from public.ranked_runs
   where player_id = p_player and kind = 'daily' and status = 'verified' and not test
     and coalesce((metrics->>'levelsCleared')::int, score) >= coalesce((params->>'levels')::int, 2)
$$;
revoke all on function public.daily_completed(uuid) from public, anon, authenticated;

-- Défi du jour terminé aujourd'hui par le joueur connecté ? {done, tries} (parties lancées aujourd'hui).
create or replace function public.my_daily_status() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  per text := to_char((now() at time zone 'Europe/Paris')::date, 'YYYY-MM-DD');
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  return jsonb_build_object(
    'done', exists (select 1 from public.ranked_runs where player_id = uid and kind = 'daily' and period = per and status = 'verified' and not test
                      and coalesce((metrics->>'levelsCleared')::int, score) >= coalesce((params->>'levels')::int, 2)),
    'tries', (select count(*) from public.ranked_runs where player_id = uid and kind = 'daily' and period = per and not test),
    'total', public.daily_completed(uid));
end $$;
revoke all on function public.my_daily_status() from public, anon;
grant execute on function public.my_daily_status() to authenticated;

-- Démarrage d'une partie classée : identique à la version précédente, plus le genre « daily ».
create or replace function public.start_ranked_run(p_difficulty text, p_game_version text, p_kind text default 'difficulty') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  m public.ranked_modes%rowtype;
  per public.ranked_periods%rowtype;
  new_seed text;
  prm jsonb;
  wk jsonb;
  rid uuid;
  dl jsonb;
  paris timestamp := now() at time zone 'Europe/Paris';
  per_name text := to_char(paris, 'YYYY-MM');
  today date := paris::date;
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if p_game_version is null or char_length(p_game_version) not between 1 and 20 then
    raise exception 'version_invalide';
  end if;
  if (select count(*) from public.ranked_runs where player_id = uid and started_at > now() - interval '24 hours') >= 40 then
    raise exception 'trop_de_parties';
  end if;

  if p_kind = 'difficulty' then
    select * into m from public.ranked_modes where difficulty = p_difficulty;
    if not found then
      raise exception 'mode_inconnu';
    end if;
    update public.ranked_runs set status = 'expired' where player_id = uid and status = 'started' and kind = 'difficulty';
    new_seed := replace(gen_random_uuid()::text, '-', '');
    prm := jsonb_build_object('levels', m.levels, 'width', m.width, 'height', m.height, 'difficulty', m.difficulty, 'mods', '[]'::jsonb);
    insert into public.ranked_runs (player_id, difficulty, seed, params, game_version)
    values (uid, m.difficulty, new_seed, prm, p_game_version)
    returning id into rid;
    return jsonb_build_object('run_id', rid, 'seed', new_seed, 'params', prm);

  elsif p_kind = 'hardcore_month' then
    insert into public.ranked_periods (kind, period, seed, params, starts_at, ends_at)
    values ('hardcore_month', per_name, replace(gen_random_uuid()::text, '-', ''),
            jsonb_build_object('levels', 5, 'width', 15, 'height', 13, 'difficulty', 'hardcore', 'mods', '[]'::jsonb),
            (date_trunc('month', paris) at time zone 'Europe/Paris'),
            ((date_trunc('month', paris) + interval '1 month') at time zone 'Europe/Paris'))
    on conflict (kind, period) do nothing;
    select * into per from public.ranked_periods where kind = 'hardcore_month' and period = per_name;
    if exists (select 1 from public.ranked_runs where player_id = uid and kind = 'hardcore_month' and day = today) then
      raise exception 'essai_du_jour_utilise';
    end if;
    insert into public.ranked_runs (player_id, difficulty, seed, params, game_version, kind, period, day)
    values (uid, 'hardcore', per.seed, per.params, p_game_version, 'hardcore_month', per_name, today)
    returning id into rid;
    return jsonb_build_object('run_id', rid, 'seed', per.seed, 'params', per.params, 'period', per_name, 'day', today);

  elsif p_kind = 'weekly' then
    -- la graine de la semaine est tirée à la première partie ; deux joueurs simultanés obtiennent la même (on conflict)
    wk := public.weekly_current();
    -- une règle à score spécial (or, boss, sans piège) n'est comptée correctement que par le rejeu des versions récentes
    if coalesce(wk->'rule'->>'metric', 'levels') <> 'levels' and not public._version_at_least(p_game_version, 1, 33, 5) then
      raise exception 'version_trop_ancienne';
    end if;
    insert into public.ranked_periods (kind, period, seed, params, starts_at, ends_at)
    values ('weekly', wk->>'period', replace(gen_random_uuid()::text, '-', ''), public._weekly_params(),
            (wk->>'starts_at')::timestamptz, (wk->>'ends_at')::timestamptz)
    on conflict (kind, period) do nothing;
    select * into per from public.ranked_periods where kind = 'weekly' and period = wk->>'period';
    update public.ranked_runs set status = 'expired' where player_id = uid and status = 'started' and kind = 'weekly';
    insert into public.ranked_runs (player_id, difficulty, seed, params, game_version, kind, period)
    values (uid, per.params->>'difficulty', per.seed, per.params, p_game_version, 'weekly', per.period)
    returning id into rid;
    return jsonb_build_object('run_id', rid, 'seed', per.seed, 'params', per.params, 'period', per.period);

  elsif p_kind = 'daily' then
    -- la graine du jour est tirée à la première partie de la journée (heure de Paris) ; essais illimités
    dl := public.daily_current();
    insert into public.ranked_periods (kind, period, seed, params, starts_at, ends_at)
    values ('daily', dl->>'period', replace(gen_random_uuid()::text, '-', ''), public._daily_params(),
            (dl->>'starts_at')::timestamptz, (dl->>'ends_at')::timestamptz)
    on conflict (kind, period) do nothing;
    select * into per from public.ranked_periods where kind = 'daily' and period = dl->>'period';
    update public.ranked_runs set status = 'expired' where player_id = uid and status = 'started' and kind = 'daily';
    insert into public.ranked_runs (player_id, difficulty, seed, params, game_version, kind, period)
    values (uid, per.params->>'difficulty', per.seed, per.params, p_game_version, 'daily', per.period)
    returning id into rid;
    return jsonb_build_object('run_id', rid, 'seed', per.seed, 'params', per.params, 'period', per.period);
  end if;
  raise exception 'mode_inconnu';
end $$;

-- Récompenses d'une partie vérifiée : plus l'expérience et les badges du Défi du jour (pas d'expérience de « partie » pour lui).
create or replace function public.award_run(p_run_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  r public.ranked_runs%rowtype;
  mult numeric;
  xp int;
  st int;
  lv int;
  metric text;
  done boolean;
  n int;
begin
  select * into r from public.ranked_runs where id = p_run_id and status = 'verified' and not test;
  if not found then
    return;
  end if;
  -- niveaux franchis : le score peut être un autre total (or, boss) selon la règle de la semaine
  lv := coalesce((r.metrics->>'levelsCleared')::int, r.score);
  metric := coalesce(r.params->>'metric', 'levels');
  mult := case r.difficulty when 'easy' then 1 when 'normal' then 1.5 when 'hard' then 2 else 3 end;
  xp := floor(40 * lv * mult)::int;
  if xp > 0 and r.kind <> 'daily' then
    perform public._give_xp(r.player_id, 'partie', r.id::text, xp);
  end if;
  if r.kind = 'hardcore_month' then
    perform public._give_xp(r.player_id, 'hardcore_essai', r.id::text, 50);
    perform public._give_badge(r.player_id, 'hc_participant', '');
    if r.score >= 3 then perform public._give_badge(r.player_id, 'hc_profondeur_3', ''); perform public._give_xp(r.player_id, 'hardcore_palier3', '', 150); end if;
    if r.score >= 5 then perform public._give_badge(r.player_id, 'hc_profondeur_5', ''); perform public._give_xp(r.player_id, 'hardcore_palier5', '', 400); end if;
  elsif r.kind = 'daily' then
    -- Défi du jour : peu d'expérience, une seule fois par jour ; badges de régularité (jours réussis au total)
    if r.score >= 1 then perform public._give_xp(r.player_id, 'daily_jour', r.period, 30); end if;
    if lv >= coalesce((r.params->>'levels')::int, 2) then
      perform public._give_xp(r.player_id, 'daily_reussi', r.period, 60);
      n := public.daily_completed(r.player_id);
      if n >= 7 then perform public._give_badge(r.player_id, 'day_7', ''); end if;
      if n >= 30 then perform public._give_badge(r.player_id, 'day_30', ''); perform public._give_xp(r.player_id, 'daily_30', '', 300); end if;
      if n >= 100 then perform public._give_badge(r.player_id, 'day_100', ''); perform public._give_xp(r.player_id, 'daily_100', '', 1000); end if;
    end if;
  elsif r.kind = 'weekly' then
    -- une seule fois par semaine : participation ; une seule fois par règle : réussite (toutes les épreuves franchies)
    if r.score >= 1 then perform public._give_xp(r.player_id, 'weekly_semaine', r.period, 100); end if;
    done := lv >= coalesce((r.params->>'levels')::int, 4) and (metric <> 'clean' or r.score > 0);
    if done and r.params->>'rule' is not null
       and exists (select 1 from public.badges where id = 'wk_r_' || (r.params->>'rule')) then
      perform public._give_badge(r.player_id, 'wk_r_' || (r.params->>'rule'), '');
      perform public._give_xp(r.player_id, 'weekly_regle', r.params->>'rule', 250);
    end if;
    if r.score >= 1 then
      st := public.weekly_streak(r.player_id);
      if st >= 3 then perform public._give_badge(r.player_id, 'wk_streak_3', ''); end if;
      if st >= 6 then perform public._give_badge(r.player_id, 'wk_streak_6', ''); end if;
      if st >= 12 then perform public._give_badge(r.player_id, 'wk_streak_12', ''); perform public._give_xp(r.player_id, 'weekly_serie12', '', 500); end if;
    end if;
  end if;
end $$;

-- Clôture d'une période : le Défi du jour est simplement refermé (ni classement ni hall).
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
  if p_kind = 'daily' then      -- pas de classement ni de hall pour le défi du jour : on referme simplement la période
    update public.ranked_periods set closed_at = now() where kind = p_kind and period = p_period;
    return 0;
  end if;
  select count(distinct player_id) into n
    from public.ranked_runs
    where kind = p_kind and period = p_period and status = 'verified' and score > 0 and not test;
  top_pct := greatest(1, ceil(n * 0.10)::int);
  for b in
    select player_id, run_id, score, seconds, metrics, row_number() over (order by score desc, seconds asc, verified_at asc) as rk
    from (
      select distinct on (player_id) player_id, id as run_id, score, seconds, metrics, verified_at
      from public.ranked_runs
      where kind = p_kind and period = p_period and status = 'verified' and score > 0 and not test
      order by player_id, score desc, seconds asc, verified_at asc
    ) t
  loop
    if b.rk = 1 then
      insert into public.hall_of_fame (kind, period, player_id, run_id, score, seconds, metrics, rule_id)
      values (p_kind, p_period, b.player_id, b.run_id, b.score, b.seconds, b.metrics,
        (select params->>'rule' from public.ranked_runs where id = b.run_id))
      on conflict do nothing;
    end if;
    if p_kind = 'hardcore_month' then
      if b.rk = 1 then perform public._give_badge(b.player_id, 'hc_champion', p_period); end if;
      if b.rk = 2 then perform public._give_badge(b.player_id, 'hc_podium_2', p_period); end if;
      if b.rk = 3 then perform public._give_badge(b.player_id, 'hc_podium_3', p_period); end if;
      if b.rk <= 10 then perform public._give_badge(b.player_id, 'hc_top_10', p_period); end if;
      if b.rk <= top_pct then perform public._give_badge(b.player_id, 'hc_top_10pct', p_period); end if;
      perform public._give_xp(b.player_id, 'hardcore_rang', p_period,
        case when b.rk = 1 then 1500 when b.rk = 2 then 1000 when b.rk = 3 then 700 when b.rk <= 10 then 300 when b.rk <= top_pct then 150 else 50 end);
    elsif p_kind = 'weekly' then
      if b.rk = 1 then perform public._give_badge(b.player_id, 'wk_champion', p_period); end if;
      if b.rk = 2 then perform public._give_badge(b.player_id, 'wk_podium_2', p_period); end if;
      if b.rk = 3 then perform public._give_badge(b.player_id, 'wk_podium_3', p_period); end if;
      if b.rk <= 10 then perform public._give_badge(b.player_id, 'wk_top_10', p_period); end if;
      perform public._give_xp(b.player_id, 'weekly_rang', p_period,
        case when b.rk = 1 then 600 when b.rk = 2 then 400 when b.rk = 3 then 250 when b.rk <= 10 then 120 else 30 end);
    end if;
  end loop;
  update public.ranked_periods set closed_at = now() where kind = p_kind and period = p_period;
  return n;
end $$;
