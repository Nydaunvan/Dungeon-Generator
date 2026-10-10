#!/usr/bin/env python3
"""Prépare les fichiers de publication d'une version à partir de l'export découpé (voir tools/gen_export_presets.py).

Entrées  : build/windows/Dungeon Generator.{exe,pck}, build/linux/Dungeon Generator.{x86_64,pck}, build/packs/*.pck
Sorties  : dist/ avec
  - les fichiers un par un (exe-<plateforme>, core-<plateforme>.pck, themes.pck, monsters.pck, audio.pck), que le jeu télécharge
    séparément lors d'une mise à jour ;
  - manifest-windows.json / manifest-linux.json : pour chaque fichier, son chemin d'installation, son nom dans la publication, sa
    taille, sa somme SHA-256 et un « content » = empreinte du CONTENU source (les paquets contiennent project.binary, donc leurs
    octets changent à chaque numéro de version alors que leur contenu non : le jeu compare « content », pas les octets) ;
  - Dungeon-Generator-<version>-<plateforme>-full.{zip,tar.gz} : installation complète (avec install.json) ;
  - payload-windows/ : dossier prêt pour l'installateur Windows.
Usage : python3 tools/pack_manifest.py <version>"""
import hashlib, json, pathlib, shutil, sys, tarfile, zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from gen_export_presets import PACKS   # noqa: E402  (les définitions de paquets vivent à un seul endroit)

GODOT = "4.7.2"

def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def source_content(dirs):
    """Empreinte des fichiers source d'un paquet (chemins + contenu, sans les variantes « lite » exclues de l'export de bureau)."""
    h = hashlib.sha256()
    h.update(GODOT.encode())
    h.update(sha(ROOT / "export_presets.cfg").encode())
    for d in sorted(dirs):
        for p in sorted((ROOT / d).rglob("*")) if (ROOT / d).is_dir() else [ROOT / d]:
            rel = p.relative_to(ROOT).as_posix()
            if not p.is_file() or "_lite" in rel:
                continue
            h.update(rel.encode())
            h.update(sha(p).encode())
    return h.hexdigest()

def main(version):
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    contents = {name: source_content(dirs) for name, dirs in PACKS.items()}
    for plat, exe_name, exe_asset in (("windows", "Dungeon Generator.exe", "exe-windows.exe"), ("linux", "Dungeon Generator.x86_64", "exe-linux.x86_64")):
        b = ROOT / "build" / plat
        files = []
        def add(src, path, asset, content=None):
            shutil.copyfile(src, dist / asset)
            digest = sha(src)
            files.append({"path": path, "asset": asset, "size": src.stat().st_size, "sha256": digest, "content": content or digest})
        add(b / exe_name, exe_name, exe_asset)
        core_src = b / "Dungeon Generator.pck"
        add(core_src, "Dungeon Generator.pck", f"core-{plat}.pck")
        for name in PACKS:
            add(ROOT / "build" / "packs" / f"{name}.pck", f"packs/{name}.pck", f"{name}.pck", contents[name])
        manifest = {"version": version, "platform": plat, "files": files}
        (dist / f"manifest-{plat}.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
        install = {"version": version, "files": {f["path"]: {"content": f["content"], "size": f["size"]} for f in files}}
        payload = ROOT / "build" / f"payload-{plat}"
        shutil.rmtree(payload, ignore_errors=True)
        (payload / "packs").mkdir(parents=True)
        shutil.copyfile(b / exe_name, payload / exe_name)
        shutil.copyfile(core_src, payload / "Dungeon Generator.pck")
        for name in PACKS:
            shutil.copyfile(ROOT / "build" / "packs" / f"{name}.pck", payload / "packs" / f"{name}.pck")
        (payload / "install.json").write_text(json.dumps(install, ensure_ascii=False, indent=1), encoding="utf-8")
        if plat == "linux":
            # icône et entrée du menu des applications (l'exécutable ELF ne porte pas d'icône) : « ./install-menu.sh »
            shutil.copyfile(ROOT / "installer" / "app_icon_256.png", payload / "Dungeon Generator.png")
            sh = payload / "install-menu.sh"
            shutil.copyfile(ROOT / "installer" / "install-menu.sh", sh)
            sh.chmod(0o755)
        full = f"Dungeon-Generator-{version}-{plat}-full"
        if plat == "windows":
            with zipfile.ZipFile(dist / f"{full}.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
                for p in sorted(payload.rglob("*")):
                    if p.is_file():
                        z.write(p, p.relative_to(payload).as_posix())
        else:
            (payload / exe_name).chmod(0o755)
            with tarfile.open(dist / f"{full}.tar.gz", "w:gz") as t:
                for p in sorted(payload.rglob("*")):
                    if p.is_file():
                        t.add(p, arcname=p.relative_to(payload).as_posix())
    print("fichiers prêts dans", dist)

if __name__ == "__main__":
    main(sys.argv[1])
