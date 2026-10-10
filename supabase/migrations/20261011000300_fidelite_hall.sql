-- Dungeon Generator — Récompenses de fidélité : séries de semaines du Défi (badges 3/6/12), Hall des légendes (champions de semaine et de mois).

alter table public.badges drop constraint badges_frame_check, add constraint badges_frame_check check (frame is null or frame in ('bronze', 'argent', 'or', 'braise', 'givre', 'royal', 'aurore', 'legende'));

insert into public.badges (id, icon, rarity, label_fr, label_en, desc_fr, desc_en, title_fr, title_en, frame, color, sort_order) values
  ('wk_streak_3', '🔗', 2, 'Assidu', 'Dedicated', 'Jouer le Défi de la semaine 3 semaines de suite.', 'Play the weekly challenge 3 weeks in a row.', 'Assidu', 'Dedicated', 'bronze', null, 130),
  ('wk_streak_6', '🌠', 4, 'Fidèle au poste', 'True to the Post', 'Jouer le Défi de la semaine 6 semaines de suite.', 'Play the weekly challenge 6 weeks in a row.', 'Fidèle', 'Loyal', 'or', '#ffd24a', 131),
  ('wk_streak_12', '🌌', 5, 'Inébranlable', 'Unshakable', 'Jouer le Défi de la semaine 12 semaines de suite.', 'Play the weekly challenge 12 weeks in a row.', 'Inébranlable', 'Unshakable', 'aurore', '#c49cff', 132)
on conflict (id) do nothing;

-- Série de semaines consécutives (jouées et vérifiées avec au moins un niveau franchi) qui se termine cette semaine ou la précédente.
create or replace function public.weekly_streak(p_player uuid) returns int
language sql stable security definer set search_path = '' as $$
  with wk as (
    select distinct to_date(period, 'IYYY-"W"IW') as d
    from public.ranked_runs
    where player_id = p_player and kind = 'weekly' and status = 'verified' and score >= 1 and not test and period is not null
  ), g as (
    select d, d - ((row_number() over (order by d)) * 7)::int as grp from wk
  ), runs as (
    select grp, count(*)::int as n, max(d) as last_d from g group by grp
  )
  select coalesce(max(n) filter (where last_d >= date_trunc('week', now() at time zone 'Europe/Paris')::date - 7), 0) from runs;
$$;
revoke all on function public.weekly_streak(uuid) from public, anon;
grant execute on function public.weekly_streak(uuid) to authenticated;

create or replace function public.my_weekly_streak() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('streak', public.weekly_streak((select auth.uid())),
    'played_this_week', exists (select 1 from public.ranked_runs r where r.player_id = (select auth.uid()) and r.kind = 'weekly' and r.status = 'verified'
      and r.score >= 1 and not r.test and r.period = public.weekly_current()->>'period'));
$$;
revoke all on function public.my_weekly_streak() from public, anon;
grant execute on function public.my_weekly_streak() to authenticated;

-- Hall des légendes : le champion de chaque semaine et de chaque mois, à vie.
create table if not exists public.hall_of_fame (
  kind text not null check (kind in ('hardcore_month', 'weekly')),
  period text not null,
  player_id uuid not null references public.profiles (id) on delete cascade,
  run_id uuid,
  score int not null,
  seconds int not null,
  metrics jsonb,
  rule_id text,
  closed_at timestamptz not null default now(),
  primary key (kind, period)
);
alter table public.hall_of_fame enable row level security;
create policy "hall des légendes lisible par tous" on public.hall_of_fame for select using (true);

create or replace view public.hall_legendes as
select h.kind, h.period, h.score, h.seconds, h.rule_id, h.closed_at, p.pseudo,
  (select icon from public.weekly_rules w where w.rule_id = h.rule_id) as rule_icon,
  (select label_fr from public.weekly_rules w where w.rule_id = h.rule_id) as rule_fr,
  (select label_en from public.weekly_rules w where w.rule_id = h.rule_id) as rule_en,
  (select frame from public.badges where id = c.frame_badge) as frame,
  (select color from public.badges where id = c.color_badge) as color
from public.hall_of_fame h
join public.profiles p on p.id = h.player_id
left join public.player_cosmetics c on c.player_id = h.player_id;
grant select on public.hall_legendes to anon, authenticated;

create or replace function public.award_run(p_run_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  r public.ranked_runs%rowtype;
  mult numeric;
  xp int;
  st int;
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
    if r.score >= 1 then
      st := public.weekly_streak(r.player_id);
      if st >= 3 then perform public._give_badge(r.player_id, 'wk_streak_3', ''); end if;
      if st >= 6 then perform public._give_badge(r.player_id, 'wk_streak_6', ''); end if;
      if st >= 12 then perform public._give_badge(r.player_id, 'wk_streak_12', ''); perform public._give_xp(r.player_id, 'weekly_serie12', '', 500); end if;
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
