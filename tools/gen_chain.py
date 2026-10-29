import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SS = 2                     # sur-échantillonnage
PX = 4                     # pixels par unité de conception
def fbm(h, w, seed, oct=5, base=6):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w)); amp = 1.0; tot = 0
    for o in range(oct):
        g = rng.random((base * 2**o + 2, max(2, int(base * 2**o * w / h)) + 2))
        out += amp * ndi.zoom(g, (h / g.shape[0], w / g.shape[1]), order=3)[:h, :w]
        tot += amp; amp *= 0.5
    return out / tot

def load_patch():
    src = Image.open("/mnt/user-data/attachments/97f20bf3-1ee6-5379-b46f-c57472fef5c6/75fdfba2-image.png").convert("RGB")
    pt = np.asarray(src.crop((616, 84, 684, 322))).astype(np.float32) / 255      # intérieur du tube rouillé
    low = np.stack([ndi.gaussian_filter(pt[..., c], 14, mode="reflect") for c in range(3)], -1)
    detail = np.clip(pt / (low + 0.02), 0.35, 2.2)                                 # on retire l'éclairage cuit : reste le grain et la couleur locale
    mean = pt.reshape(-1, 3).mean(0)
    return detail, mean
PATCH, PMEAN = load_patch()
def alb_map(X, Y, ox, oy, scale):
    ph, pw = PATCH.shape[:2]
    u = (X * scale + ox) % (2 * pw); v = (Y * scale + oy) % (2 * ph)
    u = np.where(u >= pw, 2 * pw - 1 - u, u).astype(np.int32).clip(0, pw - 1)
    v = np.where(v >= ph, 2 * ph - 1 - v, v).astype(np.int32).clip(0, ph - 1)
    return PATCH[v, u]

LIGHT = np.array([-0.45, -0.55, 0.70]); LIGHT /= np.linalg.norm(LIGHT)

def tube(shape_sd, r, noise, yy):
    """shape_sd: distance signée (px) à la ligne médiane du tube (gradient donne le sens). Retourne couleur RGB + alpha."""
    pass

def seg_dist(X, Y, a, b):
    ax, ay = a; bx, by = b
    abx, aby = bx - ax, by - ay
    t = np.clip(((X - ax) * abx + (Y - ay) * aby) / max(1e-9, abx * abx + aby * aby), 0, 1)
    cx, cy = ax + t * abx, ay + t * aby
    return np.hypot(X - cx, Y - cy), X - cx, Y - cy

def shade(nx, ny, nz, mask, noise, hh, atex):
    h_, w_ = noise.shape
    fine = fbm(h_, w_, seed=5, oct=5, base=70)            # grain de rouille (relief)
    mid = fbm(h_, w_, seed=9, oct=4, base=18)              # plaques
    gy, gx = np.gradient(fine)
    nx = nx - gx * 18.0; ny = ny - gy * 18.0                # relief rugueux
    n = np.stack([nx, ny, nz], -1); n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-9
    diff = np.clip(n @ LIGHT, 0, 1)
    V = np.array([0, 0, 1.0]); H = LIGHT + V; H /= np.linalg.norm(H)
    spec = np.clip(n @ H, 0, 1) ** 20 * (0.10 + 0.25 * np.clip((atex.mean(-1) - 1.2) * 2.0, 0, 1))
    base = np.array([0.27, 0.17, 0.10])
    alb = base[None, None] * atex * (0.85 + 0.3 * fine[..., None])
    # bords orangés (comme l'anneau d'origine) : tons plus chauds vers les flancs du tube
    warm = (1 - hh)[..., None] ** 2 * np.array([0.25, 0.10, 0.0])
    alb = alb + warm * 0.6
    col = alb * (0.10 + 1.25 * diff[..., None]) + spec[..., None] * np.array([1.0, 0.8, 0.6])
    col += np.clip(0.5 - 0.5 * (2 * n[..., 2] * n[..., 1]), 0, 1)[..., None] ** 2 * 0.05 * np.array([1.0, 0.5, 0.2])
    col *= (0.30 + 0.70 * hh[..., None]) ** 0.9
    return np.clip(col, 0, 1)

