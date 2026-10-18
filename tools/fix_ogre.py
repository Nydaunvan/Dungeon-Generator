#!/usr/bin/env python3
"""Complète le marteau de l'ogre (assets/monsters/m22.webp + case 22 de la planche des monstres) : la tête arrière du marteau était
rognée à plat par le bord de l'image d'origine. On dessine le haut manquant de cette tête (face supérieure, arêtes claires, contour) sous les pixels
existants ; l'image gagne 20 px de marge en haut puis revient à 440 px (l'ogre est réduit de ~4,5 %).
Usage : python3 tools/fix_ogre.py <m22_original.webp> -   (écrit assets/monsters/m22.webp ; la fiche du monstre lit désormais ce fichier, pas la planche)"""
import sys
from PIL import Image, ImageDraw
import numpy as np

PAD = 20
SS = 4                    # sur-échantillonnage du dessin (bords lissés)
src_m22 = sys.argv[1]
m = Image.open(src_m22).convert("RGBA")
W, H = m.size
big = Image.new("RGBA", (W, H + PAD), (0, 0, 0, 0))
big.alpha_composite(m, (0, PAD))
a = np.array(big)
def sample(x0, x1, y0, y1):
    reg = a[PAD + y0:PAD + y1, x0:x1].reshape(-1, 4).astype(float)
    reg = reg[reg[:, 3] > 200]
    return tuple(int(v) for v in reg[:, :3].mean(0))
face = sample(160, 190, 14, 18)         # gris de la face supérieure (bande visible juste sous la coupure)
dark = sample(204, 216, 13, 16)         # face latérale sombre
bev = (236, 228, 212)                   # arête claire
line = (22, 17, 22)                     # contour
def P(x, y): return ((x) * SS, (y + PAD) * SS)
layer = Image.new("RGBA", (W * SS, (H + PAD) * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)
A_, T_, U_, B_ = (143, 12), (157, -4), (209, 7), (203, 12)
# contour sombre un peu plus large que les formes
for poly, col in [([A_, T_, U_, (219, 8.4), (230, 12), (230, 20), (143, 20)], line)]:
    d.polygon([P(x, y) for x, y in poly], fill=line + (255,))
d.polygon([P(x, y) for x, y in [(A_[0] + 1.5, A_[1] + 8), (A_[0] + 2, A_[1]), T_, (U_[0] - 0.5, U_[1]), (B_[0], B_[1] + 8)]], fill=face + (255,))
d.polygon([P(x, y) for x, y in [B_, U_, (219, 8.4), (219, 14)]], fill=dark + (255,))
d.polygon([P(x, y) for x, y in [(218, 14), (219, 8.4), (222.5, 9.5), (229, 14)]], fill=bev + (255,))
# arêtes claires (haut-gauche et haut-droite de la face supérieure)
d.line([P(A_[0] + 2.5, A_[1] + 1), P(T_[0] + 0.5, T_[1] + 2.2)], fill=bev + (255,), width=int(2.2 * SS))
d.line([P(T_[0] + 1.5, T_[1] + 2.4), P(U_[0] - 1.5, U_[1] + 1.4)], fill=bev + (255,), width=int(2.0 * SS))
# contour sombre propre sur l'extérieur : on évide l'intérieur déjà peint puis on redessine le contour fin
under = layer.resize((W, H + PAD), Image.LANCZOS)
res = Image.alpha_composite(under, big)
res = res.resize((W, H), Image.LANCZOS)
res.save("assets/monsters/m22.webp", lossless=True, quality=100, method=6)
print("m22 écrit", res.getchannel("A").getbbox())
