extends Node
## Régénération en exploration : 8 pas neufs (normal) → +1 % ; va-et-vient sans gain ; plafond 60 % ; poison ; cooldown après combat ; hardcore = 20 pas.
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout
	var gs: GameState = main.gs
	var ok := true
	for c in gs.party:
		c["hp"] = 10
	var h: Dictionary = gs.party[0]
	h["maxHp"] = 200
	gs.stats.erase("regenSteps"); gs.stats.erase("regenTrail"); gs.stats["regenCooldown"] = 0
	var got := {}
	for i in 8:
		got = ExploreRegen.on_step(gs, Vector2i(i, 0), "normal", false)
	var a: bool = got.has(str(h.id)) and int(h.hp) >= 12 and int(h.hp) <= 13
	print("8 pas neufs: hp=", h.hp, " ", a)
	var before := int(h.hp)
	for i in 30:
		ExploreRegen.on_step(gs, Vector2i(100 + (i % 2), 0), "normal", false)
	var b: bool = int(h.hp) <= before + 2
	print("va-et-vient: hp=", h.hp, " ", b)
	h["hp"] = 119
	gs.stats["regenSteps"] = 7; gs.stats["regenTrail"] = []
	ExploreRegen.on_step(gs, Vector2i(500, 5), "normal", false)
	var c1: bool = int(h.hp) == 120
	print("plafond 60%: hp=", h.hp, " ", c1)
	h["hp"] = 50
	Statuses.give(h, "poison", 3, "x")
	gs.stats["regenSteps"] = 7; gs.stats["regenTrail"] = []
	ExploreRegen.on_step(gs, Vector2i(501, 5), "normal", false)
	var d: bool = int(h.hp) == 50
	print("poison: hp=", h.hp, " ", d)
	var hc := 0
	for i in 40:
		gs.stats["regenTrail"] = []
		var r := ExploreRegen.on_step(gs, Vector2i(600 + i, 0), "hardcore", false)
		if not r.is_empty(): hc += 1
	print("hardcore: impulsions sur 40 pas (attendu 2): ", hc)
	var ok2 := a and b and c1 and d and hc <= 2 and hc >= 1
	print("RESULTAT regen -> ", "OK" if ok2 else "ECHEC")
	get_tree().quit()
