extends Control
## Monster Studio — fenêtre principale. Tout est construit en code (comme le jeu).
## Chaîne : image 2D → modèle 3D → squelette → poids de peau → animations → export .glb.

const ROLES := ["root", "spine", "head", "tail", "arm_l", "arm_r", "leg_l", "leg_r", "wing_l", "wing_r"]
const BG := Color("1b1611")
const GOLD := Color("e8b45c")
const DIM := Color("a89a80")

var cfg: Dictionary = {}
var monsters: Array[Monster] = []
var cur: Monster = null
var model: Dictionary = {}
var weights: Array = []
var sel_bone := -1
var _busy := false

var viewer: StudioViewer
var converter: Converter
var list: ItemList
var tabs: TabContainer
var status: Label
var src_preview: TextureRect
var log_label: Label
var source_opt: OptionButton
var tpl_opt: OptionButton
var sym_check: CheckBox
var bone_list: ItemList
var bone_name: LineEdit
var bone_role: OptionButton
var pos_sliders: Array[HSlider] = []
var skin_label: Label
var anim_list: ItemList
var anim_bone_opt: OptionButton
var rot_sliders: Array[HSlider] = []
var time_slider: HSlider
var speed_slider: HSlider
var export_dir_edit: LineEdit
var _updating := false
var _cur_anim := "idle"
var _import_dialog: FileDialog
var _glb_dialog: FileDialog
var _dir_dialog: FileDialog
var _workdir_dialog: FileDialog
var _settings_pop: AcceptDialog
var _cmd_edit: LineEdit
var _workdir_edit: LineEdit
var _result_edit: LineEdit

func _ready() -> void:
	cfg = StudioSettings.load_all()
	converter = Converter.new()
	add_child(converter)
	converter.finished.connect(_on_converted)
	_build_ui()
	get_window().files_dropped.connect(_on_files_dropped)
	_reload_list()

# ------------------------------------------------------------------ interface

func _lbl(t: String, size := 14, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	return b

func _slider(lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(0, 22)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb)
	return s

func _row(label: String, w: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := _lbl(label, 13, DIM)
	l.custom_minimum_size = Vector2(70, 0)
	h.add_child(l)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(w)
	return h

func _tab_box(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 10)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(v)
	sc.add_child(m)
	tabs.add_child(sc)
	return v

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	# --- colonne de gauche : bibliothèque
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(230, 0)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	left.add_child(_lbl("MONSTER STUDIO", 20, GOLD))
	left.add_child(_lbl("Images 2D → 3D → squelette → animations", 12, DIM))
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.icon_mode = ItemList.ICON_MODE_LEFT
	list.fixed_icon_size = Vector2i(44, 44)
	list.item_selected.connect(_on_list_selected)
	left.add_child(list)
	left.add_child(_btn("📥 Importer des images 2D…", func(): _import_dialog.popup_centered_ratio(0.7)))
	left.add_child(_btn("🗑 Supprimer le monstre", _delete_current))
	left.add_child(_btn("⚙ Réglages (modèle d'IA, export)", func(): _open_settings()))
	left.add_child(_lbl("Astuce : glissez des images (ou des .glb) sur la fenêtre pour les importer.", 11, DIM))
	# --- centre : 3D
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	viewer = StudioViewer.new()
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer.gui_input.connect(_on_viewer_input)
	mid.add_child(viewer)
	var bar := HBoxContainer.new()
	var cb := CheckBox.new()
	cb.text = "Afficher le squelette"
	cb.button_pressed = true
	cb.toggled.connect(func(on: bool):
		viewer.show_bones = on
		viewer._redraw())
	bar.add_child(cb)
	bar.add_child(_btn("Recentrer la vue", func(): viewer.frame_model()))
	status = _lbl("Importez une image pour commencer.", 13, DIM)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(status)
	mid.add_child(bar)
	# --- droite : étapes
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(440, 0)
	root.add_child(tabs)
	_build_tab_model()
	_build_tab_skeleton()
	_build_tab_anim()
	_build_tab_export()
	tabs.tab_changed.connect(_on_tab_changed)
	# --- fenêtres de fichiers
	_import_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILES, ["*.png,*.webp,*.jpg,*.jpeg,*.glb ; Images 2D et modèles .glb"])
	_import_dialog.files_selected.connect(func(p: PackedStringArray): import_paths(Array(p)))
	_glb_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.glb,*.gltf ; Modèles 3D"])
	_glb_dialog.file_selected.connect(func(p: String): if cur != null: converter.use_glb(cur, p))
	_dir_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_DIR, [])
	_dir_dialog.dir_selected.connect(func(p: String):
		cfg.export_dir = p
		export_dir_edit.text = p
		StudioSettings.save_all(cfg))
	_workdir_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_DIR, [])
	_workdir_dialog.dir_selected.connect(func(p: String):
		_workdir_edit.text = p)

