class_name InstinctOverlay
extends Control
## « Instinct de survie » : quand un coup de monstre va faire tomber un héros à 0 PV, le combat est suspendu et le bouton rouge (le sceau de
## l'accueil) apparaît au centre de la vue. Un anneau se resserre autour : plus l'appui est proche du sceau, meilleure est la qualité
## (tôt / bon / parfait = dernier tiers). Aucun appui avant la fin du temps = « none ». Le résultat (dé compris) est calculé par les règles.

const SEAL := "res://assets/home/seal.png"
const GOOD_FROM := 0.35          # part du temps écoulée à partir de laquelle l'appui est « bon »
const PERFECT_FROM := 0.67       # … et « parfait »

var ctrl: CombatController
var view: Control                # vue 3D encadrée : le bouton est centré dessus

var _vignette: TextureRect
var _seal: Control
var _ring: Control
var _name: Label
var _t0 := 0
var _seconds := 3.0
var _active := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# vignette rouge sur les bords (la tension monte)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.45, 1.0])
	g.colors = PackedColorArray([Color(0.55, 0.0, 0.0, 0.0), Color(0.55, 0.0, 0.0, 0.55)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = gt
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_seal = Control.new()
	_seal.mouse_filter = Control.MOUSE_FILTER_STOP
	_seal.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_seal.gui_input.connect(_on_seal_input)
	var pic := TextureRect.new()
	pic.texture = load(SEAL)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.add_child(pic)
	add_child(_seal)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.0)))
	_name.add_theme_color_override("font_color", Color("ffd88a"))
	_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_name.add_theme_constant_override("outline_size", 6)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	if ctrl != null:
		ctrl.instinct_prompt.connect(_on_prompt)
		ctrl.instinct_end.connect(func(_o): _hide())

func _on_prompt(char_id: String, seconds: float) -> void:
	_seconds = maxf(0.5, seconds)
	_t0 = Time.get_ticks_msec()
	_active = true
	var hero: Dictionary = ctrl.gs.char_by_id(char_id)
	_name.text = str(hero.get("name", ""))
	var area: Rect2 = view.get_global_rect() if view != null else get_viewport_rect()
	var d := clampf(minf(area.size.x, area.size.y) * 0.42, 130.0, 260.0)
	_seal.size = Vector2(d, d)
	_seal.pivot_offset = _seal.size * 0.5
	_seal.global_position = area.get_center() - _seal.size * 0.5
	_ring.size = area.size
	_ring.global_position = area.position
	_name.size = Vector2(d * 1.6, 28)
	_name.global_position = Vector2(area.get_center().x - _name.size.x * 0.5, _seal.global_position.y + d + 6.0)
	_seal.scale = Vector2(0.6, 0.6)
	_seal.modulate.a = 0.0
	_vignette.modulate.a = 0.0
	visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_seal, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_seal, "modulate:a", 1.0, 0.12)
	tw.tween_property(_vignette, "modulate:a", 1.0, 0.25)
	Sound.sfx("heartbeat")
	set_process(true)

func _hide() -> void:
	if not _active and not visible:
		return
	_active = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(func():
		visible = false
		modulate.a = 1.0)

## Fraction (0..1) du temps écoulé.
func _frac() -> float:
	return clampf(float(Time.get_ticks_msec() - _t0) / (_seconds * 1000.0), 0.0, 1.0)

func _process(_d: float) -> void:
	if not _active:
		return
	var f := _frac()
	_ring.queue_redraw()
	_seal.scale = Vector2.ONE * (1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.012))
	if f >= 1.0:
		_finish("none")

func _quality(f: float) -> String:
	if f >= PERFECT_FROM:
		return "perfect"
	if f >= GOOD_FROM:
		return "good"
	return "early"

func _finish(q: String) -> void:
	if not _active:
		return
	_active = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_seal, "scale", Vector2(1.25, 1.25), 0.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(func():
		visible = false
		modulate.a = 1.0)
	if ctrl != null:
		ctrl.instinct_input(q)

func _on_seal_input(ev: InputEvent) -> void:
	if _active and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_finish(_quality(_frac()))

func _unhandled_input(ev: InputEvent) -> void:
	if _active and ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		_finish(_quality(_frac()))

## Anneau qui se resserre : sombre au début, orange puis doré quand l'appui devient « parfait ».
func _draw_ring() -> void:
	if not _active:
		return
	var f := _frac()
	var c := _seal.global_position + _seal.size * 0.5 - _ring.global_position
	var r0 := _seal.size.x * 0.5
	var r := lerpf(r0 * 2.3, r0 * 1.04, f)
	var col := Color("a33a2a") if f < GOOD_FROM else (Color("ffb347") if f < PERFECT_FROM else Color("ffe08a"))
	_ring.draw_arc(c, r0 * 1.04, 0.0, TAU, 96, Color(1, 0.88, 0.5, 0.35), 3.0, true)       # cible : bord du sceau
	_ring.draw_arc(c, r, 0.0, TAU, 96, col, 5.0 if f >= PERFECT_FROM else 3.5, true)
