#!/usr/bin/env python3
"""Masque des cascades du fond d'accueil (assets/home/waterfall_mask.png, 1920×1080, niveaux de gris).
Polygones tracés à la main sur home_bg.png (3840×2160) × clarté locale de l'image : l'animation n'éclaire que ce qui est déjà de l'eau claire.
Si le fond change, retracer les polygones (coordonnées en pixels du fond 3840×2160)."""
import pathlib
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).resolve().parent.parent
POLYS = [   # (polygone, poids)
    ([(3628, 545), (3708, 540), (3700, 700), (3690, 930), (3630, 930), (3622, 700)], 1.0),       # grande chute, sous le pont du haut
    ([(3522, 1005), (3594, 1000), (3592, 1100), (3525, 1100)], 1.0),                             # petite chute, sous le pont du milieu
    ([(3525, 1105), (3590, 1105), (3585, 1330), (3530, 1330)], 0.7),                             # filets sous ce pont
    ([(3330, 1590), (3490, 1590), (3495, 1800), (3440, 1950), (3340, 1950), (3300, 1750)], 0.55),  # brume d'eau du fond
]

def main():
    bg = Image.open(ROOT / "assets/home/home_bg.png").convert("RGB").resize((1920, 1080), Image.LANCZOS)
    lum = np.asarray(bg).astype(np.float32).mean(-1) / 255
    gate = np.clip((ndi.gaussian_filter(lum, 1.5) - 0.18) / 0.22, 0, 1)
    m = np.zeros((1080, 1920), np.float32)
    for poly, w in POLYS:
        img = Image.new("L", (1920, 1080), 0)
        ImageDraw.Draw(img).polygon([(x / 2, y / 2) for x, y in poly], fill=255)
        p = ndi.gaussian_filter(np.asarray(img).astype(np.float32) / 255, 3.0)
        m = np.maximum(m, p * w)
    out = np.clip(m * gate, 0, 1)
    Image.fromarray((out * 255).astype(np.uint8), "L").save(ROOT / "assets/home/waterfall_mask.png")
    print("masque écrit, couverture %.2f %%" % (100 * (out > 0.05).mean()))

if __name__ == "__main__":
    main()
