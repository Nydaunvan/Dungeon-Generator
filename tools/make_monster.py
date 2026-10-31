#!/usr/bin/env python3
"""Découpe la PLANCHE d'un monstre « Atlas Noir » et écrit les cinq webp du jeu.
Usage : python3 tools/make_monster.py <id> planche.png [--sans-liseré | --liseré-uniforme[=N]]
     ou : python3 tools/make_monster.py <id> repos.png attaque.png coup.png attaque2.png mort.png   (cinq images, une par pose)
  --liseré-uniforme[=N] : retire le liseré d'origine (épaisseur inégale d'une image à l'autre, franges colorées, parfois absent) puis retrace un liseré blanc
     pur de N px (5 par défaut), identique sur les cinq poses, APRÈS la mise à l'échelle des poses.
  → assets/monsters/<id>.webp, <id>_attack.webp, <id>_hit.webp, <id>_attack2.webp, <id>_dead.webp (carrés, RGBA, même taille)
    + une carte de normales par pose (<id>_n.webp, <id>_attack_n.webp…) pour l'éclairage en relief (import : compress/normal_map=1, mipmaps).

Format de la planche (fond transparent, un liseré blanc « autocollant » autour de chaque pose) :
  3 poses en haut puis 2 en bas, OU une seule rangée de 5 (détectée toute seule), toujours dans l'ordre Attente, Attaque, Impact (coup reçu), Attaque alternative, Mort.
Traitements (indispensables pour que le sprite ne SCINTILLE pas en 3D) :
  1. découpe des cinq poses (composantes connexes de l'alpha) ;
  2. le liseré blanc est GARDÉ par défaut (choix de l'auteur) ; avec --sans-liseré : suppression du liseré blanc : pixels clairs reliés à l'extérieur (le trait noir de l'illustration reste), puis bord
     légèrement érodé et adouci : un trait clair fin qui bouge à la respiration ou à la caméra crépite à l'écran ;
  3. couleurs des pixels transparents prolongées depuis le bord (pas de frange claire ou noire aux mipmaps) ;
  4. AUCUN rééchantillonnage ni flou : la résolution d'origine de la planche est conservée (pas d'agrandissement) ;
  5. toutes les poses à la même échelle, dans un même carré : pieds sur la même ligne et centre de masse de l'attente au milieu.
Le carré est dimensionné pour que la pose la plus grande tienne ; l'affichage dans le jeu se règle par la ligne du monstre
dans EntityLayer.MON_HEIGHTS (hauteur de la pose d'attente = IDLE_FRAC × côté du carré, affichée à la fin du script).
Côté moteur : respiration réduite à 30 % pour ces monstres (EntityLayer, méta « atlas »).
Les imports Godot du dossier assets/monsters doivent avoir mipmaps/generate=true (voir assets/monsters/*.webp.import)."""
import sys, pathlib
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).resolve().parent.parent
SUFFIXES = ["", "_attack", "_hit", "_attack2", "_dead"]
OUTLINE_ITER = 16   # px max parcourus par le liseré blanc depuis l'extérieur
ERODE = 2           # px retirés ensuite (reste de liseré gris)
FEATHER = 1.0       # px de dégradé du bord
KEEP_OUTLINE = True  # liseré blanc conservé (voulu) ; --sans-liseré pour le retirer
UNIFORM_PX = 0       # > 0 : liseré d'origine remplacé par un liseré blanc de cette épaisseur (--liseré-uniforme)
FLOOR = 0.94        # position des pieds dans le carré (fraction de la hauteur)
MARGIN = 0.03       # marge minimale autour de la pose la plus grande

