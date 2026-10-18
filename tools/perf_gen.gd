extends Node
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	for cfgp in [[3, 13, 11], [5, 25, 25], [8, 40, 40], [12, 40, 40]]:
		var t0 := Time.get_ticks_msec()
		var c := DungeonGenerator.build_config(Data.config, cfgp[0], cfgp[1], cfgp[2], "normal", [])
		print("niveaux=%d %dx%d -> %d ms (%d niveaux)" % [cfgp[0], cfgp[1], cfgp[2], Time.get_ticks_msec() - t0, (c.levels as Array).size()])
	get_tree().quit()
