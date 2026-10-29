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

var tone: String = "spell"      # "spell", "attack", "ult" (7e sort : technique ultime), "empty"
var ult_charge: float = 0.0     ## ultime : remplissage de la jauge (0 → 1)
var ult_locked: bool = false    ## ultime : verrouillé (le héros n'a pas encore évolué) → cadenas
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
		if tone == "spell" or tone == "attack" or tone == "ult":
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
	if _flash <= 0.0 and not (tone == "ult" and ult_charge >= 1.0 and not ult_locked):
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

## Jauge de l'ultime : `charge` 0 → 1, `locked` = cadenas (classe de base).
func set_ult(charge: float, locked: bool) -> void:
	charge = clampf(charge, 0.0, 1.0)
	if is_equal_approx(charge, ult_charge) and locked == ult_locked:
		return
	ult_charge = charge
	ult_locked = locked
	set_process(ult_charge >= 1.0 or _flash > 0.0)
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

## Anneau lumineux de l'ultime (shader additif) : l'arc se remplit depuis le haut avec une tête incandescente ; il pulse en continu
## (doucement en charge, franchement une fois pleine, avec un éclat qui en fait le tour) et le halo déborde du disque.
const ULT_RING_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float charge = 0.0;
uniform float ring_px = 26.0;
uniform float width_px = 2.6;
uniform float glow_px = 14.0;
uniform float node_px = 100.0;
uniform float dim = 1.0;
uniform float boost = 0.0;
uniform vec3 gold : source_color = vec3(1.0, 0.81, 0.35);
uniform vec3 hot : source_color = vec3(1.0, 0.95, 0.74);

float wrap_dist(float a, float b) {
	float d = abs(a - b);
	return min(d, 1.0 - d);
}

