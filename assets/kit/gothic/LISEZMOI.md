# Kit d'architecture gothique : modèles à fournir

`scripts/dungeon/kit_decor.gd` pose automatiquement ces modules sur les niveaux du thème `gothic`. **Un module dont le fichier est absent n'est pas posé**
(aucun remplaçant provisoire en jeu). Fichiers attendus dans ce dossier, format glTF binaire (`.glb`), matériaux PBR intégrés (sinon une pierre sombre neutre est appliquée) :

| Fichier | Rôle | Encombrement maximal (L × H × P, unités du jeu) | Origine et orientation |
|---|---|---|---|
| `plinth.glb` | plinthe de pierre, un pan de mur entier | 4,0 × 0,35 × 0,22 | milieu du pan, au sol ; +Z vers l'intérieur de la case ; bords à bord (raccord au pan voisin) |
| `pilaster.glb` | pilastre mural, sur la jonction de deux pans | 0,9 × 4,0 × 0,45 | centré sur la jonction, au sol ; +Z vers l'intérieur |
| `pillar.glb` | pilier sculpté, aux angles (là où le jeu pose ses colonnes) | 0,8 × 4,0 × 0,8 | centré, au sol |
| `arch.glb` | arche en ogive entre deux cases d'un couloir droit | 4,0 × 4,0 × 0,5 | centrée sur l'arête, au sol ; +Z dans le sens de marche ; ouverture libre **≥ 3,0 de large et ≥ 3,5 de haut** |
| `door_frame.glb` | encadrement de porte (la herse reste visible) | 4,0 × 4,0 × 0,6 | centré sur l'arête de la porte, +Z vers la case d'où on la voit ; ouverture ≥ 3,0 × 3,4 |
| `stair_frame.glb` | encadrement d'escalier | 4,0 × 4,0 × 0,7 | comme `door_frame` ; ouverture ≥ 3,0 × 3,4 |
| `bracket.glb` | support de torche en fer forgé | 0,3 × 0,5 × 0,35 | au point d'accroche de la torche (milieu de la hauteur 2,5 u), +Z vers l'intérieur |
| `ornament.glb` | élément décoratif mural discret | 0,7 × 1,0 × 0,1 | centré sur le pan, au sol ; +Z vers l'intérieur ; posé sur environ 1 pan sur 4 sans torche |

## Contraintes générales

- 1 case = 4 × 4 × 4 u ; murs de zéro épaisseur à l'arête de la case : un module reste **dans** sa case, profondeur ≤ 1,9 u (moins de la moitié de la case).
- Aucune collision (le jeu n'utilise pas la physique 3D) ; aucune lumière dans les modèles (les torches viennent de `TorchLayer`).
- Faible coût : moins de 2 000 triangles par module (instances en MultiMesh par bloc de 8 × 8 cases).
- Un module ne doit jamais masquer un passage, une porte ou un monstre (taille du plus grand monstre : 1,85 u).
- Placement 100 % déterministe (coordonnées + identifiant du niveau), désactivable : `KitDecor.enabled = false` ou `"kit": false` dans le niveau.
