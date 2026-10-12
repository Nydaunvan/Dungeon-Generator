-- Dungeon Generator — équipe d'administration : rôles (modérateur / super admin / développeur), nominations, journal des actions,
-- bannissement de compte, annonce globale, mode maintenance, réinitialisation d'un classement, santé du serveur.
--
-- Hiérarchie :  développeur (3) > super admin (2) > modérateur (1) > joueur (0).
--  * seul le développeur nomme / retire un super admin ; un super admin nomme / retire des modérateurs ; un modérateur ne nomme personne ;
--  * personne ne peut toucher un rôle supérieur ou égal au sien, ni son propre rôle ; le rôle « développeur » ne se modifie QUE par SQL
--    depuis le tableau de bord Supabase (verrouillé depuis le jeu) ;
--  * un sanctionneur ne peut sanctionner (silence, interdiction de publier) qu'un compte de rang strictement inférieur au sien ;
--  * toutes les fonctions revérifient le rôle CÔTÉ SERVEUR ; la table des rôles est illisible depuis l'API.

-- ───────────────────────────── Rôles ─────────────────────────────

create table public.staff_roles (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  role text not null check (role in ('moderator', 'super_admin', 'dev')),
  granted_by uuid references public.profiles (id) on delete set null,
  granted_at timestamptz not null default now()
);
alter table public.staff_roles enable row level security;          -- aucune politique : invisible depuis l'API
revoke all on public.staff_roles from public, anon, authenticated;

-- Reprise de l'existant : les anciens admins deviennent super admins.
insert into public.staff_roles (player_id, role, granted_at)
select player_id, 'super_admin', granted_at from public.admins on conflict do nothing;

-- Le développeur du jeu : le plus ancien compte de pseudo « Nydaunvan ».
insert into public.staff_roles (player_id, role)
select id, 'dev' from public.profiles where lower(pseudo) = 'nydaunvan' order by created_at limit 1
on conflict (player_id) do update set role = 'dev', granted_by = null;

-- Le rôle « développeur » est verrouillé : aucune modification possible depuis le jeu (auth.uid() non nul), seulement par SQL.
create function public._staff_dev_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is not null
     and ((tg_op <> 'INSERT' and old.role = 'dev') or (tg_op <> 'DELETE' and new.role = 'dev')) then
    raise exception 'acces_refuse';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
create trigger staff_roles_dev_garde before insert or update or delete on public.staff_roles
  for each row execute function public._staff_dev_garde();

