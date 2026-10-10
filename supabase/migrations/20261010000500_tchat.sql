-- Dungeon Generator — tchat des joueurs connectés (étape 7).
--
-- Salons : Général, Français, English. Lecture et écriture réservées aux comptes connectés.
-- Aucune table n'est accessible directement depuis le jeu (RLS sans politique) : tout passe par des fonctions qui font respecter les règles :
--  - écriture : 300 caractères au plus, un message toutes les 3 s et 15 par minute, pas de message identique en 30 s, filtre de mots
--    interdits (table chat_words, modifiable par le super admin), joueur réduit au silence (chat_mutes) refusé ;
--  - lecture : les messages supprimés et ceux des joueurs bloqués par le lecteur ne sont jamais renvoyés ;
--  - signalement d'un message par n'importe quel joueur ; le super admin les traite (supprimer, couper, ignorer) ;
--  - conservation : 30 jours (chat_purge_old, appelée par le vérificateur) ; la suppression d'un compte supprime ses messages.
-- Ni courriel ni identifiant technique de session n'est renvoyé : seulement le pseudo, le niveau de compte et la couleur du pseudo.

-- ───────────────────────────── Tables ─────────────────────────────

create table public.chat_rooms (
  id text primary key check (id ~ '^[a-z]{2,12}$'),
  label_fr text not null,
  label_en text not null,
  sort_order int not null default 100
);
alter table public.chat_rooms enable row level security;
create policy "salons lisibles par les joueurs connectés" on public.chat_rooms for select to authenticated using (true);
insert into public.chat_rooms (id, label_fr, label_en, sort_order) values
  ('general', 'Général', 'General', 10),
  ('fr', 'Français', 'French', 20),
  ('en', 'Anglais', 'English', 30);

create table public.chat_messages (
  id bigint generated always as identity primary key,
  room text not null references public.chat_rooms (id),
  player_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 300),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.profiles (id) on delete set null
);
create index chat_messages_room_idx on public.chat_messages (room, id desc) where deleted_at is null;
create index chat_messages_player_idx on public.chat_messages (player_id, created_at desc);
create index chat_messages_age_idx on public.chat_messages (created_at);
alter table public.chat_messages enable row level security;      -- aucune politique : lecture et écriture par fonctions seulement

create table public.chat_blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.chat_blocks enable row level security;

create table public.chat_mutes (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  until timestamptz not null,
  reason text check (reason is null or char_length(reason) <= 200),
  muted_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.chat_mutes enable row level security;

create table public.chat_reports (
  id bigint generated always as identity primary key,
  message_id bigint not null references public.chat_messages (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason text check (reason is null or char_length(reason) <= 200),
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  unique (message_id, reporter_id)
);
create index chat_reports_open_idx on public.chat_reports (created_at desc) where handled_at is null;
alter table public.chat_reports enable row level security;

-- Mots interdits : minuscules sans accent ; un mot ne correspond qu'en mot entier (« pute » n'attrape pas « computer »).
create table public.chat_words (
  word text primary key check (char_length(word) between 2 and 40 and word ~ '^[a-z0-9][a-z0-9 ''-]*$')
);
alter table public.chat_words enable row level security;
insert into public.chat_words (word) values
  ('nigger'), ('nigga'), ('faggot'), ('kys'), ('kill yourself'), ('sieg heil'), ('heil hitler'),
  ('encule'), ('enculer'), ('enculee'), ('connard'), ('connasse'), ('salope'), ('pute'), ('fdp'), ('ntm'),
  ('sale juif'), ('sale arabe'), ('sale noir'), ('sale negre'), ('sale pd');

-- ───────────────────────────── Utilitaires internes ─────────────────────────────

create function public._chat_norm(p text) returns text
language sql immutable set search_path = '' as $$
  select translate(lower(coalesce(p, '')), 'àâäáãéèêëíìîïóòôöõúùûüýÿç', 'aaaaaeeeeiiiiooooouuuuyyc')
$$;

create function public._chat_filtered(p_body text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.chat_words w where public._chat_norm(p_body) ~ ('\m' || w.word || '\M'))
$$;

revoke all on function public._chat_norm(text), public._chat_filtered(text) from public, anon, authenticated;

-- ───────────────────────────── Écrire ─────────────────────────────

create function public.chat_send(p_room text, p_body text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  b text;
  mute public.chat_mutes%rowtype;
  new_id bigint;
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if p_body is null or char_length(p_body) > 1000 then
    raise exception 'message_trop_long';
  end if;
  -- caractères de commande et de direction du texte retirés, espaces réduits
  b := btrim(regexp_replace(regexp_replace(p_body, '[[:cntrl:]​-‏‪-‮⁦-⁩﻿]', ' ', 'g'), ' {2,}', ' ', 'g'));
  if char_length(b) = 0 then
    raise exception 'message_vide';
  end if;
  if char_length(b) > 300 then
    raise exception 'message_trop_long';
  end if;
  if not exists (select 1 from public.chat_rooms where id = p_room) then
    raise exception 'salon_inconnu';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));       -- deux envois simultanés ne contournent pas la limite
  select * into mute from public.chat_mutes where player_id = uid and until > now();
  if found then
    raise exception 'chat_mute' using hint = mute.until::text;
  end if;
  if exists (select 1 from public.chat_messages where player_id = uid and created_at > now() - interval '3 seconds')
     or (select count(*) from public.chat_messages where player_id = uid and created_at > now() - interval '1 minute') >= 15 then
    raise exception 'chat_trop_rapide';
  end if;
  if exists (select 1 from public.chat_messages where player_id = uid and created_at > now() - interval '30 seconds' and lower(body) = lower(b)) then
    raise exception 'message_repete';
  end if;
  if public._chat_filtered(b) then
    raise exception 'message_refuse';
  end if;
  insert into public.chat_messages (room, player_id, body) values (p_room, uid, b) returning id into new_id;
  return jsonb_build_object('id', new_id);
