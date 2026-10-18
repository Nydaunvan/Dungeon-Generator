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
var mon_id: String = ""          # monstre affiché (réactions visuelles)
var _atk_turn := 0
var _hidden: Array = []
var _nodes: Dictionary = {}   # clé -> {node, halo, rage, aura, idx, h}
var _cur_st: Dictionary = {}   # état (vivant) du monstre affiché : sert à tenir les effets de statut à jour
var _aura_clock := 0.0

static var _halo_tex: Texture2D

## Active la salle pour le monstre engagé (`def`/`st`), `p` = case du joueur, `dir` = direction du regard.
func enter(theme: String, p: Vector2i, dir: int, def: Dictionary, st: Dictionary, sel: int) -> void:
	if not active:
		for c in view.get_children():
			if c != self and c.visible and not c is FogMist:       # la brume reste visible pendant le combat
				_hidden.append(c)
				c.hide()
		active = true
	mon_id = str(def.id)
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

func _process(delta: float) -> void:
	if not active or view == null or view.entities == null:
		return
	_aura_clock += delta
	if _aura_clock > 0.3:
		_aura_clock = 0.0
		_sync_auras()
	var nodes: Array = []
	for k in _nodes.keys():
		var en: Dictionary = _nodes[k]
		var sl: Vector3 = en.get("slide", Vector3.ZERO)
		if sl != Vector3.ZERO:                      # glissement vers la nouvelle place (voir _refresh_monsters)
			var step := sl * clampf(delta * 9.0, 0.0, 1.0)
			if sl.length() < 0.01:
				step = sl
			(en.node as Node3D).position += Vector3(step.x, 0.0, step.z)
			en["slide"] = sl - step if sl.length() >= 0.01 else Vector3.ZERO
		nodes.append(en.node)
	view.entities.animate_stage(nodes, delta)

## Réaction visuelle d'un combattant : « hit » touche le membre ciblé (ou tous), « attack » fait avancer un membre à tour de rôle.
func react(id: String, kind: String) -> void:
	if not active or id != mon_id or _nodes.is_empty():
		return
	var keys: Array = _nodes.keys()
	keys.sort()
	var picked: Array = []
	if kind == "attack" and keys.size() > 1:
		picked.append(keys[_atk_turn % keys.size()])
		_atk_turn += 1
	elif kind == "hit":
		for k in keys:
			var e: Dictionary = _nodes[k]
			if e.halo != null and e.halo.visible:
				picked.append(k)
	if picked.is_empty():
		picked = keys
	for k in picked:
		view.entities.play_node(_nodes[k].node, kind)

## Mort du monstre : tous les sprites affichés s'effondrent puis disparaissent.
func die_all() -> void:
	for k in _nodes.keys():
		_free_entry(k, true)

