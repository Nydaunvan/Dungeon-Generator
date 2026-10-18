extends Node
## Vue d'ensemble des bonus d'un héros très équipé : chaque effet est listé avec ses sources (objets, talents, statuts, classe, partie).
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var gs: GameState = main.gs
	var h: Dictionary = gs.party[0]
	h["equipment"] = {
		"weapon": {"id": "t1", "name": "Lame mythique", "icon": "", "type": "weapon", "rarity": "mythic", "bonusAtkMin": 5, "bonusAtkMax": 9, "bonusForce": 4, "bonusSpeed": 2,
			"resists": {"fire": 20, "shadow": 25}, "perks": [{"id": "critdmg", "value": 40}, {"id": "execute", "value": 20}, {"id": "last_stand", "value": 1}]},
		"body": {"id": "t3", "name": "Cuirasse mythique", "icon": "", "type": "armor", "slot": "body", "rarity": "mythic", "bonusHp": 30, "bonusCon": 5, "resists": {"fire": 15, "ice": -10},
			"perks": [{"id": "thorns", "value": 18}, {"id": "lifesteal", "value": 9}]},
		"accessory": {"id": "t2", "name": "Bague rare", "icon": "", "type": "jewelry", "rarity": "rare", "bonusDex": 3, "bonusInt": 2, "bonusSpellDmg": 3, "perks": [{"id": "gold", "value": 12}, {"id": "spell", "value": 8}, {"id": "crit", "value": 6}]}}
	Characters.recompute(h, gs.cfg)
	var groups := BonusOverview.build(h, gs.cfg)
	var n_entries := 0
	for g in groups:
		print("== %s (%d) sans effet: %s" % [g.title, g.entries.size(), str(g.inactive)])
		for e in g.entries:
			n_entries += 1
			print("  %s %s  %s" % [e.icon, e.label, e.value])
			for s in e.subs:
				print("      · ", s.text)
	var titles := groups.map(func(g): return str(g.title))
	var ok: bool = n_entries >= 12 and titles.size() == 7
	print("RESULTAT vue d'ensemble : %d entrées -> %s" % [n_entries, "OK" if ok else "ECHEC"])
	get_tree().quit()
