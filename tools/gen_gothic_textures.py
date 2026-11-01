#!/usr/bin/env python3
"""Génère les textures PBR du thème gothic (V3) : wall / floor / ceil, en gothic_hd (2048) et gothic_lite (1024).

Chaque tuile couvre exactement 4 × 4 unités (une case) et se raccorde à elle-même dans les deux sens : tout le bruit est périodique
(spectre de Fourier) et la maçonnerie est calculée modulo la taille de la tuile.
Albédo JPG (sRGB), normale PNG (OpenGL, Y+), ORM JPG (R = occlusion, G = rugosité, B = métal).

Ce sont des textures PROCÉDURALES : elles remplacent les anciennes (grille de briques régulière, joints épais, raccord visible),
mais elles ne remplacent pas un vrai travail de texturage manuel. Voir assets/themes/gothic_LISEZMOI.md.
Usage : python3 tools/gen_gothic_textures.py [dossier_assets_themes]
"""
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

N = 2048
PPU = N / 4.0          # pixels par unité de jeu (une tuile = 4 u)


def fbm(n, beta, seed, lo=1.0, hi=None, ax=1.0):
    """Bruit périodique de spectre 1/f^beta, moyenne 0, écart-type 1. ax > 1 : structures étirées verticalement."""
    rng = np.random.default_rng(seed)
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.rfftfreq(n)[None, :] * n * ax
    f = np.sqrt(fx * fx + fy * fy)
    amp = np.zeros_like(f)
    ok = f >= lo
    if hi is not None:
        ok &= f <= hi
    amp[ok] = f[ok] ** (-beta)
    ph = rng.uniform(0, 2 * np.pi, f.shape)
    out = np.fft.irfft2(amp * np.exp(1j * ph), s=(n, n))
    out -= out.mean()
    return (out / out.std()).astype(np.float32)


def smooth(x, a=0.0, b=1.0):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def course_edges(rng, total, lo, hi, mix=None):
    """Bords irréguliers sur un cercle de longueur total (somme exacte). mix = [(probabilité, mini, maxi), …] : tailles tirées dans plusieurs plages
    (quelques blocs courts, quelques longs) au lieu d'une seule ; sinon uniforme entre lo et hi."""
    sizes = []
    t = 0.0
    while t < total:
        if mix:
            r = rng.uniform()
            acc = 0.0
            a, b = mix[-1][1], mix[-1][2]
            for pr, mn, mx in mix:
                acc += pr
                if r < acc:
                    a, b = mn, mx
                    break
            s = rng.uniform(a, b)
        else:
            s = rng.uniform(lo, hi)
        sizes.append(s)
        t += s
    sizes = np.array(sizes) * total / sum(sizes)
    return np.concatenate([[0.0], np.cumsum(sizes)[:-1]]), sizes


def masonry(n, rng, wx, wy):
    """Appareil de grosses pierres irrégulières. Renvoie (distance au bord, id de bloc, u, v dans le bloc)."""
    ppu = n / 4.0
    yy = (np.arange(n)[:, None] + wy) % n
    xx = (np.arange(n)[None, :] + wx) % n
    yy = np.broadcast_to(yy, (n, n)).astype(np.float32)
    xx = np.broadcast_to(xx, (n, n)).astype(np.float32)
    cedges, csizes = course_edges(rng, n, 0.40 * ppu, 0.66 * ppu, [(0.18, 0.30 * ppu, 0.40 * ppu), (0.62, 0.42 * ppu, 0.62 * ppu), (0.20, 0.66 * ppu, 0.92 * ppu)])
    dist = np.zeros((n, n), np.float32)
    bid = np.zeros((n, n), np.int32)
    bu = np.zeros((n, n), np.float32)
    bv = np.zeros((n, n), np.float32)
    ci = np.searchsorted(cedges, yy, side="right") - 1
    counter = 0
    for c in range(len(cedges)):
        y0, y1 = cedges[c], cedges[c] + csizes[c]
        be, _ = course_edges(rng, n, 0.80 * ppu, 1.70 * ppu, [(0.22, 0.55 * ppu, 0.85 * ppu), (0.56, 0.90 * ppu, 1.50 * ppu), (0.22, 1.55 * ppu, 2.15 * ppu)])
        be = np.sort((be + rng.uniform(0, n)) % n)
        m = ci == c
        x = xx[m]
        y = yy[m]
        bi = np.searchsorted(be, x, side="right") - 1
        left = np.where(bi >= 0, be[np.clip(bi, 0, None)], be[-1] - n)
        nxt = np.where(bi + 1 < len(be), be[np.clip(bi + 1, None, len(be) - 1)], be[0] + n)
        d = np.minimum.reduce([x - left, nxt - x, y - y0, y1 - y])
        dist[m] = d
        bid[m] = counter + np.where(bi >= 0, bi, len(be) - 1)
        bu[m] = (x - left) / np.maximum(nxt - left, 1)
        bv[m] = (y - y0) / (y1 - y0)
        counter += len(be)
    return dist, bid, bu, bv, counter


