class_name LivingViz
extends Control
## Visuels des compétences vivantes (dessinés, style Atlas Noir) : frise des paliers, arbre des évolutions, constellation des liens, grille de l'équipe.
## `kind` : "timeline" | "tree" | "web" | "grid" ; `d` : données (voir les fabriques ci-dessous). Purement visuel : ne modifie jamais la partie.

const BRONZE := Color("7a6242")
const BRONZE_D := Color("3a2c1c")
const GOLD := Color("e8b45c")
const PARCH := Color("f5ecd8")
const DIM := Color("8f7f60")
const CYAN := Color("35b8c8")
const TYPE_COL := {"complementaire": Color("8fc8e8"), "rivale": Color("e0a070"), "protectrice": Color("7ab648"), "antagoniste": Color("c0392b"), "fusionnelle": Color("e8b45c")}
const TIER_COL := [Color("5a4a34"), Color("8f7f60"), Color("35b8c8"), Color("7ab648"), Color("e8b45c")]

var kind := "timeline"
var d: Dictionary = {}
var _tips: Array = []      # [Rect2, texte] pour les infobulles de la grille

static func timeline(affinity: float) -> LivingViz:
	var v := LivingViz.new()
	v.kind = "timeline"
	v.d = {"a": affinity}
	v.custom_minimum_size = Vector2(0, 128)
	return v

static func tree(root_name: String, root_icon: Texture2D, desc: Dictionary) -> LivingViz:
	var v := LivingViz.new()
	v.kind = "tree"
	v.d = {"name": root_name, "icon": root_icon, "desc": desc}
	v.custom_minimum_size = Vector2(0, 28 + 3 * 66)
	return v

static func web(center: String, links: Array) -> LivingViz:
	var v := LivingViz.new()
	v.kind = "web"
	v.d = {"center": center, "links": links}
	v.custom_minimum_size = Vector2(0, 230)
	return v

## `rows` : [{name, dots: [{tier, evo, label}]}]
static func grid(rows: Array) -> LivingViz:
	var v := LivingViz.new()
	v.kind = "grid"
	v.d = {"rows": rows}
	v.custom_minimum_size = Vector2(0, 14 + rows.size() * 34)
	return v

func _f(bold: bool = false) -> Font:
	return UiTheme.font(UiTheme.F_BODY_BOLD if bold else UiTheme.F_BODY)

