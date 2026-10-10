-- Dungeon Generator — messages privés entre joueurs + compteur de messages non lus (bulle rouge).
--
-- Les messages privés vivent dans chat_messages (room = null, to_player = destinataire) : mêmes règles que les salons (longueur, débit,
-- doublons, mots interdits, silence, charte). Seuls l'expéditeur et le destinataire les lisent. Un joueur bloqué ne peut plus écrire à
-- celui qui l'a bloqué ; chacun peut fermer ses messages privés (chat_prefs) ; 20 nouveaux correspondants par jour au plus.
-- Un message privé reçu peut être signalé au super admin comme n'importe quel message.

alter table public.chat_messages alter column room drop not null;
alter table public.chat_messages add column if not exists to_player uuid references public.profiles (id) on delete cascade;
alter table public.chat_messages add constraint chat_messages_prive_coherent check ((room is null) = (to_player is not null) );
create index if not exists chat_messages_dm_idx on public.chat_messages (to_player, id desc) where to_player is not null and deleted_at is null;

create table if not exists public.chat_prefs (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  dm_open boolean not null default true
);
alter table public.chat_prefs enable row level security;

-- Dernier message lu par salon (« general », « fr », « en ») ou par conversation (« dm:<id du correspondant> »).
create table if not exists public.chat_reads (
  player_id uuid not null references public.profiles (id) on delete cascade,
  scope text not null check (scope ~ '^(general|fr|en|dm:[0-9a-f-]{36})$'),
  last_id bigint not null default 0,
  primary key (player_id, scope)
);
alter table public.chat_reads enable row level security;

-- Les salons ne montrent jamais un message privé (room est null, donc jamais égal au salon demandé) : rien à changer à chat_fetch.

create or replace function public.chat_report(p_message_id bigint, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if not exists (select 1 from public.chat_messages where id = p_message_id and deleted_at is null and player_id <> uid and (to_player is null or to_player = uid)) then
    raise exception 'message_introuvable';
  end if;
  if (select count(*) from public.chat_reports where reporter_id = uid and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'trop_de_signalements';
  end if;
  insert into public.chat_reports (message_id, reporter_id, reason)
  values (p_message_id, uid, nullif(left(btrim(coalesce(p_reason, '')), 200), ''))
  on conflict (message_id, reporter_id) do nothing;
end $$;

create or replace function public.chat_send_dm(p_to uuid, p_body text) returns jsonb
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
  if not public._chat_charte_ok(uid) then
    raise exception 'charte_non_acceptee';
  end if;
  if p_body is null or char_length(p_body) > 1000 then
    raise exception 'message_trop_long';
  end if;
  b := btrim(regexp_replace(regexp_replace(p_body, '[[:cntrl:]​-‏‪-‮⁦-⁩﻿]', ' ', 'g'), ' {2,}', ' ', 'g'));
  if char_length(b) = 0 then
    raise exception 'message_vide';
  end if;
  if char_length(b) > 300 then
    raise exception 'message_trop_long';
  end if;
  if p_to is null or p_to = uid or not exists (select 1 from public.profiles where id = p_to) then
    raise exception 'destinataire_indisponible';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));
  select * into mute from public.chat_mutes where player_id = uid and until > now();
  if found then
    raise exception 'chat_mute' using hint = mute.until::text;
  end if;
  if exists (select 1 from public.chat_blocks where (blocker_id = p_to and blocked_id = uid) or (blocker_id = uid and blocked_id = p_to))
     or exists (select 1 from public.chat_prefs where player_id = p_to and not dm_open) then
    raise exception 'destinataire_indisponible';
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
  -- anti-démarchage : 20 nouveaux correspondants par jour au plus
  if not exists (select 1 from public.chat_messages where player_id = uid and to_player = p_to)
     and (select count(distinct to_player) from public.chat_messages where player_id = uid and to_player is not null and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'trop_de_destinataires';
  end if;
  insert into public.chat_messages (room, to_player, player_id, body) values (null, p_to, uid, b) returning id into new_id;
  return jsonb_build_object('id', new_id);
end $$;

-- Conversation avec un joueur : sans `p_after`, les derniers messages ; avec `p_after`, ceux qui suivent ce numéro.
create or replace function public.chat_fetch_dm(p_with uuid, p_after bigint default 0, p_limit int default 60) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  lim int := least(greatest(coalesce(p_limit, 60), 1), 100);
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if not public._chat_charte_ok(uid) then
    raise exception 'charte_non_acceptee';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.id) from (
      select m.id, m.player_id, p.pseudo, m.body, m.created_at,
             public.account_level(coalesce((select sum(x.amount) from public.xp_log x where x.player_id = m.player_id), 0)) as level,
             (select b.color from public.player_cosmetics c join public.badges b on b.id = c.color_badge where c.player_id = m.player_id) as color
        from public.chat_messages m
        join public.profiles p on p.id = m.player_id
       where m.room is null and m.deleted_at is null
         and ((m.player_id = uid and m.to_player = p_with) or (m.player_id = p_with and m.to_player = uid))
         and (coalesce(p_after, 0) <= 0 or m.id > p_after)
         and not exists (select 1 from public.chat_blocks bl where bl.blocker_id = uid and bl.blocked_id = p_with)
       order by (case when coalesce(p_after, 0) > 0 then m.id else -m.id end)
       limit lim
    ) t), '[]'::jsonb);
