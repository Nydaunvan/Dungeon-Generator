# Thème « gothic » : textures (V3, V4)

Les 18 fichiers de `assets/themes/gothic_hd/` (2048 × 2048) et `assets/themes/gothic_lite/` (1024 × 1024) sont des textures **procédurales**,
produites par `python3 tools/gen_gothic_textures.py` (reproductible : graines fixes). Elles remplacent le premier pack, qui avait une grille de briques
parfaitement régulière (environ 0,5 × 0,2 u), des joints de 10 % de la surface, un bruit nuageux et un raccord horizontal visible.

**Ce ne sont PAS des textures peintes ou scannées.** Elles sont nettement meilleures que le premier pack, mais un travail manuel (scan de pierre réelle ou
sculpture de haute poly cuite en normales) reste la référence à atteindre (voir « Dépendance artistique » ci-dessous).

## Contenu et échelle

Une tuile = 4 × 4 u = une case (`GOTHIC_WALL_REPEAT` / `GOTHIC_FLOOR_REPEAT` / `GOTHIC_CEIL_REPEAT` = 1). Densité : 512 px/u (HD), 256 px/u (lite).
Les UV vont de 0 à 1 par case : le raccord se fait aux bords de case, tout le bruit est périodique et les blocs sont calculés modulo la tuile.

| Pièce | Contenu |
|---|---|
| `wall` | grosses pierres irrégulières (V4 : assises de 0,30 à 0,92 u, blocs de 0,55 à 2,15 u, décalés), joints creusés et ébréchés avec ombre douce à leur pied (fond gris-bleu, pas noir), micro-relief au ciseau, teinte propre à chaque pierre |
| `floor` | dalles irrégulières (Voronoï, 6 × 6 par tuile), anthracite plus foncé que les murs ; V4 : l'humidité est dans la rugosité (≈ 0,5 au lieu de 0,8 aux endroits humides, large et irrégulière, plus marquée le long des joints) et à peine dans la couleur (−7 %) |
| `ceil` | grandes pierres taillées grossièrement (4 × 4 par tuile), plus sombres, relief deux fois plus marqué, distinctes des murs |

Formats : albédo JPG (sRGB, sans lumière peinte), normale PNG OpenGL (Y+), ORM JPG (R = occlusion, G = rugosité, B = métal = 0).

## Contrôles automatiques

`tools/check_gothic.tscn` vérifie : tailles, raccord périodique (écart entre bords opposés comparé à l'écart entre pixels voisins), saturation faible,
métal nul, rugosité 0,4 à 0,95, joints de 1 à 9 % de la surface du mur, ordre de luminosité mur > sol > plafond.

## Dépendance artistique (non résolue)

À produire à la main pour un résultat définitif, aux mêmes noms, tailles et dossiers (le jeu les prend automatiquement) :
- `wall` : pierre réelle à grain fin, avec fissures et épaufrures propres à chaque bloc (le bruit procédural n'a pas de logique de taille de pierre) ;
- `floor` : dalles usées par le passage, joints comblés de terre, rugosité peinte à la main ;
- `ceil` : voûte en moellons ou en briques, variante moussue.
Variantes utiles : une seconde tuile de mur (usée / humide) pour casser la répétition par case, qui existe encore (toutes les cases de mur sont identiques, seule la teinte varie).
