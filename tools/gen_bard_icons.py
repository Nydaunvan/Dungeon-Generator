"""Icônes des sorts du Barde, du Skalde et du Ménestrel (128×128, fond transparent, couleurs claires comme `spell_sonicnote`).
Usage : python3 tools/gen_bard_icons.py  → écrit assets/icons/spell_<id>.png (Godot réimporte au prochain lancement de l'éditeur)."""
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
GOLD, GOLD_D, GOLD_L = (247, 184, 52), (170, 104, 16), (255, 230, 130)
BLUE, BLUE_D, BLUE_L = (96, 200, 250), (28, 104, 190), (190, 236, 255)
RED, RED_D = (240, 90, 60), (150, 36, 28)
GREEN, GREEN_D = (110, 220, 120), (30, 130, 60)
VIO, VIO_D, VIO_L = (190, 140, 250), (96, 56, 170), (230, 210, 255)
ORG = (255, 150, 40)
W = 7

def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))

def glow(im, color, cx=256, cy=256, r=200, a=120):
    g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    g = g.filter(ImageFilter.GaussianBlur(r * 0.45))
    im.alpha_composite(g)

def note(d, x, y, s, fill=GOLD, line=GOLD_D, flag=True):
    """Croche : tête en (x, y), taille s."""
    d.line([(x + s * 0.42, y), (x + s * 0.42, y - s * 2.7)], fill=line, width=int(s * 0.34))
    d.line([(x + s * 0.42, y), (x + s * 0.42, y - s * 2.7)], fill=fill, width=int(s * 0.2))
    if flag:
        pts = [(x + s * 0.42, y - s * 2.7), (x + s * 1.3, y - s * 2.2), (x + s * 1.35, y - s * 1.5), (x + s * 0.42, y - s * 1.9)]
        d.polygon(pts, fill=fill, outline=line, width=W // 2)
    d.ellipse([x - s * 0.55, y - s * 0.35, x + s * 0.55, y + s * 0.35], fill=fill, outline=line, width=W)

def waves(d, cx, cy, r0, n, color, width=14, span=50):
    for i in range(n):
        r = r0 + i * 44
        d.arc([cx - r, cy - r, cx + r, cy + r], -span, span, fill=color, width=width)

def shield(d, cx, cy, w, h, fill, line, inner):
    top = cy - h / 2
    pts = [(cx - w / 2, top), (cx + w / 2, top), (cx + w / 2, cy + h * 0.1), (cx, cy + h / 2), (cx - w / 2, cy + h * 0.1)]
    d.polygon(pts, fill=fill, outline=line, width=W + 2)
    k = 0.8
    pts2 = [(cx - w / 2 * k, top + h * 0.1), (cx + w / 2 * k, top + h * 0.1), (cx + w / 2 * k, cy + h * 0.05), (cx, cy + h * 0.4), (cx - w / 2 * k, cy + h * 0.05)]
    d.polygon(pts2, fill=inner)

def star(d, cx, cy, r, color):
    pts = []
    for i in range(8):
        a = math.pi / 4 * i
        rr = r if i % 2 == 0 else r * 0.3
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=color)

def bard1():  # Souffle du Guerrier : croche dorée emportée par un souffle vert (endurance)
    im = canvas(); glow(im, GREEN_L := (200, 255, 200), a=140); d = ImageDraw.Draw(im)
    for i, (y, l) in enumerate([(170, 250), (250, 300), (330, 240)]):
        d.arc([60, y - 60, 60 + l, y + 60], 200, 340, fill=GREEN, width=20)
        d.arc([60, y - 60, 60 + l, y + 60], 200, 340, fill=(230, 255, 230), width=7)
    note(d, 240, 360, 110)
    star(d, 400, 130, 46, GOLD_L)
    return im

