#!/usr/bin/env python3
"""Génère les textures d'interface (cadres bronze rivés, cartes en arche, boutons, rubans…).
Usage : python3 tools/gen_ui_textures.py   ->   assets/ui/*.png
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)
SS = 4  # sur-échantillonnage

def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

BLACK = hexc("050302")
BRONZE_D = hexc("3b2b1a")
BRONZE = hexc("7a6242")
BRONZE_L = hexc("b39560")
BRONZE_HI = hexc("d8c090")
GOLD = hexc("e8b45c")
INNER = hexc("140f0a")

def noise(w, h, base, amp, seed=1, blur=1.2, tile=False):
    rng = np.random.default_rng(seed)
    n = rng.normal(0, 1, (h * (3 if tile else 1), w * (3 if tile else 1)))
    img = Image.fromarray(((n * 40) + 128).clip(0, 255).astype("uint8"))
    img = img.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(img).astype("float32") - 128
    if tile:
        a = a[h:2 * h, w:2 * w]
    a = a / max(1.0, np.abs(a).max())
    out = np.zeros((h, w, 4), dtype="float32")
    for i in range(3):
        out[..., i] = base[i] + a * amp
    out[..., 3] = 255
    return Image.fromarray(out.clip(0, 255).astype("uint8"), "RGBA")

def down(img, w, h):
    return img.resize((w, h), Image.LANCZOS)

def save(img, name):
    img.save(os.path.join(OUT, name))
    print("ok", name, img.size)

def rrect(d, box, r, fill):
    d.rounded_rectangle(box, radius=r, fill=fill)

def rivet(d, cx, cy, r):
    d.ellipse((cx - r - SS, cy - r - SS, cx + r + SS, cy + r + SS), fill=BLACK)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=BRONZE)
    d.ellipse((cx - r * 0.85, cy - r * 0.85, cx + r * 0.6, cy + r * 0.6), fill=BRONZE_L)
    d.ellipse((cx - r * 0.55, cy - r * 0.6, cx + r * 0.05, cy - r * 0.05), fill=BRONZE_HI)

# --------------------------------------------------------------------------- fond
def bg_tile():
    img = noise(256, 256, (30, 23, 16), 9, seed=3, blur=1.6, tile=True)
    img2 = noise(256, 256, (0, 0, 0), 5, seed=9, blur=0.6, tile=True)
    a = np.asarray(img).astype("int16") + (np.asarray(img2).astype("int16") - 0) * 0
    save(img, "bg_tile.png")

def panel_tile():
    save(noise(128, 128, (24, 18, 12), 6, seed=5, blur=1.0, tile=True), "panel_tile.png")

# --------------------------------------------------------------------------- cadres 9-slice
def frame(name, size=96, border=9, center="dark", rivets=True, radius=8):
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    b = border * SS
    r = radius * SS
    rrect(d, (0, 0, s - 1, s - 1), r, BLACK)
    rrect(d, (SS, SS, s - SS - 1, s - SS - 1), r - SS, BRONZE_D)
    rrect(d, (2 * SS, 2 * SS, s - 2 * SS - 1, s - 2 * SS - 1), r - 2 * SS, BRONZE)
    # biseau : clair en haut/gauche, sombre en bas/droite
    d.line((3 * SS, 3 * SS, s - 3 * SS, 3 * SS), fill=BRONZE_L, width=SS)
    d.line((3 * SS, 3 * SS, 3 * SS, s - 3 * SS), fill=BRONZE_L, width=SS)
    d.line((3 * SS, s - 3 * SS, s - 3 * SS, s - 3 * SS), fill=BRONZE_D, width=SS)
    d.line((s - 3 * SS, 3 * SS, s - 3 * SS, s - 3 * SS), fill=BRONZE_D, width=SS)
    # filet intérieur
    rrect(d, (b - SS, b - SS, s - b + SS - 1, s - b + SS - 1), max(1, r // 2), BLACK)
    if center == "dark":
        rrect(d, (b, b, s - b - 1, s - b - 1), max(1, r // 2 - SS), INNER)
    else:
        # évide le centre
        mask = Image.new("L", (s, s), 255)
        ImageDraw.Draw(mask).rounded_rectangle((b, b, s - b - 1, s - b - 1), radius=max(1, r // 2 - SS), fill=0)
        a = np.asarray(img).copy()
        a[..., 3] = (a[..., 3].astype("uint16") * np.asarray(mask) // 255).astype("uint8")
        img = Image.fromarray(a, "RGBA")
        d = ImageDraw.Draw(img)
    if rivets:
        c = (border * 0.5 + 2.5) * SS
        for (x, y) in [(c, c), (s - c, c), (c, s - c), (s - c, s - c)]:
            rivet(d, x, y, 4.2 * SS)
    save(down(img, size, size), name)

# --------------------------------------------------------------------------- cartes en arche
def card(name, border_col, glow=None, w=160, h=210, top_r=62, glow_w=0):
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if glow:
        g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(g)
        rrect(gd, (SS, SS, W - SS, H - SS), top_r * SS, glow)
        g = g.filter(ImageFilter.GaussianBlur(4 * SS))
        img.alpha_composite(g)
    d = ImageDraw.Draw(img)
    def shape(inset, fill):
        x0, y0, x1, y1 = inset * SS, inset * SS, W - inset * SS - 1, H - inset * SS - 1
        # haut très arrondi, bas peu arrondi
        d.rounded_rectangle((x0, y0, x1, y1), radius=max(2, (top_r - inset) * SS), fill=fill,
                            corners=(True, True, False, False))
        d.rounded_rectangle((x0, y0 + (top_r) * SS, x1, y1), radius=max(2, (8 - inset // 2) * SS), fill=fill,
                            corners=(False, False, True, True))
    shape(3, BLACK)
    shape(4, border_col)
    shape(10, BLACK)
    shape(11, INNER)
    save(down(img, w, h), name)

# --------------------------------------------------------------------------- boutons / plaques
def plate(name, border, fill, size=48, r=7, bw=3):
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, s - 1, s - 1), r * SS, BLACK)
    rrect(d, (SS, SS, s - SS - 1, s - SS - 1), (r - 1) * SS, border)
    rrect(d, ((1 + bw) * SS, (1 + bw) * SS, s - (1 + bw) * SS - 1, s - (1 + bw) * SS - 1), (r - bw) * SS, fill)
    d.line((5 * SS, 5 * SS, s - 5 * SS, 5 * SS), fill=tuple(min(255, c + 22) for c in fill[:3]) + (255,), width=SS)
    save(down(img, size, size), name)

def inset(name="inset.png", size=48):
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, s - 1, s - 1), 5 * SS, hexc("2a2016"))
    rrect(d, (SS, SS, s - SS - 1, s - SS - 1), 4 * SS, BRONZE_D)
    rrect(d, (2 * SS, 2 * SS, s - 2 * SS - 1, s - 2 * SS - 1), 3 * SS, hexc("0a0705"))
    save(down(img, size, size), name)

# --------------------------------------------------------------------------- ronds (sorts / attaque)
def ring(name, ring_col, fill, size=128, swords=False, glow=False):
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = 2 * SS
    d.ellipse((m, m, s - m, s - m), fill=BLACK)
    d.ellipse((m + SS, m + SS, s - m - SS, s - m - SS), fill=ring_col)
    d.ellipse((m + 5 * SS, m + 5 * SS, s - m - 5 * SS, s - m - 5 * SS), fill=BLACK)
    d.ellipse((m + 6 * SS, m + 6 * SS, s - m - 6 * SS, s - m - 6 * SS), fill=fill)
    # reflet
    hl = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse((s * 0.2, s * 0.14, s * 0.8, s * 0.55), fill=(255, 255, 255, 22))
    img.alpha_composite(hl)
    if swords:
        c = s / 2
        L = s * 0.27
        for ang in (45, -45):
            a = math.radians(ang)
            dx, dy = math.cos(a) * L, math.sin(a) * L
            d.line((c - dx, c - dy, c + dx, c + dy), fill=hexc("d8d8dc"), width=int(s * 0.055))
            d.line((c - dx, c - dy, c + dx, c + dy), fill=hexc("9a9aa2"), width=int(s * 0.02))
            # garde
            px, py = -math.sin(a), math.cos(a)
            gx, gy = c - dx * 0.55, c - dy * 0.55
            d.line((gx - px * s * 0.09, gy - py * s * 0.09, gx + px * s * 0.09, gy + py * s * 0.09), fill=GOLD, width=int(s * 0.04))
    save(down(img, size, size), name)

def ribbon(name="ribbon.png", w=180, h=30):
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    n = 12 * SS
    pts = [(0, 0), (W, 0), (W - n, H // 2), (W, H), (0, H), (n, H // 2)]
    pts_in = [(2 * SS, 2 * SS), (W - 2 * SS, 2 * SS), (W - n - SS, H // 2), (W - 2 * SS, H - 2 * SS), (2 * SS, H - 2 * SS), (n + SS, H // 2)]
    d.polygon(pts, fill=BLACK)
    d.polygon(pts_in, fill=(235, 235, 235, 255))
    d.line((n + 6 * SS, 4 * SS, W - n - 6 * SS, 4 * SS), fill=(255, 255, 255, 255), width=SS)
    save(down(img, w, h), name)

def medallion(name="medallion.png", size=40):
    """Petit crâne sur médaillon de bronze (ornement en haut des panneaux)."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, s - 1, s - 1), fill=BLACK)
    d.ellipse((2 * SS, 2 * SS, s - 2 * SS, s - 2 * SS), fill=BRONZE)
    d.ellipse((4 * SS, 4 * SS, s - 4 * SS, s - 4 * SS), fill=hexc("1a130c"))
    bone = hexc("efe6d0")
    c = s / 2
    d.ellipse((c - s * 0.24, c - s * 0.27, c + s * 0.24, c + s * 0.15), fill=bone)
    d.rounded_rectangle((c - s * 0.15, c + s * 0.05, c + s * 0.15, c + s * 0.27), radius=int(s * 0.04), fill=bone)
    d.ellipse((c - s * 0.16, c - s * 0.13, c - s * 0.04, c + s * 0.0), fill=hexc("120c07"))
    d.ellipse((c + s * 0.04, c - s * 0.13, c + s * 0.16, c + s * 0.0), fill=hexc("120c07"))
    d.polygon([(c, c + s * 0.02), (c - s * 0.03, c + s * 0.09), (c + s * 0.03, c + s * 0.09)], fill=hexc("120c07"))
    for i in (-1, 0, 1):
        d.line((c + i * s * 0.07, c + s * 0.16, c + i * s * 0.07, c + s * 0.26), fill=hexc("120c07"), width=SS)
    save(down(img, size, size), name)