func _file_dialog(mode: int, filters: Array) -> FileDialog:
	var d := FileDialog.new()
	d.file_mode = mode as FileDialog.FileMode
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.use_native_dialog = true
	d.filters = PackedStringArray(filters)
	add_child(d)
	return d

func _build_tab_model() -> void:
	var v := _tab_box("1 Modèle")
	v.add_child(_lbl("Image source", 14, GOLD))
	src_preview = TextureRect.new()
	src_preview.custom_minimum_size = Vector2(0, 200)
	src_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	src_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(src_preview)
	v.add_child(_lbl("Source du modèle 3D", 14, GOLD))
	source_opt = OptionButton.new()
	source_opt.add_item("IA locale (commande des Réglages, TripoSR par défaut)")
	source_opt.add_item("Importer un fichier .glb existant…")
	source_opt.add_item("Silhouette de test : bipède")
	source_opt.add_item("Silhouette de test : quadrupède")
	source_opt.add_item("Silhouette de test : serpent")
	v.add_child(source_opt)
	v.add_child(_btn("✨ Créer le modèle 3D", _on_create_model))
	log_label = _lbl("", 12, DIM)
	v.add_child(log_label)
	v.add_child(_lbl("Orientation du modèle (si l'IA l'a produit couché ou de dos : la façade doit regarder vers l'avant, +Z)", 12, DIM))
	var oh := HBoxContainer.new()
	oh.add_child(_btn("↻ X 90°", func(): _turn(Vector3(90, 0, 0))))
	oh.add_child(_btn("↻ Y 90°", func(): _turn(Vector3(0, 90, 0))))
	oh.add_child(_btn("↻ Z 90°", func(): _turn(Vector3(0, 0, 90))))
	oh.add_child(_btn("⟲ Demi-tour", func(): _turn(Vector3(0, 180, 0))))
	v.add_child(oh)
	v.add_child(_lbl("L'IA tourne sur votre PC (carte graphique NVIDIA conseillée) : la conversion prend de quelques secondes à quelques minutes. Le résultat est normalisé : centré, pieds au sol, hauteur 2.", 12, DIM))

