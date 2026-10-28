class_name SpellDisc
extends Control
## Disque de bronze rivé (attaque, sorts, arcs des cartes) dessiné en vectoriel : net à toute taille.
## Port des styles .ab-slot / .ab-attack-btn / .csa-icon-btn du HTML.

signal pressed
signal tip_show
signal tip_hide

const LONG_PRESS := 0.45

## Rendu « grisé » (sort indisponible faute d'endurance) : toutes les couleurs du disque passent en niveaux de gris.
static var _gray_mat: ShaderMaterial = null

static func _gray_material() -> ShaderMaterial:
	if _gray_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR.rgb = vec3(g * 0.85);\n}\n"
		_gray_mat = ShaderMaterial.new()
		_gray_mat.shader = sh
	return _gray_mat

var tone: String = "spell"      # "spell", "attack", "empty"
var glyph: String = ""
var tex: Texture2D = null
var cd_text: String = ""
var dim: float = 1.0
var highlight: bool = false
var disabled: bool = false
var gray: bool = false
var badge: String = ""          ## pastille discrète : icône du statut que le sort inflige (vide = aucun)
var badge_bad: bool = true      ## statut nuisible (anneau rouge) ou bénéfique (anneau vert)
var caption: String = ""       ## numéro de touche affiché sous le disque
var _hover: bool = false
var _flash: float = 0.0          ## 1 → 0 : disque « allumé » quand sa touche du clavier vient d'être pressée
var _down: bool = false
var _long: bool = false
var _timer: Timer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(30, 30)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = LONG_PRESS
	_timer.timeout.connect(func():
		_long = true
		tip_show.emit())
	add_child(_timer)
	mouse_entered.connect(func():
		_hover = true
		queue_redraw()
		if tone == "spell" or tone == "attack":
			tip_show.emit())
	mouse_exited.connect(func():
		_hover = false
		_down = false
		_timer.stop()
		queue_redraw()
		tip_hide.emit())
	resized.connect(func(): pivot_offset = size * 0.5)

## Allume le disque un court instant (appui sur la touche de clavier correspondante).
func flash() -> void:
	_flash = 1.0
	set_process(true)
	queue_redraw()

func _process(d: float) -> void:
	_flash = maxf(0.0, _flash - d / 0.45)
	queue_redraw()
	if _flash <= 0.0:
		set_process(false)

func _cap_font() -> int:
	return int(clampf(minf(size.x, 60.0) * 0.26, 9.0, 14.0))

func _cap_height() -> float:
	return float(_cap_font()) + 4.0 if caption != "" else 0.0

func set_caption(t: String) -> void:
	if t == caption:
		return
	caption = t
	queue_redraw()

func set_state(g: String, t: Texture2D, cd: String, dimmed: float, hl: bool = false, grayed: bool = false) -> void:
	if g == glyph and t == tex and cd == cd_text and is_equal_approx(dimmed, dim) and hl == highlight and grayed == gray:
		return
	gray = grayed
	material = _gray_material() if grayed else null
	glyph = g
	tex = t
	cd_text = cd
	dim = dimmed
	highlight = hl
	queue_redraw()

func set_badge(glyph: String, harmful: bool = true) -> void:
	if glyph == badge and harmful == badge_bad:
		return
	badge = glyph
	badge_bad = harmful
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_long = false
			if e.device != -1 or DisplayServer.is_touchscreen_available():
				_timer.start()
		else:
			_timer.stop()
			var was_long := _long
			_long = false
			if _down and not was_long and not disabled and tone != "empty":
				pressed.emit()
			if was_long:
				tip_hide.emit()
			_down = false
		queue_redraw()
		accept_event()

