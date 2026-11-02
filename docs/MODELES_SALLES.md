# Modèles 3D des salles — état et cahier des charges GLB

## État actuel (thème gothic)
| Objet | Source | Statut |
|---|---|---|
| Autel (`altar_g`) | maillage procédural `PropGothic.altar` (scripts/dungeon/prop_gothic.gd) | **Provisoire** : volumes chanfreinés, arcatures, colonnettes, corniche, chemin d'autel, calice, livre, plateaux de bougies. À remplacer par un GLB sculpté. |
| Candélabres (`candelabra_g0..2`) | maillage procédural `PropGothic.candelabra` | **Provisoire** : fer forgé (pieds en volute, nœuds, bras en S, bobèches à pointe, cire coulée). 3 variantes. |
| Sol damier / filets / joints | calques 256 px (`_floor_overlay`: `damier_g`, `filets_g`, `joints`) sur la dalle PBR gothic | Intégré, définitif tant qu'aucune texture peinte n'existe. |
| Tapis | texture procédurale `_rug_texture` (128 px/case en gothic) | Intégré ; flou de près : prévoir une texture tissée 1024² tuilable. |
| Autres salles (bibliothèque, armes, cellier, ruine, commune, humide, trésor, repaire, marché) | modèles procéduraux d'origine | **Non refondus** : encore la version d'origine (bois uni, tonneaux simples…). |

Les anciens modèles restent utilisés par les 7 autres thèmes et pour toutes les salles non encore refondues.

## Convention commune (tous les GLB)
- Unités : mètre, Y vers le haut. **Origine au centre de l'emprise, au sol (y = 0)**. **+Z = côté intérieur de la salle** (face visible quand l'objet est contre un mur).
- Une case de jeu = 4 m ; hauteur de salle 4 m. Un objet ne dépasse jamais son emprise déclarée.
- Matériaux PBR métal/rugosité : albedo 2048² (1024² pour le petit mobilier), normal OpenGL 2048², ORM (occlusion/rugosité/métal) 1024² ; UV non chevauchantes ; atlas partagé par famille (pierre, bois ancien, fer forgé, bronze, tissu, cire).
- Pas de lumière, pas de collision, pas de caméra, pas d'animation dans le fichier ; flammes et halos restent gérés par `TorchLayer`/`RoomDecor._flame`. Fournir en option un empty nommé `flame_N` marquant chaque position de flamme.
- 3 niveaux de détail : LOD0 (< 8 m), LOD1 (≈ 40 %), LOD2 (≈ 12 %) nommés `_LOD0/1/2`. Pas de faces cachées ni d'intérieur.
- Format : `.glb` (glTF 2.0 binaire), dans `assets/models/salles/<nom>.glb`.

## Ressources manquantes (à produire par un artiste 3D)
| Modèle | Emprise (L×P×H m) | Budget LOD0 | Textures |
|---|---|---|---|
| autel gothic sculpté | 2,9 × 2,4 × 1,45 | 25 000 tri | pierre 2048² |
| candélabre fer forgé (×3 variantes) | 0,7 × 0,7 × 1,7 | 6 000 tri | fer + cire 1024² |
| lustre fer forgé 8 bougies | Ø 1,2 × 1,3 | 8 000 tri | fer + cire 1024² |
| table longue + banc vieux bois (×2 variantes abîmées) | 2,4 × 0,9 × 0,95 / 2,2 × 0,35 × 0,5 | 5 000 tri | bois 1024² |
| bibliothèque murale pleine hauteur | 2,4 × 0,5 × 3,2 | 12 000 tri | bois + reliures 2048² |
| pupitre à lutrin | 0,7 × 0,6 × 1,3 | 3 000 tri | bois 1024² |
| coffre cerclé de fer | 1,1 × 0,6 × 0,7 | 4 000 tri | bois + fer 1024² |
| tonneau / caisse / jarre / urne (×3 variantes chacun) | Ø 0,8 × 1,0 ; 0,8³ ; Ø 0,6 × 0,9 | 1 500–3 000 tri | bois / terre cuite 512–1024² |
| râtelier d'armes, cadre de bannière, console de pierre, niche murale | 2,0 × 0,5 × 2,2 ; 1,1 × 0,05 × 2,3 ; 0,6 × 0,5 × 0,4 ; 1,0 × 0,4 × 1,8 | 2 000–8 000 tri | atlas pierre / bois / tissu |
| piliers sculptés (fût, base, chapiteau modulaires) | Ø 0,9 × 4,0 (3 pièces) | 6 000 tri | pierre 2048² |
| tapis tissé (texture) | 1024² tuilable | — | albedo + normal |