void fragment() {
	vec2 p = (UV - 0.5) * node_px;
	float d = length(p);
	float t = atan(p.x, -p.y) / TAU;
	t = t < 0.0 ? t + 1.0 : t;
	float full = step(0.999, charge);
	float dr = abs(d - ring_px);
	float side = d < ring_px ? 1.7 : 1.0;
	// arc rempli (bord doux) ; pleine, tout le tour
	float lit = max(full, smoothstep(charge + 0.006, charge - 0.006, t) * step(0.001, charge));
	float lit_soft = max(full, smoothstep(charge + 0.025, charge - 0.01, t) * smoothstep(0.0, 0.035, t) * step(0.001, charge));
	float spd = mix(2.4, 5.2, full);
	float pulse = 0.5 + 0.5 * sin(TIME * spd);
	float amp = mix(0.22, 0.6, full);
	float breath = 1.0 - amp + amp * 2.0 * pulse;       // 1 - amp .. 1 + amp
	// filet net + halo serré + halo large
	float core = smoothstep(width_px * 0.5 + 0.9, width_px * 0.5 - 0.3, dr) * lit;
	float halo1 = exp(-dr * side / (glow_px * 0.22)) * lit_soft * 0.75;
	float halo2 = exp(-dr * side / (glow_px * 0.62)) * lit_soft * 0.42;
	// tête incandescente à l'avant de l'arc pendant la charge (distance réelle au point de tête : étincelle ronde)
	float ha = charge * TAU;
	vec2 head_pos = ring_px * vec2(sin(ha), -cos(ha));
	float hd = length(p - head_pos);
	float on_charge = step(0.001, charge) * (1.0 - full);
	float head = exp(-pow(hd / (width_px * 2.2), 2.0)) * on_charge;
	float head_halo = exp(-hd / (glow_px * 0.45)) * on_charge * 0.7;
	// éclat qui fait le tour de l'anneau une fois plein
	float ga = fract(TIME * 0.38) * TAU;
	float gd = length(p - ring_px * vec2(sin(ga), -cos(ga)));
	float glint = exp(-pow(gd / (width_px * 3.5), 2.0)) * full;
	float glint_halo = exp(-gd / (glow_px * 0.4)) * full * 0.3;
	float inten = (core * 1.15 + halo1 + halo2) * breath + head * 1.6 + head_halo + glint * 0.9 + glint_halo;
	// fondu vers zéro avant le bord du carré : aucun bord de halo visible
	float edge = 1.0 - smoothstep(ring_px + glow_px * 1.2, node_px * 0.5, d);
	inten *= edge * (1.0 + boost);
	vec3 col = mix(gold, hot, clamp(0.25 * pulse * (full + 0.4) + head * 0.8 + glint * 0.7, 0.0, 1.0));
	COLOR = vec4(col * inten, dim);
}
"""

static var _ult_shader: Shader = null
static var _spark_tex: GradientTexture2D = null

var _ult_ring: ColorRect
var _ult_sparks: CPUParticles2D

func _ensure_ult_nodes() -> void:
	if _ult_ring != null:
		return
	if _ult_shader == null:
		_ult_shader = Shader.new()
		_ult_shader.code = ULT_RING_SHADER
	_ult_ring = ColorRect.new()
	_ult_ring.name = "UltRing"
	_ult_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_ring.color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = _ult_shader
	_ult_ring.material = mat
	add_child(_ult_ring)
	if _spark_tex == null:
		_spark_tex = GradientTexture2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_spark_tex.gradient = g
		_spark_tex.fill = GradientTexture2D.FILL_RADIAL
		_spark_tex.fill_from = Vector2(0.5, 0.5)
		_spark_tex.fill_to = Vector2(1.0, 0.5)
		_spark_tex.width = 16
		_spark_tex.height = 16
	_ult_sparks = CPUParticles2D.new()
	_ult_sparks.name = "UltSparks"
	_ult_sparks.texture = _spark_tex
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ult_sparks.material = cm
	_ult_sparks.amount = 20
	_ult_sparks.lifetime = 1.2
	_ult_sparks.emitting = false
	_ult_sparks.local_coords = true
	_ult_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_ult_sparks.gravity = Vector2.ZERO
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.55, 0.0))
	grad.add_point(0.2, Color(1.0, 0.85, 0.4, 0.9))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.7, 0.2, 0.0))
	_ult_sparks.color_ramp = grad
	add_child(_ult_sparks)

## Place et règle l'anneau lumineux : `c` centre du disque, `ro` rayon de l'anneau, `k` échelle.
func _update_ult_ring(c: Vector2, ro: float, k: float) -> void:
	_ensure_ult_nodes()
	var glow := 15.0 * k
	var side := 2.0 * (ro + glow * 1.6 + 6.0 * k)
	_ult_ring.size = Vector2(side, side)
	_ult_ring.position = c - Vector2(side, side) * 0.5
	var mat := _ult_ring.material as ShaderMaterial
	mat.set_shader_parameter("charge", 0.0 if ult_locked else ult_charge)
	mat.set_shader_parameter("ring_px", ro)
	mat.set_shader_parameter("width_px", 2.6 * k)
	mat.set_shader_parameter("glow_px", glow)
	mat.set_shader_parameter("node_px", side)
	mat.set_shader_parameter("dim", dim)
	mat.set_shader_parameter("boost", _flash * 0.6)
	_ult_ring.visible = not ult_locked
	_ult_sparks.position = c
	_ult_sparks.emission_sphere_radius = ro
	_ult_sparks.radial_accel_min = 5.0 * k
	_ult_sparks.radial_accel_max = 11.0 * k
	_ult_sparks.scale_amount_min = 0.35 * k
	_ult_sparks.scale_amount_max = 0.85 * k
	_ult_sparks.emitting = ult_charge >= 1.0 and not ult_locked

## Jauge d'ultime : piste cuivre fixe, anneau lumineux et pulsant par-dessus (shader) ; verrouillé : cadenas.
func _draw_ult(c: Vector2, r: float, k: float, mod: Color) -> void:
	var ro := r + 3.4 * k
	draw_arc(c, ro, 0.0, TAU, 56, Color(Atlas.COPPER_DIM, 0.45 * dim), 2.4 * k, true)
	_update_ult_ring(c, ro, k)

func _draw_lock(c: Vector2, r: float) -> void:
	var w := r * 0.62
	var h := r * 0.46
	var col := Color(Atlas.IVORY_DIM, 0.9 * dim)
	draw_arc(Vector2(c.x, c.y - h * 0.35), w * 0.34, PI, TAU, 14, col, maxf(1.6, r * 0.11), true)
	draw_line(Vector2(c.x - w * 0.34, c.y - h * 0.35), Vector2(c.x - w * 0.34, c.y), col, maxf(1.6, r * 0.11), true)
	draw_line(Vector2(c.x + w * 0.34, c.y - h * 0.35), Vector2(c.x + w * 0.34, c.y), col, maxf(1.6, r * 0.11), true)
	var body_r := Rect2(Vector2(c.x - w * 0.5, c.y - h * 0.05), Vector2(w, h))
	draw_rect(body_r, Color(Atlas.COPPER, 0.85 * dim))
	draw_rect(body_r, Color("0a0c0b", 0.9 * dim), false, 1.0)
	draw_circle(Vector2(c.x, c.y + h * 0.28), maxf(1.4, r * 0.07), Color("0a0c0b", 0.9 * dim))

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
	if tone == "ult":
		_draw_ult(c, r, k, mod)
	if caption != "":
		var cf := Atlas.font(Atlas.F_BODY_BOLD)
		var cs := _cap_font()
		var ct := cf.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs)
		draw_string(cf, Vector2(c.x - ct.x * 0.5, area.y + cap_h - 3.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Color(Atlas.IVORY_DIM, dim))
	# contenu
	var inner := r * 1.08
	if tone == "ult" and ult_locked:
		_draw_lock(c, r)
	elif tex != null and tone != "empty":
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
