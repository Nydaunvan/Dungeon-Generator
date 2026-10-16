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
- **Exploration 3D** au pas à pas : couloirs, portes et grilles, escaliers, niches, torches, fontaines, pièges (pointes d'acier, vapeur verte, mécanisme mural à fléchettes, fosse béante et cercle de runes de flammes en vrai volume, inoffensifs une fois désamorcés, avec un son propre à chaque piège) et énigmes, avec carte du niveau.
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

**Effets de sorts** : chaque sort a son propre graphisme, cohérent avec son nom et son école, et l'éditeur de sorts propose un effet visuel au choix par école et par mode, avec une teinte, une intensité et un aperçu. Ces effets avancés (lumière HDR, particules GPU, plasma et flammes en shader, distorsion de l'air, motifs gravés au sol, lumière qui éclaire la brume) s'adaptent au niveau graphique ; l'effet d'origine reste disponible. Les 61 sorts ont leur propre effet : nature (épine venimeuse, ronces entravantes, foudre sauvage, essaim de guêpes, bourgeon de vie, souffle de la forêt), arcane (cristal, orbe, rayon, ralentissement qui fige le temps, flèche runique, volée de cinq flèches, pluie de flèches stellaires), feu (boule de feu, météore, colonne de feu), glace (javelot de givre, tempête de grêle), sacré (pilier de lumière, châtiment, jugement, aura, flammes purificatrices, anathème) et soins (soin, célérité, bénédiction, guérison de groupe, sanctuaire), ombre (frappe fatale, drain de vie, ombre fugace, exécution, lame silencieuse, coup dans l'ombre, mille entailles, malédiction, pacte obscur, apocalypse), bardes (note perçante, souffle, armure de vers, cri de guerre, lame de l'épopée, berceuse, ballade, requiem, dissipation) et coups physiques (coup puissant, tir précis, attaque sournoise, rage, frénésie, coup décisif, fureur sanglante, frappe discordante, coup bas, poison de lame, frappe du croisé, danse des lames, tourbillon, pas de la lame, danse mortelle). Les monstres qui ont une capacité spéciale la lancent avec un vrai effet : le sort part du monstre vers le héros visé (projectile, pluie, éclat ou griffes selon le sort, aux couleurs de l'école). L'aperçu de l'éditeur montre les deux sens de tir.

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
