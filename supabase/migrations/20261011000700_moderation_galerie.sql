-- Modération de la galerie de donjons (écran « Galerie » du Super admin) :
--  * signalements traitables (handled_at) ;
--  * interdiction de publier pour un auteur (table gallery_bans, illisible depuis le jeu) ;
--  * fonctions réservées au super admin : liste des donjons signalés, retrait de la galerie, suppression, classement sans suite,
--    interdiction / levée d'interdiction de publier, statistiques.

alter table public.dungeon_reports add column if not exists handled_at timestamptz;
create index if not exists dungeon_reports_pending_idx on public.dungeon_reports (dungeon_id) where handled_at is null;

create table if not exists public.gallery_bans (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  reason text,
  banned_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.gallery_bans enable row level security;      -- aucune politique : réservée aux fonctions du serveur

-- Un auteur interdit ne peut plus rendre un donjon public.
create or replace function public.dungeons_ban_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_public and exists (select 1 from public.gallery_bans b where b.player_id = new.owner_id) then
    raise exception 'publication_interdite';
  end if;
  return new;
end $$;
drop trigger if exists dungeons_ban_garde_trg on public.dungeons;
create trigger dungeons_ban_garde_trg
  before insert or update of is_public on public.dungeons
  for each row execute function public.dungeons_ban_garde();

-- Donjons signalés (non traités, ou tous avec p_include_handled), le plus récemment signalé d'abord.
create or replace function public.admin_gallery_reports(p_include_handled boolean default false, p_limit int default 50) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.last_report desc) from (
      select d.id as dungeon_id, d.title, d.description, d.is_public, d.downloads, d.created_at, d.game_version,
             p.id as player_id, p.pseudo,
             count(r.id) as reports, max(r.created_at) as last_report,
             (select jsonb_agg(x.reason) from (select r2.reason from public.dungeon_reports r2
                where r2.dungeon_id = d.id order by r2.created_at limit 3) x) as reasons,
             exists (select 1 from public.gallery_bans b where b.player_id = p.id) as banned
        from public.dungeon_reports r
        join public.dungeons d on d.id = r.dungeon_id
        join public.profiles p on p.id = d.owner_id
       where p_include_handled or r.handled_at is null
       group by d.id, p.id
       order by max(r.created_at) desc
       limit least(greatest(p_limit, 1), 200)
    ) t), '[]'::jsonb);
end $$;

-- Retire un donjon de la galerie (il reste dans l'espace de son auteur) et classe ses signalements.
create or replace function public.admin_gallery_unpublish(p_dungeon uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  update public.dungeons set is_public = false where id = p_dungeon and is_public;
  update public.dungeon_reports set handled_at = now() where dungeon_id = p_dungeon and handled_at is null;
end $$;

-- Supprime définitivement un donjon (et ses signalements).
create or replace function public.admin_gallery_delete(p_dungeon uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  delete from public.dungeons where id = p_dungeon;
end $$;

-- Classe les signalements d'un donjon sans suite.
create or replace function public.admin_gallery_dismiss(p_dungeon uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  update public.dungeon_reports set handled_at = now() where dungeon_id = p_dungeon and handled_at is null;
end $$;

-- Interdit à un auteur de publier (ses donjons publics repassent privés). Un super admin ne peut pas être interdit.
create or replace function public.admin_gallery_ban(p_player uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  if p_player is null or not exists (select 1 from public.profiles where id = p_player) or exists (select 1 from public.admins where player_id = p_player) then
    raise exception 'joueur_inconnu';
  end if;
  insert into public.gallery_bans (player_id, reason, banned_by)
  values (p_player, nullif(left(btrim(coalesce(p_reason, '')), 200), ''), (select auth.uid()))
  on conflict (player_id) do update set reason = excluded.reason, banned_by = excluded.banned_by, created_at = now();
  update public.dungeons set is_public = false where owner_id = p_player and is_public;
  update public.dungeon_reports set handled_at = now()
   where handled_at is null and dungeon_id in (select id from public.dungeons where owner_id = p_player);
end $$;

create or replace function public.admin_gallery_unban(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  delete from public.gallery_bans where player_id = p_player;
end $$;

-- Auteurs interdits de publication : [{player_id, pseudo, reason, created_at}].
create or replace function public.admin_gallery_bans() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('player_id', b.player_id, 'pseudo', p.pseudo, 'reason', b.reason, 'created_at', b.created_at)
                                    order by b.created_at desc)
                     from public.gallery_bans b join public.profiles p on p.id = b.player_id), '[]'::jsonb);
end $$;

create or replace function public.admin_gallery_stats() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return jsonb_build_object(
    'public', (select count(*) from public.dungeons where is_public),
    'total', (select count(*) from public.dungeons),
    'downloads', (select coalesce(sum(downloads), 0) from public.dungeons),
    'reports_pending', (select count(distinct dungeon_id) from public.dungeon_reports where handled_at is null),
    'bans', (select count(*) from public.gallery_bans));
end $$;

do $$
declare f text;
begin
  foreach f in array array['admin_gallery_reports(boolean,int)', 'admin_gallery_unpublish(uuid)', 'admin_gallery_delete(uuid)', 'admin_gallery_dismiss(uuid)',
                           'admin_gallery_ban(uuid,text)', 'admin_gallery_unban(uuid)', 'admin_gallery_bans()', 'admin_gallery_stats()']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
