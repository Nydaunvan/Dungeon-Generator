#!/usr/bin/env python3
"""Collier de perles et de crocs (case 151 de la planche d'objets, `spr_151`) : rogné à droite par le bord de l'image d'origine (coupure verticale
à x = 108 sur 128). Le collier est symétrique gauche / droite : la partie manquante est reprise telle quelle sur la moitié gauche retournée
(axe trouvé par recherche de la meilleure symétrie), sans aucun dessin ajouté. Écrit assets/icons/spr_151.png (l'icône individuelle est
prioritaire sur la planche, qui n'est pas ré-encodée). Usage : python3 tools/fix_necklace.py"""
import numpy as np
from PIL import Image
from scipy import ndimage

SHEET = "assets/sheets/items_sheet.webp"
IDX = 151
sh = Image.open(SHEET).convert("RGBA")
x0, y0 = (IDX % 8) * 128, (IDX // 8) * 128
C = np.array(sh.crop((x0, y0, x0 + 128, y0 + 128))).astype(float)
A = C[..., 3] > 128
xs = np.nonzero(A.any(0))[0]
left, right = xs.min(), xs.max()
print("emprise x :", left, right)

def mirror(cx):
    X = np.arange(128)
    src = 2 * cx - X
    out = np.zeros_like(C)
    for ch in range(4):
        for y in range(128):
            out[y, :, ch] = np.interp(src, X, C[y, :, ch], left=0, right=0)
    return out

best = None
for cx in np.arange(60.0, 78.0, 0.25):
    M = mirror(cx)
    reg = np.zeros((128, 128), bool)
    reg[:, int(cx) + 4:right - 3] = True        # moitié droite existante, hors bord coupé
    ok = reg & A & (M[..., 3] > 200)
    if ok.sum() < 300:
        continue
    err = ((C[..., :3] - M[..., :3]) ** 2)[ok].mean()
    if best is None or err < best[0]:
        best = (err, cx)
print("axe de symétrie : x = %.2f (erreur %.0f)" % (best[1], best[0]))
M = mirror(best[1])
xx = np.mgrid[0:128, 0:128][1]
fill = (~A) & (M[..., 3] > 128) & (xx >= right - 5)
out = C.copy()
dist = ndimage.distance_transform_edt(~A)
w = np.clip(dist / 4.0, 0, 1)                   # raccord : fondu sur 4 px près de la coupure
out[fill, :3] = (M[..., :3] * w[..., None] + C[..., :3] * (1 - w[..., None]))[fill]
out[fill, 3] = 255
# sur la bande coupée (5 px avant le bord), les perles tronquées sont remplacées par leur copie complète, fondue avec l'original
band = A & (xx >= right - 5) & (M[..., 3] > 200)
wb = np.clip((xx - (right - 5)) / 5.0, 0, 1)[..., None]
out[band, :3] = (M[..., :3] * wb + C[..., :3] * (1 - wb))[band]
alpha = out[..., 3] / 255.0
alpha = np.where(fill, ndimage.gaussian_filter(alpha, 0.6), alpha)
out[..., 3] = np.clip(alpha, 0, 1) * 255
known = A | fill
_, (iy, ix) = ndimage.distance_transform_edt(~known, return_indices=True)
miss = (out[..., 3] > 128) & ~known
out[miss, :3] = out[iy, ix][miss, :3]
img = Image.fromarray(out.astype(np.uint8), "RGBA")
img.save("assets/icons/spr_151.png")
print("écrit assets/icons/spr_151.png", img.getchannel("A").getbbox())
