#!/usr/bin/env python3
"""Prépare les textures 3D du thème « pierre » (mur : StoneBricksSplitface001, sol : GroundDirtRocky020) en deux jeux :
  assets/themes/stone_hd/    2048x2048  -> exécutable Windows
  assets/themes/stone_lite/  1024x1024  -> Web et mobile
Chaque jeu : <partie>_albedo.jpg (couleur), <partie>_normal.png (normales OpenGL), <partie>_orm.jpg (R = occlusion, G = rugosité, B = 0).
Les filtres d'exclusion des presets d'export (export_presets.cfg) retirent le jeu inutile de chaque build.
Usage : python3 tools/prepare_stone.py wall <dossier extrait du zip du mur>
        python3 tools/prepare_stone.py floor <dossier extrait du zip du sol>
"""
import os, sys, shutil
import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
PART = sys.argv[1] if len(sys.argv) > 2 else "wall"
SRC = sys.argv[2] if len(sys.argv) > 2 else (sys.argv[1] if len(sys.argv) > 1 else ".")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "themes")
PREFIX = {"wall": "StoneBricksSplitface001_", "floor": "GroundDirtRocky020_"}
P = PREFIX[PART]

def load(name, mode):
    return Image.open(os.path.join(SRC, P + name)).convert(mode)

def resize_normal(img, size):
    a = np.asarray(img, dtype=np.float32) / 255.0 * 2.0 - 1.0
    t = Image.fromarray(((a + 1.0) * 0.5 * 255.0).astype(np.uint8))
    t = t.resize((size, size), Image.LANCZOS)
    b = np.asarray(t, dtype=np.float32) / 255.0 * 2.0 - 1.0
    b /= np.maximum(np.linalg.norm(b, axis=2, keepdims=True), 1e-6)   # renormalise après réduction
    return Image.fromarray(((b + 1.0) * 0.5 * 255.0 + 0.5).clip(0, 255).astype(np.uint8))

def build(size, folder):
    d = os.path.join(OUT, folder)
    os.makedirs(d, exist_ok=True)
    col = load("COL_2K.jpg", "RGB")
    nrm = load("NRM_2K.png" if os.path.exists(os.path.join(SRC, P + "NRM_2K.png")) else "NRM_2K.jpg", "RGB")
    ao = load("AO_2K.jpg", "L")
    gloss = load("GLOSS_2K.jpg", "L")
    if size != col.size[0]:
        col = col.resize((size, size), Image.LANCZOS)
        nrm = resize_normal(nrm, size)
        ao = ao.resize((size, size), Image.LANCZOS)
        gloss = gloss.resize((size, size), Image.LANCZOS)
    rough = Image.eval(gloss, lambda v: 255 - v)          # Godot attend une rugosité, pas une brillance
    orm = Image.merge("RGB", (ao, rough, Image.new("L", (size, size), 0)))
    col.save(os.path.join(d, PART + "_albedo.jpg"), quality=92, subsampling=0, optimize=True)
    nrm.save(os.path.join(d, PART + "_normal.png"), optimize=True)
    orm.save(os.path.join(d, PART + "_orm.jpg"), quality=95, subsampling=0, optimize=True)   # 4:4:4 : pas de mélange des canaux
    print(folder, size, "ok")

build(2048, "stone_hd")
build(1024, "stone_lite")
