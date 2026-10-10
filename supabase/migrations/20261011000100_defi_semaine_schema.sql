-- Dungeon Generator — Défi de la semaine (1/2) : le genre « weekly » est accepté, les périodes peuvent être des semaines ISO (2026-W41).
-- Les parties du Défi de la semaine n'ont pas de « jour » (colonne null) : l'index « un essai par jour » (player_id, kind, day) ne s'applique
-- donc qu'au Hardcore du mois, et le Défi de la semaine a des essais illimités (dans la limite de 40 parties lancées par 24 h).
alter table public.ranked_runs drop constraint ranked_runs_kind_check, add constraint ranked_runs_kind_check check (kind in ('difficulty', 'hardcore_month', 'weekly'));
alter table public.ranked_periods drop constraint ranked_periods_kind_check, add constraint ranked_periods_kind_check check (kind in ('hardcore_month', 'weekly')),
  drop constraint ranked_periods_period_check, add constraint ranked_periods_period_check check (period ~ '^[0-9]{4}-([0-9]{2}|W[0-9]{2})$');
alter table public.ranked_runs drop constraint ranked_runs_periode_coherente, add constraint ranked_runs_periode_coherente check (
  (kind = 'difficulty' and period is null and day is null)
  or (kind = 'weekly' and period is not null and day is null)
  -- (les parties de test du Hardcore n'ont pas de jour : elles ne consomment pas l'essai du joueur)
  or (kind = 'hardcore_month' and period is not null and (day is not null or test)));
