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

## Commandes (couloir 3D)
Boutons à l'écran (tactile) ou clavier, touches physiques : ↑/Z avancer, ↓/S reculer, Q/D pas de côté, ←/A et →/E tourner (libellés AZERTY).
