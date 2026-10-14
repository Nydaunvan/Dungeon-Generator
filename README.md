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

<p align="center"><img src="docs/img/en-ligne.jpg" alt="Mode en ligne" width="48%"> <img src="docs/img/creation.jpg" alt="Éditeur de donjon" width="48%"></p>

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
Rendu Forward+ (Vulkan) avec repli automatique sur OpenGL. Quatre niveaux de qualité (Faible, Moyen, Élevé, Ultra) et un réglage Auto qui s'adapte à la machine. Les effets (occlusion ambiante, reflets, relief, brouillard volumétrique, étalonnage des couleurs) se règlent un par un dans **⚙ Paramètres › Graphismes**. F3 affiche, sur une seule ligne tout en haut à gauche (sans cadre), les images par seconde, la mémoire et le nombre d'appels de dessin.

**Effets de sorts** : l'éditeur de sorts propose, pour chaque sort, un effet visuel au choix (aujourd'hui le cristal, l'orbe de mana et le rayon pour les sorts d'arcane de dégâts), avec une teinte (bleu et blanc par défaut, comme l'icône d'Éclat Arcanique), une intensité et un aperçu. Ces effets avancés (lumière HDR, particules GPU, distorsion, cercle runique gravé au sol (24 runes du futhark), lumière qui éclaire la brume) s'adaptent au niveau graphique ; l'effet d'origine reste disponible.

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
| `scripts/` | Le code du jeu (GDScript) : règles, donjon 3D, interface, services et éditeur de donjon. |
| `scenes/` | Les scènes Godot du jeu. |
| `data/` | Les données du jeu : configuration, textes, réglages graphiques, journal des versions. |
| `assets/` | Les ressources utilisées par le jeu : images, textures, sons, musiques, polices. |
| `assets_src/` | Les images sources, d'origine, dont sont tirées certaines ressources ; le jeu ne les charge pas. |
| `supabase/` | Le schéma de la base de données de la partie en ligne. |
| `tools/` | Les outils de développement : vérifications, captures, génération de ressources, préparation des publications. |
| `installer/` | L'installateur Windows et l'entrée de menu Linux. |
| `.github/` | La publication automatique des versions. |
| `docs/` | La documentation technique et les images du README. |

Le détail des sous-dossiers est dans la [documentation technique](docs/TECHNIQUE.md#sous-dossiers). La branche `migration/donnees` est la branche de développement : les versions sont publiées depuis elle.
