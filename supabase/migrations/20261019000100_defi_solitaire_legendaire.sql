-- Défi de la semaine « Héros solitaire » : deux niveaux seulement, butin doublé et entièrement légendaire (modificateur mod_legend),
-- monstres un peu plus costauds. À appliquer APRÈS la publication de la version du jeu qui connaît `mod_legend`.
update public.weekly_rules
   set mods = '["mod_solo", "mod_legend"]'::jsonb,
       params = '{"levels": 2}'::jsonb,
       desc_fr = 'Un seul héros part à l''aventure, avec deux fois plus de PV et de dégâts (attaques et sorts). Deux niveaux seulement, un butin doublé et entièrement légendaire, mais des monstres un peu plus costauds (+25 % de PV, +15 % de dégâts).',
       desc_en = 'A single hero ventures forth, with twice the HP and damage (attacks and spells). Only two levels, doubled and fully legendary loot, but slightly tougher monsters (+25% HP, +15% damage).'
 where rule_id = 'solo';
