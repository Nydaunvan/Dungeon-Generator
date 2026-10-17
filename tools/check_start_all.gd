extends Node
## Tous les sorts et attaques : l'effet doit démarrer sur le bord bas de la carte du lanceur (et pas en bas de l'écran).
var _best := 1e9
var _bot := Vector2.ZERO
var _ov: CardFxOverlay

func _on_added(n: Node) -> void:
	if n is Node3D and not n is Camera3D and _ov._world.is_ancestor_of(n):
		_probe.call_deferred(n)

func _probe(n: Node3D) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	var p3 := n.global_position
	if not _ov._cam.is_position_behind(p3):
		_best = minf(_best, _ov._cam.unproject_position(p3).distance_to(_bot))

func _ready() -> void:
	VisualFx.force_forward = false      # rendu de compatibilité simulé : les effets doivent quand même partir des cartes
	Settings.opts["fx_glow"] = false      # palier 0 : aucun halo, les effets doivent quand même partir des cartes
	print("TIER ", SpellFxLibrary.tier(), " usable=", CardFxOverlay.usable())
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var ov := CardFxOverlay.new()
	root.add_child(ov)
	get_window().size = Vector2i(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	var view := Control.new()
	view.position = Vector2(100, 50)
	view.size = Vector2(800, 500)
	root.add_child(view)
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 500)
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 70.0
	vp.add_child(cam)
	await get_tree().process_frame
	var centers := [Vector2(300, 700), Vector2(500, 700), Vector2(700, 700), Vector2(900, 700)]
	var bottoms := [Vector2(300, 780), Vector2(500, 780), Vector2(700, 780), Vector2(900, 780)]
	var tgt := {"pos": Vector3(0, 0, -4), "h": 1.5, "w": 1.0}
	var cfg: Dictionary = Data.active()
	var bad: Array = []
	var jobs: Array = []
	for sp in cfg.get("spells", []):
		jobs.append(["spell", str(sp.id), sp])
	for fxid in SpellFxLibrary.CATALOG:
		var fe: Dictionary = SpellFxLibrary.CATALOG[fxid]
		jobs.append(["fx", str(fxid), {"style": str((fe.styles as Array)[0]), "mode": str((fe.modes as Array)[0]), "fx": str(fxid), "status": "", "id": "t_" + str(fxid)}])
	for w in ["bow", "staff", "sword", "dagger", "axe", "mace", "unarmed"]:
		jobs.append(["weapon", w, {}])
	for j in jobs:
		for c in ov._world.get_children():
			if not c is Camera3D:
				c.free()
		_best = 1e9
		_bot = bottoms[1] - ov.global_position
		_ov = ov
		get_tree().node_added.connect(_on_added)
		var ok := false
		if j[0] == "fx":
			var ctx := {"style": j[2].style, "mode": j[2].mode, "fx": j[2].fx, "fxTint": "", "fxPower": 1.0, "status": "", "caster": 1, "ally": 1 if str(j[2].mode).begins_with("heal") else 0, "targets": [tgt, tgt], "solo": false}
			ok = ov.play("t_" + str(j[1]), tgt, ctx, cam, view, vp, centers, bottoms)
		elif j[0] == "spell":
			var ctx := SpellFxLibrary.ctx_for(j[2])
			ctx["caster"] = 1
			ctx["ally"] = 1 if str(ctx.mode).begins_with("heal") else 0
			ctx["targets"] = [tgt]
			ctx["solo"] = false
			if str(ctx.mode).ends_with("Group"):
				ctx["targets"] = [tgt, tgt]
			ok = ov.play(str(j[1]), tgt, ctx, cam, view, vp, centers, bottoms)
		else:
			ok = ov.play_action(str(j[1]), {"caster": 1, "solo": false}, cam, view, centers, tgt, vp, bottoms)
		# plus petite distance (écran) entre le point de départ voulu et le PREMIER emplacement de chaque élément créé pendant 0,6 s
		await get_tree().create_timer(0.6).timeout
		get_tree().node_added.disconnect(_on_added)
		var best := _best
		var tag := "%s %s ok=%s ecart=%d" % [j[0], j[1], ok, int(best)]
		print("START ", tag)
		if ["spell_archer1", "spell_nature1", "spell_arc1", "bow"].has(str(j[1])) and best > 5.0:
			bad.append(tag)
	print("STARTALL ", "OK" if bad.is_empty() else "ECHEC " + str(bad))
	get_tree().quit(0 if bad.is_empty() else 1)
