class_name TrapPit
extends RefCounted
## Piège « fosse » en vrai volume : un trou béant dans le sol de la case (le sol du niveau est découpé par `LevelBuilder`, voir `HALF`).
## Les parois sont maçonnées en assises de blocs taillés (bords chanfreinés, profondeurs irrégulières), le bord est une margelle de dalles
## ébréchées entourée de vrais rochers, et le fond est hérissé de pieux. Pierre, normales et rugosité sont celles du thème du niveau en cours
## (mur et sol du `ThemeMaterials`), projetées en triplanaire : la fosse se fond dans le couloir. Désamorcé, des planches de bois texturé
## (veinage, nœuds, bords chanfreinés, sangles et clous de fer) sont jetées en travers du trou ; un échec laisse la fosse ouverte.
## Repère local : l'origine est au centre de la case, au niveau du sol.

const HALF := 0.85            ## demi-côté du trou (m) ; la case fait 4 m
const DEPTH := 2.4
const COPING := 0.34          ## largeur de la margelle autour du trou

static var _mesh: ArrayMesh          ## surfaces : 0 blocs des parois, 1 rochers, 2 margelle, 3 pieux
static var _planks: ArrayMesh        ## surfaces : 0 bois, 1 fer
static var _stone_mats: Dictionary = {}
static var _wood_mat: StandardMaterial3D
static var _iron_mat: StandardMaterial3D

static func make(theme: String = "stone") -> MeshInstance3D:
	_build()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	var mats := _stone(theme)
	mi.set_surface_override_material(0, mats.wall)
	mi.set_surface_override_material(1, mats.floor)
	mi.set_surface_override_material(2, mats.floor)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("trap_pit", true)
	var pl := MeshInstance3D.new()
	pl.name = "Planks"
	pl.mesh = _planks
	pl.set_surface_override_material(0, _wood())
	pl.set_surface_override_material(1, _iron())
	pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pl.visible = false
	mi.add_child(pl)
	# faible lueur froide au fond : sans elle, l'ombre du bord noie la fosse et on ne voit plus ni les parois ni les pieux
	var l := OmniLight3D.new()
	l.name = "Depth"
	l.light_color = Color(0.75, 0.8, 0.95)
	l.light_energy = 0.9
	l.omni_range = 3.4
	l.light_specular = 0.0
	l.shadow_enabled = false
	l.position = Vector3(0, -0.7, 0)
	mi.add_child(l)
	return mi

## Piège désamorcé : les planches tombent en travers du trou (immédiat au chargement du niveau).
static func cover(root: Node, animate: bool = true) -> void:
	var pl := root.get_node_or_null("Planks") as Node3D
	if pl == null or bool(root.get_meta("trap_pit_off", false)):
		return
	root.set_meta("trap_pit_off", true)
	pl.visible = true
	var dl := root.get_node_or_null("Depth")
	if dl != null:
		dl.queue_free()
	if not animate or not root.is_inside_tree():
		pl.position.y = 0.0
		return
	pl.position.y = 0.9
	var tw := pl.create_tween()
	tw.tween_property(pl, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pl, "position:y", 0.05, 0.07)
	tw.tween_property(pl, "position:y", 0.0, 0.08)

# ------------------------------------------------------------------ matériaux

## Pierre du thème (mur pour les blocs des parois, sol pour la margelle et les rochers) : copie du matériau du niveau, projetée en triplanaire (le maillage
## n'a pas de coordonnées de texture), sans relief par parallaxe, assombrie par les couleurs de sommet (profondeur).
static func _stone(theme: String) -> Dictionary:
	if _stone_mats.has(theme):
		return _stone_mats[theme]
	var tm: Dictionary = ThemeMaterials.for_theme(theme)
	var out := {}
	for part in ["wall", "floor"]:
		var src: StandardMaterial3D = tm[part]
		var m: StandardMaterial3D = src.duplicate()
		var s := maxf(0.2, src.uv1_scale.x / LevelBuilder.CELL) * (1.0 if part == "wall" else 2.0)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = false
		m.uv1_scale = Vector3(s, s, s)
		m.heightmap_enabled = false
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_BACK
		out[part] = m
	_stone_mats[theme] = out
	return out