func _build_tab_skeleton() -> void:
	var v := _tab_box("2 Squelette")
	v.add_child(_lbl("Gabarit de départ", 14, GOLD))
	tpl_opt = OptionButton.new()
	for id in SkeletonTemplates.IDS:
		tpl_opt.add_item(SkeletonTemplates.label(id))
	v.add_child(tpl_opt)
	v.add_child(_btn("🦴 Placer le squelette du gabarit", func(): place_skeleton(SkeletonTemplates.IDS[tpl_opt.selected])))
	v.add_child(_lbl("Ajustez ensuite chaque os : cliquez sur une articulation dans la vue 3D ou choisissez-la dans la liste, puis déplacez-la avec les curseurs.", 12, DIM))
	sym_check = CheckBox.new()
	sym_check.text = "Symétrie gauche / droite"
	sym_check.button_pressed = true
	v.add_child(sym_check)
	bone_list = ItemList.new()
	bone_list.custom_minimum_size = Vector2(0, 170)
	bone_list.item_selected.connect(func(i: int): _select_bone(i))
	v.add_child(bone_list)
	bone_name = LineEdit.new()
	bone_name.text_submitted.connect(_rename_bone)
	v.add_child(_row("Nom", bone_name))
	bone_role = OptionButton.new()
	for r in ROLES:
		bone_role.add_item(r)
	bone_role.item_selected.connect(func(i: int):
		if _updating or sel_bone < 0:
			return
		_bones()[sel_bone].role = ROLES[i]
		_bones_changed())
	v.add_child(_row("Rôle", bone_role))
	for ax in 3:
		var s := _slider(-2.0 if ax != 1 else -0.3, 2.0 if ax != 1 else 2.5, 0.005, _on_pos_slider.bind(ax))
		pos_sliders.append(s)
		v.add_child(_row(["X (gauche)", "Y (haut)", "Z (avant)"][ax], s))
	var h := HBoxContainer.new()
	h.add_child(_btn("+ Os enfant", _add_bone))
	h.add_child(_btn("− Supprimer l'os", _remove_bone))
	v.add_child(h)
	v.add_child(_btn("🧬 Calculer la peau (poids)", func(): await compute_skin()))
	skin_label = _lbl("Peau : à calculer.", 12, DIM)
	v.add_child(skin_label)
	v.add_child(_lbl("Les rôles pilotent les animations : bras/pattes avant (arm), jambes/pattes arrière (leg), colonne (spine), tête, queue, ailes. L'os « root » est le pivot du corps.", 12, DIM))

func _build_tab_anim() -> void:
	var v := _tab_box("3 Animation")
	anim_list = ItemList.new()
	anim_list.custom_minimum_size = Vector2(0, 112)
	for n in AnimPresets.NAMES:
		anim_list.add_item(AnimPresets.label(n))
	anim_list.select(0)
	anim_list.item_selected.connect(func(i: int): _play(AnimPresets.NAMES[i]))
	v.add_child(anim_list)
	var h := HBoxContainer.new()
	h.add_child(_btn("▶ Lire", func(): _play(_cur_anim)))
	h.add_child(_btn("⏸ Pause", func():
		if viewer.player != null:
			viewer.player.pause()))
	h.add_child(_btn("■ Pose de repos", func(): _rest_pose()))
	v.add_child(h)
	speed_slider = _slider(0.1, 2.0, 0.05, func(x: float):
		if viewer.player != null:
			viewer.player.speed_scale = x)
	speed_slider.value = 1.0
	v.add_child(_row("Vitesse", speed_slider))
	time_slider = _slider(0.0, 1.0, 0.01, func(t: float):
		if _updating or viewer.player == null:
			return
		viewer.player.pause()
		viewer.player.seek(t, true))
	v.add_child(_row("Instant", time_slider))
	v.add_child(_lbl("Retouche d'une pose : choisissez un os et un instant, réglez sa rotation (en degrés), puis insérez une clé. Les os sans clé gardent l'animation automatique.", 12, DIM))
	anim_bone_opt = OptionButton.new()
	anim_bone_opt.item_selected.connect(func(_i: int): _load_rot_sliders())
	v.add_child(_row("Os", anim_bone_opt))
	for ax in 3:
		var s := _slider(-180.0, 180.0, 1.0, _on_rot_slider.bind(ax))
		rot_sliders.append(s)
		v.add_child(_row(["Rot. X", "Rot. Y", "Rot. Z"][ax], s))
	v.add_child(_btn("🔑 Insérer une clé à cet instant", _insert_key))
	v.add_child(_btn("↺ Effacer les clés de cet os (animation automatique)", _clear_keys))

