class_name CardFxOverlay
extends Control
## Couche d'effets 3D transparente posée au-dessus de toute l'interface : les effets venant des monstres et les soins / protections
## des héros y sont joués, de sorte qu'ils atteignent les cartes du bandeau d'équipe (hors de la vue 3D du jeu).
## Le point de départ d'un effet de monstre est reprojeté depuis la vue du jeu ; la caméra de la couche a le même grossissement en
## pixels que celle de la vue, donc la taille des effets est la même. La couche ne dessine (et ne coûte) rien tant qu'aucun effet ne joue.

var _svc: SubViewportContainer
var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _idle := 0.0

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	visible = false
	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.handle_input_locally = false
	_vp.msaa_3d = Settings.msaa_mode()
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_svc.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.58, 0.54)
	env.ambient_light_energy = 1.2
	if bool(Settings.opt("fx_glow")):
		env.glow_enabled = true
		env.glow_intensity = 0.55
		env.glow_strength = 0.95
		env.glow_bloom = 0.04
		env.glow_hdr_threshold = 0.8
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 100.0
	_world.add_child(_cam)
	_cam.current = true

## Vrai si les effets peuvent jouer ici (option activée). Indépendant du rendu et du palier d'effets : même en compatibilité ou sans halo (palier 0),
## les sorts des héros et les coups reçus partent / arrivent sur les cartes (les effets avancés de monstres demandent Forward+ et un palier ≥ 1, voir SpellFxLibrary.cast).
static func usable() -> bool:
	return Settings.card_fx

## Joue l'effet dans la couche. `main_cam` / `view` / `view_vp` : caméra, zone et rendu de la vue du jeu ; `centers` : centre de chaque carte du groupe
## (pixels de la fenêtre, dans l'ordre du groupe). Renvoie faux si l'effet n'a pas pu être placé (l'appelant le joue alors dans la vue).
func play(spell_id: String, target: Dictionary, ctx: Dictionary, main_cam: Camera3D, view: Control, view_vp: SubViewport, centers: Array, bottoms: Array = []) -> bool:
	if main_cam == null or view == null or view_vp == null or centers.is_empty() or size.y < 50.0 or view.size.y < 50.0:
		return false
	_frame(main_cam, view)
	var c := ctx.duplicate()
	c["slotPx"] = centers.map(func(p): return (p as Vector2) - global_position)
	c["slotStartPx"] = (bottoms if not bottoms.is_empty() else centers).map(func(p): return (p as Vector2) - global_position)
	var tgt := _remap(target, main_cam, view, view_vp)
	if tgt.is_empty() and not target.is_empty():
		return false
	var pts: Array = []
	for t in ctx.get("targets", []):
		var m := _remap(t, main_cam, view, view_vp)
		if not m.is_empty():
			pts.append(m)
	c["targets"] = pts
	visible = true
	_idle = 0.0
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	SpellFxLibrary.cast(_world, _cam, spell_id, tgt, c)
	return true

## Caméra de la couche : même nombre de pixels par unité de monde qu'à l'écran de jeu, tan(fov_couche / 2) = tan(fov_vue / 2) × (hauteur couche / hauteur vue).
func _frame(main_cam: Camera3D, view: Control) -> void:
	_cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(main_cam.fov * 0.5)) * size.y / view.size.y))
	_cam.global_transform = Transform3D.IDENTITY

## Effet d'action (coup de monstre sur un héros) : `ctx.victim` = place du héros touché.
## `target` / `view_vp` : monstre visé dans la vue du jeu (flèche de l'archer, qui part de la carte de l'archer).
func play_action(kind: String, ctx: Dictionary, main_cam: Camera3D, view: Control, centers: Array, target: Dictionary = {}, view_vp: SubViewport = null, bottoms: Array = []) -> bool:
	if main_cam == null or view == null or centers.is_empty() or size.y < 50.0 or view.size.y < 50.0:
		return false
	_frame(main_cam, view)
	var c := ctx.duplicate()
	c["slotPx"] = centers.map(func(p): return (p as Vector2) - global_position)
	c["slotStartPx"] = (bottoms if not bottoms.is_empty() else centers).map(func(p): return (p as Vector2) - global_position)
	var tgt := {}
	if not target.is_empty() and view_vp != null:
		tgt = _remap(target, main_cam, view, view_vp)
		if tgt.is_empty():
			return false
	visible = true
	_idle = 0.0
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	SpellFxStyles.cast_action(_world, _cam, kind, tgt, c)
	return true

## Point du monde de la vue → point de la couche à l'écran identique (même profondeur).
func _remap(t: Dictionary, main_cam: Camera3D, view: Control, view_vp: SubViewport) -> Dictionary:
	if t.is_empty() or not t.has("pos"):
		return {}
	var p: Vector3 = t.pos
	var depth := (p - main_cam.global_position).dot(-main_cam.global_transform.basis.z)
	if depth < 0.1:
		return {}
	var px := main_cam.unproject_position(p) * (view.size / Vector2(view_vp.size))
	var win := view.global_position + px - global_position
	var out := t.duplicate()
	out["pos"] = _cam.project_position(win, depth)
	return out

func _process(delta: float) -> void:
	if not visible:
		return
	if _world.get_child_count() > 2:       # environnement + caméra + effets en cours
		_idle = 0.0
		return
	_idle += delta
	if _idle > 0.4:
		visible = false
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
