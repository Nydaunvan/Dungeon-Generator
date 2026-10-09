-- Dungeon Generator — partie en ligne, étape 1 : profils, donjons partagés, signalements.
--
-- À appliquer dans le projet Supabase (SQL Editor), dans l'ordre des fichiers de ce dossier.
-- Le jeu n'utilise que la clé PUBLIQUE (publishable) : tout ce qu'elle a le droit de faire est défini ici par les règles d'accès
-- par ligne (RLS). La clé secrète (sb_secret_… / service_role) ne doit jamais figurer dans le dépôt ni dans le jeu.

-- ───────────────────────────── Profils ─────────────────────────────

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  pseudo text not null,
  created_at timestamptz not null default now(),
  constraint profiles_pseudo_format check (pseudo ~ '^[A-Za-z0-9_-]{3,20}$')
);
-- pseudo unique sans tenir compte des majuscules
create unique index profiles_pseudo_lower_idx on public.profiles (lower(pseudo));

alter table public.profiles enable row level security;

-- Le pseudo est public (classements, auteurs de donjons) ; l'email, lui, reste dans auth.users et n'est jamais exposé.
create policy "profils lisibles par tous" on public.profiles
  for select using (true);
create policy "chacun modifie son propre profil" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
-- Pas de politique d'insertion : le profil est créé par le déclencheur ci-dessous, à l'inscription.

-- Création automatique du profil. Le jeu envoie le pseudo choisi dans les métadonnées de l'inscription ({"pseudo": "..."}) ;
-- s'il est invalide ou déjà pris, on attribue un pseudo provisoire plutôt que de refuser l'inscription.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  wanted text := coalesce(new.raw_user_meta_data ->> 'pseudo', '');
begin
  if wanted !~ '^[A-Za-z0-9_-]{3,20}$'
     or exists (select 1 from public.profiles where lower(pseudo) = lower(wanted)) then
    wanted := 'joueur_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;
  insert into public.profiles (id, pseudo) values (new.id, wanted);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Le jeu vérifie la disponibilité d'un pseudo avant l'inscription.
create function public.pseudo_disponible(p text) returns boolean
language sql stable security definer set search_path = '' as $$
  select p ~ '^[A-Za-z0-9_-]{3,20}$'
     and not exists (select 1 from public.profiles where lower(pseudo) = lower(p));
$$;
grant execute on function public.pseudo_disponible(text) to anon, authenticated;

-- Suppression du compte par le joueur lui-même (RGPD) : efface l'utilisateur, et en cascade son profil, ses donjons et ses parties.
create function public.supprimer_mon_compte() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'non_connecte';
  end if;
  delete from auth.users where id = (select auth.uid());
end $$;
revoke execute on function public.supprimer_mon_compte() from public, anon;
grant execute on function public.supprimer_mon_compte() to authenticated;

-- ───────────────────────────── Donjons partagés ─────────────────────────────

create table public.dungeons (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 60),
  description text not null default '' check (char_length(description) <= 500),
  -- code de partage du jeu : « DGZ1 » + base64 du JSON compressé (voir Data.encode_code)
  code text not null check (code like 'DGZ1%' and char_length(code) between 10 and 200000),
  game_version text not null check (char_length(game_version) <= 20),   -- version du jeu qui a créé le donjon
  schema_version int not null default 1,                                  -- version du schéma des données (SaveMigrations.SCHEMA)
  tags text[] not null default '{}' check (cardinality(tags) <= 8),
  is_public boolean not null default true,
  downloads int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index dungeons_owner_idx on public.dungeons (owner_id);
create index dungeons_public_recent_idx on public.dungeons (created_at desc) where is_public;

alter table public.dungeons enable row level security;

create policy "donjons publics ou les siens" on public.dungeons
  for select using (is_public or owner_id = (select auth.uid()));
create policy "publier un donjon à son nom" on public.dungeons
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and downloads = 0);
create policy "modifier ses donjons" on public.dungeons
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "supprimer ses donjons" on public.dungeons
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- Limite anti-abus : 20 publications par 24 h et 200 donjons au total par joueur ; date de modification tenue à jour.
create function public.dungeons_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if (select count(*) from public.dungeons where owner_id = new.owner_id and created_at > now() - interval '24 hours') >= 20 then
      raise exception 'trop_de_publications';
    end if;
    if (select count(*) from public.dungeons where owner_id = new.owner_id) >= 200 then
      raise exception 'trop_de_donjons';
    end if;
  else
    new.owner_id := old.owner_id;
    new.created_at := old.created_at;
    -- le compteur ne se modifie que par count_download(), qui lève ce drapeau le temps de sa transaction (et ne touche pas à updated_at)
    if coalesce(current_setting('app.count_download', true), '') = '1' then
      new.updated_at := old.updated_at;
    else
      new.downloads := old.downloads;
      new.updated_at := now();
    end if;
  end if;
  return new;
end $$;
create trigger dungeons_garde_trg
  before insert or update on public.dungeons
  for each row execute function public.dungeons_garde();

-- Compteur de téléchargements (un appel par import réussi ; simple, non dédoublonné).
create function public.count_download(dungeon uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform set_config('app.count_download', '1', true);      -- true = limité à la transaction en cours
  update public.dungeons set downloads = downloads + 1
  where id = dungeon and is_public;
  perform set_config('app.count_download', '', true);
end $$;
revoke execute on function public.count_download(uuid) from public, anon;
grant execute on function public.count_download(uuid) to authenticated;

-- ───────────────────────────── Signalements ─────────────────────────────

create table public.dungeon_reports (
  id uuid primary key default gen_random_uuid(),
  dungeon_id uuid not null references public.dungeons (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 500),
  created_at timestamptz not null default now(),
  unique (dungeon_id, reporter_id)
);
alter table public.dungeon_reports enable row level security;

create policy "signaler un donjon" on public.dungeon_reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()));
create policy "voir ses propres signalements" on public.dungeon_reports
  for select to authenticated
  using (reporter_id = (select auth.uid()));
-- La modération (lecture de tous les signalements, retrait d'un donjon) se fait depuis le tableau de bord Supabase.
