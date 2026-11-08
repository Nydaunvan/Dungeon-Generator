class_name LavaFx
extends RefCounted
## Magma décorative du thème « lava » v2 (Les Forges du monde brisé) : fissures et canaux de lave incandescente au pied des murs, failles verticales dans
## certains pans, lumières chaudes localisées, braises et fumée. PUREMENT VISUEL : aucun nœud de collision, rien dans la grille, le générateur, les déplacements,
## les portes, les escaliers ou le rejeu. Placement déterministe : uniquement la grille et l'identifiant du niveau (jamais GameRng ni le hasard global).
## L'animation (shader assets/shaders/magma.gdshader) ne dépend que du temps d'affichage : elle n'influence jamais le jeu.
##
## Trois états de magma, chacun un matériau partagé : 0 presque refroidie (croûte noire, quelques veines), 1 active, 2 très incandescente.
## Effets (braises, fumée, lumières) : réglage « Particules » de Settings (0 = aucun), lumières limitées par « Torches avec lumière ».

const CELL := LevelBuilder.CELL
const HALF := CELL * 0.5
const SHADER := "res://assets/shaders/magma.gdshader"
const MAX_LIGHTS := 10
const LIGHT_GAP := 9.0          # écart minimal entre deux lumières de magma (unités)
const MAX_EMBERS := 18
const MAX_SMOKE := 8
## Dernier niveau posé : {"floor": n, "wall": n, "lights": n, "embers": n, "smoke": n} (tests, mesures).
static var last_stats: Dictionary = {}
## Interrupteurs (outils) : false = ne pose pas l'élément.
static var enabled := true
static var effects := true

static var _shader: Shader
static var _mats: Array = []
static var _ember_mat: StandardMaterial3D
static var _smoke_mat: StandardMaterial3D
static var _ember_mesh: QuadMesh
static var _smoke_mesh: QuadMesh

static func applies(theme: String, level: Dictionary) -> bool:
	return enabled and theme == "lava" and ThemeMaterials.lava2_on(theme) and not bool(level.get("outdoor", false))

static func _h(a: int, b: int, c: int) -> int:
	return KitDecor._h(a, b, c)

## Matériau partagé de l'état `s` (0, 1 ou 2).
static func material(s: int) -> ShaderMaterial:
	if _shader == null:
		_shader = load(SHADER) as Shader
	while _mats.size() < 3:
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("state", float(_mats.size()))
		_mats.append(m)
	return _mats[clampi(s, 0, 2)]

# ------------------------------------------------------------------ plan

