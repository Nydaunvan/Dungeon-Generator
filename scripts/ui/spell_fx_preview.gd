class_name SpellFxPreview
extends RefCounted
## Aperçu d'un effet de sort dans l'éditeur : une petite scène 3D (couloir sombre, mannequin à quelques pas) où l'effet du sort
## est joué en boucle avec les réglages graphiques actuels. Le sort est relu à chaque lancer : on peut garder la fenêtre ouverte,
## modifier le sort dans l'éditeur, puis rejouer.

const VIEW := Vector2(560, 320)
const LOOP_SECONDS := 2.6

static func open(host: Node, spell: Dictionary) -> void:
	var m := Modal.open(host, L.t("admin.spells.apercu_titre"), 640.0)
	if not VisualFx.is_forward():
		m.add_text(L.t("admin.spells.apercu_indispo"), UiTheme.PARCH, 15)
		m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): m.close()}])
		return
	m.add_text("%s %s" % [str(spell.get("icon", "")), L.c(str(spell.get("name", "")))], UiTheme.PARCH, 18)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = VIEW
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vp := SubViewport.new()
	vp.size = Vector2i(VIEW)
	vp.own_world_3d = true
	vp.msaa_3d = Settings.msaa_mode()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	m.content.add_child(svc)

	var root := Node3D.new()
	vp.add_child(root)
	var env := WarmUp.make_environment()
	VisualFx.apply_environment(env, "stone", false)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.1
	cam.far = 100.0
	cam.position = Vector3(0, 0.9, 0)
	root.add_child(cam)
	cam.current = true
	_build_set(root)

	# cible : mannequin sombre à 4 m, de 1,7 m de haut (même dictionnaire que celui d'un monstre en combat)
	var target := {"pos": Vector3(0, 0.95, -4.0), "h": 1.7, "w": 1.0}
	var play := func():
		if not is_instance_valid(root):
			return
		SpellFxLibrary.cast(root, cam, str(spell.get("id", "preview")), target, SpellFxLibrary.ctx_for(spell))
	var timer := Timer.new()
	timer.wait_time = LOOP_SECONDS
	timer.autostart = true
	timer.timeout.connect(play)
	m.add_child(timer)
	m.get_tree().create_timer(0.4).timeout.connect(play)
	m.set_buttons([
		{"text": L.t("admin.spells.apercu_rejouer"), "cb": play},
		{"text": L.t("common.fermer"), "cb": func(): m.close()},
	], true)

## Décor minimal : sol et fond de pierre sombre, mannequin.
static func _build_set(root: Node3D) -> void:
	var floor_mesh := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(14, 14)
	floor_mesh.mesh = pl
	floor_mesh.material_override = _stone(Color(0.16, 0.13, 0.11))
	floor_mesh.position = Vector3(0, 0, -5)
	root.add_child(floor_mesh)
	var wall := MeshInstance3D.new()
	var wq := QuadMesh.new()
	wq.size = Vector2(14, 6)
	wall.mesh = wq
	wall.material_override = _stone(Color(0.20, 0.17, 0.14))
	wall.position = Vector3(0, 3, -8)
	root.add_child(wall)
	var dummy := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.38
	cap.height = 1.7
	dummy.mesh = cap
	dummy.material_override = _stone(Color(0.32, 0.28, 0.25))
	dummy.position = Vector3(0, 0.85, -4.0)
	root.add_child(dummy)

static func _stone(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	return m
