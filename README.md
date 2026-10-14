<p align="center"><img src="docs/img/epee.png" alt="L'épée du jeu" width="460"></p>

<h1 align="center">Éditeur de Donjon</h1>
<p align="center"><em>Créez, explorez, survivez.</em></p>

<p align="center">
<img alt="Version" src="https://img.shields.io/github/v/release/Nydaunvan/Dungeon-Generator?include_prereleases&label=version">
<img alt="Moteur" src="https://img.shields.io/badge/Godot-4.7-478cbf">
<img alt="Plateformes" src="https://img.shields.io/badge/Windows%20%7C%20Linux-ex%C3%A9cutable-444">
</p>

Un jeu de donjon en vue subjective et en 3D : on mène un groupe de quatre héros dans des labyrinthes générés au hasard ou créés soi-même, on combat, on récupère du butin et on descend toujours plus profond. C'est un jeu à part entière, écrit en GDScript sous Godot Engine 4.7.

<p align="center"><img src="docs/img/accueil.jpg" alt="Écran d'accueil" width="48%"> <img src="docs/img/combat.jpg" alt="Combat contre un homme-lézard" width="48%"></p>

**▶ Télécharger la dernière version : [Releases](https://github.com/Nydaunvan/Dungeon-Generator/releases)** (installateur Windows, archive Windows ou Linux). Le jeu se met ensuite à jour tout seul : il ne télécharge que les fichiers modifiés.

## Le jeu
- **Exploration 3D** au pas à pas : couloirs, portes et grilles, escaliers, niches, torches, fontaines, pièges et énigmes, avec carte du niveau.
- **Un groupe de quatre héros** : caractéristiques, équipement, sacs, évolutions et arbre de talents.
- **Combat au tour par tour** avec jauges d'initiative, sorts et effets visuels en 3D, statuts, monstres de groupe et boss.
- **Donjons aléatoires** réglables (difficulté, taille, nombre de niveaux) et **éditeur de niveaux** intégré ; les donjons se partagent par code.
- **Village** : forge, Maître des Talents, marchands itinérants et boutique.
- **Sept thèmes** de décor (matériaux, éclairage et ambiance propres à chacun), avec parfois du brouillard.
- **Français et anglais**, guide du jeu et tutoriel intégrés, touches réassignables.

## En ligne (facultatif)
Le jeu reste entièrement jouable hors ligne. Avec un compte, on peut partager ses donjons, relever les défis, jouer des parties classées vérifiées (chaque partie est rejouée côté serveur), tenter le Hardcore du mois, gagner des badges, titres et cadres cosmétiques, et discuter avec les autres joueurs.

## Graphismes
Rendu Forward+ (Vulkan) avec repli automatique sur OpenGL. Quatre niveaux de qualité (Faible, Moyen, Élevé, Ultra) et un réglage Auto qui s'adapte à la machine. Les effets (occlusion ambiante, reflets, relief, brouillard volumétrique, étalonnage des couleurs) se règlent un par un dans **⚙ Paramètres › Graphismes**. F3 affiche le compteur d'images par seconde et la mémoire utilisée.

## Commandes
Au clavier (touches physiques, libellés AZERTY) : ↑/Z avancer, ↓/S reculer, Q/D pas de côté, ←/A et →/E tourner. Tout est réassignable dans les paramètres, et des boutons à l'écran permettent le jeu tactile.

## Lancer depuis les sources
1. Cloner le dépôt : `git clone https://github.com/Nydaunvan/Dungeon-Generator.git`
2. Ouvrir `project.godot` dans [Godot 4.7](https://godotengine.org/) et lancer le projet (F5).

## Pour les développeurs
Structure du code, vérifications automatiques, publication des versions, partie en ligne et rejeu vérifié : voir la [documentation technique](docs/TECHNIQUE.md).

## Organisation du dépôt
| Dossier | Contenu |
|---|---|
| `scripts/` | Tout le code GDScript du jeu. `rules/` : règles sans affichage (personnages, combat, générateur de donjon, état de partie, hasard et horloge déterministes, journal d'actions). `dungeon/` : couloir 3D (murs, portes, torches, brouillard, fontaines, sprites des monstres, salle de combat). `game/` : liaison entre règles et affichage (combat, actions, pièges et fenêtres de décision, monstres errants). `ui/` : fenêtres et interface (sac, forge, paramètres, comptes, défis, chat…). `core/` : services (données, textes, réglages graphiques, sauvegardes, son, mise à jour, compte en ligne, rejeu). `admin/` : éditeur de donjon et outils d'administration. |
| `scenes/` | Les quatre scènes Godot : démarrage, accueil, partie, administration. |
| `data/` | Données du jeu : configuration par défaut, talents des classes, constantes, niveaux de qualité graphique, journal des versions, `lang/` (textes français et anglais, guide, tutoriel) et la configuration publique du compte en ligne. |
| `assets/` | Ressources utilisées par le jeu (environ 90 Mo) : `themes/` textures des sept thèmes de décor (murs, sols, plafonds, fontaine), `monsters/` sprites des monstres et boss, `portraits/` portraits des héros, `icons/` icônes d'objets, de sorts et de classes, `ui/` éléments d'interface (cadres, boutons, emplacements), `home/` écran d'accueil, `fonts/`, `music/`, `sounds/`, `sheets/` planches d'objets et de monstres, `misc/` textures diverses (dont l'étal du marchand), `splash.png` et `app_icon.png`. |
| `assets_src/` | Images sources de l'épée du jeu (taille d'origine). Le jeu ne les charge pas : seules les versions retaillées de `assets/ui/` sont exportées. |
| `supabase/migrations/` | Schéma de la base en ligne, un fichier SQL par évolution, à appliquer dans l'ordre : profils, donjons partagés, défis, classements, parties classées, récompenses, rôles. |
| `tools/` | Outils de développement, hors jeu : vérifications automatiques (`check_*`), captures d'écran (`shot_*`), génération de textures et d'icônes (`gen_*`, `make_icon.py`), préparation des publications (versions, notes, paquets, VirusTotal) et vérificateur des parties classées. |
| `installer/` | Installateur Windows (script Inno Setup, icône) et entrée de menu pour Linux. |
| `.github/workflows/` | Publication automatique (exécutables, paquets, installateur) et vérification des parties classées. |
| `docs/` | Documentation technique et images du README. |
| `project.godot`, `export_presets.cfg` | Projet Godot (version du jeu incluse) et préréglages d'export Windows et Linux, générés par `tools/gen_export_presets.py`. |

La branche `migration/donnees` est la branche de développement : les versions sont publiées depuis elle.
