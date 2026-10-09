class_name Updater
extends Node
## Mises à jour du jeu (versions Windows et Linux). Source : les publications GitHub du dépôt (API publique, sans clé).
##  1. `check` : lit la liste des publications, retient la plus récente adaptée (préversions seulement si demandé, version
##     ignorée écartée, manifeste de la plateforme présent), puis lit son manifeste et le compare à ce qui est installé :
##     seuls les fichiers modifiés (exécutable, paquet principal, paquets thèmes / monstres / audio) sont à télécharger.
##  2. `download` : télécharge ces fichiers un par un (un fichier déjà téléchargé et valide est réutilisé), vérifie leur SHA-256.
##  3. `install` : écrit un petit script qui, après la fermeture du jeu, recopie les fichiers dans le dossier d'installation puis
##     relance le jeu. Les sauvegardes (user://) ne sont jamais touchées ; elles sont migrées à la lecture.
## État installé : « install.json » (dans le dossier du jeu) = pour chaque fichier, l'empreinte de contenu et la taille. Il est mis à
## jour au lancement qui suit une installation réussie (la version qui tourne prouve que le script a fait son travail).
## La version Web n'est pas concernée (elle se met à jour avec le site), ni l'éditeur Godot.

const REPO := "Nydaunvan/Dungeon-Generator"
const API := "https://api.github.com/repos/%s/releases?per_page=20"
const PREFS := "user://update.cfg"
const DIR := "user://update"
const PENDING := "user://update/pending.json"
const STATE := "install.json"
const SEMVER := "^\\d+\\.\\d+\\.\\d+(-[A-Za-z0-9.]+)?$"

signal check_done(result: Dictionary)           ## {} = rien de nouveau ; {"error": …} ; sinon la publication retenue
signal progress(done: int, total: int)
signal finished(ok: bool, message: String)      ## ok = installation prête : le jeu doit se fermer

var _req: HTTPRequest
var _info: Dictionary = {}
var _queue: Array = []          # fichiers restant à télécharger
var _done_bytes := 0            # octets des fichiers déjà complets
var _total_bytes := 0
var _current: Dictionary = {}

func _ready() -> void:
	set_process(false)

# ------------------------------------------------------------------ préférences

static func pref(key: String, default: Variant) -> Variant:
	var cf := ConfigFile.new()
	if cf.load(PREFS) != OK:
		return default
	return cf.get_value("update", key, default)

