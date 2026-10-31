# Thème « gothic » : textures à fournir

Le thème `gothic` (Atlas Noir, test) fonctionne dès maintenant avec des matériaux **provisoires** dérivés de la pierre `stone`
(niveaux de gris contrastés et teinte froide, voir `ThemeMaterials._gothic_derived`). Ce ne sont PAS les textures définitives.
Dès que les dossiers ci-dessous existent, ils sont utilisés automatiquement à la place (aucun code à changer).

## Dossiers et fichiers attendus

`assets/themes/gothic_hd/` (2048 × 2048) et `assets/themes/gothic_lite/` (1024 × 1024), pour chaque `<part>` dans `wall`, `floor`, `ceil` :

| Fichier | Contenu |
|---|---|
| `<part>_albedo.jpg` | couleur sans lumière ni ombre, sRGB |
| `<part>_normal.png` | relief, OpenGL (Y+), espace tangent |
| `<part>_orm.jpg` | R = occlusion, G = rugosité, B = métal (0 pour la pierre) |

Soit 9 fichiers par dossier, 18 au total.

## Contraintes

- Parfaitement **répétables** (aucun raccord visible en tuilage horizontal et vertical), 1 tuile = 1 case (4 u) ou un nombre entier de tuiles par case.
- **Murs** : gros blocs anciens irréguliers, anthracite et gris froid, joints profonds.
- **Sol** : dalles gris foncé, usure, variation discrète, humidité localisée (rugosité plus basse par endroits).
- **Plafond** : pierres sombres, relief marqué, texture nettement distincte de celle des murs.
- Couleurs peu saturées ; aucune ombre ni lumière peintes dans l'albédo.
- Mêmes noms et mêmes dossiers `_hd` / `_lite` que les autres thèmes (le dossier `_lite` est exclu des exports de bureau).