-- L'ancienne table devient une vue illisible depuis l'API (les anciennes fonctions s'en servent encore pour « est un admin »).
drop table public.admins;
create view public.admins with (security_invoker = on) as
  select player_id, granted_at from public.staff_roles where role in ('super_admin', 'dev');
revoke all on public.admins from public, anon, authenticated;

create function public.staff_rank(p uuid) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce((select case role when 'dev' then 3 when 'super_admin' then 2 when 'moderator' then 1 end
                     from public.staff_roles where player_id = p), 0)
$$;
revoke all on function public.staff_rank(uuid) from public, anon, authenticated;

create function public.staff_role() returns text
language sql stable security definer set search_path = '' as $$
  select role from public.staff_roles where player_id = (select auth.uid())
$$;
create function public.is_staff() returns boolean
language sql stable security definer set search_path = '' as $$ select public.staff_rank((select auth.uid())) >= 1 $$;
create function public.is_dev() returns boolean
language sql stable security definer set search_path = '' as $$ select public.staff_rank((select auth.uid())) >= 3 $$;
create or replace function public.is_super_admin() returns boolean
language sql stable security definer set search_path = '' as $$ select public.staff_rank((select auth.uid())) >= 2 $$;
revoke all on function public.staff_role(), public.is_staff(), public.is_dev(), public.is_super_admin() from public, anon;
grant execute on function public.staff_role(), public.is_staff(), public.is_dev(), public.is_super_admin() to authenticated;

-- ───────────────────────────── Journal des actions ─────────────────────────────

create table public.staff_log (
  id bigserial primary key,
  actor uuid references public.profiles (id) on delete set null,
  action text not null,
  target uuid references public.profiles (id) on delete set null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index staff_log_created_idx on public.staff_log (created_at desc);
create index staff_log_actor_idx on public.staff_log (actor, created_at desc);
alter table public.staff_log enable row level security;
revoke all on public.staff_log from public, anon, authenticated;

create function public._staff_log_add(p_action text, p_target uuid, p_detail jsonb default '{}'::jsonb) returns void
language sql security definer set search_path = '' as $$
  insert into public.staff_log (actor, action, target, detail) values ((select auth.uid()), p_action, p_target, coalesce(p_detail, '{}'::jsonb))
$$;
revoke all on function public._staff_log_add(text, uuid, jsonb) from public, anon, authenticated;

-- Journalise les actions de l'équipe faites sur les tables de modération (seulement si l'auteur est de l'équipe).
create function public._staff_audit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
begin
  if actor is null or not public.is_staff() then
    return coalesce(new, old);
  end if;
  case tg_table_name
    when 'chat_mutes' then
      if tg_op = 'DELETE' then
        perform public._staff_log_add('chat_unmute', old.player_id);
      else
        perform public._staff_log_add('chat_mute', new.player_id, jsonb_build_object('until', new.until, 'reason', new.reason));
      end if;
    when 'chat_messages' then
      if old.deleted_at is null and new.deleted_at is not null then
        perform public._staff_log_add('chat_delete', new.player_id, jsonb_build_object('message', new.id, 'body', left(new.body, 200)));
      end if;
    when 'chat_words' then
      perform public._staff_log_add(case tg_op when 'DELETE' then 'chat_word_remove' else 'chat_word_add' end, null,
        jsonb_build_object('word', coalesce(new.word, old.word)));
    when 'gallery_bans' then
      if tg_op = 'DELETE' then
        perform public._staff_log_add('gallery_unban', old.player_id);
      else
        perform public._staff_log_add('gallery_ban', new.player_id, jsonb_build_object('reason', new.reason));
      end if;
    when 'dungeons' then
      if tg_op = 'DELETE' then
        if old.owner_id <> actor then
          perform public._staff_log_add('gallery_delete', old.owner_id, jsonb_build_object('title', old.title, 'dungeon', old.id));
        end if;
      elsif new.owner_id <> actor and not exists (select 1 from public.gallery_bans b where b.player_id = new.owner_id)
            and not public.account_banned(new.owner_id) then
        perform public._staff_log_add('gallery_unpublish', new.owner_id, jsonb_build_object('title', new.title, 'dungeon', new.id));
      end if;
    when 'staff_roles' then
      if tg_op = 'DELETE' then
        perform public._staff_log_add('role_remove', old.player_id, jsonb_build_object('role', old.role));
      else
        perform public._staff_log_add('role_set', new.player_id,
          jsonb_build_object('role', new.role, 'previous', case when tg_op = 'UPDATE' then old.role end));
      end if;
    when 'account_bans' then
      if tg_op = 'DELETE' then
        perform public._staff_log_add('account_unban', old.player_id);
      else
        perform public._staff_log_add('account_ban', new.player_id, jsonb_build_object('until', new.until, 'reason', new.reason));
      end if;
    else
      null;
  end case;
  return coalesce(new, old);
end $$;
revoke all on function public._staff_audit() from public, anon, authenticated;

-- ───────────────────────────── Bannissement de compte (développeur) ─────────────────────────────

create table public.account_bans (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  reason text,
  until timestamptz,                       -- null = définitif
  banned_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.account_bans enable row level security;
revoke all on public.account_bans from public, anon, authenticated;

create function public.account_banned(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.account_bans b where b.player_id = p and (b.until is null or b.until > now()))
$$;
revoke all on function public.account_banned(uuid) from public, anon, authenticated;

-- Un compte banni ne peut plus lancer de partie classée (les parties de test, réservées à l'équipe, restent possibles).
create function public._ranked_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not new.test then
    if public.account_banned(new.player_id) then
      raise exception 'compte_banni';
    end if;
    if (select ranked_closed from public.server_state where id = 1) then
      raise exception 'maintenance';
    end if;
  end if;
  return new;
end $$;

-- Tchat : fermé pendant la maintenance (sauf pour l'équipe).
create function public._chat_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select chat_closed from public.server_state where id = 1) and not public.is_staff() then
    raise exception 'tchat_ferme';
  end if;
  return new;
end $$;

-- La publication en galerie est aussi interdite aux comptes bannis.
create or replace function public.dungeons_ban_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_public and (exists (select 1 from public.gallery_bans b where b.player_id = new.owner_id) or public.account_banned(new.owner_id)) then
    raise exception 'publication_interdite';
  end if;
  return new;
end $$;

-- ───────────────────────────── Maintenance ─────────────────────────────

create table public.server_state (
  id int primary key default 1 check (id = 1),
  ranked_closed boolean not null default false,
  chat_closed boolean not null default false,
  message text,
  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.server_state (id) values (1);
alter table public.server_state enable row level security;
revoke all on public.server_state from public, anon, authenticated;

create trigger ranked_runs_garde before insert on public.ranked_runs for each row execute function public._ranked_garde();
create trigger chat_messages_garde before insert on public.chat_messages for each row execute function public._chat_garde();

-- État public (lu par le jeu au démarrage).
create function public.server_state_get() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('ranked_closed', ranked_closed, 'chat_closed', chat_closed, 'message', message) from public.server_state where id = 1
$$;
revoke all on function public.server_state_get() from public;
grant execute on function public.server_state_get() to anon, authenticated;

-- ───────────────────────────── Annonces ─────────────────────────────

create table public.announcements (
  id bigserial primary key,
  body text not null check (char_length(body) between 1 and 400),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
alter table public.announcements enable row level security;
revoke all on public.announcements from public, anon, authenticated;

create function public.announcement_current() returns jsonb
language sql stable security definer set search_path = '' as $$
  select (select jsonb_build_object('id', a.id, 'body', a.body, 'created_at', a.created_at, 'expires_at', a.expires_at)
            from public.announcements a where a.expires_at > now() order by a.id desc limit 1)
$$;
revoke all on function public.announcement_current() from public;
grant execute on function public.announcement_current() to anon, authenticated;

-- ───────────────────────────── Journalisation : déclencheurs ─────────────────────────────

create trigger chat_mutes_audit after insert or update or delete on public.chat_mutes for each row execute function public._staff_audit();
create trigger chat_messages_audit after update of deleted_at on public.chat_messages for each row
  when (old.deleted_at is null and new.deleted_at is not null) execute function public._staff_audit();
create trigger chat_words_audit after insert or delete on public.chat_words for each row execute function public._staff_audit();
create trigger gallery_bans_audit after insert or update or delete on public.gallery_bans for each row execute function public._staff_audit();
create trigger dungeons_audit_unpublish after update of is_public on public.dungeons for each row
  when (old.is_public and not new.is_public) execute function public._staff_audit();
create trigger dungeons_audit_delete after delete on public.dungeons for each row execute function public._staff_audit();
create trigger staff_roles_audit after insert or update or delete on public.staff_roles for each row execute function public._staff_audit();
create trigger account_bans_audit after insert or update or delete on public.account_bans for each row execute function public._staff_audit();

-- ───────────────────────────── Modération : ouverte aux modérateurs ─────────────────────────────

-- Les fonctions de modération du tchat et de la galerie passent du contrôle « super admin » au contrôle « équipe » ; la suppression
-- définitive d'un donjon reste réservée aux super admins. La règle « on ne sanctionne pas un rang égal ou supérieur » remplace
-- l'ancienne « on ne sanctionne pas un admin ».
do $$
declare
  r record;
  d text;
  n text;
begin
  for r in select p.oid, p.proname from pg_proc p join pg_namespace s on s.oid = p.pronamespace
            where s.nspname = 'public' and (p.proname like 'admin\_chat\_%' or p.proname like 'admin\_gallery\_%')
              and p.proname <> 'admin_gallery_delete'
  loop
    d := pg_get_functiondef(r.oid);
    n := replace(d, 'public.is_super_admin()', 'public.is_staff()');
    n := replace(n, 'exists (select 1 from public.admins where player_id = p_player)',
                    'public.staff_rank(p_player) >= public.staff_rank((select auth.uid()))');
    if n = d then
      raise exception 'fonction inchangée : %', r.proname;
    end if;
    execute n;
  end loop;
end $$;

-- ───────────────────────────── Équipe ─────────────────────────────

create function public.staff_list() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.rank desc, t.granted_at) from (
      select s.player_id, p.pseudo, s.role, public.staff_rank(s.player_id) as rank, s.granted_at, s.granted_by, g.pseudo as granted_by_pseudo
        from public.staff_roles s
        join public.profiles p on p.id = s.player_id
        left join public.profiles g on g.id = s.granted_by
    ) t), '[]'::jsonb);
end $$;

-- Nomme (moderator / super_admin) ou retire ('none') un membre de l'équipe.
create function public.staff_set_role(p_player uuid, p_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  my_rank int := public.staff_rank((select auth.uid()));
  target_rank int := public.staff_rank(p_player);
  new_rank int;
begin
  if my_rank < 2 then
    raise exception 'acces_refuse';
  end if;
  if p_role is null or p_role not in ('moderator', 'super_admin', 'none') then
    raise exception 'role_invalide';
  end if;
  if p_player is null or not exists (select 1 from public.profiles where id = p_player) then
    raise exception 'joueur_inconnu';
  end if;
  new_rank := case p_role when 'moderator' then 1 when 'super_admin' then 2 else 0 end;
  if p_player = me or target_rank >= my_rank then
    raise exception 'acces_refuse';                                   -- ni soi-même, ni un rang égal ou supérieur
  end if;
  if (new_rank >= 2 or target_rank >= 2) and my_rank < 3 then
    raise exception 'acces_refuse';                                   -- les super admins : le développeur seul
  end if;
  if p_role = 'none' then
    delete from public.staff_roles where player_id = p_player;
  else
    insert into public.staff_roles (player_id, role, granted_by) values (p_player, p_role, me)
    on conflict (player_id) do update set role = excluded.role, granted_by = excluded.granted_by, granted_at = now();
  end if;
end $$;

-- Liste des joueurs avec rôle et sanctions en cours (sans courriel).
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
             public.account_banned(p.id) as banned
        from public.profiles p
        left join (select player_id, sum(amount) as xp from public.xp_log group by player_id) x on x.player_id = p.id
       where coalesce(p_search, '') = '' or position(lower(p_search) in lower(p.pseudo)) > 0
       order by p.created_at desc
       limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)
    ) t), '[]'::jsonb);
