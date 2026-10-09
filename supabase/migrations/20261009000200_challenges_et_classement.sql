-- Dungeon Generator — partie en ligne, étape 2 : challenges, parties soumises (rejeu vérifié) et classement.
--
-- Principe anti-triche : le jeu n'envoie JAMAIS un score que le serveur croirait sur parole. Il envoie la graine et le journal
-- d'actions de la partie ; un vérificateur de confiance (voir supabase/README.md) rejoue la partie avec les règles du jeu
-- et inscrit le score recalculé. Seules les parties « verified » comptent dans le classement.

-- ───────────────────────────── Challenges ─────────────────────────────

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]{3,40}$'),
  title text not null check (char_length(title) between 1 and 80),
  theme text not null check (char_length(theme) between 1 and 40),     -- libre pour l'instant : les thèmes restent à décider
  description text not null default '' check (char_length(description) <= 1000),
  config_code text not null check (config_code like 'DGZ1%'),          -- donjon imposé, identique pour tous les participants
  seed text not null,                                                    -- graine imposée de la partie
  rules jsonb not null default '{}'::jsonb,                              -- règles propres au challenge (score, limites…)
  game_version text not null,                                            -- version des règles à utiliser pour le rejeu
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);
alter table public.challenges enable row level security;

-- Lecture publique ; aucune politique d'écriture : les challenges se créent depuis le tableau de bord (clé secrète).
create policy "challenges lisibles par tous" on public.challenges
  for select using (true);

-- ───────────────────────────── Parties soumises ─────────────────────────────

create table public.runs (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  player_id uuid not null references public.profiles (id) on delete cascade,
  game_version text not null check (char_length(game_version) <= 20),
  seed text not null,
  actions jsonb not null check (octet_length(actions::text) <= 500000),   -- journal d'actions à rejouer
  client_score int check (client_score >= 0),                              -- annoncé par le jeu : indicatif, jamais classé
  status text not null default 'pending' check (status in ('pending', 'verified', 'rejected')),
  verified_score int check (verified_score >= 0),
  verified_at timestamptz,
  reject_reason text,
  created_at timestamptz not null default now(),
  constraint runs_verifie_coherent check ((status = 'verified') = (verified_score is not null))
);
create index runs_challenge_status_idx on public.runs (challenge_id, status);
create index runs_player_idx on public.runs (player_id, created_at desc);
create index runs_pending_idx on public.runs (created_at) where status = 'pending';

alter table public.runs enable row level security;

create policy "voir ses propres parties" on public.runs
  for select to authenticated
  using (player_id = (select auth.uid()));

-- Un joueur ne peut soumettre qu'une partie « pending », sans score vérifié, pour un challenge ouvert.
-- Aucune politique de modification ni de suppression : seul le vérificateur (clé secrète) change le statut.
create policy "soumettre sa partie" on public.runs
  for insert to authenticated
  with check (
    player_id = (select auth.uid())
    and status = 'pending'
    and verified_score is null and verified_at is null and reject_reason is null
    and exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and c.starts_at <= now()
        and (c.ends_at is null or c.ends_at > now())
        and c.game_version = runs.game_version
        and c.seed = runs.seed
    )
  );

-- Limite anti-abus : 10 parties en attente de vérification par joueur, 50 soumissions par 24 h.
create function public.runs_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.runs where player_id = new.player_id and status = 'pending') >= 10 then
    raise exception 'trop_de_parties_en_attente';
  end if;
  if (select count(*) from public.runs where player_id = new.player_id and created_at > now() - interval '24 hours') >= 50 then
    raise exception 'trop_de_soumissions';
  end if;
  return new;
end $$;
create trigger runs_garde_trg
  before insert on public.runs
  for each row execute function public.runs_garde();

-- ───────────────────────────── Classement ─────────────────────────────

-- Meilleure partie VÉRIFIÉE de chaque joueur, par challenge. La vue s'exécute avec les droits de son propriétaire : elle expose
-- uniquement le pseudo et le score, sans ouvrir la table des parties (qui contient les journaux d'actions).
-- Interrogation depuis le jeu : /rest/v1/leaderboard?challenge_id=eq.<id>&order=score.desc,verified_at.asc&limit=100
create view public.leaderboard as
select distinct on (r.challenge_id, r.player_id)
  r.challenge_id,
  r.player_id,
  p.pseudo,
  r.verified_score as score,
  r.verified_at
from public.runs r
join public.profiles p on p.id = r.player_id
where r.status = 'verified'
order by r.challenge_id, r.player_id, r.verified_score desc, r.verified_at asc;

grant select on public.leaderboard to anon, authenticated;