func _draw() -> void:
	# Style Atlas : disque sombre, filet cuivre (ambre au survol / sélection), pas de rivets ; légende (numéro de touche) dessous.
	var cap_h := _cap_height()
	var area := Vector2(size.x, size.y - cap_h)
	var c := Vector2(size.x * 0.5, area.y * 0.5)
	var r := minf(area.x, area.y) * 0.5 - 3.0
	var hot := (_hover or highlight or _flash > 0.0) and tone != "empty"
	if hot and not _down:
		r += 1.0
	var k := clampf(r / 23.0, 0.6, 2.2)
	var mod := Color(1, 1, 1, dim)
	if _down:
		r *= 0.94
	var body := Color("0a0c0b") if tone == "empty" else (Color("2a1a14") if tone == "attack" else Color("151a18"))
	if hot:    # halo ambre autour du disque survolé / sélectionné
		var gl := 1.0 + _flash * 1.6      # l'éclair de la touche pressée éclaire plus fort et élargit le halo
		for i in 6:
			draw_arc(c, r + 1.0 + i * 1.7 * k, 0.0, TAU, 56, Color(Atlas.AMBER, clampf((0.22 - i * 0.034) * gl, 0.0, 0.8) * dim), 1.8 * k, true)
		if _flash > 0.0:
			draw_circle(c, r, Color(Atlas.AMBER, 0.28 * _flash * dim), true, -1.0, true)
	draw_circle(c, r, body * mod, true, -1.0, true)
	# anneau extérieur en dégradé (cuivre éclairé en haut à gauche, ardoise sombre en bas à droite) ; ambre quand il est chaud
	var lit := Atlas.AMBER if hot else (Atlas.COPPER if tone != "empty" else Atlas.COPPER_DIM)
	var shade := Atlas.AMBER_DIM if hot else Color("2c3430")
	var n := 48
	var w_out := maxf(1.3, 1.5 * k) * (1.5 if hot else 1.0)
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var a0 := t0 * TAU
		var a1 := t1 * TAU + 0.02
		var m := absf(fmod(t0 + 0.625, 1.0) * 2.0 - 1.0)   # 0 = angle -135° (haut gauche), 1 = opposé
		draw_arc(c, r - 0.5, a0, a1, 3, lit.lerp(shade, m * m * (3.0 - 2.0 * m)) * mod, w_out, true)
	if tone != "empty":
		draw_arc(c, r - 3.2 * k, 0.0, TAU, 48, Color(Atlas.COPPER_DIM, 0.55 * dim), 1.0, true)
		# repères aux quatre points cardinaux, de part et d'autre de l'anneau
		var tc := Color(Atlas.AMBER if hot else Atlas.COPPER, 0.9 * dim)
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + dir * (r - 1.0), c + dir * (r + 2.6 * k), tc, 1.0, true)
	if caption != "":
		var cf := Atlas.font(Atlas.F_BODY_BOLD)
		var cs := _cap_font()
		var ct := cf.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs)
		draw_string(cf, Vector2(c.x - ct.x * 0.5, area.y + cap_h - 3.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Color(Atlas.IVORY_DIM, dim))
	# contenu
	var inner := r * 1.08
	if tex != null and tone != "empty":
		var s := inner * 0.92
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1.25, 1.25, 1.25, dim))
	elif glyph != "":
		var font: Font = Atlas.font(Atlas.F_BODY_BOLD)
		var fs := int(r * (0.8 if tone == "empty" else 1.0))
		if tone == "empty":
			font = UiTheme.font(UiTheme.F_TITLE_BOLD)
		var col2 := Color(Atlas.IVORY_DIM, 0.35 * dim) if tone == "empty" else (Atlas.AMBER if tone == "attack" else Atlas.IVORY) * mod
		var ts := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var asc := font.get_ascent(fs)
		var ds := font.get_descent(fs)
		draw_string(font, Vector2(c.x - ts.x * 0.5, c.y + (asc - ds) * 0.5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col2)
	# compte à rebours : disque sombre + secondes
	if cd_text != "":
		draw_circle(c, r * 0.98, Color("0a0503", 0.92 * dim), true, -1.0, true)
		var f2: Font = UiTheme.font(UiTheme.F_TITLE_BOLD)
		var fs2 := int(r * 0.9)
		var ts2 := f2.get_string_size(cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		draw_string(f2, Vector2(c.x - ts2.x * 0.5, c.y + (f2.get_ascent(fs2) - f2.get_descent(fs2)) * 0.5), cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color("e8b45c", dim))
	# pastille de statut (coin bas droit) : le sort applique un statut
	if badge != "" and tone == "spell":
		var bp := c + Vector2(0.72, 0.72) * r
		var br := maxf(7.0, r * 0.38)
		draw_circle(bp, br + 1.5, Color("070504", 0.95 * dim), true, -1.0, true)
		draw_circle(bp, br, (Color("5a1a14") if badge_bad else Color("1f4a22")) * Color(1, 1, 1, dim), true, -1.0, true)
		draw_arc(bp, br, 0.0, TAU, 20, (Color("e5624f") if badge_bad else Color("7ad07a")) * Color(1, 1, 1, dim), 1.2, true)
		var bf := ThemeDB.fallback_font
		var bfs := int(br * 1.25)
		var bts := bf.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs)
		draw_string(bf, Vector2(bp.x - bts.x * 0.5, bp.y + bfs * 0.34), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(1, 1, 1, dim))
