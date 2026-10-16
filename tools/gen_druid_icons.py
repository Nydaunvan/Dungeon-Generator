"""Icônes de la classe Druide, de ses deux évolutions (Gardien de la Forêt, Druide de la Tempête) et des 11 sorts de nature
(128×128, fond transparent, couleurs claires comme les icônes du Barde).
Usage : python3 tools/gen_druid_icons.py  → écrit assets/icons/class_<id>.png et assets/icons/spell_nature<N>.png
(Godot réimporte au prochain lancement de l'éditeur ; `SHEET=/chemin.png` écrit une planche de contrôle)."""
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
LEAF, LEAF_D, LEAF_L = (110, 205, 70), (34, 108, 42), (196, 246, 140)
BARK, BARK_D, BARK_L = (158, 104, 52), (86, 52, 26), (208, 158, 96)
GOLD, GOLD_D, GOLD_L = (247, 184, 52), (170, 104, 16), (255, 232, 140)
PINK, PINK_D = (255, 150, 196), (190, 70, 120)
ELEC, ELEC_D = (255, 246, 130), (200, 150, 20)
CLOUD, CLOUD_D = (196, 206, 220), (96, 108, 130)
SAP, SAP_D = (255, 190, 70), (180, 100, 20)
W = 7


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def glow(im, color, cx=256, cy=256, r=200, a=120):
    g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    g = g.filter(ImageFilter.GaussianBlur(r * 0.45))
    im.alpha_composite(g)


def rot(pts, cx, cy, ang):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def leaf(d, cx, cy, length, ang_deg, fill=LEAF, line=LEAF_D, width=None, rib=True):
    """Feuille dont la base est en (cx, cy) et la pointe à `length` dans la direction `ang_deg` (0 = vers le haut)."""
    w = width or length * 0.42
    pts = []
    n = 14
    for i in range(n + 1):
        t = i / n
        pts.append((w * math.sin(math.pi * t ** 0.8) * 0.5, -length * t))
    for i in range(n, -1, -1):
        t = i / n
        pts.append((-w * math.sin(math.pi * t ** 0.8) * 0.5, -length * t))
    pts = [(cx + x, cy + y) for x, y in pts]
    pts = rot(pts, cx, cy, math.radians(ang_deg))
    d.polygon(pts, fill=fill, outline=line, width=W // 2 + 1)
    if rib:
        tip = rot([(cx, cy - length * 0.9)], cx, cy, math.radians(ang_deg))[0]
        d.line([(cx, cy), tip], fill=line, width=max(3, int(length * 0.025)))


def star(d, cx, cy, r, color):
    pts = []
    for i in range(8):
        a = math.pi / 4 * i
        rr = r if i % 2 == 0 else r * 0.3
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=color)


def thick(d, pts, fill, line, wd, wl=None):
    wl = wl or wd + 14
    d.line(pts, fill=line, width=wl, joint="curve")
    d.line(pts, fill=fill, width=wd, joint="curve")


def bolt(d, x, y, size, fill=ELEC, line=ELEC_D):
    """Éclair en zigzag dont la pointe haute est en (x, y)."""
    s = size / 100.0
    pts = [(0, 0), (58, 0), (30, 52), (70, 52), (-14, 160), (10, 72), (-28, 72)]
    pts = [(x + px * s, y + py * s) for px, py in pts]
    d.polygon(pts, fill=fill, outline=line, width=W)
    return pts


def drop(d, cx, cy, r, fill, line, hi=(255, 255, 255)):
    pts = [(cx, cy - r * 1.7)]
    for i in range(0, 181, 10):
        a = math.radians(i)
        pts.append((cx + math.sin(a) * r, cy + r * 0.2 - math.cos(a) * r * 1.0 + r * 0.8))
    for i in range(180, 361, 10):
        a = math.radians(i)
        pts.append((cx + math.sin(a) * r, cy + r * 0.2 - math.cos(a) * r * 1.0 + r * 0.8))
    pts = [(cx, cy - r * 1.7), (cx + r, cy + r * 0.4), (cx + r * 0.6, cy + r * 1.3), (cx, cy + r * 1.55), (cx - r * 0.6, cy + r * 1.3), (cx - r, cy + r * 0.4)]
    d.polygon(pts, fill=fill, outline=line, width=W)
    d.ellipse([cx - r * 0.55, cy + r * 0.1, cx - r * 0.1, cy + r * 0.7], fill=hi)


# ------------------------------------------------------------------------------------------ CLASSES

