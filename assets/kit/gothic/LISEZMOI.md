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

## Herse et encadrement de porte (mesures en rendu, thème gothic)

- La grille de herse (texture `assets/ui/door_grille.png`, plan de 4 u posé sur l'arête) a des barres jusqu'à ± 1,91 u ; l'ouverture de `door_frame.glb` fait 3,11 u (montants de 1,555 à 1,995).
  Les barres pénètrent donc d'environ 0,36 u dans chaque montant (le plan z = 0 traverse l'épaisseur du montant, de - 0,28 à + 0,29).
- Aucun défaut visible dans les captures (`tools/render_gothic.tscn` : vues de face, obliques, depuis la case de la porte, herse à mi-course, de côté) :
  la partie enfoncée est cachée par la pierre, la herse se lit comme coulissant dans des rainures et monte dans le linteau pendant l'animation.
  Aucun décalage ni réglage n'a donc été ajouté au code (largeur et animation de la herse inchangées).
- Amélioration artistique possible (nouveau GLB, non bloquante) : creuser une rainure de 0,4 u de large et 0,1 u de profondeur sur la face intérieure des montants
  (x de ± 1,555 à ± 1,95, au plan z = 0) pour justifier la pénétration des barres.

## Ce que le pack actuel ne contient pas (à fournir dans une prochaine version des GLB)

- **Normales** : les 8 GLB livrés ne contiennent que `POSITION` (ni `NORMAL`, ni `TEXCOORD_0`, ni tangentes). Le jeu recalcule des normales par face au chargement
  (`KitDecor.flat_normals`, ombrage plat) : l'éclairage est correct, mais sans biseaux lissés. À exporter : normales (lissées ou non) et UV 0.
- **UV** : sans UV, la pierre du thème est projetée en triplanaire (monde, 1 tuile = 2 u, mélange net). Avec des UV dépliés, des textures propres au kit seraient possibles.
- **Arche gothique** : `arch.glb` est un portique rectangulaire (deux montants et un linteau plat), pas une ogive. À remplacer par une vraie ogive de même encombrement
  (4 × 4 × 0,5 u, ouverture libre ≥ 3,0 u de large et 3,5 u de haut au sommet de la clé : une ogive laisse moins de hauteur sur les côtés, la baie doit rester dégagée sur
  ± 1,5 u de large jusqu'à 3,5 u de haut, soit un tympan plein au-dessus).
- **Matériaux** : les pierres du pack sont des couleurs unies ; le jeu y applique temporairement la pierre du thème (surfaces dont `metallic` < 0,3). Le fer et le bronze
  (`metallic` ≥ 0,3) gardent le matériau du GLB.

## V2 : géométrie procédurale de remplacement et GLB à fournir

Le jeu génère désormais lui-même (`scripts/dungeon/kit_geometry.gd`) une géométrie gothique de remplacement, technique et non définitive.
Un GLB portant le même nom dans `assets/kit/gothic/` remplace automatiquement la version procédurale (`KitGeometry.PROCEDURAL`).
Tous : origine au centre de l'arête de case, face avant vers +z, x en largeur, y en hauteur (0 = sol, 4 = plafond), épaisseur ≤ 0,5 u, normales et UV 0 exportées.

| Fichier | Rôle | Encombrement | Baie libre |
|---|---|---|---|
| `ogive.glb` | arc brisé sur arête de couloir ou de salle | 4 × 4 × 0,5 | ± 1,55 u jusqu'à y ≈ 0,85, sommet ≥ 3,5 u ; tympan plein au-dessus |
| `portal_room.glb` | cadre d'entrée de salle (clé de voûte, impostes) | 4 × 4 × 0,5 | ± 1,5 u, sommet ≥ 3,5 u |
| `portal_door.glb` | cadre de porte à herse | 4 × 4 × 0,5 | ± 1,5 u ; rainure de 0,4 × 0,1 u sur la face intérieure des montants |
| `portal_stair.glb` | cadre d'escalier | 4 × 4 × 0,5 | ± 1,5 u |
| `rib.glb` | nervure de voûte en saillie au plafond | 4 (long.) × 0,3 × 0,3 | sans objet |
| `cornice.glb` | corniche haute continue | 4 × 0,25 × 0,25 | sans objet |

Textures nouvelles utiles : pierre à joints moins répétitifs (variante « usée » et variante « mousse ») et dallage de sol avec mortier plus marqué. La variation de teinte par face (`LevelBuilder._vary`) atténue la répétition mais ne la supprime pas.

## V3 : claveaux, support de torche et GLB prévus

- **Ogive** : les arcs générés ont de vrais claveaux (voir la section V4 ci-dessous). Un GLB doit faire mieux :
  claveaux sculptés irréguliers, clé de voûte, chanfreins, profondeur ≥ 0,25 u.
- **`torch_bracket`** (remplace `bracket` quand il existe) : platine en ogive clouée au mur, volute de fer qui porte le pied du manche, collerette. Fer sombre (métal 0,55, rugosité 0,52).
  Repère de `TorchLayer` : origine au point d'accroche, +Z vers l'intérieur, mur en Z = -0,04, manche incliné de ≈ 23° (bas en (0, -0,24, 0,045)). La platine, le bras et l'anneau de la torche elle-même
  sont dessinés par `TorchLayer` : un modèle de remplacement doit les prolonger sans les doubler. **Aucune lumière dans le GLB** (le jeu pose la sienne). Matériau métallique (`metallic` ≥ 0,3), sinon le jeu y applique la pierre.
- **`arch.glb`** : le fichier du premier pack est un portique rectangulaire. Un `arch.glb` en ogive n'est utilisé que si son nom est listé dans `kit_v3.json` (champ `v3`), pour ne pas confondre les deux.
  Mêmes règles que `ogive` (4 × 4 × 0,5 ; baie libre ± 1,5 u jusqu'à 3,5 u).
- `portal_room.glb`, `portal_door.glb`, `portal_stair.glb`, `rib.glb`, `cornice.glb`, `torch_bracket.glb` : le nom suffit, ils remplacent le module généré (aucune entrée dans `kit_v3.json`).

## V4 : ogive en archivolte

L'ogive et les portails générés (`KitGeometry`) ont changé : baie de 3,0 u, 3,48 u au sommet, archivolte à trois membres (largeur radiale 0,20 + 0,17 + 0,09 u, ressauts jusqu'à 0,34 u de part et d'autre du plan du mur), 14 claveaux par moitié et par membre,
arête de baie chanfreinée, clef en saillie. Encombrement : 4 × 4 × ≤ 0,86 u. Ces modules restent **procéduraux** : la forme est juste (silhouette, proportions, claveaux, chanfreins), mais ni sculptée, ni irrégulière pierre par pierre ;
un GLB du même nom les remplace toujours (mêmes contraintes de baie libre qu'avant).