def split(sheet):
    """Renvoie les cinq poses (rgb float 0-1, alpha bool) recadrées, dans l'ordre Attente, Attaque, Impact, Attaque2, Mort."""
    a = np.asarray(Image.open(sheet).convert("RGBA")).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3]
    # noyaux érodés (deux poses dont les liserés se touchent restent séparées), puis chaque pixel va au noyau le plus proche
    core = ndi.binary_erosion(al > 0.5, iterations=6)
    clab, n = ndi.label(core)
    sizes = ndi.sum(core, clab, range(1, n + 1))
    keep = [i + 1 for i, s in enumerate(sizes) if s > 10000]
    assert len(keep) == 5, f"5 poses attendues, {len(keep)} trouvées (tailles : {sorted(sizes)[-8:]})"
    clab = np.where(np.isin(clab, keep), clab, 0)
    idx = ndi.distance_transform_edt(clab == 0, return_distances=False, return_indices=True)
    lab = np.where(al > 0.08, clab[idx[0], idx[1]], 0)
    cm = {i: ndi.center_of_mass(lab == i) for i in keep}
    one_row = al.shape[1] > 2.2 * al.shape[0]                   # planche large (cinq poses côte à côte) : de gauche à droite
    if one_row:
        order = sorted(keep, key=lambda i: cm[i][1])
    else:                                                       # 3 poses en haut, 2 en bas
        by_y = sorted(keep, key=lambda i: cm[i][0])
        order = sorted(by_y[:3], key=lambda i: cm[i][1]) + sorted(by_y[3:], key=lambda i: cm[i][1])
    poses = []
    for i in order:
        mine = lab == i                                           # pixels de CETTE pose seulement (liseré compris)
        solid = (al > 0.5) & mine
        ys, xs = np.where(mine)
        y0, y1 = max(0, ys.min() - 4), min(al.shape[0], ys.max() + 5)
        x0, x1 = max(0, xs.min() - 4), min(al.shape[1], xs.max() + 5)
        poses.append(clean(rgb[y0:y1, x0:x1], solid[y0:y1, x0:x1], (al * mine)[y0:y1, x0:x1]))
    return poses

def _scales(files):
    """Échelle de chaque pose par rapport à l'attente (images dessinées séparément : le monstre n'y a pas toujours la même taille).
    Appariement de points SIFT sur les détails rigides (crânes, boucles, écailles) + similitude RANSAC ; 1.0 si l'appariement échoue."""
    try:
        import cv2
    except ImportError:
        print("opencv absent : poses laissées à leur échelle d'origine")
        return [1.0] * len(files)
    sift = cv2.SIFT_create(4000)
    def feat(f):
        im = cv2.imread(str(f), cv2.IMREAD_UNCHANGED)
        g = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2GRAY)
        return sift.detectAndCompute(g, (im[..., 3] > 200).astype(np.uint8) * 255)
    k0, d0 = feat(files[0])
    out = [1.0]
    for f in files[1:]:
        k, d = feat(f)
        sc = 1.0
        if d is not None and d0 is not None and len(k) > 10:
            good = [m for m, n in cv2.BFMatcher().knnMatch(d, d0, k=2) if m.distance < 0.75 * n.distance]
            if len(good) >= 8:
                src = np.float32([k[m.queryIdx].pt for m in good]); dst = np.float32([k0[m.trainIdx].pt for m in good])
                M, inl = cv2.estimateAffinePartial2D(src, dst, method=cv2.RANSAC, ransacReprojThreshold=6)
                if M is not None and inl is not None and int(inl.sum()) >= 10:
                    sc = float(np.sqrt(abs(np.linalg.det(M[:, :2]))))
        out.append(sc if 0.8 < sc < 1.25 else 1.0)
    return out

def split_files(files):
    """Une image par pose (déjà sur fond transparent), dans l'ordre Attente, Attaque, Impact, Attaque alternative, Mort.
    Les poses sont remises à l'échelle de l'attente (voir _scales)."""
    scales = _scales(files)
    print("échelles des poses (par rapport à l'attente) :", ", ".join("%.3f" % x for x in scales))
    poses = []
    for f, sc in zip(files, scales):
        img = Image.open(f).convert("RGBA")
        if abs(sc - 1.0) > 0.02:
            r = img.resize((round(img.width * sc), round(img.height * sc)), Image.LANCZOS)    # LANCZOS sur RGBA prémultiplié : pas de frange
            pm = np.asarray(img).astype(np.float32) / 255; pm[..., :3] *= pm[..., 3:4]
            pm = np.asarray(Image.fromarray((pm * 255).astype(np.uint8), "RGBA").resize(r.size, Image.LANCZOS)).astype(np.float32) / 255
            a_ = pm[..., 3:4]; pm[..., :3] = np.where(a_ > 1e-4, pm[..., :3] / np.maximum(a_, 1e-4), 0)
            a = np.clip(pm, 0, 1)
        else:
            a = np.asarray(img).astype(np.float32) / 255
        rgb, al = a[..., :3], a[..., 3]
        mine = al > 0.08
        ys, xs = np.where(al > 0.5)
        m_ = 4 + UNIFORM_PX
        y0, y1 = max(0, ys.min() - m_), min(al.shape[0], ys.max() + m_ + 1)
        x0, x1 = max(0, xs.min() - m_), min(al.shape[1], xs.max() + m_ + 1)
        poses.append(clean(rgb[y0:y1, x0:x1], (al > 0.5)[y0:y1, x0:x1], (al * mine)[y0:y1, x0:x1]))
    return poses

