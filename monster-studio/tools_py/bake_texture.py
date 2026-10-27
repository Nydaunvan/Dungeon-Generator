#!/usr/bin/env python
"""Cuisson de texture pour Monster Studio.

Entrée  : le maillage de TripoSR (couleurs par sommet) + l'image 2D détourée d'origine (cut.png, RGBA).
Sortie  : un .glb orienté (façade +Z, haut +Y), allégé, déplié (UV) et portant UNE texture 2K/4K :
  - face avant : le dessin d'origine plaqué tel quel (précision de l'image source, agrandie proprement) ;
  - reste (côtés, dos) : couleurs de TripoSR recalées sur celles du dessin, plus le grain fin du dessin ;
  - joints : bords prolongés pour éviter les coutures.

Dépendances : numpy, scipy, Pillow (déjà là avec TripoSR) ; trimesh (lecture du .glb) et xatlas (dépliage) viennent avec
TripoSR ; fast-simplification (allègement) est installé à la volée au besoin.
Usage : python bake_texture.py --mesh mesh.glb --cut cut.png --out model.glb [--size 2048] [--faces 30000]
"""
import argparse
import itertools
import json
import math
import struct
import subprocess
import sys
import io

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi


def log(*a):
    print("BAKE:", *a, flush=True)


# --------------------------------------------------------------------------------------------- rasterisation

def rasterize(tri_xy, w, h, tri_z=None):
    """Remplit une grille w×h. tri_xy : (F,3,2) en pixels (x droite, y bas).
    Renvoie (identifiant de triangle ou -1, barycentriques (h,w,3), profondeur ou None).
    Avec tri_z (F,3) : tampon de profondeur, le plus grand z gagne."""
    f_count = tri_xy.shape[0]
    fid = np.full((h, w), -1, np.int32)
    bary = np.zeros((h, w, 3), np.float32)
    zb = np.full((h, w), -np.inf, np.float32) if tri_z is not None else None
    for f in range(f_count):
        p = tri_xy[f]
        x0 = max(int(math.floor(p[:, 0].min() - 0.5)), 0)
        x1 = min(int(math.ceil(p[:, 0].max() - 0.5)), w - 1)
        y0 = max(int(math.floor(p[:, 1].min() - 0.5)), 0)
        y1 = min(int(math.ceil(p[:, 1].max() - 0.5)), h - 1)
        if x1 < x0 or y1 < y0:
            continue
        den = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(den) < 1e-12:
            continue
        xs = np.arange(x0, x1 + 1, dtype=np.float32) + 0.5
        ys = np.arange(y0, y1 + 1, dtype=np.float32) + 0.5
        gx, gy = np.meshgrid(xs, ys)
        l0 = ((p[1, 1] - p[2, 1]) * (gx - p[2, 0]) + (p[2, 0] - p[1, 0]) * (gy - p[2, 1])) / den
        l1 = ((p[2, 1] - p[0, 1]) * (gx - p[2, 0]) + (p[0, 0] - p[2, 0]) * (gy - p[2, 1])) / den
        l2 = 1.0 - l0 - l1
        eps = -1e-4
        inside = (l0 >= eps) & (l1 >= eps) & (l2 >= eps)
        if not inside.any():
            continue
        if tri_z is not None:
            z = l0 * tri_z[f, 0] + l1 * tri_z[f, 1] + l2 * tri_z[f, 2]
            cur = zb[y0:y1 + 1, x0:x1 + 1]
            inside &= z > cur
            if not inside.any():
                continue
            cur[inside] = z[inside]
        sub_f = fid[y0:y1 + 1, x0:x1 + 1]
        sub_b = bary[y0:y1 + 1, x0:x1 + 1]
        sub_f[inside] = f
        sub_b[inside, 0] = l0[inside]
        sub_b[inside, 1] = l1[inside]
        sub_b[inside, 2] = l2[inside]
    return fid, bary, zb


# --------------------------------------------------------------------------------------------- orientation

def rotations24():
    out = []
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product((1, -1), repeat=3):
            m = np.zeros((3, 3))
            for i in range(3):
                m[i, perm[i]] = signs[i]
            if np.linalg.det(m) > 0:
                out.append(m)
    return out


