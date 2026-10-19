extends Node
## Infobulle d'un objet déjà équipé : stats affichées, sans écart, pied « Équipé par … ».
func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var gs: GameState = main.gs
	var h: Dictionary = gs.party[0]
	var w := {"id": "t1", "name": "Lame", "icon": "", "type": "weapon", "rarity": "common", "bonusAtkMin": 5, "bonusAtkMax": 9, "bonusForce": 4}
	h["equipment"] = {"weapon": w}
	Characters.recompute(h, gs.cfg)
	var box := BagCommon.tooltip_for(gs, w, str(h.id))
	var t: Array = []
	_texts(box, t)
	print(t)
	var joined := " ".join(PackedStringArray(t))
	var ok: bool = joined.contains("+4") and joined.contains(str(h.name)) and not joined.contains("(=)") and not joined.contains("Remplace")
	print("RESULTAT infobulle équipé -> %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()