end $$;

-- Fiche d'un joueur : rôle, sanctions en cours, derniers messages publics du tchat, dernières actions le concernant.
create function public.admin_player_card(p_player uuid) returns jsonb
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

-- Journal : les modérateurs ne voient que leurs propres actions ; super admins et développeur voient tout (filtres facultatifs).
create function public.staff_log_list(p_actor uuid default null, p_action text default null, p_since timestamptz default null,
                                      p_limit int default 100, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  rk int := public.staff_rank((select auth.uid()));
begin
  if rk < 1 then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t)) from (
      select l.id, l.actor, a.pseudo as actor_pseudo, l.action, l.target, tg.pseudo as target_pseudo, l.detail, l.created_at
        from public.staff_log l
        left join public.profiles a on a.id = l.actor
        left join public.profiles tg on tg.id = l.target
       where (case when rk < 2 then l.actor = me else p_actor is null or l.actor = p_actor end)
         and (p_action is null or p_action = '' or l.action = p_action)
         and (p_since is null or l.created_at >= p_since)
       order by l.id desc
       limit least(greatest(p_limit, 1), 500) offset greatest(p_offset, 0)
    ) t), '[]'::jsonb);
end $$;

-- ───────────────────────────── Outils réservés au développeur ─────────────────────────────

-- Bannit un compte : plus de partie classée, tchat coupé, galerie fermée. p_hours null = définitif.
create function public.admin_account_ban(p_player uuid, p_hours int default null, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  till timestamptz := case when p_hours is null then null else now() + make_interval(hours => least(greatest(p_hours, 1), 87600)) end;
  why text := nullif(left(btrim(coalesce(p_reason, '')), 200), '');
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  if p_player is null or not exists (select 1 from public.profiles where id = p_player) or public.staff_rank(p_player) >= 3 then
    raise exception 'joueur_inconnu';
  end if;
  insert into public.account_bans (player_id, reason, until, banned_by)
  values (p_player, why, till, (select auth.uid()))
  on conflict (player_id) do update set reason = excluded.reason, until = excluded.until, banned_by = excluded.banned_by, created_at = now();
  insert into public.chat_mutes (player_id, until, reason, muted_by)
  values (p_player, coalesce(till, now() + interval '100 years'), why, (select auth.uid()))
  on conflict (player_id) do update set until = excluded.until, reason = excluded.reason, muted_by = excluded.muted_by, created_at = now();
  update public.dungeons set is_public = false where owner_id = p_player and is_public;
  update public.ranked_runs set status = 'expired' where player_id = p_player and status = 'started' and not test;
end $$;

create function public.admin_account_unban(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  delete from public.account_bans where player_id = p_player;
  delete from public.chat_mutes where player_id = p_player;
end $$;

create function public.admin_account_bans() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('player_id', b.player_id, 'pseudo', p.pseudo, 'reason', b.reason,
                                                       'until', b.until, 'created_at', b.created_at) order by b.created_at desc)
                     from public.account_bans b join public.profiles p on p.id = b.player_id
                    where b.until is null or b.until > now()), '[]'::jsonb);
