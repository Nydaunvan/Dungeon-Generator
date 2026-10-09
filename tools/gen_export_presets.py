#!/usr/bin/env python3
"""Régénère les préréglages d'export de bureau de export_presets.cfg à partir des définitions de paquets ci-dessous.
 - « Windows » et « Linux » : exécutable + « <nom>.pck » (code, scènes, données, polices, interface) sans les gros assets ;
 - « Pack <nom> » : un paquet par groupe de dossiers (exportés avec `godot --export-pack "Pack themes" build/packs/themes.pck`).
Le préréglage « Web » (tout intégré) est conservé tel quel. Usage : python3 tools/gen_export_presets.py"""
import re, pathlib

PACKS = {
    "themes": ["assets/themes"],
    "monsters": ["assets/monsters", "assets/portraits", "assets/sheets", "assets/misc"],
    "audio": ["assets/music", "assets/sounds"],
}
CORE_DIRS = ["scripts", "scenes", "data", "assets/fonts", "assets/ui", "assets/icons", "assets/home", "assets/splash.png"]
BASE_EXCLUDE = ["_tmp/*", "tests/*", "tools/*", "assets/themes/stone_lite/*", "assets/themes/fountain_lite/*"]

def join(items): return ", ".join(items)

def preset(n, name, platform, path, exclude, include, extra_opts):
    return f'''[preset.{n}]

name="{name}"
platform="{platform}"
runnable={"true" if n in (1, 2) else "false"}
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="{include}"
exclude_filter="{join(exclude)}"
export_path="{path}"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.{n}.options]

custom_template/debug=""
custom_template/release=""
{extra_opts}
'''

WIN_OPTS = '''debug/export_console_wrapper=0
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
application/modify_resources=false
application/product_name="Dungeon Generator"
application/file_description="Dungeon Generator"'''
LIN_OPTS = '''debug/export_console_wrapper=1
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
ssh_remote_deploy/enabled=false'''

def asset_dirs(dirs): return [d + ("/*" if "." not in d.split("/")[-1] else "*") for d in dirs]

def main():
    path = pathlib.Path(__file__).resolve().parent.parent / "export_presets.cfg"
    text = path.read_text(encoding="utf-8")
    web = text[:text.index("[preset.1]")].rstrip() + "\n\n"
    all_pack_dirs = [d for ds in PACKS.values() for d in ds]
    out = web
    out += preset(1, "Windows", "Windows Desktop", "build/windows/Dungeon Generator.exe", BASE_EXCLUDE + asset_dirs(all_pack_dirs), "data/*.json", WIN_OPTS) + "\n"
    out += preset(2, "Linux", "Linux", "build/linux/Dungeon Generator.x86_64", BASE_EXCLUDE + asset_dirs(all_pack_dirs), "data/*.json", LIN_OPTS) + "\n"
    for i, (name, dirs) in enumerate(PACKS.items(), start=3):
        others = CORE_DIRS + [d for n2, ds in PACKS.items() if n2 != name for d in ds]
        out += preset(i, "Pack " + name, "Linux", f"build/packs/{name}.pck", BASE_EXCLUDE + asset_dirs(others), "", LIN_OPTS) + "\n"
    path.write_text(out.rstrip() + "\n", encoding="utf-8")
    print("préréglages écrits :", ["Web", "Windows", "Linux"] + ["Pack " + n for n in PACKS])

if __name__ == "__main__":
    main()
