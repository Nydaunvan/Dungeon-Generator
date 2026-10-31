#!/usr/bin/env python3
"""Estime l'échelle de chaque pose d'un monstre (cinq images) par rapport à l'attente, en comparant TOUTES les paires de poses.

Usage : python3 tools/estimate_scales.py repos.png attaque.png coup.png attaque2.png mort.png
Affiche les échelles à passer à `make_monster.py --echelles=...`.

Pourquoi : `make_monster.py` apparie chaque pose à l'attente (points SIFT + similitude RANSAC). Quand une pose est très différente de l'attente
(attaque en fente, mort effondrée), il y a trop peu d'appariements fiables et l'échelle retombe à 1,0. Les poses voisines (deux attaques, coup reçu)
s'apparient bien entre elles : on résout alors les échelles globales par moindres carrés pondérés (en logarithme) sur toutes les paires fiables
(au moins 14 points concordants). Une pose sans aucune paire fiable (souvent la mort) reste à 1,0 : à contrôler à l'œil."""
import sys, itertools
import cv2
import numpy as np

NAMES = ["repos", "attaque", "coup", "attaque2", "mort"]

def main():
    files = sys.argv[1:]
    assert len(files) == 5, "cinq images attendues (repos, attaque, coup, attaque2, mort)"
    sift = cv2.SIFT_create(6000)
    feats = []
    for f in files:
        im = cv2.imread(f, cv2.IMREAD_UNCHANGED)
        g = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2GRAY)
        feats.append(sift.detectAndCompute(g, (im[..., 3] > 200).astype(np.uint8) * 255))
    rows, rhs, wts = [], [], []
    linked = {0}
    for i, j in itertools.combinations(range(5), 2):
        (ki, di), (kj, dj) = feats[i], feats[j]
        if di is None or dj is None:
            continue
        good = [m for m, n in cv2.BFMatcher().knnMatch(di, dj, k=2) if m.distance < 0.8 * n.distance]
        if len(good) < 8:
            continue
        src = np.float32([ki[m.queryIdx].pt for m in good]); dst = np.float32([kj[m.trainIdx].pt for m in good])
        M, inl = cv2.estimateAffinePartial2D(src, dst, method=cv2.RANSAC, ransacReprojThreshold=6)
        if M is None:
            continue
        n = int(inl.sum()); sc = float(np.sqrt(abs(np.linalg.det(M[:, :2]))))
        ok = n >= 14 and 0.8 < sc < 1.25
        print(f"  {NAMES[i]:8s} → {NAMES[j]:8s} échelle {sc:.3f}  points concordants {n:3d}  {'retenue' if ok else 'ignorée'}")
        if ok:
            r = np.zeros(5); r[i] = 1; r[j] = -1
            rows.append(r); rhs.append(np.log(sc)); wts.append(n)
            linked |= {i, j}
    A = np.vstack(rows + [np.eye(5)[0] * 100]); b = np.append(rhs, 0.0); w = np.sqrt(np.append(wts, 1.0))
    x, *_ = np.linalg.lstsq(A * w[:, None], b * w, rcond=None)
    sc = [float(np.exp(v)) if k in linked else 1.0 for k, v in enumerate(x)]
    for k in range(5):
        print(f"{NAMES[k]:9s} {sc[k]:.3f}" + ("" if k in linked else "   (aucune paire fiable : laissée à 1,0, à contrôler à l'œil)"))
    print("--echelles=" + ",".join("%.3f" % v for v in sc))

if __name__ == "__main__":
    main()
