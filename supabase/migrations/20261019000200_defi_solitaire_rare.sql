-- Défi de la semaine « Héros solitaire » (v2) : donjon de 15 × 15 sur deux niveaux, héros parti avec une arme rare, équipement trouvé rare au minimum,
-- butin nettement plus abondant, dégâts +1/3 (au lieu de ×2), PV ×2, monstres un peu plus costauds.
-- À appliquer APRÈS la publication de la version du jeu qui connaît ces règles (mod_legend « Butin de choix » et dmgMult 1,33).
update public.weekly_rules
   set mods = '["mod_solo", "mod_legend"]'::jsonb,
       params = '{"levels": 2, "width": 15, "height": 15}'::jsonb,
       desc_fr = 'Un seul héros part à l''aventure, avec une arme rare, deux fois plus de PV et un tiers de dégâts en plus (attaques et sorts). Le donjon fait 15 × 15 cases sur deux niveaux et contient beaucoup plus de butin : tout l''équipement trouvé est au moins rare (épique, légendaire et mythique restent possibles). Les monstres sont un peu plus costauds (+25 % de PV, +15 % de dégâts). À la fin de la partie, pas de village ni de donjon plus difficile : on revient directement au mode en ligne.',
       desc_en = 'A single hero ventures forth with a rare weapon, twice the HP and one third more damage (attacks and spells). The dungeon is 15 × 15 tiles over two levels and holds much more loot: all gear found is rare at the very least (epic, legendary and mythic are still possible). Monsters are slightly tougher (+25% HP, +15% damage). When the run ends there is no village and no harder dungeon: you go straight back to the online mode window.'
 where rule_id = 'solo';
