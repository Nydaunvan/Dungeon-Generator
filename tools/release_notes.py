#!/usr/bin/env python3
"""Notes de publication GitHub d'une version, tirées de data/changelog.json (même texte que le journal du jeu).
Usage : python3 tools/release_notes.py [version]  (par défaut : config/version de project.godot) ; Markdown sur la sortie."""
import sys
from version_util import project_version, base_version, key, changelog

v = sys.argv[1] if len(sys.argv) > 1 else project_version()
want = base_version(v)
entry = next((e for e in changelog() if key(str(e['version'])) == key(want)), None)
if entry is None:
    print('Notes de version à venir.')
else:
    for line in entry['changes']:
        s = str(line)
        print(('\n### ' + s[3:] + '\n') if s.startswith('## ') else '- ' + s)