static func set_pref(key: String, value: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(PREFS)
	cf.set_value("update", key, value)
	cf.save(PREFS)

# ------------------------------------------------------------------ versions

## « 1.30.1-test1 » → [1, 30, 1, "test1"] ; [] si le format est invalide.
static func parse_version(v: String) -> Array:
	var s := v.strip_edges()
	if s.begins_with("v") or s.begins_with("V"):
		s = s.substr(1)
	if RegEx.create_from_string(SEMVER).search(s) == null:
		return []
	var suffix := ""
	var dash := s.find("-")
	if dash >= 0:
		suffix = s.substr(dash + 1)
		s = s.substr(0, dash)
	var p := s.split(".")
	return [int(p[0]), int(p[1]), int(p[2]), suffix]

## -1, 0 ou 1. À numéro égal, une version de test (suffixe) précède la version finale.
static func compare(a: String, b: String) -> int:
	var pa := parse_version(a)
	var pb := parse_version(b)
	if pa.is_empty() or pb.is_empty():
		return 0
	for i in 3:
		if pa[i] != pb[i]:
			return 1 if pa[i] > pb[i] else -1
	var sa: String = pa[3]
	var sb: String = pb[3]
	if sa == sb:
		return 0
	if sa == "":
		return 1
	if sb == "":
		return -1
	return 1 if sa > sb else -1

static func platform() -> String:
	match OS.get_name():
		"Windows": return "windows"
		"Linux": return "linux"
	return ""

## Le jeu peut-il se remplacer lui-même ici ? (pas dans l'éditeur, pas sur le Web, pas sur une autre plateforme)
static func can_self_update() -> bool:
	return platform() != "" and not OS.has_feature("editor") and not OS.has_feature("web")

## Choisit, parmi les publications GitHub, la plus récente qui apporte du nouveau (voir l'en-tête).
static func pick(releases: Array, current: String, include_pre: bool, plat: String, ignored: String = "") -> Dictionary:
	var best: Dictionary = {}
	for r in releases:
		if not (r is Dictionary) or bool(r.get("draft", false)):
			continue
		if bool(r.get("prerelease", false)) and not include_pre:
			continue
		var v := str(r.get("tag_name", ""))
		if parse_version(v).is_empty():
			continue
		v = v.trim_prefix("v").trim_prefix("V")
		if compare(v, current) <= 0 or v == ignored:
			continue
		if not best.is_empty() and compare(v, str(best.version)) <= 0:
			continue
		var assets := {}
		for a in r.get("assets", []):
			assets[str(a.get("name", ""))] = str(a.get("browser_download_url", ""))
		var manifest := "manifest-%s.json" % plat
		if not assets.has(manifest):
			continue        # publication d'un autre format (anciennes versions) : on ne la propose pas
		best = {"version": v, "name": str(r.get("name", "")), "notes": str(r.get("body", "")), "page": str(r.get("html_url", "")),
			"prerelease": bool(r.get("prerelease", false)), "manifest_url": str(assets[manifest]), "assets": assets}
	return best

## Un fichier du manifeste doit-il être (re)téléchargé ? `state` : entrées de install.json ; `local_size` : -1 si absent ;
## `local_sha` : Callable calculant la somme du fichier local (seulement si l'état ne le connaît pas).
static func needs_download(f: Dictionary, state: Dictionary, local_size: int, local_sha: Callable) -> bool:
	if local_size < 0:
		return true
	var st = state.get(str(f.path))
	if st is Dictionary:
		return str(st.get("content", "")) != str(f.content) or int(st.get("size", -1)) != local_size
	return str(local_sha.call()) != str(f.sha256)

static func build_plan(files: Array, state: Dictionary, base: String) -> Array:
	var plan: Array = []
	for f in files:
		var path := local_path(str(f.path)) if base == install_dir() else base.path_join(str(f.path))
		var size := -1
		if FileAccess.file_exists(path):
			var fa := FileAccess.open(path, FileAccess.READ)
			size = fa.get_length() if fa != null else -1
		if needs_download(f, state, size, func(): return FileAccess.get_sha256(path)):
			plan.append(f)
	return plan

## Chemin de l'exécutable (remplaçable par les tests : jamais le binaire de Godot).
static var exe_override := ""

static func exe_path() -> String:
	return exe_override if exe_override != "" else OS.get_executable_path()

static func install_dir() -> String:
	return exe_path().get_base_dir()

## Chemin local d'un fichier du manifeste. L'exécutable garde son nom actuel (même renommé) et le paquet principal doit porter
## le même nom que lui (c'est ainsi que Godot le retrouve).
static func local_path(rel: String) -> String:
	var exe := exe_path()
	if rel.ends_with(".exe") or rel.ends_with(".x86_64"):
		return exe
	if rel == "Dungeon Generator.pck":
		return exe.get_basename() + ".pck"
	return install_dir().path_join(rel)

static func read_state() -> Dictionary:
	var p := install_dir().path_join(STATE)
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return (d.get("files", {}) as Dictionary) if (d is Dictionary and d.get("files") is Dictionary) else {}

## Le dossier d'installation accepte-t-il l'écriture (sans droits administrateur) ?
static func install_dir_writable() -> bool:
	var t := install_dir().path_join(".write_test")
	var f := FileAccess.open(t, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(t)
	return true

# ------------------------------------------------------------------ 1. vérification

func check(force: bool = false) -> void:
	if not can_self_update() and not force:
		check_done.emit({})
		return
	if not force:
		if not bool(pref("auto_check", true)):
			check_done.emit({})
			return
	_req = HTTPRequest.new()
	_req.timeout = 8.0
	add_child(_req)
	_req.request_completed.connect(_on_list.bind(force))
	if _req.request(API % REPO, PackedStringArray(["User-Agent: DungeonGenerator", "Accept: application/vnd.github+json"])) != OK:
		check_done.emit({"error": "requête"})

func _on_list(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, force: bool) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		check_done.emit({"error": "réseau (%d/%d)" % [result, code]})
		return
	set_pref("last_check", int(Time.get_unix_time_from_system()))
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Array):
		check_done.emit({"error": "réponse"})
		return
	var ignored := "" if force else str(pref("ignored", ""))
	var info := pick(data, AppVersion.number(), bool(pref("include_pre", false)), platform(), ignored)
	if info.is_empty():
		check_done.emit({})
		return
	load_manifest(info)

## Lit le manifeste de la publication retenue et prépare la liste des fichiers à télécharger (émet `check_done`).
func load_manifest(info: Dictionary) -> void:
	_info = info
	var r2 := HTTPRequest.new()
	r2.timeout = 8.0
	add_child(r2)
	r2.request_completed.connect(_on_manifest)
	if r2.request(str(info.manifest_url), PackedStringArray(["User-Agent: DungeonGenerator"])) != OK:
		check_done.emit({"error": "manifeste"})

func _on_manifest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var m = JSON.parse_string(body.get_string_from_utf8()) if (result == HTTPRequest.RESULT_SUCCESS and code == 200) else null
	if not (m is Dictionary) or not (m.get("files") is Array):
		check_done.emit({"error": "manifeste illisible"})
		return
	_info["manifest_files"] = m.files
	var plan := build_plan(m.files, read_state(), install_dir())
	var size := 0
	for f in plan:
		size += int(f.size)
	_info["plan"] = plan
	_info["download_size"] = size
	for f in plan:
		f["url"] = str(_info.assets.get(str(f.asset), ""))
	check_done.emit(_info)

# ------------------------------------------------------------------ 2. téléchargement

func download(info: Dictionary) -> void:
	_info = info
	DirAccess.make_dir_recursive_absolute(DIR)
	_queue = (info.get("plan", []) as Array).duplicate()
	_done_bytes = 0
	_total_bytes = int(info.get("download_size", 0))
	_next()

func _local(f: Dictionary) -> String:
	return ProjectSettings.globalize_path(DIR).path_join(str(f.asset))

func _next() -> void:
	if _queue.is_empty():
		set_process(false)
		_install()
		return
	_current = _queue.pop_front()
	var path := _local(_current)
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == str(_current.sha256):
		_done_bytes += int(_current.size)           # déjà téléchargé et valide (reprise)
		_next()
		return
	_req = HTTPRequest.new()
	_req.download_file = path
	_req.use_threads = true
	_req.timeout = 0.0
	add_child(_req)
	_req.request_completed.connect(_on_downloaded)
	if _req.request(str(_current.url), PackedStringArray(["User-Agent: DungeonGenerator"])) != OK:
		finished.emit(false, "téléchargement")
		return
	set_process(true)

func _process(_d: float) -> void:
	if _req != null and is_instance_valid(_req) and _req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		progress.emit(_done_bytes + _req.get_downloaded_bytes(), _total_bytes)

func cancel() -> void:
	set_process(false)
	_queue.clear()
	if _req != null and is_instance_valid(_req):
		_req.cancel_request()
	if not _current.is_empty():
		DirAccess.remove_absolute(_local(_current))     # fichier partiel ; les fichiers complets sont gardés pour une reprise

func _on_downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	set_process(false)
	var path := _local(_current)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(path)
		finished.emit(false, "téléchargement (%d/%d)" % [result, code])
		return
	if FileAccess.get_sha256(path) != str(_current.sha256):
		DirAccess.remove_absolute(path)
		finished.emit(false, "somme de contrôle incorrecte (%s)" % str(_current.path))
		return
	_done_bytes += int(_current.size)
	_req.queue_free()
	_next()

# ------------------------------------------------------------------ 3. installation

func _install() -> void:
	if not install_dir_writable():
		finished.emit(false, "dossier d'installation protégé en écriture")
		return
	var pairs: Array = []     # [source téléchargée, destination], paquets d'abord, exécutable en dernier
	var exe_changed := false
	for f in _info.plan:
		var dst := local_path(str(f.path))
		if str(f.path).ends_with(".exe") or str(f.path).ends_with(".x86_64"):
			exe_changed = true
		pairs.append([_local(f), dst])
	pairs.sort_custom(func(a, b): return _rank(str(a[1])) < _rank(str(b[1])))
	var exe := exe_path()
	var err := ""
	match platform():
		"windows": err = _install_windows(pairs, exe)
		"linux": err = _install_linux(pairs, exe)
		_: err = "plateforme"
	if err != "":
		finished.emit(false, err)
		return
	_write_pending(exe_changed)
	finished.emit(true, "")

static func _rank(dst: String) -> int:
	if dst.ends_with(".exe") or dst.ends_with(".x86_64"):
		return 2
	return 1 if dst.ends_with("Dungeon Generator.pck") else 0

## État à enregistrer une fois la mise à jour appliquée (promu au lancement suivant si la version qui tourne est la bonne).
func _write_pending(_exe_changed: bool) -> void:
	var state := read_state()
	for f in _info.get("manifest_files", _info.get("plan", [])):
		state[str(f.path)] = {"content": str(f.content), "size": int(f.size)}
	var f2 := FileAccess.open(PENDING, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(JSON.stringify({"version": str(_info.version), "files": state}))

## Script de remplacement Windows (VBScript lancé par wscript : aucune fenêtre, contrairement à cmd). Il attend que le jeu soit
## fermé (la copie échoue tant qu'un fichier est verrouillé), recopie tous les fichiers, relance le jeu et s'efface.
static func windows_script(pairs: Array, exe: String) -> String:
	var e := exe.replace("/", "\\")
	var lines := [
		"Dim fso, sh, i, ok",
		"Set fso = CreateObject(\"Scripting.FileSystemObject\")",
		"Set sh = CreateObject(\"WScript.Shell\")",
		"ok = False",
		"For i = 1 To 60",
		"  WScript.Sleep 500",
		"  ok = True",
		"  On Error Resume Next"]
	for p in pairs:
		lines.append("  fso.CopyFile \"%s\", \"%s\", True" % [str(p[0]).replace("/", "\\"), str(p[1]).replace("/", "\\")])
		lines.append("  If Err.Number <> 0 Then ok = False")
		lines.append("  Err.Clear")
	lines.append_array([
		"  On Error GoTo 0",
		"  If ok Then Exit For",
		"Next",
		"If ok Then",
		"  sh.CurrentDirectory = fso.GetParentFolderName(\"%s\")" % e,
		"  sh.Run Chr(34) & \"%s\" & Chr(34), 1, False" % e,
		"End If",
		"On Error Resume Next",
		"fso.DeleteFile WScript.ScriptFullName, True",
		""])
	return "\r\n".join(lines)

## Octets d'un script VBS : UTF-16 avec marque d'ordre des octets (les chemins avec accents restent corrects).
static func vbs_bytes(text: String) -> PackedByteArray:
	var b := PackedByteArray([0xFF, 0xFE])
	b.append_array(text.to_utf16_buffer())
	return b

static func linux_script(pairs: Array, exe: String) -> String:
	var out := "#!/bin/sh\nsleep 1\ni=0\nwhile true; do\n  ok=1\n"
	for p in pairs:
		out += "  mkdir -p '%s' && cp -f '%s' '%s' || ok=0\n" % [str(p[1]).get_base_dir(), str(p[0]), str(p[1])]
	out += "  [ $ok = 1 ] && break\n  i=$((i+1))\n  [ $i -ge 30 ] && exit 1\n  sleep 1\ndone\nchmod +x '%s'\nnohup '%s' >/dev/null 2>&1 &\nrm -- \"$0\"\n" % [exe, exe]
	return out

func _install_windows(pairs: Array, exe: String) -> String:
	var vbs := ProjectSettings.globalize_path(DIR) + "/apply.vbs"
	var bf := FileAccess.open(vbs, FileAccess.WRITE)
	if bf == null:
		return "script"
	bf.store_buffer(vbs_bytes(windows_script(pairs, exe)))
	bf.close()
	# wscript //B : pas de fenêtre ni de boîte de dialogue ; le script attend la fermeture du jeu
	if OS.create_process("wscript.exe", ["//B", "//Nologo", vbs.replace("/", "\\")]) < 0:
		return "lancement du script"
	return ""

func _install_linux(pairs: Array, exe: String) -> String:
	var sh := ProjectSettings.globalize_path(DIR) + "/apply.sh"
	var sf := FileAccess.open(sh, FileAccess.WRITE)
	if sf == null:
		return "script"
	sf.store_string(linux_script(pairs, exe))
	sf.close()
	OS.execute("chmod", ["+x", sh])
	OS.create_process("/bin/sh", [sh])
	return ""

## Au lancement : si une mise à jour vient d'être appliquée (la version qui tourne est celle de « pending.json »), l'état installé
## est mis à jour ; puis les fichiers téléchargés sont supprimés.
static func cleanup() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	if FileAccess.file_exists(PENDING):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PENDING))
		if d is Dictionary and str(d.get("version", "")) == AppVersion.number():
			var f := FileAccess.open(install_dir().path_join(STATE), FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify({"version": AppVersion.number(), "files": d.get("files", {})}, " "))
		DirAccess.remove_absolute(PENDING)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".pck") or f.ends_with(".exe") or f.ends_with(".x86_64") or f.ends_with(".zip") or f.ends_with(".tar.gz"):
			DirAccess.remove_absolute(dir + "/" + f)
