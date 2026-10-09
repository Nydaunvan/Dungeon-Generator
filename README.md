# Dungeon-Generator (migration Godot 4.7)

Portage du jeu HTML/WebGL « Donjon3D » vers Godot Engine (GDScript, rendu GL Compatibility pour mobile + PC + Web).

## Structure
- `data/` : données extraites du build HTML (config par défaut, talents, constantes)
- `assets/` : textures des 7 thèmes, icônes, portraits, planches (monstres, objets, torches)
- `scripts/core/` : chargement des données (autoload `Data`)
- `scripts/rules/` : moteur de règles sans affichage (formules de stats, puis combat, statuts…)
- `scenes/` : scènes Godot
- `data/quality_presets.json` : niveaux graphiques Faible / Moyen / Élevé / Ultra (menu « ⚙ Paramètres », autoload `Settings` : détection de la machine et adaptation automatique)

## Utilisation
Cloner le dépôt, ouvrir `project.godot` dans Godot 4.7, lancer la scène principale (F5) : la console affiche le donjon chargé et les stats des 4 personnages.

## Plan de migration
1. Données en JSON ✔ 2. Moteur de règles 3. Couloir 3D (✔ murs, torches, portes, escaliers, monstres et objets en sprites) 4. Interface adaptative 5. Boutique/forge/talents 6. Audio 7. Éditeur intégré + sauvegardes + export Web

## Vérifications
- Compilation : `godot --headless --path . res://tools/check_compile.tscn`
- Textes : `python3 tools/check_lang.py`
- Réglages graphiques : `godot --headless --path . res://tools/check_settings.tscn`
- Mise en page mobile (aucun débordement à droite, carte masquée) : `godot --headless --path . res://tools/check_mobile.tscn`
- Touches du clavier (défauts par langue, réassignation, conflits, onglet Commandes) : `godot --headless --path . res://tools/check_keys.tscn`
- Version et journal : `python3 tools/check_version.py`

## Versions et publication
- Le numéro de version est dans `project.godot` (`config/version`, forme `1.30.1`, ou `1.30.1-test1` pour un build de test). Le jeu l'affiche à partir de là (`AppVersion`).
- Journal des versions : `data/changelog.json` (affiché dans le jeu). Les notes de la publication GitHub en sont tirées (`tools/release_notes.py`).
- Publier : pousser sur `migration/donnees` un commit dont le message contient `[exe]` (préversion `v<version>`) ou `[release]` (publication normale). Le workflow « Publication » exporte Windows et Linux en **exécutable + paquets** (voir ci-dessous), crée ou met à jour la publication et y joint : l'installateur Windows (`...-setup.exe`), les installations complètes (`...-windows-full.zip`, `...-linux-full.tar.gz`), les fichiers un par un (`exe-*`, `core-*.pck`, `themes.pck`, `monsters.pck`, `audio.pck`) et les manifestes `manifest-<plateforme>.json` lus par la mise à jour du jeu.
- Disposition d'une installation : `Dungeon Generator.exe` (moteur seul) + `Dungeon Generator.pck` (code, données, polices, interface) + `packs/*.pck` (gros assets) + `install.json` (état des fichiers). Les groupes de paquets sont définis dans `tools/gen_export_presets.py` (qui régénère `export_presets.cfg`) ; `scripts/core/pack_loader.gd` monte `packs/*.pck` au démarrage. Le Web reste en un seul bloc.
- Mise à jour partielle (`scripts/core/updater.gd`) : le jeu lit le manifeste de la dernière publication et ne télécharge que les fichiers dont l'empreinte de contenu a changé. Essai complet : `sh tools/check_update_e2e.sh` (variable `GODOT`).
- L'export Web part en FTP à chaque push, sans condition (workflow « Export Web »).

## Commandes (couloir 3D)
Boutons à l'écran (tactile) ou clavier, touches physiques : ↑/Z avancer, ↓/S reculer, Q/D pas de côté, ←/A et →/E tourner (libellés AZERTY).