def render(W, H, links, noise_seed=3):
    """links: liste (kind, cx, cy[, extra]) — 'F' lien de face (stade), 'E' lien de profil (barre), 'R' grand anneau."""
    w, h = W * SS, H * SS
    Y, X = np.mgrid[0:h, 0:w].astype(np.float32)
    noise = fbm(h, w, noise_seed, 5, 8)
    rgb = np.zeros((h, w, 3), np.float32); a = np.zeros((h, w), np.float32)
    r = 14.0 * SS
    def put(sd_dist, gx, gy, atex):
        nonlocal rgb, a
        d = sd_dist
        m = d < r
        hh = np.sqrt(np.clip(1 - (d / r) ** 2, 0, 1))
        nx = gx / r; ny = gy / r
        col = shade(nx, ny, hh, m, noise, hh, atex)
        edge = np.clip((r - d) / 1.2, 0, 1)          # anti-crénelage
        al = edge * m
        rgb = rgb * (1 - al[..., None]) + col * al[..., None]; a = np.maximum(a, al) * 1.0 + 0 * al
        a = np.where(al > 0, np.maximum(a, al), a)
    def put_shadow(mask_alpha):
        pass
    order = [l for l in links if l[0] in "FR"] + [l for l in links if l[0] == "E"]
    rng = np.random.default_rng(99)
    for kind, cx, cy, *ex in order:
        cx *= SS; cy *= SS
        flip = rng.random() < 0.5
        atex = alb_map(X if not flip else (w - X), Y, rng.integers(0, 400), rng.integers(0, 400), 0.9 / SS * 1.0 * 1.0)
        if kind == "F":      # stade : ligne médiane = rectangle arrondi (R=28 px, droite 36 px)
            Rr = 28.0 * SS; st = 18.0 * SS
            # distance à la ligne médiane = | dist(segment) - R |
            d0, dx, dy = seg_dist(X, Y, (cx, cy - st), (cx, cy + st))
            sd = d0 - Rr
            gx = np.where(d0 > 1e-6, dx / (d0 + 1e-9), 0); gy = np.where(d0 > 1e-6, dy / (d0 + 1e-9), 0)
            dd = np.abs(sd); sgn = np.sign(sd)
            put(dd, gx * sgn * dd, gy * sgn * dd, atex)
        elif kind == "R":    # grand anneau de face
            Rr = ex[0] * SS
            dx = X - cx; dy = Y - cy; d0 = np.hypot(dx, dy)
            sd = d0 - Rr; dd = np.abs(sd); sgn = np.sign(sd)
            put(dd, dx / (d0 + 1e-9) * sgn * dd, dy / (d0 + 1e-9) * sgn * dd, atex)
        else:                # profil : capsule verticale de rayon r (soit 46 px de droite)
            st = 46.0 * SS
            # ombre portée douce sur ce qui est dessous
            d0, dx, dy = seg_dist(X, Y, (cx, cy - st), (cx, cy + st))
            sh = np.clip(1 - (d0 - r) / (10.0 * SS), 0, 1) ** 2 * 0.55 * (d0 >= r)
            rgb *= (1 - sh[..., None]); 
            put(d0, dx, dy, atex)
    img = np.concatenate([rgb, a[..., None]], -1)
    im = Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize((W, H), Image.LANCZOS)
    return im

def pitch_links(cy_start, count_dir, cx, y_from, y_to):
    pass

def build_left():
    W, H = 100 * PX, 300 * PX
    skull = Image.open("/mnt/user-data/attachments/97f20bf3-1ee6-5379-b46f-c57472fef5c6/75fdfba2-image.png").convert("RGB")
    sw = W; sh = round(skull.height * W / skull.width)
    skull = skull.resize((sw, sh), Image.LANCZOS)
    arr = np.asarray(skull).astype(np.float32) / 255
    lum = arr.max(-1)
    dark = lum < 0.07
    lab, n = ndi.label(dark)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    alpha = (~bg).astype(np.float32)
    alpha = ndi.gaussian_filter(alpha, 1.0)
    alpha = np.clip((alpha - 0.3) / 0.5, 0, 1)
    # fondu en haut pour se fondre dans la chaîne
    fade = np.clip(np.arange(sh)[:, None] / (6.0 * PX), 0, 1)
    alpha = alpha * fade
    sk = np.dstack([arr, alpha])
    sk_im = Image.fromarray((sk * 255).astype(np.uint8), "RGBA")
    top = H - sh
    pitch = 16.0 * PX
    cF = top - 5.0 * PX                       # centre du lien de face qui coiffe la tête
    links = []
    cx = W / 2; k = 0
    y = cF
    while y > -80:
        links.append(("F" if k % 2 == 0 else "E", cx, y)); y -= pitch; k += 1
    base = render(W, H, links, noise_seed=11)
    # léger voile sombre sous le crâne pour le détacher du fond
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0)); out.alpha_composite(base)
    out.alpha_composite(sk_im, (0, top))
    return out

def build_right():
    W, H = 64 * PX, 367 * PX
    pitch = 16.0 * PX
    cx = W / 2
    ring_r = 40.0; ring_cy = H - 58.0 * 1.0
    links = [("R", cx, ring_cy, ring_r)]
    # dernier lien de profil passant dans l'anneau
    y = ring_cy - ring_r - 0.0 - 6.0       # le lien E coiffe le haut de l'anneau
    k = 0
    cE = ring_cy - ring_r + 18.0
    y = cE; k = 1
    while y > -80:
        links.append(("E" if k % 2 == 1 else "F", cx, y)); y -= pitch; k += 1
    return render(W, H, links, noise_seed=23)

if __name__ == "__main__":
    import sys
    out = sys.argv[1]
    build_left().save(out + "/chain_left.png")
    build_right().save(out + "/chain_right.png")
