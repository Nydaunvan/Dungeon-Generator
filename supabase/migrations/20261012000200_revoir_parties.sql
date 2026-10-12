-- Dungeon Generator — revoir les parties d'un joueur (réservé au développeur) :
--  * admin_player_runs : les 30 dernières parties d'un joueur (sans le journal, donc léger) ;
--  * admin_run_log : une partie complète (graine, réglages, version, résultat et journal d'actions) pour la rejouer dans le moteur
--    ou l'exporter en CSV. Chaque consultation est écrite dans le journal de l'équipe (action « run_view »).

create function public.admin_player_runs(p_player uuid, p_limit int default 30) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(t)) from (
      select r.id, r.kind, r.period, r.day, r.difficulty, r.status, r.score, r.seconds, r.game_version, r.reject_reason,
             r.started_at, r.submitted_at, r.verified_at, r.test,
             (r.log is not null) as has_log,
             case when r.log is null then null else jsonb_array_length(r.log) end as actions
        from public.ranked_runs r
       where r.player_id = p_player
       order by r.started_at desc
       limit least(greatest(coalesce(p_limit, 30), 1), 100)
    ) t), '[]'::jsonb);
end $$;

create function public.admin_run_log(p_run uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r public.ranked_runs%rowtype;
  who text;
begin
  if not public.is_dev() then
    raise exception 'acces_refuse';
  end if;
  select * into r from public.ranked_runs where id = p_run;
  if not found then
    raise exception 'partie_introuvable';
  end if;
  select pseudo into who from public.profiles where id = r.player_id;
  perform public._staff_log_add('run_view', r.player_id, jsonb_build_object('run', p_run));
  return jsonb_build_object(
    'id', r.id, 'player_id', r.player_id, 'pseudo', who, 'kind', r.kind, 'period', r.period, 'day', r.day,
    'difficulty', r.difficulty, 'status', r.status, 'score', r.score, 'seconds', r.seconds, 'game_version', r.game_version,
    'reject_reason', r.reject_reason, 'started_at', r.started_at, 'submitted_at', r.submitted_at, 'verified_at', r.verified_at,
    'test', r.test, 'seed', r.seed, 'params', r.params, 'metrics', r.metrics, 'log', r.log);
end $$;

revoke all on function public.admin_player_runs(uuid, int), public.admin_run_log(uuid) from public, anon;
grant execute on function public.admin_player_runs(uuid, int), public.admin_run_log(uuid) to authenticated;
