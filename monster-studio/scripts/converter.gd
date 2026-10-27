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
	DirAccess.make_dir_recursive_absolute(outdir + "/0")      # avec --no-remove-bg, TripoSR ne crée pas ce dossier et échoue à l'écriture de mesh.glb
	var image := ProjectSettings.globalize_path(m.source_path())
	var cmd_tpl := str(cfg.get("command", ""))
	# Détourage et cadrage faits ici (fond uni) : TripoSR reçoit un sujet propre sur gris, sans refaire son propre détourage.
	var prep_msg := ImagePrep.prepare(image, outdir + "/prepared.png")
	if prep_msg == "":
		image = outdir + "/prepared.png"
		if not cmd_tpl.contains("--no-remove-bg"):
			cmd_tpl += " --no-remove-bg"
	var cmd := command_line(cmd_tpl, image, outdir)
	var result_path := str(cfg.get("result", "")).replace("{outdir}", outdir)
	var model_dst := ProjectSettings.globalize_path(m.model_path())
	var bake := ""
	var tex_size := int(cfg.get("texture_size", 2048))
	if tex_size > 0 and FileAccess.file_exists(outdir + "/cut.png"):
		bake = _bake_command(cmd_tpl, result_path, outdir + "/cut.png", model_dst, tex_size)
	_busy = true
	_thread = Thread.new()
	_thread.start(_run.bind(workdir, cmd, result_path, model_dst, bake))

## Commande de cuisson de texture (script Python livré avec Monster Studio, copié sur le disque pour pouvoir être lancé).
func _bake_command(cmd_tpl: String, mesh: String, cut: String, out: String, size: int) -> String:
	var script := ProjectSettings.globalize_path("user://studio/bake_texture.py")
	DirAccess.make_dir_recursive_absolute(script.get_base_dir())
	var src := FileAccess.get_file_as_string("res://tools_py/bake_texture.py")
	if src == "":
		return ""
	var f := FileAccess.open(script, FileAccess.WRITE)
	f.store_string(src)
	f.close()
	var py := cmd_tpl.strip_edges().split(" ")[0]
	return "%s \"%s\" --mesh \"%s\" --cut \"%s\" --out \"%s\" --size %d" % [py, script, mesh, cut, out, size]

func _shell(workdir: String, cmd: String, out: Array) -> int:
	if OS.get_name() == "Windows":
		return OS.execute("cmd", ["/c", "cd /d \"%s\" && %s" % [workdir, cmd]], out, true)
	return OS.execute("sh", ["-c", "cd \"%s\" && %s" % [workdir, cmd]], out, true)

func _run(workdir: String, cmd: String, result_path: String, model_dst: String, bake: String) -> void:
	var out: Array = []
	var code := _shell(workdir, cmd, out)
	var log := "\n".join(PackedStringArray(out.map(func(x): return str(x))))
	var ok := code == 0 and FileAccess.file_exists(result_path)
	var note := ""
	if ok:
		var baked := false
		if bake != "":
			var bout: Array = []
			var bcode := _shell(workdir, bake, bout)
			var blog := "\n".join(PackedStringArray(bout.map(func(x): return str(x))))
			baked = bcode == 0 and FileAccess.file_exists(model_dst) and blog.contains("BAKE: terminé")
			note = " Texture cuite." if baked else " Texture impossible (couleurs par sommet gardées) :\n" + blog.right(900)
		if not baked:
			DirAccess.copy_absolute(result_path, model_dst)
	call_deferred("_done", ok, ("Modèle 3D créé." + note if ok else "Échec (code %d). Sortie :\n%s" % [code, log.right(1500)]))

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