def uniform_outline(rgb, solid, px):
    """Retire le liseré blanc d'origine puis retrace un liseré blanc pur de `px` px tout autour du dessin (trous du tissu compris).
    Le liseré d'origine : blanc relié au vide, plus la bande des 2 px du bord (frange colorée des pixels semi-transparents)."""
    lab, n = ndi.label(solid)
    if n > 1:
        sz = ndi.sum(solid, lab, range(1, n + 1))
        solid = np.isin(lab, [i + 1 for i, z in enumerate(sz) if z > 400])
    whitish = (rgb.min(-1) > 0.78) & ((rgb.max(-1) - rgb.min(-1)) < 0.18)
    band = solid & ~ndi.binary_erosion(solid, iterations=2, border_value=0)
    cand = (whitish | band) & solid
    removed = ~solid
    for _ in range(OUTLINE_ITER):
        grown = ndi.binary_dilation(removed) & cand & ~removed
        if not grown.any():
            break
        removed |= grown
    blob = whitish & solid & ~removed                 # restes de liseré piégés entre deux pointes
    wl, wn = ndi.label(blob)
    if wn:
        touch = np.unique(wl[ndi.binary_dilation(removed, iterations=2) & blob])
        wsz = ndi.sum(blob, wl, range(1, wn + 1))
        removed |= np.isin(wl, [i for i in touch if i and wsz[i - 1] < 1500])
    inner = solid & ~removed
    lab, n = ndi.label(inner)
    if n > 1:
        sz = ndi.sum(inner, lab, range(1, n + 1))
        inner = np.isin(lab, [i + 1 for i, z in enumerate(sz) if z > 300])
    dist = ndi.distance_transform_edt(~inner)
    alpha = np.where(inner, 1.0, np.clip(px + 0.5 - dist, 0, 1)).astype(np.float32)
    out = np.where(inner[..., None], rgb, 1.0).astype(np.float32)     # liseré : blanc pur, prolongé en blanc au-delà (pas de frange aux mipmaps)
    return out, alpha

def clean(rgb, solid, soft):
    """Par défaut le liseré blanc est GARDÉ (alpha d'origine de la planche, poussière écartée). Avec --sans-liseré : retire le liseré
    relié à l'extérieur, érode, adoucit."""
    if UNIFORM_PX > 0:
        return uniform_outline(rgb, solid, UNIFORM_PX)
    if KEEP_OUTLINE:
        lab, n = ndi.label(solid)
        if n > 1:
            sz = ndi.sum(solid, lab, range(1, n + 1))
            solid = np.isin(lab, [i + 1 for i, z in enumerate(sz) if z > 400])
        alpha = np.where(ndi.binary_dilation(solid, iterations=2), np.clip((soft - 0.06) / 0.9, 0, 1), 0).astype(np.float32)
        idx = ndi.distance_transform_edt(~solid, return_distances=False, return_indices=True)
        return rgb[idx[0], idx[1]], alpha
    solid = np.pad(solid, 2); rgb = np.pad(rgb, ((2, 2), (2, 2), (0, 0)), mode="edge")
    whitish = (rgb.min(-1) > 0.78) & ((rgb.max(-1) - rgb.min(-1)) < 0.18)
    removed = ~solid
    for _ in range(OUTLINE_ITER):
        grown = ndi.binary_dilation(removed) & whitish & solid
        if not grown.any() or (grown & ~removed).sum() == 0:
            break
        removed |= grown
    # restes de liseré piégés entre deux pointes de tissu : petits amas très clairs collés à la zone déjà retirée
    # (un reflet clair de l'illustration, lui, est séparé du vide par le trait noir)
    blob = whitish & solid & ~removed
    wl, wn = ndi.label(blob)
    if wn:
        touch = np.unique(wl[ndi.binary_dilation(removed, iterations=2) & blob])
        wsz = ndi.sum(blob, wl, range(1, wn + 1))
        removed |= np.isin(wl, [i for i in touch if i and wsz[i - 1] < 1500])
    inner = solid & ~removed
    inner = ndi.binary_opening(inner, iterations=1)
    lab, n = ndi.label(inner)                                    # on garde les pièces principales (pas de poussière)
    if n > 1:
        sz = ndi.sum(inner, lab, range(1, n + 1))
        inner = np.isin(lab, [i + 1 for i, s in enumerate(sz) if s > 400])
    inner = ndi.binary_erosion(inner, iterations=ERODE)
    alpha = np.clip((ndi.gaussian_filter(inner.astype(np.float32), FEATHER) - 0.2) / 0.6, 0, 1)
    idx = ndi.distance_transform_edt(~inner, return_distances=False, return_indices=True)
    return rgb[idx[0], idx[1]], alpha

