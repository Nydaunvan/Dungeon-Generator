-- Dungeon Generator — parties suspectes moins agressives : niveaux de suspicion, rejets « techniques » à part, seuils relevés.
--
--  * Un rejet « technique » (version non rejouable, rejeu trop long ou sans résultat, divergence du rejeu : engagement_inattendu,
--    fenetre_absente, jeu_jamais_au_repos, ou action de l'équipe de développement) n'est PAS un signe de triche : niveau « info ».
--  * « Trop rapide » : moins de 20 % de la durée médiane (au lieu de 30 %), médiane calculée sur au moins 10 parties (au lieu de 5).
--  * « Récidive » : 5 rejets non techniques ou plus (au lieu de 3 rejets quelconques), et elle ne marque plus que les parties rejetées
--    ou trop rapides du joueur, jamais ses parties validées normales.
--  * Chaque partie reçoit un niveau : 'probable' (récidive, moins de 10 % de la médiane, score invraisemblable), 'watch' (rejetée non
--    technique, trop rapide) ou 'info' (rejet technique). La liste est triée du plus au moins suspect.
--  * Le rappel d'ouverture du jeu (admin_queue_counts) ne compte plus les parties de niveau 'info'.

create or replace function public.admin_suspect_runs(p_days int default 14, p_limit int default 60) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    with base as (
      select r.id, r.player_id, r.difficulty, r.status, r.score, r.seconds, r.reject_reason, r.log is not null as has_log,
             coalesce(r.submitted_at, r.started_at) as at,
             (r.status = 'rejected' and coalesce(r.reject_reason, '') ~ '^(version_non_rejouable|rejeu_|engagement_inattendu|fenetre_absente|jeu_jamais_au_repos|reinitialise_dev|annulee_dev)') as technical
        from public.ranked_runs r
       where not r.test and r.status in ('verified', 'rejected')
         and coalesce(r.submitted_at, r.started_at) > now() - make_interval(days => least(greatest(p_days, 1), 90))
    ),
    med as (
      select difficulty, score, percentile_cont(0.5) within group (order by seconds) as m
        from public.ranked_runs where status = 'verified' and not test and seconds is not null
       group by difficulty, score having count(*) >= 10
    ),
    rej as (select player_id, count(*) as n from base where status = 'rejected' and not technical group by player_id),
    calc as (
      select b.*, p.pseudo, md.m,
             case when md.m is not null and md.m > 0 and b.seconds is not null then round((b.seconds / md.m)::numeric, 2) end as ratio,
             (b.status = 'rejected' and not b.technical) as real_rej,
             (b.status = 'verified' and md.m is not null and md.m > 0 and b.seconds < 0.2 * md.m) as fast,
             (b.status = 'verified' and md.m is not null and md.m > 0 and b.seconds < 0.1 * md.m) as very_fast,
             coalesce(rj.n, 0) as rej_n
        from base b
        join public.profiles p on p.id = b.player_id
        left join med md on md.difficulty = b.difficulty and md.score = b.score
        left join rej rj on rj.player_id = b.player_id
       where not exists (select 1 from public.suspect_seen s where s.run_id = b.id)
    ),
    flagged as (
      select c.*,
             (c.rej_n >= 5 and (c.real_rej or c.fast)) as repeat,
             array_remove(array[
               case when c.technical then 'technical' end,
               case when c.real_rej then 'rejected' end,
               case when c.fast then 'fast' end,
               case when c.rej_n >= 5 and (c.real_rej or c.fast) then 'repeat' end], null) as flags
        from calc c
    ),
    lvl as (
      select f.*,
             case when f.repeat or f.very_fast or (f.real_rej and coalesce(f.reject_reason, '') like 'score_invraisemblable%') then 'probable'
                  when f.real_rej or f.fast then 'watch'
                  else 'info' end as level
        from flagged f where cardinality(f.flags) > 0
    )
    select jsonb_agg(jsonb_build_object('run_id', f.id, 'player_id', f.player_id, 'pseudo', f.pseudo, 'difficulty', f.difficulty,
             'status', f.status, 'score', f.score, 'seconds', f.seconds, 'reject_reason', f.reject_reason, 'flags', to_jsonb(f.flags),
             'level', f.level, 'ratio', f.ratio, 'at', f.at, 'has_log', f.has_log)
             order by case f.level when 'probable' then 0 when 'watch' then 1 else 2 end, f.at desc)
      from (select * from lvl
             order by case level when 'probable' then 0 when 'watch' then 1 else 2 end, at desc
             limit least(greatest(p_limit, 1), 200)) f
  ), '[]'::jsonb);
end $$;
revoke all on function public.admin_suspect_runs(int, int) from public, anon;
grant execute on function public.admin_suspect_runs(int, int) to authenticated;

-- Le compteur d'ouverture ignore les parties « info » (rejets techniques).
create or replace function public.admin_queue_counts() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    raise exception 'acces_refuse';
  end if;
  return jsonb_build_object(
    'chat', (select count(distinct message_id) from public.chat_reports where handled_at is null),
    'gallery', (select count(distinct dungeon_id) from public.dungeon_reports where handled_at is null),
    'players', (select count(distinct player_id) from public.player_reports where handled_at is null),
    'suspects', case when public.is_super_admin()
                     then (select count(*)::int from jsonb_array_elements(public.admin_suspect_runs(7, 200)) e where e ->> 'level' <> 'info')
                     else 0 end,
    'alert', public._flag_int('queue_alert', 5));
end $$;
revoke all on function public.admin_queue_counts() from public, anon;
grant execute on function public.admin_queue_counts() to authenticated;