func _free_entry(k, dying: bool = false) -> void:
	var e: Dictionary = _nodes[k]
	if dying and view != null and view.entities != null:
		view.entities.die_node(e.node)
	else:
		e.node.queue_free()
	if e.halo != null:
		e.halo.queue_free()
	if e.get("rage") != null:
		e.rage.queue_free()
	_nodes.erase(k)       # l'effet de statut est enfant du sprite : il disparaît avec lui

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
			e = {"node": node, "halo": null, "rage": null, "aura": null, "idx": idx, "h": float(node.get_meta("h"))}
			_nodes[key] = e
			_sprite_mass(node)      # précalcule le centre visible (visée des sorts)
			node.set_meta("ph", randf() * TAU)      # animations (voir EntityLayer.animate_stage)
			node.set_meta("boss", is_boss)
		var h: float = e.h
		var gap := maxf(2.6, h * 1.15)
		var slot := float(pos) - float(n - 1) / 2.0
		var off := view.entities.anchor_offset(icon) * h
		var at := Vector3(cell.x * CELL + right.x * slot * gap, h * 0.5 + 0.02 + off, cell.y * CELL + right.y * slot * gap)
		var mirrored: bool = is_group and idx == int(st.get("mirrorSlot", -1))
		var prev_at: Vector3 = e.node.get_meta("at", Vector3.INF)
		if prev_at != at:       # on ne touche à la pose animée que si l'emplacement change
			if prev_at != Vector3.INF and Settings.monster_anim and absf(prev_at.y - at.y) < 0.001:
				# un membre du groupe est tombé : les survivants glissent vers leur nouvelle place au lieu de sauter
				e["slide"] = Vector3(e.get("slide", Vector3.ZERO)) + (at - prev_at)
				e.node.set_meta("at", at)
			else:
				e.node.position = at
				e.node.set_meta("at", at)
				e.node.set_meta("by", at.y)
				e.node.set_meta("off", Vector3.ZERO)
		e.node.set_meta("mirror", -1.0 if mirrored else 1.0)
		if not e.node.has_meta("by") or e.node.scale.y == 1.0:
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
		# rage : halo rouge sombre qui pulse derrière le monstre (différent du halo de sélection)
		var raged: bool = bool(st.get("enraged", false))
		if not e.has("was"):
			e["was"] = raged            # déjà enragé à la première image (chargement d'une partie) : pas de mise en scène
		if raged and e.rage == null:
			e.rage = _make_rage_aura()
			add_child(e.rage)
			(e.rage.get_meta("mat") as ShaderMaterial).set_shader_parameter("grow", 1.0 if e.was else 0.0)
		if raged and not e.was and e.rage != null:
			_rage_burst(e.rage)          # entrée en rage : grognement, onde de choc, l'aura monte en puissance
		e["was"] = raged
		if e.rage != null:
			e.rage.visible = raged
			e.rage.position = at + Vector3(0, -h * 0.02, 0) - Vector3(fwd.x, 0, fwd.y) * 0.12
			_size_rage(e.rage, h)
	for k in _nodes.keys():
		if not wanted.has(k):
			_free_entry(k, true)       # membre du groupe tombé : il s'effondre et s'efface lui-même, les autres restent debout
	_cur_st = st
	_sync_auras()

## Effets de statut persistants sur chaque combattant affiché : ils restent tant que le statut dure (sommeil, poison, brûlure, gel…).
func _sync_auras() -> void:
	var live: bool = not _cur_st.is_empty() and bool(_cur_st.get("alive", true))
	for k in _nodes:
		var e: Dictionary = _nodes[k]
		var idx := int(e.get("idx", -1))
		var holder: Dictionary = _cur_st.members[idx] if live and idx >= 0 and _cur_st.has("members") and idx < _cur_st.members.size() else _cur_st      # chaque membre d'un groupe a ses propres statuts
		var looks: Array = StatusAura.looks_for(holder) if live else []
		if e.get("aura") == null:
			if looks.is_empty():
				continue
			e["aura"] = StatusAura.new()
			(e.node as Node3D).add_child(e.aura)
		var a: StatusAura = e.aura
		var info := _sprite_mass(e.node)
		var h: float = e.h
		var sz: Vector2 = info.size
		a.ext = Vector2(maxf(h * sz.x, h * 0.3), maxf(h * sz.y, h * 0.3))
		a.position = Vector3((info.center.x - 0.5) * h, (0.5 - info.center.y) * h, 0.04)
		a.set_looks(looks)

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

