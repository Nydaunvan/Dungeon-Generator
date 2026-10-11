extends SceneTree
## Capture des fenêtres de survol des statistiques. Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_stattip.gd -- <largeur> <hauteur> <sortie.png> [clés…]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280
	var h := int(a[1]) if a.size() > 1 else 720
	var out := a[2] if a.size() > 2 else "/tmp/stattip.png"
	var keys: Array = Array(a.slice(3)) if a.size() > 3 else ["force", "dex", "con", "int"]
	root.size = Vector2i(w, h)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	var gs = m.gs
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var c: Dictionary = gs.party[1]
	var CH = load("res://scripts/rules/characters.gd")
	c["equipment"]["weapon"] = {"name": "Épée de test", "type": "weapon", "slot": "weapon", "icon": "@icon:sword_holy", "bonusForce": 3, "bonusAtkMin": 2, "bonusAtkMax": 4}
	c["equipment"]["head"] = {"name": "Casque du Gardien", "type": "armor", "slot": "head", "icon": "@icon:helm_winged", "bonusCon": 2, "bonusHp": 6, "bonusSpellDmg": 1, "bonusDex": 1}
	CH.recompute(c, gs.cfg)
	var host := Control.new()
	host.position = Vector2(w * 0.5 - 80, h * 0.62)
	host.size = Vector2(160, 30)
	m.add_child(host)
	var SE = load("res://scripts/ui/stat_explain.gd")
	var ST = load("res://scripts/ui/stat_tip.gd")
	ST._host = host
	var t = ST._inst_for(host)
	await t._show(host, SE.many_data(c, gs.cfg, keys))
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out)
	print("capture : ", out, " panel ", t.position, t.size, " hôte ", host.get_global_rect(), " vue ", root.get_visible_rect().size)
	quit()
