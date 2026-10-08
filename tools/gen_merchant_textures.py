#!/usr/bin/env python3
"""Textures procédurales de l'étal du marchand en 3D (tissus rouge et beige, bois, jute, emblème de fiole dorée).
python3 tools/gen_merchant_textures.py   ->   assets/misc/merchant3d/*.webp"""
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "misc", "merchant3d")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def fbm(h, w, octaves=6, base=4, persistence=0.55, stretch=(1.0, 1.0), seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        sy = max(2, int(base * (2 ** o) * stretch[0]))
        sx = max(2, int(base * (2 ** o) * stretch[1]))
        n = r.random((sy, sx))
        n = np.tile(n, (2, 2))
        up = ndi.zoom(n, (h * 2 / n.shape[0], w * 2 / n.shape[1]), order=3, mode="wrap")
        out += amp * up[:h, :w]
        tot += amp
        amp *= persistence
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-9)


def normal_from_height(hmap, strength=3.0):
    gy, gx = np.gradient(hmap)
    nx, ny, nz = -gx * strength * 40, -gy * strength * 40, np.ones_like(hmap)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.dstack([nx / l, ny / l, nz / l]) * 0.5 + 0.5
    return Image.fromarray((n * 255).astype(np.uint8))


def save(img, name, lossless=False):
    img.save(os.path.join(OUT, name), "WEBP", quality=92, method=6, lossless=lossless)


def cloth(name, base, dark, light, size=1024, seed=1, fold_scale=1.0):
    # plis : bruit étiré + déformation, taches
    f1 = fbm(size, size, 6, 3, 0.6, (1.6, 0.8), seed)
    f2 = fbm(size, size, 5, 10, 0.5, (1.0, 1.0), seed + 11)
    folds = np.abs(np.sin((f1 * 9.0 * fold_scale + f2 * 1.5) * np.pi))
    folds = ndi.gaussian_filter(folds, 1.2)
    height = 0.55 * f1 + 0.25 * folds + 0.2 * f2
    stain = fbm(size, size, 5, 5, 0.65, (1, 1), seed + 31)
    weave = (np.sin(np.arange(size) * 1.9)[None, :] * np.sin(np.arange(size) * 1.9)[:, None]) * 0.5 + 0.5
    t = np.clip(0.5 + (height - 0.5) * 1.6, 0, 1)
    col = np.array(dark)[None, None, :] * (1 - t[..., None]) + np.array(light)[None, None, :] * t[..., None]
    col = col * (0.82 + 0.18 * stain[..., None]) * (0.95 + 0.05 * weave[..., None])
    wear = np.clip((stain - 0.62) * 3, 0, 1)[..., None]
    col = col * (1 - 0.25 * wear) + np.array(base)[None, None, :] * 0.25 * wear
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    save(img, name + ".webp")
    save(normal_from_height(height + 0.15 * weave, 2.2), name + "_n.webp")


def wood(name, base, size=1024, seed=5, planks=4):
    f = fbm(size, size, 6, 3, 0.6, (0.12, 3.0), seed)        # fibres le long de y
    knots = fbm(size, size, 4, 6, 0.7, (1, 1), seed + 3)
    h = size // planks
    col = np.zeros((size, size, 3))
    height = np.zeros((size, size))
    for p in range(planks):
        sh = rng.random() * 0.25 - 0.12
        sl = slice(p * h, (p + 1) * h)
        g = fbm(h, size, 6, 3, 0.62, (0.5, 0.06), seed + p * 17)   # fibres le long de x
        tone = np.clip(g * 1.25 + sh, 0, 1)
        c = np.array(base)[None, None, :] * (0.55 + 0.75 * tone[..., None])
        col[sl] = c
        height[sl] = g
        col[sl.start:sl.start + 3] *= 0.35            # joint entre planches
        col[sl.stop - 3:sl.stop] *= 0.35
    col *= (0.88 + 0.12 * knots[..., None])
    save(Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)), name + ".webp")
    save(normal_from_height(height, 2.0), name + "_n.webp")


