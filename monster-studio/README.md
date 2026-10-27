# Monster Studio

Logiciel **indépendant du jeu** (projet Godot séparé, dossier `monster-studio/`) qui transforme vos monstres 2D en modèles 3D animés :

1. **Importer** des images 2D (png, webp, jpg) — par le bouton ou en les glissant sur la fenêtre ;
2. **Créer le modèle 3D** avec une IA qui tourne sur votre PC (par défaut TripoSR, open source) ;
3. **Placer un squelette** (gabarit bipède, quadrupède, ailé ou serpent) puis l'ajuster os par os ;
4. **Calculer la peau** (poids automatiques) et **animer** : repos, marche, attaque, coup reçu, mort, avec retouche de pose par clés ;
5. **Exporter en `.glb`** (maillage + squelette + animations), prêt à charger dans Godot.

Les données sont rangées par monstre dans `user://studio/<monstre>/` (image, modèle, `rig.json`).

## Lancer

- Depuis Godot 4.7 : ouvrir le dossier `monster-studio/` comme projet, puis F5.
- Application Windows : menu Projet → Exporter → préréglage « Windows » (fichier unique `build/windows/Monster Studio.exe`).

## Brancher l'IA 2D → 3D (TripoSR, une seule fois)

**Le plus simple : double-cliquez sur `install_triposr.bat`** (dans ce dossier). Il vérifie Python 3.11 (ou 3.10 ; la 3.12 et au-delà ne sont pas prises en charge par les dépendances de TripoSR), Git et la carte NVIDIA, télécharge TripoSR dans `%USERPROFILE%\TripoSR` (ou dans le dossier donné en argument), crée un environnement isolé, installe PyTorch (CUDA 12.1) et les dépendances, fait un essai complet (téléchargement du modèle compris), puis écrit lui-même les réglages de Monster Studio. Il peut être relancé : il reprend là où il s'est arrêté. Si la compilation de `torchmcubes` échoue, il indique quoi installer (Build Tools de Visual Studio, kit CUDA 12.1). Il n'a pas encore été essayé sur un vrai PC Windows.

À la main :

L'IA est un programme externe que Monster Studio lance ; il faut l'installer vous-même (carte NVIDIA conseillée, quelques Go) :

```
git clone https://github.com/VAST-AI-Research/TripoSR
cd TripoSR
python -m venv venv
venv\Scripts\activate
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
pip install -r requirements.txt
```

`requirements.txt` compile `torchmcubes` : sous Windows il faut les « Build Tools » de Visual Studio et le kit CUDA (voir le dépôt TripoSR en cas d'erreur). Ensuite, dans Monster Studio → **Réglages** :

- **Dossier** : le dossier `TripoSR` ;
- **Commande** : `venv\Scripts\python run.py "{image}" --output-dir "{outdir}" --model-save-format glb` (adaptez `python` à votre installation) ;
- **Résultat** : `{outdir}/0/mesh.glb`.

La commande est libre : tout outil qui transforme une image en `.glb` convient (autre modèle open source, script maison…). On peut aussi **importer un `.glb` déjà fait** (autre outil ou service en ligne), ou essayer la chaîne avec une **silhouette de test**.

## Conseils

- Le modèle est normalisé à l'import : centré, pieds au sol, **hauteur 2**, façade vers **+Z**. Si l'IA le produit couché ou de dos, utilisez les boutons d'orientation (onglet 1) avant de placer le squelette.
- Les **rôles** des os (root, spine, head, tail, arm, leg, wing) pilotent les animations automatiques ; « arm » = bras ou pattes avant, « leg » = jambes ou pattes arrière.
- Une clé de pose insérée sur un os remplace son animation automatique (bouton « Effacer les clés » pour revenir en arrière).

## Vérification

`xvfb-run -a godot --path monster-studio res://tools/check_studio.tscn` joue toute la chaîne (hors IA) sur des silhouettes de test pour les 4 gabarits : import, squelette, poids, animations, export `.glb` et relecture.