def voronoi(n, rng, g, wx, wy, jitter=0.38):
    """Dalles irrégulières (cellules de Voronoï périodiques, g × g). Renvoie (distance au joint, id, u, v)."""
    cs = n / g
    pts = np.zeros((g, g, 2), np.float32)
    for i in range(g):
        for j in range(g):
            pts[i, j] = ((j + 0.5 + rng.uniform(-jitter, jitter)) * cs, (i + 0.5 + rng.uniform(-jitter, jitter)) * cs)
    yy = ((np.arange(n)[:, None] + wy) % n).astype(np.float32)
    xx = ((np.arange(n)[None, :] + wx) % n).astype(np.float32)
    yy = np.broadcast_to(yy, (n, n))
    xx = np.broadcast_to(xx, (n, n))
    ci = np.floor(yy / cs).astype(np.int32)
    cj = np.floor(xx / cs).astype(np.int32)
    f1 = np.full((n, n), 1e9, np.float32)
    f2 = np.full((n, n), 1e9, np.float32)
    idm = np.zeros((n, n), np.int32)
    px = np.zeros((n, n), np.float32)
    py = np.zeros((n, n), np.float32)
    for di in (-2, -1, 0, 1, 2):
        for dj in (-2, -1, 0, 1, 2):
            ii = ci + di
            jj = cj + dj
            wxo = np.where(jj < 0, -n, np.where(jj >= g, n, 0)).astype(np.float32)
            wyo = np.where(ii < 0, -n, np.where(ii >= g, n, 0)).astype(np.float32)
            p = pts[ii % g, jj % g]
            qx = p[..., 0] + wxo
            qy = p[..., 1] + wyo
            d = np.hypot(xx - qx, yy - qy)
            better = d < f1
            second = (~better) & (d < f2)
            f2 = np.where(better, f1, np.where(second, d, f2))
            idm = np.where(better, (ii % g) * g + (jj % g), idm)
            px = np.where(better, qx, px)
            py = np.where(better, qy, py)
            f1 = np.where(better, d, f1)
    dist = (f2 - f1) * 0.5
    u = np.clip((xx - px) / cs * 0.5 + 0.5, 0, 1)
    v = np.clip((yy - py) / cs * 0.5 + 0.5, 0, 1)
    return dist.astype(np.float32), idm, u.astype(np.float32), v.astype(np.float32), g * g


def per_block(rng, count, sd):
    return rng.normal(0.0, sd, count).astype(np.float32)


def down(a, k):
    if k == 1:
        return a
    n = a.shape[0] // k
    return a.reshape(n, k, n, k, *a.shape[2:]).mean(axis=(1, 3))


