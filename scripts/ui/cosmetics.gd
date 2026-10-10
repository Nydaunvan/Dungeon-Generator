class_name Cosmetics
extends RefCounted
## Rendu des cosmétiques gagnés avec un compte : cadre, couleur du pseudo, titre. Purement visuel (aucun effet sur la partie).

const FRAMES := {
	"bronze": {"color": "cd7f32", "width": 2, "glow": 0},
	"argent": {"color": "d8dde6", "width": 2, "glow": 0},
	"or": {"color": "ffd24a", "width": 2, "glow": 0},
	"braise": {"color": "ff7a45", "width": 2, "glow": 6},
	"givre": {"color": "7ef0e0", "width": 2, "glow": 6},
	"royal": {"color": "ffd24a", "width": 3, "glow": 8},
	"aurore": {"color": "c49cff", "width": 3, "glow": 10},
	"legende": {"color": "fff0a0", "width": 3, "glow": 12},
}
const RARITY_COLORS := [Color("9a8c74"), Color("c9a46a"), Color("8fd3ff"), Color("c49cff"), Color("ffd24a")]

static func frame_style(frame: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	if FRAMES.has(frame):
		var f: Dictionary = FRAMES[frame]
		sb.border_color = Color(str(f.color))
		sb.set_border_width_all(int(f.width))
		if int(f.glow) > 0:
			sb.shadow_color = Color(str(f.color), 0.45)
			sb.shadow_size = int(f.glow)
	else:
		sb.bg_color = Color(0, 0, 0, 0)
	return sb

static func name_color(hex: Variant) -> Color:
	return Color(str(hex)) if hex != null and str(hex) != "" else UiTheme.PARCH

## Pseudo (couleur gagnée), titre gagné, dans son cadre. `title` vide = pas de titre ; `frame` vide = pas de cadre.
static func name_plate(pseudo: String, title: String, frame: String, color: Variant, size: int = 15, level: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame_style(frame))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var n := Label.new()
	n.text = pseudo
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", name_color(color))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(n)
	if title != "":
		var t := Label.new()
		t.text = "« %s »" % title
		t.add_theme_font_size_override("font_size", maxi(size - 3, 10))
		t.add_theme_color_override("font_color", UiTheme.DIM)
		h.add_child(t)
	if level > 0:
		var lv := Label.new()
		lv.text = "Nv.%d" % level
		lv.add_theme_font_size_override("font_size", maxi(size - 4, 10))
		lv.add_theme_color_override("font_color", UiTheme.DIM)
		h.add_child(lv)
	return p

## XP nécessaire pour atteindre le niveau n (même formule que public.account_level : niveau = 1 + racine(xp / 100)).
static func xp_for_level(n: int) -> int:
	return 100 * (n - 1) * (n - 1)

static func level_of(xp: int) -> int:
	return 1 + int(floor(sqrt(maxf(xp, 0) / 100.0)))

## Texte d'un champ localisé d'une ligne du catalogue (champ_fr / champ_en).
static func loc(row: Dictionary, field: String) -> String:
	var en := str(row.get(field + "_en", ""))
	return en if Data.lang == "en" and en != "" else str(row.get(field + "_fr", ""))