static func _iron() -> StandardMaterial3D:
	if _iron_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.32, 0.31, 0.3)
		m.metallic = 0.55
		m.roughness = 0.6
		_iron_mat = m
	return _iron_mat

static func _wood() -> StandardMaterial3D:
	if _wood_mat == null:
		var tex := _wood_textures()
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = tex[0]
		m.normal_enabled = true
		m.normal_texture = tex[1]
		m.normal_scale = 1.3
		m.roughness = 0.82
		m.metallic_specular = 0.25
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(1.1, 1.1, 1.1)
		m.texture_repeat = true
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_wood_mat = m
	return _wood_mat

## Bois : couleur et normales (1024 x 1024, fabriquées une fois par `tools/make_pit_wood.gd` et rangées dans assets/misc), veinage le long de
## l'axe vertical de l'image (les planches courent le long de Z, projection triplanaire du dessus), cernes ondulés, pores, deux nœuds.
static func _wood_textures() -> Array:
	return [load("res://assets/misc/pit_wood_albedo.jpg"), load("res://assets/misc/pit_wood_normal.png")]

## Précalcule ce qui est lent à fabriquer (bois, maillages) : appelé par `warm_up.gd`.
static func prepare() -> void:
	_build()
	_wood()

# ------------------------------------------------------------------ géométrie

