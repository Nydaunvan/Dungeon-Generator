extends SceneTree
## File d'initiative : le rond central ne montre que le participant dont c'est le tour, y compris pendant l'animation de son action.
## Lancer (Xvfb requis) : xvfb-run -a godot --path . --script res://tools/check_queue.gd
var fails := 0
func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func _key_of(k: String) -> String:
	if k.begins_with("char_"):
		return k.substr(5)
	var rest := k.substr(4)
	return rest.replace("#", "_")

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7, 1)
	data.launch(cfg, "random")
	await create_timer(8.0).timeout
	var m = current_scene
	var ctrl = m.ctrl
	var t_wait := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < t_wait and not ctrl.model_in_combat():
		await process_frame
	var q = m.layout.queue
	var samples := 0
	var bad := 0
	var held := 0
	var t_end := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < t_end and ctrl.model_in_combat():
		var cm = ctrl.combat
		if ctrl.in_combat() and cm != null:
			var cur := str(cm._state.get("current", ""))
			var acting: String = ctrl.queue_hold
			if acting == "" and cur != "" and float(cm.gauges.get(cur, 0.0)) >= 100.0:
				acting = cur
			if acting != "":
				var es: Array = q._entries(8)
				samples += 1
				if ctrl.queue_hold != "":
					held += 1
				if es.is_empty() or str(es[0].key) != _key_of(acting) or not bool(es[0].current):
					bad += 1
					print("  écart : agit=", acting, " centre=", es[0].key if not es.is_empty() else "∅")
			if not ctrl._busy and float(cm.gauges.get("char_" + str(m.gs.active_char_id), 0.0)) >= 100.0:
				ctrl.attack()
		await process_frame
	check("échantillons pris (%d, dont %d pendant une action)" % [samples, held], samples > 20)
	check("le centre montre toujours le participant qui agit (%d écarts)" % bad, bad == 0)
	print("check_queue : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(fails)
