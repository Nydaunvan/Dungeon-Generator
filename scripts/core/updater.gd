class_name Updater
extends Node
## Mises à jour du jeu (versions Windows et Linux). Source : les publications GitHub du dépôt (API publique, sans clé).
##  1. `check` : lit la liste des publications, retient la plus récente adaptée (préversions seulement si demandé, version
##     ignorée écartée, archive de la plateforme présente) et la compare à `config/version`.
##  2. `download` : télécharge l'archive, vérifie sa somme SHA-256 (fichier SHA256SUMS.txt de la publication, s'il existe).
##  3. `install` : extrait le nouvel exécutable à côté de l'ancien, écrit un petit script qui le met en place après la
##     fermeture du jeu puis le relance. Les sauvegardes (user://) ne sont jamais touchées ; elles sont migrées à la lecture.
## La version Web n'est pas concernée (elle se met à jour avec le site), ni l'éditeur Godot.

const REPO := "Nydaunvan/Dungeon-Generator"
const API := "https://api.github.com/repos/%s/releases?per_page=20"
const PREFS := "user://update.cfg"
const DIR := "user://update"
const CHECK_EVERY := 86400            # au plus une vérification automatique par jour
const SUMS_NAME := "SHA256SUMS.txt"
const SEMVER := "^\\d+\\.\\d+\\.\\d+(-[A-Za-z0-9.]+)?$"

signal check_done(result: Dictionary)           ## {} = rien de nouveau ; {"error": …} ; sinon la publication retenue
signal progress(done: int, total: int)
signal finished(ok: bool, message: String)      ## ok = installation prête : le jeu doit se fermer

var _req: HTTPRequest
var _total_hint := 0
var _file := ""
var _info: Dictionary = {}

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

static func _asset_suffix(plat: String) -> String:
	return "-windows.zip" if plat == "windows" else "-linux.tar.gz"

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
		var asset: Dictionary = {}
		var sums := ""
		for a in r.get("assets", []):
			var n := str(a.get("name", ""))
			if n.ends_with(_asset_suffix(plat)):
				asset = a
			elif n == SUMS_NAME:
				sums = str(a.get("browser_download_url", ""))
		if asset.is_empty():
			continue
		best = {"version": v, "name": str(r.get("name", "")), "notes": str(r.get("body", "")), "page": str(r.get("html_url", "")),
			"prerelease": bool(r.get("prerelease", false)), "asset": str(asset.get("name", "")),
			"url": str(asset.get("browser_download_url", "")), "size": int(asset.get("size", 0)), "sums_url": sums}
	return best

## Somme attendue pour `name` dans un fichier « sha256  nom » (format de sha256sum).
static func expected_sum(sums_text: String, name: String) -> String:
	for line in sums_text.split("\n"):
		var parts := line.strip_edges().split(" ", false)
		if parts.size() >= 2 and parts[parts.size() - 1].trim_prefix("*") == name:
			return parts[0].to_lower()
	return ""

# ------------------------------------------------------------------ 1. vérification

func check(force: bool = false) -> void:
	if not can_self_update() and not force:
		check_done.emit({})
		return
	if not force:
		if not bool(pref("auto_check", true)) or int(Time.get_unix_time_from_system()) - int(pref("last_check", 0)) < CHECK_EVERY:
			check_done.emit({})
			return
	_req = HTTPRequest.new()
	_req.timeout = 12.0
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
	check_done.emit(pick(data, AppVersion.number(), bool(pref("include_pre", false)), platform(), ignored))

# ------------------------------------------------------------------ 2. téléchargement

func download(info: Dictionary) -> void:
	_info = info
	DirAccess.make_dir_recursive_absolute(DIR)
	_file = ProjectSettings.globalize_path(DIR) + "/" + str(info.asset)
	_total_hint = int(info.size)
	_req = HTTPRequest.new()
	_req.download_file = _file
	_req.use_threads = true
	_req.timeout = 0.0
	add_child(_req)
	_req.request_completed.connect(_on_downloaded)
	if _req.request(str(info.url), PackedStringArray(["User-Agent: DungeonGenerator"])) != OK:
		finished.emit(false, "téléchargement")
		return
	set_process(true)

func _process(_d: float) -> void:
	if _req != null and is_instance_valid(_req) and _req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		var total := _req.get_body_size()
		progress.emit(_req.get_downloaded_bytes(), total if total > 0 else _total_hint)

func cancel() -> void:
	if _req != null and is_instance_valid(_req):
		_req.cancel_request()
	set_process(false)
	DirAccess.remove_absolute(_file)