static func _build() -> void:
	if _mesh != null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var blocks := SurfaceTool.new()
	blocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	# parois : assises de blocs taillés sur un fond de mortier sombre
	var corners := [Vector2(-HALF, -HALF), Vector2(HALF, -HALF), Vector2(HALF, HALF), Vector2(-HALF, HALF)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var tangent := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
		var inward := Vector3(-(a.x + b.x), 0, -(a.y + b.y)).normalized()
		var origin := Vector3(a.x, 0, a.y)
		var length := a.distance_to(b)
		# mortier : plan de fond, très sombre
		_quad(blocks, origin, origin + tangent * length, origin + tangent * length + Vector3(0, -DEPTH, 0), origin + Vector3(0, -DEPTH, 0),
			inward, Color(0.05, 0.045, 0.04), Color(0.02, 0.02, 0.02))
		var y := 0.0
		var row := 0
		while y > -DEPTH + 0.05:
			var rh := rng.randf_range(0.26, 0.44)
			rh = minf(rh, DEPTH + y)
			var x := -(0.0 if row % 2 == 0 else rng.randf_range(0.1, 0.3))
			while x < length - 0.02:
				var bw := rng.randf_range(0.3, 0.62)
				var x0 := maxf(x, 0.0)
				var x1 := minf(x + bw, length)
				x += bw
				if x1 - x0 < 0.08:
					continue
				var depth := rng.randf_range(0.01, 0.075)
				var shade := clampf(0.5 * (1.0 + (y - rh * 0.5) / (DEPTH * 0.95)), 0.1, 1.0)       # plus sombre en descendant
				var tint := rng.randf_range(0.85, 1.05)
				_block(blocks, origin, tangent, inward, x0 + 0.01, x1 - 0.01, y - 0.01, y - rh + 0.01, depth, rng.randf_range(0.025, 0.045), Color.WHITE * (shade * tint))
			y -= rh
			row += 1
	# fond : sol de gravats sombre
	_quad(blocks, Vector3(-HALF, -DEPTH, HALF), Vector3(HALF, -DEPTH, HALF), Vector3(HALF, -DEPTH, -HALF), Vector3(-HALF, -DEPTH, -HALF),
		Vector3.UP, Color(0.18, 0.16, 0.14), Color(0.18, 0.16, 0.14))
	var rocks := SurfaceTool.new()
	rocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slabs := SurfaceTool.new()
	slabs.begin(Mesh.PRIMITIVE_TRIANGLES)
	# margelle : dalles posées autour du trou, légèrement surélevées, ébréchées (deux couches : le dessus en retrait fait le biseau)
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var dirv := Vector2(b.x - a.x, b.y - a.y).normalized()
		var outv := Vector2(dirv.y, -dirv.x)       # vers l'extérieur du trou
		var t := -COPING
		var side_len := a.distance_to(b)
		while t < side_len + COPING * 0.4:
			var w := rng.randf_range(0.28, 0.5)
			var mid := a + dirv * (t + w * 0.5) + outv * (COPING * 0.5 + 0.01 + rng.randf_range(-0.02, 0.03))
			var hh := rng.randf_range(0.018, 0.042)
			var yaw := atan2(dirv.x, dirv.y) + rng.randf_range(-0.07, 0.07)
			var e := Vector3(w * 0.5 - 0.012, hh, COPING * 0.5 + rng.randf_range(-0.03, 0.03))
			var tone := rng.randf_range(0.72, 0.95)
			_rbox(slabs, Vector3(mid.x, hh - 0.012, mid.y), e, yaw, Color.WHITE * tone)
			_rbox(slabs, Vector3(mid.x, hh * 2.0 - 0.014, mid.y), Vector3(e.x - 0.012, 0.007, e.z - 0.012), yaw, Color.WHITE * (tone * 1.06))
			t += w + rng.randf_range(0.004, 0.02)
	# rochers : éboulis sur la margelle et au bord, quelques-uns tombés dans le trou ; maillage lissé
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 2.2
	noise.seed = 77
	for i in 26:
		var ang := rng.randf_range(0.0, TAU)
		var rr := rng.randf_range(HALF + 0.08, HALF + COPING + 0.5)
		var p := Vector2(cos(ang), sin(ang)) * rr
		# projeté sur le carré : le bord du trou est carré, pas rond
		var m := maxf(absf(p.x), absf(p.y))
		p *= (HALF + rng.randf_range(0.04, COPING + 0.42)) / maxf(m, 0.01)
		var s := rng.randf_range(0.045, 0.12)
		_rock(rocks, Vector3(p.x, 0.0, p.y), Vector3(s * rng.randf_range(0.9, 1.5), s * rng.randf_range(0.5, 0.85), s * rng.randf_range(0.9, 1.5)), noise, rng, Color.WHITE * rng.randf_range(0.95, 1.25), i)
	for i in 5:       # gravats sur le bord du trou, à demi suspendus
		var side := rng.randi_range(0, 3)
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var p := a.lerp(b, rng.randf_range(0.1, 0.9))
		var s := rng.randf_range(0.03, 0.065)
		_rock(rocks, Vector3(p.x, 0.0, p.y), Vector3(s * 1.3, s * 0.6, s * 1.1), noise, rng, Color.WHITE * 0.8, 40 + i)
	for i in 7:       # éboulis au fond
		var s := rng.randf_range(0.08, 0.18)
		_rock(rocks, Vector3(rng.randf_range(-HALF + 0.1, HALF - 0.1), -DEPTH, rng.randf_range(-HALF + 0.1, HALF - 0.1)), Vector3(s, s * 0.7, s), noise, rng, Color.WHITE * 0.35, 60 + i)
	# pieux du fond (normales lissées, matériau d'acier propre au piège de pointes)
	var sp := SurfaceTool.new()
	sp.begin(Mesh.PRIMITIVE_TRIANGLES)
	sp.set_smooth_group(0)
	var n := 0
	for ix in 4:
		for iz in 4:
			var base := Vector3((float(ix) - 1.5) * 0.4, -DEPTH, (float(iz) - 1.5) * 0.4) + Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
			var lean := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
			TrapSpikes._spike(sp, base, 0.06, rng.randf_range(0.45, 0.8), lean, n % 5 == 2)
			n += 1
	sp.generate_normals()
	_mesh = ArrayMesh.new()
	blocks.commit(_mesh)
	rocks.generate_normals()
	rocks.commit(_mesh)
	slabs.commit(_mesh)
	sp.commit(_mesh)
	_mesh.surface_set_material(3, TrapSpikes._spike_mat())
	_build_planks(rng)

## Planches jetées en travers (nœud à part, caché tant que le piège est actif) : 5 planches aux bords chanfreinés, 2 traverses, sangles et clous.
static func _build_planks(rng: RandomNumberGenerator) -> void:
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-0.55, 0.55]:
		_rbox(wood, Vector3(0, 0.0, z), Vector3(0.98, 0.03, 0.07), 0.0, Color.WHITE * 0.55)
	for i in 5:
		var x := (float(i) - 2.0) * 0.35 + rng.randf_range(-0.02, 0.02)
		var w := rng.randf_range(0.15, 0.165)
		var yaw := rng.randf_range(-0.05, 0.05)
		var tone := rng.randf_range(0.82, 1.08)
		var c := Vector3(x, 0.04, rng.randf_range(-0.05, 0.05))
		_rbox(wood, c, Vector3(w, 0.032, 1.2), yaw, Color(tone, tone * 0.97, tone * 0.93))
		_rbox(wood, c + Vector3(0, 0.026, 0), Vector3(w - 0.014, 0.01, 1.2 - 0.014), yaw, Color(tone * 1.05, tone * 1.02, tone * 0.98))   # arête chanfreinée
		for z in [-0.55, 0.55]:      # clous
			var bs := Basis(Vector3.UP, yaw)
			var pn: Vector3 = c + bs * Vector3(0, 0.0, z - c.z)
			TrapSpikes.add_prism(iron, Vector3(pn.x, 0.074, pn.z), 0.016, 0.009, 8, Color.WHITE * 0.9)
	for z in [-0.12, 0.3]:      # sangles de fer en travers des planches
		_rbox(iron, Vector3(0, 0.083, z), Vector3(0.9, 0.006, 0.032), 0.0, Color.WHITE * 0.85)
	_planks = ArrayMesh.new()
	wood.commit(_planks)
	iron.commit(_planks)

