-- Clôture des périodes à l'heure : la distribution des récompenses (close_due_periods) est appelée par le vérificateur ; sans parties à
-- vérifier, celui-ci ne tournait que sur le cron de GitHub (irrégulier). La relance de sécurité lance désormais aussi le vérificateur
-- quand une période (semaine, mois) est arrivée à échéance sans être clôturée.
select cron.unschedule('verifier-relance') where exists (select 1 from cron.job where jobname = 'verifier-relance');
select cron.schedule('verifier-relance', '*/3 * * * *',
  $$select public.kick_verifier() where exists (select 1 from public.ranked_runs where status = 'submitted' and submitted_at < now() - interval '90 seconds')
       or exists (select 1 from public.ranked_periods where closed_at is null and ends_at + interval '2 days' < now())$$);
