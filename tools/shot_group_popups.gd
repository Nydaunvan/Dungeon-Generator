extends Node
## Chiffres de dégâts d'un groupe : chaque membre porte les siens au-dessus de lui (capture + positions).
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	var stage = main.level_node.stage
	var def := {"id": "tst", "name": "Gobelins", "icon": "@icon:mon_cavegoblin", "isGroup": true, "groupSize": 3}
	var st := {"alive": true, "enraged": false, "hp": 30.0, "maxHp": 30.0,
		"members": [{"alive": true, "hp": 10.0}, {"alive": true, "hp": 10.0}, {"alive": true, "hp": 10.0}]}
	var dir := int(main.rig.dir) if "dir" in main.rig else 0
	main.layout.sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.enter("stone", Vector2i(main.rig.gx, main.rig.gy), dir, def, st, 1)
	await get_tree().create_timer(1.0).timeout
	var xs: Array = []
	for i in 3:
		var p: Vector2 = main._member_head_global(i)
		xs.append(p)
		main._show_popup("-%d" % (7 + i), Color("ffd88a"), "mon:%d" % i)
	print("TETES ", xs)
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/popups.png")
	var ok: bool = xs[0].x > 0 and xs[0].x < xs[1].x and xs[1].x < xs[2].x
	print("RESULTAT popups groupe -> %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()