end $$;

-- ───────────────────────────── Lire ─────────────────────────────

-- Sans `p_after` : les derniers messages du salon. Avec `p_after` : ceux qui suivent ce numéro (interrogation régulière du jeu).
create function public.chat_fetch(p_room text, p_after bigint default 0, p_limit int default 60) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  lim int := least(greatest(coalesce(p_limit, 60), 1), 100);
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if not exists (select 1 from public.chat_rooms where id = p_room) then
    raise exception 'salon_inconnu';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.id) from (
      select m.id, m.player_id, p.pseudo, m.body, m.created_at,
             public.account_level(coalesce((select sum(x.amount) from public.xp_log x where x.player_id = m.player_id), 0)) as level,
             (select b.color from public.player_cosmetics c join public.badges b on b.id = c.color_badge where c.player_id = m.player_id) as color
        from public.chat_messages m
        join public.profiles p on p.id = m.player_id
       where m.room = p_room and m.deleted_at is null
         and (coalesce(p_after, 0) <= 0 or m.id > p_after)
         and not exists (select 1 from public.chat_blocks bl where bl.blocker_id = uid and bl.blocked_id = m.player_id)
       order by (case when coalesce(p_after, 0) > 0 then m.id else -m.id end)
       limit lim
    ) t), '[]'::jsonb);
end $$;

-- ───────────────────────────── Signaler, bloquer ─────────────────────────────

create function public.chat_report(p_message_id bigint, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if not exists (select 1 from public.chat_messages where id = p_message_id and deleted_at is null and player_id <> uid) then
    raise exception 'message_introuvable';
  end if;
  if (select count(*) from public.chat_reports where reporter_id = uid and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'trop_de_signalements';
  end if;
  insert into public.chat_reports (message_id, reporter_id, reason)
  values (p_message_id, uid, nullif(left(btrim(coalesce(p_reason, '')), 200), ''))
  on conflict (message_id, reporter_id) do nothing;
end $$;

create function public.chat_block(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if p_player is null or p_player = uid or not exists (select 1 from public.profiles where id = p_player) then
    raise exception 'joueur_inconnu';
  end if;
  insert into public.chat_blocks (blocker_id, blocked_id) values (uid, p_player) on conflict do nothing;
end $$;

create function public.chat_unblock(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  n int;
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  with d as (delete from public.chat_blocks where blocker_id = uid and blocked_id = p_player returning 1)
  select count(*) into n from d;
end $$;

create function public.chat_blocked() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('player_id', p.id, 'pseudo', p.pseudo) order by p.pseudo)
                     from public.chat_blocks bl join public.profiles p on p.id = bl.blocked_id where bl.blocker_id = uid), '[]'::jsonb);
end $$;

revoke all on function public.chat_send(text, text), public.chat_fetch(text, bigint, int), public.chat_report(bigint, text),
  public.chat_block(uuid), public.chat_unblock(uuid), public.chat_blocked() from public, anon;
grant execute on function public.chat_send(text, text), public.chat_fetch(text, bigint, int), public.chat_report(bigint, text),
  public.chat_block(uuid), public.chat_unblock(uuid), public.chat_blocked() to authenticated;

-- ───────────────────────────── Modération (super admin) ─────────────────────────────

-- Messages signalés (par défaut : ceux dont les signalements ne sont pas encore traités), le plus récemment signalé d'abord.
create function public.admin_chat_reports(p_include_handled boolean default false, p_limit int default 50) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.last_report desc) from (
      select m.id as message_id, m.room, m.body, m.created_at, (m.deleted_at is not null) as deleted,
             p.id as player_id, p.pseudo,
             count(r.id) as reports, max(r.created_at) as last_report,
             (select jsonb_agg(x.reason) from (select r2.reason from public.chat_reports r2
                where r2.message_id = m.id and r2.reason is not null order by r2.created_at limit 3) x) as reasons,
             (select cm.until from public.chat_mutes cm where cm.player_id = p.id and cm.until > now()) as muted_until
        from public.chat_reports r
        join public.chat_messages m on m.id = r.message_id
        join public.profiles p on p.id = m.player_id
       where p_include_handled or r.handled_at is null
       group by m.id, p.id
       order by max(r.created_at) desc
       limit least(greatest(p_limit, 1), 200)
    ) t), '[]'::jsonb);
