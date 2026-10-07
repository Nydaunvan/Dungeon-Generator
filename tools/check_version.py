#!/usr/bin/env python3
"""Cohérence de la version : format MAJEUR.MINEUR.CORRECTIF (suffixe de test possible : 1.30.1-test1) et lien avec le journal.
 - erreur  : format invalide, ou journal plus récent que project.godot ;
 - alerte  : aucune entrée du journal pour la version en cours (rédigée sur demande) — ne bloque pas.
Usage : python3 tools/check_version.py  (code de sortie 1 en cas d'erreur)."""
import sys
from version_util import project_version, base_version, key, changelog, SEMVER

v = project_version()
if not SEMVER.match(v):
    print(f'ERREUR : config/version « {v} » invalide (attendu : 1.30.1 ou 1.30.1-test1)'); sys.exit(1)
entries = changelog()
if not entries:
    print('ERREUR : journal vide'); sys.exit(1)
top = str(entries[0]['version'])
vk, tk = key(v), key(top)
if tk > vk:
    print(f'ERREUR : le journal ({top}) est plus récent que project.godot ({v})'); sys.exit(1)
ordered = all(key(str(a['version'])) >= key(str(b['version'])) for a, b in zip(entries, entries[1:]))
if not ordered:
    print('ERREUR : les versions du journal ne sont pas classées de la plus récente à la plus ancienne'); sys.exit(1)
if tk < vk:
    print(f'ALERTE : pas d\'entrée « {base_version(v)} » dans data/changelog.json (dernière entrée : {top}). Les notes de la publication seront génériques.')
else:
    print(f'OK : version {v}, journal à jour ({top})')