class Fit:
    """Projection orthographique d'un maillage tourné vers l'image découpée (pixels)."""

    def __init__(self, p, w, h):
        self.w, self.h = w, h
        lo, hi = p.min(0), p.max(0)
        self.cx, self.cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
        pw, ph = max(hi[0] - lo[0], 1e-9), max(hi[1] - lo[1], 1e-9)
        self.s = math.sqrt((w / pw) * (h / ph))
        self.dx = 0.0
        self.dy = 0.0

    def uv(self, p):
        return (self.s * (p[:, 0] - self.cx) + self.w / 2 + self.dx,
                self.h / 2 - self.s * (p[:, 1] - self.cy) + self.dy)


def _splat(u, v, c, g_w, g_h, z):
    """Nuage de points -> silhouette dilatée + image des couleurs (le plus proche de la caméra gagne)."""
    ix = np.clip(u.astype(np.int32), 0, g_w - 1)
    iy = np.clip(v.astype(np.int32), 0, g_h - 1)
    inb = (u >= 0) & (u < g_w) & (v >= 0) & (v < g_h)
    order = np.argsort(z[inb])
    ix, iy, cc = ix[inb][order], iy[inb][order], c[inb][order]
    img = np.zeros((g_h, g_w, 3), np.float32)
    msk = np.zeros((g_h, g_w), bool)
    img[iy, ix] = cc
    msk[iy, ix] = True
    msk = ndi.binary_closing(ndi.binary_dilation(msk, iterations=1), iterations=2)
    msk = ndi.binary_fill_holes(msk)
    return msk, img


def find_orientation(V, C, cut):
    """Cherche la rotation (parmi les 24 orientations de cube) et le cadrage qui superposent le mieux le maillage au dessin."""
    h0, w0 = cut.shape[:2]
    k = 220.0 / max(h0, w0)
    g_w, g_h = max(8, int(w0 * k)), max(8, int(h0 * k))
    small = np.asarray(Image.fromarray((cut * 255).astype(np.uint8), "RGBA").resize((g_w, g_h), Image.BILINEAR), np.float32) / 255.0
    mask = small[..., 3] > 0.5
    rgb = small[..., :3]
    if mask.sum() < 50:
        raise RuntimeError("image découpée vide")
    sub = np.random.default_rng(1).choice(len(V), min(len(V), 60000), replace=False)
    Vs, Cs = V[sub], C[sub]
    scores = []
    for ri, R in enumerate(rotations24()):
        P = Vs @ R.T
        fit = Fit(P, g_w, g_h)
        u, v = fit.uv(P)
        msk, img = _splat(u, v, Cs, g_w, g_h, P[:, 2])
        inter = (msk & mask).sum()
        iou = inter / max(1, (msk | mask).sum())
        scores.append((iou, ri, R))
    scores.sort(key=lambda t: -t[0])
    best = None
    for iou, ri, R in scores[:6]:
        P = Vs @ R.T
        fit = Fit(P, g_w, g_h)
        u, v = fit.uv(P)
        msk, img = _splat(u, v, Cs, g_w, g_h, P[:, 2])
        both = msk & mask
        err = float(np.abs(img[both] - rgb[both]).mean()) if both.sum() > 20 else 1.0
        score = iou - 0.8 * err
        if best is None or score > best[0]:
            best = (score, iou, err, R)
    _, iou, err, R = best
    log("orientation : IoU %.2f, écart de couleur %.2f" % (iou, err))
    # affinage du cadrage (échelle, décalage) par recherche locale sur l'IoU
    P = Vs @ R.T
    fit = Fit(P, g_w, g_h)
    s0 = fit.s

    def iou_of(ft):
        u, v = ft.uv(P)
        msk, _ = _splat(u, v, Cs, g_w, g_h, P[:, 2])
        return (msk & mask).sum() / max(1, (msk | mask).sum())

    cur = iou_of(fit)
    step_s, step_d = 0.04, 0.03
    for _ in range(4):
        improved = False
        for ds, dx, dy in itertools.product((-1, 0, 1), repeat=3):
            if ds == dx == dy == 0:
                continue
            ft = Fit(P, g_w, g_h)
            ft.s = fit.s * (1 + ds * step_s)
            ft.dx = fit.dx + dx * step_d * g_w
            ft.dy = fit.dy + dy * step_d * g_h
            sc = iou_of(ft)
            if sc > cur + 1e-4:
                cur, fit, improved = sc, ft, True
        if not improved:
            step_s *= 0.5
            step_d *= 0.5
    log("cadrage affiné : IoU %.2f" % cur)
    # ramène dans les pixels de l'image pleine
    full = Fit(V @ R.T, w0, h0)
    full.s = fit.s / k
    full.dx = fit.dx / k
    full.dy = fit.dy / k
    return R, full