end $$;

-- Liste des conversations, la plus récente d'abord : correspondant, dernier message, nombre de messages non lus.
create or replace function public.chat_conversations() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if not public._chat_charte_ok(uid) then
    raise exception 'charte_non_acceptee';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.last_id desc) from (
      select c.peer as player_id, p.pseudo, c.last_id,
             (select m.body from public.chat_messages m where m.id = c.last_id) as body,
             (select m.created_at from public.chat_messages m where m.id = c.last_id) as created_at,
             (select m.player_id = uid from public.chat_messages m where m.id = c.last_id) as mine,
             (select count(*) from public.chat_messages m
               where m.room is null and m.deleted_at is null and m.player_id = c.peer and m.to_player = uid
                 and m.id > coalesce((select r.last_id from public.chat_reads r where r.player_id = uid and r.scope = 'dm:' || c.peer::text), 0))::int as unread
        from (
          select case when m.player_id = uid then m.to_player else m.player_id end as peer, max(m.id) as last_id
            from public.chat_messages m
           where m.room is null and m.deleted_at is null and (m.player_id = uid or m.to_player = uid)
           group by 1
        ) c
        join public.profiles p on p.id = c.peer
       where not exists (select 1 from public.chat_blocks bl where bl.blocker_id = uid and bl.blocked_id = c.peer)
       order by c.last_id desc
       limit 50
    ) t), '[]'::jsonb);
end $$;

create or replace function public.chat_mark_read(p_scope text, p_last_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if p_scope is null or p_scope !~ '^(general|fr|en|dm:[0-9a-f-]{36})$' or coalesce(p_last_id, 0) < 0 then
    raise exception 'salon_inconnu';
  end if;
  insert into public.chat_reads (player_id, scope, last_id) values (uid, p_scope, p_last_id)
  on conflict (player_id, scope) do update set last_id = greatest(public.chat_reads.last_id, excluded.last_id);
end $$;

-- Bulle rouge : messages privés non lus et nouveaux messages des salons depuis la dernière visite. Un salon jamais ouvert ne compte pas.
create or replace function public.chat_unread() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  dm int;
  rooms jsonb;
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if not public._chat_charte_ok(uid) then
    return jsonb_build_object('dm', 0, 'rooms', '{}'::jsonb, 'total', 0);
  end if;
  select count(*)::int into dm
    from public.chat_messages m
   where m.room is null and m.deleted_at is null and m.to_player = uid
     and m.id > coalesce((select r.last_id from public.chat_reads r where r.player_id = uid and r.scope = 'dm:' || m.player_id::text), 0)
     and not exists (select 1 from public.chat_blocks bl where bl.blocker_id = uid and bl.blocked_id = m.player_id);
  select coalesce(jsonb_object_agg(r.scope, n), '{}'::jsonb) into rooms from (
    select r.scope, (select count(*) from public.chat_messages m
       where m.room = r.scope and m.deleted_at is null and m.player_id <> uid and m.id > r.last_id
         and not exists (select 1 from public.chat_blocks bl where bl.blocker_id = uid and bl.blocked_id = m.player_id))::int as n
      from public.chat_reads r where r.player_id = uid and r.scope in ('general', 'fr', 'en')
  ) r;
  return jsonb_build_object('dm', dm, 'rooms', rooms,
    'total', dm + coalesce((select sum(v::int) from jsonb_each_text(rooms) e(k, v)), 0)::int);
end $$;

create or replace function public.chat_dm_open() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select dm_open from public.chat_prefs where player_id = (select auth.uid())), true);
$$;

create or replace function public.chat_set_dm(p_open boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  insert into public.chat_prefs (player_id, dm_open) values (uid, coalesce(p_open, true))
  on conflict (player_id) do update set dm_open = excluded.dm_open;
end $$;

revoke all on function public.chat_send_dm(uuid, text), public.chat_fetch_dm(uuid, bigint, int), public.chat_conversations(),
  public.chat_mark_read(text, bigint), public.chat_unread(), public.chat_dm_open(), public.chat_set_dm(boolean) from public, anon;
grant execute on function public.chat_send_dm(uuid, text), public.chat_fetch_dm(uuid, bigint, int), public.chat_conversations(),
  public.chat_mark_read(text, bigint), public.chat_unread(), public.chat_dm_open(), public.chat_set_dm(boolean) to authenticated;
