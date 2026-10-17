extends Node
## Préchauffage complet (effets de sorts, aura de rage, statuts) : doit se terminer sans erreur. godot --path . res://tools/check_warm_up.tscn
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	await WarmUp.run(self, func(_f): pass)
	print("WARMUP ok en ", Time.get_ticks_msec() - t0, " ms")
	get_tree().quit()
