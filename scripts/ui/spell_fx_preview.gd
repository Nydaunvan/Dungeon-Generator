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
	var ico := str(spell.get("icon", ""))
	m.add_text(L.c(str(spell.get("name", ""))) if ico.begins_with("@icon:") else "%s %s" % [ico, L.c(str(spell.get("name", "")))], UiTheme.PARCH, 18)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = VIEW
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stage := Control.new()            # cadre : vue 3D + repères des quatre places du groupe (cibles des soins et des sorts d'allié)
	stage.custom_minimum_size = VIEW
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vp := SubViewport.new()
	vp.size = Vector2i(VIEW)
	vp.own_world_3d = true
	vp.msaa_3d = Settings.msaa_mode()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(svc)
	_add_party_marks(stage)
	m.content.add_child(stage)

	var root := Node3D.new()
	vp.add_child(root)
	var env := WarmUp.make_environment()
	VisualFx.apply_environment(env, "stone", false)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR      # lumière d'ambiance : les mannequins restent lisibles sans écraser les effets
	env.ambient_light_color = Color(0.62, 0.58, 0.54)
	env.ambient_light_energy = 1.6
	env.fog_enabled = false
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
	var fill := OmniLight3D.new()                                     # lampe douce au-dessus du groupe de mannequins
	fill.position = Vector3(0, 2.6, -2.6)
	fill.light_color = Color(1.0, 0.92, 0.8)
	fill.light_energy = 1.4
	fill.omni_range = 9.0
	fill.shadow_enabled = false
	root.add_child(fill)

	# cibles : trois mannequins sombres de 1,7 m (même dictionnaires qu'un monstre en combat) : les effets de groupe les touchent tous
	var target := {"pos": Vector3(0, 0.95, -4.0), "h": 1.7, "w": 1.0}
	var points: Array = [{"pos": Vector3(-1.7, 0.95, -4.3), "h": 1.7, "w": 1.0}, target, {"pos": Vector3(1.7, 0.95, -4.3), "h": 1.7, "w": 1.0}]
	var play := func():
		if not is_instance_valid(root):
			return
		var ctx := SpellFxLibrary.ctx_for(spell)
		ctx["targets"] = points
		ctx["ally"] = 1       # allié visé : deuxième place du groupe ; lanceur : troisième
		ctx["caster"] = 2
		SpellFxLibrary.cast(root, cam, str(spell.get("id", "preview")), target, ctx)
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
	pl.size = Vector2(40, 14)
	floor_mesh.mesh = pl
	floor_mesh.material_override = _stone(Color(0.16, 0.13, 0.11))
	floor_mesh.position = Vector3(0, 0, -5)
	root.add_child(floor_mesh)
	var wall := MeshInstance3D.new()
	var wq := QuadMesh.new()
	wq.size = Vector2(40, 8)
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
	for sx in [-1.7, 1.7]:
		var d2 := MeshInstance3D.new()
		d2.mesh = cap
		d2.material_override = dummy.material_override
		d2.position = Vector3(sx, 0.85, -4.3)
		root.add_child(d2)

## Repères des quatre places du groupe, en bas de la vue (là où les soins et les sorts d'allié se posent).
static func _add_party_marks(stage: Control) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	stage.add_child(row)
	for i in 4:
		var cell := Control.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cell)
		var lab := Label.new()
		lab.text = L.t("admin.spells.apercu_place") % (i + 1)
		lab.add_theme_font_size_override("font_size", 12)
		lab.modulate = Color(1, 1, 1, 0.55 if i == 1 else 0.3)
		lab.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		lab.anchor_top = 0.93
		lab.anchor_bottom = 1.0
		lab.anchor_left = 0.0
		lab.anchor_right = 1.0
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(lab)

static func _stone(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	return m
