#!/usr/bin/env python3
"""Contrôle des fichiers de langue : mêmes clés dans fr.json et en.json, et toute clé citée dans le code existe.
Usage : python3 tools/check_lang.py  (code de sortie 1 en cas d'écart)."""
import json, re, glob, sys
fr = json.load(open('data/lang/fr.json')); en = json.load(open('data/lang/en.json'))
bad = 0
for sec in ('ui', 'content'):
    a, b = set(fr[sec]), set(en[sec])
    for k in sorted(a ^ b):
        print('clé non partagée', sec, k, '(fr)' if k in a else '(en)'); bad += 1
for sec in ('ui', 'content'):
    for k, v in en[sec].items():
        if v == '' : print('EN vide', k); bad += 1
        f = fr[sec].get(k, '')
        if (v.count('%s'), v.count('%d'), sorted(re.findall(r'\{\w+\}', v))) != (f.count('%s'), f.count('%d'), sorted(re.findall(r'\{\w+\}', f))):
            print('variables différentes', k); bad += 1
pat = re.compile(r'"((?:admin|ui|rules|game|core|main|home|common)\.[a-z0-9_.]+)"')
for fn in glob.glob('scripts/**/*.gd', recursive=True):
    if fn.endswith(('lang_translation.gd', 'l.gd')): continue
    for i, l in enumerate(open(fn), 1):
        for m in pat.finditer(l):
            if m.group(1) not in fr['ui']:
                print('clé absente', fn, i, m.group(1)); bad += 1
# Énigmes des pièges : chaque numéro jusqu'à COUNT doit avoir sa question et ses quatre réponses, avec la bonne en « a »
m = re.search(r'const COUNT := (\d+)', open('scripts/ui/trap_puzzle_riddle.gd').read())
for n in range(1, int(m.group(1)) + 1):
    for lang, d in (('fr', fr), ('en', en)):
        ks = ['ui.trap_puzzle.riddle_%d_%s' % (n, s) for s in 'qabcd']
        miss = [k for k in ks if k not in d['ui']]
        if miss:
            print('énigme incomplète', lang, n, miss); bad += 1
        elif len({d['ui'][k] for k in ks[1:]}) < 4:
            print('énigme : réponses en double', lang, n); bad += 1
print('OK' if not bad else f'{bad} écart(s)')
sys.exit(1 if bad else 0)
