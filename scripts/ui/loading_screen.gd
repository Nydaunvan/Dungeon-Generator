class_name LoadingScreen
extends Control
## Écran de chargement : mur de pierre sombre, sceau, titre doré, barre de progression bronze et conseils qui défilent.
## Sur le Web, une fois tout chargé, un bouton « Entrer » attend un geste de l'utilisateur (les navigateurs n'autorisent le son qu'ensuite).

signal entered

const TIP_KEYS := ["loading.tip_torches", "loading.tip_son", "loading.tip_sauvegardes", "loading.tip_guide", "loading.tip_editeur"]

var _title: Label
var _sub: Label
var _step: Label
var _pct: Label
var _tip: Label
var _bar
var _seal: TextureRect
var _gate: Button
var _gate_hint: Label
var _bar_box: Control
var _embers: CPUParticles2D
var _target := 0.0
var _shown := 0.0
var _t := 0.0
var _tip_i := 0
var _tip_t := 0.0

func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # rien ne passe à travers pendant le chargement
	_build()
	_tip_i = randi() % TIP_KEYS.size()
	_show_tip()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var wall := TextureRect.new()
	wall.texture = UiTheme.tex("bg_tile")
	wall.stretch_mode = TextureRect.STRETCH_TILE
	wall.modulate = Color(0.95, 0.8, 0.65)
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall)
	# vignette : le centre reste lisible, les bords s'assombrissent
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.07, 0.05, 0.03, 0.0), Color(0.07, 0.05, 0.03, 0.45), Color(0.03, 0.02, 0.01, 0.92)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.85)
	gt.width = 256
	gt.height = 256
	var vig := TextureRect.new()
	vig.texture = gt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	# braises qui montent du bas de l'écran
	_embers = CPUParticles2D.new()
	_embers.amount = 26
	_embers.lifetime = 5.5
	_embers.preprocess = 0.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(420, 4)
	_embers.direction = Vector2(0, -1)
	_embers.spread = 18.0
	_embers.gravity = Vector2(6, -14)
	_embers.initial_velocity_min = 30.0
	_embers.initial_velocity_max = 90.0
	_embers.scale_amount_min = 1.5
	_embers.scale_amount_max = 4.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0.1))
	_embers.scale_amount_curve = sc
	var eg := Gradient.new()
	eg.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	eg.colors = PackedColorArray([Color(1, 0.8, 0.5, 0.0), Color(1, 0.66, 0.28, 0.9), Color(0.9, 0.3, 0.1, 0.0)])
	_embers.color_ramp = eg
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_embers.material = add_mat
	add_child(_embers)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var seal_box := Control.new()
	seal_box.custom_minimum_size = Vector2(150, 150)
	seal_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	seal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_box.visible = false
	col.add_child(seal_box)
	_seal = TextureRect.new()
	_seal.texture = load("res://assets/home/seal.png")
	_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_seal.size = Vector2(150, 150)
	_seal.pivot_offset = Vector2(75, 75)
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_box.add_child(_seal)

	_title = _label(L.t("loading.titre"), UiTheme.F_DISPLAY_BOLD, 58, UiTheme.GOLD)
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_outline_color", Color(0.07, 0.04, 0.02))
	col.add_child(_title)
	_sub = _label("", UiTheme.F_BODY_ITALIC, 20, UiTheme.DIM)
	col.add_child(_sub)
	col.add_child(_spacer(16))

	_bar_box = Control.new()
	_bar_box.custom_minimum_size = Vector2(880, 400)
	_bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_bar_box)
	_bar = SwordBar.new()
	_bar.position = Vector2(0, 0)
	_bar_box.add_child(_bar)
	_step = _label("", UiTheme.F_BODY, 17, UiTheme.PARCH)
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_step.position = Vector2(44, 346)
	_step.size = Vector2(560, 26)
	_bar_box.add_child(_step)
	_pct = _label("0 %", UiTheme.F_TITLE, 17, UiTheme.GOLD)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pct.position = Vector2(736, 346)
	_pct.size = Vector2(100, 26)
	_bar_box.add_child(_pct)

	_gate = Button.new()
	_gate.text = L.t("loading.entrer")
	_gate.custom_minimum_size = Vector2(320, 58)
	_gate.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	_gate.add_theme_font_size_override("font_size", 22)
	_gate.visible = false
	_gate.pressed.connect(func(): entered.emit())
	col.add_child(_gate)
	_gate_hint = _label(L.t("loading.entrer_indice"), UiTheme.F_BODY_ITALIC, 16, UiTheme.DIM)
	_gate_hint.visible = false
	col.add_child(_gate_hint)

	_tip = _label("", UiTheme.F_BODY_ITALIC, 18, UiTheme.DIM)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(640, 0)
	_tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tip.offset_left = -320
	_tip.offset_right = 320
	_tip.offset_top = -78
	_tip.offset_bottom = -30
	add_child(_tip)
	_embers.position = Vector2(640, 760)

