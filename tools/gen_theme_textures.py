#!/usr/bin/env python3
"""Génère les textures PBR des thèmes « dirt » (terre), « ice » (glace) et « ruins » (ruines) : wall / floor / ceil, en <thème>_hd (2048) et <thème>_lite (1024).

Même méthode et mêmes formats que le thème gothic (tools/gen_gothic_textures.py, dont ce script réutilise les briques) : tuile de 4 × 4 unités = une case,
bruit périodique (raccord dans les deux sens), albédo JPG sRGB, normale PNG OpenGL (Y+), ORM JPG (R = occlusion, G = rugosité, B = métal = 0).
Textures PROCÉDURALES (graines fixes, reproductibles) : bien meilleures que les anciens aplats, mais pas des textures peintes ou scannées.
Usage : python3 tools/gen_theme_textures.py [dossier_assets_themes] [thème ...]
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_gothic_textures as G
from gen_gothic_textures import fbm, smooth, masonry, voronoi, per_block, down, normal_map, to_u8

N = G.N

# structure : ("masonry", échelle) ou ("voronoi", g, jitter) ; joint_half / bevel en pixels (tuile 2048) ; relief ; tilt_k ; base RVB ; tone_sd ; strength (normale)
SPECS = {
    "ruins": {
        "wall": {"st": ("masonry", 0.62), "joint": 6.5, "bevel": 34.0, "relief": 0.85, "tilt": 0.10, "base": (0.355, 0.335, 0.295), "tone": 0.17, "strength": 15.0, "jc": (0.150, 0.125, 0.095), "rough": 0.86},
        "floor": {"st": ("voronoi", 5, 0.46), "joint": 7.0, "bevel": 30.0, "relief": 0.70, "tilt": 0.10, "base": (0.300, 0.282, 0.255), "tone": 0.15, "strength": 12.0, "jc": (0.135, 0.105, 0.078), "rough": 0.88},
        "ceil": {"st": ("voronoi", 3, 0.44), "joint": 8.0, "bevel": 46.0, "relief": 0.95, "tilt": 0.16, "base": (0.215, 0.205, 0.190), "tone": 0.15, "strength": 22.0, "jc": (0.100, 0.085, 0.068), "rough": 0.92},
    },
    "dirt": {
        "wall": {"st": ("voronoi", 7, 0.46), "joint": 3.0, "bevel": 95.0, "relief": 1.15, "tilt": 0.16, "base": (0.330, 0.225, 0.140), "tone": 0.17, "strength": 17.0, "jc": (0.140, 0.092, 0.055), "rough": 0.93},
        "floor": {"st": ("voronoi", 13, 0.48), "joint": 2.5, "bevel": 70.0, "relief": 0.85, "tilt": 0.10, "base": (0.285, 0.200, 0.128), "tone": 0.13, "strength": 12.0, "jc": (0.150, 0.100, 0.060), "rough": 0.95},
        "ceil": {"st": ("voronoi", 5, 0.48), "joint": 3.0, "bevel": 110.0, "relief": 1.30, "tilt": 0.20, "base": (0.205, 0.140, 0.090), "tone": 0.16, "strength": 22.0, "jc": (0.100, 0.066, 0.040), "rough": 0.96},
    },
    "ice": {
        "wall": {"st": ("voronoi", 5, 0.47), "joint": 2.2, "bevel": 24.0, "relief": 0.55, "tilt": 0.14, "base": (0.470, 0.620, 0.745), "tone": 0.10, "strength": 10.0, "jc": (0.78, 0.88, 0.96), "rough": 0.34},
        "floor": {"st": ("voronoi", 4, 0.46), "joint": 2.0, "bevel": 20.0, "relief": 0.35, "tilt": 0.07, "base": (0.400, 0.545, 0.680), "tone": 0.09, "strength": 7.0, "jc": (0.70, 0.82, 0.92), "rough": 0.20},
        "ceil": {"st": ("voronoi", 4, 0.47), "joint": 3.0, "bevel": 40.0, "relief": 0.85, "tilt": 0.14, "base": (0.230, 0.320, 0.425), "tone": 0.12, "strength": 17.0, "jc": (0.46, 0.58, 0.70), "rough": 0.48},
    },
    # « Les Forges du monde brisé » (thème lave v2) : basalte noir, obsidienne, cendre chaude ; le magma n'est pas dans ces textures (voir LavaKit / ThemeMaterials)
    "lava2": {
        "wall": {"st": ("masonry", 1.5), "joint": 10.0, "bevel": 58.0, "relief": 1.15, "tilt": 0.14, "base": (0.300, 0.312, 0.335), "tone": 0.16, "strength": 17.0, "jc": (0.085, 0.050, 0.048), "rough": 0.84},
        "floor": {"st": ("voronoi", 4, 0.36), "joint": 5.5, "bevel": 30.0, "relief": 0.6, "tilt": 0.07, "base": (0.245, 0.252, 0.272), "tone": 0.13, "strength": 11.0, "jc": (0.095, 0.058, 0.052), "rough": 0.70},
        "ceil": {"st": ("voronoi", 3, 0.42), "joint": 9.0, "bevel": 60.0, "relief": 1.25, "tilt": 0.20, "base": (0.175, 0.180, 0.195), "tone": 0.15, "strength": 26.0, "jc": (0.062, 0.036, 0.034), "rough": 0.90},
    },
}


def build(theme, part, seed):
    sp = SPECS[theme][part]
    rng = np.random.default_rng(seed)
    n = N
    wx = fbm(n, 1.6, seed + 1, lo=2, hi=40) * 10.0 + fbm(n, 1.0, seed + 2, lo=20, hi=300) * 2.5
    wy = fbm(n, 1.6, seed + 3, lo=2, hi=40) * 10.0 + fbm(n, 1.0, seed + 4, lo=20, hi=300) * 2.5
    mid = fbm(n, 1.5, seed + 5, lo=3, hi=60)
    fine = fbm(n, 1.0, seed + 6, lo=30, hi=260)
    grain = fbm(n, 0.4, seed + 7, lo=100, hi=420)
    streak = fbm(n, 1.6, seed + 8, lo=2, hi=60, ax=7.0)
    broad = fbm(n, 1.9, seed + 11, lo=1, hi=5)
    pool = fbm(n, 1.4, seed + 14, lo=3, hi=22)
    st = sp["st"]
    if st[0] == "masonry":
        dist, bid, u, v, cnt = masonry(n, rng, wx, wy, st[1])
    else:
        dist, bid, u, v, cnt = voronoi(n, rng, st[1], wx, wy, jitter=st[2])
    tone = np.clip(np.exp(per_block(rng, cnt, sp["tone"])), 0.72, 1.14)
    hue = per_block(rng, cnt, 0.04)
    tiltx = per_block(rng, cnt, 1.0)
    tilty = per_block(rng, cnt, 1.0)
    rgh = per_block(rng, cnt, 0.05)
    t = tone[bid]
    d = dist + mid * 2.8 + gaussian_filter(fine, 1.2, mode="wrap") * 1.6
    s = smooth(d, sp["joint"], sp["joint"] + sp["bevel"])
    edge_band = 1.0 - smooth(d, sp["joint"], sp["joint"] + sp["bevel"] * 0.35)
    joint = 1.0 - smooth(d, sp["joint"] - 1.6, sp["joint"] + 1.6)
    chisel = fbm(n, 1.2, seed + 13, lo=60, hi=380, ax=3.0)
    surf = (0.60 * mid + 0.17 * fine + 0.05 * grain + 0.08 * chisel) * sp["relief"]
    pits = np.clip(fine - 1.9, 0, None) * 0.22
    tilt = (tiltx[bid] * (u - 0.5) + tilty[bid] * (v - 0.5)) * sp["tilt"]
    h = s ** 0.8 * 0.45 + surf * 0.18 * s + tilt * s - pits * s
    h = h * (1 - joint) + (grain * 0.01 - 0.02) * joint
    h = h - h.min()
    h /= h.max()

    base = np.array(sp["base"])
    col = base[None, None, :] * t[..., None]
    col = col * np.stack([1 + hue[bid] * 0.7, np.ones_like(t), 1 - hue[bid] * 0.9], -1)
    mott = 1.0 + 0.07 * mid + 0.08 * fine + 0.055 * grain
    mott *= 1.0 - 0.07 * np.clip(streak, 0, None)
    col = col * mott[..., None]
    col = col * (1.0 + 0.18 * edge_band * (s > 0.02))[..., None]
    jc = np.array(sp["jc"]) * (1.0 + 0.25 * fine[..., None])
    col = col * (1 - joint[..., None]) + jc * joint[..., None]
    ao = np.clip(1.0 - 3.0 * np.clip(gaussian_filter(h, 10, mode="wrap") - h, 0, None), 0.25, 1.0)
    ao *= 1.0 - 0.5 * joint
    ao *= 1.0 - 0.25 * np.clip(gaussian_filter(joint, 7, mode="wrap") * 2.2, 0, 1)
    rough = sp["rough"] + rgh[bid] + 0.07 * fine + 0.05 * grain
    rough = rough * (1 - joint) + min(0.97, sp["rough"] + 0.1) * joint + 0.05 * edge_band

    if theme == "ruins":
        # mousse : dans les joints, au pied des pierres et en plaques larges ; terre dans les joints du sol ; usure par la rugosité
        along = np.clip(gaussian_filter(joint, 12, mode="wrap") * 3.0, 0.0, 1.0)
        moss = np.clip((smooth(pool, -0.2, 1.6) * 0.8 + 0.5 * along) * smooth(broad, -0.4, 1.2), 0.0, 1.0)
        if part == "ceil":
            moss *= 0.3
        mc = np.array([0.150, 0.215, 0.085]) * (1.0 + 0.25 * fine[..., None])
        col = col * (1 - 0.55 * moss[..., None]) + mc * (0.55 * moss[..., None])
        rough = rough + 0.06 * moss
        h = h + 0.012 * moss * (1 - joint)
        if part == "floor":
            dirt = smooth(fbm(n, 1.5, seed + 15, lo=2, hi=14), 0.0, 1.4)
            dc = np.array([0.215, 0.160, 0.108]) * (1.0 + 0.2 * fine[..., None])
            col = col * (1 - 0.45 * dirt[..., None]) + dc * (0.45 * dirt[..., None])
        col = col * (1.0 - 0.10 * smooth(streak, 0.2, 2.0))[..., None]      # coulures sombres
    if theme == "dirt":
        # cailloux clairs dans la terre, racines sombres (strates étirées), poussière claire sur le dessus des blocs
        peb = smooth(fbm(n, 0.9, seed + 16, lo=40, hi=200), 1.1, 2.2)
        col = col * (1 - 0.6 * peb[..., None]) + np.array([0.46, 0.40, 0.33])[None, None, :] * (0.6 * peb[..., None]) * (0.8 + 0.4 * grain[..., None] * 0.2)
        strata = 1.0 - 0.10 * smooth(fbm(n, 1.4, seed + 17, lo=2, hi=40, ax=9.0), 0.2, 2.0)
        col = col * strata[..., None]
        h = h + 0.02 * peb
        ao *= 1.0 - 0.15 * peb
        if part == "floor":
            rough = rough - 0.08 * smooth(pool, 0.4, 1.8)         # terre tassée un peu plus lisse par endroits (passage)
    if theme == "ice":
        # fractures blanches : réseau fin dans la glace, nuages laiteux internes ; givre mat (rugosité forte) sur les arêtes et en plaques
        crack_n = fbm(n, 1.1, seed + 18, lo=10, hi=120)
        cracks = np.clip(1.0 - np.abs(crack_n) * 14.0, 0.0, 1.0) ** 3
        milk = smooth(pool, 0.1, 1.8) * 0.55 + smooth(mid, 0.4, 2.0) * 0.25
        frost = np.clip(smooth(broad, 0.0, 1.5) * 0.5 + 0.7 * edge_band * smooth(mid, -0.5, 1.0), 0.0, 1.0)
        white = np.array([0.80, 0.88, 0.95])
        col = col * (1 - 0.35 * milk[..., None]) + white[None, None, :] * (0.35 * milk[..., None])
        col = col * (1 - 0.5 * cracks[..., None]) + white[None, None, :] * (0.5 * cracks[..., None])
        col = col * (1 - 0.55 * frost[..., None]) + np.array([0.86, 0.92, 0.97])[None, None, :] * (0.55 * frost[..., None])
        rough = rough * (1 - 0.8 * frost) + 0.85 * frost * 0.8
        rough = rough - 0.10 * cracks
        h = h - 0.01 * cracks
        ao = np.clip(ao * (1.0 - 0.10 * cracks), 0.3, 1.0)
        if part == "floor":                                      # rayures de patins / passage : fines stries claires
            scr = smooth(fbm(n, 1.0, seed + 19, lo=30, hi=300, ax=14.0), 1.2, 2.6)
            col = col * (1 - 0.3 * scr[..., None]) + white[None, None, :] * (0.3 * scr[..., None])
            rough = rough + 0.25 * scr
    if theme == "lava2":
        # zones vitrifiées (obsidienne : noires, brillantes), fractures minérales claires et fines, cendre chaude et traces de chauffe au pied des joints
        glass = smooth(pool, 0.6, 1.7) * smooth(mid, -0.4, 1.0)
        crack_n = fbm(n, 1.1, seed + 18, lo=8, hi=100)
        mineral = np.clip(1.0 - np.abs(crack_n) * 16.0, 0.0, 1.0) ** 3
        along = np.clip(gaussian_filter(joint, 14, mode="wrap") * 3.0, 0.0, 1.0)
        ash = np.clip(smooth(broad, -0.1, 1.6) * (0.35 + 0.65 * smooth(pool, -0.2, 1.4)) * (0.5 + 0.5 * along), 0.0, 1.0)
        if part == "floor":
            ash = np.clip(ash * 1.2, 0.0, 1.0)
        heat = np.array([0.330, 0.215, 0.165])
        col = col * (1 - 0.26 * ash[..., None]) + heat[None, None, :] * (0.26 * ash[..., None])
        col = col * (1 - 0.30 * glass[..., None])
        col = col * (1 - 0.30 * mineral[..., None]) + np.array([0.40, 0.36, 0.33])[None, None, :] * (0.30 * mineral[..., None])
        rough = rough * (1 - 0.75 * glass) + 0.22 * 0.75 * glass + 0.12 * ash
        if part == "floor":                         # dalles polies par le passage : lisses au centre des dalles, rudes aux bords
            worn = smooth(pool, 0.2, 1.6) * (1 - edge_band)
            rough = rough - 0.30 * worn
        rough = rough - 0.08 * mineral
        h = h - 0.012 * mineral
        ao = np.clip(ao * (1.0 - 0.10 * mineral), 0.3, 1.0)
    rough = np.clip(rough, 0.12, 1.0)
    return col.clip(0, 1).astype(np.float32), h.astype(np.float32), ao.astype(np.float32), rough.astype(np.float32), sp["strength"]


def save(out_dir, theme, part, res, k, data):
    col, h, ao, rough, strength = data
    n = N // k
    albedo = down(col, k)
    hh = down(h, k)
    orm = np.stack([down(ao, k), down(rough, k), np.zeros((n, n), np.float32)], -1)
    d = f"{out_dir}/{theme}_{res}"
    os.makedirs(d, exist_ok=True)
    Image.fromarray(to_u8(albedo)).save(f"{d}/{part}_albedo.jpg", quality=90, subsampling=0)
    Image.fromarray(normal_map(hh, strength, n)).save(f"{d}/{part}_normal.png", optimize=True)
    Image.fromarray(to_u8(orm)).save(f"{d}/{part}_orm.jpg", quality=92, subsampling=0)


def main():
    args = sys.argv[1:]
    out = "assets/themes"
    if args and os.path.isdir(args[0]):
        out = args.pop(0)
    themes = args or list(SPECS)
    for ti, theme in enumerate(["ruins", "dirt", "ice", "lava2"]):
        if theme not in themes:
            continue
        for i, part in enumerate(["wall", "floor", "ceil"]):
            data = build(theme, part, 3000 + 400 * ti + 97 * i)
            save(out, theme, part, "hd", 1, data)
            save(out, theme, part, "lite", 2, data)
            print(theme, part, "ok", flush=True)


if __name__ == "__main__":
    main()
