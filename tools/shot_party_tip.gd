extends Node
## Fiche de survol du héros seul (défi solitaire) : doit s'afficher au-dessus de la carte, même complète.
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var gs: GameState = main.gs
	gs.party = [gs.party[0]]
	var h: Dictionary = gs.party[0]
	var mk := func(id: String, tp: String, slot: String) -> Dictionary:
		return {"id": id, "name": "Pièce " + id, "icon": "", "type": tp, "slot": slot, "rarity": "rare", "bonusHp": 10, "bonusCon": 3, "bonusForce": 2, "bonusDex": 2, "bonusAtkMin": 2, "bonusAtkMax": 4,
			"perks": [{"id": "crit", "value": 6}]}
	h["equipment"] = {"weapon": mk.call("a", "weapon", ""), "head": mk.call("b", "armor", "head"), "body": mk.call("c", "armor", "body"), "hands": mk.call("d", "armor", "hands"),
		"feet": mk.call("e", "armor", "feet"), "accessory": mk.call("f", "jewelry", "")}
	Characters.recompute(h, gs.cfg)
	main.layout.hud.refresh() if main.layout.hud.has_method("refresh") else null
	await get_tree().create_timer(0.5).timeout
	var card: Control = main.layout.hud._cards[str(h.id)].card
	PartyTip.show_for(card, gs, h)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/ptip.png")
	var tip: Control = PartyTip._inst
	print("CARTE ", card.get_global_rect(), " TIP ", tip.position, tip.size)
	print("RESULTAT fiche -> %s" % ("OK" if tip.position.y + tip.size.y <= card.get_global_rect().position.y + 1.0 else "SUPERPOSEE/EN DESSOUS"))
	get_tree().quit()
