extends Node
## Héros solitaire : un seul héros, PV ×2 et dégâts ×1,33 ; sans le modificateur, rien ne change.
func _ready() -> void:
	var m: Dictionary = DungeonGenerator.combine_mods(["mod_solo"])
	var n: Dictionary = DungeonGenerator.combine_mods([])
	var cfg: Dictionary = DungeonGenerator.build_config(Data.original_config, 2, 13, 11, "normal", ["mod_solo"], 1, 12345)
	var ok: bool = absf(float(m.dmgMult) - 1.3333) < 0.001 and float(m.hpMult) == 2.0 and float(n.dmgMult) == 1.0 and (cfg.party as Array).size() == 1
	print("SOLO dmg=", m.dmgMult, " hp=", m.hpMult, " sans=", n.dmgMult, " party=", (cfg.party as Array).size(), " -> ", "OK" if ok else "ECHEC")
	get_tree().quit(0 if ok else 1)