func _build_tab_export() -> void:
	var v := _tab_box("4 Export")
	v.add_child(_lbl("Dossier d'export", 14, GOLD))
	export_dir_edit = LineEdit.new()
	export_dir_edit.text = str(cfg.get("export_dir", ""))
	export_dir_edit.placeholder_text = "ex. le dossier des modèles du jeu"
	export_dir_edit.text_changed.connect(func(t: String):
		cfg.export_dir = t
		StudioSettings.save_all(cfg))
	v.add_child(export_dir_edit)
	v.add_child(_btn("Choisir le dossier…", func(): _dir_dialog.popup_centered_ratio(0.7)))
	v.add_child(_btn("💾 Exporter ce monstre en .glb", func(): export_current()))
	v.add_child(_btn("💾 Exporter tous les monstres prêts", func(): export_all()))
	v.add_child(_lbl("Le .glb contient le maillage lié au squelette et les 5 animations (idle, walk, attack, hit, death). Il se charge tel quel dans Godot.", 12, DIM))

# ------------------------------------------------------------------ bibliothèque

func _set_status(t: String) -> void:
	status.text = t

func _reload_list(select_slug := "") -> void:
	monsters = Library.list_all()
	list.clear()
	var pick := -1
	for i in monsters.size():
		var m := monsters[i]
		var label := m.title + ("  ✔3D" if m.has_model() else "") + ("  ✔os" if m.has_rig() else "")
		var tex: Texture2D = null
		if m.has_source():
			var img := Image.load_from_file(ProjectSettings.globalize_path(m.source_path()))
			if img != null and not img.is_empty():
				img.resize(44, 44, Image.INTERPOLATE_BILINEAR)
				tex = ImageTexture.create_from_image(img)
		list.add_item(label, tex)
		if m.slug == select_slug:
			pick = i
	if pick >= 0:
		list.select(pick)
		_select(monsters[pick])
	elif monsters.is_empty():
		_select(null)

func _on_list_selected(i: int) -> void:
	_select(monsters[i])

func _on_files_dropped(files: PackedStringArray) -> void:
	import_paths(Array(files))

## Importe des images (ou, pour le monstre courant, un .glb).
func import_paths(paths: Array) -> void:
	var last := ""
	var n := 0
	for p in paths:
		var ext := str(p).get_extension().to_lower()
		if ext == "glb" or ext == "gltf":
			if cur != null:
				converter.use_glb(cur, str(p))
			continue
		if ext in Library.EXTS:
			var m := Library.import_image(str(p))
			if m != null:
				last = m.slug
				n += 1
	if n > 0:
		_set_status("%d image(s) importée(s)." % n)
		_reload_list(last)

func _delete_current() -> void:
	if cur == null:
		return
	Library.delete(cur)
	cur = null
	_reload_list()

func _select(m: Monster) -> void:
	cur = m
	model = {}
	weights = []
	sel_bone = -1
	if m == null:
		src_preview.texture = null
		viewer.show_node(null)
		viewer.set_bone_list([])
		_fill_bone_lists()
		return
	if m.has_source():
		var img := Image.load_from_file(ProjectSettings.globalize_path(m.source_path()))
		src_preview.texture = ImageTexture.create_from_image(img) if img != null else null
	log_label.text = ""
	await _load_model()
	_fill_bone_lists()
	if m.has_rig() and not model.is_empty():
		await compute_skin()
	else:
		_refresh_viewer()
	_set_status("%s : %s" % [m.title, ("modèle 3D prêt" if not model.is_empty() else "pas encore de modèle 3D")])

func _load_model() -> void:
	model = {}
	if cur != null and cur.has_model():
		model = ModelIO.load_normalized(cur.model_path(), cur.orient)

func _on_tab_changed(t: int) -> void:
	if t == 2 and viewer.player != null and not viewer.player.is_playing():
		_play(_cur_anim)

# ------------------------------------------------------------------ modèle 3D