## Plan de pose (pur calcul) : {"floor": [{pos, t, along, len, w, off, d, state, key}], "wall": [{pos, d, t, state}], "lights": [Vector3], "embers": [Vector3], "smoke": [Vector3]}.
static func plan(level: Dictionary, grid: DungeonGrid, niches: Dictionary, holes: Dictionary) -> Dictionary:
	var seed := str(level.get("id", "")).hash()
	var special := KitDecor._special_cells(level, RoomDecor._blocked_cells(level), niches)
	var ridx := RoomMap.index(RoomMap.detect(level.mapRows))
	var rsize := {}
	for c in ridx:
		rsize[ridx[c]] = int(rsize.get(ridx[c], 0)) + 1
	var floors: Array = []
	var walls: Array = []
	var anchors: Array = []      # points d'ancrage des effets : {pos, state, vent}
	for y in grid.height:
		for x in grid.width:
			var ch := grid.cell(x, y)
			if ch != ".":
				continue
			var cell := Vector2i(x, y)
			if special.has(cell) or KitDecor._near_special(special, grid, cell, 1):
				continue
			var big := ridx.has(cell) and int(rsize.get(ridx[cell], 0)) >= 12
			var p_floor := 3 if big else 5      # une chance sur p
			for di in 4:
				var d: Vector2i = DungeonGrid.DIRS[di]
				if grid.cell(x + d.x, y + d.y) != "#" or KitDecor._face_cut(cell, d, niches, holes):
					continue
				var t := Vector2i(1, 0) if d.x == 0 else Vector2i(0, 1)
				var along := x if t.x != 0 else y
				var c := Vector3(x * CELL, 0.0, y * CELL)
				var edge := c + Vector3(d.x * HALF, 0.0, d.y * HALF)
				var hh := _h(x, y, seed ^ (di * 2713 + 41))
				var state := 0 if hh % 10 < 2 else (1 if hh % 10 < 7 else 2)
				# fissure de sol : canal de deux cases si le voisin suit le même mur, sinon une case
				if along % 2 == 0 and (hh >> 4) % p_floor == 0:
					var nb := cell + t
					var two := grid.cell(nb.x, nb.y) == "." and grid.cell(nb.x + d.x, nb.y + d.y) == "#" and not special.has(nb) \
							and not KitDecor._near_special(special, grid, nb, 1) and not KitDecor._face_cut(nb, d, niches, holes)
					var len_ := 7.4 if two else 3.2
					var mid := edge + Vector3(t.x, 0.0, t.y) * (HALF if two else 0.0)
					var w := 0.55 + 0.5 * float((hh >> 9) % 5) / 4.0
					var off := 0.30 + 0.25 * float((hh >> 13) % 3) / 2.0
					floors.append({"pos": mid, "t": t, "len": len_, "w": w, "off": off, "d": d, "state": state, "u": float(hh % 997)})
					anchors.append({"pos": mid - Vector3(d.x, 0.0, d.y) * (off + w * 0.5), "state": state, "vent": false, "key": hh})
				# faille murale verticale : pans sans torche et sans ornement, rare
				elif (x + y) % 2 != 0 and (hh >> 4) % (4 if big else 6) == 1 and _h(x, y, seed ^ (di * 131 + 7)) % 4 != 0:
					var wp := edge - Vector3(d.x, 0.0, d.y) * 0.07
					walls.append({"pos": wp, "d": d, "t": t, "state": maxi(state, 1), "u": float(hh % 991)})
					anchors.append({"pos": wp - Vector3(d.x, 0.0, d.y) * 0.5 + Vector3(0, 1.5, 0), "state": maxi(state, 1), "vent": true, "key": hh})
	# lumières, braises, fumée : choisies parmi les ancres, dans l'ordre de lecture (stable), avec écart minimal
	var lights: Array = []
	var embers: Array = []
	var smoke: Array = []
	var lpos: Array = []
	for a in anchors:
		var pos: Vector3 = a.pos
		var st: int = a.state
		var far := true
		for q in lpos:
			if (q as Vector3).distance_to(pos) < LIGHT_GAP:
				far = false
				break
		if far and st >= 1 and lights.size() < MAX_LIGHTS:
			lights.append({"pos": pos + Vector3(0, 0.9, 0), "state": st})
			lpos.append(pos)
		if st >= 1 and embers.size() < MAX_EMBERS and int(a.key >> 3) % 2 == 0:
			embers.append({"pos": pos, "state": st})
		if a.vent and smoke.size() < MAX_SMOKE:
			smoke.append({"pos": pos})
	return {"floor": floors, "wall": walls, "lights": lights, "embers": embers, "smoke": smoke}

# ------------------------------------------------------------------ pose

static func add(view: LevelView, level: Dictionary, grid: DungeonGrid, theme: String, niches: Dictionary, holes: Dictionary) -> void:
	last_stats = {}
	if not applies(theme, level):
		return
	var pl := plan(level, grid, niches, holes)
	var root := Node3D.new()
	root.name = "LavaFx"
	view.add_child(root)
	var groups := {}      # "état|bloc x|bloc z" -> {v, c, uv}
	var span := CELL * float(LevelBuilder.CHUNK)
	for f in pl.floor:
		var t: Vector2i = f.t
		var d: Vector2i = f.d
		var ax := Vector3(t.x, 0.0, t.y)
		var nrm := Vector3(-d.x, 0.0, -d.y)      # vers l'intérieur de la case
		var base: Vector3 = f.pos + Vector3(0, 0.02, 0) + nrm * float(f.off)
		var a := base - ax * (float(f.len) * 0.5)
		var b := base + ax * (float(f.len) * 0.5)
		var wv := nrm * float(f.w)
		_quad(groups, int(f.state), span, [a, b, b + wv, a + wv], float(f.len), float(f.w), float(f.u))
	for wl in pl.wall:
		var t: Vector2i = wl.t
		var d: Vector2i = wl.d
		var ax := Vector3(t.x, 0.0, t.y)
		var p: Vector3 = wl.pos
		var hw := 0.42
		var y0 := 0.45
		var y1 := 2.95
		var a := p - ax * hw + Vector3(0, y0, 0)
		var b := p + ax * hw + Vector3(0, y0, 0)
		_quad(groups, int(wl.state), span, [a, b, b + Vector3(0, y1 - y0, 0), a + Vector3(0, y1 - y0, 0)], hw * 2.0, y1 - y0, float(wl.u))
	var keys: Array = groups.keys()
	keys.sort()
	for k in keys:
		var g: Dictionary = groups[k]
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(g.v)
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(g.n)
		arr[Mesh.ARRAY_COLOR] = PackedColorArray(g.c)
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(g.uv)
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "Magma_" + str(k).replace("|", "_")
		mi.mesh = m
		mi.material_override = material(int(g.state))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 70.0
		root.add_child(mi)
	var nl := 0
	var ne := 0
	var ns := 0
	if effects and Settings.torch_lights() > 0:
		for l in pl.lights:
			var ol := OmniLight3D.new()
			ol.position = l.pos
			ol.light_color = Color(1.0, 0.42, 0.13) if int(l.state) == 1 else Color(1.0, 0.5, 0.16)
			ol.light_energy = 1.5 if int(l.state) == 1 else 2.4
			ol.omni_range = 7.5
			ol.omni_attenuation = 1.4
			ol.shadow_enabled = false
			ol.light_specular = 0.3
			ol.distance_fade_enabled = true
			ol.distance_fade_begin = 16.0
			ol.distance_fade_length = 8.0
			root.add_child(ol)
			nl += 1
	if effects and float(Settings.opt("particles")) > 0.05:
		for e in pl.embers:
			root.add_child(_embers(e.pos, int(e.state)))
			ne += 1
		for s in pl.smoke:
			root.add_child(_smoke(s.pos))
			ns += 1
	last_stats = {"floor": pl.floor.size(), "wall": pl.wall.size(), "lights": nl, "embers": ne, "smoke": ns}