end $$;

create function public.admin_announce(p_body text, p_hours int default 24) returns void
language plpgsql security definer set search_path = '' as $$
declare
  b text := btrim(coalesce(p_body, ''));
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  if char_length(b) not between 1 and 400 then
    raise exception 'message_invalide';
  end if;
  update public.announcements set expires_at = now() where expires_at > now();
  insert into public.announcements (body, created_by, expires_at)
  values (b, (select auth.uid()), now() + make_interval(hours => least(greatest(coalesce(p_hours, 24), 1), 720)));
  perform public._staff_log_add('announce', null, jsonb_build_object('body', left(b, 200), 'hours', p_hours));
end $$;

create function public.admin_announce_clear() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  update public.announcements set expires_at = now() where expires_at > now();
  perform public._staff_log_add('announce_clear', null);
end $$;

create function public.admin_set_server_state(p_ranked_closed boolean, p_chat_closed boolean, p_message text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  update public.server_state
     set ranked_closed = coalesce(p_ranked_closed, false), chat_closed = coalesce(p_chat_closed, false),
         message = nullif(left(btrim(coalesce(p_message, '')), 300), ''), updated_by = (select auth.uid()), updated_at = now()
   where id = 1;
  perform public._staff_log_add('maintenance', null,
    jsonb_build_object('ranked_closed', p_ranked_closed, 'chat_closed', p_chat_closed, 'message', left(coalesce(p_message, ''), 200)));
end $$;

-- Classements existants (type, période, mode) avec le nombre de parties vérifiées.
create function public.admin_boards() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.kind, t.period desc nulls last, t.difficulty) from (
      select kind, period, case when kind = 'difficulty' then difficulty end as difficulty, count(*) as verified
        from public.ranked_runs where status = 'verified' and not test
       group by kind, period, case when kind = 'difficulty' then difficulty end
    ) t), '[]'::jsonb);
