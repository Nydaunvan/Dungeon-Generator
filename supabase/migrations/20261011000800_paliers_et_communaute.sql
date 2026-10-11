-- Récompenses de niveau de compte (paliers 5 à 100) et récompenses de communauté (galerie de donjons). Tout est COSMÉTIQUE
-- (titres, cadres, couleurs de pseudo) : aucun avantage en jeu.
--  * paliers : un badge par palier, donné automatiquement dès que l'expérience du compte atteint le niveau (rattrapage inclus) ;
--  * créateurs : premier donjon publié, 10 puis 100 téléchargements (téléchargeurs distincts, hors auteur) ;
--  * testeurs : 5 puis 25 donjons de la galerie terminés ;
--  * donjon de la semaine : le donjon le plus téléchargé des 7 derniers jours, mis en avant dans la galerie ; son auteur reçoit un badge
--    chaque lundi.

-- ───────────────────────────── Paliers de niveau de compte ─────────────────────────────

insert into public.badges (id, icon, rarity, label_fr, label_en, desc_fr, desc_en, title_fr, title_en, frame, color, sort_order) values
  ('lvl_5',   '🌱', 1, 'Aventurier', 'Adventurer', 'Atteindre le niveau 5 du compte.', 'Reach account level 5.', 'Aventurier', 'Adventurer', 'bronze', null, 200),
  ('lvl_10',  '🧭', 2, 'Explorateur', 'Explorer', 'Atteindre le niveau 10 du compte.', 'Reach account level 10.', 'Explorateur', 'Explorer', 'argent', null, 201),
  ('lvl_20',  '⚔️', 3, 'Vétéran', 'Veteran', 'Atteindre le niveau 20 du compte.', 'Reach account level 20.', 'Vétéran', 'Veteran', 'or', '#ffd24a', 202),
  ('lvl_30',  '🏰', 3, 'Maître des donjons', 'Dungeon Master', 'Atteindre le niveau 30 du compte.', 'Reach account level 30.', 'Maître des donjons', 'Dungeon Master', 'braise', null, 203),
  ('lvl_40',  '🌀', 4, 'Seigneur du labyrinthe', 'Lord of the Labyrinth', 'Atteindre le niveau 40 du compte.', 'Reach account level 40.', 'Seigneur du labyrinthe', 'Lord of the Labyrinth', 'givre', null, 204),
  ('lvl_50',  '🌅', 4, 'Légende vivante', 'Living Legend', 'Atteindre le niveau 50 du compte.', 'Reach account level 50.', 'Légende vivante', 'Living Legend', 'aurore', null, 205),
  ('lvl_75',  '💎', 5, 'Mythique', 'Mythic', 'Atteindre le niveau 75 du compte.', 'Reach account level 75.', 'Mythique', 'Mythic', 'royal', null, 206),
  ('lvl_100', '♾️', 5, 'Éternel', 'Eternal', 'Atteindre le niveau 100 du compte.', 'Reach account level 100.', 'Éternel', 'Eternal', 'legende', '#fff0a0', 207)
on conflict (id) do nothing;

