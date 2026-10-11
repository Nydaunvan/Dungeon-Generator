#!/usr/bin/env python3
"""Analyse VirusTotal des fichiers d'une publication + bandeau (français / anglais) à placer en tête des notes.

Usage : VT_API_KEY=… python3 tools/virustotal.py scan --out vt.json [--merge ancien.json] fichier [fichier…]
Ne fait JAMAIS échouer la publication : en cas de problème (clé absente, réseau, quota), le fichier est simplement marqué
« non analysé » dans le bandeau. Les fichiers de plus de 32 Mo passent par l'adresse d'envoi spéciale de l'API (jusqu'à 650 Mo).
Compte gratuit : 4 requêtes par minute, 500 par jour ; les appels sont donc espacés."""
import hashlib, json, os, pathlib, sys, time, urllib.error, urllib.request, uuid

API = "https://www.virustotal.com/api/v3"
GUI = "https://www.virustotal.com/gui/file/"
SPACING = 16.0            # secondes entre deux appels (4 par minute)
MAX_WAIT = 25 * 60        # attente maximale de l'ensemble des analyses
SMALL = 32 * 1024 * 1024  # limite de l'envoi direct
_last = [0.0]

def _throttle():
    wait = SPACING - (time.time() - _last[0])
    if wait > 0:
        time.sleep(wait)
    _last[0] = time.time()

def _call(method, url, key, data=None, headers=None):
    """Retourne (code HTTP, JSON ou None). Réessaie après une minute en cas de dépassement de quota (429)."""
    for attempt in range(3):
        _throttle()
        req = urllib.request.Request(url, data=data, method=method, headers={"x-apikey": key, **(headers or {})})
        try:
            with urllib.request.urlopen(req, timeout=600) as r:
                body = r.read()
                return r.status, (json.loads(body) if body else None)
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 2:
                time.sleep(60)
                continue
            try:
                return e.code, json.loads(e.read())
            except Exception:
                return e.code, None
        except Exception as e:  # réseau
            print(f"::warning::VirusTotal : {e}")
            return 0, None
    return 429, None

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def _stats(js):
    try:
        a = js["data"]["attributes"]
        s = a.get("last_analysis_stats") or {}
        if sum(s.values()) == 0:
            return None
        return {k: int(s.get(k, 0)) for k in ("malicious", "suspicious", "harmless", "undetected")}
    except Exception:
        return None

def _upload(path, key):
    size = path.stat().st_size
    url = API + "/files"
    if size > SMALL:
        code, js = _call("GET", API + "/files/upload_url", key)
        if code != 200 or not js or "data" not in js:
            return None
        url = js["data"]
    boundary = uuid.uuid4().hex
    head = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
            "Content-Type: application/octet-stream\r\n\r\n").encode()
    body = head + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    code, js = _call("POST", url, key, body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    if code != 200 or not js or "data" not in js:
        return None
    return js["data"].get("id")

def scan(files, key, merge=None):
    entries = {e["name"]: e for e in (merge or {}).get("files", [])}
    pending = []
    for f in files:
        p = pathlib.Path(f)
        if not p.is_file():
            continue
        h = sha256(p)
        e = {"name": p.name, "sha256": h, "size": p.stat().st_size, "url": GUI + h, "status": "error"}
        entries[p.name] = e
        if not key:
            continue
        code, js = _call("GET", f"{API}/files/{h}", key)       # déjà connu de VirusTotal ? on évite un nouvel envoi
        st = _stats(js) if code == 200 else None
        if st:
            e.update(status="done", **st)
            print(f"{p.name} : déjà analysé ({st['malicious']} détection(s))")
            continue
        aid = _upload(p, key)
        if aid:
            e["status"] = "pending"
            e["analysis"] = aid
            pending.append(e)
            print(f"{p.name} : envoyé")
        else:
            print(f"::warning::VirusTotal : envoi impossible pour {p.name}")
    t0 = time.time()
    while pending and time.time() - t0 < MAX_WAIT:
        for e in list(pending):
            code, js = _call("GET", f"{API}/analyses/{e['analysis']}", key)
            if code == 200 and js and js["data"]["attributes"].get("status") == "completed":
                st = _stats({"data": {"attributes": {"last_analysis_stats": js["data"]["attributes"].get("stats", {})}}})
                if st:
                    e.update(status="done", **st)
                    pending.remove(e)
                    print(f"{e['name']} : terminé ({st['malicious']} détection(s))")
        if pending:
            time.sleep(30)
    return {"files": list(entries.values())}

# ------------------------------------------------------------------ bandeau

def _badge(e):
    if e.get("status") == "done":
        det = e["malicious"] + e["suspicious"]
        total = sum(e[k] for k in ("malicious", "suspicious", "harmless", "undetected"))
        color = "brightgreen" if det == 0 else ("orange" if det <= 3 else "red")
        label = f"{det}%2F{total}"
    elif e.get("status") == "pending":
        color, label = "lightgrey", "analyse%20en%20cours"
    else:
        color, label = "lightgrey", "non%20analys%C3%A9"
    return f"[![VirusTotal](https://img.shields.io/badge/VirusTotal-{label}-{color})]({e['url']})"

def banner(data):
    files = (data or {}).get("files") or []
    if not files:
        return ""
    bad = [e for e in files if e.get("status") == "done" and e["malicious"] + e["suspicious"] > 0]
    out = ["## 🛡️ Analyse VirusTotal · VirusTotal scan", "",
           "Les fichiers de cette version ont été soumis à VirusTotal (cliquer sur un badge pour voir le rapport complet).  ",
           "The files of this release were submitted to VirusTotal (click a badge to see the full report).", "",
           "| Fichier · File | Résultat · Result |", "|---|---|"]
    out += [f"| `{e['name']}` | {_badge(e)} |" for e in files]
    if bad:
        out += ["", "> ⚠️ **Avertissement** : au moins un moteur d'analyse signale un fichier (" + ", ".join(f"`{e['name']}`" for e in bad) + "). "
                "Un exécutable non signé produit souvent de faux positifs ; consulte le rapport et ne lance le fichier que si tu as confiance dans la source.  ",
                "> ⚠️ **Warning**: at least one antivirus engine flags a file. Unsigned executables often trigger false positives; check the report "
                "and only run the file if you trust the source."]
    if any(e.get("status") != "done" for e in files):
        out += ["", "> ℹ️ Certaines analyses n'étaient pas terminées à la publication : le badge renvoie au rapport, qui se complète ensuite.  ",
                "> ℹ️ Some scans were not finished at publication time: the badge links to the report, which fills in later."]
    return "\n".join(out) + "\n\n---\n\n"

def main(argv):
    if len(argv) < 2 or argv[1] != "scan":
        print(__doc__)
        return 0
    args, out, merge, files = argv[2:], None, None, []
    i = 0
    while i < len(args):
        if args[i] == "--out":
            out = args[i + 1]; i += 2
        elif args[i] == "--merge":
            merge = args[i + 1]; i += 2
        else:
            files.append(args[i]); i += 1
    old = None
    if merge and os.path.isfile(merge):
        old = json.loads(pathlib.Path(merge).read_text(encoding="utf-8"))
    key = os.environ.get("VT_API_KEY", "").strip()
    if not key:
        print("::warning::VT_API_KEY absent : fichiers marqués « non analysés ».")
    try:
        data = scan(files, key, old)
    except Exception as e:  # ne jamais bloquer la publication
        print(f"::warning::VirusTotal : {e}")
        data = old or {"files": []}
    pathlib.Path(out or "vt.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