def chest(name="chest.png", size=24):
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2 * SS, 6 * SS, s - 2 * SS, s - 4 * SS), radius=3 * SS, fill=hexc("6b4a2a"), outline=BLACK, width=SS)
    d.rounded_rectangle((2 * SS, 6 * SS, s - 2 * SS, 12 * SS), radius=3 * SS, fill=hexc("8a6238"), outline=BLACK, width=SS)
    d.rectangle((s / 2 - 2 * SS, 11 * SS, s / 2 + 2 * SS, 16 * SS), fill=GOLD)
    save(down(img, size, size), name)

if __name__ == "__main__":
    bg_tile()
    panel_tile()
    frame("frame_panel.png", 96, 9, "dark")
    frame("frame_view.png", 96, 9, "clear")
    frame("frame_header.png", 96, 8, "dark", rivets=True, radius=6)
    card("card_arch.png", BRONZE)
    card("card_arch_active.png", GOLD, glow=(232, 180, 92, 150))
    card("card_arch_target.png", hexc("7fd17f"), glow=(127, 209, 127, 120))
    plate("btn_n.png", BRONZE, hexc("2a2016"))
    plate("btn_h.png", GOLD, hexc("3a2c1c"))
    plate("btn_p.png", GOLD, hexc("120c07"))
    plate("btn_d.png", BRONZE_D, hexc("1a140e"))
    plate("plaque.png", BRONZE, hexc("15100a"), r=5, bw=3)
    inset()
    ring("slot.png", BRONZE, hexc("15100a"))
    ring("slot_active.png", GOLD, hexc("3a2c1c"))
    ring("attack.png", GOLD, hexc("8a1c14"), swords=True)
    ring("attack_p.png", GOLD, hexc("4a0e0a"), swords=True)
    ribbon()
    medallion()
    chest()
