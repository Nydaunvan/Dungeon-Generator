extends Node
## Statuts sur un groupe : un sort sur une cible ne touche que le membre visé ; un sort de zone touche tous les membres ;
## la brûlure ronge le membre (pas le groupe) et le tue seul ; le groupe tombe quand le dernier membre meurt.
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var combat: Combat = main.ctrl.combat
	var gs: GameState = main.gs
	var def := {"id": "tg", "name": "Gobelins", "isBoss": false, "isGroup": true, "groupSize": 3, "force": 10, "dex": 10, "con": 10, "x": 1, "y": 1}
	var st: Dictionary = gs.monster_state(def)
	combat.lstate().monsters["tg"] = st
	var mage: Dictionary = gs.party[0]
	var spell := {"id": "sp_t", "name": "Boule de feu", "style": "fire", "statusEffect": "burn", "statusChance": 100, "statusDuration": 3, "statusPower": 2}
	for m in st.members:
		m["hp"] = 30.0; m["maxHp"] = 30.0
	gs.selected_member["tg"] = 1
	combat._hit_monster(mage, def, 5, true, "lance", false, false, spell, false)
	var single_ok: bool = st.members[1].statusEffects.size() == 1 and (st.members[0].get("statusEffects", []) as Array).is_empty() and (st.members[2].get("statusEffects", []) as Array).is_empty() and (st.get("statusEffects", []) as Array).is_empty()
	print("cible unique : membre0=%d membre1=%d membre2=%d groupe=%d" % [(st.members[0].get("statusEffects", []) as Array).size(), st.members[1].statusEffects.size(), (st.members[2].get("statusEffects", []) as Array).size(), (st.get("statusEffects", []) as Array).size()])
	var hp_before_group := float(st.hp)
	var stun_a := combat.tick_monster(def, st, st.members[0])
	var m1_before := float(st.members[1].hp)
	combat.tick_monster(def, st, st.members[1])
	var burn_ok: bool = float(st.members[1].hp) == m1_before - 2.0 and float(st.members[0].hp) == 30.0 and float(st.hp) == hp_before_group
	print("brûlure : membre1 %.0f→%.0f, membre0 %.0f, groupe %.0f→%.0f" % [m1_before, float(st.members[1].hp), float(st.members[0].hp), hp_before_group, float(st.hp)])
	combat._hit_monster(mage, def, 5, true, "lance", true, false, spell, true)
	var all_ok := true
	for m in st.members:
		all_ok = all_ok and m.alive and (m.get("statusEffects", []) as Array).size() == 1
	print("sort de zone : tous touchés=%s" % all_ok)
	# mort par brûlure d'un seul membre
	st.members[2]["hp"] = 1.0
	combat.tick_monster(def, st, st.members[2])
	var death_ok: bool = not st.members[2].alive and st.alive and st.members[0].alive
	print("membre 2 mort de brûlure seul=%s groupe vivant=%s" % [not st.members[2].alive, st.alive])
	print("RESULTAT statuts de groupe : cible=%s brûlure=%s zone=%s mort=%s -> %s" % [single_ok, burn_ok, all_ok, death_ok, "OK" if single_ok and burn_ok and all_ok and death_ok else "ECHEC"])
	get_tree().quit()
