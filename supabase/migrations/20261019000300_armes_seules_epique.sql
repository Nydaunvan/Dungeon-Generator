-- Défi « Armes seules » : chaque héros part avec une arme épique, tout l'équipement trouvé ou vendu est rare au minimum (chances habituelles au-dessus).
-- À appliquer APRÈS la publication de la version du jeu qui connaît `minRarity` / `startWeaponRarity` sur mod_nospells.
update public.weekly_rules
   set desc_fr = 'Aucun sort ni capacité : seules les armes comptent. En contrepartie, chaque héros part avec une arme épique et tout l''équipement trouvé ou vendu par les marchands est au moins rare (épique, légendaire et mythique restent possibles, aux chances habituelles).',
       desc_en = 'No spells or abilities: only weapons count. In return, every hero starts with an epic weapon and all gear found or sold by merchants is rare at the very least (epic, legendary and mythic are still possible, at the usual odds).'
 where rule_id = 'nospells';