def skald1():  # Frappe Discordante : tambour et baguettes, éclat d'impact
    im = canvas(); glow(im, (255, 210, 190), a=130); d = ImageDraw.Draw(im)
    d.rectangle([110, 250, 400, 380], fill=RED, outline=RED_D, width=W)
    for x in range(140, 400, 52):
        d.line([(x, 250), (x + 26, 380), (x + 52, 250)], fill=GOLD_L, width=9)
    d.ellipse([110, 200, 400, 300], fill=(255, 240, 220), outline=GOLD_D, width=W)
    d.ellipse([110, 340, 400, 420], fill=RED, outline=RED_D, width=W)
    d.rectangle([112, 340, 398, 380], fill=RED)
    d.line([(150, 70), (270, 230)], fill=GOLD_D, width=30); d.line([(150, 70), (270, 230)], fill=GOLD, width=18)
    d.line([(380, 70), (250, 230)], fill=GOLD_D, width=30); d.line([(380, 70), (250, 230)], fill=GOLD, width=18)
    star(d, 258, 232, 64, (255, 250, 200))
    return im

def skald2():  # Armure de Vers : écu doré marqué d'une croche
    im = canvas(); glow(im, BLUE_L, a=130); d = ImageDraw.Draw(im)
    shield(d, 256, 262, 300, 380, GOLD, GOLD_D, BLUE)
    note(d, 235, 330, 80, fill=(255, 255, 255), line=BLUE_D)
    return im

def skald3():  # Cri de Guerre : cor de chasse et ondes de choc rouges
    im = canvas(); glow(im, (255, 200, 170), cx=220, a=130); d = ImageDraw.Draw(im)
    horn = [(70, 300), (330, 150), (380, 250), (130, 360)]
    d.polygon(horn, fill=GOLD, outline=GOLD_D, width=W + 2)
    d.polygon([(70, 300), (130, 360), (95, 395), (45, 345)], fill=GOLD_L, outline=GOLD_D, width=W)
    d.ellipse([300, 140, 400, 270], fill=(255, 240, 200), outline=GOLD_D, width=W + 2)
    for i, c in enumerate([RED, ORG, RED]):
        r = 110 + i * 42
        d.arc([320 - r, 205 - r, 320 + r, 205 + r], -48, 48, fill=c, width=22 - i * 3)
    return im

def skald4():  # Lame de l'Épopée : épée enflammée
    im = canvas(); glow(im, (255, 215, 150), a=150); d = ImageDraw.Draw(im)
    d.polygon([(256, 40), (292, 120), (292, 330), (220, 330), (220, 120)], fill=(240, 246, 255), outline=(90, 110, 150), width=W)
    d.line([(256, 60), (256, 320)], fill=(190, 210, 240), width=8)
    d.rounded_rectangle([160, 330, 350, 362], 12, fill=GOLD, outline=GOLD_D, width=W)
    d.rectangle([240, 362, 272, 440], fill=(150, 80, 40), outline=(90, 45, 20), width=W)
    d.ellipse([228, 430, 284, 480], fill=GOLD, outline=GOLD_D, width=W)
    for x, h in [(200, 200), (330, 170), (255, 90)]:
        d.polygon([(x - 38, 280), (x - 28, 280 - h * 0.6), (x, 280 - h), (x + 20, 280 - h * 0.5), (x + 38, 280)], fill=ORG)
        d.polygon([(x - 20, 270), (x, 280 - h * 0.65), (x + 14, 270)], fill=(255, 235, 120))
    return im

def minstrel1():  # Berceuse Apaisante : croissant de lune, « z » et croche
    im = canvas(); glow(im, VIO_L, a=150); d = ImageDraw.Draw(im)
    d.ellipse([90, 90, 400, 400], fill=GOLD_L, outline=GOLD_D, width=W)
    d.ellipse([170, 60, 460, 350], fill=(0, 0, 0, 0))
    im2 = canvas(); d2 = ImageDraw.Draw(im2)
    d2.ellipse([90, 110, 380, 400], fill=GOLD_L, outline=GOLD_D, width=W)
    d2.ellipse([180, 70, 460, 350], fill=(0, 0, 0, 0))
    mask = Image.new("L", (S, S), 255); ImageDraw.Draw(mask).ellipse([185, 70, 465, 350], fill=0)
    im2.putalpha(Image.composite(im2.getchannel("A"), Image.new("L", (S, S), 0), mask))
    im = canvas(); glow(im, VIO_L, a=150); im.alpha_composite(im2); d = ImageDraw.Draw(im)
    for (x, y, s) in [(330, 330, 70), (400, 250, 52), (440, 180, 38)]:
        zz = [(x, y), (x + s, y), (x, y + s), (x + s, y + s)]
        d.line(zz, fill=VIO_D, width=18, joint="curve"); d.line(zz, fill=VIO, width=9, joint="curve")
    note(d, 160, 420, 60, fill=VIO, line=VIO_D)
    return im

