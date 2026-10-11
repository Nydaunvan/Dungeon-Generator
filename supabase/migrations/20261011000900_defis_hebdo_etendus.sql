-- Défi de la semaine : quatre nouvelles règles (Plus riche, Chasseur de boss, Sans piège, Marathon) et score spécial par règle.
--  * weekly_rules.metric : ce que mesure le classement — 'levels' (niveaux franchis), 'gold' (or gagné), 'bosses' (boss vaincus),
--    'clean' (niveaux franchis, mais un seul piège déclenché ramène le score à 0) ;
--  * weekly_rules.params : réglages du donjon propres à la règle (niveaux, taille, difficulté), sinon 4 niveaux 13×11 « normal » ;
--  * la rotation passe de 8 à 12 règles (les 8 premières semaines ne changent pas) ;
--  * une règle à score spécial n'est jouable qu'avec le jeu 1.33.5 ou plus récent (le rejeu des versions précédentes compterait des niveaux) ;
--  * l'expérience et le badge de réussite d'une règle se basent sur les niveaux franchis réels, pas sur le score spécial.

alter table public.weekly_rules drop constraint if exists weekly_rules_slot_check;
alter table public.weekly_rules add constraint weekly_rules_slot_check check (slot between 0 and 63);
alter table public.weekly_rules add column if not exists metric text not null default 'levels' check (metric in ('levels', 'gold', 'bosses', 'clean'));
alter table public.weekly_rules add column if not exists params jsonb not null default '{}'::jsonb;

insert into public.weekly_rules (slot, rule_id, icon, label_fr, label_en, desc_fr, desc_en, mods, metric, params) values
  (8, 'richest', '💰', 'Plus riche', 'Richest',
   'Le classement se fait à l''or gagné : butin des monstres et trésors trouvés (les ventes ne comptent pas). Terminer le donjon reste nécessaire pour le badge.',
   'Ranking is by gold earned: monster loot and treasure found (sales do not count). Clearing the dungeon is still required for the badge.',
   '[]', 'gold', '{}'),
  (9, 'bossrush', '👑', 'Chasseur de boss', 'Boss Hunter',
   'Six niveaux, un boss au bout de chacun. Le classement se fait au nombre de boss vaincus, puis au temps.',
   'Six levels, a boss at the end of each. Ranking is by bosses defeated, then by time.',
   '[]', 'bosses', '{"levels": 6}'),
  (10, 'clean', '🕸️', 'Sans piège', 'Trapfree',
   'Déclencher un seul piège ruine la partie (score nul). Sinon, le classement se fait aux niveaux franchis.',
   'Triggering a single trap ruins the run (zero score). Otherwise ranking is by levels cleared.',
   '[]', 'clean', '{}'),
  (11, 'marathon', '🏃', 'Marathon', 'Marathon',
   'Dix niveaux dans de grands donjons, en une seule partie de 2 heures maximum. Le classement se fait aux niveaux franchis, puis au temps.',
   'Ten levels in large dungeons, in a single run of 2 hours at most. Ranking is by levels cleared, then by time.',
   '[]', 'levels', '{"levels": 10, "width": 15, "height": 13}')
on conflict (slot) do nothing;

insert into public.badges (id, icon, rarity, label_fr, label_en, desc_fr, desc_en, title_fr, title_en, frame, color, sort_order) values
  ('wk_r_richest',  '💰', 3, 'Les poches pleines', 'Pockets Full', 'Réussir le Défi de la semaine « Plus riche ».', 'Clear the “Richest” weekly challenge.', 'Chasseur de trésors', 'Treasure Hunter', null, '#ffd24a', 116),
  ('wk_r_bossrush', '👑', 4, 'Tueur de géants', 'Giant Slayer', 'Réussir le Défi de la semaine « Chasseur de boss ».', 'Clear the “Boss Hunter” weekly challenge.', 'Tueur de boss', 'Boss Slayer', 'braise', null, 117),
  ('wk_r_clean',    '🕸️', 3, 'Pas à pas', 'Step by Step', 'Réussir le Défi de la semaine « Sans piège ».', 'Clear the “Trapfree” weekly challenge.', 'Pied léger', 'Light Foot', null, '#9cc79a', 118),
  ('wk_r_marathon', '🏃', 4, 'Coureur de marathon', 'Marathon Runner', 'Réussir le Défi de la semaine « Marathon ».', 'Clear the “Marathon” weekly challenge.', 'Marathonien', 'Marathoner', 'argent', null, 119)
