-- Dungeon Generator — super admin : tester N'IMPORTE QUELLE règle de défi (format « semaine » ou format « jour »).
--  * admin_test_rules()  : liste des règles (identifiant, icône, noms, métrique, réglages semaine) pour le sélecteur.
--  * admin_start_rule_run(règle, format, version) : partie de TEST (hors classements, sans essai consommé, sans récompense),
--    graine au hasard. Format 'weekly' : réglages propres à la règle (niveaux, taille, difficulté) ; format 'daily' : 2 niveaux 13×11 normal.

create or replace function public.admin_test_rules() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('rule_id', rule_id, 'icon', icon, 'label_fr', label_fr, 'label_en', label_en, 'metric', metric,
             'daily', (metric = 'levels' and params = '{}'::jsonb),
             'levels', coalesce((params->>'levels')::int, 4), 'width', coalesce((params->>'width')::int, 13),
             'height', coalesce((params->>'height')::int, 11), 'difficulty', coalesce(params->>'difficulty', 'normal')) order by slot)
      from public.weekly_rules), '[]'::jsonb);
end $$;

create or replace function public.admin_start_rule_run(p_rule text, p_format text, p_game_version text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r public.weekly_rules%rowtype;
  new_seed text := replace(gen_random_uuid()::text, '-', '');
  prm jsonb;
  per_name text;
  rid uuid;
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  if p_game_version is null or char_length(p_game_version) not between 1 and 20 then
    raise exception 'version_invalide';
  end if;
  if p_format not in ('weekly', 'daily') then
    raise exception 'mode_inconnu';
  end if;
  select * into r from public.weekly_rules where rule_id = p_rule;
  if not found then
    raise exception 'mode_inconnu';
  end if;
  if p_format = 'weekly' then
    prm := jsonb_build_object('levels', coalesce((r.params->>'levels')::int, 4), 'width', coalesce((r.params->>'width')::int, 13),
             'height', coalesce((r.params->>'height')::int, 11), 'difficulty', coalesce(r.params->>'difficulty', 'normal'),
             'mods', r.mods, 'rule', r.rule_id, 'metric', r.metric);
    per_name := public.weekly_current()->>'period';
  else
    prm := jsonb_build_object('levels', 2, 'width', 13, 'height', 11, 'difficulty', 'normal',
             'mods', r.mods, 'rule', r.rule_id, 'metric', 'levels');
    per_name := public.daily_current()->>'period';
  end if;
  insert into public.ranked_runs (player_id, difficulty, seed, params, game_version, kind, period, test)
  values ((select auth.uid()), prm->>'difficulty', new_seed, prm, p_game_version, p_format, per_name, true)
  returning id into rid;
  return jsonb_build_object('run_id', rid, 'seed', new_seed, 'params', prm, 'period', per_name, 'test', true);
end $$;

do $$
declare f text;
begin
  foreach f in array array['admin_test_rules()', 'admin_start_rule_run(text,text,text)']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
