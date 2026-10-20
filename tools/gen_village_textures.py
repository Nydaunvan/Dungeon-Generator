#!/usr/bin/env python3
"""Prépare les textures du village (packs ambientCG fournis) au format des autres thèmes : <partie>_albedo.jpg, <partie>_normal.png,
<partie>_orm.jpg (R = occlusion, G = rugosité), dans assets/themes/village_hd (2048 px, taille d'origine) et village_lite (1024 px).
Usage : python3 tools/gen_village_textures.py <dossier contenant les packs dézippés (et concrete_house_004/textures/ pour la maison à colombages)>
Chaque pack est un dossier <Nom>_2K-JPG avec <Nom>_2K-JPG_Color.jpg, _NormalGL.jpg, _Roughness.jpg (et _Opacity.jpg pour le feuillage)."""
import sys, pathlib
from PIL import Image

PACKS = {"brique": "Bricks085", "roche": "Rock064", "terre": "Ground067", "herbe": "Grass002", "paves": "PavingStones138",
         "toit": "PavingStones127", "tronc": "Wood075", "feuille": "LeafSet017"}

def open_png(path) -> Image.Image:
    """Certains PNG de la maison portent un gros bloc de texte compressé (zTXt) que Pillow refuse : on ne garde que les blocs d'image."""
    import struct, io
    data = pathlib.Path(path).read_bytes()
    out = bytearray(data[:8])
    pos = 8
    while pos < len(data):
        n = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        if kind in (b"IHDR", b"PLTE", b"IDAT", b"IEND", b"tRNS"):
            out += data[pos:pos + 12 + n]
        pos += 12 + n
    return Image.open(io.BytesIO(bytes(out)))

# Maison à colombages (concrete_house_004) : textures du modèle, en fichiers explicites (couleur, normales, rugosité).
HOUSE = {"beton": ("concrete/concrete_bc.jpg", "concrete/concrete_n.jpg", "concrete/concrete_roughness.jpg"),
         "toit_m": ("roof/roof_bc.png", "roof/roof_n.png", "roof/roof_roughness.png"),
         "bois_m": ("tiled_redwood/T_tiled_redwood_bc.png", "tiled_redwood/T_tiled_redwood_n.png", "tiled_redwood/T_tiled_redwood_r.png")}

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
        house = src / "concrete_house_004" / "textures"
        if house.exists():
            def load_img(path, mode):
                im = open_png(path) if str(path).endswith(".png") else Image.open(path)
                return im.convert(mode)
            for part, (c, n, r) in HOUSE.items():
                fit(load_img(house / c, "RGB")).save(out / f"{part}_albedo.jpg", quality=92)
                fit(load_img(house / n, "RGB")).save(out / f"{part}_normal.png", optimize=True)
                rough = fit(load_img(house / r, "L"))
                Image.merge("RGB", (Image.new("L", rough.size, 255), rough, Image.new("L", rough.size, 0))).save(out / f"{part}_orm.jpg", quality=92)
        print("écrit", out)

if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]))
