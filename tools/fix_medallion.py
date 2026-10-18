#!/usr/bin/env python3
"""Médaillon de bronze rond (case 147 de la planche d'objets, `spr_147`) : le disque est rogné à droite par le bord de l'image d'origine
(coupure verticale à x ≈ 117 sur 128). Le médaillon est symétrique gauche / droite : la partie manquante est reprise telle quelle sur
la moitié gauche retournée (axe trouvé par recherche de la meilleure symétrie), sans aucun dessin ajouté. Écrit assets/icons/spr_147.png
(l'icône individuelle est prioritaire sur la planche, qui n'est pas ré-encodée).
Usage : python3 tools/fix_medallion.py"""
import numpy as np
from PIL import Image
from scipy import ndimage

SHEET = "assets/sheets/items_sheet.webp"
IDX = 147
sh = Image.open(SHEET).convert("RGBA")
x0, y0 = (IDX % 8) * 128, (IDX // 8) * 128
cell = sh.crop((x0, y0, x0 + 128, y0 + 128))
C = np.array(cell).astype(float)
A = C[..., 3] > 128
xs = np.nonzero(A.any(0))[0]
right = xs.max()
left = xs.min()
print("emprise x :", left, right)

def mirror(cx):
    """Image retournée autour de l'axe x = cx (en pixels, demi-pixels permis)."""
    X = np.arange(128)
    src = 2 * cx - X
    out = np.zeros_like(C)
    for ch in range(4):
        for y in range(128):
            out[y, :, ch] = np.interp(src, X, C[y, :, ch], left=0, right=0)
    return out

best = None
for cx in np.arange(60.0, 76.0, 0.5):
    M = mirror(cx)
    reg = np.zeros((128, 128), bool)
    reg[:, int(cx) + 6:right - 2] = True
    ok = reg & A & (M[..., 3] > 200)
    if ok.sum() < 500:
        continue
    err = ((C[..., :3] - M[..., :3]) ** 2)[ok].mean()
    if best is None or err < best[0]:
        best = (err, cx)
print("axe de symétrie : x =", best[1], " (erreur %.0f)" % best[0])
M = mirror(best[1])
# rayon et centre du disque d'après les bords haut, bas et gauche
ys = np.nonzero(A.any(1))[0]
cy = (ys.min() + ys.max()) / 2.0
R = (ys.max() - ys.min()) / 2.0
yy, xx = np.mgrid[0:128, 0:128]
inside = (xx - best[1]) ** 2 + (yy - cy) ** 2 <= (R + 0.5) ** 2
fill = (~A) & inside & (M[..., 3] > 128)
out = C.copy()
# raccord : sur 5 px près de la coupure, on fond la copie avec l'original pour éviter une couture visible
dist = ndimage.distance_transform_edt(~A)
w = np.clip(dist / 5.0, 0, 1)
fd = fill
out[fd, :3] = (M[..., :3] * w[..., None] + C[..., :3] * (1 - w[..., None]))[fd]
out[fd, 3] = 255
# la bande de bord de la partie d'origine garde ses pixels ; on lisse seulement l'alpha du pourtour reconstruit
alpha = out[..., 3] / 255.0
alpha = np.where(fill, ndimage.gaussian_filter(alpha, 0.6), alpha)
alpha = np.clip(alpha, 0, 1)
alpha = np.maximum(alpha, ndimage.binary_fill_holes(alpha > 0.5) * 1.0)       # pas de trou isolé dans le disque
out[..., 3] = alpha * 255
# pixels devenus opaques sans couleur fiable : couleur du plus proche pixel d'origine
known = A | fill
_, (iy, ix) = ndimage.distance_transform_edt(~known, return_indices=True)
miss = (alpha > 0.5) & ~known
out[miss, :3] = out[iy, ix][miss, :3]
Image.fromarray(out.astype(np.uint8), "RGBA").save("assets/icons/spr_147.png")
bb = Image.fromarray(out.astype(np.uint8), "RGBA").getchannel("A").getbbox()
print("écrit assets/icons/spr_147.png", bb)