def minstrel2():  # Ballade Protectrice : bulle de lumière bleue, croches
    im = canvas(); glow(im, BLUE_L, a=150); d = ImageDraw.Draw(im)
    d.ellipse([60, 60, 452, 452], fill=BLUE_L + (200,), outline=BLUE_D, width=W + 3)
    d.arc([100, 100, 412, 412], 200, 290, fill=(255, 255, 255), width=18)
    note(d, 200, 340, 70, fill=GOLD, line=GOLD_D)
    note(d, 320, 300, 60, fill=GOLD, line=GOLD_D, flag=False)
    d.line([(246, 340 - 189), (362 + 0, 300 - 162)], fill=GOLD_D, width=16)
    return im

def minstrel3():  # Requiem de Vigueur : trompette dorée et étincelles vertes
    im = canvas(); glow(im, (210, 255, 210), a=140); d = ImageDraw.Draw(im)
    d.rounded_rectangle([60, 235, 330, 285], 22, fill=GOLD, outline=GOLD_D, width=W)
    d.polygon([(320, 215), (450, 120), (450, 400), (320, 305)], fill=GOLD, outline=GOLD_D, width=W + 2)
    d.ellipse([410, 120, 480, 400], fill=GOLD_L, outline=GOLD_D, width=W)
    for x in (120, 190, 260):
        d.rounded_rectangle([x, 195, x + 28, 235], 8, fill=GOLD_L, outline=GOLD_D, width=W // 2 + 1)
    d.arc([60, 250, 190, 380], 90, 270, fill=GOLD_D, width=18)
    for (x, y, r) in [(110, 120, 40), (210, 70, 28), (150, 400, 34)]:
        star(d, x, y, r, GREEN)
    return im

def minstrel4():  # Mélodie de Dissipation : carillon, éclat violet
    im = canvas(); glow(im, VIO_L, a=160); d = ImageDraw.Draw(im)
    d.rounded_rectangle([90, 70, 420, 110], 14, fill=GOLD, outline=GOLD_D, width=W)
    for i, (x, h) in enumerate([(130, 220), (205, 300), (280, 260), (355, 190)]):
        d.line([(x, 110), (x, 110 + 60)], fill=GOLD_D, width=6)
        d.rounded_rectangle([x - 20, 170, x + 20, 170 + h * 0.8], 14, fill=VIO if i % 2 == 0 else BLUE, outline=VIO_D, width=W)
        d.rectangle([x - 14, 176, x - 8, 170 + h * 0.8 - 8], fill=(255, 255, 255, 170))
    for (x, y, r) in [(60, 330, 46), (450, 360, 50), (250, 460, 34)]:
        star(d, x, y, r, (255, 255, 255)); star(d, x, y, r * 0.6, VIO)
    return im

ICONS = {"bard1": bard1, "skald1": skald1, "skald2": skald2, "skald3": skald3, "skald4": skald4,
         "minstrel1": minstrel1, "minstrel2": minstrel2, "minstrel3": minstrel3, "minstrel4": minstrel4}

if __name__ == "__main__":
    sheet = Image.new("RGBA", (128 * 5, 128 * 2), (30, 24, 20, 255))
    for i, (k, fn) in enumerate(ICONS.items()):
        small = fn().resize((128, 128), Image.LANCZOS)
        small.save(os.path.join(OUT, "spell_%s.png" % k))
        sheet.alpha_composite(small, ((i % 5) * 128, (i // 5) * 128))
    sheet.save(os.environ.get("SHEET", "/tmp/bard_sheet.png"))
