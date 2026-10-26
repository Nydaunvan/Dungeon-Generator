-- Défi de la semaine « Nid de monstres » : butin du boss toujours légendaire (75 %) ou mythique (25 %) — texte affiché dans le jeu.
-- Les taux eux-mêmes (bossLegendaryPct, bossMythicPct) sont dans le jeu : data/game_constants.json, modificateur « mod_horde2 ».
update public.weekly_rules
   set desc_fr = '40 % de monstres en plus et davantage de groupes ; le butin du boss est toujours légendaire (75 %) ou mythique (25 %).',
       desc_en = '40% more monsters and more groups; boss loot is always legendary (75%) or mythic (25%).'
 where rule_id = 'den';