def burlap(name, base, size=512, seed=9):
    y, x = np.mgrid[0:size, 0:size]
    weave = (np.sin(x * 0.9) * np.sin(y * 0.9)) * 0.5 + 0.5
    n = fbm(size, size, 5, 6, 0.6, (1, 1), seed)
    t = 0.55 + 0.45 * n
    col = np.array(base)[None, None, :] * (t[..., None]) * (0.78 + 0.22 * weave[..., None])
    save(Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)), name + ".webp")
    save(normal_from_height(weave * 0.6 + n * 0.4, 3.0), name + "_n.webp")


def metal(name, size=512, seed=12):
    n = fbm(size, size, 6, 5, 0.6, (1, 1), seed)
    col = np.dstack([n * 120 + 50, n * 118 + 52, n * 125 + 56])
    save(Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)), name + ".webp")
    save(normal_from_height(n, 1.6), name + "_n.webp")


GOLD = (236, 170, 78)
GOLD_D = (190, 118, 42)


def emblem(banner=False):
    S = 4
    W, H = (1280, 768) if not banner else (512, 1024)
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def poly(pts, fill=None, outline=None, width=0):
        pts = [(x * S, y * S) for x, y in pts]
        if fill:
            d.polygon(pts, fill=fill)
        if outline:
            d.line(pts + [pts[0]], fill=outline, width=width * S, joint="curve")

    def diamond(cx, cy, rx, ry, fill=None, outline=None, width=0):
        poly([(cx, cy - ry), (cx + rx, cy), (cx, cy + ry), (cx - rx, cy)], fill, outline, width)

    def flask(cx, cy, k=1.0):
        r = 105 * k
        bulb_c = (cx, cy + 55 * k)
        # corps : ballon + col
        d.ellipse([(bulb_c[0] - r) * S, (bulb_c[1] - r) * S, (bulb_c[0] + r) * S, (bulb_c[1] + r) * S], outline=GOLD_D + (255,), width=int(20 * k * S))
        d.polygon([((cx - 30 * k) * S, (cy - 95 * k) * S), ((cx + 30 * k) * S, (cy - 95 * k) * S),
                   ((cx + 52 * k) * S, (cy - 5 * k) * S), ((cx - 52 * k) * S, (cy - 5 * k) * S)], fill=None)
        d.line([((cx - 30 * k) * S, (cy - 95 * k) * S), ((cx - 52 * k) * S, (cy - 5 * k) * S)], fill=GOLD_D + (255,), width=int(18 * k * S))
        d.line([((cx + 30 * k) * S, (cy - 95 * k) * S), ((cx + 52 * k) * S, (cy - 5 * k) * S)], fill=GOLD_D + (255,), width=int(18 * k * S))
        # liquide (moitié basse du ballon)
        liq = Image.new("L", img.size, 0)
        ld = ImageDraw.Draw(liq)
        ld.ellipse([(bulb_c[0] - r + 12 * k) * S, (bulb_c[1] - r + 12 * k) * S, (bulb_c[0] + r - 12 * k) * S, (bulb_c[1] + r - 12 * k) * S], fill=255)
        ld.rectangle([0, 0, img.size[0], (bulb_c[1] - 12 * k) * S], fill=0)
        img.paste(Image.new("RGBA", img.size, GOLD + (255,)), (0, 0), liq)
        # goulot, lèvre, bouchon
        d.rectangle([(cx - 44 * k) * S, (cy - 125 * k) * S, (cx + 44 * k) * S, (cy - 95 * k) * S], fill=GOLD_D + (255,))
        d.rectangle([(cx - 30 * k) * S, (cy - 165 * k) * S, (cx + 30 * k) * S, (cy - 125 * k) * S], fill=GOLD + (255,))
        d.rectangle([(cx - 30 * k) * S, (cy - 165 * k) * S, (cx + 30 * k) * S, (cy - 125 * k) * S], outline=GOLD_D + (255,), width=int(8 * k * S))

    if not banner:
        cx, cy = 640, 384
        diamond(cx, cy, 340, 340, outline=GOLD + (255,), width=26)
        diamond(cx, cy, 300, 300, outline=GOLD_D + (255,), width=8)
        diamond(70, cy, 52, 88, fill=GOLD + (255,))
        diamond(1210, cy, 52, 88, fill=GOLD + (255,))
        flask(cx, cy, 1.05)
    else:
        cx = 256
        d.arc([cx * S - 190 * S, 20 * S, cx * S + 190 * S, 380 * S], 200, 340, fill=GOLD + (255,), width=int(22 * S))
        diamond(cx, 250, 36, 62, fill=GOLD + (255,))
        flask(cx, 560, 1.15)
        diamond(cx, 880, 36, 62, fill=GOLD + (255,))
    return img.resize((W, H), Image.LANCZOS)


