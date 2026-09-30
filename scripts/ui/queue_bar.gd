class_name QueueBar
extends Control
## File d'initiative du combat (port de QueueFX du JS) : chaîne horizontale sous la vue 3D, médaillons-crânes
## aux extrémités, curseur à lames croisées sur celui qui agit, pastilles qui glissent d'un tour à l'autre
## (les précédents restent en grisé à gauche), barre de vie, pastille de statut, gerbe d'étincelles à la mort.

const PAD := 30.0            # marge de chaque côté (les crânes y logent)
const LINK := 24.0           # période d'un maillon de chaîne (SVG chainH)

var gs: GameState
var ctrl: CombatController
var _recs: Dictionary = {}       # clé -> enregistrement (pastille actuelle/à venir)
var _past: Array = []
var _fading: Array = []
var _bursts: Array = []
var _chain_pos: float = 0.0
var _chain_target: float = 0.0
var _prev_seq: int = -1
var _prev_items: Array = []
var _sig: String = ""
var _show: float = 0.0           # 0 (caché) .. 1 (visible), animé
var _want_h: float = 56.0
var _cursor_x: float = -1.0

static var _halo_tex: Texture2D

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 0)
	ctrl.changed.connect(_on_changed)
	resized.connect(func(): _sig = "")

func in_combat() -> bool:
	return ctrl != null and ctrl.combat != null and ctrl.in_combat()

func set_target_height(h: float) -> void:
	_want_h = h

# ------------------------------------------------------------------ mise en page

func _layout() -> Dictionary:
	var w := maxf(10.0, size.x - PAD * 2.0)
	var h := size.y
	var sz := minf(46.0, maxf(h, 64.0) * 0.64)
	var m := sz * 0.9
	var s0 := maxi(3, int(floor((w - 2.0 * m) / (sz * 1.25))) + 1)
	var slots := s0 if s0 % 2 == 1 else s0 - 1
	var slot_w := (w - 2.0 * m) / float(slots - 1)
	var n_past := (slots - 1) / 2
	return {"size": sz, "slotW": slot_w, "nPast": n_past, "slots": slots, "xc": PAD + m + n_past * slot_w, "cy": h * 0.5}

func capacity() -> int:
	var l := _layout()
	return int(l.slots) - int(l.nPast)

# ------------------------------------------------------------------ données

func _entries(n: int) -> Array:
	var out: Array = []
	if not in_combat():
		return out
	var keys: Array = ctrl.combat.upcoming(n)
	var seq0: int = ctrl.combat.turn_seq
	var occ := {}
	for i in keys.size():
		var key: String = keys[i]
		var o: int = int(occ.get(key, 0))
		occ[key] = o + 1
		var suffix := "_occ%d" % o if o > 0 else ""
		var e := {"turnSeq": seq0 + i, "current": i == 0}
		if key.begins_with("char_"):
			var c := gs.char_by_id(key.substr(5))
			if c.is_empty() or int(c.hp) <= 0:
				continue
			var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
			e["key"] = str(c.id) + suffix
			e["kind"] = "char"
			e["icon"] = str(cls.get("icon", ""))
			e["portrait"] = IconResolver.portrait_path(c, gs.cfg)
			e["hp"] = clampf(float(c.hp) / maxf(1.0, float(c.maxHp)), 0.0, 1.0)
			var eff := Statuses.active(c)
			e["status"] = str(Statuses.def(str(eff[0].type)).get("icon", "")) if eff.size() > 0 else ""
		else:
			var rest := key.substr(4)
			var hi := rest.find("#")
			var mid := rest if hi < 0 else rest.substr(0, hi)
			var mi := -1 if hi < 0 else int(rest.substr(hi + 1))
			var def := ctrl.combat.monster_def(mid)
			var st: Dictionary = ctrl.combat.lstate().monsters.get(mid, {})
			if def.is_empty() or st.is_empty() or not st.alive:
				continue
			var holder: Dictionary = st
			if mi >= 0:
				if not st.has("members") or mi >= st.members.size() or not st.members[mi].alive:
					continue
				holder = st.members[mi]
			e["key"] = mid + ("_%d" % mi if mi >= 0 else "") + suffix
			e["kind"] = "mon"
			e["icon"] = str(def.get("icon", ""))
			e["hp"] = clampf(float(holder.hp) / maxf(1.0, float(holder.maxHp)), 0.0, 1.0)
			e["status"] = ""
		out.append(e)
	return out

func _on_changed() -> void:
	if not in_combat():
		_clear()
		return
	_update(_entries(capacity()))