def class_druid():  # bâton noueux couronné d'une orbe verte, deux feuilles
    im = canvas(); glow(im, LEAF_L, cy=190, a=140); d = ImageDraw.Draw(im)
    thick(d, [(168, 480), (205, 360), (250, 250), (292, 150)], BARK, BARK_D, 34)
    thick(d, [(215, 330), (150, 300), (120, 250)], BARK, BARK_D, 16)
    thick(d, [(292, 150), (230, 120), (225, 60)], BARK, BARK_D, 20)
    thick(d, [(292, 150), (360, 130), (372, 62)], BARK, BARK_D, 20)
    d.ellipse([240, 40, 360, 160], fill=LEAF, outline=LEAF_D, width=W + 2)
    d.ellipse([262, 58, 306, 102], fill=(235, 255, 215))
    d.ellipse([300, 100, 340, 140], fill=LEAF_D)
    leaf(d, 230, 330, 130, 62)
    leaf(d, 250, 260, 120, -58)
    leaf(d, 120, 252, 90, -20, fill=LEAF_L)
    star(d, 410, 120, 40, GOLD_L)
    return im


def class_warden():  # écu d'écorce marqué d'un arbre
    im = canvas(); glow(im, LEAF_L, a=130); d = ImageDraw.Draw(im)
    w, h, cx, cy = 320, 400, 256, 262
    top = cy - h / 2
    pts = [(cx - w / 2, top), (cx + w / 2, top), (cx + w / 2, cy + h * 0.1), (cx, cy + h / 2), (cx - w / 2, cy + h * 0.1)]
    d.polygon(pts, fill=BARK, outline=BARK_D, width=W + 3)
    k = 0.82
    pts2 = [(cx - w / 2 * k, top + h * 0.09), (cx + w / 2 * k, top + h * 0.09), (cx + w / 2 * k, cy + h * 0.06), (cx, cy + h * 0.4), (cx - w / 2 * k, cy + h * 0.06)]
    d.polygon(pts2, fill=LEAF_D)
    # arbre : tronc, racines, trois masses de feuillage
    d.polygon([(236, 410), (248, 300), (264, 300), (276, 410), (300, 430), (212, 430)], fill=BARK_L, outline=BARK_D, width=W - 2)
    for (x, y, r, col) in [(210, 270, 66, LEAF), (302, 270, 66, LEAF), (256, 208, 78, LEAF), (256, 292, 56, LEAF)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=col, outline=LEAF_D, width=W - 2)
    for (x, y, r) in [(236, 190, 22), (292, 262, 18), (200, 262, 16)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=LEAF_L)
    star(d, 410, 92, 40, GOLD_L)
    return im


def class_stormcaller():  # nuage d'orage, éclair, feuille de chêne
    im = canvas(); glow(im, ELEC, cy=200, a=110); d = ImageDraw.Draw(im)
    for (x, y, r) in [(170, 150, 66), (250, 120, 84), (340, 150, 70), (258, 170, 78)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=CLOUD, outline=CLOUD_D, width=W)
    for (x, y, r) in [(170, 150, 58), (250, 120, 76), (340, 150, 62), (258, 170, 70)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=CLOUD)
    d.rectangle([150, 160, 360, 220], fill=CLOUD)
    leaf(d, 220, 470, 250, 14, fill=LEAF, line=LEAF_D, width=190)
    bolt(d, 250, 190, 100)
    for ang in (150, 205, 330):
        d.arc([60, 250, 450, 470], ang, ang + 36, fill=(235, 255, 235), width=10)
    star(d, 430, 270, 34, GOLD_L)
    return im


# ------------------------------------------------------------------------------------------ SORTS

def bez(p0, p1, p2, n=24):
    return [((1 - u) ** 2 * p0[0] + 2 * (1 - u) * u * p1[0] + u * u * p2[0], (1 - u) ** 2 * p0[1] + 2 * (1 - u) * u * p1[1] + u * u * p2[1])
            for u in [i / n for i in range(n + 1)]]


def nature1():  # Épine Venimeuse : épine recourbée, gouttes de poison
    im = canvas(); glow(im, LEAF_L, a=130); d = ImageDraw.Draw(im)
    tip = (400, 60)
    outer = bez((70, 330), (110, 120), tip)           # dos de l'épine
    inner = bez(tip, (230, 190), (250, 420))          # creux de l'épine
    d.polygon(outer + inner[1:] + [(70, 330)], fill=LEAF, outline=LEAF_D, width=W + 2)
    hi = bez((95, 330), (130, 150), (385, 80)) + bez((385, 80), (200, 210), (200, 380))[1:]
    d.polygon(hi, fill=LEAF_L)
    d.line(bez((110, 360), (150, 190), (370, 90)), fill=LEAF_D, width=8)
    d.ellipse([60, 330, 270, 450], fill=BARK_L, outline=BARK_D, width=W)
    d.ellipse([90, 350, 240, 430], fill=BARK)
    drop(d, 400, 300, 50, (150, 80, 200), (70, 30, 110))
    drop(d, 330, 420, 28, (150, 80, 200), (70, 30, 110))
    return im


