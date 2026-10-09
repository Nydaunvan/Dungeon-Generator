-- Dungeon Generator — partie en ligne, étape 3 : défis « déclarés » (donjon aléatoire) et classement unifié.
--
-- Un défi « replay » (étape 2) impose une graine et se vérifie par rejeu. Un défi « declared » (cette étape) concerne les donjons
-- ALÉATOIRES : chaque joueur a son propre donjon, il n'y a donc ni graine commune ni rejeu possible pour l'instant.
-- Le jeu annonce son score (« déclaré ») ; la base le borne par des contrôles de plausibilité (voir scores_garde) et la modération
-- peut retirer une ligne depuis le tableau de bord. Le classement indique si un score est vérifié ou seulement déclaré.
-- Quand le rejeu vérifié sera disponible pour ces défis, les scores déclarés pourront être remplacés sans changer le jeu.

-- ───────────────────────────── Défis : mode, donjon et graine facultatifs ─────────────────────────────

alter table public.challenges
  add column mode text not null default 'replay' check (mode in ('replay', 'declared'));
alter table public.challenges alter column config_code drop not null;   -- pas de donjon imposé pour un défi « declared »
alter table public.challenges alter column seed drop not null;
alter table public.challenges
  add constraint challenges_mode_coherent check (
    mode = 'declared' or (config_code is not null and seed is not null)
  );
-- Ordre d'affichage et libellé de l'unité du score (ex. « niveaux ») : texte libre de l'interface, traduit par le jeu via la clé.
alter table public.challenges add column unit text not null default 'points' check (unit ~ '^[a-z_]{1,30}$');
alter table public.challenges add column sort_order int not null default 100;

-- ───────────────────────────── Scores déclarés ─────────────────────────────

create table public.scores (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  player_id uuid not null references public.profiles (id) on delete cascade,
  run_id text not null check (run_id ~ '^[A-Za-z0-9_-]{8,64}$'),         -- identifiant de la partie (une ligne par partie, mise à jour au fil de la progression)
  score int not null check (score between 0 and 100000),
  seconds int not null default 0 check (seconds between 0 and 8640000),   -- temps de jeu de la partie
  details jsonb not null default '{}'::jsonb check (octet_length(details::text) <= 2000),
  game_version text not null check (char_length(game_version) <= 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (challenge_id, player_id, run_id)
);
create index scores_challenge_idx on public.scores (challenge_id, score desc, seconds);
create index scores_player_idx on public.scores (player_id, created_at desc);

alter table public.scores enable row level security;

create policy "voir ses propres scores" on public.scores
  for select to authenticated
  using (player_id = (select auth.uid()));

-- Un joueur n'écrit que ses propres scores, pour un défi « declared » ouvert.
create policy "déclarer son score" on public.scores
  for insert to authenticated
  with check (
    player_id = (select auth.uid())
    and exists (
      select 1 from public.challenges c
      where c.id = challenge_id and c.mode = 'declared'
        and c.starts_at <= now() and (c.ends_at is null or c.ends_at > now())
    )
  );
create policy "mettre à jour son score" on public.scores
  for update to authenticated
  using (player_id = (select auth.uid()))
  with check (player_id = (select auth.uid()));
-- Pas de suppression par le joueur : une partie ratée se contente de ne plus progresser. La modération supprime depuis le tableau de bord.

-- Contrôles de plausibilité et garde-fous anti-abus.
--  - un score ne baisse jamais (on garde la meilleure valeur de la partie, avec le temps correspondant) ;
--  - il faut au moins 10 s de jeu par unité de score (franchir un niveau prend plus de temps que cela) ;
--  - 30 parties distinctes par 24 h et par défi au plus.
create function public.scores_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if (select count(*) from public.scores
        where player_id = new.player_id and challenge_id = new.challenge_id and created_at > now() - interval '24 hours') >= 30 then
      raise exception 'trop_de_soumissions';
    end if;
  else
    new.challenge_id := old.challenge_id;
    new.player_id := old.player_id;
    new.run_id := old.run_id;
    new.created_at := old.created_at;
    if new.score < old.score then      -- un score ne baisse pas : on ignore la régression
      new.score := old.score;
      new.seconds := old.seconds;
      new.details := old.details;
      new.game_version := old.game_version;
    end if;
  end if;
  if new.score > 0 and new.seconds < new.score * 10 then
    raise exception 'score_invraisemblable';
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger scores_garde_trg
  before insert or update on public.scores
  for each row execute function public.scores_garde();

-- ───────────────────────────── Classement unifié ─────────────────────────────

-- Meilleure partie de chaque joueur par défi : score VÉRIFIÉ (rejeu) ou DÉCLARÉ, au choix du meilleur score puis du meilleur temps.
-- Colonnes de détail restreintes : le journal d'actions des parties n'est jamais exposé. La vue s'exécute avec les droits de son
-- propriétaire (comme public.leaderboard) : elle expose le pseudo et le score sans ouvrir les tables sous-jacentes.
-- Interrogation depuis le jeu :
--   /rest/v1/classement?challenge_id=eq.<id>&order=score.desc,seconds.asc.nullslast,achieved_at.asc&limit=100
create view public.classement as
select distinct on (x.challenge_id, x.player_id)
  x.challenge_id, x.player_id, p.pseudo, x.score, x.seconds, x.details, x.verified, x.achieved_at
from (
  select s.challenge_id, s.player_id, s.score, s.seconds,
         (select coalesce(jsonb_object_agg(k, s.details -> k), '{}'::jsonb)
            from unnest(array['expeditions', 'difficulty', 'kills', 'levels']) as k
           where s.details ? k) as details,
         false as verified, s.updated_at as achieved_at
  from public.scores s
  union all
  select r.challenge_id, r.player_id, r.verified_score, null::int, '{}'::jsonb, true, r.verified_at
  from public.runs r
  where r.status = 'verified'
) x
join public.profiles p on p.id = x.player_id
order by x.challenge_id, x.player_id, x.score desc, x.seconds asc nulls last, x.achieved_at asc;

grant select on public.classement to anon, authenticated;

-- ───────────────────────────── Premier défi ─────────────────────────────

insert into public.challenges (slug, title, theme, description, mode, unit, sort_order, game_version, rules)
values (
  'le-plus-profond',
  'Le plus profond',
  'Exploration',
  'Qui ira le plus loin dans des donjons aléatoires ? Chaque niveau franchi (escalier pris) compte, expéditions successives comprises. À égalité, le temps de jeu le plus court l''emporte.',
  'declared', 'niveaux', 10, '1.32.1',
  '{"metric": "levelsCleared", "tiebreak": "seconds", "origin": "random", "en": {"title": "The Deepest", "description": "Who will go the furthest in random dungeons? Every level cleared (stairs taken) counts, across successive expeditions. On a tie, the shortest play time wins."}}'::jsonb
);