func _on_create_model() -> void:
	if cur == null:
		_set_status("Choisissez d'abord un monstre.")
		return
	match source_opt.selected:
		0:
			_set_status("Conversion en cours (cela peut prendre plusieurs minutes)…")
			log_label.text = "Commande : " + Converter.command_line(str(cfg.command), "<image>", "<sortie>")
			converter.start_ai(cur, cfg)
		1:
			_glb_dialog.popup_centered_ratio(0.7)
		2: converter.use_test(cur, "biped")
		3: converter.use_test(cur, "quadruped")
		4: converter.use_test(cur, "serpent")

func _on_converted(ok: bool, msg: String) -> void:
	log_label.text = msg
	_set_status(msg.get_slice("\n", 0))
	if ok and cur != null:
		weights = []
		await _load_model()
		_refresh_viewer()
		viewer.frame_model()
		_reload_list(cur.slug)

## Tourne le modèle (multiples de 90°). Le squelette est à replacer : il est posé sur la boîte du modèle.
func _turn(delta: Vector3) -> void:
	if cur == null or model.is_empty():
		return
	var b := Basis.from_euler(cur.orient * PI / 180.0)
	b = Basis.from_euler(delta * PI / 180.0) * b
	var e := b.get_euler() * 180.0 / PI
	cur.orient = Vector3(snappedf(e.x, 90.0), snappedf(e.y, 90.0), snappedf(e.z, 90.0))
	cur.rig = {}
	weights = []
	sel_bone = -1
	cur.save()
	await _load_model()
	_fill_bone_lists()
	_refresh_viewer()
	_set_status("Modèle tourné : replacez le squelette (onglet 2).")

# ------------------------------------------------------------------ squelette

func _bones() -> Array:
	return cur.rig.get("bones", []) if cur != null else []

func place_skeleton(tpl: String) -> void:
	if cur == null or model.is_empty():
		_set_status("Créez d'abord le modèle 3D.")
		return
	cur.rig = {"template": tpl, "bones": SkeletonTemplates.build(tpl, model.aabb)}
	cur.anim_keys = {}
	weights = []
	sel_bone = 0
	cur.save()
	_fill_bone_lists()
	_refresh_viewer()
	skin_label.text = "Peau : à calculer."
	_set_status("Squelette placé : ajustez les os, puis calculez la peau.")

func _fill_bone_lists() -> void:
	_updating = true
	bone_list.clear()
	anim_bone_opt.clear()
	for b in _bones():
		bone_list.add_item(str(b.name))
		anim_bone_opt.add_item(str(b.name))
	_updating = false
	if sel_bone >= 0 and sel_bone < _bones().size():
		bone_list.select(sel_bone)
		anim_bone_opt.select(sel_bone)
	_load_bone_fields()

func _select_bone(i: int) -> void:
	sel_bone = i
	viewer.selected = i
	_load_bone_fields()
	if i >= 0 and i < anim_bone_opt.item_count:
		anim_bone_opt.select(i)
		_load_rot_sliders()

func _load_bone_fields() -> void:
	_updating = true
	var ok := sel_bone >= 0 and sel_bone < _bones().size()
	bone_name.editable = ok
	if ok:
		var b: Dictionary = _bones()[sel_bone]
		bone_name.text = str(b.name)
		var r := ROLES.find(str(b.role))
		bone_role.select(maxi(r, 0))
		for ax in 3:
			pos_sliders[ax].value = float(b.pos[ax])
		bone_list.select(sel_bone)
	else:
		bone_name.text = ""
	_updating = false
	viewer.selected = sel_bone

func _on_pos_slider(v: float, ax: int) -> void:
	if _updating or sel_bone < 0 or sel_bone >= _bones().size():
		return
	var b: Dictionary = _bones()[sel_bone]
	b.pos[ax] = v
	if sym_check.button_pressed:
		var other := _mirror_of(str(b.name))
		if other >= 0:
			var o: Dictionary = _bones()[other]
			o.pos = [-float(b.pos[0]), float(b.pos[1]), float(b.pos[2])]
	_bones_changed()