# ------------------------------------------------------------------ primitives

## Bloc taillé accolé à une paroi : face avant en retrait de `depth` vers l'intérieur, reliée au contour par quatre chanfreins de largeur `bevel`.
## `origin` / `tangent` : début et sens de la paroi ; x0..x1 le long de la paroi ; y0 (haut) .. y1 (bas) en hauteur.
static func _block(st: SurfaceTool, origin: Vector3, tangent: Vector3, inward: Vector3, x0: float, x1: float, y0: float, y1: float, depth: float, bevel: float, col: Color) -> void:
	var up := Vector3.UP
	var bv := minf(bevel, minf((x1 - x0), (y0 - y1)) * 0.35)
	var base := [origin + tangent * x0 + up * y0, origin + tangent * x1 + up * y0, origin + tangent * x1 + up * y1, origin + tangent * x0 + up * y1]
	var front := [base[0] + inward * depth + tangent * bv - up * bv, base[1] + inward * depth - tangent * bv - up * bv,
		base[2] + inward * depth - tangent * bv + up * bv, base[3] + inward * depth + tangent * bv + up * bv]
	var lit_top := col * 1.12
	var lit_bot := col * 0.82
	_quad(st, front[0], front[1], front[2], front[3], inward, lit_top, lit_bot)
	var mid: Vector3 = ((base[0] as Vector3) + (base[2] as Vector3)) * 0.5 + inward * depth * 0.5
	for e in 4:
		var f0: Vector3 = front[e]
		var f1: Vector3 = front[(e + 1) % 4]
		var b0: Vector3 = base[e]
		var b1: Vector3 = base[(e + 1) % 4]
		var nrm := (f1 - f0).cross(b0 - f0).normalized()
		var centre := (f0 + f1 + b0 + b1) * 0.25
		if nrm.dot(centre - mid) < 0.0:
			nrm = -nrm
		var shade := 1.0
		if e == 0:
			shade = 1.18      # chanfrein du haut : éclairé
		elif e == 2:
			shade = 0.7       # chanfrein du bas : dans l'ombre
		_quad(st, f0, f1, b1, b0, nrm, col * shade, col * shade)

## Quadrilatère a-b-c-d (a, b en haut, c, d en bas) tourné vers `n`, couleur ca en haut et cb en bas ; sens horaire vu de `n`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ca: Color, cb: Color) -> void:
	var cn := (b - a).cross(c - a)
	var pts: Array = [[a, ca], [b, ca], [c, cb], [a, ca], [c, cb], [d, cb]]
	if cn.dot(n) > 0.0:
		pts = [[a, ca], [c, cb], [b, ca], [a, ca], [d, cb], [c, cb]]
	for p in pts:
		st.set_normal(n)
		st.set_color(p[1])
		st.add_vertex(p[0])

