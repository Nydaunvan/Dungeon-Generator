#!/usr/bin/env python3
"""Découpe la PLANCHE d'un monstre « Atlas Noir » et écrit les cinq webp du jeu.
Usage : python3 tools/make_monster.py <id> planche.png [--sans-liseré]
  → assets/monsters/<id>.webp, <id>_attack.webp, <id>_hit.webp, <id>_attack2.webp, <id>_dead.webp (carrés, RGBA, même taille)
    + une carte de normales par pose (<id>_n.webp, <id>_attack_n.webp…) pour l'éclairage en relief (import : compress/normal_map=1, mipmaps).

Format de la planche (fond transparent, un liseré blanc « autocollant » autour de chaque pose) :
  en haut, de gauche à droite : Attente, Attaque, Impact (coup reçu) ; en bas : Attaque alternative, Mort.
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
    by_y = sorted(keep, key=lambda i: cm[i][0])
    top = sorted(by_y[:3], key=lambda i: cm[i][1])
    bot = sorted(by_y[3:], key=lambda i: cm[i][1])
    poses = []
    for i in top + bot:
        mine = lab == i                                           # pixels de CETTE pose seulement (liseré compris)
        solid = (al > 0.5) & mine
        ys, xs = np.where(mine)
        y0, y1 = max(0, ys.min() - 4), min(al.shape[0], ys.max() + 5)
        x0, x1 = max(0, xs.min() - 4), min(al.shape[1], xs.max() + 5)
        poses.append(clean(rgb[y0:y1, x0:x1], solid[y0:y1, x0:x1], (al * mine)[y0:y1, x0:x1]))
    return poses

def clean(rgb, solid, soft):
    """Par défaut le liseré blanc est GARDÉ (alpha d'origine de la planche, poussière écartée). Avec --sans-liseré : retire le liseré
    relié à l'extérieur, érode, adoucit."""
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
    global KEEP_OUTLINE
    if "--sans-liseré" in sys.argv:
        sys.argv.remove("--sans-liseré"); KEEP_OUTLINE = False
    mid, sheet = sys.argv[1], sys.argv[2]
    poses = split(sheet)
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
        nout = ROOT / "assets/monsters" / f"{mid}{suf}_n.webp"
        Image.fromarray((nm * 255 + 0.5).astype(np.uint8), "RGB").save(nout, lossless=True, quality=100, method=6)
        print("écrit", out.relative_to(ROOT), "+ normales")
    print(f"carré {side} px ; pose d'attente haute de {idle_h} px = {idle_h / side:.3f} du carré")

if __name__ == "__main__":
    main()
