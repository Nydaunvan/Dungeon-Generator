class_name UltimateOverlay
extends Control
## Bouton d'ultime : quand la jauge du héros dont c'est le tour est pleine, un sceau doré (le sceau rouge de l'instinct, recoloré) apparaît sur le côté
## DROIT de la vue 3D, à l'opposé de l'instinct de survie. Un clic ou la touche d'ultime (R / 8) lance la technique ; il disparaît dès qu'elle part,
## que le tour change ou que la jauge se vide. Aucun décompte : il reste tant que l'ultime est prêt.

const SEAL := "res://assets/ui/seal_gold.png"

var ctrl: CombatController
var view: Control                # vue 3D encadrée : le bouton est posé sur son bord droit
var instinct: InstinctOverlay    # l'instinct (coup fatal) a toujours la priorité : le bouton s'efface pendant son invite
var right_limit: Callable          # abscisse écran (px) du bord gauche de la colonne de droite : le sceau reste en entier dans la vue, jamais sous les panneaux

var _seal: Control
var _ring: Control
var _pic: TextureRect
var _glyph: Label
var _word: Label
var _name: Label
var _hint: Label
var _shown := false
var _sid := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_seal = Control.new()
	_seal.mouse_filter = Control.MOUSE_FILTER_STOP
	_seal.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_seal.gui_input.connect(_on_seal_input)
	var bg := TextureRect.new()
	bg.texture = load(SEAL)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.add_child(bg)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.add_child(_pic)
	_glyph = _label(Color("fff4d0"), Color(0.25, 0.14, 0.0, 1.0), 8)
	_word = _label(Color("fff4d0"), Color(0.25, 0.14, 0.0, 1.0), 8)
	_seal.add_child(_glyph)
	_seal.add_child(_word)
	add_child(_seal)
	_name = _label(Color("ffd88a"), Color.BLACK, 6)
	add_child(_name)
	_hint = _label(Color("e8dcc0"), Color.BLACK, 5)
	add_child(_hint)
	set_process(true)

func _label(col: Color, outline: Color, osize: int) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", osize)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Le bouton est proposé : combat en cours, c'est le tour du héros actif, sa jauge est pleine et rien d'autre n'est en cours.
func _wanted() -> bool:
	if ctrl == null or ctrl.combat == null or ctrl.gs.game_over or ctrl.gs.won:
		return false
	if instinct != null and instinct.visible:
		return false
	if not ctrl.in_combat() or ctrl.is_busy() or not ctrl.hero_ready():
		return false
	var c := ctrl.gs.char_by_id(ctrl.gs.active_char_id)
	return not c.is_empty() and int(c.hp) > 0 and Characters.ult_ready(ctrl.gs.cfg, c)

func _process(_d: float) -> void:
	var want := _wanted()
	if want and not _shown:
		_show()
	elif not want and _shown:
		_hide()
	if _shown:
		_place()
		_ring.queue_redraw()
		_seal.scale = Vector2.ONE * (1.0 + 0.035 * sin(Time.get_ticks_msec() * 0.006))

func _show() -> void:
	_shown = true
	var c := ctrl.gs.char_by_id(ctrl.gs.active_char_id)
	_sid = Characters.ultimate_id(ctrl.gs.cfg, c)
	var sp := ctrl.combat.spell_def(_sid)
	var icon := str(sp.get("icon", "✨"))
	var tex: Texture2D = IconResolver.texture(icon) if icon.begins_with("@icon:") else null
	_pic.texture = tex
	_pic.visible = tex != null
	_glyph.text = "" if tex != null else icon
	_glyph.visible = tex == null
	_word.text = L.t("ui.ultimate.bouton")
	_name.text = "%s — %s" % [str(c.get("name", "")), str(sp.get("name", ""))]
	_hint.text = L.fa(L.t("ui.ultimate.touche"), Keybinds.text("slot_8").get_slice(" ", 0))
	_place()
	modulate.a = 1.0
	_seal.scale = Vector2(0.6, 0.6)
	_seal.modulate.a = 0.0
	visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_seal, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_seal, "modulate:a", 1.0, 0.15)
	Sound.sfx("level_up")

func _hide() -> void:
	_shown = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		if not _shown:
			visible = false
		modulate.a = 1.0)

## Sceau sur le côté droit de la vue 3D (symétrique de l'instinct, à gauche) ; rappelé à chaque image car la vue peut encore bouger.
func _place() -> void:
	var area: Rect2 = view.get_global_rect() if view != null else get_viewport_rect()
	var d := clampf(minf(area.size.x, area.size.y) * 0.36, 120.0, 210.0)
	var center := Vector2(area.end.x - maxf(d * 1.25, area.size.x * 0.17), area.get_center().y)
	if right_limit.is_valid():
		center.x = minf(center.x, float(right_limit.call()) - d * 0.5)      # le sceau est à gauche de la colonne de droite
	_seal.size = Vector2(d, d)
	_seal.pivot_offset = _seal.size * 0.5
	_seal.global_position = center - _seal.size * 0.5
	_ring.size = area.size
	_ring.global_position = area.position
	var inner := d * 0.56
	_pic.size = Vector2(inner, inner)
	_pic.position = Vector2((d - inner) * 0.5, d * 0.30)
	_glyph.add_theme_font_size_override("font_size", int(d * 0.36))
	_glyph.size = Vector2(d, d * 0.5)
	_glyph.position = Vector2(0.0, d * 0.28)
	_word.add_theme_font_size_override("font_size", _fit(_word, d * 0.56, int(d * 0.125)))
	_word.size = Vector2(d, d * 0.2)
	_word.position = Vector2(0.0, d * 0.17)
	_name.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.0)))
	_hint.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.8)))
	_name.size = Vector2(d * 1.9, 28)
	_name.global_position = Vector2(center.x - _name.size.x * 0.5, _seal.global_position.y + d + 6.0)
	_hint.size = Vector2(d * 1.9, 22)
	_hint.global_position = Vector2(center.x - _hint.size.x * 0.5, _name.global_position.y + 26.0)

func _fit(l: Label, max_w: float, max_size: int) -> int:
	var font := l.get_theme_font("font")
	var size := max_size
	while size > 8 and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		size -= 1
	return size

func _on_seal_input(ev: InputEvent) -> void:
	if _shown and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_fire()

func _fire() -> void:
	if _sid != "" and ctrl != null:
		ctrl.cast(_sid)

## Halos dorés pulsants autour du sceau (pas de décompte : l'ultime reste prêt).
func _draw_ring() -> void:
	if not _shown:
		return
	var c := _seal.global_position + _seal.size * 0.5 - _ring.global_position
	var r0 := _seal.size.x * 0.5
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
	_ring.draw_arc(c, r0 * 1.04, 0.0, TAU, 96, Color(1, 0.88, 0.5, 0.35), 3.0, true)
	for i in 4:
		var rr := r0 * (1.08 + 0.09 * i + 0.05 * pulse)
		_ring.draw_arc(c, rr, 0.0, TAU, 96, Color("ffd24a", (0.5 - i * 0.11) * (0.6 + 0.4 * pulse)), 3.0 - i * 0.5, true)