func _t(pos: Vector2, text: String, size: int, col: Color, bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	draw_string(_f(bold), pos, text, align as HorizontalAlignment, w, size, col)

func _fit(text: String, size: int, w: float, bold: bool = false) -> String:
	var f := _f(bold)
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= w:
		return text
	while text.length() > 1 and f.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
		text = text.substr(0, text.length() - 1)
	return text + "…"

func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	draw_rect(r, BRONZE_D, false, 1.0)

func _draw() -> void:
	match kind:
		"timeline": _draw_timeline()
		"tree": _draw_tree()
		"web": _draw_web()
		"grid": _draw_grid()

# ------------------------------------------------------------------ frise des paliers

func _draw_timeline() -> void:
	var w := size.x
	var pad := 52.0
	var xs: Array = []
	for i in 5:
		xs.append(pad + (w - 2.0 * pad) * float(i) / 4.0)
	var a := float(d.a)
	var ty := 24.0
	draw_line(Vector2(xs[0], ty), Vector2(xs[4], ty), BRONZE_D, 5.0)
	# progression : interpolation entre deux seuils
	var px: float = xs[0]
	for i in 4:
		var lo: float = LivingSkills.TIER_AT[i]
		var hi: float = LivingSkills.TIER_AT[i + 1]
		if a >= hi:
			px = xs[i + 1]
		elif a > lo:
			px = lerpf(xs[i], xs[i + 1], (a - lo) / (hi - lo))
			break
	draw_line(Vector2(xs[0], ty), Vector2(px, ty), GOLD, 5.0)
	var cur := LivingSkills.tier(a)
	for i in 5:
		var reached := a >= float(LivingSkills.TIER_AT[i])
		var c := Vector2(xs[i], ty)
		draw_circle(c, 11.0, BRONZE_D)
		draw_circle(c, 9.0, GOLD if reached else Color("1a130c"))
		draw_arc(c, 10.0, 0.0, TAU, 24, GOLD if reached else BRONZE, 1.5)
		if i == cur:
			draw_arc(c, 15.0, 0.0, TAU, 32, PARCH, 1.5)
		var col := PARCH if reached else DIM
		_t(Vector2(xs[i] - 50.0, 56.0), L.t("ui.living.tier_%d" % i), 13, GOLD if i == cur else col, i == cur, HORIZONTAL_ALIGNMENT_CENTER, 100.0)
		_t(Vector2(xs[i] - 50.0, 72.0), "%d" % int(LivingSkills.TIER_AT[i]), 11, DIM, false, HORIZONTAL_ALIGNMENT_CENTER, 100.0)
		draw_multiline_string(_f(), Vector2(xs[i] - 46.0, 88.0), L.t("ui.living.tcap_%d" % i), HORIZONTAL_ALIGNMENT_CENTER, 92.0, 11, 3, col if reached else DIM)
	# repère « vous êtes ici »
	_t(Vector2(px - 30.0, 6.0), "▼ %d" % int(a), 11, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER, 60.0)

# ------------------------------------------------------------------ arbre des évolutions

func _draw_tree() -> void:
	var desc: Dictionary = d.desc
	var prof: Dictionary = desc.profile
	var w := size.x
	var rx := 0.0
	var rw := 132.0
	var bx := rw + 46.0
	var bw := w - bx
	var h := size.y
	var evolved := str(desc.evolved)
	# racine
	var rr := Rect2(rx, h * 0.5 - 40.0, rw, 80.0)
	draw_rect(rr, Color(0.1, 0.07, 0.04, 0.9))
	draw_rect(rr, GOLD if evolved != "" else BRONZE, false, 1.5)
	var tex: Texture2D = d.icon
	if tex != null:
		draw_texture_rect(tex, Rect2(rr.position.x + rw * 0.5 - 14.0, rr.position.y + 6.0, 28.0, 28.0), false)
	_t(Vector2(rr.position.x + 4.0, rr.position.y + 50.0), _fit(str(d.name), 13, rw - 8.0, true), 13, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER, rw - 8.0)
	_t(Vector2(rr.position.x + 4.0, rr.position.y + 68.0), "%s · %d" % [L.t("ui.living.tier_%d" % int(desc.tier)), int(desc.affinity)], 11, DIM, false, HORIZONTAL_ALIGNMENT_CENTER, rw - 8.0)
	var branches: Array = prof.branches
	for i in branches.size():
		var b: Dictionary = branches[i]
		var by := 6.0 + i * 66.0
		var r := Rect2(bx, by, bw, 58.0)
		var kindk := str(b.kind)
		var chosen := evolved == kindk
		var other := evolved != "" and not chosen
		var ready := (desc.available as Array).has(kindk)
		var tr := int((desc.traits as Dictionary).get(str(b.trait), 0))
		var aff_ok := float(desc.affinity) >= LivingSkills.EVOLVE_AFF
		var tr_ok := tr >= LivingSkills.TRAIT_MIN
		var edge := GOLD if (chosen or ready) else (Color("4a3c28") if other else BRONZE)
		# connecteur
		var from := Vector2(rr.end.x, rr.position.y + 40.0)
		var to := Vector2(bx, by + 29.0)
		var mid := (from.x + to.x) * 0.5
		var lc := edge if not other else Color("33281a")
		draw_polyline(PackedVector2Array([from, Vector2(mid, from.y), Vector2(mid, to.y), to]), lc, 2.0 if (chosen or ready) else 1.5)
		draw_rect(r, Color(0.16, 0.11, 0.05, 0.95) if chosen else Color(0.08, 0.06, 0.04, 0.9))
		draw_rect(r, edge, false, 2.0 if (chosen or ready) else 1.0)
		var tcol := GOLD if (chosen or ready) else (DIM if other else PARCH)
		_t(Vector2(r.position.x + 10.0, r.position.y + 18.0), ("✦ " if (chosen or ready) else "· ") + L.t("ui.living.k_%s_n" % kindk), 14, tcol, true)
		var state := L.t("ui.living.viz_awake") if chosen else (L.t("ui.living.viz_other") if other else (L.t("ui.living.viz_ready") if ready else L.t("ui.living.viz_locked")))
		_t(Vector2(r.end.x - 130.0, r.position.y + 18.0), state, 12, tcol, false, HORIZONTAL_ALIGNMENT_RIGHT, 120.0)
		var half := (bw - 30.0) * 0.5
		_t(Vector2(r.position.x + 10.0, r.position.y + 34.0), L.t("ui.living.viz_aff"), 11, DIM)
		_bar(Rect2(r.position.x + 10.0, r.position.y + 39.0, half - 4.0, 8.0), float(desc.affinity) / LivingSkills.EVOLVE_AFF, CYAN if aff_ok else BRONZE)
		_t(Vector2(r.position.x + 10.0 + half - 4.0 - 60.0, r.position.y + 34.0), "%d / %d" % [mini(int(desc.affinity), 99), int(LivingSkills.EVOLVE_AFF)], 11, PARCH if aff_ok else DIM, false, HORIZONTAL_ALIGNMENT_RIGHT, 60.0)
		var x2 := r.position.x + 20.0 + half
		_t(Vector2(x2, r.position.y + 34.0), L.t("ui.living.trait_%s" % str(b.trait)), 11, DIM)
		_bar(Rect2(x2, r.position.y + 39.0, half - 4.0, 8.0), float(tr) / float(LivingSkills.TRAIT_MIN), GOLD if tr_ok else BRONZE)
		_t(Vector2(x2 + half - 4.0 - 60.0, r.position.y + 34.0), "%d / %d" % [tr, LivingSkills.TRAIT_MIN], 11, PARCH if tr_ok else DIM, false, HORIZONTAL_ALIGNMENT_RIGHT, 60.0)

# ------------------------------------------------------------------ constellation

func _draw_web() -> void:
	var links: Array = d.links
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var rx := size.x * 0.5 - 70.0
	var ry := size.y * 0.5 - 30.0
	var n := links.size()
	for i in n:
		var l: Dictionary = links[i]
		var ang := -PI * 0.5 + TAU * float(i) / float(maxi(1, n))
		var p := c + Vector2(cos(ang) * rx, sin(ang) * ry)
		var col: Color = TYPE_COL.get(str(l.type), BRONZE)
		draw_line(c, p, col, 1.0 + 1.5 * float(int(l.level)))
		var rad := 7.0 + 2.0 * float(int(l.level))
		draw_circle(p, rad + 2.0, BRONZE_D)
		draw_circle(p, rad, col)
		var lab := _fit(str(l.name), 11, 130.0)
		var up := p.y < c.y - 2.0
		_t(Vector2(p.x - 70.0, p.y + (-rad - 18.0 if up else rad + 14.0)), lab, 11, PARCH, false, HORIZONTAL_ALIGNMENT_CENTER, 140.0)
		_t(Vector2(p.x - 70.0, p.y + (-rad - 6.0 if up else rad + 26.0)), "%s · %s" % [L.t("ui.living.rel_%s" % str(l.type)), L.t("ui.living.rel_level") % int(l.level)], 10, col, false, HORIZONTAL_ALIGNMENT_CENTER, 140.0)
	draw_circle(c, 22.0, BRONZE_D)
	draw_circle(c, 19.0, GOLD)
	draw_rect(Rect2(c.x - 62.0, c.y + 24.0, 124.0, 17.0), Color(0.07, 0.05, 0.03, 0.92))      # fond sombre : le nom reste lisible là où passent les liens
	_t(Vector2(c.x - 60.0, c.y + 37.0), _fit(str(d.center), 12, 120.0, true), 12, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	if n == 0:
		_t(Vector2(0, c.y - 40.0), L.t("ui.living.no_relations"), 12, DIM, false, HORIZONTAL_ALIGNMENT_CENTER, size.x)

# ------------------------------------------------------------------ grille de l'équipe

func _draw_grid() -> void:
	_tips.clear()
	var rows: Array = d.rows
	for i in rows.size():
		var y := 8.0 + i * 34.0
		_t(Vector2(0, y + 18.0), _fit(str(rows[i].name), 13, 110.0, true), 13, GOLD, true)
		var x := 124.0
		for dot in rows[i].dots:
			var cc := Vector2(x + 11.0, y + 13.0)
			var t: int = int(dot.tier)
			draw_circle(cc, 11.0, BRONZE_D)
			draw_circle(cc, 9.0, TIER_COL[t])
			if str(dot.evo) != "":
				draw_arc(cc, 12.5, 0.0, TAU, 24, GOLD, 2.0)
			_tips.append([Rect2(x, y, 22.0, 26.0), "%s — %s%s" % [dot.label, L.t("ui.living.tier_%d" % t), (" · " + L.t("ui.living.k_%s_n" % str(dot.evo))) if str(dot.evo) != "" else ""]])
			x += 28.0
			if x > size.x - 24.0:
				break

func _get_tooltip(at_position: Vector2) -> String:
	for t in _tips:
		if (t[0] as Rect2).has_point(at_position):
			return str(t[1])
	return ""
