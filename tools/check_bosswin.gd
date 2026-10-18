extends Node
func _ready() -> void:
	Sound.boss_win("boss_a")
	await get_tree().create_timer(0.9).timeout
	var p: AudioStreamPlayer = Sound._boss_player
	print("RESULTAT boss_win : lecteur=%s lit=%s flux=%s db=%s -> %s" % [p != null, p.playing if p else false, p.stream.get_length() if p and p.stream else -1, p.volume_db if p else 0, "OK" if p and p.playing else "ECHEC"])
	get_tree().quit()
