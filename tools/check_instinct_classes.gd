extends Node
## Effets de l'instinct parfait pour chaque classe du jeu (aucune erreur de script, PV cohérents).
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var combat: Combat = main.ctrl.combat
	var gs: GameState = main.gs
	var def := {"id": "t", "name": "Test", "isBoss": false}
	var st := {"enraged": false, "hp": 500.0, "alive": true}
	var n := 0
	var bad := 0
	for cls in gs.cfg.get("classes", []):
		var h: Dictionary = gs.party[0]
		h["classId"] = str(cls.id)
		h["maxHp"] = 100
		h["hp"] = 1
		h["shieldAmount"] = 0
		for c in gs.party:
			c["stamina"] = 10
		var dmg_ok := combat._instinct_damage(h, 40, "ok")
		var dmg_pf := combat._instinct_damage(h, 40, "perfect")
		combat._instinct_class_effect(def, st, h, 40)
		n += 1
		var fam := combat._class_family(h)
		print("%-14s famille=%-10s ok→dégâts %d, parfait→dégâts %d, PV après effet=%d bouclier=%d" % [str(cls.name), fam, dmg_ok, dmg_pf, int(h.hp), int(h.get("shieldAmount", 0))])
		if dmg_ok != 0 or dmg_pf < 0 or dmg_pf > 1:
			bad += 1
	print("RESULTAT classes=%d anomalies=%d -> %s" % [n, bad, "OK" if n > 0 and bad == 0 else "ECHEC"])
	get_tree().quit()
