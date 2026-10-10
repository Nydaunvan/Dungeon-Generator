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
- Fenêtre de compte (sans réseau) : `godot --headless --path . res://tools/check_account.tscn`
- Textes : `python3 tools/check_lang.py`
- Réglages graphiques : `godot --headless --path . res://tools/check_settings.tscn`
- Mise en page mobile (aucun débordement à droite, carte masquée) : `godot --headless --path . res://tools/check_mobile.tscn`
- Touches du clavier (défauts par langue, réassignation, conflits, onglet Commandes) : `godot --headless --path . res://tools/check_keys.tscn`
- Version et journal : `python3 tools/check_version.py`
- Compte en ligne (sans réseau) : `godot --headless --path . res://tools/check_cloud.tscn`

## Versions et publication
- Le numéro de version est dans `project.godot` (`config/version`, forme `1.30.1`, ou `1.30.1-test1` pour un build de test). Le jeu l'affiche à partir de là (`AppVersion`).
- Journal des versions : `data/changelog.json` (affiché dans le jeu). Les notes de la publication GitHub en sont tirées (`tools/release_notes.py`).
- Publier : pousser sur `migration/donnees` un commit dont le message contient `[exe]` (préversion `v<version>`) ou `[release]` (publication normale). Le workflow « Publication » exporte Windows et Linux en **exécutable + paquets** (voir ci-dessous), crée ou met à jour la publication et y joint : l'installateur Windows (`...-setup.exe`), les installations complètes (`...-windows-full.zip`, `...-linux-full.tar.gz`), les fichiers un par un (`exe-*`, `core-*.pck`, `themes.pck`, `monsters.pck`, `audio.pck`) et les manifestes `manifest-<plateforme>.json` lus par la mise à jour du jeu.
- Disposition d'une installation : `Dungeon Generator.exe` (moteur seul) + `Dungeon Generator.pck` (code, données, polices, interface) + `packs/*.pck` (gros assets) + `install.json` (état des fichiers). Les groupes de paquets sont définis dans `tools/gen_export_presets.py` (qui régénère `export_presets.cfg`) ; `scripts/core/pack_loader.gd` monte `packs/*.pck` au démarrage. Le Web reste en un seul bloc.
- Mise à jour partielle (`scripts/core/updater.gd`) : le jeu lit le manifeste de la dernière publication et ne télécharge que les fichiers dont l'empreinte de contenu a changé. Essai complet : `sh tools/check_update_e2e.sh` (variable `GODOT`).
- L'export Web part en FTP à chaque push, sans condition (workflow « Export Web »).

