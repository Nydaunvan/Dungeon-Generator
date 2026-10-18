extends Node
## Détail par héros des effets d'objets : résistances des six écoles et capacités de rareté (cartes + sources).
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var gs: GameState = main.gs
	var h: Dictionary = gs.party[0]
	h["talents"] = []
	h["equipment"] = {
		"weapon": {"id": "t1", "name": "Épée test", "icon": "", "type": "weapon", "rarity": "epic", "perks": [{"id": "critdmg", "value": 40}, {"id": "execute", "value": 20}]},
		"body": {"id": "t3", "name": "Armure test", "icon": "", "type": "armor", "slot": "body", "resists": {"fire": 15, "shadow": -10}, "rarity": "rare", "perks": [{"id": "thorns", "value": 10}, {"id": "last_stand", "value": 1}]},
		"accessory": {"id": "t2", "name": "Bague test", "icon": "", "type": "jewelry", "resists": {"fire": 5}, "rarity": "rare", "perks": [{"id": "gold", "value": 12}, {"id": "spell", "value": 8}, {"id": "bleed", "value": 15}]}}
	Characters.recompute(h, gs.cfg)
	var ok := true
	for k in Resist.KEYS:
		var sec: Dictionary = StatExplain.data(h, gs.cfg, "res_" + k)
		print("res_%s total=%s rows=%s sources=%d" % [k, sec.value, sec.rows.map(func(r): return "%s=%s" % [r.k, r.v]), sec.sources.size()])
	var fire: Dictionary = StatExplain.data(h, gs.cfg, "res_fire")
	var shadow: Dictionary = StatExplain.data(h, gs.cfg, "res_shadow")
	var res_ok: bool = fire.sources.size() == 2 and shadow.sources.size() == 1
	var want := {"critdmg": 1, "execute": 1, "thorns": 1, "last_stand": 1, "gold": 1, "spell": 1, "bleed": 1}
	var perk_ok := true
	for p in want:
		var sec: Dictionary = StatExplain.data(h, gs.cfg, "perk_" + p)
		print("perk_%s total=%s sources=%d rule=%s" % [p, sec.value, sec.sources.size(), str(sec.rule).left(40)])
		perk_ok = perk_ok and sec.sources.size() == want[p] and str(sec.rule) != ""
	print("RESULTAT détails : resistances=%s capacités=%s -> %s" % [res_ok, perk_ok, "OK" if res_ok and perk_ok else "ECHEC"])
	get_tree().quit()
