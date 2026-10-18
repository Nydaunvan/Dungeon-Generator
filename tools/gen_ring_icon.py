#!/usr/bin/env python3
"""Dessine l'anneau d'or (assets/icons/ring_gold.png, 256 px) : tore doré rendu en perspective orthographique, métal éclairé, bords lissés.
L'ancienne vignette de la planche d'objets (case 40) était rognée sur les côtés. Usage : python3 tools/gen_ring_icon.py"""
import numpy as np
from PIL import Image
import os

S = 1024                      # toile de calcul (réduite ensuite à 256)
R = 1.0
NU, NV = 5200, 1600
u = np.linspace(0, 2 * np.pi, NU, endpoint=False)[:, None]
v = np.linspace(0, 2 * np.pi, NV, endpoint=False)[None, :]
# anneau « jonc » : section arrondie plus large (axe) qu'épaisse (rayon), bord légèrement bombé
def spow(t, p):
    return np.sign(t) * np.abs(t) ** p
a_rad, b_ax, pw = 0.12, 0.27, 0.6
top = np.clip(np.sin(u), 0, 1) ** 2          # épaulements : le jonc s'élargit vers le haut (comme les autres anneaux)
rad = R + a_rad * (1 + 0.5 * top) * spow(np.cos(v), pw)
x = rad * np.cos(u) + 0 * v
y = rad * np.sin(u) + 0 * v
z = b_ax * (1 + 0.55 * top) * spow(np.sin(v), pw) + 0 * u
# normales par différences finies sur la grille (u : tour, v : section)
Pg = np.stack([x, y, z], axis=2)
du = np.roll(Pg, -1, 0) - np.roll(Pg, 1, 0)
dv = np.roll(Pg, -1, 1) - np.roll(Pg, 1, 1)
Ng = np.cross(du, dv)
Ng /= np.maximum(np.linalg.norm(Ng, axis=2, keepdims=True), 1e-9)
# orienter vers l'extérieur de la matière : produit scalaire avec (position - centre de la section) positif
cen = np.stack([R * np.cos(u) + 0 * v, R * np.sin(u) + 0 * v, 0 * z], axis=2)
sgn = np.sign(((Pg - cen) * Ng).sum(2, keepdims=True)); sgn[sgn == 0] = 1
Ng *= sgn
nx, ny, nz = Ng[..., 0], Ng[..., 1], Ng[..., 2]