static func _quad(groups: Dictionary, state: int, span: float, p: Array, w_m: float, h_m: float, u0: float) -> void:
	var c0: Vector3 = p[0]
	var key := "%d|%d|%d" % [state, int(floor((c0.x + HALF) / span)), int(floor((c0.z + HALF) / span))]
	if not groups.has(key):
		groups[key] = {"state": state, "v": [], "n": [], "c": [], "uv": []}
	var g: Dictionary = groups[key]
	# coins : 0 = (-1,-1), 1 = (+1,-1), 2 = (+1,+1), 3 = (-1,+1) (COLOR.rg = position réduite dans le quad, UV en mètres)
	var cc := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var order := [0, 1, 2, 0, 2, 3]
	var n := Vector3.UP if absf((p[1] as Vector3 - p[0] as Vector3).cross(p[3] as Vector3 - p[0] as Vector3).y) > 0.5 else (p[1] as Vector3 - p[0] as Vector3).cross(p[3] as Vector3 - p[0] as Vector3).normalized()
	for i in order:
		(g.v as Array).append(p[i])
		(g.n as Array).append(n)
		(g.c as Array).append(Color(cc[i].x, cc[i].y, 0.0, 1.0))
		(g.uv as Array).append(Vector2(u0 + (cc[i].x * 0.5 + 0.5) * w_m, (cc[i].y * 0.5 + 0.5) * h_m))

static func _soft_texture() -> Texture2D:
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	return gt

static func _embers(pos: Vector3, state: int) -> CPUParticles3D:
	if _ember_mat == null:
		_ember_mat = StandardMaterial3D.new()
		_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_ember_mat.vertex_color_use_as_albedo = true
		_ember_mat.albedo_texture = _soft_texture()
		_ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ember_mat.no_depth_test = false
		_ember_mesh = QuadMesh.new()
		_ember_mesh.size = Vector2(0.09, 0.09)
		_ember_mesh.material = _ember_mat
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.15, 0)
	p.mesh = _ember_mesh
	p.amount = Settings.pc(6 if state == 1 else 10)
	p.lifetime = 3.2
	p.explosiveness = 0.0
	p.randomness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.55
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0.05, 0.22, 0.0)
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.75
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
	g.add_point(0.6, Color(1.0, 0.35, 0.08, 0.8))
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.05, 0.0, 0.0))
	p.color_ramp = g
	p.visibility_range_end = 26.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func _smoke(pos: Vector3) -> CPUParticles3D:
	if _smoke_mat == null:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.albedo_texture = _soft_texture()
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.disable_receive_shadows = true
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.size = Vector2(1.0, 1.0)
		_smoke_mesh.material = _smoke_mat
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.6, 0)
	p.mesh = _smoke_mesh
	p.amount = Settings.pc(4)
	p.lifetime = 6.0
	p.randomness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.0, 0.12, 0.0)
	p.initial_velocity_min = 0.12
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.16, 0.12, 0.11, 0.0))
	g.add_point(0.2, Color(0.16, 0.12, 0.11, 0.22))
	g.set_color(g.get_point_count() - 1, Color(0.08, 0.07, 0.07, 0.0))
	p.color_ramp = g
	p.visibility_range_end = 22.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
