extends Node
## Les bonus des objets (Dextérité, Constitution, capacités de rareté, ensemble mythique, modificateurs de partie) apparaissent dans les cartes
## Critique / Esquive / Garde, et leurs totaux sont ceux du combat.
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var gs: GameState = main.gs
	var h: Dictionary = gs.party[0]
	h["dex"] = 10; h["con"] = 10
	h["talents"] = []
	h["equipment"] = {
		"weapon": {"id": "t1", "name": "Épée test", "icon": "", "type": "weapon", "bonusDex": 4, "rarity": "rare", "perks": [{"id": "crit", "value": 5}]},
		"accessory": {"id": "t2", "name": "Bague test", "icon": "", "type": "jewelry", "bonusDex": 3, "rarity": "uncommon", "perks": [{"id": "dodge", "value": 3}]},
		"body": {"id": "t3", "name": "Armure test", "icon": "", "type": "armor", "slot": "body", "bonusCon": 6}}
	Characters.recompute(h, gs.cfg)
	var ok := true
	for key in ["crit", "dodge", "guard"]:
		var sec: Dictionary = StatExplain.data(h, gs.cfg, key)
		var names := []
		for s in sec.sources:
			names.append("%s %s%s" % [s.name, s.value, str(s.parts)])
		print("%s : total=%s  sources=%s" % [key, sec.value, names])
		print("   lignes: ", sec.rows.map(func(r): return "%s=%s" % [r.k, r.v]))
	# attendu : Dex 17 → crit 7 + rareté 5 = 12 ; esquive floor(7*0.8)=5 + 3 = 8 ; garde Con 16 → 6
	var crit_ok: bool = Stats.crit_total(h) == 12 and StatExplain.data(h, gs.cfg, "crit").value == "12 %"
	var dodge_ok: bool = int(h.dodgePct) == 8 and StatExplain.data(h, gs.cfg, "dodge").value == "8 %"
	var guard_ok: bool = int(h.guardPct) == 6 and StatExplain.data(h, gs.cfg, "guard").value == "6 %"
	var src_crit: Array = StatExplain.data(h, gs.cfg, "crit").sources
	var src_ok: bool = src_crit.size() == 2     # épée (Dex + capacité) et bague (Dex)
	var src_dodge: bool = StatExplain.data(h, gs.cfg, "dodge").sources.size() == 2
	print("RESULTAT stats objets : crit=%s esquive=%s garde=%s sources_crit=%s sources_esquive=%s -> %s" % [crit_ok, dodge_ok, guard_ok, src_ok, src_dodge, "OK" if crit_ok and dodge_ok and guard_ok and src_ok and src_dodge else "ECHEC"])
	get_tree().quit()