end $$;

create function public.admin_chat_delete(p_message_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  update public.chat_messages set deleted_at = now(), deleted_by = (select auth.uid()) where id = p_message_id and deleted_at is null;
  update public.chat_reports set handled_at = now() where message_id = p_message_id and handled_at is null;
end $$;

create function public.admin_chat_dismiss(p_message_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  update public.chat_reports set handled_at = now() where message_id = p_message_id and handled_at is null;
end $$;

-- Réduit un joueur au silence pour `p_minutes` minutes (1 minute à 1 an) ; un super admin ne peut pas être coupé.
create function public.admin_chat_mute(p_player uuid, p_minutes int, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  if p_player is null or not exists (select 1 from public.profiles where id = p_player) or exists (select 1 from public.admins where player_id = p_player) then
    raise exception 'joueur_inconnu';
  end if;
  insert into public.chat_mutes (player_id, until, reason, muted_by)
  values (p_player, now() + make_interval(mins => least(greatest(coalesce(p_minutes, 60), 1), 525600)),
          nullif(left(btrim(coalesce(p_reason, '')), 200), ''), (select auth.uid()))
  on conflict (player_id) do update set until = excluded.until, reason = excluded.reason, muted_by = excluded.muted_by, created_at = now();
end $$;

create function public.admin_chat_unmute(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  with d as (delete from public.chat_mutes where player_id = p_player returning 1)
  select count(*) into n from d;
end $$;

create function public.admin_chat_words() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((select jsonb_agg(word order by word) from public.chat_words), '[]'::jsonb);
end $$;

create function public.admin_chat_word_add(p_word text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  w text := public._chat_norm(btrim(coalesce(p_word, '')));
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  if w !~ '^[a-z0-9][a-z0-9 ''-]*$' or char_length(w) not between 2 and 40 then
    raise exception 'mot_invalide';
  end if;
  insert into public.chat_words (word) values (w) on conflict do nothing;
end $$;

create function public.admin_chat_word_remove(p_word text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  with d as (delete from public.chat_words where word = public._chat_norm(btrim(coalesce(p_word, ''))) returning 1)
  select count(*) into n from d;
end $$;

create function public.admin_chat_stats() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return jsonb_build_object(
    'messages_24h', (select count(*) from public.chat_messages where created_at > now() - interval '24 hours'),
    'authors_24h', (select count(distinct player_id) from public.chat_messages where created_at > now() - interval '24 hours'),
    'messages_total', (select count(*) from public.chat_messages),
    'deleted_total', (select count(*) from public.chat_messages where deleted_at is not null),
    'reports_pending', (select count(distinct message_id) from public.chat_reports where handled_at is null),
    'mutes_active', (select count(*) from public.chat_mutes where until > now()),
    'blocks', (select count(*) from public.chat_blocks),
    'words', (select count(*) from public.chat_words));
end $$;

revoke all on function public.admin_chat_reports(boolean, int), public.admin_chat_delete(bigint), public.admin_chat_dismiss(bigint),
  public.admin_chat_mute(uuid, int, text), public.admin_chat_unmute(uuid), public.admin_chat_words(), public.admin_chat_word_add(text),
  public.admin_chat_word_remove(text), public.admin_chat_stats() from public, anon;
grant execute on function public.admin_chat_reports(boolean, int), public.admin_chat_delete(bigint), public.admin_chat_dismiss(bigint),
  public.admin_chat_mute(uuid, int, text), public.admin_chat_unmute(uuid), public.admin_chat_words(), public.admin_chat_word_add(text),
  public.admin_chat_word_remove(text), public.admin_chat_stats() to authenticated;

-- ───────────────────────────── Conservation (vérificateur) ─────────────────────────────

-- Messages de plus de 30 jours et silences expirés depuis plus de 30 jours ; renvoie le nombre de messages supprimés.
create function public.chat_purge_old() returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
  m int;
begin
  with d as (delete from public.chat_messages where created_at < now() - interval '30 days' returning 1)
  select count(*) into n from d;
  with d as (delete from public.chat_mutes where until < now() - interval '30 days' returning 1)
  select count(*) into m from d;
  return n;
end $$;
revoke all on function public.chat_purge_old() from public, anon, authenticated;
grant execute on function public.chat_purge_old() to service_role;
