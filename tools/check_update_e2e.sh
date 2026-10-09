#!/bin/sh
# Essai de bout en bout de la mise à jour partielle (Linux). Prérequis : export découpé dans build/ (voir release.yml).
# Usage : sh tools/check_update_e2e.sh   (variable GODOT = binaire de Godot)
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
T=$(mktemp -d)
python3 tools/pack_manifest.py 9.9.9 >/dev/null
cp -r build/payload-linux "$T/inst"
cd "$T/inst"
# ancienne installation : paquet principal différent, paquet audio absent, exécutable factice (relance simulée)
printf 'old' >> "Dungeon Generator.pck"
rm packs/audio.pck
printf '#!/bin/sh\ntouch "%s/RELANCE"\n' "$T" > "Dungeon Generator.x86_64"
chmod +x "Dungeon Generator.x86_64"
python3 - <<PY
import json
s=json.load(open('install.json'))
m=json.load(open('$OLDPWD/dist/manifest-linux.json'))
exe=[f for f in m['files'] if f['path'].endswith('.x86_64')][0]
import os
s['files']['Dungeon Generator.x86_64']={'content':exe['content'],'size':os.path.getsize('Dungeon Generator.x86_64')}
s['files']['Dungeon Generator.pck']['size']=os.path.getsize('Dungeon Generator.pck')   # taille locale = taille enregistrée, contenu différent
s['files']['Dungeon Generator.pck']['content']='ancien'
json.dump(s,open('install.json','w'))
PY
cd - >/dev/null
python3 -m http.server 8765 --directory dist >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null; rm -rf "$T" 2>/dev/null; true' EXIT
sleep 1
ASSETS=$(ls dist | tr '\n' ',' | sed 's/,$//')
OUT=$($GODOT --headless --path . res://tools/check_update_e2e.tscn -- base=http://127.0.0.1:8765 exe="$T/inst/Dungeon Generator.x86_64" assets="$ASSETS" 2>&1) || true
echo "$OUT" | grep -vE "ALSA|^$" | tail -15
sleep 5
ok=1
cmp -s "$T/inst/Dungeon Generator.pck" dist/core-linux.pck || { echo "ÉCHEC : paquet principal non remplacé"; ok=0; }
cmp -s "$T/inst/packs/audio.pck" dist/audio.pck || { echo "ÉCHEC : paquet audio absent"; ok=0; }
[ -f "$T/RELANCE" ] || { echo "ÉCHEC : le jeu n'a pas été relancé"; ok=0; }
[ $ok = 1 ] && echo "OK : mise à jour partielle de bout en bout"
[ $ok = 1 ]
