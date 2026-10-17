-- Correctif : « Réafficher les parties vues » échouait ("DELETE requires a WHERE clause") car l'API Supabase charge l'extension
-- pg_safeupdate, qui refuse un DELETE sans WHERE. On ajoute une clause toujours vraie.
create or replace function public.admin_suspect_restore() returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  if not public.is_super_admin() then
    raise exception 'acces_refuse';
  end if;
  with del as (delete from public.suspect_seen where true returning 1)
  select count(*) into n from del;
  perform public._staff_log_add('suspect_restore', null, jsonb_build_object('count', n));
  return n;
end $$;
revoke all on function public.admin_suspect_restore() from public, anon;
grant execute on function public.admin_suspect_restore() to authenticated;
