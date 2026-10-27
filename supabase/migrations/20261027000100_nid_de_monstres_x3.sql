-- Défi de la semaine « Nid de monstres » : le butin du boss est toujours légendaire, avec trois fois plus de chances d'être mythique
-- que la difficulté (le taux fixe de 25 % disparaît : en difficulté faible le mythique reste rare). Texte affiché dans le jeu.
-- Le taux lui-même est dans le jeu : data/game_constants.json, modificateur « mod_horde2 » (champ bossMythicMult = 3).
update public.weekly_rules
   set desc_fr = '40 % de monstres en plus et davantage de groupes ; le butin du boss est toujours légendaire, avec trois fois plus de chances d''être mythique.',
       desc_en = '40% more monsters and more groups; boss loot is always legendary, with three times the usual chance of being mythic.'
 where rule_id = 'den';