func _mirror_of(nm: String) -> int:
	var tgt := ""
	if nm.ends_with("_l"):
		tgt = nm.trim_suffix("_l") + "_r"
	elif nm.ends_with("_r"):
		tgt = nm.trim_suffix("_r") + "_l"
	if tgt == "":
		return -1
	for i in _bones().size():
		if str(_bones()[i].name) == tgt:
			return i
	return -1

func _bones_changed() -> void:
	weights = []
	skin_label.text = "Peau : à recalculer."
	cur.save()
	_refresh_viewer()

func _rename_bone(t: String) -> void:
	if sel_bone < 0 or t.strip_edges() == "":
		return
	var old := str(_bones()[sel_bone].name)
	var nw := t.strip_edges().replace(" ", "_")
	for b in _bones():
		if str(b.name) == nw and nw != old:
			_set_status("Ce nom existe déjà.")
			bone_name.text = old
			return
	for b in _bones():
		if str(b.parent) == old:
			b.parent = nw
	_bones()[sel_bone].name = nw
	for an in cur.anim_keys:
		if (cur.anim_keys[an] as Dictionary).has(old):
			cur.anim_keys[an][nw] = cur.anim_keys[an][old]
			(cur.anim_keys[an] as Dictionary).erase(old)
	_fill_bone_lists()
	_bones_changed()

func _add_bone() -> void:
	if cur == null or model.is_empty():
		return
	if not cur.has_rig():
		cur.rig = {"template": "custom", "bones": []}
	var bones := _bones()
	var par := sel_bone if (sel_bone >= 0 and sel_bone < bones.size()) else -1
	var n := 1
	while bones.any(func(b): return str(b.name) == "os_%d" % n):
		n += 1
	var pos := [0.0, 1.0, 0.0]
	var role := "root"
	var parent_name := ""
	if par >= 0:
		var pp: Array = bones[par].pos
		pos = [pp[0], float(pp[1]) + 0.15, pp[2]]
		role = str(bones[par].role) if str(bones[par].role) != "root" else "spine"
		parent_name = str(bones[par].name)
	elif not bones.is_empty():
		_set_status("Choisissez l'os parent d'abord.")
		return
	bones.append({"name": "os_%d" % n, "parent": parent_name, "role": role, "pos": pos})
	cur.rig.bones = bones
	sel_bone = bones.size() - 1
	_fill_bone_lists()
	_bones_changed()

func _remove_bone() -> void:
	if sel_bone < 0 or sel_bone >= _bones().size():
		return
	var bones := _bones()
	var nm := str(bones[sel_bone].name)
	var par := str(bones[sel_bone].parent)
	if par == "" and bones.size() > 1:
		_set_status("L'os racine ne peut pas être supprimé tant que d'autres os existent.")
		return
	for b in bones:
		if str(b.parent) == nm:
			b.parent = par
	bones.remove_at(sel_bone)
	cur.rig.bones = SkeletonTemplates.ordered(bones)
	sel_bone = mini(sel_bone, _bones().size() - 1)
	_fill_bone_lists()
	_bones_changed()