end $$;

-- Réinitialise un classement : les parties vérifiées concernées sont écartées (l'expérience et les badges déjà gagnés restent acquis).
-- Demande le mot de confirmation « REINITIALISER ». Renvoie le nombre de parties écartées.
create function public.admin_reset_board(p_kind text, p_period text, p_difficulty text, p_confirm text) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  if p_confirm is distinct from 'REINITIALISER' then
    raise exception 'confirmation_requise';
  end if;
  with d as (
    update public.ranked_runs set status = 'rejected', reject_reason = 'reinitialise_dev'
     where status = 'verified' and not test and kind = p_kind
       and period is not distinct from nullif(p_period, '')
       and (p_kind <> 'difficulty' or difficulty = p_difficulty)
    returning 1)
  select count(*) into n from d;
  perform public._staff_log_add('board_reset', null, jsonb_build_object('kind', p_kind, 'period', p_period, 'difficulty', p_difficulty, 'runs', n));
  return n;
end $$;

-- Annule une partie classée suspecte (elle disparaît des classements).
create function public.admin_cancel_run(p_run uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  who uuid;
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  update public.ranked_runs set status = 'rejected', reject_reason = 'annulee_dev' where id = p_run and not test returning player_id into who;
  if who is null then
    raise exception 'partie_introuvable';
  end if;
  perform public._staff_log_add('run_cancel', who, jsonb_build_object('run', p_run, 'reason', left(coalesce(p_reason, ''), 200)));
end $$;

-- Santé du serveur : files de vérification, parties restées « en cours », rejets récents, taille des tables.
create function public.admin_health() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  return jsonb_build_object(
    'generated_at', now(),
    'stuck_started', (select count(*) from public.ranked_runs where status = 'started' and started_at < now() - interval '3 hours'),
    'in_progress', (select count(*) from public.ranked_runs where status = 'started' and started_at >= now() - interval '3 hours'),
    'queue', (select count(*) from public.ranked_runs where status = 'submitted'),
    'oldest_queue_seconds', (select extract(epoch from now() - min(submitted_at))::int from public.ranked_runs where status = 'submitted'),
    'rejected_24h', (select coalesce(jsonb_agg(jsonb_build_object('reason', reason, 'n', n) order by n desc), '[]'::jsonb)
                       from (select coalesce(reject_reason, '?') as reason, count(*) as n from public.ranked_runs
                              where status = 'rejected' and not test and coalesce(verified_at, submitted_at, started_at) > now() - interval '24 hours'
                              group by 1) r),
    'expired_24h', (select count(*) from public.ranked_runs where status = 'expired' and started_at > now() - interval '24 hours'),
    'chat_24h', (select count(*) from public.chat_messages where created_at > now() - interval '24 hours'),
    'staff_actions_24h', (select count(*) from public.staff_log where created_at > now() - interval '24 hours'),
    'db_bytes', pg_database_size(current_database()),
    'tables', (select coalesce(jsonb_agg(jsonb_build_object('name', c.relname, 'bytes', pg_total_relation_size(c.oid)) order by pg_total_relation_size(c.oid) desc), '[]'::jsonb)
                 from (select oid, relname from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r'
                        order by pg_total_relation_size(oid) desc limit 8) c),
    'server_state', (select to_jsonb(s) - 'id' - 'updated_by' from public.server_state s where id = 1));
end $$;

-- Marque de rôle affichée à côté des pseudos (tchat, classements) : liste publique {player_id, role} de l'équipe (aucune autre donnée).
create function public.staff_public() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('player_id', player_id, 'role', role)), '[]'::jsonb) from public.staff_roles
$$;
revoke all on function public.staff_public() from public;
grant execute on function public.staff_public() to anon, authenticated;

-- ───────────────────────────── Droits d'exécution ─────────────────────────────

do $$
declare f text;
begin
  foreach f in array array[
    'staff_list()', 'staff_set_role(uuid,text)', 'admin_players(text,int,int)', 'admin_player_card(uuid)',
    'staff_log_list(uuid,text,timestamptz,int,int)', 'admin_account_ban(uuid,int,text)', 'admin_account_unban(uuid)', 'admin_account_bans()',
    'admin_announce(text,int)', 'admin_announce_clear()', 'admin_set_server_state(boolean,boolean,text)', 'admin_boards()',
    'admin_reset_board(text,text,text,text)', 'admin_cancel_run(uuid,text)', 'admin_health()']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
