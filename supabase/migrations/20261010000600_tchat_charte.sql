-- Charte du tchat : chaque compte doit l'avoir acceptée (dans sa version courante) pour lire et écrire.
-- Pour la faire évoluer : changer le numéro renvoyé par chat_charte_version() ; chacun la revoit alors une fois.
-- L'acceptation est enregistrée côté serveur (elle vaut sur tous les appareils) ; le jeu ne fait qu'afficher le texte.

create table public.chat_charte (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  version int not null,
  accepted_at timestamptz not null default now()
);
alter table public.chat_charte enable row level security;

create function public.chat_charte_version() returns int
language sql immutable set search_path = '' as $$ select 1 $$;

create function public._chat_charte_ok(p_uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.chat_charte c where c.player_id = p_uid and c.version >= public.chat_charte_version())
$$;
revoke all on function public._chat_charte_ok(uuid) from public, anon, authenticated;

-- État du compte : version à accepter et version acceptée (0 = jamais).
create function public.chat_charte_etat() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  return jsonb_build_object('version', public.chat_charte_version(),
    'accepted', coalesce((select c.version from public.chat_charte c where c.player_id = uid), 0));
end $$;

-- Accepter la version affichée (refusée si ce n'est plus la version courante : le joueur doit relire).
create function public.chat_charte_accepter(p_version int) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if p_version is distinct from public.chat_charte_version() then
    raise exception 'charte_obsolete';
  end if;
  insert into public.chat_charte (player_id, version) values (uid, p_version)
  on conflict (player_id) do update set version = excluded.version, accepted_at = now();
end $$;

revoke all on function public.chat_charte_etat(), public.chat_charte_accepter(int) from public, anon;
grant execute on function public.chat_charte_etat(), public.chat_charte_accepter(int) to authenticated;
grant execute on function public.chat_charte_version() to authenticated;

-- Lecture et écriture exigent la charte.
create or replace function public.chat_send(p_room text, p_body text) returns jsonb
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
  -- caractères de commande et de direction du texte retirés, espaces réduits
  b := btrim(regexp_replace(regexp_replace(p_body, '[[:cntrl:]\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]', ' ', 'g'), ' {2,}', ' ', 'g'));
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

create or replace function public.chat_fetch(p_room text, p_after bigint default 0, p_limit int default 60) returns jsonb
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
