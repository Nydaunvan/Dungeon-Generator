# Kit volcanique « Les Forges du monde brisé » — remplacer le générateur par de vrais modèles

Aujourd'hui ces modules sont **générés par code** (`scripts/dungeon/kit_geometry_lava.gd`) : blocs de basalte subdivisés dont les sommets sont déplacés par un bruit 3D,
fer noirci en ferrures. **Ce n'est pas de l'art final** : c'est un remplaçant technique fidèle aux cotes. Déposer un GLB du même nom dans ce dossier le remplace
automatiquement (KitDecor : GLB d'abord, sinon génération). Repères et cotes identiques au kit gothic (assets/kit/gothic/LISEZMOI.md) : 1 case = 4 u,
origine au sol au milieu de l'arête, +Y en haut, +Z vers la case d'où on voit le module, mur en Z = -0,04.

| Fichier | Fonction | Encombrement (u) | Contraintes |
|---|---|---|---|
| arch.glb | portail trapézoïdal de couloir droit | 4,0 × 4,0 × 0,8 | baie libre ≥ 3,0 large (3,04 actuel) × 3,5 haut, montants à fruit, linteau massif, rien dans la baie |
| portal_room.glb | entrée de salle | 4,0 × 4,0 × 0,9 | idem, plus lourd, plaque de forge au linteau |
| portal_door.glb | encadrement de porte | 4,0 × 4,0 × 0,9 | idem ; la herse reste visible et ne traverse pas les montants |
| portal_stair.glb | encadrement d'escalier | 4,0 × 4,0 × 0,9 | idem ; ouverture ≥ 3,0 × 3,4 |
| pillar.glb | pilier d'angle, orgues hexagonaux groupés | ≤ 0,8 × 4,0 × 0,8 | origine au sol au sommet d'angle, touche le plafond (y = 4) |
| cornice.glb | corniche anguleuse massive | 4,0 × 0,8 × 0,3 | raccord bord à bord, ne gêne pas le passage |
| plinth.glb | plinthe lourde | 4,0 × 0,35 × 0,2 | raccord bord à bord |
| torch_bracket.glb | console de torche (basalte + fer) | 0,3 × 0,55 × 0,2 | aucune lumière dans le modèle ; au point d'accroche de la torche |
| ornament.glb | plaque de forge gravée, rare | 0,7 × 1,0 × 0,1 | centrée sur un pan sans torche |

Matériaux : ne livrer que des couleurs unies ou des teintes ; la pierre PBR du thème (`assets/themes/lava2_hd|lite`) est projetée en triplanaire sur les surfaces non métalliques.
Surfaces métalliques (metallic ≥ 0,3) : conservées telles quelles (fer noirci, bronze ancien).