def tear_alpha(w, h, top_flat=True, depth=0.25, teeth=9, seed=3, bottom_only=True):
    """Masque d'un tissu dont le bord bas est déchiqueté en dents irrégulières."""
    r = np.random.default_rng(seed)
    a = np.ones((h, w), np.uint8) * 255
    xs = np.linspace(0, 1, teeth + 1)
    xs[1:-1] += (r.random(teeth - 1) - 0.5) * 0.4 / teeth
    for i in range(teeth):
        x0, x1 = xs[i], xs[i + 1]
        tip = depth * (0.35 + 0.65 * r.random())
        xm = x0 + (x1 - x0) * (0.3 + 0.4 * r.random())
        for px in range(int(x0 * w), int(x1 * w)):
            u = px / w
            t = (u - x0) / (xm - x0) if u < xm else 1 - (u - xm) / (x1 - xm)
            cut = int(h * (1 - tip * np.clip(t, 0, 1)))
            a[cut:, px] = 0
    return a


def torn_cloth(name, base_tex, w=1024, h=640, depth=0.28, teeth=9, seed=3, emb=None):
    base = Image.open(os.path.join(OUT, base_tex)).convert("RGB").resize((w, h), Image.LANCZOS)
    rgba = base.convert("RGBA")
    if emb is not None:
        e = emb.copy()
        s = w * 0.66 / e.width
        e = e.resize((int(e.width * s), int(e.height * s)), Image.LANCZOS)
        rgba.alpha_composite(e, ((w - e.width) // 2, int(h * 0.06)))
    a = tear_alpha(w, h, depth=depth, teeth=teeth, seed=seed)
    # bord abîmé : liseré plus sombre
    edge = ndi.binary_dilation(a == 0, iterations=3) & (a > 0)
    arr = np.array(rgba)
    arr[edge, :3] = (arr[edge, :3] * 0.55).astype(np.uint8)
    arr[..., 3] = a
    save(Image.fromarray(arr), name + ".webp", lossless=False)


if __name__ == "__main__":
    cloth("cloth_red", (150, 42, 28), (96, 22, 16), (176, 62, 42), seed=1)
    cloth("cloth_tan", (190, 150, 100), (140, 104, 66), (214, 178, 124), seed=2, fold_scale=0.7)
    wood("wood", (118, 76, 40), planks=4, seed=5)
    wood("wood_dark", (62, 40, 24), planks=6, seed=8)
    burlap("burlap", (150, 112, 70))
    metal("metal")
    em = emblem(False)
    save(em, "emblem.webp", lossless=True)
    emb = emblem(True)
    save(emb, "emblem_banner.webp", lossless=True)
    torn_cloth("front_cloth", "cloth_red.webp", 1024, 640, depth=0.30, teeth=11, seed=4, emb=em)
    torn_cloth("banner_cloth", "cloth_red.webp", 512, 1024, depth=0.16, teeth=8, seed=6, emb=None)
    torn_cloth("canopy_red", "cloth_red.webp", 1024, 512, depth=0.42, teeth=6, seed=21)
    torn_cloth("canopy_tan", "cloth_tan.webp", 1024, 512, depth=0.42, teeth=7, seed=22)
    # bannière : l'emblème est posé en décalque dans l'image finale
    b = Image.open(os.path.join(OUT, "banner_cloth.webp")).convert("RGBA")
    e2 = emb.resize((int(512 * 0.78), int(1024 * 0.78 * 0.9)), Image.LANCZOS)
    b.alpha_composite(e2, ((512 - e2.width) // 2, 10))
    save(b, "banner_cloth.webp")
    print("ok", sorted(os.listdir(OUT)))