## Partie en ligne (Supabase)
- Le jeu reste jouable hors ligne : rien n'est appelé au lancement. Le module de compte est l'autoload `Cloud` (`scripts/core/cloud.gd`) ; sa configuration (URL du projet + clé **publique**) est dans `data/cloud_config.json`. La clé secrète (`sb_secret_…` / `service_role`) ne va jamais dans le dépôt ni dans le jeu.
- Le schéma de la base est versionné dans `supabase/migrations/` (à appliquer dans l'ordre dans le SQL Editor du projet Supabase) : profils (pseudo public), donjons partagés (code DGZ1), signalements, challenges, parties soumises et classement. Les règles d'accès (RLS) bornent tout ce que la clé publique peut faire.
- Classement : le jeu envoie la graine et le journal d'actions de la partie (`runs`, statut `pending`), jamais un score cru sur parole. Un vérificateur de confiance, qui détient la clé secrète hors du dépôt, rejoue la partie et inscrit le score recalculé (`verified`) ; seul le classement des parties vérifiées est public (`leaderboard`).
- Défis (donjon aléatoire) : cliquer sur « Donjon aléatoire » ouvre d'abord la fenêtre des défis en cours avec leurs classements (`scripts/ui/challenges_modal.gd`), puis « Lancer un donjon aléatoire » mène aux réglages habituels. Un défi `declared` concerne les donjons aléatoires (pas de graine commune, donc pas de rejeu) : le jeu **déclare** son score (`scores`) et la base le borne par des contrôles de plausibilité (au moins 10 s de jeu par niveau, score qui ne baisse jamais, limites par jour) ; le classement public (`classement`) distingue les scores vérifiés (✔) des scores déclarés. Le suivi de partie (`levelsCleared`, `playSeconds`, `runId`, `adminUsed` dans `gs.stats`) et l'envoi sont dans `scripts/core/challenges.gd`. Une partie où l'administration a été ouverte n'est jamais envoyée. Un score trop incohérent se retire depuis le tableau de bord Supabase (table `scores`).
- Tests sans réseau : `godot --headless --path . res://tools/check_cloud.tscn` (compte), `res://tools/check_account.tscn` (fenêtre de compte), `res://tools/check_challenges.tscn` (défis, classement, envoi du score) ; suivi d'une vraie partie (affichage ou Xvfb requis) : `--script res://tools/check_run_tracking.gd`.
- Rejeu vérifié (en cours, étapes 1–4 faites) : toute la partie découle d'une graine texte (`Seeds`, `GameRng` : flux nommés combat/loot/trap/wander/village/ids, état sauvegardé avec la partie) et d'une horloge de jeu (`GameClock`, jamais l'heure réelle). Les actions du joueur sont journalisées dans `gs.run_log` (`RunLog`, entrées `[ms, commande, …]`) : déplacements, combat, objets (`Actions`), forge et Maître des Talents (village), et toutes les fenêtres de décision (`Flows` : fontaine, talents, évolution, piège et ses puzzles, boutique, marchand, victoire, village, modificateurs). Toute action non journalisée marque la partie « souillée » (`RunLog.unrecorded`) : elle n'est alors jamais classée. Le rejeu (`scripts/core/replayer.gd`) fait tourner la vraie scène du jeu et y injecte les commandes ; les règles d'acceptation vivent dans la logique partagée, pas dans l'interface. Tests : `check_determinism.tscn`, `check_game_rng.tscn` (valeurs de référence à confirmer sous Windows), `check_clock.gd`, et `xvfb-run -a godot --path . --script res://tools/check_replay.gd -- <graine> <actions> <niveaux>` (un bot joue une vraie partie, puis le journal est rejoué : l'empreinte de l'état doit être identique). Restent : règles des parties classées (ni administration, ni sauvegarde manuelle, ni retour arrière), vérificateur serveur et classement vérifié par mode de jeu.
- Parties classées par difficulté (serveur, étape 6a, pas encore branché à l'interface) : `supabase/migrations/20261010000200_parties_classees.sql` (réglages par difficulté `ranked_modes`, parties `ranked_runs`, fonctions `start_ranked_run` / `submit_ranked_run`, vue `classement_difficulte` vide tant que rien n'est vérifié). Côté jeu : `scripts/core/ranked_run.gd` (configuration partagée avec le vérificateur, démarrage, envoi, classement). Vérificateur : `tools/replay_run.gd` (rejoue un journal) + `tools/verify_runs.py` + workflow `.github/workflows/verify-runs.yml` (toutes les 15 min, secrets `SUPABASE_URL` et `SUPABASE_SECRET_KEY`, chaque partie est rejouée avec les règles de sa version, étiquette `v<version>`). Une partie classée n'accepte ni administration, ni export/import ; sa sauvegarde est à usage unique.
- Hardcore du mois (étape 6b) : `supabase/migrations/20261010000300_hardcore_mensuel_et_recompenses.sql`. Une graine par mois tirée par le serveur à la première partie du mois, difficulté hardcore, UN essai par jour (jour de Paris, consommé au lancement), classement `classement_periode` des parties vérifiées. Récompenses uniquement cosmétiques et de l'expérience : catalogue `badges` (titres, cadres, couleurs de pseudo), `player_badges`, `xp_log` / vue `account_xp` (niveau de compte), `player_cosmetics` + `equip_cosmetics`. Le vérificateur attribue tout (`award_run` après chaque partie vérifiée, `close_due_periods` pour les badges de rang des mois terminés depuis 2 jours), une seule fois. Côté jeu : section « Hardcore du mois » dans la fenêtre des défis du donjon aléatoire (`challenges_modal.gd`), `RankedRun.launch` / `submit` (journal gardé hors ligne puis renvoyé). Écrans : « Mes récompenses » (`rewards_modal.gd` : niveau de compte, collection de badges, équipement du titre, du cadre et de la couleur), « Parties classées » (`ranked_modal.gd` : un classement par difficulté + lancement), plaques de pseudo avec cadre (`cosmetics.gd`), accessibles depuis la fenêtre des défis et le compte. Tests sans réseau : `xvfb-run -a godot --path . --script res://tools/check_ranked_flow.gd` et `check_rewards_ui.gd`.

## Commandes (couloir 3D)
Boutons à l'écran (tactile) ou clavier, touches physiques : ↑/Z avancer, ↓/S reculer, Q/D pas de côté, ←/A et →/E tourner (libellés AZERTY).

## Icône du jeu
- Source : l'épée du jeu (`assets/ui/sword_loading_padded.png`) ; `python3 tools/make_icon.py` régénère `assets/app_icon.png` (icône du projet : fenêtre et barre des tâches sous Windows et Linux), `installer/app.ico` et `installer/app_icon_256.png`.
- Windows : le workflow de publication applique `installer/app.ico` et les informations de version à l'exécutable avec rcedit sous Wine (`tools/patch_windows_exe.sh`, vérifié par `tools/check_exe_icon.py` : simple avertissement en cas d'échec) ; l'installateur Inno Setup, ses raccourcis et la désinstallation utilisent la même icône (`installer/app.ico`).
- Linux : l'exécutable ELF ne porte pas d'icône ; l'archive complète contient `Dungeon Generator.png` et `install-menu.sh` (entrée du menu des applications avec l'icône, sans droits administrateur ; `--remove` pour la retirer).

