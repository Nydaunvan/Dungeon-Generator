class_name CombatBanner
extends PanelContainer
## Plaquette du monstre engagé (nom + barre de PV). Un clic ouvre sa fiche ; la partie est en pause tant qu'elle est ouverte.

signal pressed(def: Dictionary, st: Dictionary)
var ctrl: CombatController
var _btn: Button
var _bar: ProgressBar
var _label: Label

func setup(controller: CombatController) -> void:
	ctrl = controller
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.02, 0.82)
	sb.border_color = Color("8a6a3a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	_btn = Button.new()
	_btn.flat = true
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.tooltip_text = "Voir la fiche du monstre"
	_btn.add_theme_font_size_override("font_size", 16)
	_btn.pressed.connect(func():
		var eng := ctrl.combat.engaged()
		if not eng.is_empty():
			pressed.emit(eng.monster, ctrl.combat.lstate().monsters[str(eng.monster.id)]))
	v.add_child(_btn)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(190, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c2453b")
	_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_bar.add_theme_stylebox_override("background", bg)
	v.add_child(_bar)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", UiTheme.DIM)
	v.add_child(_label)

func _process(_d: float) -> void:
	var on := ctrl != null and ctrl.combat != null and ctrl.in_combat()
	visible = on
	if not on:
		return
	var eng := ctrl.combat.engaged()
	var def: Dictionary = eng.monster
	var st: Dictionary = ctrl.combat.lstate().monsters[str(def.id)]
	var hp := 0.0
	var mx := 0.0
	var parts: Array = st.members if (bool(def.get("isGroup", false)) and st.has("members")) else [st]
	for mem in parts:
		mx += float(mem.maxHp)
		if mem.alive:
			hp += maxf(0.0, float(mem.hp))
	_bar.max_value = maxf(1.0, mx)
	_bar.value = hp
	var nm := str(def.get("name", "Monstre"))
	var icon := str(def.get("icon", ""))
	_btn.text = ("%s " % icon if not icon.begins_with("@icon:") else "") + nm + ("  😡" if st.get("enraged", false) else "")
	_label.text = "%d / %d PV" % [ceili(hp), ceili(mx)]