def nature2():  # Ronces Entravantes : liane épineuse en spirale
    im = canvas(); glow(im, LEAF_L, a=120); d = ImageDraw.Draw(im)
    pts = []
    for i in range(0, 120):
        t = i / 119
        a = t * math.pi * 3.2
        r = 190 * (1 - t * 0.6)
        pts.append((256 + math.cos(a) * r, 270 + math.sin(a) * r * 0.85))
    thick(d, pts, LEAF, LEAF_D, 26)
    for i in range(6, 118, 11):
        x, y = pts[i]
        a = math.atan2(y - 270, x - 256)
        tip = (x + math.cos(a) * 52, y + math.sin(a) * 52)
        px, py = -math.sin(a) * 12, math.cos(a) * 12
        d.polygon([(x + px, y + py), tip, (x - px, y - py)], fill=BARK_L, outline=BARK_D, width=5)
    leaf(d, 330, 120, 90, 40, fill=LEAF_L)
    return im


def nature3():  # Foudre Sauvage : éclair et feuille
    im = canvas(); glow(im, ELEC, a=120); d = ImageDraw.Draw(im)
    leaf(d, 150, 470, 330, -20, fill=LEAF, line=LEAF_D, width=210)
    bolt(d, 250, 40, 230)
    star(d, 410, 330, 36, GOLD_L)
    return im


def wasp(d, cx, cy, s, ang):
    wing = (225, 240, 255, 200)
    d.ellipse([cx - 10 * s, cy - 60 * s, cx + 50 * s, cy], fill=wing, outline=CLOUD_D, width=3)
    d.ellipse([cx - 50 * s, cy - 55 * s, cx + 4 * s, cy - 5 * s], fill=wing, outline=CLOUD_D, width=3)
    d.ellipse([cx - 40 * s, cy - 24 * s, cx + 40 * s, cy + 24 * s], fill=(255, 205, 50), outline=(70, 50, 10), width=5)
    for x in (-12, 8, 26):
        d.rectangle([cx + x * s, cy - 20 * s, cx + (x + 8) * s, cy + 20 * s], fill=(50, 38, 10))
    d.ellipse([cx - 56 * s, cy - 18 * s, cx - 26 * s, cy + 14 * s], fill=(70, 50, 10))
    d.polygon([(cx + 40 * s, cy), (cx + 66 * s, cy + 6 * s), (cx + 40 * s, cy + 12 * s)], fill=(70, 50, 10))


def nature4():  # Essaim de Guêpes
    im = canvas(); glow(im, GOLD_L, a=120); d = ImageDraw.Draw(im)
    wasp(d, 170, 170, 1.5, 0)
    wasp(d, 330, 250, 1.7, 0)
    wasp(d, 200, 360, 1.5, 0)
    wasp(d, 390, 110, 0.9, 0)
    return im


def nature5():  # Bourgeon de Vie : bourgeon rose sur une tige
    im = canvas(); glow(im, PINK, a=110); d = ImageDraw.Draw(im)
    thick(d, [(256, 480), (250, 380), (262, 300)], LEAF, LEAF_D, 22)
    leaf(d, 252, 410, 140, -62)
    leaf(d, 256, 370, 120, 60)
    for a in (-55, -28, 0, 28, 55):
        leaf(d, 262, 300, 190, a, fill=PINK, line=PINK_D, width=100, rib=False)
    d.ellipse([228, 180, 296, 250], fill=GOLD_L, outline=GOLD_D, width=W)
    star(d, 410, 110, 36, (255, 255, 255))
    return im


def nature6():  # Souffle de la Forêt : volutes de vent et feuilles
    im = canvas(); glow(im, LEAF_L, a=120); d = ImageDraw.Draw(im)
    for i, (y, l) in enumerate([(160, 330), (250, 380), (340, 300)]):
        d.arc([60, y - 70, 60 + l, y + 70], 195, 345, fill=(150, 215, 165), width=22)
        d.arc([60, y - 70, 60 + l, y + 70], 195, 345, fill=(230, 255, 235), width=8)
    leaf(d, 150, 150, 120, -30)
    leaf(d, 330, 250, 130, 40, fill=LEAF_L)
    leaf(d, 210, 370, 110, 110)
    leaf(d, 400, 400, 80, -50)
    return im


def nature7():  # Écorce Protectrice : écu d'écorce rond et feuille
    im = canvas(); glow(im, LEAF_L, a=120); d = ImageDraw.Draw(im)
    d.ellipse([70, 70, 442, 442], fill=BARK, outline=BARK_D, width=W + 4)
    for r, col in [(150, BARK_L), (110, BARK), (70, BARK_L), (30, BARK_D)]:
        d.ellipse([256 - r, 256 - r, 256 + r, 256 + r], outline=BARK_D if col != BARK_L else BARK_D, width=8)
    for a in range(0, 360, 45):
        x = 256 + math.cos(math.radians(a)) * 190
        y = 256 + math.sin(math.radians(a)) * 190
        d.ellipse([x - 12, y - 12, x + 12, y + 12], fill=GOLD, outline=GOLD_D, width=3)
    leaf(d, 256, 300, 200, -30, fill=LEAF, line=LEAF_D, width=120)
    leaf(d, 256, 300, 170, 40, fill=LEAF_L, line=LEAF_D, width=100)
    return im


