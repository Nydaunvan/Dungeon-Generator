extends Node
## Rage : tirage aléatoire des monstres ordinaires, rage systématique des boss (désactivable), déclenchement sur un monstre ordinaire.
func _ready() -> void:
	var tot := 0
	var raged := 0
	var bosses := 0
	var boss_raged := 0
	for s in 40:
		var cfg := DungeonGenerator.build_config(Data.active(), 3, 13, 11, "normal", [], 1, 500 + s)
		for lv in cfg.levels:
			for m in lv.monsters:
				if m.get("isBoss", false):
					bosses += 1
					boss_raged += 1 if int(m.get("enrageThreshold", 0)) > 0 else 0
				else:
					tot += 1
					raged += 1 if int(m.get("enrageThreshold", 0)) > 0 else 0
	var base: Dictionary = Data.active().duplicate(true)
	base["bossRage"] = false
	base["monsterRageChancePct"] = 0
	var none := 0
	var cfg2 := DungeonGenerator.build_config(base, 3, 13, 11, "normal", [], 1, 77)
	for lv in cfg2.levels:
		for m in lv.monsters:
			none += 1 if int(m.get("enrageThreshold", 0)) > 0 else 0
	var pct := 100.0 * raged / maxf(1.0, tot)
	var good: bool = tot > 50 and pct > 10.0 and pct < 45.0 and bosses == boss_raged and none == 0
	print("RAGE ordinaires=", tot, " enragés=", snappedf(pct, 0.1), "% boss=", boss_raged, "/", bosses, " sans_rage=", none, " -> ", "OK" if good else "ECHEC")
	get_tree().quit(0 if good else 1)
