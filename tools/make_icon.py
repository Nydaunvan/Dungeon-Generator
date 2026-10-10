#!/usr/bin/env python3
"""Génère l'icône du jeu à partir de l'épée du jeu (assets/ui/sword_loading_padded.png) :
  - assets/app_icon.png  (512 px : icône du projet, utilisée comme icône de fenêtre et de barre des tâches) ;
  - installer/app.ico    (16 à 256 px : icône de l'exécutable Windows, de l'installateur et des raccourcis) ;
  - installer/app_icon_256.png (icône du menu des applications sous Linux).
Usage : python3 tools/make_icon.py"""
from PIL import Image, ImageDraw, ImageFilter
import pathlib, math

ROOT = pathlib.Path(__file__).resolve().parent.parent
S = 1024

def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), radius, fill=255)
    return m

def build():
    # fond : brun sombre du jeu avec une lueur chaude au centre
    bg = Image.new("RGBA", (S, S), (24, 17, 11, 255))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse((S * 0.12, S * 0.12, S * 0.88, S * 0.88), fill=(150, 96, 34, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
    bg = Image.alpha_composite(bg, glow)
    # épée, tournée de 45° (pointe en haut à droite), à l'échelle de la diagonale
    sword = Image.open(ROOT / "assets/ui/sword_loading_padded.png").convert("RGBA")
    sword = sword.crop(sword.getchannel("A").getbbox())
    target = S * 1.12
    sword = sword.resize((int(target), int(target * sword.height / sword.width)), Image.LANCZOS)
    sword = sword.rotate(45, expand=True, resample=Image.BICUBIC)
    # ombre portée
    shadow = Image.new("RGBA", sword.size, (0, 0, 0, 0))
    shadow.putalpha(sword.getchannel("A").point(lambda v: int(v * 0.6)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.015))
    pos = ((S - sword.width) // 2, (S - sword.height) // 2)
    bg.alpha_composite(shadow, (pos[0] + int(S * 0.012), pos[1] + int(S * 0.02)))
    bg.alpha_composite(sword, pos)
    # liseré or
    frame = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((S * 0.02, S * 0.02, S * 0.98, S * 0.98), S * 0.17, outline=(224, 176, 74, 255), width=int(S * 0.025))
    ImageDraw.Draw(frame).rounded_rectangle((S * 0.05, S * 0.05, S * 0.95, S * 0.95), S * 0.15, outline=(120, 82, 30, 255), width=int(S * 0.008))
    bg.alpha_composite(frame)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(bg, (0, 0), rounded_mask(S, int(S * 0.19)))
    return out

def main():
    img = build()
    img.resize((512, 512), Image.LANCZOS).save(ROOT / "assets/app_icon.png", optimize=True)
    img.resize((256, 256), Image.LANCZOS).save(ROOT / "installer/app_icon_256.png", optimize=True)
    img.save(ROOT / "installer/app.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("icônes écrites")

if __name__ == "__main__":
    main()
