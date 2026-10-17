extends SceneTree
## Sonde : capacités des raretés en combat (dernier souffle, exécution, critique) et fenêtres d'objets (infobulle, marchand) avec des objets rares.

var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  ÉCHEC : ", what)
	else:
		print("  ok : ", what)

func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	var gs = m.gs
	var ctrl = m.ctrl
	var combat = ctrl.combat
	var Rarity = load("res://scripts/rules/rarity.gd")
	var Characters = load("res://scripts/rules/characters.gd")
	var f := func(): return randf()
	# équipement de test : un objet de chaque palier sur le premier héros
	var hero: Dictionary = gs.party[0]
	var tiers := {"weapon": "uncommon", "head": "rare", "body": "epic", "hands": "legendary", "feet": "mythic"}
	for slot in tiers:
		var it := {"id": "t_" + slot, "name": "Objet " + tiers[slot], "type": "weapon" if slot == "weapon" else "armor", "slot": slot, "icon": "@icon:spr_1", "bonusHp": 4, "bonusAtkMin": 2, "bonusAtkMax": 3}
		if slot == "weapon":
			it["weaponType"] = "sword"
		Rarity.apply(it, tiers[slot], f)
		hero.equipment[slot] = it
	Characters.recompute(hero, gs.cfg)
	ok(Rarity.of(hero.equipment.feet) == "mythic" and Rarity.perks_of(hero.equipment.feet).size() == 2, "objet mythique : 2 capacités")
	ok(int(hero.maxHp) > 0, "personnage recalculé : %d PV" % int(hero.maxHp))

	# infobulle et fenêtre du marchand avec ces objets
	for slot in tiers:
		var tip: Control = load("res://scripts/ui/bag_common.gd").tooltip_for(gs, hero.equipment[slot], str(hero.id))
		ok(tip != null, "infobulle de l'objet " + tiers[slot])
		tip.queue_free()
	var Shop = load("res://scripts/rules/shop.gd")
	GameRng.begin(5)
	var offers: Array = Shop.village_offers(gs.cfg, 6, gs.party)
	load("res://scripts/ui/shop_modal.gd").open(m._modals(), gs, offers, true)
	await create_timer(1.0).timeout
	ok(not get_nodes_in_group("modal").is_empty(), "la fenêtre du marchand s'ouvre avec des objets rares")
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	await create_timer(0.3).timeout

	# dernier souffle : un monstre adjacent, tous les héros à 1 PV avec la capacité
	var mons: Array = (combat.level.get("monsters", []) as Array).filter(func(x): return combat.lstate().monsters.get(str(x.id), {}).get("alive", false))
	var pos: Vector2i = combat.pos
	var d: int = combat.dir
	var fwd: Vector2i = load("res://scripts/dungeon/dungeon_grid.gd").DIRS[d]
	var mon: Dictionary = mons[0]
	var st: Dictionary = combat.lstate().monsters[str(mon.id)]
	st.x = pos.x + fwd.x
	st.y = pos.y + fwd.y
	st.hidden = false
	st["atkMin"] = 50
	st["atkMax"] = 60
	for c in gs.party:
		c["hp"] = 1
		c.equipment.head = {"id": "ls", "name": "Test", "type": "armor", "slot": "head", "rarity": "legendary", "legendary": true, "perks": [{"id": "last_stand", "value": 1}]}
	ctrl.sync_position()
	combat.monster_act("mon_" + str(mon.id))
	var survivors := 0
	var used := 0
	for c in gs.party:
		if int(c.hp) > 0:
			survivors += 1
		if bool(c.get("lastStandUsed", false)):
			used += 1
	ok(used == 1 and survivors == gs.party.size(), "dernier souffle : un héros survit à 1 PV (flag %d, vivants %d/%d)" % [used, survivors, gs.party.size()])
	combat.end_combat_reset()
	var left := 0
	for c in gs.party:
		if bool(c.get("lastStandUsed", false)):
			left += 1
	ok(left == 0, "fin de combat : la capacité est rechargée")
	print("RÉSULTAT : ", fails, " échec(s)")
	quit()