const RAGE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float grow = 1.0;     // 0 → 1 : montée en puissance à l'entrée en rage
uniform float flash = 0.0;    // éclat d'entrée
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){ return vnoise(p) * 0.55 + vnoise(p * 2.1 + 7.3) * 0.3 + vnoise(p * 4.3 + 2.9) * 0.15; }
void vertex(){
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment(){
	float x = (UV.x - 0.5) * 2.0;
	float y = 1.0 - UV.y;                              // 0 en bas, 1 en haut
	float t = TIME;
	// flammes qui montent : le bruit défile vers le haut, les langues s'étirent avec la hauteur
	float n = fbm(vec2(x * 3.4 + sin(t * 0.9) * 0.25, y * 2.6 - t * 2.3));
	float n2 = fbm(vec2(x * 6.5 - 3.1, y * 4.2 - t * 3.6));
	float width = (0.5 - 0.2 * y) * (0.5 + 0.5 * grow) + 0.05 * sin(t * 6.0 + y * 4.0);
	float tongue = (n * 0.75 + n2 * 0.45) * (1.0 - y * 0.5);
	float d = abs(x) - width * (0.4 + 0.95 * tongue);
	float body = smoothstep(0.16, -0.08, d);
	float top = smoothstep(0.95, 0.3 + 0.2 * grow, y + (1.0 - n) * 0.3);     // les flammes se dissipent en haut
	float bottom = smoothstep(0.0, 0.08, y);
	// cœur creux : le monstre reste lisible, l'énergie est surtout sur le contour
	float core = mix(0.1, 1.0, smoothstep(0.1, 0.8, abs(x) / max(width, 0.05)));
	float a = body * top * bottom * core;
	vec3 deep = vec3(0.45, 0.0, 0.0);
	vec3 hot = vec3(0.95, 0.1, 0.02);
	vec3 col = mix(deep, hot, smoothstep(0.1, 0.9, a + n2 * 0.25));
	col += vec3(0.8, 0.06, 0.0) * smoothstep(0.55, 1.0, a) * 0.5;             // liseré incandescent : toujours dans les rouges
	float pulse = 0.88 + 0.12 * sin(t * 7.0);
	float alpha = clamp(a * 1.15, 0.0, 1.0) * grow * pulse * (1.0 + flash * 1.6);
	ALBEDO = col * (1.0 + flash * 0.8);
	ALPHA = alpha;
}
"""

static var _rage_sh: Shader

## Shader des flammes de rage, créé une seule fois : un `Shader.new()` par monstre obligeait le moteur à le recompiler à chaque entrée en rage
## (micro-saccade), puisque le shader chauffé au chargement n'était pas celui utilisé.
static func _rage_shader() -> Shader:
	if _rage_sh == null:
		_rage_sh = Shader.new()
		_rage_sh.code = RAGE_SHADER
	return _rage_sh

## Aura de rage façon « ki » : flammes rouges qui montent le long du monstre (shader), braises, halo sombre au fond.
## Se compose de : halo de braise (mesh `halo`), flammes (mesh `flames`, shader), braises (CPUParticles3D `embers`) ; réglages dans `_size_rage`.
static func _make_rage_aura() -> Node3D:
	var root := Node3D.new()
	root.set_meta("halo", _make_rage_halo())
	root.add_child(root.get_meta("halo"))
	var fl := MeshInstance3D.new()
	fl.mesh = QuadMesh.new()
	var sm := ShaderMaterial.new()
	sm.shader = _rage_shader()      # UN SEUL shader pour toutes les auras : celui compilé au préchauffage est aussi celui du combat
	sm.render_priority = -1
	fl.material_override = sm
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fl)
	root.set_meta("flames", fl)
	root.set_meta("mat", sm)
	var em := CPUParticles3D.new()
	em.amount = 22
	em.lifetime = 1.4
	em.preprocess = 0.8
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	em.direction = Vector3(0, 1, 0)
	em.spread = 14.0
	em.gravity = Vector3(0, 0.6, 0)
	em.initial_velocity_min = 0.5
	em.initial_velocity_max = 1.3
	em.scale_amount_min = 0.5
	em.scale_amount_max = 1.2
	var pm := QuadMesh.new()
	pm.size = Vector2(0.09, 0.09)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pmat.vertex_color_use_as_albedo = true
	pmat.albedo_texture = _rage_dot()
	pm.material = pmat
	em.mesh = pm
	var cr := Gradient.new()
	cr.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	cr.colors = PackedColorArray([Color(1.0, 0.3, 0.05, 0.0), Color(1.0, 0.18, 0.02, 1.0), Color(0.5, 0.0, 0.0, 0.0)])
	em.color_ramp = cr
	root.add_child(em)
	root.set_meta("embers", em)
	return root

static var _dot_tex: Texture2D

static func _rage_dot() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot_tex = t
	return _dot_tex

static func _size_rage(root: Node3D, h: float) -> void:
	((root.get_meta("halo") as MeshInstance3D).mesh as QuadMesh).size = Vector2(h * 1.7, h * 1.5)
	var fl: MeshInstance3D = root.get_meta("flames")
	(fl.mesh as QuadMesh).size = Vector2(h * 1.5, h * 1.9)
	fl.position = Vector3(0, h * 0.32, 0.02)
	var em: CPUParticles3D = root.get_meta("embers")
	em.emission_box_extents = Vector3(h * 0.45, 0.05, 0.1)
	em.position = Vector3(0, -h * 0.4, 0)

## Entrée en rage : grognement, éclat, onde de choc rouge, l'aura enfle (1,1 s) puis se stabilise.
static func _rage_burst(root: Node3D, silent: bool = false) -> void:
	if not silent:
		Sound.rage()
	var sm: ShaderMaterial = root.get_meta("mat")
	sm.set_shader_parameter("grow", 0.0)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_method(func(v: float): sm.set_shader_parameter("grow", v), 0.0, 1.0, 1.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): sm.set_shader_parameter("flash", v), 1.0, 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	ring.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.albedo_texture = _ring_texture()
	m.albedo_color = Color(1.0, 0.2, 0.05, 0.95)
	ring.material_override = m
	var h := ((root.get_meta("halo") as MeshInstance3D).mesh as QuadMesh).size.x / 1.7
	ring.scale = Vector3(h * 0.6, h * 0.6, 1.0)
	root.add_child(ring)
	var t2 := root.create_tween().set_parallel(true)
	t2.tween_property(ring, "scale", Vector3(h * 3.6, h * 3.6, 1.0), 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t2.tween_property(m, "albedo_color:a", 0.0, 0.8)
	t2.chain().tween_callback(ring.queue_free)
	var em: CPUParticles3D = root.get_meta("embers")
	em.amount = 70
	var t3 := root.create_tween()
	t3.tween_interval(1.0)
	t3.tween_callback(func(): if is_instance_valid(em): em.amount = 22)

static var _ring_tex: Texture2D

static func _ring_texture() -> Texture2D:
	if _ring_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.72, 0.86, 0.94, 1.0])
		g.colors = PackedColorArray([Color(1, 0.1, 0, 0), Color(1, 0.15, 0.02, 0.0), Color(1, 0.3, 0.08, 1.0), Color(0.8, 0.05, 0, 0.5), Color(0.5, 0, 0, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_ring_tex = t
	return _ring_tex

## Halo de rage : braise rouge sombre à cœur transparent (le monstre reste lisible), liseré orangé, qui pulse sans fin.
static func _make_rage_halo() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _rage_texture()
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.render_priority = -2
	mi.material_override = m
	var tw := mi.create_tween().set_loops()
	tw.tween_property(m, "albedo_color:a", 0.18, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(m, "albedo_color:a", 0.5, 0.55).set_trans(Tween.TRANS_SINE)
	return mi

static var _rage_tex: Texture2D

static func _rage_texture() -> Texture2D:
	if _rage_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.62, 0.8, 0.92, 1.0])
		g.colors = PackedColorArray([Color(0.5, 0.0, 0.0, 0.0), Color(0.55, 0.02, 0.0, 0.25), Color(0.85, 0.05, 0.02, 0.75),
				Color(1.0, 0.25, 0.05, 0.9), Color(1.0, 0.1, 0.02, 0.35), Color(0.6, 0.0, 0.0, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_rage_tex = t
	return _rage_tex

static func _halo_texture() -> Texture2D:
	if _halo_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.125, 0.5625, 1.0])
		# sélection : halo léger bleu-cyan (le rouge est réservé à la rage)
		g.colors = PackedColorArray([Color(0.45, 0.85, 1.0, 0.38), Color(0.45, 0.85, 1.0, 0.38),
				Color(0.3, 0.7, 1.0, 0.2), Color(0.25, 0.65, 1.0, 0.0)])
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

## Centres visibles de TOUS les combattants affichés (sorts de zone).
func target_points() -> Array:
	var out: Array = []
	for k in _nodes:
		var e: Dictionary = _nodes[k]
		if e.node.visible:
			out.append(_visual_center(e))
	return out

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
