class_name CombatStage
extends Node3D
## Salle de combat scellée (3 x 3 cases devant le joueur) où le monstre – ou tout le groupe – est
## affiché en entier et peut être visé d'un clic. Reprend buildArena / setCombatBackdrop / updateMonsters du JS.

const CELL := LevelBuilder.CELL
const DEPTH := 3
const GROUP_SHRINK := {1: 1.0, 2: 0.88, 3: 0.72, 4: 0.6}

var view: LevelView
var camera: Camera3D
var active: bool = false
var _arena: MeshInstance3D
var _sig: String = ""
var _hidden: Array = []
var _nodes: Dictionary = {}   # clé -> {node, halo, idx, h}

static var _halo_tex: Texture2D

## Active la salle pour le monstre engagé (`def`/`st`), `p` = case du joueur, `dir` = direction du regard.
func enter(theme: String, p: Vector2i, dir: int, def: Dictionary, st: Dictionary, sel: int) -> void:
	if not active:
		for c in view.get_children():
			if c != self and c.visible:
				_hidden.append(c)
				c.hide()
		active = true
	var sig := "%s|%d,%d|%d" % [theme, p.x, p.y, dir]
	if sig != _sig:
		_build_arena(theme, p, dir)
		_sig = sig
	_arena.visible = true
	_refresh_monsters(p, dir, def, st, sel)

func exit() -> void:
	if not active:
		return
	active = false
	for c in _hidden:
		if is_instance_valid(c):
			c.show()
	_hidden.clear()
	if _arena != null:
		_arena.visible = false
	for k in _nodes.keys():
		_free_entry(k)

func _free_entry(k) -> void:
	var e: Dictionary = _nodes[k]
	e.node.queue_free()
	if e.halo != null:
		e.halo.queue_free()
	_nodes.erase(k)

func _build_arena(theme: String, p: Vector2i, dir: int) -> void:
	if _arena != null:
		_arena.queue_free()
	var mats: Dictionary = ThemeMaterials.for_theme(theme)
	var parts := {}
	for k in ["wall", "floor", "ceil"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[k] = st
	var fwd: Vector2i = DungeonGrid.DIRS[dir]
	var left: Vector2i = DungeonGrid.DIRS[(dir + 3) % 4]
	var right: Vector2i = DungeonGrid.DIRS[(dir + 1) % 4]
	var half := CELL * 0.5
	for i in DEPTH:
		for c in range(-1, 2):
			var g := p + fwd * i + right * c
			var ctr := Vector3(g.x * CELL, 0.0, g.y * CELL)
			LevelBuilder._quad(parts["floor"], ctr, Vector3(0, 0, -1), Vector3.UP, half)
			LevelBuilder._quad(parts["ceil"], ctr + Vector3(0, CELL, 0), Vector3(0, 0, 1), Vector3.DOWN, half)
			if c == -1:
				_wall(parts["wall"], ctr, left, half)
			if c == 1:
				_wall(parts["wall"], ctr, right, half)
			if i == DEPTH - 1:
				_wall(parts["wall"], ctr, fwd, half)
	var mesh := ArrayMesh.new()
	for k in ["wall", "floor", "ceil"]:
		if k != "path":
			parts[k].generate_tangents()   # nécessaires aux cartes de normales (mur, sol, plafond)
		parts[k].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[k])
	_arena = MeshInstance3D.new()
	_arena.name = "Arena"
	_arena.mesh = mesh
	add_child(_arena)

func _wall(st: SurfaceTool, ctr: Vector3, d: Vector2i, half: float) -> void:
	var edge := ctr + Vector3(d.x * half, 0.0, d.y * half)
	LevelBuilder._quad(st, edge + Vector3(0, half, 0), Vector3.UP, Vector3(-d.x, 0, -d.y), half)