# --------------------------------------------------------------------------------------------- maillage

def vertex_normals(V, F):
    n = np.zeros_like(V)
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    for i in range(3):
        np.add.at(n, F[:, i], fn)
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    return n / np.maximum(ln, 1e-12)


def signed_volume(V, F):
    a, b, c = V[F[:, 0]], V[F[:, 1]], V[F[:, 2]]
    return float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0)


def decimate(V, F, target):
    if len(F) <= target:
        return V, F
    try:
        import fast_simplification  # noqa
    except ImportError:
        try:
            log("installation de fast-simplification…")
            subprocess.run([sys.executable, "-m", "pip", "install", "-q", "fast-simplification"], check=True)
            import fast_simplification  # noqa
        except Exception as e:  # pragma: no cover
            log("allègement impossible (%s) : maillage gardé tel quel" % e)
            return V, F
    import fast_simplification as fs
    v2, f2 = fs.simplify(V.astype(np.float32), F.astype(np.int32), target_reduction=1.0 - target / len(F))
    log("allègement : %d → %d triangles" % (len(F), len(f2)))
    return np.asarray(v2, np.float64), np.asarray(f2, np.int64)


def unwrap(V, F, size):
    """Dépliage UV. Renvoie (indices de sommets sources, faces, uv (0..1)). xatlas si possible, sinon un atlas de triangles."""
    try:
        import xatlas
    except ImportError:
        try:
            log("installation de xatlas…")
            subprocess.run([sys.executable, "-m", "pip", "install", "-q", "xatlas"], check=True)
            import xatlas
        except Exception:
            xatlas = None
    if xatlas is not None:
        vmap, idx, uv = xatlas.parametrize(V.astype(np.float32), F.astype(np.uint32))
        log("dépliage xatlas : %d sommets" % len(vmap))
        return np.asarray(vmap, np.int64), np.asarray(idx, np.int64), np.asarray(uv, np.float64)
    log("xatlas absent : atlas de secours (un petit carré par paire de triangles)")
    n = len(F)
    pairs = (n + 1) // 2
    cells = int(math.ceil(math.sqrt(pairs)))
    c = 1.0 / cells
    pad = 1.5 / size
    vmap = F.reshape(-1).copy()
    idx = np.arange(n * 3).reshape(n, 3)
    uv = np.zeros((n * 3, 2))
    for f in range(n):
        cx, cy = (f // 2) % cells, (f // 2) // cells
        x0, y0 = cx * c, cy * c
        if f % 2 == 0:
            tri = [(x0 + pad, y0 + pad), (x0 + c - 2 * pad, y0 + pad), (x0 + pad, y0 + c - 2 * pad)]
        else:
            tri = [(x0 + c - pad, y0 + c - pad), (x0 + 2 * pad, y0 + c - pad), (x0 + c - pad, y0 + 2 * pad)]
        for j in range(3):
            uv[f * 3 + j] = tri[j]
    return vmap, idx, uv


# --------------------------------------------------------------------------------------------- texture

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def sample(img, u, v):
    """Échantillonnage bilinéaire d'une image (h,w,c) aux pixels (u,v)."""
    out = np.empty((len(u), img.shape[2]), np.float32)
    for c in range(img.shape[2]):
        out[:, c] = ndi.map_coordinates(img[..., c], [v - 0.5, u - 0.5], order=1, mode="nearest")
    return out


def upscale_source(cut, target_h):
    """Agrandit le dessin (Lanczos + netteté légère) pour que l'échantillonnage ne le floute pas."""
    h, w = cut.shape[:2]
    f = max(1.0, min(4.0, target_h / h))
    im = Image.fromarray((cut * 255 + 0.5).astype(np.uint8), "RGBA")
    if f > 1.01:
        rgb = im.convert("RGB").resize((int(w * f), int(h * f)), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.4, percent=70, threshold=2))
        a = im.getchannel("A").resize(rgb.size, Image.BILINEAR)
        rgb.putalpha(a)
        im = rgb
    return np.asarray(im, np.float32) / 255.0, f


