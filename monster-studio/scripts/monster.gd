class_name Monster
extends RefCounted
## Un monstre de la bibliothèque : image source, modèle 3D, squelette (rig) et animations modifiées.
## Dossier : user://studio/<slug>/  (source.png, model.glb, rig.json)

var slug := ""
var title := ""
var rig: Dictionary = {}            ## {template, bones:[{name,parent,role,pos:[x,y,z]}], weights_done}
var orient := Vector3.ZERO          ## orientation du modèle importé (degrés, multiples de 90) : redresse un modèle couché ou de dos
var anim_keys: Dictionary = {}      ## clés ajoutées à la main : {anim: {bone: [[t, [x,y,z] degrés], …]}}

func dir() -> String:
	return Library.ROOT + "/" + slug

func source_path() -> String:
	return dir() + "/source.png"

func model_path() -> String:
	return dir() + "/model.glb"

func has_source() -> bool:
	return FileAccess.file_exists(source_path())

func has_model() -> bool:
	return FileAccess.file_exists(model_path())

func has_rig() -> bool:
	return not (rig.get("bones", []) as Array).is_empty()

func save() -> void:
	DirAccess.make_dir_recursive_absolute(dir())
	var f := FileAccess.open(dir() + "/rig.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"title": title, "rig": rig, "anim_keys": anim_keys, "orient": [orient.x, orient.y, orient.z]}, "\t"))
	f.close()

func load_meta() -> void:
	var p := dir() + "/rig.json"
	if not FileAccess.file_exists(p):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if d is Dictionary:
		title = str(d.get("title", title))
		rig = d.get("rig", {})
		anim_keys = d.get("anim_keys", {})
		var o: Variant = d.get("orient", [0, 0, 0])
		if o is Array and (o as Array).size() == 3:
			orient = Vector3(float(o[0]), float(o[1]), float(o[2]))