func _on_viewer_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and not (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if cur != null and cur.has_rig() and tabs.current_tab in [1, 2]:
			if (e as InputEventMouseButton).position.distance_to(_press_pos) < 5.0:
				var i := viewer.pick_bone((e as InputEventMouseButton).position)
				if i >= 0:
					_select_bone(i)
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_press_pos = (e as InputEventMouseButton).position

var _press_pos := Vector2.ZERO

## Calcule la peau (poids) pour le squelette courant puis affiche le modèle lié.
func compute_skin() -> void:
	if cur == null or model.is_empty() or not cur.has_rig() or _busy:
		return
	_busy = true
	skin_label.text = "Calcul de la peau…"
	_set_status("Calcul de la peau (%d sommets)…" % ModelIO.vertex_count(model))
	await get_tree().process_frame
	weights = await RigBuilder.compute_weights(model, _bones(), get_tree())
	_busy = false
	skin_label.text = "Peau calculée (%d os, %d sommets)." % [_bones().size(), ModelIO.vertex_count(model)]
	_set_status("Peau prête : passez à l'onglet Animations.")
	_refresh_viewer()

func _refresh_viewer() -> void:
	if model.is_empty():
		viewer.show_node(null)
		return
	var keep := _cur_anim
	var node: Node3D
	if cur.has_rig() and not weights.is_empty():
		node = RigBuilder.build(model, cur.rig, weights, cur.anim_keys)
	else:
		node = RigBuilder.build(model, {"bones": []}, [])
	viewer.show_node(node)
	viewer.set_bone_list(_bones())
	viewer.selected = sel_bone
	if viewer.player != null and tabs.current_tab == 2:
		_play(keep)

# ------------------------------------------------------------------ animations

func _play(anim: String) -> void:
	_cur_anim = anim
	if viewer.player == null:
		_set_status("Calculez d'abord la peau pour voir les animations.")
		return
	viewer.player.speed_scale = speed_slider.value
	viewer.player.play(anim)
	var a := viewer.player.get_animation(anim)
	time_slider.max_value = a.length

func _rest_pose() -> void:
	if viewer.player != null:
		viewer.player.stop()
	if viewer.skeleton != null:
		viewer.skeleton.reset_bone_poses()

func _anim_bone_name() -> String:
	return anim_bone_opt.get_item_text(anim_bone_opt.selected) if anim_bone_opt.selected >= 0 else ""

func _load_rot_sliders() -> void:
	if viewer.skeleton == null:
		return
	var i := viewer.skeleton.find_bone(_anim_bone_name())
	if i < 0:
		return
	_updating = true
	var e := viewer.skeleton.get_bone_pose_rotation(i).get_euler() * 180.0 / PI
	for ax in 3:
		rot_sliders[ax].value = snappedf(e[ax], 1.0)
	_updating = false

func _on_rot_slider(_v: float, _ax: int) -> void:
	if _updating or viewer.skeleton == null:
		return
	var i := viewer.skeleton.find_bone(_anim_bone_name())
	if i < 0:
		return
	if viewer.player != null:
		viewer.player.pause()
	var deg := Vector3(rot_sliders[0].value, rot_sliders[1].value, rot_sliders[2].value)
	viewer.skeleton.set_bone_pose_rotation(i, Quaternion.from_euler(deg * PI / 180.0))

func _insert_key() -> void:
	if cur == null or viewer.skeleton == null or viewer.player == null:
		return
	var bn := _anim_bone_name()
	if bn == "":
		return
	var t := snappedf(viewer.player.current_animation_position, 0.01)
	var deg := [rot_sliders[0].value, rot_sliders[1].value, rot_sliders[2].value]
	if not cur.anim_keys.has(_cur_anim):
		cur.anim_keys[_cur_anim] = {}
	var d: Dictionary = cur.anim_keys[_cur_anim]
	if not d.has(bn):
		# première clé : on part de l'animation automatique échantillonnée pour ne pas tout perdre
		d[bn] = _sampled_keys(bn)
	var keys: Array = d[bn]
	keys = keys.filter(func(k): return absf(float(k[0]) - t) > 0.02)
	keys.append([t, deg])
	d[bn] = keys
	cur.save()
	_replace_anim()
	_set_status("Clé ajoutée sur %s à %.2f s." % [bn, t])

func _sampled_keys(bn: String) -> Array:
	var out: Array = []
	var a := AnimPresets.build(_bones(), _cur_anim, {})
	for tr in a.get_track_count():
		if a.track_get_type(tr) == Animation.TYPE_ROTATION_3D and str(a.track_get_path(tr)).ends_with(":" + bn):
			for k in a.track_get_key_count(tr):
				var q: Quaternion = a.track_get_key_value(tr, k)
				var e := q.get_euler() * 180.0 / PI
				out.append([a.track_get_key_time(tr, k), [e.x, e.y, e.z]])
	return out

func _clear_keys() -> void:
	if cur == null:
		return
	var bn := _anim_bone_name()
	if cur.anim_keys.has(_cur_anim):
		(cur.anim_keys[_cur_anim] as Dictionary).erase(bn)
	cur.save()
	_replace_anim()
	_set_status("Clés effacées sur %s." % bn)

func _replace_anim() -> void:
	if viewer.player == null:
		return
	var lib := viewer.player.get_animation_library("")
	lib.remove_animation(_cur_anim)
	lib.add_animation(_cur_anim, AnimPresets.build(_bones(), _cur_anim, cur.anim_keys.get(_cur_anim, {})))
	viewer.player.play(_cur_anim)

# ------------------------------------------------------------------ export

## Exporte le monstre courant ; renvoie le chemin écrit (ou "" en cas d'échec).
func export_current(path := "") -> String:
	if cur == null or model.is_empty():
		_set_status("Rien à exporter : créez d'abord le modèle 3D.")
		return ""
	if not cur.has_rig():
		_set_status("Placez d'abord un squelette.")
		return ""
	if weights.is_empty():
		await compute_skin()
	if path == "":
		var dir := str(cfg.get("export_dir", "")).strip_edges()
		if dir == "":
			_set_status("Choisissez d'abord un dossier d'export (onglet 4).")
			return ""
		path = dir.path_join(cur.slug + ".glb")
	var node := RigBuilder.build(model, cur.rig, weights, cur.anim_keys)
	RigBuilder.set_owners(node, node)
	var err := ModelIO.save_glb(node, path)
	node.free()
	if err != OK:
		_set_status("Export impossible (erreur %d)." % err)
		return ""
	_set_status("Exporté : " + path)
	return path

func export_all() -> void:
	var n := 0
	var keep := cur
	for m in Library.list_all():
		if not (m.has_model() and m.has_rig()):
			continue
		await _select(m)
		if await export_current() != "":
			n += 1
	_set_status("%d monstre(s) exporté(s)." % n)
	if keep != null:
		_reload_list(keep.slug)

# ------------------------------------------------------------------ réglages

func _open_settings() -> void:
	if _settings_pop == null:
		_settings_pop = AcceptDialog.new()
		_settings_pop.title = "Réglages"
		_settings_pop.min_size = Vector2i(640, 330)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.add_child(_lbl("Modèle d'IA 2D → 3D (local). Par défaut : TripoSR (open source). Installez-le une fois (git clone + pip install), puis indiquez son dossier.", 13, DIM))
		_workdir_edit = LineEdit.new()
		_workdir_edit.placeholder_text = "Dossier du modèle (ex. C:/IA/TripoSR)"
		var h := HBoxContainer.new()
		_workdir_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(_workdir_edit)
		h.add_child(_btn("Parcourir…", func(): _workdir_dialog.popup_centered_ratio(0.7)))
		v.add_child(_row("Dossier", h))
		_cmd_edit = LineEdit.new()
		v.add_child(_row("Commande", _cmd_edit))
		_result_edit = LineEdit.new()
		v.add_child(_row("Résultat", _result_edit))
		v.add_child(_lbl("Variables : {image} = image du monstre, {outdir} = dossier de sortie. « Résultat » = le .glb que la commande produit.", 12, DIM))
		_settings_pop.add_child(v)
		_settings_pop.confirmed.connect(func():
			cfg.workdir = _workdir_edit.text
			cfg.command = _cmd_edit.text
			cfg.result = _result_edit.text
			StudioSettings.save_all(cfg))
		add_child(_settings_pop)
	_workdir_edit.text = str(cfg.workdir)
	_cmd_edit.text = str(cfg.command)
	_result_edit.text = str(cfg.result)
	_settings_pop.popup_centered()