func _clear() -> void:
	for r in _recs.values() + _past + _fading:
		r.chip.queue_free()
	_recs.clear()
	_past.clear()
	_fading.clear()
	_bursts.clear()
	_chain_pos = 0.0
	_chain_target = 0.0
	_prev_items = []
	_prev_seq = -1

func _strip_occ(k: String) -> String:
	var i := k.rfind("_occ")
	return k.substr(0, i) if i >= 0 else k

func _update(entries: Array) -> void:
	if size.x < 20.0 or size.y < 10.0:
		return
	var L := _layout()
	var sz: float = L.size
	var slot_w: float = L.slotW
	var xc: float = L.xc
	_cursor_x = xc
	var used := {}
	var seq0: int = int(entries[0].turnSeq) if entries.size() > 0 else -1
	if not _prev_items.is_empty() and seq0 >= 0 and seq0 > _prev_seq:
		_chain_target += float(seq0 - _prev_seq) * slot_w
		for p in _prev_items:
			if int(p.turnSeq) >= seq0:
				continue
			var old = _recs.get(p.key)
			if old == null:
				continue
			_recs.erase(p.key)
			old.dim = true
			old.chip.halo_on = false
			old.chip.status_on = false
			old.base = sz * 0.82
			_past.append(old)
			var b := _strip_occ(p.key)
			var n := 1
			while _recs.has(b + "_occ%d" % n):
				var r = _recs[b + "_occ%d" % n]
				_recs.erase(b + "_occ%d" % n)
				_recs[b if n == 1 else b + "_occ%d" % (n - 1)] = r
				n += 1
	while _past.size() > int(L.nPast):
		var f = _past.pop_front()
		f.life = 0.0
		f.op0 = f.op
		_fading.append(f)
	for j in _past.size():
		_past[j].tx = xc - float(_past.size() - j) * slot_w
		_past[j].base = sz * 0.82
	_prev_seq = seq0
	_prev_items = entries.map(func(e): return {"key": e.key, "turnSeq": e.turnSeq})
	for i in entries.size():
		var e: Dictionary = entries[i]
		used[e.key] = true
		var tx := xc + float(i) * slot_w
		var base: float = sz * 1.12 if e.current else sz
		var rec = _recs.get(e.key)
		if rec == null:
			var chip := QueueChip.new()
			add_child(chip)
			chip.position = Vector2(tx + slot_w, float(L.cy))
			rec = {"chip": chip, "x": tx + slot_w, "tx": tx, "base": base, "op": 0.0, "dim": false, "life": 0.0, "op0": 1.0, "icon_key": ""}
			_recs[e.key] = rec
			chip.is_char = e.kind == "char"
			chip.bar_color = Color("c05a3a") if e.kind == "mon" else Color("7fae4a")
		rec.tx = tx
		rec.base = base
		var ikey: String = e.kind + "|" + str(e.icon)
		if rec.icon_key != ikey:
			rec.icon_key = ikey
			rec.chip.tex = _icon_tex(e)
		rec.chip.hp = float(e.hp)
		rec.chip.halo_on = bool(e.current)
		if e.current:
			rec.chip.halo_col = Color("ff4d3d") if e.kind == "mon" else Color("ffcf7a")
			rec.chip.halo_a = 0.65 if e.kind == "mon" else 0.48
		rec.chip.status = str(e.status)
		rec.chip.status_on = str(e.status) != ""
	for k in _recs.keys():
		if used.has(k):
			continue
		var rec = _recs[k]
		_recs.erase(k)
		if rec.tx >= xc + (entries.size() - 1.5) * slot_w or rec.op < 0.5:
			rec.life = 0.0
			rec.op0 = rec.op
			_fading.append(rec)
		else:
			_burst(Vector2(rec.x, float(L.cy)), rec.chip.bar_color)
			rec.chip.queue_free()

func _icon_tex(e: Dictionary) -> Texture2D:
	if e.kind == "char":
		var t := IconResolver.texture(str(e.icon)) if str(e.icon) != "" else null
		if t == null and str(e.portrait) != "":
			t = load(str(e.portrait))
		return t
	return IconResolver.texture(str(e.icon))

func _burst(at: Vector2, col: Color) -> void:
	for i in 8:
		var ang := randf() * TAU
		var spd := 50.0 + randf() * 90.0
		_bursts.append({"p": at, "v": Vector2(cos(ang), sin(ang)) * spd, "life": 0.0, "max": 0.4 + randf() * 0.3, "col": col})