func _refresh_monsters(p: Vector2i, dir: int, def: Dictionary, st: Dictionary, sel: int) -> void:
	var fwd: Vector2i = DungeonGrid.DIRS[dir]
	var right: Vector2i = DungeonGrid.DIRS[(dir + 1) % 4]
	var icon := str(def.get("icon", ""))
	var is_boss := bool(def.get("isBoss", false))
	var is_group: bool = bool(def.get("isGroup", false)) and st.has("members")
	var alive: Array = []
	var total := 1
	if is_group:
		total = st.members.size()
		for i in total:
			if st.members[i].alive:
				alive.append(i)
	else:
		alive.append(-1)
	var cell := p + fwd
	var wanted := {}
	var n := alive.size()
	var big := icon == "@icon:mon_ogre" or icon == "@icon:mon_minotaur"
	var shrink: float = float(GROUP_SHRINK.get(total, 0.6)) if (big and total > 1) else 1.0
	for pos in n:
		var idx: int = alive[pos]
		var key := "m%d" % idx
		wanted[key] = true
		var e: Dictionary = _nodes.get(key, {})
		if e.is_empty():
			var node: MeshInstance3D = view.entities._make_sprite(icon, is_boss, false, 1.5 * shrink)
			if node == null:
				continue
			node.name = "Combatant_%d" % idx
			add_child(node)
			e = {"node": node, "halo": null, "idx": idx, "h": float(node.get_meta("h"))}
			_nodes[key] = e
			_sprite_mass(node)      # précalcule le centre visible (visée des sorts)
		var h: float = e.h
		var gap := maxf(2.6, h * 1.15)
		var slot := float(pos) - float(n - 1) / 2.0
		var off := view.entities.anchor_offset(icon) * h
		var at := Vector3(cell.x * CELL + right.x * slot * gap, h * 0.5 + 0.02 + off, cell.y * CELL + right.y * slot * gap)
		e.node.position = at
		var mirrored: bool = is_group and idx == int(st.get("mirrorSlot", -1))
		e.node.scale = Vector3(-1.0 if mirrored else 1.0, 1.0, 1.0)
		e.node.visible = true
		var targeted: bool = is_group and idx == sel
		if targeted and e.halo == null:
			e.halo = _make_halo()
			add_child(e.halo)
		if e.halo != null:
			e.halo.visible = targeted
			e.halo.position = at + Vector3(0, -h * 0.12, 0) - Vector3(fwd.x, 0, fwd.y) * 0.05
			(e.halo.mesh as QuadMesh).size = Vector2(h * 1.75, h * 1.4)
	for k in _nodes.keys():
		if not wanted.has(k):
			_free_entry(k)

func _make_halo() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_texture = _halo_texture()
	m.render_priority = -1
	mi.material_override = m
	return mi