def finish(V, F, C, cut, size, faces):
    """V (N,3) sommets, F (M,3) triangles, C (N,3) couleurs 0..1, cut (h,w,4) 0..1 -> (sommets, normales, uv, triangles, texture uint8)."""
    R, fit0 = find_orientation(V, C, cut)
    Vr = V @ R.T
    if signed_volume(Vr, F) < 0:
        F = F[:, ::-1]
    # allègement
    Vd, Fd = decimate(Vr, F, faces)
    # dépliage
    vmap, idx, uv = unwrap(Vd, Fd, size)
    Vu = Vd[vmap]
    Nvert = vertex_normals(Vd, Fd)[vmap]
    # rasterisation dans l'atlas
    log("rasterisation de l'atlas %d×%d…" % (size, size))
    tri_uv = np.stack([uv[idx][:, :, 0] * size, uv[idx][:, :, 1] * size], axis=2)
    fid, bary, _ = rasterize(tri_uv, size, size)
    valid = fid >= 0
    ys, xs = np.nonzero(valid)
    f = fid[ys, xs]
    b = bary[ys, xs]
    tri_v = idx[f]
    pos = np.einsum("tj,tjk->tk", b, Vu[tri_v])
    nrm = np.einsum("tj,tjk->tk", b, Nvert[tri_v])
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
    # couleur de base : sommets les plus proches du maillage d'origine
    log("couleurs de base…")
    from scipy.spatial import cKDTree
    tree = cKDTree(Vr)
    dist, nn = tree.query(pos, k=4)
    wgt = 1.0 / np.maximum(dist, 1e-6)
    wgt /= wgt.sum(axis=1, keepdims=True)
    base = np.einsum("tk,tkc->tc", wgt, C[nn]).astype(np.float32)
    # dessin d'origine agrandi
    up, fscale = upscale_source(cut, min(size * 1.0, 4096))
    h, w = up.shape[:2]
    fit = Fit(Vr, w, h)
    fit.s = fit0.s * fscale
    fit.dx = fit0.dx * fscale
    fit.dy = fit0.dy * fscale
    fit.cx, fit.cy = fit0.cx, fit0.cy
    u_t, v_t = fit.uv(pos)
    # tampons de profondeur, avant et arrière (grille réduite)
    zg = 1024.0 / max(w, h)
    gw, gh = max(8, int(w * zg)), max(8, int(h * zg))
    uu, vv = fit.uv(Vd)
    tri_f = np.stack([uu[Fd] * zg, vv[Fd] * zg], axis=2)
    _, _, zfront = rasterize(tri_f, gw, gh, Vd[Fd][:, :, 2])
    _, _, zback = rasterize(tri_f, gw, gh, -Vd[Fd][:, :, 2])
    span = float(Vd[:, 2].max() - Vd[:, 2].min())
    tol = 0.02 * span
    gu = np.clip((u_t * zg).astype(np.int32), 0, gw - 1)
    gv = np.clip((v_t * zg).astype(np.int32), 0, gh - 1)
    vis_f = pos[:, 2] >= zfront[gv, gu] - tol
    vis_b = -pos[:, 2] >= zback[gv, gu] - tol
    alpha_tex = np.asarray(Image.fromarray((up[..., 3] * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)), np.float32) / 255.0
    inside = sample(alpha_tex[..., None], u_t, v_t)[:, 0]
    front_rgb = sample(up[..., :3], u_t, v_t)
    w_front = smoothstep(0.15, 0.6, nrm[:, 2]) * vis_f * smoothstep(0.3, 0.9, inside)
    # recalage global de la couleur de base sur celle du dessin (là où les deux se voient)
    ref = w_front > 0.9
    gain = np.ones(3, np.float32)
    if ref.sum() > 200:
        gain = np.clip(front_rgb[ref].mean(0) / np.maximum(base[ref].mean(0), 1e-3), 0.6, 1.6)
        log("recalage couleur du reste : x%.2f %.2f %.2f" % tuple(gain))
    base = np.clip(base * gain, 0, 1)
    # grain fin du dessin sur le dos / les côtés
    lum = up[..., :3].mean(2)
    blur = ndi.gaussian_filter(lum, 2.5 * fscale)
    hp = np.tanh((lum - blur) / 0.08) * 0.08
    uc = fit.w / 2 + fit.dx
    u_b = 2 * uc - u_t
    hb = sample(hp[..., None], u_b, v_t)[:, 0]
    inside_b = sample(alpha_tex[..., None], u_b, v_t)[:, 0]
    w_back = smoothstep(0.15, 0.6, -nrm[:, 2]) * vis_b * smoothstep(0.3, 0.9, inside_b)
    rest = np.clip(base + (hb * w_back * 0.9)[:, None], 0, 1)
    col = rest * (1 - w_front[:, None]) + front_rgb * w_front[:, None]
    tex = np.zeros((size, size, 3), np.float32)
    tex[ys, xs] = col
    # joints : prolonge les bords de 6 pixels
    inv = ~valid
    near = ndi.distance_transform_edt(inv, return_distances=False, return_indices=True)
    dist_edge = ndi.distance_transform_edt(inv)
    grown = tex[near[0], near[1]]
    tex = np.where(valid[..., None], tex, np.where((dist_edge <= 6)[..., None], grown, 0.5))
    # sortie normalisée comme Monster Studio : centré, pieds à 0, hauteur 2
    lo, hi = Vu.min(0), Vu.max(0)
    ctr = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    sc = 2.0 / max(hi[1] - lo[1], 1e-9)
    Vout = (Vu - ctr) * sc
    return Vout, Nvert, uv, idx, (np.clip(tex, 0, 1) * 255 + 0.5).astype(np.uint8)