# ------------------------------------------------------------------ animation / affichage

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	var want := 1.0 if in_combat() else 0.0
	_show = move_toward(_show, want, dt / 0.3)
	var h := _want_h * _show
	if absf(custom_minimum_size.y - h) > 0.5:
		custom_minimum_size.y = h
	visible = _show > 0.001
	if not visible:
		return
	if in_combat() and _sig != str(size):
		_sig = str(size)
		_update(_entries(capacity()))
	var k4 := minf(1.0, dt * 4.0)
	_chain_pos += (_chain_target - _chain_pos) * k4
	var t := Time.get_ticks_msec() * 0.001
	for i in range(_fading.size() - 1, -1, -1):
		var f = _fading[i]
		f.life += dt
		var p := minf(1.0, f.life / 0.45)
		f.x -= 40.0 * dt
		f.chip.position.x = f.x
		f.chip.position.y += 30.0 * dt
		f.chip.modulate.a = float(f.op0) * (1.0 - p)
		if p >= 1.0:
			f.chip.queue_free()
			_fading.remove_at(i)
	var cy := size.y * 0.5
	for rec in _recs.values() + _past:
		rec.x += (rec.tx - rec.x) * k4
		var vis: float = (0.45 if rec.dim else 1.0) if (rec.x > PAD * 0.5 and rec.x < size.x - PAD * 0.5) else 0.0
		rec.op += (vis - rec.op) * k4
		var chip: QueueChip = rec.chip
		chip.position = Vector2(rec.x, cy)
		chip.modulate.a = rec.op
		chip.base = rec.base
		chip.dim = rec.dim
		chip.pulse = 1.0 + sin(t * 5.0) * 0.07
		chip.queue_redraw()
	for i in range(_bursts.size() - 1, -1, -1):
		var b = _bursts[i]
		b.life += dt
		if b.life >= b.max:
			_bursts.remove_at(i)
			continue
		b.p += b.v * dt
		b.v.y += 70.0 * dt
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if h < 4.0:
		return
	var cy := h * 0.5
	# chaîne (SVG chainH défilant, recadrée entre les deux crânes)
	var chain := SvgArt.tex("chainH", maxf(2.0, h / 12.0 * 0.0 + 2.0))
	if chain != null:
		var ch := 12.0 * (h / 44.0 if h < 44.0 else 1.0)
		ch = clampf(ch, 9.0, 12.0)
		var x0 := PAD
		var x1 := w - PAD
		var off := fposmod(_chain_pos, LINK * ch / 12.0)
		var lw := LINK * ch / 12.0
		var x := x0 - off
		while x < x1:
			var dx0 := maxf(x, x0)
			var dx1 := minf(x + lw, x1)
			if dx1 > dx0:
				var u0 := (dx0 - x) / lw
				var u1 := (dx1 - x) / lw
				var tw := chain.get_size().x
				draw_texture_rect_region(chain, Rect2(dx0, cy - ch * 0.5, dx1 - dx0, ch), Rect2(u0 * tw, 0, (u1 - u0) * tw, chain.get_size().y))
			x += lw
	# médaillons-crânes
	var r := clampf(h * 0.3, 9.0, 13.0)
	for cx in [3.0 + r, w - 3.0 - r]:
		var c := Vector2(cx, cy)
		draw_circle(c, r + 4.0, Color("070504"))
		draw_circle(c, r + 3.0, Color("5a4630"))
		draw_circle(c, r + 2.0, Color("070504"))
		draw_circle(c, r, Color("1a120c"))
		draw_circle(c - Vector2(0, r * 0.24), r * 0.8, Color("2c2217"))
		var sk := SvgArt.tex("skull", maxf(1.0, r * 1.28 / 40.0 * 2.0))
		if sk != null:
			var ss := r * 2.0 * 0.64
			draw_texture_rect(sk, Rect2(c - Vector2(ss, ss) * 0.5, Vector2(ss, ss)), false)
	# curseur (lames croisées + anneau) sous la pastille courante
	if _cursor_x >= 0.0 and in_combat():
		_draw_cursor(Vector2(_cursor_x, cy), float(_layout().size) * 1.12 + 16.0)
	# étincelles
	for b in _bursts:
		var a: float = 1.0 - float(b.life) / float(b.max)
		var col: Color = b.col
		draw_circle(b.p, 4.5 * (1.0 - 0.5 * (1.0 - a)), Color(col.r, col.g, col.b, a * 0.9))

