-- Dungeon Generator — Défi de la semaine (2/2) : une règle spéciale par semaine, un donjon unique pour tous (graine tirée par le serveur à la
-- première partie de la semaine), essais illimités, classement de la semaine sur les parties VÉRIFIÉES, badges par règle réussie et de rang.
-- La règle est tournante : 8 règles, une par semaine (lundi 00 h, heure de Paris). Les règles sont appliquées par le jeu ET par le vérificateur
-- (modificateurs d'expédition « mods » du rejeu).

create table public.weekly_rules (
  slot int primary key check (slot between 0 and 7),
  rule_id text not null unique check (rule_id ~ '^[a-z0-9]{3,20}$'),
  icon text not null,
  label_fr text not null, label_en text not null,
  desc_fr text not null, desc_en text not null,
  mods jsonb not null
);
alter table public.weekly_rules enable row level security;
create policy "règles de la semaine lisibles par tous" on public.weekly_rules for select using (true);

insert into public.weekly_rules (slot, rule_id, icon, label_fr, label_en, desc_fr, desc_en, mods) values
  (0, 'norest', '🏕️', 'Sans repos', 'No Rest', 'Aucune fontaine dans le donjon : chaque point de vie compte.', 'No fountains in the dungeon: every hit point counts.', '["mod_norest"]'),
  (1, 'glass', '🥂', 'Verre brisé', 'Glass Cannon', 'PV max du groupe divisés par deux : un faux pas peut être fatal.', 'Party max HP halved: one misstep can be fatal.', '["mod_glass"]'),
  (2, 'solo', '🧍', 'Héros solitaire', 'Lone Hero', 'Un seul héros part à l''aventure, avec deux fois plus de PV.', 'A single hero ventures forth, with twice the HP.', '["mod_solo"]'),
  (3, 'nospells', '🗡️', 'Armes seules', 'Steel Only', 'Aucun sort ni capacité : seules les armes comptent.', 'No spells or abilities: only weapons count.', '["mod_nospells"]'),
  (4, 'den', '👹', 'Nid de monstres', 'Monster Den', '40 % de monstres en plus et davantage de groupes ; le butin du boss est toujours légendaire.', '40% more monsters and more groups; boss loot is always legendary.', '["mod_horde2"]'),
  (5, 'frenzy', '🌪️', 'Vitesse folle', 'Frenzy', 'Les monstres attaquent deux fois plus vite.', 'Monsters attack twice as fast.', '["mod_frenzy"]'),
  (6, 'fog', '🌫️', 'Brouillard épais', 'Thick Fog', 'Mini-carte très réduite : on avance à tâtons.', 'Very reduced minimap: you feel your way forward.', '["mod_fog"]'),
  (7, 'lowsta', '💀', 'Endurance limitée', 'Limited Stamina', 'Endurance maximale du groupe réduite de 30 %.', 'Party max stamina reduced by 30%.', '["mod_lowsta"]');

-- Badges : un par règle réussie (toutes les épreuves de la semaine franchies) et des badges de rang à la clôture de la semaine.
insert into public.badges (id, icon, rarity, label_fr, label_en, desc_fr, desc_en, title_fr, title_en, frame, color, sort_order) values
  ('wk_r_norest', '🏕️', 2, 'Sans feu ni lieu', 'No Hearth, No Home', 'Réussir le Défi de la semaine « Sans repos ».', 'Clear the “No Rest” weekly challenge.', 'Ascète', 'Ascetic', null, '#e0a96d', 110),
  ('wk_r_glass', '🥂', 2, 'Sans une égratignure', 'Not a Scratch', 'Réussir le Défi de la semaine « Verre brisé ».', 'Clear the “Glass Cannon” weekly challenge.', 'Funambule', 'Tightrope Walker', null, '#bfe3ff', 111),
  ('wk_r_solo', '🧍', 2, 'Seul contre tous', 'One Against All', 'Réussir le Défi de la semaine « Héros solitaire ».', 'Clear the “Lone Hero” weekly challenge.', 'Loup solitaire', 'Lone Wolf', null, '#c8b6ff', 112),
  ('wk_r_nospells', '🗡️', 3, 'Lame nue', 'Bare Blade', 'Réussir le Défi de la semaine « Armes seules ».', 'Clear the “Steel Only” weekly challenge.', 'Lame nue', 'Bare Blade', 'argent', '#d8dde6', 113),
  ('wk_r_den', '👹', 3, 'Dans la fosse aux monstres', 'In the Monster Pit', 'Réussir le Défi de la semaine « Nid de monstres ».', 'Clear the “Monster Den” weekly challenge.', 'Exterminateur', 'Exterminator', null, '#ff8a6a', 114),
  ('wk_r_frenzy', '🌪️', 3, 'Dans la tempête', 'Into the Storm', 'Réussir le Défi de la semaine « Vitesse folle ».', 'Clear the “Frenzy” weekly challenge.', 'Cœur de tempête', 'Storm Heart', null, '#8fe3ff', 115),
  ('wk_r_fog', '🌫️', 2, 'À tâtons dans la brume', 'Feeling Through the Fog', 'Réussir le Défi de la semaine « Brouillard épais ».', 'Clear the “Thick Fog” weekly challenge.', 'Spectre', 'Phantom', null, '#b7c4cf', 116),
  ('wk_r_lowsta', '💀', 2, 'À bout de souffle', 'Out of Breath', 'Réussir le Défi de la semaine « Endurance limitée ».', 'Clear the “Limited Stamina” weekly challenge.', 'Coureur de fond', 'Long-Distance Runner', null, '#ff9ab8', 117),
  ('wk_top_10', '🏅', 3, 'Brave de la semaine', 'Brave of the Week', 'Terminer une semaine du Défi dans les dix premiers.', 'Finish a weekly challenge in the top ten.', 'Brave de la semaine', 'Brave of the Week', 'braise', '#ff7a45', 120),
  ('wk_podium_3', '🥉', 4, 'Troisième de la semaine', 'Third of the Week', 'Troisième du classement du Défi de la semaine.', 'Third in the weekly challenge ranking.', 'Bronze de la semaine', 'Bronze of the Week', 'bronze', '#cd7f32', 121),
  ('wk_podium_2', '🥈', 4, 'Deuxième de la semaine', 'Runner-up of the Week', 'Deuxième du classement du Défi de la semaine.', 'Second in the weekly challenge ranking.', 'Argent de la semaine', 'Silver of the Week', 'argent', '#d8dde6', 122),
  ('wk_champion', '👑', 5, 'Champion de la semaine', 'Champion of the Week', 'Premier du classement du Défi de la semaine.', 'First in the weekly challenge ranking.', 'Maître de la semaine', 'Master of the Week', 'or', '#ffd24a', 123);

-- Règle en cours (et suivante) : lisible par tous, sans révéler la graine.
create or replace function public.weekly_current() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  paris timestamp := now() at time zone 'Europe/Paris';
  wk_start date := date_trunc('week', paris)::date;
  idx int := ((((wk_start - date '2026-10-05') / 7) % 8) + 8) % 8;
  r public.weekly_rules%rowtype;
  nx public.weekly_rules%rowtype;
begin
  select * into r from public.weekly_rules where slot = idx;
  select * into nx from public.weekly_rules where slot = (idx + 1) % 8;
  return jsonb_build_object(
    'period', to_char(wk_start, 'IYYY-"W"IW'),
    'starts_at', (wk_start::timestamp at time zone 'Europe/Paris'),
    'ends_at', ((wk_start + 7)::timestamp at time zone 'Europe/Paris'),
    'rule', jsonb_build_object('rule_id', r.rule_id, 'icon', r.icon, 'label_fr', r.label_fr, 'label_en', r.label_en,
                               'desc_fr', r.desc_fr, 'desc_en', r.desc_en, 'mods', r.mods),
    'next', jsonb_build_object('rule_id', nx.rule_id, 'icon', nx.icon, 'label_fr', nx.label_fr, 'label_en', nx.label_en),
    'levels', 4, 'width', 13, 'height', 11, 'difficulty', 'normal');
end $$;
revoke all on function public.weekly_current() from public;
grant execute on function public.weekly_current() to anon, authenticated;

-- Réglages d'une partie de la semaine (donjon, règle) à partir de l'état courant.
create or replace function public._weekly_params() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('levels', (w->>'levels')::int, 'width', (w->>'width')::int, 'height', (w->>'height')::int,
                            'difficulty', w->>'difficulty', 'mods', w->'rule'->'mods', 'rule', w->'rule'->>'rule_id')
  from (select public.weekly_current() as w) t
$$;
revoke all on function public._weekly_params() from public, anon, authenticated;

-- ───────────────────────────── Démarrer une partie classée (ajoute le genre « weekly ») ─────────────────────────────

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

create or replace function public.admin_start_ranked_run(p_difficulty text, p_game_version text, p_kind text default 'difficulty') returns jsonb
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
    prm := jsonb_build_object('levels', 5, 'width', 15, 'height', 13, 'difficulty', 'hardcore', 'mods', '[]'::jsonb);
    insert into public.ranked_runs (player_id, difficulty, seed, params, game_version, kind, period, test)
    values ((select auth.uid()), 'hardcore', new_seed, prm, p_game_version, 'hardcore_month', per_name, true)
    returning id into rid;
    return jsonb_build_object('run_id', rid, 'seed', new_seed, 'params', prm, 'period', per_name, 'test', true);
  elsif p_kind = 'weekly' then
    -- règle de la semaine, graine au hasard : la vraie graine de la semaine n'est jamais révélée
    prm := public._weekly_params();
    per_name := public.weekly_current()->>'period';
    insert into public.ranked_runs (player_id, difficulty, seed, params, game_version, kind, period, test)
    values ((select auth.uid()), prm->>'difficulty', new_seed, prm, p_game_version, 'weekly', per_name, true)
    returning id into rid;
    return jsonb_build_object('run_id', rid, 'seed', new_seed, 'params', prm, 'period', per_name, 'test', true);
  end if;
  raise exception 'mode_inconnu';
end $$;

-- ───────────────────────────── Récompenses ─────────────────────────────

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
  elsif r.kind = 'weekly' then
    -- une seule fois par semaine : participation ; une seule fois par règle : réussite (toutes les épreuves franchies)
    if r.score >= 1 then perform public._give_xp(r.player_id, 'weekly_semaine', r.period, 100); end if;
    if r.score >= coalesce((r.params->>'levels')::int, 4) and r.params->>'rule' is not null
       and exists (select 1 from public.badges where id = 'wk_r_' || (r.params->>'rule')) then
      perform public._give_badge(r.player_id, 'wk_r_' || (r.params->>'rule'), '');
      perform public._give_xp(r.player_id, 'weekly_regle', r.params->>'rule', 250);
    end if;
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
  for b in
    select player_id, row_number() over (order by score desc, seconds asc, verified_at asc) as rk
    from (
      select distinct on (player_id) player_id, score, seconds, verified_at
      from public.ranked_runs
      where kind = p_kind and period = p_period and status = 'verified' and score > 0 and not test
      order by player_id, score desc, seconds asc, verified_at asc
    ) t
  loop
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
