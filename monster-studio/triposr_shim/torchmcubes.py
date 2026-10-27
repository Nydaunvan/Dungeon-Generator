"""Remplaçant de `torchmcubes` pour TripoSR, sans compilation (scikit-image à la place).

TripoSR appelle `marching_cubes(vol, seuil)` et s'attend à :
  - des sommets (x, y, z) où x est l'indice du DERNIER axe du volume (donc l'ordre inverse des axes) ;
    TripoSR les remet ensuite dans l'ordre des axes avec `v_pos[..., [2, 1, 0]]` ;
  - des faces de triangles (indices de sommets).
Ce fichier est copié dans le dossier de TripoSR par install_triposr.bat (il passe avant le vrai paquet dans le chemin d'import).
La orientation des faces est calée pour que les normales sortent de l'objet, quel que soit le sens choisi par scikit-image.
"""
import numpy as np


def _mc(vol: np.ndarray, thresh: float):
    from skimage import measure
    vol = np.ascontiguousarray(vol, dtype=np.float32)
    if not (float(vol.min()) < thresh < float(vol.max())):
        return np.zeros((0, 3), np.float32), np.zeros((0, 3), np.int64)       # aucune surface
    verts, faces, _normals, _values = measure.marching_cubes(vol, level=thresh)
    verts = verts.astype(np.float32)
    faces = faces.astype(np.int64)
    # volume signé du maillage (repère des axes du volume) : négatif = faces tournées vers l'intérieur
    a, b, c = verts[faces[:, 0]], verts[faces[:, 1]], verts[faces[:, 2]]
    if float(np.einsum("ij,ij->", a, np.cross(b, c))) < 0.0:
        faces = faces[:, ::-1].copy()
    return np.ascontiguousarray(verts[:, ::-1]), faces                        # sommets dans l'ordre (dernier axe, …, premier axe)


def marching_cubes(vol, thresh):
    import torch
    v = vol.detach().float().cpu().numpy()
    verts, faces = _mc(v, float(thresh))
    dev = vol.device
    return torch.from_numpy(verts).to(dev), torch.from_numpy(faces).to(dev)
