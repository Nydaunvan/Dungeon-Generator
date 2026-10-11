extends SceneTree
## Infobulle de statistique : un objet qui modifie plusieurs valeurs d'une carte n'apparaît qu'UNE fois, avec le détail.
var fails := 0
func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func _init() -> void:
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = data.original_config.duplicate(true)
	var SE = load("res://scripts/ui/stat_explain.gd")
	var c: Dictionary = (cfg.party[0] as Dictionary).duplicate(true)
	c["equipment"] = {"weapon": {"name": "Lame test", "icon": "", "bonusAtkMin": 2, "bonusAtkMax": 4, "bonusForce": 1}, "accessory": {"name": "Anneau test", "icon": "", "bonusAtkMax": 3}}
	c["talents"] = []
	c["atkMin"] = 5
	c["atkMax"] = 12
	var sec: Dictionary = SE.data(c, cfg, "atk")
	var srcs: Array = sec.sources
	var blade := srcs.filter(func(s): return str(s.name) == "Lame test")
	check("l'arme n'apparaît qu'une fois (%d)" % blade.size(), blade.size() == 1)
	check("avec 2 lignes de détail", blade.size() == 1 and (blade[0].parts as Array).size() == 2)
	var ring := srcs.filter(func(s): return str(s.name) == "Anneau test")
	check("un seul bonus : valeur directe", ring.size() == 1 and str(ring[0].value) == "+3" and (ring[0].parts as Array).is_empty())
	print(SE.flatten([sec]))
	print("check_sources : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(fails)
