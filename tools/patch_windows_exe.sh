#!/bin/sh
# Donne à l'exécutable Windows exporté son icône et ses informations de version (au lieu de l'icône de Godot), avec rcedit sous Wine.
# Usage : tools/patch_windows_exe.sh "<exe>" <version> [<rcedit-x64.exe>]        (la version peut porter un suffixe : 1.32.1-test2)
# Puis vérification (tools/check_exe_icon.py) : un échec n'arrête pas la publication, il est signalé par un avertissement.
set -eu
EXE="$1"; VERSION="$2"; RCEDIT="${3:-$HOME/rcedit/rcedit-x64.exe}"
BASE=${VERSION%%-*}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ICO="$ROOT/installer/app.ico"
export WINEDEBUG=-all
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-rcedit}"
wine "$RCEDIT" "$EXE" \
  --set-icon "$ICO" \
  --set-file-version "$BASE" --set-product-version "$BASE" \
  --set-version-string ProductName "Dungeon Generator" \
  --set-version-string FileDescription "Dungeon Generator" \
  --set-version-string OriginalFilename "Dungeon Generator.exe" \
  --set-version-string CompanyName "Nydaunvan"
if python3 "$ROOT/tools/check_exe_icon.py" "$EXE" "$ICO"; then
  echo "Icône appliquée à $EXE"
else
  echo "::warning::L'icône n'a pas pu être vérifiée dans l'exécutable Windows (il garde peut-être l'icône de Godot)."
fi