func _draw_cursor(c: Vector2, frame: float) -> void:
	var hh := frame * 0.5 + 14.0
	for ang in [PI / 4.0, -PI / 4.0]:
		draw_set_transform(c, ang, Vector2.ONE)
		var w := 8.0
		var lc := Color("7d868d")
		var hi := Color("f2f4f5")
		var lo := Color("5d656c")
		var dk := Color("23282c")
		draw_polygon(PackedVector2Array([Vector2(0, -hh), Vector2(-w, 0), Vector2(0, hh)]), PackedColorArray([hi, lc, hi]))
		draw_polygon(PackedVector2Array([Vector2(0, -hh), Vector2(w, 0), Vector2(0, hh)]), PackedColorArray([lo, dk, lo]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var rr := frame * 0.5 - 5.0
	draw_circle(c + Vector2(0, 3), rr + 3.0, Color(0, 0, 0, 0.35))
	draw_circle(c, rr + 3.0, Color("070504"))
	draw_circle(c, rr + 2.0, Color("7a6242"))
	draw_circle(c, rr + 1.0, Color("070504"))
	draw_circle(c, rr, Color("2e251c"))
	draw_circle(c, rr - 3.0, Color("0d0906"))
	draw_circle(c - Vector2(0, rr * 0.2), (rr - 3.0) * 0.82, Color("211911"))

static func halo_texture() -> Texture2D:
	if _halo_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.156, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 0.88, 0.59, 0.95), Color(1, 0.88, 0.59, 0.95), Color(1, 0.71, 0.24, 0.5), Color(1, 0.59, 0.12, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_halo_tex = t
	return _halo_tex


## Une pastille de la file : halo additif, médaillon (personnage) ou sprite (monstre), barre de vie, statut.
class QueueChip extends Node2D:
	var tex: Texture2D
	var is_char: bool = false
	var base: float = 40.0
	var hp: float = 1.0
	var halo_on: bool = false
	var halo_col: Color = Color("ffcf7a")
	var halo_a: float = 0.5
	var pulse: float = 1.0
	var dim: bool = false
	var status: String = ""
	var status_on: bool = false
	var bar_color: Color = Color("7fae4a")
	var _halo: Sprite2D

	func _ready() -> void:
		_halo = Sprite2D.new()
		_halo.texture = QueueBar.halo_texture()
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_halo.material = m
		_halo.show_behind_parent = true
		add_child(_halo)

	func _draw() -> void:
		if _halo != null:
			_halo.visible = halo_on
			var s := base * 1.55 * pulse / 128.0
			_halo.scale = Vector2(s, s)
			_halo.modulate = Color(halo_col.r, halo_col.g, halo_col.b, halo_a)
		var tint := Color("8a8378") if dim else Color.WHITE
		var half := base * 0.5
		if is_char:
			draw_circle(Vector2.ZERO, base * 58.0 / 128.0, Color(0.1, 0.067, 0.035, 0.95))
			if tex != null:
				_draw_disc(tex, base * 50.0 / 128.0, tint)
			draw_arc(Vector2.ZERO, base * 50.0 / 128.0, 0.0, TAU, 40, Color("e8b45c").darkened(0.35) if dim else Color("e8b45c"), maxf(1.5, base * 6.0 / 128.0), true)
		elif tex != null:
			draw_texture_rect(tex, Rect2(-half, -half, base, base), false, tint)
		# barre de vie
		var bw := base * 0.85 * maxf(0.04, hp)
		var bc := bar_color
		bc.a = 0.5 if dim else 1.0
		draw_rect(Rect2(-bw * 0.5, base * 0.62 - 2.0, bw, 4.0), bc)
		# statut
		if status_on and not dim:
			var bs := base * 0.42
			var p := Vector2(base * 0.36, -base * 0.36)
			draw_circle(p, bs * 0.44, Color(0.078, 0.047, 0.031, 0.92))
			draw_arc(p, bs * 0.44, 0.0, TAU, 24, Color("e8b45c"), maxf(1.0, bs * 3.0 / 64.0), true)
			var f := UiTheme.font(UiTheme.F_TITLE)
			var fs := int(bs * 34.0 / 64.0 * 1.25)
			var ts := f.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, p + Vector2(-ts.x * 0.5, fs * 0.36), status, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)

	## Dessine `t` rognée en disque de rayon `r` (polygone texturé).
	func _draw_disc(t: Texture2D, r: float, tint: Color) -> void:
		var n := 40
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in n:
			var a := TAU * float(i) / float(n)
			pts.append(Vector2(cos(a), sin(a)) * r)
			uvs.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
		draw_colored_polygon(pts, tint, uvs, t)