func _on_downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	set_process(false)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		finished.emit(false, "téléchargement (%d/%d)" % [result, code])
		return
	var sums_url := str(_info.get("sums_url", ""))
	if sums_url == "":
		_install()
		return
	var r2 := HTTPRequest.new()
	add_child(r2)
	r2.request_completed.connect(func(res: int, c: int, _hh, body: PackedByteArray):
		if res != HTTPRequest.RESULT_SUCCESS or c != 200:
			finished.emit(false, "somme de contrôle")
			return
		var want := expected_sum(body.get_string_from_utf8(), str(_info.asset))
		if want != "" and FileAccess.get_sha256(_file) != want:
			DirAccess.remove_absolute(_file)
			finished.emit(false, "somme de contrôle incorrecte")
			return
		_install())
	r2.request(sums_url, PackedStringArray(["User-Agent: DungeonGenerator"]))

# ------------------------------------------------------------------ 3. installation

func _install() -> void:
	var exe := OS.get_executable_path()
	var err := ""
	match platform():
		"windows": err = _install_windows(exe)
		"linux": err = _install_linux(exe)
		_: err = "plateforme"
	if err != "":
		finished.emit(false, err)
	else:
		finished.emit(true, "")

## Écrit un script de remplacement : attend que le jeu soit fermé, met le nouvel exécutable en place, le relance.
static func windows_script(new_exe: String, exe: String) -> String:
	var n := new_exe.replace("/", "\\")
	var e := exe.replace("/", "\\")
	return "@echo off\r\nset N=0\r\n:wait\r\nping 127.0.0.1 -n 2 >nul\r\nset /a N+=1\r\nmove /Y \"%s\" \"%s\" >nul 2>&1\r\nif errorlevel 1 (\r\n  if %%N%% LSS 30 goto wait\r\n  exit /b 1\r\n)\r\nstart \"\" \"%s\"\r\n(goto) 2>nul & del \"%%~f0\"\r\n" % [n, e, e]

static func linux_script(new_exe: String, exe: String) -> String:
	return "#!/bin/sh\nsleep 1\ni=0\nwhile ! mv -f '%s' '%s' 2>/dev/null; do\n  i=$((i+1))\n  [ $i -ge 30 ] && exit 1\n  sleep 1\ndone\nchmod +x '%s'\nnohup '%s' >/dev/null 2>&1 &\nrm -- \"$0\"\n" % [new_exe, exe, exe, exe]

func _install_windows(exe: String) -> String:
	var zr := ZIPReader.new()
	if zr.open(_file) != OK:
		return "archive illisible"
	var entry := ""
	for f in zr.get_files():
		if f.to_lower().ends_with(".exe"):
			entry = f
			break
	if entry == "":
		zr.close()
		return "exécutable absent de l'archive"
	var bytes := zr.read_file(entry)
	zr.close()
	var new_exe := exe + ".new"
	var f := FileAccess.open(new_exe, FileAccess.WRITE)
	if f == null:
		return "dossier d'installation protégé en écriture"
	f.store_buffer(bytes)
	f.close()
	var bat := ProjectSettings.globalize_path(DIR) + "/apply.bat"
	var bf := FileAccess.open(bat, FileAccess.WRITE)
	if bf == null:
		return "script"
	bf.store_string(windows_script(new_exe, exe))
	bf.close()
	OS.create_process("cmd.exe", ["/c", "start", "", "/min", bat.replace("/", "\\")])
	return ""

func _install_linux(exe: String) -> String:
	var out_dir := ProjectSettings.globalize_path(DIR) + "/x"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var o := []
	if OS.execute("tar", ["-xzf", _file, "-C", out_dir], o) != 0:
		return "extraction"
	var found := ""
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".x86_64"):
			found = out_dir + "/" + f
	if found == "":
		return "exécutable absent de l'archive"
	var new_exe := exe + ".new"
	if DirAccess.copy_absolute(found, new_exe) != OK:
		return "dossier d'installation protégé en écriture"
	OS.execute("chmod", ["+x", new_exe])
	var sh := ProjectSettings.globalize_path(DIR) + "/apply.sh"
	var sf := FileAccess.open(sh, FileAccess.WRITE)
	if sf == null:
		return "script"
	sf.store_string(linux_script(new_exe, exe))
	sf.close()
	OS.execute("chmod", ["+x", sh])
	OS.create_process("/bin/sh", [sh])
	return ""

## Nettoyage au lancement : archive téléchargée et fichiers temporaires de la mise à jour précédente.
static func cleanup() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	if not DirAccess.dir_exists_absolute(dir):
		return
	var x := dir + "/x"
	if DirAccess.dir_exists_absolute(x):
		for f in DirAccess.get_files_at(x):
			DirAccess.remove_absolute(x + "/" + f)
		DirAccess.remove_absolute(x)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".zip") or f.ends_with(".tar.gz"):
			DirAccess.remove_absolute(dir + "/" + f)
