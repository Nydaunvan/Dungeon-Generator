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
- Publier : pousser sur `migration/donnees` un commit dont le message contient `[exe]` (préversion `v<version>`) ou `[release]` (publication normale). Le workflow « Publication » exporte Windows (`.zip`) et Linux (`.tar.gz`), crée ou met à jour la publication et y joint les fichiers.
- L'export Web part en FTP à chaque push, sans condition (workflow « Export Web »).

## Commandes (couloir 3D)
Boutons à l'écran (tactile) ou clavier, touches physiques : ↑/Z avancer, ↓/S reculer, Q/D pas de côté, ←/A et →/E tourner (libellés AZERTY).
