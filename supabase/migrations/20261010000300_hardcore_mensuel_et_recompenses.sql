-- Dungeon Generator — défi « Hardcore du mois », expérience du compte et récompenses (étape 6b).
--
-- Hardcore du mois : une graine par mois (tirée par le serveur à la première partie du mois, donc inconnue d'avance), difficulté
-- maximale, UN essai par jour (jour de Paris), consommé dès le lancement. Classement du mois sur les parties VÉRIFIÉES.
-- Récompenses uniquement cosmétiques (titres, badges, cadres, couleur du pseudo) et de l'expérience de compte : aucun avantage en jeu.
-- Tout est attribué par le vérificateur (clé secrète), une seule fois par partie / par période.

-- ───────────────────────────── Périodes (une graine par mois) ─────────────────────────────

create table public.ranked_periods (
  kind text not null check (kind in ('hardcore_month')),
  period text not null check (period ~ '^[0-9]{4}-[0-9]{2}$'),
  seed text not null check (seed ~ '^[0-9a-f]{32}$'),
  params jsonb not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  closed_at timestamptz,
  primary key (kind, period)
);
alter table public.ranked_periods enable row level security;     -- aucune politique : la graine ne sort que par start_ranked_run

alter table public.ranked_runs
  add column kind text not null default 'difficulty' check (kind in ('difficulty', 'hardcore_month')),
  add column period text,
  add column day date,
  add constraint ranked_runs_periode_coherente check ((kind = 'difficulty') = (period is null and day is null));
-- Un essai par jour pour le Hardcore du mois (les parties abandonnées comptent : l'essai est consommé au lancement).
create unique index ranked_runs_un_essai_par_jour on public.ranked_runs (player_id, kind, day) where kind <> 'difficulty';
create index ranked_runs_periode_idx on public.ranked_runs (kind, period, score desc, seconds) where status = 'verified';

-- ───────────────────────────── Démarrer une partie classée (remplace la version de l'étape 6a) ─────────────────────────────

drop function public.start_ranked_run(text, text);
create function public.start_ranked_run(p_difficulty text, p_game_version text, p_kind text default 'difficulty') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  m public.ranked_modes%rowtype;
  per public.ranked_periods%rowtype;
  new_seed text;
  prm jsonb;
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
    -- la graine du mois est tirée à la première partie du mois ; deux joueurs simultanés obtiennent la même (on conflict)
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
  end if;
  raise exception 'mode_inconnu';
end $$;
revoke all on function public.start_ranked_run(text, text, text) from public, anon;
grant execute on function public.start_ranked_run(text, text, text) to authenticated;

-- ───────────────────────────── Récompenses : catalogue de badges ─────────────────────────────

-- title_* : titre affichable à côté du pseudo ; frame : cadre de portrait ; color : couleur du pseudo dans les classements.
create table public.badges (
  id text primary key check (id ~ '^[a-z0-9_]{3,40}$'),
  icon text not null,
  rarity int not null check (rarity between 1 and 5),
  label_fr text not null, label_en text not null,
  desc_fr text not null, desc_en text not null,
  title_fr text, title_en text,
  frame text check (frame is null or frame in ('bronze', 'argent', 'or', 'braise', 'givre', 'royal')),
  color text check (color is null or color ~ '^#[0-9a-f]{6}$'),
  sort_order int not null default 100
);
alter table public.badges enable row level security;
create policy "badges lisibles par tous" on public.badges for select using (true);

insert into public.badges (id, icon, rarity, label_fr, label_en, desc_fr, desc_en, title_fr, title_en, frame, color, sort_order) values
  ('hc_participant', '🔥', 1, 'Entré dans la fournaise', 'Into the Furnace', 'Avoir joué au Hardcore du mois.', 'Played the monthly Hardcore.', 'Téméraire', 'Daredevil', 'bronze', null, 10),
  ('hc_profondeur_3', '⛏️', 2, 'Trois étages sous terre', 'Three Floors Down', 'Franchir 3 niveaux dans une partie Hardcore du mois.', 'Clear 3 levels in a monthly Hardcore run.', 'Fouisseur', 'Delver', null, '#c9a46a', 20),
  ('hc_profondeur_5', '🕳️', 3, 'Au cœur du gouffre', 'Heart of the Abyss', 'Franchir 5 niveaux dans une partie Hardcore du mois.', 'Clear 5 levels in a monthly Hardcore run.', 'Abyssal', 'Abyssal', 'argent', '#8fd3ff', 30),
  ('hc_profondeur_8', '👁️', 4, 'Plus loin que les cartes', 'Beyond the Maps', 'Franchir 8 niveaux dans une partie Hardcore du mois.', 'Clear 8 levels in a monthly Hardcore run.', 'Sans-fond', 'Bottomless', 'givre', '#7ef0e0', 40),
  ('hc_top_10pct', '🎖️', 3, 'Parmi les meilleurs', 'Among the Best', 'Terminer un mois Hardcore dans les 10 % de tête.', 'Finish a Hardcore month in the top 10%.', 'Vétéran du feu', 'Fire Veteran', null, '#ffb347', 50),
  ('hc_top_10', '🏅', 4, 'Dans les dix premiers', 'Top Ten', 'Terminer un mois Hardcore dans les dix premiers.', 'Finish a Hardcore month in the top ten.', 'Maître de la braise', 'Ember Master', 'braise', '#ff7a45', 60),
  ('hc_podium_3', '🥉', 4, 'Troisième du mois', 'Third of the Month', 'Troisième du classement Hardcore du mois.', 'Third in the monthly Hardcore ranking.', 'Bronze du mois', 'Bronze of the Month', 'bronze', '#cd7f32', 70),
  ('hc_podium_2', '🥈', 5, 'Deuxième du mois', 'Runner-up of the Month', 'Deuxième du classement Hardcore du mois.', 'Second in the monthly Hardcore ranking.', 'Argent du mois', 'Silver of the Month', 'argent', '#d8dde6', 80),
  ('hc_champion', '👑', 5, 'Champion du mois', 'Champion of the Month', 'Premier du classement Hardcore du mois.', 'First in the monthly Hardcore ranking.', 'Champion hardcore', 'Hardcore Champion', 'royal', '#ffd24a', 90);

create table public.player_badges (
  player_id uuid not null references public.profiles (id) on delete cascade,
  badge_id text not null references public.badges (id),
  period text not null default '',             -- mois concerné pour les badges de classement ('' pour les paliers permanents)
  earned_at timestamptz not null default now(),
  primary key (player_id, badge_id, period)
);
alter table public.player_badges enable row level security;
create policy "badges des joueurs lisibles par tous" on public.player_badges for select using (true);

-- ───────────────────────────── Expérience du compte ─────────────────────────────

create table public.xp_log (
  player_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null check (char_length(reason) <= 40),
  ref text not null,                           -- identifiant de la partie ou de la période : une seule attribution par (joueur, raison, réf.)
  amount int not null check (amount > 0),
  created_at timestamptz not null default now(),
  primary key (player_id, reason, ref)
);
alter table public.xp_log enable row level security;
create policy "voir son journal d'expérience" on public.xp_log for select to authenticated using (player_id = (select auth.uid()));

-- Niveau de compte : 100 XP pour le niveau 2, puis de plus en plus (niveau = 1 + racine de xp/100).
create function public.account_level(p_xp bigint) returns int
language sql immutable set search_path = '' as $$ select 1 + floor(sqrt(greatest(p_xp, 0) / 100.0))::int $$;

create view public.account_xp as
select l.player_id, sum(l.amount)::int as xp, public.account_level(sum(l.amount)) as level
from public.xp_log l group by l.player_id;
grant select on public.account_xp to anon, authenticated;

-- ───────────────────────────── Cosmétiques équipés ─────────────────────────────

create table public.player_cosmetics (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  title_badge text references public.badges (id),
  frame_badge text references public.badges (id),
  color_badge text references public.badges (id)
);
alter table public.player_cosmetics enable row level security;
create policy "cosmétiques lisibles par tous" on public.player_cosmetics for select using (true);

-- Équipe un titre, un cadre et une couleur : chacun doit venir d'un badge possédé qui l'offre réellement (null = rien).
create function public.equip_cosmetics(p_title text, p_frame text, p_color text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if p_title is not null and not exists (
       select 1 from public.player_badges pb join public.badges b on b.id = pb.badge_id
       where pb.player_id = uid and pb.badge_id = p_title and b.title_fr is not null) then
    raise exception 'badge_non_possede';
  end if;
  if p_frame is not null and not exists (
       select 1 from public.player_badges pb join public.badges b on b.id = pb.badge_id
       where pb.player_id = uid and pb.badge_id = p_frame and b.frame is not null) then
    raise exception 'badge_non_possede';
  end if;
  if p_color is not null and not exists (
       select 1 from public.player_badges pb join public.badges b on b.id = pb.badge_id
       where pb.player_id = uid and pb.badge_id = p_color and b.color is not null) then
    raise exception 'badge_non_possede';
  end if;
  insert into public.player_cosmetics (player_id, title_badge, frame_badge, color_badge)
  values (uid, p_title, p_frame, p_color)
  on conflict (player_id) do update set title_badge = excluded.title_badge, frame_badge = excluded.frame_badge, color_badge = excluded.color_badge;
end $$;
revoke all on function public.equip_cosmetics(text, text, text) from public, anon;
grant execute on function public.equip_cosmetics(text, text, text) to authenticated;

-- ───────────────────────────── Attribution (vérificateur seulement) ─────────────────────────────

create function public._give_badge(p_player uuid, p_badge text, p_period text) returns void
language sql security definer set search_path = '' as $$
  insert into public.player_badges (player_id, badge_id, period) values (p_player, p_badge, p_period) on conflict do nothing;
$$;
create function public._give_xp(p_player uuid, p_reason text, p_ref text, p_amount int) returns void
language sql security definer set search_path = '' as $$
  insert into public.xp_log (player_id, reason, ref, amount) values (p_player, p_reason, p_ref, p_amount) on conflict do nothing;
$$;

-- Récompenses d'une partie vérifiée : XP selon les niveaux franchis et la difficulté, bonus Hardcore, paliers de profondeur.
create function public.award_run(p_run_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  r public.ranked_runs%rowtype;
  mult numeric;
  xp int;
begin
  select * into r from public.ranked_runs where id = p_run_id and status = 'verified';
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

-- Clôture d'un mois : badges et XP de rang, une seule fois. Renvoie le nombre de joueurs classés.
create function public.close_period(p_kind text, p_period text) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
  top_pct int;
begin
  if not exists (select 1 from public.ranked_periods where kind = p_kind and period = p_period and closed_at is null) then
    return 0;
  end if;
  drop table if exists pg_temp._rk;
  create temp table _rk on commit drop as
    select player_id, row_number() over (order by score desc, seconds asc, verified_at asc) as rk
    from (
      select distinct on (player_id) player_id, score, seconds, verified_at
      from public.ranked_runs
      where kind = p_kind and period = p_period and status = 'verified'
      order by player_id, score desc, seconds asc, verified_at asc
    ) b;
  select count(*) into n from _rk;
  top_pct := greatest(1, ceil(n * 0.10)::int);
  if p_kind = 'hardcore_month' then
    perform public._give_badge(player_id, 'hc_champion', p_period) from _rk where rk = 1;
    perform public._give_badge(player_id, 'hc_podium_2', p_period) from _rk where rk = 2;
    perform public._give_badge(player_id, 'hc_podium_3', p_period) from _rk where rk = 3;
    perform public._give_badge(player_id, 'hc_top_10', p_period) from _rk where rk <= 10;
    perform public._give_badge(player_id, 'hc_top_10pct', p_period) from _rk where rk <= top_pct;
    perform public._give_xp(player_id, 'hardcore_rang', p_period,
      case when rk = 1 then 1500 when rk = 2 then 1000 when rk = 3 then 700 when rk <= 10 then 300 when rk <= top_pct then 150 else 50 end)
      from _rk;
  end if;
  update public.ranked_periods set closed_at = now() where kind = p_kind and period = p_period;
  return n;
end $$;

-- Ferme les mois terminés depuis 2 jours (le temps d'envoyer et de vérifier les dernières parties), sans partie encore en attente.
create function public.close_due_periods() returns int
language plpgsql security definer set search_path = '' as $$
declare
  p record;
  total int := 0;
begin
  for p in select kind, period from public.ranked_periods
           where closed_at is null and ends_at + interval '2 days' < now()
             and not exists (select 1 from public.ranked_runs r where r.kind = ranked_periods.kind and r.period = ranked_periods.period and r.status = 'submitted')
  loop
    total := total + public.close_period(p.kind, p.period);
  end loop;
  return total;
end $$;

revoke all on function public._give_badge(uuid, text, text), public._give_xp(uuid, text, text, int), public.award_run(uuid),
  public.close_period(text, text), public.close_due_periods() from public, anon, authenticated;
grant execute on function public.award_run(uuid), public.close_period(text, text), public.close_due_periods() to service_role;

-- ───────────────────────────── Classements (avec cosmétiques) ─────────────────────────────

-- Classement du mois : meilleure partie vérifiée de chaque joueur.
-- /rest/v1/classement_periode?kind=eq.hardcore_month&period=eq.2026-10&order=score.desc,seconds.asc,achieved_at.asc&limit=100
create view public.classement_periode as
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
where r.status = 'verified' and r.kind <> 'difficulty'
order by r.kind, r.period, r.player_id, r.score desc, r.seconds asc, r.verified_at asc;
grant select on public.classement_periode to anon, authenticated;
