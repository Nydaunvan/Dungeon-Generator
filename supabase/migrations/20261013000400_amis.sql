-- Dungeon Generator — liste d'amis : demandes d'ami (envoyer, accepter, refuser, annuler), retirer un ami, état en ligne des amis.
--
-- Une ligne par couple de joueurs (dans un sens ou dans l'autre) : « pending » tant que le destinataire n'a pas répondu, « accepted »
-- ensuite. Refuser, annuler ou retirer SUPPRIME la ligne (aucune trace, on peut redemander plus tard). Les tables n'ont AUCUNE politique :
-- tout passe par les fonctions ci-dessous, qui revérifient le joueur connecté côté serveur.
--  * Un joueur bloqué (tchat) ne peut ni demander ni recevoir de demande ; bloquer un joueur supprime l'amitié et les demandes en cours.
--  * Chacun peut fermer ses demandes d'ami (friend_set_open).
--  * Limites : 100 amis, 30 demandes envoyées en attente, 20 demandes par jour.
--  * L'état en ligne et la dernière connexion (player_presence) ne sont visibles que par les amis acceptés.

create table public.friendships (
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);
-- un seul lien par couple, quel que soit le sens
create unique index friendships_pair_idx on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index friendships_addressee_idx on public.friendships (addressee_id, status);
alter table public.friendships enable row level security;       -- aucune politique : invisible depuis l'API

create table public.friend_prefs (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  requests_open boolean not null default true
);
alter table public.friend_prefs enable row level security;

-- Bloquer un joueur défait l'amitié et les demandes entre les deux.
create function public._friends_on_block() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.friendships
   where (requester_id = new.blocker_id and addressee_id = new.blocked_id)
      or (requester_id = new.blocked_id and addressee_id = new.blocker_id);
  return new;
end $$;
create trigger friends_on_block after insert on public.chat_blocks for each row execute function public._friends_on_block();

create function public._friend_blocked(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.chat_blocks
                  where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;

create function public._friend_count(p uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.friendships where status = 'accepted' and (requester_id = p or addressee_id = p)
$$;

revoke all on function public._friends_on_block(), public._friend_blocked(uuid, uuid), public._friend_count(uuid) from public, anon, authenticated;

-- Demande d'ami (cœur commun). Renvoie 'sent' (demande envoyée) ou 'accepted' (l'autre avait déjà demandé : amitié créée).
create function public._friend_send(uid uuid, target uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  f public.friendships%rowtype;
begin
  if target is null or not exists (select 1 from public.profiles where id = target) then
    raise exception 'joueur_inconnu';
  end if;
  if target = uid then
    raise exception 'pas_soi_meme';
  end if;
  if public._friend_blocked(uid, target) then
    raise exception 'ami_impossible';
  end if;
  select * into f from public.friendships
   where (requester_id = uid and addressee_id = target) or (requester_id = target and addressee_id = uid);
  if found then
    if f.status = 'accepted' then
      raise exception 'deja_ami';
    elsif f.requester_id = uid then
      raise exception 'demande_deja_envoyee';
    end if;
    -- l'autre joueur nous avait déjà demandé : on accepte
    if public._friend_count(uid) >= 100 then
      raise exception 'trop_d_amis';
    end if;
    if public._friend_count(target) >= 100 then
      raise exception 'destinataire_indisponible';
    end if;
    update public.friendships set status = 'accepted', responded_at = now() where requester_id = target and addressee_id = uid;
    return 'accepted';
  end if;
  if not coalesce((select requests_open from public.friend_prefs where player_id = target), true) then
    raise exception 'demandes_fermees';
  end if;
  if public._friend_count(uid) >= 100 then
    raise exception 'trop_d_amis';
  end if;
  if (select count(*) from public.friendships where requester_id = uid and status = 'pending') >= 30
     or (select count(*) from public.friendships where requester_id = uid and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'trop_de_demandes';
  end if;
  insert into public.friendships (requester_id, addressee_id) values (uid, target);
  return 'sent';
end $$;
revoke all on function public._friend_send(uuid, uuid) from public, anon, authenticated;

create function public.friend_request(p_player uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  return public._friend_send(uid, p_player);
end $$;

-- Même chose en tapant le pseudo (sans tenir compte des majuscules).
create function public.friend_request_pseudo(p_pseudo text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  target uuid;
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  select id into target from public.profiles where lower(pseudo) = lower(btrim(coalesce(p_pseudo, '')));
  return public._friend_send(uid, target);
end $$;

-- Accepter une demande reçue.
create function public.friend_accept(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if not exists (select 1 from public.friendships where requester_id = p_player and addressee_id = uid and status = 'pending') then
    raise exception 'demande_introuvable';
  end if;
  if public._friend_blocked(uid, p_player) then
    raise exception 'ami_impossible';
  end if;
  if public._friend_count(uid) >= 100 then
    raise exception 'trop_d_amis';
  end if;
  if public._friend_count(p_player) >= 100 then
    raise exception 'destinataire_indisponible';
  end if;
  update public.friendships set status = 'accepted', responded_at = now()
   where requester_id = p_player and addressee_id = uid and status = 'pending';
end $$;

-- Refuser une demande reçue.
create function public.friend_decline(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  n int;
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  with d as (delete from public.friendships where requester_id = p_player and addressee_id = uid and status = 'pending' returning 1)
  select count(*) into n from d;
  if n = 0 then
    raise exception 'demande_introuvable';
  end if;
end $$;

-- Annuler une demande envoyée.
create function public.friend_cancel(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  n int;
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  with d as (delete from public.friendships where requester_id = uid and addressee_id = p_player and status = 'pending' returning 1)
  select count(*) into n from d;
  if n = 0 then
    raise exception 'demande_introuvable';
  end if;
end $$;

-- Retirer un ami (l'autre n'est pas prévenu).
create function public.friend_remove(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  delete from public.friendships
   where status = 'accepted'
     and ((requester_id = uid and addressee_id = p_player) or (requester_id = p_player and addressee_id = uid));
end $$;

-- Accepter ou non les demandes d'ami.
create function public.friend_set_open(p_open boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  insert into public.friend_prefs (player_id, requests_open) values (uid, coalesce(p_open, true))
  on conflict (player_id) do update set requests_open = excluded.requests_open;
end $$;

-- Tout l'écran : {requests_open, friends: [{player_id, pseudo, level, online, last_login, since}],
--                 incoming: [{player_id, pseudo, level, at}], outgoing: [{player_id, pseudo, level, at}]}
create function public.friend_list() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  return jsonb_build_object(
    'requests_open', coalesce((select requests_open from public.friend_prefs where player_id = uid), true),
    'friends', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.online desc, lower(t.pseudo)) from (
        select p.id as player_id, p.pseudo,
               public.account_level(coalesce((select sum(amount) from public.xp_log x where x.player_id = p.id), 0)) as level,
               coalesce(pp.online_until > now(), false) as online,
               pp.last_login,
               f.responded_at as since
          from public.friendships f
          join public.profiles p on p.id = case when f.requester_id = uid then f.addressee_id else f.requester_id end
          left join public.player_presence pp on pp.player_id = p.id
         where f.status = 'accepted' and (f.requester_id = uid or f.addressee_id = uid)
           and not public._friend_blocked(uid, p.id)
      ) t), '[]'::jsonb),
    'incoming', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.at desc) from (
        select p.id as player_id, p.pseudo,
               public.account_level(coalesce((select sum(amount) from public.xp_log x where x.player_id = p.id), 0)) as level,
               f.created_at as at
          from public.friendships f join public.profiles p on p.id = f.requester_id
         where f.status = 'pending' and f.addressee_id = uid and not public._friend_blocked(uid, p.id)
      ) t), '[]'::jsonb),
    'outgoing', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.at desc) from (
        select p.id as player_id, p.pseudo,
               public.account_level(coalesce((select sum(amount) from public.xp_log x where x.player_id = p.id), 0)) as level,
               f.created_at as at
          from public.friendships f join public.profiles p on p.id = f.addressee_id
         where f.status = 'pending' and f.requester_id = uid and not public._friend_blocked(uid, p.id)
      ) t), '[]'::jsonb));
end $$;

-- Nombre de demandes reçues en attente (pastille de l'onglet Amis).
create function public.friend_pending_count() returns int
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  return (select count(*)::int from public.friendships f
           where f.addressee_id = uid and f.status = 'pending' and not public._friend_blocked(uid, f.requester_id));
end $$;

do $$
declare f text;
begin
  foreach f in array array['friend_request(uuid)', 'friend_request_pseudo(text)', 'friend_accept(uuid)', 'friend_decline(uuid)',
                           'friend_cancel(uuid)', 'friend_remove(uuid)', 'friend_set_open(boolean)', 'friend_list()', 'friend_pending_count()']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
