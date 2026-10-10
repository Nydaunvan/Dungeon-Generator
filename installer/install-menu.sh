#!/bin/sh
# Ajoute Dungeon Generator au menu des applications (avec son icône), pour l'utilisateur courant. Aucun droit administrateur.
# À lancer une fois depuis le dossier du jeu : ./install-menu.sh        Pour retirer l'entrée : ./install-menu.sh --remove
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
if [ "${1:-}" = "--remove" ]; then
  rm -f "$APPS/dungeon-generator.desktop" "$ICONS/dungeon-generator.png"
  echo "Entrée du menu retirée."
  exit 0
fi
mkdir -p "$APPS" "$ICONS"
cp "$DIR/Dungeon Generator.png" "$ICONS/dungeon-generator.png"
cat > "$APPS/dungeon-generator.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Dungeon Generator
Comment=Éditeur et jeu de donjons
Exec="$DIR/Dungeon Generator.x86_64"
Path=$DIR
Icon=dungeon-generator
Terminal=false
Categories=Game;RolePlaying;
StartupWMClass=Dungeon Generator
EOF
chmod 644 "$APPS/dungeon-generator.desktop"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" >/dev/null 2>&1 || true
echo "Dungeon Generator ajouté au menu des applications."
