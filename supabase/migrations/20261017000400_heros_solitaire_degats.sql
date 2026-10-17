-- Héros solitaire : dégâts ×2 (attaques et sorts) en plus des PV ×2 — description affichée dans le jeu.
update public.weekly_rules
   set desc_fr = 'Un seul héros part à l''aventure, avec deux fois plus de PV et deux fois plus de dégâts (attaques et sorts).',
       desc_en = 'A single hero ventures forth, with twice the HP and twice the damage (attacks and spells).'
 where rule_id = 'solo';
