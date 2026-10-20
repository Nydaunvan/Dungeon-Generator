#!/usr/bin/env python3
"""Prépare les textures du village (packs ambientCG fournis) au format des autres thèmes : <partie>_albedo.jpg, <partie>_normal.png,
<partie>_orm.jpg (R = occlusion, G = rugosité), dans assets/themes/village_hd (2048 px, taille d'origine) et village_lite (1024 px).
Usage : python3 tools/gen_village_textures.py <dossier contenant les packs dézippés>
Chaque pack est un dossier <Nom>_2K-JPG avec <Nom>_2K-JPG_Color.jpg, _NormalGL.jpg, _Roughness.jpg (et _Opacity.jpg pour le feuillage)."""
import sys, pathlib
from PIL import Image

PACKS = {"brique": "Bricks085", "roche": "Rock064", "terre": "Ground067", "herbe": "Grass002", "paves": "PavingStones138",
         "toit": "PavingStones127", "tronc": "Wood075", "feuille": "LeafSet017"}

def main(src: pathlib.Path) -> None:
    root = pathlib.Path(__file__).resolve().parent.parent / "assets" / "themes"
    for tag, size in (("hd", None), ("lite", 1024)):
        out = root / f"village_{tag}"
        out.mkdir(parents=True, exist_ok=True)
        for part, pack in PACKS.items():
            base = src / f"{pack}_2K-JPG" / f"{pack}_2K-JPG"
            def fit(im: Image.Image) -> Image.Image:
                if size is None:
                    return im
                k = size / max(im.size)
                return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
            fit(Image.open(f"{base}_Color.jpg").convert("RGB")).save(out / f"{part}_albedo.jpg", quality=92)
            fit(Image.open(f"{base}_NormalGL.jpg").convert("RGB")).save(out / f"{part}_normal.png", optimize=True)
            rough = fit(Image.open(f"{base}_Roughness.jpg").convert("L"))
            white = Image.new("L", rough.size, 255)
            zero = Image.new("L", rough.size, 0)
            Image.merge("RGB", (white, rough, zero)).save(out / f"{part}_orm.jpg", quality=92)
            op = pathlib.Path(f"{base}_Opacity.jpg")
            if op.exists():
                fit(Image.open(op).convert("L")).save(out / f"{part}_opacity.jpg", quality=92)
        print("écrit", out)

if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]))
