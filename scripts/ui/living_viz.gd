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
const TYPE_COL := {"complementaire": Color("35b8c8"), "rivale": Color("d9955a"), "protectrice": Color("7ab648"), "antagoniste": Color("c0392b"), "fusionnelle": Color("e5ae52")}
const TIER_COL := [Color("5a4a34"), Color("8f7f60"), Color("35b8c8"), Color("7ab648"), Color("e8b45c")]

var kind := "timeline"
var d: Dictionary = {}
var _tips: Array = []      # [Rect2, texte] pour les infobulles (grille, carte des liens)
var _time := 0.0
var _animated := false

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

static func web(center: String, links: Array, icon: Texture2D = null) -> LivingViz:
	var v := LivingViz.new()
	v.kind = "web"
	v.d = {"center": center, "links": links, "icon": icon}
	v.custom_minimum_size = Vector2(0, 390)
	return v

func _ready() -> void:
	_animated = kind == "web" and not Settings.reduced_motion
	set_process(_animated)

func _process(dt: float) -> void:
	_time += dt
	queue_redraw()

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
	var evs: Array = []
	for k in [str(desc.evolved), str(desc.get("evolved2", ""))]:
		if k != "":
			evs.append(k)
	var evolved := str(desc.evolved)
	var need_aff := LivingSkills.EVOLVE_AFF if evs.is_empty() else LivingSkills.LINK_AFF      # 1re évolution : « attachée » ; seconde : « liée »
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
		var chosen := evs.has(kindk)
		var other := evs.size() >= 2 and not chosen
		var ready := (desc.available as Array).has(kindk)
		var tr := int((desc.traits as Dictionary).get(str(b.trait), 0))
		var aff_ok := float(desc.affinity) >= need_aff
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
		_bar(Rect2(r.position.x + 10.0, r.position.y + 39.0, half - 4.0, 8.0), minf(1.0, float(desc.affinity) / need_aff), CYAN if aff_ok else BRONZE)
		_t(Vector2(r.position.x + 10.0 + half - 4.0 - 60.0, r.position.y + 34.0), "%d / %d" % [mini(int(desc.affinity), 99), int(need_aff)], 11, PARCH if aff_ok else DIM, false, HORIZONTAL_ALIGNMENT_RIGHT, 60.0)
		var x2 := r.position.x + 20.0 + half
		_t(Vector2(x2, r.position.y + 34.0), L.t("ui.living.trait_%s" % str(b.trait)), 11, DIM)
		_bar(Rect2(x2, r.position.y + 39.0, half - 4.0, 8.0), float(tr) / float(LivingSkills.TRAIT_MIN), GOLD if tr_ok else BRONZE)
		_t(Vector2(x2 + half - 4.0 - 60.0, r.position.y + 34.0), "%d / %d" % [tr, LivingSkills.TRAIT_MIN], 11, PARCH if tr_ok else DIM, false, HORIZONTAL_ALIGNMENT_RIGHT, 60.0)

# ------------------------------------------------------------------ carte des liens (rose des vents)

## Carte d'atlas : la compétence est au centre d'une rose des vents (anneaux de portée, graduations, pointes comme sur le logo) ; chaque lien est une
## route de carte vers un médaillon. Le style de la route dit le type de lien (plein, pointillé, double, étoilé), les losanges le niveau, et une lueur
## la parcourt lentement (immobile avec « Mouvements réduits »).
func _bez(p0: Vector2, c: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * u * u + c * 2.0 * u * t + p2 * t * t

func _route(p0: Vector2, c: Vector2, p2: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 33:
		out.append(_bez(p0, c, p2, float(i) / 32.0))
	return out

func _diamond_at(pos: Vector2, r: float, col: Color, filled: bool = true) -> void:
	var pts := PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r * 0.8, 0), pos + Vector2(0, r), pos + Vector2(-r * 0.8, 0)])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		var cl := pts.duplicate()
		cl.append(pts[0])
		draw_polyline(cl, col, 1.2, true)

