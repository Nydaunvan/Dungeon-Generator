#!/usr/bin/env python3
"""Génère la pierre de la fontaine : calcaire sculpté, sans couture, en deux résolutions.
  assets/themes/fountain_hd/    2048x2048  -> exécutable Windows
  assets/themes/fountain_lite/  1024x1024  -> Web et mobile
Fichiers : albedo.jpg (couleur), normal.png (normales OpenGL), orm.jpg (R = occlusion, G = rugosité, B = 0).
Tout vient de bruits spectraux périodiques (donc sans couture) : grain fin, pores, hairlines fissurées,
veines de calcite, lits sédimentaires et taches d'oxyde. Usage : python3 tools/gen_fountain_stone.py
"""
import os
import numpy as np
from PIL import Image

N = 2048
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "themes")

def field(beta, seed, n=N):
    """Bruit périodique de spectre 1/f^beta, normalisé (moyenne 0, écart-type 1)."""
    rng = np.random.default_rng(seed)
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / f ** (beta / 2.0)
    amp[0, 0] = 0.0
    a = np.fft.ifft2(np.fft.fft2(rng.standard_normal((n, n))) * amp).real
    return (a - a.mean()) / a.std()

def blur(a, sigma):
    n = a.shape[0]
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    g = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.fft.ifft2(np.fft.fft2(a) * g).real

def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def lines(fld, width):
    """Fines lignes sinueuses : passages par zéro d'un bruit lisse."""
    return np.exp(-(fld / width) ** 2)

def build():
    low = field(3.2, 1)
    mid = field(2.3, 2)
    grain = field(0.9, 3)
    fine = field(0.5, 4)
    # pores : creux épars de petite taille
    p = field(1.1, 5)
    pores = smooth(p, 1.9, 2.6)
    # fissures et veines de calcite, présentes par zones seulement
    zone = smooth(field(3.0, 6), -1.0, 0.3)
    cracks = lines(field(2.4, 7), 0.075) * zone
    zone2 = smooth(field(3.0, 8), -1.0, 0.2)
    veins = lines(field(2.6, 9), 0.085) * zone2
    # lits sédimentaires : bandes horizontales ondulées (entiers pour rester périodique)
    yy = np.arange(N)[:, None] / N
    warp = field(3.4, 10)
    band = np.sin(2 * np.pi * (11 * yy + 0.09 * warp)) * 0.6 + np.sin(2 * np.pi * (29 * yy + 0.05 * warp + 0.3)) * 0.4
    # taches d'oxyde
    stain = smooth(field(3.6, 11), 0.5, 1.6)

    # --- relief
    h = 0.50 * low + 0.65 * mid + 0.09 * grain + 0.03 * fine - 1.0 * pores - 0.9 * cracks
    # --- couleur (sRGB)
    base = np.array([0.80, 0.765, 0.69])
    c = np.empty((N, N, 3))
    var = 1.0 + 0.11 * low + 0.06 * mid + 0.045 * grain + 0.015 * fine + 0.04 * band
    for i in range(3):
        c[..., i] = base[i] * var
    ochre = np.array([0.64, 0.51, 0.36])
    c = c * (1 - 0.5 * stain[..., None]) + ochre * (0.5 * stain[..., None]) * var[..., None]
    calc = np.array([0.93, 0.91, 0.86])
    c = c * (1 - 0.7 * veins[..., None]) + calc * 0.7 * veins[..., None]
    c *= (1 - 0.5 * pores[..., None])
    c *= (1 - 0.75 * cracks[..., None])
    albedo = (np.clip(c, 0, 1) * 255 + 0.5).astype(np.uint8)

    # --- normales (OpenGL : Y vers le haut de l'image)
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    gs = np.sqrt(dx.std() ** 2 + dy.std() ** 2)
    strength = 0.5 / gs          # pente moyenne visée, quelle que soit la composition du relief
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / ln, ny / ln, nz / ln], axis=-1)
    normal_img = ((normal * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)

    # --- occlusion (creux) et rugosité
    cavity = np.clip((blur(h, 5.0) - h) * 1.3, 0, 1)
    ao = 1.0 - np.clip(0.55 * cavity + 0.45 * pores + 0.5 * cracks, 0, 0.8)
    rough = np.clip(0.80 + 0.03 * grain + 0.04 * mid + 0.10 * pores + 0.06 * cracks - 0.05 * veins, 0.55, 0.98)
    orm = np.stack([ao, rough, np.zeros_like(ao)], axis=-1)
    orm_img = (np.clip(orm, 0, 1) * 255 + 0.5).astype(np.uint8)
    return albedo, normal_img, orm_img

def save(albedo, normal, orm, size, folder):
    d = os.path.join(OUT, folder)
    os.makedirs(d, exist_ok=True)
    a, n, o = Image.fromarray(albedo), Image.fromarray(normal), Image.fromarray(orm)
    if size != N:
        a = a.resize((size, size), Image.LANCZOS)
        o = o.resize((size, size), Image.LANCZOS)
        nn = np.asarray(n.resize((size, size), Image.LANCZOS), dtype=np.float32) / 255.0 * 2 - 1
        nn /= np.maximum(np.linalg.norm(nn, axis=2, keepdims=True), 1e-6)
        n = Image.fromarray(((nn * 0.5 + 0.5) * 255 + 0.5).clip(0, 255).astype(np.uint8))
    a.save(os.path.join(d, "albedo.jpg"), quality=93, subsampling=0, optimize=True)
    n.save(os.path.join(d, "normal.png"), optimize=True)
    o.save(os.path.join(d, "orm.jpg"), quality=95, subsampling=0, optimize=True)
    print(folder, size, "ok")

if __name__ == "__main__":
    al, no, orm = build()
    save(al, no, orm, 2048, "fountain_hd")
    save(al, no, orm, 1024, "fountain_lite")
