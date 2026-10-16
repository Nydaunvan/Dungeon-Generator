-- Dungeon Generator — présence des joueurs : « connecté ou non » et date de la dernière connexion, visibles dans l'administration.
--
-- Le jeu envoie un signal à la connexion (`login`), puis toutes les minutes tant qu'il est ouvert (`ping`), et à la déconnexion
-- (`logout`). Un joueur est « en ligne » tant que `online_until` est dans le futur : un signal le repousse de 150 s, donc un jeu
-- fermé brutalement (plantage, coupure réseau) repasse hors ligne tout seul en moins de 3 minutes.
-- La table n'a AUCUNE politique : illisible et inscriptible depuis le jeu ; seules les fonctions ci-dessous y touchent.

create table public.player_presence (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  last_login timestamptz,                         -- dernière connexion au jeu
  last_seen timestamptz not null default now(),   -- dernier signal reçu
  online_until timestamptz not null default now() -- en ligne tant que cette date n'est pas dépassée
);
alter table public.player_presence enable row level security;

-- Signal de présence du joueur connecté. p_event : 'login' | 'ping' | 'logout'.
create function public.presence_ping(p_event text default 'ping') returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    raise exception 'non_connecte';
  end if;
  if p_event not in ('login', 'ping', 'logout') then
    raise exception 'valeur_invalide';
  end if;
  if not exists (select 1 from public.profiles where id = me) then
    return;
  end if;
  insert into public.player_presence (player_id, last_login, last_seen, online_until)
  values (me,
          case when p_event = 'login' then now() end,
          now(),
          case when p_event = 'logout' then now() else now() + interval '150 seconds' end)
  on conflict (player_id) do update set
    last_login = case when p_event = 'login' then now() else public.player_presence.last_login end,
    last_seen = now(),
    online_until = case when p_event = 'logout' then now() else now() + interval '150 seconds' end;
end $$;
revoke all on function public.presence_ping(text) from public, anon;
grant execute on function public.presence_ping(text) to authenticated;

-- Liste des joueurs : ajoute `online`, `last_login` et `last_seen`.
create or replace function public.admin_players(p_search text default '', p_limit int default 50, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t)) from (
      select p.id, p.pseudo, p.created_at,
             coalesce(x.xp, 0)::int as xp,
             public.account_level(coalesce(x.xp, 0)) as level,
             (select count(*) from public.ranked_runs r where r.player_id = p.id and not r.test) as runs,
             (select count(*) from public.ranked_runs r where r.player_id = p.id and not r.test and r.status = 'verified') as verified,
             (select max(r.score) from public.ranked_runs r where r.player_id = p.id and not r.test and r.status = 'verified') as best_score,
             (select max(r.started_at) from public.ranked_runs r where r.player_id = p.id and not r.test) as last_run_at,
             (select count(*) from public.player_badges b where b.player_id = p.id) as badges,
             public.staff_rank(p.id) >= 2 as admin,
             (select s.role from public.staff_roles s where s.player_id = p.id) as role,
             exists (select 1 from public.chat_mutes m where m.player_id = p.id and m.until > now()) as muted,
             exists (select 1 from public.gallery_bans b where b.player_id = p.id) as gallery_banned,
             public.account_banned(p.id) as banned,
             coalesce(pp.online_until > now(), false) as online,
             pp.last_login,
             pp.last_seen
        from public.profiles p
        left join (select player_id, sum(amount) as xp from public.xp_log group by player_id) x on x.player_id = p.id
        left join public.player_presence pp on pp.player_id = p.id
       where coalesce(p_search, '') = '' or position(lower(p_search) in lower(p.pseudo)) > 0
       order by coalesce(pp.online_until > now(), false) desc, p.created_at desc
       limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)
    ) t), '[]'::jsonb);
end $$;

-- Fiche d'un joueur : ajoute `online`, `last_login` et `last_seen`.
create or replace function public.admin_player_card(p_player uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  if not exists (select 1 from public.profiles where id = p_player) then
    raise exception 'joueur_inconnu';
  end if;
  return jsonb_build_object(
    'player_id', p_player,
    'pseudo', (select pseudo from public.profiles where id = p_player),
    'created_at', (select created_at from public.profiles where id = p_player),
    'online', coalesce((select online_until > now() from public.player_presence where player_id = p_player), false),
    'last_login', (select last_login from public.player_presence where player_id = p_player),
    'last_seen', (select last_seen from public.player_presence where player_id = p_player),
    'role', (select role from public.staff_roles where player_id = p_player),
    'rank', public.staff_rank(p_player),
    'mute', (select jsonb_build_object('until', until, 'reason', reason) from public.chat_mutes where player_id = p_player and until > now()),
    'gallery_ban', (select jsonb_build_object('reason', reason, 'since', created_at) from public.gallery_bans where player_id = p_player),
    'account_ban', (select jsonb_build_object('until', until, 'reason', reason, 'since', created_at)
                      from public.account_bans where player_id = p_player and (until is null or until > now())),
    'messages', coalesce((select jsonb_agg(to_jsonb(m)) from (
        select id, room, body, created_at, (deleted_at is not null) as deleted
          from public.chat_messages where player_id = p_player and to_player is null order by id desc limit 15) m), '[]'::jsonb),
    'history', coalesce((select jsonb_agg(to_jsonb(h)) from (
        select l.action, l.detail, l.created_at, a.pseudo as actor_pseudo
          from public.staff_log l left join public.profiles a on a.id = l.actor
         where l.target = p_player order by l.id desc limit 10) h), '[]'::jsonb));
end $$;

-- Les droits d'exécution des deux fonctions remplacées sont conservés (create or replace) ; on les réaffirme par prudence.
revoke all on function public.admin_players(text, int, int), public.admin_player_card(uuid) from public, anon;
grant execute on function public.admin_players(text, int, int), public.admin_player_card(uuid) to authenticated;
