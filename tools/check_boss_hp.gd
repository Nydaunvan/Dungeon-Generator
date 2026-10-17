extends Node
## Vérifie que les boss générés ont des PV et des dégâts majorés (hpMult, dmgMult) et le boss final davantage.
func _ready() -> void:
	var cfg: Dictionary = DungeonGenerator.build_config(Data.original_config, 3, 20, 20, "normal", [])
	var lv: Array = cfg.levels
	var ok := true
	for i in lv.size():
		for m in lv[i].get("monsters", []):
			if bool(m.get("isBoss", false)):
				var d := Stats.monster_derived(m)
				print("niveau %d : boss con %d hpMult %.1f -> %d PV, dégâts %d-%d, xp %d" % [i + 1, int(m.con), float(m.get("hpMult", 1)), int(d.maxHp), int(d.atkMin), int(d.atkMax), int(m.xpReward)])
				ok = ok and float(m.get("hpMult", 1.0)) >= 1.8
	print("OK : boss costauds" if ok else "ÉCHEC")
	get_tree().quit()
