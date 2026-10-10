-- Le Hardcore du mois compte 5 niveaux : le palier « 8 niveaux » est inatteignable. On le retire (badge et récompense).
create or replace function public.award_run(p_run_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  r public.ranked_runs%rowtype;
  mult numeric;
  xp int;
begin
  select * into r from public.ranked_runs where id = p_run_id and status = 'verified' and not test;
  if not found then
    return;
  end if;
  mult := case r.difficulty when 'easy' then 1 when 'normal' then 1.5 when 'hard' then 2 else 3 end;
  xp := floor(40 * r.score * mult)::int;
  if xp > 0 then
    perform public._give_xp(r.player_id, 'partie', r.id::text, xp);
  end if;
  if r.kind = 'hardcore_month' then
    perform public._give_xp(r.player_id, 'hardcore_essai', r.id::text, 50);
    perform public._give_badge(r.player_id, 'hc_participant', '');
    if r.score >= 3 then perform public._give_badge(r.player_id, 'hc_profondeur_3', ''); perform public._give_xp(r.player_id, 'hardcore_palier3', '', 150); end if;
    if r.score >= 5 then perform public._give_badge(r.player_id, 'hc_profondeur_5', ''); perform public._give_xp(r.player_id, 'hardcore_palier5', '', 400); end if;
  end if;
end $$;

with gone as (select id from public.badges where id = 'hc_profondeur_8' and not exists (select 1 from public.player_badges pb where pb.badge_id = 'hc_profondeur_8'))
delete from public.badges b using gone where b.id = gone.id;
