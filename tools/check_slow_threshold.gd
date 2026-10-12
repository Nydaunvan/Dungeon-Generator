extends SceneTree
## Seuil « trop lent » de l'adaptation automatique : 95 i/s ne doit pas faire baisser la qualité, même avec une cible de 120.
## Usage : godot --headless --path . --script res://tools/check_slow_threshold.gd
func _init() -> void:
	await process_frame
	var st = root.get_node("Settings")
	st.vsync = false
	st.fps_cap = 0
	var bad := 0
	for row in [[30, 25.5], [60, 51.0], [90, 63.0], [120, 84.0]]:
		st.target_fps = int(row[0])
		var th: float = st.slow_threshold()
		print("cible %d -> seuil %.1f" % [row[0], th])
		if absf(th - float(row[1])) > 0.01:
			bad += 1
			print("ÉCHEC : seuil attendu ", row[1])
	st.target_fps = 120
	if 95.0 < st.slow_threshold():
		bad += 1
		print("ÉCHEC : 95 i/s jugé trop lent")
	print("anomalies : ", bad)
	quit(1 if bad > 0 else 0)
