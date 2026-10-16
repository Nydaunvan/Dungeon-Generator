-- Défi de la semaine « Verre brisé » : groupes de 2 monstres au maximum et critique du groupe +5 % (texte affiché dans le jeu).
-- Les règles elles-mêmes (maxGroupSize, critChanceBonus) sont dans le jeu : data/game_constants.json, modificateur « mod_glass ».
update public.weekly_rules
   set desc_fr = 'PV max du groupe divisés par deux, mais chances de coup critique +5 % et des groupes de 2 monstres au maximum (jamais 3) : un faux pas peut être fatal.',
       desc_en = 'Party max HP halved, but critical hit chance +5% and monster groups of 2 at most (never 3): one misstep can be fatal.'
 where rule_id = 'glass';