NORMAL_PX = 5.0     # relief tiré de la luminance du dessin (en px de hauteur)
BEVEL_PX = 9.0      # arrondi de la silhouette : la lumière rase glisse sur les bords
BEVEL_W = 16        # largeur (px) de l'arrondi

def normal_map(rgb, alpha):
    """Carte de normales (convention Godot, Y vers le haut) : relief du dessin + silhouette arrondie, plat hors du sprite.
    C'est elle qui donne du volume aux sprites sous la torche et les lampes (sans elle, un sprite plat est éclairé uniformément)."""
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    h = (0.55 * ndi.gaussian_filter(lum, 1.1) + 0.45 * ndi.gaussian_filter(lum, 3.5)) * NORMAL_PX
    d = ndi.distance_transform_edt(alpha > 0.5)
    b = np.clip(d / BEVEL_W, 0, 1)
    h = h + (1 - (1 - b) ** 2) * BEVEL_PX
    hy, hx = np.gradient(h)
    n = np.dstack([-hx, hy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    n = np.where((alpha > 0.02)[..., None], n, np.array([0, 0, 1], np.float32))
    return n * 0.5 + 0.5

def stats(alpha):
    ys, xs = np.where(alpha > 0.5)
    w = alpha[ys, xs]
    return dict(top=ys.min(), bottom=ys.max(), left=xs.min(), right=xs.max(),
                cx=float((xs * w).sum() / w.sum()))

def main():
    global KEEP_OUTLINE, UNIFORM_PX
    if "--sans-liseré" in sys.argv:
        sys.argv.remove("--sans-liseré"); KEEP_OUTLINE = False
    for a in list(sys.argv):
        if a.startswith("--liseré-uniforme"):
            sys.argv.remove(a); UNIFORM_PX = int(a.split("=")[1]) if "=" in a else 5
    mid = sys.argv[1]
    files = sys.argv[2:]
    poses = split_files(files) if len(files) == 5 else split(files[0])     # 5 images (une par pose) ou une planche
    st = [stats(p[1]) for p in poses]
    idle_cx, idle_h = st[0]["cx"], st[0]["bottom"] - st[0]["top"] + 1
    # carré : tout doit tenir autour du centre de masse de l'attente et entre le sol et le plafond
    need_h = max((s["bottom"] - s["top"] + 1) for s in st) / (FLOOR - MARGIN)
    need_w = max(2 * max(s["cx"] - s["left"], s["right"] - s["cx"]) for s in st) / (1 - 2 * MARGIN)
    side = int(np.ceil(max(need_h, need_w) / 16) * 16)
    floor_y = int(round(FLOOR * side))
    for suf, (rgb, alpha), s in zip(SUFFIXES, poses, st):
        im = np.dstack([rgb, alpha])
        canvas = np.zeros((side, side, 4), np.float32)
        canvas[..., :3] = 0
        dy = floor_y - 1 - s["bottom"]
        dx = int(round(side / 2 - s["cx"])) if suf != "" else int(round(side / 2 - idle_cx))
        h, w = alpha.shape
        ys0, xs0 = max(0, dy), max(0, dx)
        ys1, xs1 = min(side, dy + h), min(side, dx + w)
        canvas[ys0:ys1, xs0:xs1] = im[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
        assert canvas[..., 3].sum() > 0.97 * alpha.sum(), f"pose {suf or 'repos'} rognée"
        out = ROOT / "assets/monsters" / f"{mid}{suf}.webp"
        Image.fromarray((canvas * 255 + 0.5).astype(np.uint8), "RGBA").save(out, lossless=True, quality=100, method=6)
        nm = normal_map(canvas[..., :3], canvas[..., 3])
        nim = Image.fromarray((nm * 255 + 0.5).astype(np.uint8), "RGB")
        if side > 1000:                                          # le relief n'a pas besoin de la définition du dessin : moitié moins de mémoire vidéo
            nim = nim.resize((side // 2, side // 2), Image.LANCZOS)
        nout = ROOT / "assets/monsters" / f"{mid}{suf}_n.webp"
        nim.save(nout, lossless=True, quality=100, method=6)
        print("écrit", out.relative_to(ROOT), "+ normales")
    print(f"carré {side} px ; pose d'attente haute de {idle_h} px = {idle_h / side:.3f} du carré")

if __name__ == "__main__":
    main()