def nature8():  # Sève Régénérante : goutte ambrée, feuille, étincelle
    im = canvas(); glow(im, SAP, a=130); d = ImageDraw.Draw(im)
    drop(d, 256, 260, 120, SAP, SAP_D, hi=(255, 240, 190))
    leaf(d, 150, 420, 130, -40)
    leaf(d, 360, 430, 130, 40, fill=LEAF_L)
    star(d, 400, 110, 40, (255, 255, 255)); star(d, 110, 160, 26, GOLD_L)
    return im


def nature9():  # Arbre-Monde : grand arbre et racines
    im = canvas(); glow(im, LEAF_L, a=130); d = ImageDraw.Draw(im)
    d.polygon([(226, 420), (240, 280), (272, 280), (286, 420), (340, 470), (172, 470)], fill=BARK_L, outline=BARK_D, width=W)
    thick(d, [(250, 330), (180, 270), (150, 200)], BARK, BARK_D, 14)
    thick(d, [(266, 330), (340, 270), (370, 190)], BARK, BARK_D, 14)
    for (x, y, r, col) in [(160, 190, 78, LEAF), (352, 190, 78, LEAF), (256, 110, 92, LEAF), (200, 120, 70, LEAF_L), (312, 120, 70, LEAF_L), (256, 220, 70, LEAF)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=col, outline=LEAF_D, width=W - 2)
    for (x, y, r) in [(230, 80, 22), (330, 150, 18), (150, 160, 16), (260, 200, 14)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=GOLD_L)
    star(d, 440, 60, 34, (255, 255, 255))
    return im


def nature10():  # Ouragan de Feuilles : tornade de feuilles
    im = canvas(); glow(im, LEAF_L, a=110); d = ImageDraw.Draw(im)
    for i, (y, w) in enumerate([(100, 360), (190, 290), (280, 210), (370, 130)]):
        x0 = 256 - w / 2 + (i % 2) * 20
        d.ellipse([x0, y - 34, x0 + w, y + 34], fill=(190, 225, 200, 235), outline=(110, 160, 130), width=6)
        d.arc([x0 + 10, y - 26, x0 + w - 10, y + 26], 200, 340, fill=(255, 255, 255), width=8)
    leaf(d, 90, 150, 90, -70)
    leaf(d, 420, 250, 100, 70, fill=LEAF_L)
    leaf(d, 330, 70, 80, 20)
    leaf(d, 150, 420, 90, -120)
    leaf(d, 380, 440, 90, 120, fill=LEAF_L)
    return im


def nature11():  # Colère de la Nature : grand éclair et ronces
    im = canvas(); glow(im, ELEC, a=130); d = ImageDraw.Draw(im)
    for (x, y, a) in [(120, 470, -25), (392, 470, 25)]:
        pts = []
        for i in range(30):
            t = i / 29
            pts.append((x + math.sin(t * 7 + a) * 28 + a * t * 3, y - t * 250))
        thick(d, pts, LEAF, LEAF_D, 22)
        for i in range(3, 28, 5):
            px, py = pts[i]
            d.polygon([(px, py - 8), (px + (34 if a > 0 else -34), py - 26), (px, py + 8)], fill=BARK_L, outline=BARK_D, width=4)
    bolt(d, 240, 20, 270)
    star(d, 420, 120, 36, (255, 255, 255)); star(d, 90, 150, 26, GOLD_L)
    return im


ICONS = {"class_druid": class_druid, "class_warden": class_warden, "class_stormcaller": class_stormcaller,
         "spell_nature1": nature1, "spell_nature2": nature2, "spell_nature3": nature3, "spell_nature4": nature4, "spell_nature5": nature5,
         "spell_nature6": nature6, "spell_nature7": nature7, "spell_nature8": nature8, "spell_nature9": nature9, "spell_nature10": nature10,
         "spell_nature11": nature11}

if __name__ == "__main__":
    sheet = Image.new("RGBA", (128 * 7, 128 * 2), (30, 24, 20, 255))
    for i, (k, fn) in enumerate(ICONS.items()):
        small = fn().resize((128, 128), Image.LANCZOS)
        small.save(os.path.join(OUT, "%s.png" % k))
        sheet.alpha_composite(small, ((i % 7) * 128, (i // 7) * 128))
    sheet.save(os.environ.get("SHEET", "/tmp/druid_sheet.png"))