# --------------------------------------------------------------------------------------------- export .glb

def write_glb(path, V, N, UV, F, png_bytes):
    V = V.astype(np.float32)
    N = N.astype(np.float32)
    UV = UV.astype(np.float32)
    F = F.astype(np.uint32)
    parts = [V.tobytes(), N.tobytes(), UV.tobytes(), F.tobytes(), png_bytes]
    views, offs, off = [], [], 0
    for p in parts:
        pad = (4 - len(p) % 4) % 4
        offs.append((off, len(p)))
        off += len(p) + pad
        views.append(p + b"\0" * pad)
    blob = b"".join(views)
    js = {
        "asset": {"version": "2.0", "generator": "Monster Studio bake_texture"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": "monstre"}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
        "materials": [{"pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0}}],
        "textures": [{"source": 0, "sampler": 0}], "images": [{"bufferView": 4, "mimeType": "image/png"}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}],
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": offs[0][0], "byteLength": offs[0][1], "target": 34962},
            {"buffer": 0, "byteOffset": offs[1][0], "byteLength": offs[1][1], "target": 34962},
            {"buffer": 0, "byteOffset": offs[2][0], "byteLength": offs[2][1], "target": 34962},
            {"buffer": 0, "byteOffset": offs[3][0], "byteLength": offs[3][1], "target": 34963},
            {"buffer": 0, "byteOffset": offs[4][0], "byteLength": offs[4][1]},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(V), "type": "VEC3", "min": V.min(0).tolist(), "max": V.max(0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": len(N), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": len(UV), "type": "VEC2"},
            {"bufferView": 3, "componentType": 5125, "count": int(F.size), "type": "SCALAR"},
        ],
    }
    jb = json.dumps(js, separators=(",", ":")).encode()
    jb += b" " * ((4 - len(jb) % 4) % 4)
    total = 12 + 8 + len(jb) + 8 + len(blob)
    with open(path, "wb") as fh:
        fh.write(struct.pack("<4sII", b"glTF", 2, total))
        fh.write(struct.pack("<I4s", len(jb), b"JSON") + jb)
        fh.write(struct.pack("<I4s", len(blob), b"BIN\0") + blob)


# --------------------------------------------------------------------------------------------- entrée

def load_cut(cut_path):
    im = Image.open(cut_path).convert("RGBA")
    return np.asarray(im, np.float32) / 255.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mesh", required=True)
    ap.add_argument("--cut", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", type=int, default=2048)
    ap.add_argument("--faces", type=int, default=30000)
    a = ap.parse_args()
    import trimesh
    m = trimesh.load(a.mesh, force="mesh", process=False)
    V = np.asarray(m.vertices, np.float64)
    F = np.asarray(m.faces, np.int64)
    try:
        C = np.asarray(m.visual.vertex_colors, np.float64)[:, :3] / 255.0
    except Exception:
        C = np.full((len(V), 3), 0.5)
    log("maillage : %d sommets, %d triangles" % (len(V), len(F)))
    cut = load_cut(a.cut)
    Vo, No, uv, F2, tex = finish(V, F, C, cut, a.size, a.faces)
    buf = io.BytesIO()
    Image.fromarray(tex, "RGB").save(buf, "PNG", optimize=False)
    write_glb(a.out, Vo, No, uv, F2, buf.getvalue())
    log("terminé : %s (texture %d×%d, %d triangles)" % (a.out, a.size, a.size, len(F2)))


if __name__ == "__main__":
    main()
