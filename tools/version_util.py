"""Utilitaires de version partagés par check_version.py, release_notes.py et le workflow de publication."""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SEMVER = re.compile(r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.]+))?$')

def project_version():
    m = re.search(r'^config/version="([^"]*)"', (ROOT / 'project.godot').read_text(encoding='utf-8'), re.M)
    return m.group(1) if m else ''

def base_version(v):
    """« 1.30.1-test2 » -> « 1.30.1 »."""
    return v.split('-', 1)[0]

def key(v):
    """Clé de tri numérique : « 1.29 » et « 1.29.0 » sont égaux."""
    parts = [int(x) for x in re.findall(r'\d+', base_version(v))][:3]
    return tuple(parts + [0] * (3 - len(parts)))

def changelog():
    return json.loads((ROOT / 'data' / 'changelog.json').read_text(encoding='utf-8'))
