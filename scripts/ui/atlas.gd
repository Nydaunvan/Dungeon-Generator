class_name Atlas
extends RefCounted
## Identité « Atlas Noir » de l'interface en jeu : palette restreinte, polices, et petits outils de dessin
## (cadres à angles coupés, filets, repères). Les composants Atlas s'appuient tous sur ce fichier : un changement ici
## se répercute partout. L'ancien système (FrameBox / IronBox / OrnatePanel) reste en place pour ce qui n'est pas encore migré.

# --- palette -------------------------------------------------------------------------------------------------------
const OBSIDIAN := Color("101312")      # fond des panneaux
const OBSIDIAN_DEEP := Color("0a0c0b") # creux : fonds de barres, cases vides
const SLATE := Color("202522")         # surfaces secondaires
const SLATE_HI := Color("2a302c")      # survol
const COPPER := Color("986A42")        # détails structurels
const COPPER_DIM := Color("5a4129")    # filets au repos
const IVORY := Color("D8C8A4")         # texte et tracés
const IVORY_DIM := Color("a2967c")     # texte secondaire
const AMBER := Color("E5AE52")         # sélection, action importante
const AMBER_DIM := Color("a9793a")     # cible possible
# Les ressources gardent des teintes immédiatement reconnaissables.
const HP := Color("b8392e")
const HP_DARK := Color("6e1f19")
const MANA := Color("35b8c8")
const DANGER := Color("c0392b")

# --- polices : Cinzel pour les titres, Spectral pour les valeurs et les textes -------------------------------------
const F_TITLE := "res://assets/fonts/Cinzel-SemiBold.ttf"
const F_TITLE_BOLD := "res://assets/fonts/Cinzel-Bold.ttf"
const F_BODY := "res://assets/fonts/Spectral-Regular.ttf"
const F_BODY_MED := "res://assets/fonts/Spectral-Medium.ttf"
const F_BODY_BOLD := "res://assets/fonts/Spectral-SemiBold.ttf"
const F_BODY_ITALIC := "res://assets/fonts/Spectral-Italic.ttf"

static var _spaced: Dictionary = {}

static func font(path: String) -> Font:
	return UiTheme.font(path)

## Police de titre en capitales espacées (espacement entre lettres en pixels).
static func title_font(bold: bool = false, spacing: int = 2) -> Font:
	var key := "%s|%d" % [bold, spacing]
	if not _spaced.has(key):
		var fv := FontVariation.new()
		fv.base_font = UiTheme.font(F_TITLE_BOLD if bold else F_TITLE)
		fv.spacing_glyph = spacing
		_spaced[key] = fv
	return _spaced[key]

# --- géométrie ---------------------------------------------------------------------------------------------------
## Rectangle dont certains coins sont coupés en biais. `corners` = (haut-gauche, haut-droite, bas-droite, bas-gauche), 1 = coupé.
static func chamfer(r: Rect2, cut: float, corners: Vector4 = Vector4(1, 0, 1, 0)) -> PackedVector2Array:
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.5)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var p := PackedVector2Array()
	if corners.x > 0.0:
		p.append(Vector2(x0, y0 + c)); p.append(Vector2(x0 + c, y0))
	else:
		p.append(Vector2(x0, y0))
	if corners.y > 0.0:
		p.append(Vector2(x1 - c, y0)); p.append(Vector2(x1, y0 + c))
	else:
		p.append(Vector2(x1, y0))
	if corners.z > 0.0:
		p.append(Vector2(x1, y1 - c)); p.append(Vector2(x1 - c, y1))
	else:
		p.append(Vector2(x1, y1))
	if corners.w > 0.0:
		p.append(Vector2(x0 + c, y1)); p.append(Vector2(x0, y1 - c))
	else:
		p.append(Vector2(x0, y1))
	return p

## Dessine un cadre Atlas (fond en dégradé vertical léger + filet) sur un CanvasItem, dans son `_draw`.
static func draw_box(ci: CanvasItem, r: Rect2, fill_top: Color, fill_bottom: Color, border: Color, width: float = 1.0, cut: float = 6.0, corners: Vector4 = Vector4(1, 0, 1, 0)) -> void:
	var pts := chamfer(r.grow(-width * 0.5), cut, corners)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(fill_top.lerp(fill_bottom, clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	if border.a > 0.0 and width > 0.0:
		var line := pts.duplicate()
		line.append(pts[0])
		ci.draw_polyline(line, border, width, true)

## Petit losange (repère de sélection, séparateur).
static func draw_diamond(ci: CanvasItem, c: Vector2, half: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -half), c + Vector2(half, 0), c + Vector2(0, half), c + Vector2(-half, 0)]), col)

## Filet horizontal avec losange central optionnel.
static func draw_rule(ci: CanvasItem, from: Vector2, to: Vector2, col: Color, width: float = 1.0, diamond: bool = false) -> void:
	ci.draw_line(from, to, col, width, true)
	if diamond:
		draw_diamond(ci, (from + to) * 0.5, 3.0, col)

## Filet effilé : l'épaisseur passe de `w0` (au point `from`) à `w1` (au point `to`), comme les traits de la maquette autour du titre.
static func draw_taper(ci: CanvasItem, from: Vector2, to: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([from + n * w0 * 0.5, to + n * w1 * 0.5, to - n * w1 * 0.5, from - n * w0 * 0.5]), col)

## Graduations régulières le long d'un segment horizontal (repères de cartographie).
static func draw_ticks(ci: CanvasItem, from: Vector2, to: Vector2, count: int, h: float, col: Color) -> void:
	for i in count + 1:
		var x := lerpf(from.x, to.x, float(i) / float(maxi(1, count)))
		ci.draw_line(Vector2(x, from.y), Vector2(x, from.y - (h if i % 5 == 0 else h * 0.5)), col, 1.0)

# --- composants communs ----------------------------------------------------------------------------------------------
## Icône de la famille de traits GameIcons, dans la couleur voulue (ivoire par défaut).
static func icon(name: String, px: int, col: Color = IVORY, stroke: float = 1.6) -> Texture2D:
	return GameIcons.tex(name, px, col, stroke)

## Les cinq styles d'un bouton Atlas (normal, hover, pressed, focus, disabled) : fond sombre, filet fin, angles coupés.
## `kind` : "" (neutre), "accent" (ambre, action importante), "danger" (rouge, fuite).
static func button_boxes(kind: String = "", pad: float = 6.0) -> Dictionary:
	var out := {}
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var b := AtlasBox.new(pad)
		b.cut = 5.0
		b.width = 1.0
		var edge := COPPER_DIM
		var top := Color("1b201d")
		var bot := Color("111513")
		match kind:
			"accent":
				edge = AMBER_DIM
			"danger":
				edge = Color("8a3a2a")
				top = Color("2a1511")
				bot = Color("1a0d0a")
		if st == "hover" or st == "pressed":
			edge = AMBER if kind != "danger" else Color("d0452e")
			top = top.lightened(0.08)
			bot = bot.lightened(0.05)
		if st == "disabled":
			edge = Color(edge, 0.4)
		b.border = edge
		b.fill_top = top
		b.fill_bottom = bot
		out[st] = b
	return out

## Applique `button_boxes` à un bouton.
static func style_button(b: Button, kind: String = "", pad: float = 6.0) -> void:
	var st := button_boxes(kind, pad)
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_color_override("font_color", IVORY)
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_pressed_color", AMBER)