def rot_x(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
def rot_z(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
M = rot_z(np.radians(-8)) @ rot_x(np.radians(38))
P = np.stack([x.ravel(), y.ravel(), z.ravel()])
N = np.stack([nx.ravel(), ny.ravel(), nz.ravel()])
P = M @ P
N = M @ N
px, py, pz = P
# cadrage : l'anneau remplit ~88 % de la toile
w = (px.max() - px.min()); h = (py.max() - py.min())
sc = 0.88 * S / max(w, h)
cx = (px.max() + px.min()) / 2; cy = (py.max() + py.min()) / 2
ix = np.clip(((px - cx) * sc + S / 2).astype(int), 0, S - 1)
iy = np.clip((-(py - cy) * sc + S / 2).astype(int), 0, S - 1)
facing = N[2]                                          # la caméra regarde vers -z → visible si n.z > 0
vis = facing > -0.05
idx = iy * S + ix
order = np.argsort(pz[vis])                              # du plus loin au plus près : la dernière écriture gagne
sel = np.nonzero(vis)[0][order]
UU = (u + 0 * v).ravel(); VV = (v + 0 * u).ravel()
buf_uv = np.zeros((S * S, 2)); buf_n = np.zeros((S * S, 3)); buf_p = np.zeros((S * S, 3)); mask = np.zeros(S * S, bool)
buf_n[idx[sel]] = N[:, sel].T
buf_p[idx[sel]] = P[:, sel].T
buf_uv[idx[sel]] = np.stack([UU[sel], VV[sel]], 1)
mask[idx[sel]] = True
n = buf_n.reshape(S, S, 3); m = mask.reshape(S, S); uvm = buf_uv.reshape(S, S, 2)
# fermeture des trous de l'échantillonnage : chaque pixel vide prend la normale du plus proche pixel plein
from scipy import ndimage
m = ndimage.binary_closing(m, iterations=3)
solid = np.abs(n).sum(2) > 0
_, (iy2, ix2) = ndimage.distance_transform_edt(~solid, return_indices=True)
n = n[iy2, ix2]
uvm = uvm[iy2, ix2]
n = n / np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)
# éclairage métallique
Lv = np.array([-0.45, 0.65, 0.62]); Lv /= np.linalg.norm(Lv)
V = np.array([0.0, 0.0, 1.0])
nv = np.clip(n[..., 2], 0, 1)
diff = np.clip((n * Lv).sum(2), 0, 1)
H = Lv + V; H /= np.linalg.norm(H)
spec = np.clip((n * H).sum(2), 0, 1) ** 55
spec2 = np.clip((n * np.array([0.6, -0.5, 0.6]) / 0.98).sum(2), 0, 1) ** 30       # reflet secondaire, plus doux
rf = 2 * nv[..., None] * n - V                                                    # vecteur réfléchi (environnement)
env = np.clip(0.5 + 0.5 * rf[..., 1], 0, 1)                                       # ciel clair en haut, sol sombre en bas
env = env ** 1.6
band = 0.5 + 0.5 * np.sin(rf[..., 1] * 7.0 + rf[..., 0] * 2.0)                  # bandes de reflet du métal poli
base_dark = np.array([0.38, 0.22, 0.03]); base_mid = np.array([0.86, 0.60, 0.07]); base_hi = np.array([1.0, 0.86, 0.38])
t = np.clip(0.18 + 0.52 * diff + 0.55 * env * (0.6 + 0.4 * band) - 0.15, 0, 1)[..., None]
# posterisation douce : quelques paliers de lumière comme dans les dessins peints des autres anneaux
t = 0.45 * t + 0.55 * (np.round(t[..., 0] * 5) / 5)[..., None]
col = np.where(t < 0.5, base_dark + (base_mid - base_dark) * (t / 0.5), base_mid + (base_hi - base_mid) * ((t - 0.5) / 0.5))
col = col + spec[..., None] * np.array([1.0, 0.95, 0.8]) * 0.8 + spec2[..., None] * np.array([1, 0.85, 0.5]) * 0.2
# gravures : deux filets qui divergent sur les épaulements + filet de rive sur tout le tour
U_ = uvm[..., 0]; V_ = uvm[..., 1]
vv = np.where(V_ > np.pi, V_ - 2 * np.pi, V_)                   # -pi..pi, 0 = face extérieure du jonc
du_ = np.abs(((U_ - np.pi / 2 + np.pi) % (2 * np.pi)) - np.pi)
vt = 0.18 + 0.85 * np.clip(du_ / 0.95, 0, 1)
fork = (du_ < 0.95) & (np.abs(np.abs(vv) - vt) < 0.07)
rim_ln = (np.abs(np.abs(vv) - 1.15) < 0.05)
groove = (fork | rim_ln) & m
gl = ndimage.gaussian_filter(groove.astype(float), 0.9)
col = col * (1 - 0.55 * gl[..., None])
hl = ndimage.shift(gl, (2.2, 1.2), order=1) * (1 - gl)          # fin liseré clair sous chaque filet
col = col + hl[..., None] * np.array([0.55, 0.45, 0.15]) * 0.7
rim = (1 - nv) ** 2.2                                                              # bord un peu assombri : donne du volume
col = col * (1 - 0.35 * rim[..., None])
col = np.clip(col, 0, 1)
alpha = ndimage.gaussian_filter(m.astype(float), 1.1)
alpha = np.clip((alpha - 0.5) * 3.0 + 0.5, 0, 1)
edge = ndimage.binary_dilation(m, iterations=9)                                   # contour brun foncé (~2 px à 256) comme les autres icônes
ring_alpha = np.clip((ndimage.gaussian_filter(edge.astype(float), 1.1) - 0.5) * 3.0 + 0.5, 0, 1)
outline = np.array([0.20, 0.11, 0.03])
col = col * alpha[..., None] + outline * (1 - alpha[..., None])
alpha = np.maximum(alpha, ring_alpha)
rgba = np.dstack([col, alpha])
im = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")
# ombre portée douce sous l'anneau
sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
a = (ndimage.gaussian_filter(np.roll(alpha, (22, 6), (0, 1)), 14) * 0.40 * 255).astype(np.uint8)
sh.putalpha(Image.fromarray(a))
out = Image.alpha_composite(sh, im).resize((256, 256), Image.LANCZOS)
dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "icons", "ring_gold.png")
out.save(dst)
print("écrit", dst, out.getchannel("A").getbbox())
