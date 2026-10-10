#!/usr/bin/env python3
"""Vérificateur des parties classées : rejoue les journaux « submitted » et inscrit le score RECALCULÉ.

Variables d'environnement : SUPABASE_URL, SUPABASE_SECRET_KEY (clé secrète : secret GitHub, jamais dans le dépôt), GODOT (binaire).
Chaque partie est rejouée avec les règles de SA version (étiquette Git v<version>, dans un arbre de travail séparé) : sans cela, un
changement de règles invaliderait les journaux déjà envoyés. Une version sans outil de rejeu est refusée (« version_non_rejouable »).
Usage : python3 tools/verify_runs.py [--limit 20] [--dry-run]"""
import argparse, json, os, re, subprocess, sys, tempfile, urllib.request, urllib.error, datetime, pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from version_util import ROOT, project_version

REPLAY_TIMEOUT = 600


def api(method, path, body=None):
    req = urllib.request.Request(os.environ['SUPABASE_URL'].rstrip('/') + path, method=method,
                                 data=None if body is None else json.dumps(body).encode(),
                                 headers={'apikey': os.environ['SUPABASE_SECRET_KEY'],
                                          'Authorization': 'Bearer ' + os.environ['SUPABASE_SECRET_KEY'],
                                          'Content-Type': 'application/json', 'Prefer': 'return=minimal'})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raise SystemExit(f'Erreur API {e.code} sur {path} : {e.read().decode()[:300]}')


_trees = {}


def tree_for(version):
    """Dossier du projet à la version demandée (None si l'étiquette ou l'outil de rejeu manque)."""
    if version in _trees:
        return _trees[version]
    path = None
    if not re.fullmatch(r'[0-9A-Za-z.\-]{1,20}', version):
        pass
    elif version == project_version():
        path = ROOT
    else:
        d = pathlib.Path(tempfile.mkdtemp(prefix='dg-v')) / version
        if subprocess.run(['git', 'worktree', 'add', '--detach', str(d), 'v' + version], cwd=ROOT, capture_output=True).returncode == 0 \
                and (d / 'tools' / 'replay_run.gd').exists():
            path = d
    if path is not None:
        subprocess.run([os.environ['GODOT'], '--headless', '--path', str(path), '--import'], capture_output=True, timeout=900)
    _trees[version] = path
    return path


def replay(run):
    tree = tree_for(run['game_version'])
    if tree is None:
        return {'ok': False, 'reason': 'version_non_rejouable'}
    with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as f:
        json.dump({'seed': run['seed'], 'params': run['params'], 'log': run['log']}, f)
    try:
        p = subprocess.run(['xvfb-run', '-a', os.environ['GODOT'], '--path', str(tree), '--script', 'res://tools/replay_run.gd', '--', f.name],
                           capture_output=True, text=True, timeout=REPLAY_TIMEOUT)
    except subprocess.TimeoutExpired:
        return {'ok': False, 'reason': 'rejeu_trop_long'}
    finally:
        os.unlink(f.name)
    for line in p.stdout.splitlines():
        if line.startswith('RESULT:'):
            return json.loads(line[7:])
    return {'ok': False, 'reason': 'rejeu_sans_resultat'}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--limit', type=int, default=20)
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    runs = api('GET', f'/rest/v1/ranked_runs?status=eq.submitted&order=submitted_at.asc&limit={a.limit}'
                      '&select=id,seed,params,game_version,log,difficulty') or []
    print(f'{len(runs)} partie(s) à vérifier')
    for run in runs:
        res = replay(run)
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        if res.get('ok'):
            upd = {'status': 'verified', 'score': res['score'], 'seconds': res['seconds'], 'metrics': res['metrics'], 'verified_at': now}
            print(f"{run['id']} : validée, score {res['score']} en {res['seconds']} s")
        else:
            upd = {'status': 'rejected', 'reject_reason': str(res.get('reason', 'inconnue'))[:200], 'verified_at': now}
            print(f"{run['id']} : refusée ({upd['reject_reason']})")
        if not a.dry_run:
            # « status=eq.submitted » : une partie déjà traitée n'est jamais réécrite
            api('PATCH', f"/rest/v1/ranked_runs?id=eq.{run['id']}&status=eq.submitted", upd)
            if upd['status'] == 'verified':
                api('POST', '/rest/v1/rpc/award_run', {'p_run_id': run['id']})     # XP et badges, une seule fois par partie
    if not a.dry_run:
        api('POST', '/rest/v1/rpc/close_due_periods', {})                        # clôture des mois terminés (badges de rang)


if __name__ == '__main__':
    main()