def normal_map(h, strength, n):
    hs = gaussian_filter(h, 0.7 * n / N, mode="wrap")
    gx = (np.roll(hs, -1, 1) - np.roll(hs, 1, 1)) * 0.5
    gr = (np.roll(hs, -1, 0) - np.roll(hs, 1, 0)) * 0.5
    s = strength * n / N * (N / 2048.0)
    nx = -gx * s
    ny = gr * s       # OpenGL (Y+) : v vers le haut = lignes vers le haut de l'image
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    out = np.stack([nx / ln, ny / ln, nz / ln], -1)
    return ((out * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)


def to_u8(a):
    return (a.clip(0, 1) * 255 + 0.5).astype(np.uint8)


def build(part, seed):
    rng = np.random.default_rng(seed)
    n = N
    wlo = fbm(n, 1.6, seed + 1, lo=2, hi=40)
    wx = wlo * 10.0 + fbm(n, 1.0, seed + 2, lo=20, hi=300) * 2.5
    wy = fbm(n, 1.6, seed + 3, lo=2, hi=40) * 10.0 + fbm(n, 1.0, seed + 4, lo=20, hi=300) * 2.5
    mid = fbm(n, 1.5, seed + 5, lo=3, hi=60)
    fine = fbm(n, 1.0, seed + 6, lo=30, hi=260)
    grain = fbm(n, 0.4, seed + 7, lo=100, hi=420)
    streak = fbm(n, 1.6, seed + 8, lo=2, hi=60, ax=7.0)
    crackn = fbm(n, 1.8, seed + 9, lo=2, hi=24)
    crackm = fbm(n, 1.5, seed + 10, lo=2, hi=12)
    speck = fbm(n, 0.2, seed + 12, lo=150, hi=500)
    if part == "wall":
        dist, bid, u, v, cnt = masonry(n, rng, wx, wy)
        joint_half, bevel, relief, tilt_k = 5.2, 40.0, 0.62, 0.11
        base, tone_sd, strength = np.array([0.238, 0.252, 0.272]), 0.16, 14.0
    elif part == "floor":
        dist, bid, u, v, cnt = voronoi(n, rng, 6, wx, wy)
        joint_half, bevel, relief, tilt_k = 4.2, 26.0, 0.50, 0.08
        base, tone_sd, strength = np.array([0.215, 0.228, 0.245]), 0.13, 11.0
    else:
        dist, bid, u, v, cnt = voronoi(n, rng, 4, wx, wy, jitter=0.42)
        joint_half, bevel, relief, tilt_k = 7.0, 46.0, 0.95, 0.18
        base, tone_sd, strength = np.array([0.165, 0.180, 0.205]), 0.15, 24.0
    tone = np.clip(np.exp(per_block(rng, cnt, tone_sd)), 0.74, 1.12)
    hue = per_block(rng, cnt, 0.035)
    tiltx = per_block(rng, cnt, 1.0)
    tilty = per_block(rng, cnt, 1.0)
    dome = np.abs(per_block(rng, cnt, 0.5)) + 0.15
    rgh = per_block(rng, cnt, 0.05)
    t = tone[bid]
    d = dist + mid * 2.8 + gaussian_filter(fine, 1.2, mode="wrap") * 1.6          # bords ébréchés, non rectilignes (sans escalier de pixels)
    s = smooth(d, joint_half, joint_half + bevel)
    edge_band = 1.0 - smooth(d, joint_half, joint_half + bevel * 0.35)
    joint = 1.0 - smooth(d, joint_half - 1.6, joint_half + 1.6)
    chisel = fbm(n, 1.2, seed + 13, lo=60, hi=380, ax=3.0)      # coups de ciseau : micro-relief un peu étiré
    surf = (0.60 * mid + 0.17 * fine + 0.05 * grain + 0.08 * chisel) * relief
    pits = np.clip(fine - 1.9, 0, None) * 0.22
    tilt = (tiltx[bid] * (u - 0.5) + tilty[bid] * (v - 0.5)) * tilt_k
    cracks = np.zeros_like(crackn)      # pas de fissures filiformes : elles se répètent en boucles peu crédibles
    h = s ** 0.8 * 0.45 + surf * 0.18 * s + tilt * s - pits * s - cracks * 0.35
    h = h * (1 - joint) + (grain * 0.01 - 0.02) * joint
    h = h - h.min()
    h /= h.max()
    # albédo
    col = base[None, None, :] * t[..., None]
    col = col * np.stack([1 + hue[bid] * 0.7, np.ones_like(t), 1 - hue[bid] * 0.9], -1)
    mott = 1.0 + 0.06 * mid + 0.075 * fine + 0.055 * grain + 0.05 * speck
    mott *= 1.0 - 0.07 * np.clip(streak, 0, None)
    col = col * mott[..., None]
    col = col * (1.0 + 0.20 * edge_band * (s > 0.02))[..., None]
    col = col * (1.0 - 0.55 * cracks)[..., None]
    jc = np.array([0.118, 0.128, 0.146]) * (1.0 + 0.30 * fine[..., None])      # fond de joint : gris-bleu sombre, jamais noir
    col = col * (1 - joint[..., None]) + jc * joint[..., None]
    ao = np.clip(1.0 - 3.0 * np.clip(gaussian_filter(h, 10, mode="wrap") - h, 0, None), 0.25, 1.0)
    ao *= 1.0 - 0.55 * joint
    ao *= 1.0 - 0.28 * np.clip(gaussian_filter(joint, 7, mode="wrap") * 2.2, 0, 1)      # ombre douce au pied du joint : de la profondeur sans trait noir
    rough = 0.80 + rgh[bid] + 0.07 * fine + 0.05 * grain
    rough = rough * (1 - joint) + 0.97 * joint + 0.06 * edge_band
    if part == "floor":
        # humidité : surtout dans la rugosité et la réflexion, très peu dans la couleur. Large (la tuile couvre une case : pas de petites taches
        # qui se répéteraient), plus marquée au creux des joints et variable d'une dalle à l'autre.
        broad = smooth(fbm(n, 1.9, seed + 11, lo=1, hi=5), -0.3, 1.5)
        pool = smooth(fbm(n, 1.4, seed + 14, lo=3, hi=22), -0.2, 1.4)
        slab = np.clip(per_block(rng, cnt, 0.45) + 0.45, 0.0, 1.0)[bid]
        along = np.clip(gaussian_filter(joint, 14, mode="wrap") * 3.0, 0.0, 1.0)
        wet = np.clip((0.15 + 0.85 * broad) * (0.35 + 0.65 * pool) * (0.4 + 0.6 * slab) + 0.35 * along * broad, 0.0, 1.0)
        col = col * (1 - 0.07 * wet)[..., None]
        rough = rough - 0.30 * wet + 0.05 * fine * wet
        h = h - 0.008 * wet
    if part == "ceil":
        col = col * (1.0 - 0.18 * np.clip(streak, 0, None))[..., None]
    rough = np.clip(rough, 0.35, 1.0)
    return col.clip(0, 1).astype(np.float32), h.astype(np.float32), ao.astype(np.float32), rough.astype(np.float32), strength


def save(out_dir, part, res, k, data):
    col, h, ao, rough, strength = data
    n = N // k
    albedo = down(col, k)
    hh = down(h, k)
    orm = np.stack([down(ao, k), down(rough, k), np.zeros((n, n), np.float32)], -1)
    Image.fromarray(to_u8(albedo)).save(f"{out_dir}/gothic_{res}/{part}_albedo.jpg", quality=93, subsampling=0)
    Image.fromarray(normal_map(hh, strength, n)).save(f"{out_dir}/gothic_{res}/{part}_normal.png", optimize=True)
    Image.fromarray(to_u8(orm)).save(f"{out_dir}/gothic_{res}/{part}_orm.jpg", quality=95, subsampling=0)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/themes"
    for i, part in enumerate(["wall", "floor", "ceil"]):
        data = build(part, 1000 + 97 * i)
        save(out, part, "hd", 1, data)
        save(out, part, "lite", 2, data)
        print(part, "ok")


if __name__ == "__main__":
    main()
