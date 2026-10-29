#!/usr/bin/env python3
"""Prépare les cinq poses d'un monstre « Atlas Noir » à partir des images brutes (fond noir) et écrit les webp du jeu.
Usage : python3 tools/make_monster.py <id> repos.png attaque.png coup.png attaque2.png mort.png
  → assets/monsters/<id>.webp, <id>_attack.webp, <id>_hit.webp, <id>_attack2.webp, <id>_dead.webp (1024 px, RGBA).
Traitements (indispensables pour que le sprite ne SCINTILLE pas en 3D) :
  1. détourage du fond noir relié au bord (les orbites et poches sombres intérieures restent opaques) ;
  2. suppression du liseré clair « autocollant » du contour (érosion de l'alpha) et bord adouci : un trait fin de 1-2 px qui bouge à la
     respiration du sprite ou à la caméra crépite à l'écran ;
  3. couleurs des pixels transparents prolongées depuis le bord (pas de frange noire ou blanche aux mipmaps) ;
  4. léger flou des couleurs (1,2 px à 1536) : amortit le micro-contraste que la réduction 1024 → ~300 px fait danser ;
  5. toutes les poses à la même échelle, pieds calés sur la même ligne (celle du repos).
Côté moteur : respiration réduite à 30 % pour ces monstres (EntityLayer, méta « atlas »).
Les imports Godot du dossier assets/monsters doivent avoir mipmaps/generate=true (voir assets/monsters/*.webp.import)."""
import sys, pathlib
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).resolve().parent.parent
ERODE = 3          # px (à 1536) retirés autour de la silhouette
FEATHER = 1.6      # px de dégradé du bord
BLUR = 1.2         # px (à 1536) de flou sur les couleurs

def key(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255
    dark = a.max(-1) < 0.075
    lab, _ = ndi.label(dark)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    solid = ~np.isin(lab, list(border))
    solid = ndi.binary_opening(solid, iterations=1)
    solid = ndi.binary_erosion(solid, iterations=ERODE)
    alpha = ndi.gaussian_filter(solid.astype(np.float32), FEATHER)
    alpha = np.clip((alpha - 0.2) / 0.6, 0, 1)
    # couleurs : on prolonge l'intérieur vers l'extérieur (plus proche voisin opaque), puis léger flou
    idx = ndi.distance_transform_edt(~solid, return_distances=False, return_indices=True)
    filled = a[idx[0], idx[1]]
    filled = np.stack([ndi.gaussian_filter(filled[..., c], BLUR) for c in range(3)], -1)
    return filled, alpha

def bottom(alpha):
    rows = np.where(alpha.max(1) > 0.5)[0]
    return int(rows.max())

def main():
    mid, files = sys.argv[1], sys.argv[2:]
    suffixes = ["", "_attack", "_hit", "_attack2", "_dead"]
    assert len(files) == 5, "cinq images : repos, attaque, coup, attaque2, mort"
    data = [key(f) for f in files]
    ref = bottom(data[0][1])
    for suf, (rgb, alpha) in zip(suffixes, data):
        dy = ref - bottom(alpha)
        im = Image.fromarray((np.dstack([rgb, alpha]) * 255).astype(np.uint8), "RGBA")
        canvas = Image.new("RGBA", im.size, (0, 0, 0, 0))
        canvas.paste(im, (0, dy))
        canvas = canvas.resize((1024, 1024), Image.LANCZOS)
        out = ROOT / "assets/monsters" / f"{mid}{suf}.webp"
        canvas.save(out, quality=92, method=6)
        print("écrit", out.relative_to(ROOT))

if __name__ == "__main__":
    main()