func _draw_web() -> void:
	var links: Array = d.links
	var c := Vector2(size.x * 0.5, size.y * 0.5 - 10.0)
	var rx := minf(size.x * 0.5 - 92.0, size.y * 0.5 - 92.0)      # une vraie rose des vents : cercles, pas ellipses
	var ry := rx
	var n := links.size()
	var cop := Color("986A42")
	var cop_d := Color("5a4129")
	var ivory := Color("D8C8A4")
	var amber := Color("E5AE52")
	# fond : voile sombre en ellipse (le dessin se détache de la pierre) et rose des vents
	draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx + 18.0, Color(0.03, 0.025, 0.02, 0.55))
	for k in [0.38, 0.7, 1.0]:
		draw_arc(Vector2.ZERO, rx * k, 0.0, TAU, 72, Color(cop_d, 0.9 if k < 1.0 else 1.0), 1.0, true)
	for i in 72:      # graduations du cercle extérieur : plus longues tous les 90°, et tous les 30°
		var a := TAU * float(i) / 72.0
		var len := 9.0 if i % 18 == 0 else (6.0 if i % 6 == 0 else 3.0)
		draw_line(Vector2(cos(a), sin(a)) * rx, Vector2(cos(a), sin(a)) * (rx - len), Color(cop, 0.85 if i % 6 == 0 else 0.5), 1.0, true)
	for i in 8:      # huit pointes effilées, comme le compas du logo
		var a := TAU * float(i) / 8.0 + PI * 0.25 * 0.0
		var long := i % 2 == 0
		var tip := Vector2(cos(a), sin(a)) * (rx * (1.12 if long else 0.78))
		var perp := Vector2(-sin(a), cos(a)) * (5.0 if long else 3.0)
		var base := Vector2(cos(a), sin(a)) * 24.0
		draw_colored_polygon(PackedVector2Array([base + perp, tip, base - perp]), Color(cop, 0.32 if long else 0.2))
		draw_line(base, tip, Color(cop, 0.55), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_tips.clear()
	# routes
	for i in n:
		var l: Dictionary = links[i]
		var ang := -PI * 0.5 + TAU * float(i) / float(maxi(1, n))
		var p := c + Vector2(cos(ang) * rx, sin(ang) * ry)
		var typ := str(l.type)
		var lvl := int(l.level)
		var col: Color = TYPE_COL.get(typ, BRONZE)
		var from := c + (p - c).normalized() * 26.0
		var to := p - (p - c).normalized() * (11.0 + 2.0 * float(lvl))
		var perp := (to - from).orthogonal().normalized() * (0.16 * from.distance_to(to)) * (1.0 if i % 2 == 0 else -1.0)
		var ctrl := (from + to) * 0.5 + perp
		var pts := _route(from, ctrl, to)
		draw_polyline(pts, Color(0.02, 0.015, 0.01, 0.9), 4.0 + float(lvl), true)      # liseré sombre sous la route
		match typ:
			"rivale":      # pointillé : deux voix qui se répondent sans se mêler
				for k in range(0, 32, 2):
					draw_line(pts[k], pts[k + 1], col, 1.6 + 0.5 * float(lvl), true)
			"antagoniste":      # double filet barré : tension, sans pénalité
				var off := Vector2(pts[16] - pts[15]).orthogonal().normalized() * 2.2
				draw_polyline(_shift(pts, off), col, 1.2, true)
				draw_polyline(_shift(pts, -off), col, 1.2, true)
				var m := pts[16]
				draw_line(m + Vector2(-4, -4), m + Vector2(4, 4), col, 1.6, true)
				draw_line(m + Vector2(-4, 4), m + Vector2(4, -4), col, 1.6, true)
			"fusionnelle":      # route dorée à halo
				draw_polyline(pts, Color(col, 0.2), 8.0, true)
				draw_polyline(pts, col, 2.4 + 0.5 * float(lvl), true)
			"protectrice":      # route pleine et flèche vers la compétence protégée
				draw_polyline(pts, col, 1.8 + 0.5 * float(lvl), true)
				var dir := (pts[32] - pts[29]).normalized()
				var tipp := pts[32]
				draw_colored_polygon(PackedVector2Array([tipp, tipp - dir * 9.0 + dir.orthogonal() * 4.0, tipp - dir * 9.0 - dir.orthogonal() * 4.0]), col)
			_:
				draw_polyline(pts, col, 1.8 + 0.5 * float(lvl), true)
		# niveau : losanges le long de la route (vide = lien à peine tissé)
		var pips := maxi(1, lvl)
		for k in pips:
			var tt := 0.5 + (float(k) - float(pips - 1) * 0.5) * 0.1
			_diamond_at(_bez(from, ctrl, to, tt) + Vector2(0, -0.0), 3.6, col if lvl > 0 else Color(col, 0.7), lvl > 0)
		# lueur qui parcourt la route
		if _animated:
			var tl := fmod(_time * 0.12 + float(i) * 0.27, 1.0)
			var gp := _bez(from, ctrl, to, tl)
			draw_circle(gp, 7.0, Color(col, 0.16))
			draw_circle(gp, 2.6, Color(1.0, 0.95, 0.8, 0.95))
		# médaillon du lien
		var rad := 9.0 + 2.0 * float(lvl)
		draw_circle(p, rad + 3.0, Color(0.03, 0.025, 0.02, 0.95))
		draw_circle(p, rad, Color("17130e"))
		draw_arc(p, rad, 0.0, TAU, 40, col, 1.6, true)
		draw_arc(p, rad - 3.0, 0.0, TAU, 40, Color(cop_d, 0.9), 1.0, true)
		_diamond_at(p, rad * 0.42, col)
		# nom, à l'extérieur du médaillon (de côté pour les liens à gauche et à droite)
		var lab := _fit(str(l.name), 12, 150.0)
		var sub := "%s · %s" % [L.t("ui.living.rel_%s" % typ), L.t("ui.living.rel_level") % lvl]
		var ft := UiTheme.font(UiTheme.F_TITLE)
		if absf(cos(ang)) > 0.5:      # liens de gauche et de droite : légende à côté du médaillon, sur deux lignes au plus
			var right := cos(ang) > 0.0
			var x0 := p.x + rad + 8.0 if right else p.x - rad - 8.0 - 108.0
			var al := HORIZONTAL_ALIGNMENT_LEFT if right else HORIZONTAL_ALIGNMENT_RIGHT
			var nh := ft.get_multiline_string_size(str(l.name), al, 108.0, 11, 2).y
			var top := p.y - (nh + 26.0) * 0.5
			_plate(Rect2(x0 - 3.0, top - 3.0, 114.0, nh + 32.0))
			draw_multiline_string(ft, Vector2(x0, top + 10.0), str(l.name), al, 108.0, 11, 2, ivory)
			draw_string(_f(), Vector2(x0, top + nh + 9.0), L.t("ui.living.rel_%s" % typ), al, 108.0, 10, col)
			draw_string(_f(), Vector2(x0, top + nh + 21.0), L.t("ui.living.rel_level") % lvl, al, 108.0, 10, col)
		else:
			var up := p.y < c.y - 4.0      # au-dessus du médaillon pour le lien du haut, en dessous pour celui du bas
			var y0 := p.y - rad - 30.0 if up else p.y + rad + 8.0
			_plate(Rect2(p.x - 78.0, y0 - 2.0, 156.0, 34.0))
			draw_string(ft, Vector2(p.x - 75.0, y0 + 12.0), lab, HORIZONTAL_ALIGNMENT_CENTER, 150.0, 12, ivory)
			draw_string(_f(), Vector2(p.x - 75.0, y0 + 26.0), sub, HORIZONTAL_ALIGNMENT_CENTER, 150.0, 11, col)
		_tips.append([Rect2(p.x - rad - 4.0, p.y - rad - 4.0, rad * 2.0 + 8.0, rad * 2.0 + 8.0), "%s\n%s — %s\n%s" % [str(l.name), L.t("ui.living.rel_%s" % typ), L.t("ui.living.rel_level") % lvl, L.t("ui.living.reld_%s" % typ)]])
	# médaillon central
	draw_circle(c, 29.0, Color(amber, 0.12))
	draw_circle(c, 25.0, Color(0.03, 0.025, 0.02, 0.97))
	draw_arc(c, 25.0, 0.0, TAU, 56, amber, 1.8, true)
	draw_arc(c, 21.0, 0.0, TAU, 56, Color(cop, 0.9), 1.0, true)
	var ic: Texture2D = d.get("icon", null)
	if ic != null:
		draw_texture_rect(ic, Rect2(c.x - 13.0, c.y - 13.0, 26.0, 26.0), false)
	else:
		_diamond_at(c, 9.0, amber)
	_plate(Rect2(c.x - 66.0, c.y + 29.0, 132.0, 19.0))
	draw_string(UiTheme.font(UiTheme.F_TITLE_BOLD), Vector2(c.x - 62.0, c.y + 43.0), _fit(str(d.center), 12, 124.0, true), HORIZONTAL_ALIGNMENT_CENTER, 124.0, 12, amber)
	if n == 0:
		_t(Vector2(0, c.y - 50.0), L.t("ui.living.no_relations"), 12, DIM, false, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_legend(links)

func _shift(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + off)
	return out

func _plate(r: Rect2) -> void:
	draw_rect(r, Color(0.03, 0.025, 0.02, 0.72))

## Légende : un trait d'échantillon par type de lien présent (le style de la route dit le type).
func _legend(links: Array) -> void:
	var seen: Array = []
	for l in links:
		if not seen.has(str(l.type)):
			seen.append(str(l.type))
	var y := size.y - 8.0
	var x := 6.0
	for typ in seen:
		var col: Color = TYPE_COL.get(typ, BRONZE)
		var a := Vector2(x, y - 4.0)
		var b := Vector2(x + 26.0, y - 4.0)
		match typ:
			"rivale":
				draw_line(a, a + Vector2(6, 0), col, 1.8)
				draw_line(a + Vector2(10, 0), a + Vector2(16, 0), col, 1.8)
				draw_line(a + Vector2(20, 0), b, col, 1.8)
			"antagoniste":
				draw_line(a + Vector2(0, -2), b + Vector2(0, -2), col, 1.0)
				draw_line(a + Vector2(0, 2), b + Vector2(0, 2), col, 1.0)
			_:
				draw_line(a, b, col, 2.4 if typ == "fusionnelle" else 1.8)
		var txt := L.t("ui.living.rel_%s" % str(typ))
		_t(Vector2(x + 32.0, y), txt, 10, DIM)
		x += 36.0 + _f().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
		if x > size.x - 80.0:
			break

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