static func _halo_texture() -> Texture2D:
	if _halo_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.125, 0.5625, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.275, 0.196, 0.95), Color(1.0, 0.275, 0.196, 0.95),
				Color(1.0, 0.157, 0.078, 0.5), Color(1.0, 0.118, 0.04, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_halo_tex = t
	return _halo_tex

## Membre (index dans le groupe) sous le point d'écran `pos` (coordonnées de la vue 3D), ou -1.
func pick(pos: Vector2) -> int:
	if not active or camera == null:
		return -1
	var right := camera.global_transform.basis.x
	var best := -1
	var best_d := INF
	for k in _nodes:
		var e: Dictionary = _nodes[k]
		if int(e.idx) < 0 or not e.node.visible:
			continue
		var c: Vector3 = e.node.global_position
		var hh: float = float(e.h) * 0.5
		var a := camera.unproject_position(c - right * hh + Vector3.UP * hh)
		var b := camera.unproject_position(c + right * hh - Vector3.UP * hh)
		if Rect2(a, b - a).abs().has_point(pos):
			var d := camera.global_position.distance_to(c)
			if d < best_d:
				best_d = d
				best = int(e.idx)
	return best

## Point visé par les sorts : le CENTRE VISIBLE du combattant ciblé (ou du premier visible), quel que soit le monstre.
## {"pos": Vector3, "h": float (hauteur visible), "w": float (largeur visible)} ou {} sans cible.
func target_point() -> Dictionary:
	var best: Dictionary = {}
	for k in _nodes:
		var e: Dictionary = _nodes[k]
		if not e.node.visible:
			continue
		if e.halo != null and e.halo.visible:
			return _visual_center(e)
		if best.is_empty():
			best = _visual_center(e)
	return best

static var _centroids: Dictionary = {}   # clé texture+cellule -> Rect2 (centre de masse en x,y ; taille visible en size)

## Centre de masse des pixels opaques du sprite (les cases des planches ont de la marge transparente et des
## ancrages différents : le centre du quad n'est pas le centre de la créature). Calculé une fois par sprite.
func _visual_center(e: Dictionary) -> Dictionary:
	var node: MeshInstance3D = e.node
	var h: float = e.h
	var info := _sprite_mass(node)           # centre (0..1, y vers le bas) et taille (0..1) de la partie visible
	var right := camera.global_transform.basis.x if camera != null else Vector3.RIGHT
	var up := camera.global_transform.basis.y if camera != null else Vector3.UP
	var mirror := -1.0 if node.scale.x < 0.0 else 1.0
	var c: Vector2 = info.center
	var pos: Vector3 = node.global_position + right * ((c.x - 0.5) * h * mirror) + up * ((0.5 - c.y) * h)
	return {"pos": pos, "h": h * float(info.size.y), "w": h * float(info.size.x)}

static func _sprite_mass(node: MeshInstance3D) -> Dictionary:
	var mat := node.material_override as StandardMaterial3D
	if mat == null or mat.albedo_texture == null:
		return {"center": Vector2(0.5, 0.5), "size": Vector2(0.6, 0.6)}
	var tex: Texture2D = mat.albedo_texture
	var key := "%d|%.4f|%.4f" % [tex.get_rid().get_id(), mat.uv1_offset.x, mat.uv1_offset.y]
	if _centroids.has(key):
		return _centroids[key]
	var res := {"center": Vector2(0.5, 0.5), "size": Vector2(0.6, 0.6)}
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var W := img.get_width()
		var H := img.get_height()
		# région de la cellule dans la planche (uv1_scale / uv1_offset)
		var r := Rect2i(int(mat.uv1_offset.x * W), int(mat.uv1_offset.y * H), int(mat.uv1_scale.x * W), int(mat.uv1_scale.y * H))
		r = r.intersection(Rect2i(0, 0, W, H))
		if r.size.x > 0 and r.size.y > 0:
			var sub := img.get_region(r)
			var sc := 64.0 / float(maxi(sub.get_width(), sub.get_height()))
			if sc < 1.0:
				sub.resize(maxi(1, int(sub.get_width() * sc)), maxi(1, int(sub.get_height() * sc)), Image.INTERPOLATE_BILINEAR)
			var sw := sub.get_width()
			var sh := sub.get_height()
			var sx := 0.0
			var sy := 0.0
			var tot := 0.0
			var minx := sw
			var maxx := 0
			var miny := sh
			var maxy := 0
			for y in sh:
				for x in sw:
					var a := sub.get_pixel(x, y).a
					if a > 0.35:
						sx += x * a
						sy += y * a
						tot += a
						minx = mini(minx, x)
						maxx = maxi(maxx, x)
						miny = mini(miny, y)
						maxy = maxi(maxy, y)
			if tot > 0.0:
				res = {"center": Vector2((sx / tot + 0.5) / float(sw), (sy / tot + 0.5) / float(sh)),
					"size": Vector2(float(maxx - minx + 1) / float(sw), float(maxy - miny + 1) / float(sh))}
	_centroids[key] = res
	return res
