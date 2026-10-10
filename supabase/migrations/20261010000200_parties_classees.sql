-- Dungeon Generator — parties classées par difficulté (rejeu vérifié), étape 6a.
--
-- Le serveur tire la graine (le joueur ne la choisit pas) et fixe les réglages du donjon par difficulté. Le jeu envoie ensuite le
-- journal d'actions de la partie ; un vérificateur de confiance (clé secrète, hors du dépôt) le rejoue avec les règles de la version
-- de la partie et inscrit le score RECALCULÉ. Seules les parties « verified » figurent au classement : il reste vide tant que le
-- vérificateur n'a rien validé.

-- ───────────────────────────── Réglages par difficulté ─────────────────────────────

create table public.ranked_modes (
  difficulty text primary key check (difficulty in ('easy', 'normal', 'hard', 'hardcore')),
  levels int not null check (levels between 1 and 12),
  width int not null check (width between 7 and 40),
  height int not null check (height between 7 and 40),
  sort_order int not null default 100
);
alter table public.ranked_modes enable row level security;
create policy "modes classés lisibles par tous" on public.ranked_modes for select using (true);

insert into public.ranked_modes (difficulty, levels, width, height, sort_order) values
  ('easy', 3, 13, 11, 10),
  ('normal', 3, 13, 11, 20),
  ('hard', 3, 13, 11, 30),
  ('hardcore', 3, 13, 11, 40);

-- ───────────────────────────── Parties classées ─────────────────────────────

create table public.ranked_runs (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles (id) on delete cascade,
  difficulty text not null references public.ranked_modes (difficulty),
  seed text not null check (seed ~ '^[0-9a-f]{32}$'),
  params jsonb not null,                                                -- réglages figés au départ (niveaux, taille, difficulté)
  game_version text not null check (char_length(game_version) between 1 and 20),
  status text not null default 'started' check (status in ('started', 'submitted', 'verified', 'rejected', 'expired')),
  log jsonb check (log is null or octet_length(log::text) <= 500000),   -- journal d'actions à rejouer
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  verified_at timestamptz,
  reject_reason text,
  score int check (score >= 0),                                         -- niveaux franchis, recalculés par le rejeu
  seconds int check (seconds >= 0),                                     -- temps de jeu (horloge du jeu) : départage les égalités
  metrics jsonb,                                                        -- résumé recalculé (monstres, expéditions…)
  constraint ranked_runs_coherent check ((status = 'verified') = (score is not null))
);
create index ranked_runs_player_idx on public.ranked_runs (player_id, started_at desc);
create index ranked_runs_pending_idx on public.ranked_runs (submitted_at) where status = 'submitted';
create index ranked_runs_board_idx on public.ranked_runs (difficulty, score desc, seconds) where status = 'verified';

alter table public.ranked_runs enable row level security;

-- Le joueur lit ses propres parties. Aucune politique d'écriture : tout passe par les deux fonctions ci-dessous (et le vérificateur).
create policy "voir ses parties classées" on public.ranked_runs
  for select to authenticated
  using (player_id = (select auth.uid()));

-- ───────────────────────────── Démarrer une partie classée ─────────────────────────────

-- Renvoie {run_id, seed, params}. Une seule partie « started » à la fois : l'ancienne est abandonnée (« expired »).
create function public.start_ranked_run(p_difficulty text, p_game_version text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  m public.ranked_modes%rowtype;
  new_seed text;
  prm jsonb;
  rid uuid;
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if p_game_version is null or char_length(p_game_version) not between 1 and 20 then
    raise exception 'version_invalide';
  end if;
  select * into m from public.ranked_modes where difficulty = p_difficulty;
  if not found then
    raise exception 'mode_inconnu';
  end if;
  if (select count(*) from public.ranked_runs where player_id = uid and started_at > now() - interval '24 hours') >= 40 then
    raise exception 'trop_de_parties';
  end if;
  update public.ranked_runs set status = 'expired' where player_id = uid and status = 'started';
  new_seed := replace(gen_random_uuid()::text, '-', '');
  prm := jsonb_build_object('levels', m.levels, 'width', m.width, 'height', m.height, 'difficulty', m.difficulty, 'mods', '[]'::jsonb);
  insert into public.ranked_runs (player_id, difficulty, seed, params, game_version)
  values (uid, m.difficulty, new_seed, prm, p_game_version)
  returning id into rid;
  return jsonb_build_object('run_id', rid, 'seed', new_seed, 'params', prm);
end $$;
revoke all on function public.start_ranked_run(text, text) from public, anon;
grant execute on function public.start_ranked_run(text, text) to authenticated;

-- ───────────────────────────── Envoyer le journal ─────────────────────────────

-- Une seule fois par partie : le journal passe de « started » à « submitted » et attend le vérificateur.
create function public.submit_ranked_run(p_run_id uuid, p_log jsonb) returns void
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
   where id = p_run_id and player_id = uid and status = 'started';
  if not found then
    raise exception 'partie_introuvable';
  end if;
end $$;
revoke all on function public.submit_ranked_run(uuid, jsonb) from public, anon;
grant execute on function public.submit_ranked_run(uuid, jsonb) to authenticated;

-- ───────────────────────────── Classement par difficulté ─────────────────────────────

-- Meilleure partie VÉRIFIÉE de chaque joueur, par difficulté : plus de niveaux, puis temps de jeu le plus court, puis la plus ancienne.
-- Le journal n'est jamais exposé. Interrogation depuis le jeu :
--   /rest/v1/classement_difficulte?difficulty=eq.normal&order=score.desc,seconds.asc,achieved_at.asc&limit=100
create view public.classement_difficulte as
select distinct on (r.difficulty, r.player_id)
  r.difficulty, r.player_id, p.pseudo, r.score, r.seconds, r.metrics, r.verified_at as achieved_at
from public.ranked_runs r
join public.profiles p on p.id = r.player_id
where r.status = 'verified'
order by r.difficulty, r.player_id, r.score desc, r.seconds asc, r.verified_at asc;

grant select on public.classement_difficulte to anon, authenticated;
