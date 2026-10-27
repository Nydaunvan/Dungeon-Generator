class_name Converter
extends Node
## Conversion image 2D → modèle 3D. Trois sources :
##  - « ia »   : une commande externe configurable (par défaut TripoSR, modèle open source qui tourne en local), lancée en tâche de fond ;
##  - « glb »  : un .glb déjà fait (autre outil, service en ligne…), simplement copié ;
##  - « test » : une silhouette simple, pour essayer la suite sans IA.

signal finished(ok: bool, message: String)

var _thread: Thread
var _busy := false

func is_busy() -> bool:
	return _busy

static func command_line(tpl: String, image: String, outdir: String) -> String:
	return tpl.replace("{image}", image).replace("{outdir}", outdir)

func start_ai(m: Monster, cfg: Dictionary) -> void:
	if _busy:
		return
	if not m.has_source():
		finished.emit(false, "Pas d'image source pour ce monstre.")
		return
	var workdir := str(cfg.get("workdir", "")).strip_edges()
	if workdir == "" or not DirAccess.dir_exists_absolute(workdir):
		finished.emit(false, "Le dossier du modèle d'IA n'est pas réglé (Réglages → dossier TripoSR).")
		return
	var outdir := ProjectSettings.globalize_path(m.dir() + "/ia_out")
	DirAccess.make_dir_recursive_absolute(outdir)
	var image := ProjectSettings.globalize_path(m.source_path())
	var cmd := command_line(str(cfg.get("command", "")), image, outdir)
	var result_path := str(cfg.get("result", "")).replace("{outdir}", outdir)
	var model_dst := ProjectSettings.globalize_path(m.model_path())
	_busy = true
	_thread = Thread.new()
	_thread.start(_run.bind(workdir, cmd, result_path, model_dst))

func _run(workdir: String, cmd: String, result_path: String, model_dst: String) -> void:
	var out: Array = []
	var code := -1
	if OS.get_name() == "Windows":
		code = OS.execute("cmd", ["/c", "cd /d \"%s\" && %s" % [workdir, cmd]], out, true)
	else:
		code = OS.execute("sh", ["-c", "cd \"%s\" && %s" % [workdir, cmd]], out, true)
	var log := "\n".join(PackedStringArray(out.map(func(x): return str(x))))
	var ok := code == 0 and FileAccess.file_exists(result_path)
	if ok:
		DirAccess.copy_absolute(result_path, model_dst)
	call_deferred("_done", ok, ("Modèle 3D créé." if ok else "Échec (code %d). Sortie :\n%s" % [code, log.right(1500)]))

func _done(ok: bool, msg: String) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	_busy = false
	finished.emit(ok, msg)

func use_glb(m: Monster, path: String) -> bool:
	var ok := DirAccess.copy_absolute(path, ProjectSettings.globalize_path(m.model_path())) == OK
	finished.emit(ok, "Modèle importé." if ok else "Copie impossible.")
	return ok

func use_test(m: Monster, kind: String) -> bool:
	DirAccess.make_dir_recursive_absolute(m.dir())
	var ok := TestShapes.write(kind, m.model_path()) != ""
	finished.emit(ok, "Silhouette de test créée." if ok else "Création impossible.")
	return ok

func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