on conflict (id) do nothing;

-- Version du jeu (« 1.33.5 », « 1.33.5-test1 ») au moins égale à a.b.c ; faux si le texte est illisible.
create or replace function public._version_at_least(v text, a int, b int, c int) returns boolean
language plpgsql immutable set search_path = '' as $$
declare
  p text[];
begin
  p := regexp_match(coalesce(v, ''), '^(\d+)\.(\d+)\.(\d+)');
  if p is null then
    return false;
  end if;
  return (p[1]::int, p[2]::int, p[3]::int) >= (a, b, c);
end $$;
revoke all on function public._version_at_least(text, int, int, int) from public, anon, authenticated;

-- Règle et période de la semaine en cours (lecture publique). La rotation couvre toutes les règles de la table.
create or replace function public.weekly_current() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  paris timestamp := now() at time zone 'Europe/Paris';
  wk_start date := date_trunc('week', paris)::date;
  n int := greatest((select count(*) from public.weekly_rules), 1);
  idx int := ((((wk_start - date '2026-10-05') / 7) % n) + n) % n;
  r public.weekly_rules%rowtype;
  nx public.weekly_rules%rowtype;
begin
  select * into r from (select * from public.weekly_rules order by slot offset idx limit 1) x;
  select * into nx from (select * from public.weekly_rules order by slot offset ((idx + 1) % n) limit 1) y;
  return jsonb_build_object(
    'period', to_char(wk_start, 'IYYY-"W"IW'),
    'starts_at', (wk_start::timestamp at time zone 'Europe/Paris'),
    'ends_at', ((wk_start + 7)::timestamp at time zone 'Europe/Paris'),
    'rule', jsonb_build_object('rule_id', r.rule_id, 'icon', r.icon, 'label_fr', r.label_fr, 'label_en', r.label_en,
                               'desc_fr', r.desc_fr, 'desc_en', r.desc_en, 'mods', r.mods, 'metric', r.metric),
    'next', jsonb_build_object('rule_id', nx.rule_id, 'icon', nx.icon, 'label_fr', nx.label_fr, 'label_en', nx.label_en),
    'levels', coalesce((r.params->>'levels')::int, 4), 'width', coalesce((r.params->>'width')::int, 13),
    'height', coalesce((r.params->>'height')::int, 11), 'difficulty', coalesce(r.params->>'difficulty', 'normal'));
end $$;
revoke all on function public.weekly_current() from public;
grant execute on function public.weekly_current() to anon, authenticated;

create or replace function public._weekly_params() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('levels', (w->>'levels')::int, 'width', (w->>'width')::int, 'height', (w->>'height')::int,
                            'difficulty', w->>'difficulty', 'mods', w->'rule'->'mods', 'rule', w->'rule'->>'rule_id',
                            'metric', w->'rule'->>'metric')
  from (select public.weekly_current() as w) t
$$;
revoke all on function public._weekly_params() from public, anon, authenticated;

-- Démarrage d'une partie classée : identique à la version précédente, plus la barrière de version des règles à score spécial.
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
  end if;
  raise exception 'mode_inconnu';
end $$;

-- Récompenses d'une partie vérifiée : l'expérience et le badge d'une règle se basent sur les niveaux franchis réels.
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
  if xp > 0 then
    perform public._give_xp(r.player_id, 'partie', r.id::text, xp);
  end if;
  if r.kind = 'hardcore_month' then
    perform public._give_xp(r.player_id, 'hardcore_essai', r.id::text, 50);
    perform public._give_badge(r.player_id, 'hc_participant', '');
    if r.score >= 3 then perform public._give_badge(r.player_id, 'hc_profondeur_3', ''); perform public._give_xp(r.player_id, 'hardcore_palier3', '', 150); end if;
    if r.score >= 5 then perform public._give_badge(r.player_id, 'hc_profondeur_5', ''); perform public._give_xp(r.player_id, 'hardcore_palier5', '', 400); end if;
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