## Boîte tournée de `yaw` autour de Y, normales plates.
static func _rbox(st: SurfaceTool, c: Vector3, e: Vector3, yaw: float, col: Color) -> void:
	var bs := Basis(Vector3.UP, yaw)
	var faces := [
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.RIGHT, Vector3.UP, Vector3.FORWARD], [Vector3.LEFT, Vector3.UP, Vector3.BACK],
		[Vector3.BACK, Vector3.UP, Vector3.RIGHT], [Vector3.FORWARD, Vector3.UP, Vector3.LEFT],
	]
	for f in faces:
		var n: Vector3 = bs * (f[0] as Vector3)
		var u: Vector3 = bs * ((f[1] as Vector3) * e)
		var v: Vector3 = bs * ((f[2] as Vector3) * e)
		var o := c + bs * ((f[0] as Vector3) * e)
		var p0 := o - u - v
		var p1 := o + u - v
		var p2 := o + u + v
		var p3 := o - u + v
		var cn := (p1 - p0).cross(p2 - p0)
		var quad := [p0, p1, p2, p0, p2, p3]
		if cn.dot(n) > 0.0:
			quad = [p0, p2, p1, p0, p3, p2]
		for p in quad:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(p)

## Rocher : cube subdivisé ramené sur une sphère, déformé par du bruit (arêtes arrondies, faces irrégulières), aplati par le bas et posé au sol ;
## normales calculées par le SurfaceTool (maillage lissé). `radii` : demi-axes ; `seed_off` décale le bruit d'un rocher à l'autre.
static func _rock(st: SurfaceTool, c: Vector3, radii: Vector3, noise: FastNoiseLite, rng: RandomNumberGenerator, col: Color, seed_off: int) -> void:
	const N := 5
	var yaw := rng.randf_range(0.0, TAU)
	var bs := Basis(Vector3.UP, yaw)
	var axes := [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.LEFT, Vector3.BACK], [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD],
		[Vector3.LEFT, Vector3.DOWN, Vector3.FORWARD], [Vector3.BACK, Vector3.RIGHT, Vector3.DOWN], [Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN]]
	for ax in axes:
		var grid: Array = []
		for j in N + 1:
			var row: Array = []
			for i in N + 1:
				var cu := float(i) / N * 2.0 - 1.0
				var cv := float(j) / N * 2.0 - 1.0
				var dirv: Vector3 = ((ax[0] as Vector3) + (ax[1] as Vector3) * cu + (ax[2] as Vector3) * cv).normalized()
				var nz := noise.get_noise_3d(dirv.x * 2.0 + float(seed_off) * 3.1, dirv.y * 2.0, dirv.z * 2.0) * 0.32
				var p := dirv * (1.0 + nz)
				p = Vector3(p.x * radii.x, p.y * radii.y, p.z * radii.z)
				if p.y < 0.0:
					p.y *= 0.25       # base presque plate : le rocher est posé
				row.append(c + bs * p + Vector3(0, radii.y * 0.18, 0))
			grid.append(row)
		for j in N:
			for i in N:
				var p00: Vector3 = grid[j][i]
				var p10: Vector3 = grid[j][i + 1]
				var p01: Vector3 = grid[j + 1][i]
				var p11: Vector3 = grid[j + 1][i + 1]
				var cen := (p00 + p10 + p01 + p11) * 0.25
				var outward := cen - (c + Vector3(0, radii.y * 0.18, 0))
				var tri1 := [p00, p10, p11]
				var tri2 := [p00, p11, p01]
				for tri in [tri1, tri2]:
					var nrm := ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3))
					var order = tri if nrm.dot(outward) < 0.0 else [tri[0], tri[2], tri[1]]
					for p in order:
						var shade := clampf(0.62 + ((p as Vector3).y - c.y) / maxf(radii.y, 0.01) * 0.28, 0.4, 1.1)
						st.set_color(col * shade)
						st.add_vertex(p)