-- Donne tous les badges de palier que le niveau du joueur permet (idempotent).
create or replace function public._grant_level_badges(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  lvl int;
begin
  select public.account_level(coalesce(sum(amount), 0)) into lvl from public.xp_log where player_id = p_player;
  insert into public.player_badges (player_id, badge_id, period)
  select p_player, b.id, '' from public.badges b
   where b.id ~ '^lvl_[0-9]+$' and substr(b.id, 5)::int <= lvl
  on conflict do nothing;
end $$;
revoke all on function public._grant_level_badges(uuid) from public, anon, authenticated;

create or replace function public.trg_xp_level_badges() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public._grant_level_badges(new.player_id);
  return null;
end $$;
revoke all on function public.trg_xp_level_badges() from public, anon, authenticated;
drop trigger if exists xp_log_level_badges on public.xp_log;
create trigger xp_log_level_badges after insert on public.xp_log
  for each row execute function public.trg_xp_level_badges();

-- Rattrapage : les comptes qui ont déjà atteint un palier le reçoivent maintenant.
select public._grant_level_badges(player_id) from (select distinct player_id from public.xp_log) x;

-- ───────────────────────────── Communauté : badges ─────────────────────────────

insert into public.badges (id, icon, rarity, label_fr, label_en, desc_fr, desc_en, title_fr, title_en, frame, color, sort_order) values
  ('cr_first',    '🏗️', 1, 'Premier donjon publié', 'First Dungeon Published', 'Publier un donjon dans la galerie.', 'Publish a dungeon in the gallery.', 'Bâtisseur', 'Builder', 'bronze', null, 300),
  ('cr_dl_10',    '🧱', 2, 'Donjon apprécié', 'Well-Liked Dungeon', 'Vos donjons ont été téléchargés par 10 joueurs différents.', 'Your dungeons were downloaded by 10 different players.', 'Architecte', 'Architect', 'argent', null, 301),
  ('cr_dl_100',   '🏛️', 4, 'Maître bâtisseur', 'Master Builder', 'Vos donjons ont été téléchargés par 100 joueurs différents.', 'Your dungeons were downloaded by 100 different players.', 'Maître bâtisseur', 'Master Builder', 'or', '#ffd24a', 302),
  ('cr_featured', '⭐', 4, 'Donjon de la semaine', 'Dungeon of the Week', 'Voir un de vos donjons élu donjon de la semaine.', 'Have one of your dungeons chosen as dungeon of the week.', 'Auteur à l''honneur', 'Featured Author', 'aurore', '#c49cff', 303),
  ('test_5',      '🧪', 1, 'Testeur', 'Tester', 'Terminer 5 donjons de la galerie.', 'Clear 5 gallery dungeons.', 'Testeur', 'Tester', 'bronze', null, 310),
  ('test_25',     '🔦', 3, 'Éclaireur', 'Pathfinder', 'Terminer 25 donjons de la galerie.', 'Clear 25 gallery dungeons.', 'Éclaireur', 'Pathfinder', 'argent', '#8fd3ff', 311)
on conflict (id) do nothing;

-- ───────────────────────────── Communauté : téléchargements et donjons terminés ─────────────────────────────

-- Un joueur compte une seule fois pour un donjon, et jamais pour les siens (aucune politique : réservé aux fonctions du serveur).
create table if not exists public.dungeon_downloads (
  dungeon_id uuid not null references public.dungeons (id) on delete cascade,
  player_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (dungeon_id, player_id)
);
create index if not exists dungeon_downloads_recent_idx on public.dungeon_downloads (created_at desc);
alter table public.dungeon_downloads enable row level security;

create table if not exists public.gallery_clears (
  dungeon_id uuid not null references public.dungeons (id) on delete cascade,
  player_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (dungeon_id, player_id)
);
alter table public.gallery_clears enable row level security;

-- Badges « créateur » d'un auteur d'après le total de ses téléchargeurs distincts.
create or replace function public._grant_creator_badges(p_owner uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  select count(distinct x.player_id) into n
    from public.dungeon_downloads x join public.dungeons d on d.id = x.dungeon_id where d.owner_id = p_owner;
  if n >= 10 then perform public._give_badge(p_owner, 'cr_dl_10', ''); end if;
  if n >= 100 then perform public._give_badge(p_owner, 'cr_dl_100', ''); end if;
end $$;
revoke all on function public._grant_creator_badges(uuid) from public, anon, authenticated;

-- Compteur de téléchargements : un téléchargement par joueur et par donjon, hors auteur (remplace la version « simple »).
create or replace function public.count_download(dungeon uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  v_owner uuid;
  added int;
begin
  if uid is null then
    return;
  end if;
  select owner_id into v_owner from public.dungeons where id = dungeon and is_public;
  if not found or v_owner = uid then
    return;
  end if;
  insert into public.dungeon_downloads (dungeon_id, player_id) values (dungeon, uid) on conflict do nothing;
  get diagnostics added = row_count;
  if added = 0 then
    return;
  end if;
  perform set_config('app.count_download', '1', true);
  update public.dungeons set downloads = downloads + 1 where id = dungeon;
  perform set_config('app.count_download', '', true);
  perform public._grant_creator_badges(v_owner);
end $$;
revoke execute on function public.count_download(uuid) from public, anon;
grant execute on function public.count_download(uuid) to authenticated;

-- Premier donjon rendu public : badge « Bâtisseur ».
create or replace function public.trg_dungeon_first_public() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_public then
    perform public._give_badge(new.owner_id, 'cr_first', '');
  end if;
  return null;
end $$;
revoke all on function public.trg_dungeon_first_public() from public, anon, authenticated;
drop trigger if exists dungeons_first_public_trg on public.dungeons;
create trigger dungeons_first_public_trg after insert or update of is_public on public.dungeons
  for each row execute function public.trg_dungeon_first_public();

-- Rattrapage : les auteurs qui ont déjà un donjon public reçoivent « Bâtisseur ».
insert into public.player_badges (player_id, badge_id, period)
select distinct owner_id, 'cr_first', '' from public.dungeons where is_public
on conflict do nothing;

-- Le joueur déclare avoir terminé un donjon de la galerie qu'il a téléchargé (une seule fois par donjon). Récompense cosmétique :
-- la déclaration n'est pas rejouée par le serveur. 25 XP par donjon, pour les 20 premiers. Renvoie le total de donjons terminés.
create or replace function public.record_gallery_clear(p_dungeon uuid) returns int
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  added int;
  n int;
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if not exists (select 1 from public.dungeon_downloads where dungeon_id = p_dungeon and player_id = uid) then
    raise exception 'donjon_non_telecharge';
  end if;
  insert into public.gallery_clears (dungeon_id, player_id) values (p_dungeon, uid) on conflict do nothing;
  get diagnostics added = row_count;
  select count(*) into n from public.gallery_clears where player_id = uid;
  if added > 0 and n <= 20 then
    perform public._give_xp(uid, 'galerie_test', p_dungeon::text, 25);
  end if;
  if n >= 5 then perform public._give_badge(uid, 'test_5', ''); end if;
  if n >= 25 then perform public._give_badge(uid, 'test_25', ''); end if;
  return n;
end $$;
revoke all on function public.record_gallery_clear(uuid) from public, anon;
grant execute on function public.record_gallery_clear(uuid) to authenticated;

-- ───────────────────────────── Donjon de la semaine ─────────────────────────────

-- Le donjon public le plus téléchargé (téléchargeurs distincts) depuis 7 jours ; null s'il n'y en a aucun.
create or replace function public.gallery_featured() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select to_jsonb(t) from (
      select d.id, d.title, d.description, d.downloads, d.created_at, d.owner_id, d.game_version, p.pseudo,
             count(x.player_id) as week_downloads
        from public.dungeons d
        join public.profiles p on p.id = d.owner_id
        join public.dungeon_downloads x on x.dungeon_id = d.id and x.created_at > now() - interval '7 days'
       where d.is_public
       group by d.id, p.pseudo
       order by count(x.player_id) desc, d.created_at desc
       limit 1) t), 'null'::jsonb);
$$;
revoke all on function public.gallery_featured() from public;
grant execute on function public.gallery_featured() to anon, authenticated;

-- Chaque lundi : l'auteur du donjon de la semaine écoulée (au moins 3 téléchargeurs) reçoit « Donjon de la semaine ».
create or replace function public.award_featured_week() returns void
language plpgsql security definer set search_path = '' as $$
declare
  w uuid;
begin
  select d.owner_id into w
    from public.dungeons d
    join public.dungeon_downloads x on x.dungeon_id = d.id and x.created_at > now() - interval '7 days'
   where d.is_public
   group by d.id
  having count(x.player_id) >= 3
   order by count(x.player_id) desc, d.created_at desc
   limit 1;
  if w is not null then
    perform public._give_badge(w, 'cr_featured', to_char(now(), 'IYYY-"W"IW'));
    perform public._give_xp(w, 'galerie_semaine', to_char(now(), 'IYYY-"W"IW'), 200);
  end if;
end $$;
revoke all on function public.award_featured_week() from public, anon, authenticated;

select cron.unschedule('donjon-de-la-semaine') where exists (select 1 from cron.job where jobname = 'donjon-de-la-semaine');
select cron.schedule('donjon-de-la-semaine', '10 0 * * 1', $$select public.award_featured_week()$$);
