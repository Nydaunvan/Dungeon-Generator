#!/usr/bin/env python3
"""Notes de publication GitHub d'une version, tirées de data/changelog.json (même texte que le journal du jeu).
Usage : python3 tools/release_notes.py [version] [--vt vt.json] [--out notes.md]
(version par défaut : config/version de project.godot) ; Markdown sur la sortie, ou dans --out.
Avec --vt, le bandeau VirusTotal (tools/virustotal.py) est placé tout en haut."""
import io, json, os, sys
from version_util import project_version, base_version, key, changelog

args = sys.argv[1:]
opts = {}
for o in ('--vt', '--out'):
    if o in args:
        i = args.index(o)
        opts[o] = args[i + 1]
        del args[i:i + 2]
v = args[0] if args else project_version()
buf = io.StringIO()
_print = print
def print(*a):  # noqa: A001  (tout est d'abord écrit en mémoire)
    _print(*a, file=buf)
if '--vt' in opts and os.path.isfile(opts['--vt']):
    from virustotal import banner
    sys.stdout.reconfigure(encoding='utf-8') if hasattr(sys.stdout, 'reconfigure') else None
    _print(banner(json.load(open(opts['--vt'], encoding='utf-8'))), end='', file=buf)
want = base_version(v)
entry = next((e for e in changelog() if key(str(e['version'])) == key(want)), None)
if entry is None:
    print('Notes de version à venir.')
else:
    for line in entry['changes']:
        s = str(line)
        print(('\n### ' + s[3:] + '\n') if s.startswith('## ') else '- ' + s)

if '--out' in opts:
    open(opts['--out'], 'w', encoding='utf-8').write(buf.getvalue())
else:
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    sys.stdout.write(buf.getvalue())