func _label(text: String, font_path: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _show_tip() -> void:
	_tip.text = "✦  " + L.t(TIP_KEYS[_tip_i % TIP_KEYS.size()])

# ------------------------------------------------------------------ API

func set_subtitle(text: String) -> void:
	_sub.text = text

func set_progress(v: float, text: String = "") -> void:
	_target = clampf(v, 0.0, 1.0)
	if text != "":
		_step.text = text

func reset() -> void:
	_target = 0.0
	_shown = 0.0
	_bar.value = 0.0
	_pct.text = "0 %"
	_step.text = ""
	_gate.visible = false
	_gate_hint.visible = false
	_bar_box.visible = true

## La barre est pleine : propose d'entrer (geste utilisateur, nécessaire au son sur le Web).
func show_gate() -> void:
	_step.text = L.t("loading.pret")
	_bar_box.visible = true
	_gate.visible = true
	_gate_hint.visible = true
	_gate.grab_focus()

func is_full() -> bool:
	return _shown >= 0.999

func _input(event: InputEvent) -> void:
	if _gate.visible and is_visible_in_tree():
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventScreenTouch and event.pressed):
			get_viewport().set_input_as_handled()
			entered.emit()

func _process(delta: float) -> void:
	_t += delta
	# la barre rattrape sa cible en douceur (et ne recule jamais)
	_shown = minf(_target, _shown + maxf((_target - _shown) * minf(delta * 7.0, 1.0), delta * 0.04))
	_bar.value = _shown
	_pct.text = "%d %%" % int(round(_shown * 100.0))
	_seal.scale = Vector2.ONE * (1.0 + 0.025 * sin(_t * 2.2))
	_seal.rotation = sin(_t * 0.9) * 0.025
	if _gate.visible:
		_gate.modulate = Color(1, 1, 1, 0.82 + 0.18 * sin(_t * 3.0))
	_tip_t += delta
	if _tip_t > 4.5:
		_tip_t = 0.0
		_tip_i += 1
		var tw := create_tween()
		tw.tween_property(_tip, "modulate:a", 0.0, 0.25)
		tw.tween_callback(_show_tip)
		tw.tween_property(_tip, "modulate:a", 1.0, 0.25)

## Barre bronze rivetée : fond sombre, remplissage braise → or avec un reflet qui balaie.
class LoadingBar extends Control:
	var value := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r.grow(3), Color(0.02, 0.015, 0.01))
		draw_rect(r.grow(2), UiTheme.BRONZE)
		draw_rect(r.grow(-1), UiTheme.BRONZE_DARK)
		var inner := r.grow(-4)
		draw_rect(inner, Color(0.07, 0.05, 0.035))
		var w := inner.size.x * clampf(value, 0.0, 1.0)
		if w > 1.0:
			var fill := Rect2(inner.position, Vector2(w, inner.size.y))
			var steps := 24
			for i in steps:
				var x0 := fill.position.x + w * float(i) / steps
				var x1 := fill.position.x + w * float(i + 1) / steps
				var k := float(i) / float(maxi(steps - 1, 1))
				var c := Color("8a2a14").lerp(Color("e8b45c"), k)
				draw_rect(Rect2(x0, fill.position.y, x1 - x0 + 0.5, fill.size.y), c)
			# lumière en haut, ombre en bas
			draw_rect(Rect2(fill.position, Vector2(w, fill.size.y * 0.38)), Color(1, 1, 1, 0.16))
			draw_rect(Rect2(fill.position.x, fill.end.y - fill.size.y * 0.25, w, fill.size.y * 0.25), Color(0, 0, 0, 0.22))
			# reflet qui balaie la partie remplie
			var sweep := fposmod(_t * 0.55, 1.6) - 0.3
			var sx := fill.position.x + sweep * w
			for j in 8:
				var a := 0.20 * (1.0 - absf(float(j) - 3.5) / 4.0)
				var xx := sx + (j - 4) * 5.0
				if xx > fill.position.x and xx < fill.end.x - 1.0:
					draw_rect(Rect2(xx, fill.position.y, 5.0, fill.size.y), Color(1, 0.95, 0.8, a))
			# bout incandescent
			draw_circle(Vector2(fill.end.x, fill.position.y + fill.size.y * 0.5), fill.size.y * 0.8, Color(1, 0.7, 0.3, 0.16))
		# rivets aux extrémités
		for x in [-2.0, size.x + 2.0]:
			draw_circle(Vector2(x, size.y * 0.5), 4.0, Color("a88a5c"))
			draw_circle(Vector2(x - 1.0, size.y * 0.5 - 1.0), 1.6, Color("e9d9b0"))
