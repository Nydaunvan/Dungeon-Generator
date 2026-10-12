-- Outils de modération (1.34.0) — à coller APRÈS 20261012000100_roles_equipe.sql (et 20261012000200_revoir_parties.sql).
--  * signalement d'un JOUEUR (en plus des messages et des donjons déjà signalables) ;
--  * notes internes sur un joueur, historique complet (pseudos, sanctions, signalements) ;
--  * parties classées suspectes (rejetées, trop rapides, récidive) ;
--  * statistiques d'activité (inscriptions, parties, messages, donjons publiés) ;
--  * compteurs de la file de modération (alerte de l'équipe) ;
--  * sanction de galerie à durée limitée (levée automatique) ;
--  * réglages à distance (développeur) : publication en galerie, signalements, seuil d'alerte.

-- ───────────────────────────── Réglages à distance ─────────────────────────────

create table public.feature_flags (
  key text primary key check (key ~ '^[a-z_]{3,40}$'),
  value jsonb not null,
  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.feature_flags enable row level security;
revoke all on public.feature_flags from public, anon, authenticated;
insert into public.feature_flags (key, value) values
  ('gallery_publish', 'true'::jsonb),    -- publication de donjons en galerie ouverte
  ('reports_enabled', 'true'::jsonb),    -- les joueurs peuvent signaler (messages, donjons, joueurs)
  ('queue_alert', '5'::jsonb);           -- nombre d'éléments en attente à partir duquel l'équipe est alertée

create function public._flag_bool(p_key text, p_default boolean) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select (value #>> '{}')::boolean from public.feature_flags where key = p_key and jsonb_typeof(value) = 'boolean'), p_default)
$$;
create function public._flag_int(p_key text, p_default int) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce((select (value #>> '{}')::int from public.feature_flags where key = p_key and jsonb_typeof(value) = 'number'), p_default)
$$;
revoke all on function public._flag_bool(text, boolean), public._flag_int(text, int) from public, anon, authenticated;

-- Lu par le jeu au démarrage.
create function public.flags_get() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from public.feature_flags
$$;
revoke all on function public.flags_get() from public;
grant execute on function public.flags_get() to anon, authenticated;

create function public.dev_flag_set(p_key text, p_value jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  cur jsonb;
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  select value into cur from public.feature_flags where key = p_key;
  if cur is null then
    raise exception 'reglage_inconnu';
  end if;
  if jsonb_typeof(p_value) is distinct from jsonb_typeof(cur) then
    raise exception 'valeur_invalide';
  end if;
  if p_key = 'queue_alert' and ((p_value #>> '{}')::int < 1 or (p_value #>> '{}')::int > 999) then
    raise exception 'valeur_invalide';
  end if;
  update public.feature_flags set value = p_value, updated_by = (select auth.uid()), updated_at = now() where key = p_key;
  perform public._staff_log_add('flag_set', null, jsonb_build_object('key', p_key, 'value', p_value, 'previous', cur));
end $$;

-- La publication en galerie peut être coupée (l'équipe garde la main) ; les signalements aussi.
create or replace function public.dungeons_ban_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_public then
    if exists (select 1 from public.gallery_bans b where b.player_id = new.owner_id) or public.account_banned(new.owner_id) then
      raise exception 'publication_interdite';
    end if;
    if not public._flag_bool('gallery_publish', true) and not public.is_staff() then
      raise exception 'galerie_fermee';
    end if;
  end if;
  return new;
end $$;

create policy "signalements ouverts" on public.dungeon_reports
  as restrictive for insert to authenticated
  with check (public._flag_bool('reports_enabled', true));

do $$
declare
  def text;
begin
  select pg_get_functiondef('public.chat_report(bigint,text)'::regprocedure) into def;
  if position('signalements_fermes' in def) = 0 then
    def := replace(def, E'begin\n  if uid is null then', E'begin\n  if not public._flag_bool(''reports_enabled'', true) then\n    raise exception ''signalements_fermes'';\n  end if;\n  if uid is null then');
    execute def;
  end if;
end $$;

-- ───────────────────────────── Sanction de galerie à durée limitée ─────────────────────────────

alter table public.gallery_bans add column if not exists until timestamptz;       -- null = définitive

create view public.gallery_bans_active as
  select * from public.gallery_bans where until is null or until > now();
revoke all on public.gallery_bans_active from public, anon, authenticated;

-- Toute lecture de « qui est banni » ne voit plus que les sanctions en cours (les écritures restent sur la table).
do $$
declare
  r record;
  def text;
begin
  for r in select p.oid, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prokind = 'f' and p.prosrc like '%public.gallery_bans%' and p.proname <> 'dungeons_ban_garde'
  loop
    def := pg_get_functiondef(r.oid);
    def := regexp_replace(def, '(from|join) public\.gallery_bans( |\n|;|\))', '\1 public.gallery_bans_active\2', 'g');
    def := regexp_replace(def, 'delete from public\.gallery_bans_active', 'delete from public.gallery_bans', 'g');
    execute def;
  end loop;
end $$;
create or replace function public.dungeons_ban_garde() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_public then
    if exists (select 1 from public.gallery_bans_active b where b.player_id = new.owner_id) or public.account_banned(new.owner_id) then
      raise exception 'publication_interdite';
    end if;
    if not public._flag_bool('gallery_publish', true) and not public.is_staff() then
      raise exception 'galerie_fermee';
    end if;
  end if;
  return new;
end $$;

-- Le journal de la sanction de galerie indique aussi sa date de fin.
do $$
declare
  def text := pg_get_functiondef('public._staff_audit()'::regprocedure);
begin
  def := replace(def, E'_staff_log_add(''gallery_ban'', new.player_id, jsonb_build_object(''reason'', new.reason))',
                      E'_staff_log_add(''gallery_ban'', new.player_id, jsonb_build_object(''reason'', new.reason, ''until'', new.until))');
  execute def;
end $$;

-- Interdit de publier pendant p_hours heures (null = définitif).
create function public.admin_gallery_ban_for(p_player uuid, p_hours int default null, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  delete from public.gallery_bans where player_id = p_player and until is not null and until <= now();
  perform public.admin_gallery_ban(p_player, p_reason);
  -- la ligne de journal de l'insertion est remplacée par celle de la mise à jour, qui porte la date de fin
  delete from public.staff_log where id = (select max(id) from public.staff_log
                                            where action = 'gallery_ban' and target = p_player and actor = (select auth.uid()));
  update public.gallery_bans
     set until = case when p_hours is null then null else now() + make_interval(hours => least(greatest(p_hours, 1), 87600)) end
   where player_id = p_player;
end $$;

-- ───────────────────────────── Signaler un joueur ─────────────────────────────

create table public.player_reports (
  id bigint generated always as identity primary key,
  player_id uuid not null references public.profiles (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason text check (reason is null or char_length(reason) <= 200),
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by uuid references public.profiles (id) on delete set null,
  note text check (note is null or char_length(note) <= 300),
  check (player_id <> reporter_id)
);
create unique index player_reports_open_idx on public.player_reports (player_id, reporter_id) where handled_at is null;
create index player_reports_pending_idx on public.player_reports (player_id) where handled_at is null;
alter table public.player_reports enable row level security;
revoke all on public.player_reports from public, anon, authenticated;

create function public.player_report(p_player uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'non_connecte';
  end if;
  if not public._flag_bool('reports_enabled', true) then
    raise exception 'signalements_fermes';
  end if;
  if p_player is null or p_player = uid or not exists (select 1 from public.profiles where id = p_player) then
    raise exception 'joueur_inconnu';
  end if;
  if (select count(*) from public.player_reports where reporter_id = uid and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'trop_de_signalements';
  end if;
  insert into public.player_reports (player_id, reporter_id, reason)
  values (p_player, uid, nullif(left(btrim(coalesce(p_reason, '')), 200), ''))
  on conflict (player_id, reporter_id) where handled_at is null do nothing;
end $$;

-- Joueurs signalés : [{player_id, pseudo, reports, last_report, reasons, banned, muted_until}], le plus récemment signalé d'abord.
create function public.admin_player_reports(p_include_handled boolean default false, p_limit int default 50) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.last_report desc) from (
      select p.id as player_id, p.pseudo,
             count(r.id) filter (where r.handled_at is null) as reports,
             count(r.id) as total,
             max(r.created_at) as last_report,
             (select jsonb_agg(x.reason) from (select r2.reason from public.player_reports r2
                where r2.player_id = p.id and r2.reason is not null and (p_include_handled or r2.handled_at is null)
                order by r2.created_at desc limit 3) x) as reasons,
             public.account_banned(p.id) as banned,
             (select cm.until from public.chat_mutes cm where cm.player_id = p.id and cm.until > now()) as muted_until
        from public.player_reports r
        join public.profiles p on p.id = r.player_id
       where p_include_handled or r.handled_at is null
       group by p.id
       order by max(r.created_at) desc
       limit least(greatest(p_limit, 1), 200)
    ) t), '[]'::jsonb);
end $$;

create function public.admin_player_report_handle(p_player uuid, p_note text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  update public.player_reports
     set handled_at = now(), handled_by = (select auth.uid()), note = nullif(left(btrim(coalesce(p_note, '')), 300), '')
   where player_id = p_player and handled_at is null;
  get diagnostics n = row_count;
  if n > 0 then
    perform public._staff_log_add('report_handle', p_player, jsonb_build_object('count', n, 'note', nullif(left(btrim(coalesce(p_note, '')), 300), '')));
  end if;
end $$;

-- ───────────────────────────── Notes internes ─────────────────────────────

create table public.player_notes (
  id bigint generated always as identity primary key,
  player_id uuid not null references public.profiles (id) on delete cascade,
  author uuid references public.profiles (id) on delete set null,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index player_notes_player_idx on public.player_notes (player_id, id desc);
alter table public.player_notes enable row level security;
revoke all on public.player_notes from public, anon, authenticated;

create function public.admin_player_notes(p_player uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t) order by t.id desc) from (
      select n.id, n.author, a.pseudo as author_pseudo, n.body, n.created_at
        from public.player_notes n left join public.profiles a on a.id = n.author
       where n.player_id = p_player order by n.id desc limit 100
    ) t), '[]'::jsonb);
end $$;

create function public.admin_player_note_add(p_player uuid, p_body text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  b text := btrim(coalesce(p_body, ''));
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  if char_length(b) < 1 or char_length(b) > 500 then
    raise exception 'note_invalide';
  end if;
  if not exists (select 1 from public.profiles where id = p_player) then
    raise exception 'joueur_inconnu';
  end if;
  insert into public.player_notes (player_id, author, body) values (p_player, (select auth.uid()), b);
  perform public._staff_log_add('note_add', p_player, jsonb_build_object('note', left(b, 120)));
end $$;

-- Supprime une note : son auteur, ou un super admin / le développeur.
create function public.admin_player_note_delete(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare
  n public.player_notes%rowtype;
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  select * into n from public.player_notes where id = p_id;
  if not found then
    return;
  end if;
  if n.author is distinct from (select auth.uid()) and not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  delete from public.player_notes where id = p_id;
  perform public._staff_log_add('note_delete', n.player_id, jsonb_build_object('note', left(n.body, 120)));
end $$;

-- ───────────────────────────── Historique d'un joueur ─────────────────────────────

create table public.pseudo_history (
  id bigserial primary key,
  player_id uuid not null references public.profiles (id) on delete cascade,
  pseudo text not null,
  changed_at timestamptz not null default now()
);
create index pseudo_history_player_idx on public.pseudo_history (player_id, id desc);
alter table public.pseudo_history enable row level security;
revoke all on public.pseudo_history from public, anon, authenticated;
insert into public.pseudo_history (player_id, pseudo, changed_at) select id, pseudo, created_at from public.profiles;

create function public._pseudo_trace() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' or new.pseudo is distinct from old.pseudo then
    insert into public.pseudo_history (player_id, pseudo) values (new.id, new.pseudo);
  end if;
  return new;
end $$;
revoke all on function public._pseudo_trace() from public, anon, authenticated;
create trigger profiles_pseudo_trace after insert or update of pseudo on public.profiles for each row execute function public._pseudo_trace();

-- {pseudos: [{pseudo, changed_at}], actions: [journal de l'équipe le concernant], counts: {…}}
create function public.admin_player_history(p_player uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  return jsonb_build_object(
    'pseudos', coalesce((select jsonb_agg(to_jsonb(h) order by h.changed_at desc) from
                (select pseudo, changed_at from public.pseudo_history where player_id = p_player order by id desc limit 20) h), '[]'::jsonb),
    'actions', coalesce((select jsonb_agg(to_jsonb(a) order by a.created_at desc) from
                (select l.action, l.detail, l.created_at, ac.pseudo as actor_pseudo
                   from public.staff_log l left join public.profiles ac on ac.id = l.actor
                  where l.target = p_player and l.action not in ('run_view', 'note_add', 'note_delete')
                  order by l.id desc limit 100) a), '[]'::jsonb),
    'counts', jsonb_build_object(
      'chat_reported', (select count(*) from public.chat_reports r join public.chat_messages m on m.id = r.message_id where m.player_id = p_player),
      'chat_deleted', (select count(*) from public.chat_messages where player_id = p_player and deleted_at is not null),
      'gallery_reported', (select count(*) from public.dungeon_reports r join public.dungeons d on d.id = r.dungeon_id where d.owner_id = p_player),
      'player_reported', (select count(*) from public.player_reports where player_id = p_player),
      'runs_rejected', (select count(*) from public.ranked_runs where player_id = p_player and status = 'rejected' and not test)));
end $$;

-- ───────────────────────────── Parties suspectes (super admin) ─────────────────────────────

-- Parties de la période : rejetées par le rejeu, vérifiées mais bien plus rapides que la médiane de même niveau, ou joueur
-- ayant au moins 3 parties rejetées. [{run_id, player_id, pseudo, difficulty, status, score, seconds, reject_reason, flags, ratio, at, has_log}]
create function public.admin_suspect_runs(p_days int default 14, p_limit int default 60) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    with base as (
      select r.id, r.player_id, r.difficulty, r.status, r.score, r.seconds, r.reject_reason, r.log is not null as has_log,
             coalesce(r.submitted_at, r.started_at) as at
        from public.ranked_runs r
       where not r.test and r.status in ('verified', 'rejected')
         and coalesce(r.submitted_at, r.started_at) > now() - make_interval(days => least(greatest(p_days, 1), 90))
    ),
    med as (
      select difficulty, score, percentile_cont(0.5) within group (order by seconds) as m
        from public.ranked_runs where status = 'verified' and not test and seconds is not null
       group by difficulty, score having count(*) >= 5
    ),
    rej as (select player_id, count(*) as n from base where status = 'rejected' group by player_id),
    flagged as (
      select b.*, p.pseudo,
             case when md.m is not null and md.m > 0 and b.seconds is not null then round((b.seconds / md.m)::numeric, 2) end as ratio,
             array_remove(array[
               case when b.status = 'rejected' then 'rejected' end,
               case when b.status = 'verified' and md.m is not null and md.m > 0 and b.seconds < 0.3 * md.m then 'fast' end,
               case when coalesce(rj.n, 0) >= 3 then 'repeat' end], null) as flags
        from base b
        join public.profiles p on p.id = b.player_id
        left join med md on md.difficulty = b.difficulty and md.score = b.score
        left join rej rj on rj.player_id = b.player_id
    )
    select jsonb_agg(jsonb_build_object('run_id', f.id, 'player_id', f.player_id, 'pseudo', f.pseudo, 'difficulty', f.difficulty,
             'status', f.status, 'score', f.score, 'seconds', f.seconds, 'reject_reason', f.reject_reason, 'flags', to_jsonb(f.flags),
             'ratio', f.ratio, 'at', f.at, 'has_log', f.has_log) order by f.at desc)
      from (select * from flagged where cardinality(flags) > 0 order by at desc limit least(greatest(p_limit, 1), 200)) f
  ), '[]'::jsonb);
end $$;

-- ───────────────────────────── Statistiques d'activité (super admin) ─────────────────────────────

create function public.admin_stats(p_days int default 14) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  n int := least(greatest(p_days, 3), 90);
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return jsonb_build_object('days', (
    select jsonb_agg(jsonb_build_object(
      'day', d::date,
      'signups', (select count(*) from public.profiles where (created_at at time zone 'Europe/Paris')::date = d::date),
      'runs', (select count(*) from public.ranked_runs where not test and submitted_at is not null and (submitted_at at time zone 'Europe/Paris')::date = d::date),
      'chat', (select count(*) from public.chat_messages where (created_at at time zone 'Europe/Paris')::date = d::date),
      'dungeons', (select count(*) from public.dungeons where is_public and (created_at at time zone 'Europe/Paris')::date = d::date)
    ) order by d)
    from generate_series((now() at time zone 'Europe/Paris')::date - (n - 1), (now() at time zone 'Europe/Paris')::date, interval '1 day') d));
end $$;

-- ───────────────────────────── File de modération : compteurs ─────────────────────────────

-- {chat, gallery, players, suspects, alert} : éléments en attente, et seuil d'alerte réglé par le développeur.
create function public.admin_queue_counts() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  return jsonb_build_object(
    'chat', (select count(distinct message_id) from public.chat_reports where handled_at is null),
    'gallery', (select count(distinct dungeon_id) from public.dungeon_reports where handled_at is null),
    'players', (select count(distinct player_id) from public.player_reports where handled_at is null),
    'suspects', case when public.is_super_admin() then jsonb_array_length(public.admin_suspect_runs(7, 200)) else 0 end,
    'alert', public._flag_int('queue_alert', 5));
end $$;

-- ───────────────────────────── Droits ─────────────────────────────

do $$
declare
  f text;
begin
  foreach f in array array[
    'dev_flag_set(text,jsonb)', 'admin_gallery_ban_for(uuid,int,text)', 'player_report(uuid,text)', 'admin_player_reports(boolean,int)',
    'admin_player_report_handle(uuid,text)', 'admin_player_notes(uuid)', 'admin_player_note_add(uuid,text)', 'admin_player_note_delete(bigint)',
    'admin_player_history(uuid)', 'admin_suspect_runs(int,int)', 'admin_stats(int)', 'admin_queue_counts()']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
