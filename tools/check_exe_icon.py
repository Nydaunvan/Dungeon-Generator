#!/usr/bin/env python3
"""Vérifie qu'un exécutable Windows (PE) contient bien les images d'un fichier .ico (donc l'icône du jeu, pas celle de Godot).
Usage : python3 tools/check_exe_icon.py <exe> <fichier.ico>     (code de sortie 0 = icône présente)"""
import struct, sys

def ico_images(path):
    """Images (octets) d'un fichier .ico : chaque entrée du répertoire pointe vers ses données."""
    data = open(path, 'rb').read()
    reserved, kind, count = struct.unpack_from('<HHH', data, 0)
    if reserved != 0 or kind != 1:
        raise ValueError('pas un fichier .ico')
    out = []
    for i in range(count):
        size, offset = struct.unpack_from('<II', data, 6 + i * 16 + 8)
        out.append(data[offset:offset + size])
    return out

def exe_icon_blobs(path):
    """Données de toutes les ressources RT_ICON d'un exécutable PE (analyse minimale du répertoire des ressources, sans dépendance)."""
    data = open(path, 'rb').read()
    if data[:2] != b'MZ':
        raise ValueError('pas un exécutable Windows')
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    if data[pe:pe + 4] != b'PE\0\0':
        raise ValueError('en-tête PE absent')
    nsec, = struct.unpack_from('<H', data, pe + 6)
    opt_size, = struct.unpack_from('<H', data, pe + 20)
    opt = pe + 24
    magic, = struct.unpack_from('<H', data, opt)
    dd = opt + (112 if magic == 0x20B else 96)          # répertoires de données (PE32+ : 112 octets d'en-tête, PE32 : 96)
    res_rva, res_size = struct.unpack_from('<II', data, dd + 2 * 8)
    if res_rva == 0:
        return []
    sections = []
    for k in range(nsec):
        vsize, vaddr, rsize, raw = struct.unpack_from('<IIII', data, opt + opt_size + k * 40 + 8)
        sections.append((vaddr, max(vsize, rsize), raw))

    def off(rva):
        for vaddr, size, raw in sections:
            if vaddr <= rva < vaddr + size:
                return raw + rva - vaddr
        raise ValueError('adresse hors des sections')

    base = off(res_rva)

    def entries(dir_off):
        named, ids = struct.unpack_from('<HH', data, dir_off + 12)
        for e in range(named + ids):
            name, target = struct.unpack_from('<II', data, dir_off + 16 + e * 8)
            yield name, target

    blobs = []
    for type_id, t in entries(base):
        if type_id != 3 or not t & 0x80000000:          # 3 = RT_ICON
            continue
        for _name, n in entries(base + (t & 0x7FFFFFFF)):
            if not n & 0x80000000:
                continue
            for _lang, leaf in entries(base + (n & 0x7FFFFFFF)):
                rva, size = struct.unpack_from('<II', data, base + leaf)
                blobs.append(data[off(rva):off(rva) + size])
    return blobs

def main():
    exe, ico = sys.argv[1], sys.argv[2]
    want = ico_images(ico)
    have = exe_icon_blobs(exe)
    missing = [i for i, w in enumerate(want) if w not in have]
    print(f'{len(want) - len(missing)}/{len(want)} images de l\'icône trouvées dans {exe}')
    sys.exit(1 if missing else 0)

if __name__ == '__main__':
    main()
