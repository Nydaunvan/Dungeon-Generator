extends SceneTree
## Initiative : jauges + plafond. Personne ne rejoue avant que tous les autres vivants aient joué ; ordre stable (vitesse, puis héros avant monstres, puis ordre du groupe).
## Lancer : godot --headless --path . --script res://tools/check_initiative.gd
var fails := 0
func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func _init() -> void:
	await process_frame
	var C = load("res://scripts/rules/combat.gd")
	var T := GDScript.new()
	T.source_code = "extends \"res://scripts/rules/combat.gd\"\nvar speeds := {}\nfunc participant_speed(key: String) -> float:\n\treturn float(speeds.get(key, 0.0))\nfunc ensure_gauges() -> void:\n\tfor k in speeds:\n\t\tif not gauges.has(k):\n\t\t\tgauges[k] = 0.0\n"
	T.reload()
	var cases := {
		"4 héros / groupe de 2 monstres lents": {"char_a": 8, "char_b": 12, "char_c": 14, "char_d": 11, "mon_x#0": 8, "mon_x#1": 8},
		"héros lents / groupe de 3 rapides": {"char_a": 6, "char_b": 7, "mon_x#0": 15, "mon_x#1": 15, "mon_x#2": 15},
		"un héros très rapide / un monstre": {"char_a": 30, "mon_x": 5},
		"vitesses égales": {"char_a": 10, "char_b": 10, "mon_x#0": 10, "mon_x#1": 10},
	}
	for name in cases:
		var c = T.new(null, {}, null)
		c.speeds = cases[name]
		c.ensure_gauges()
		var n: int = (cases[name] as Dictionary).size()
		var seq: Array = []
		for i in n * 6:
			var preview: Array = c.upcoming(3)
			var k: String = c.advance_gauges_once()
			if i > 0 or true:
				check("%s : la frise annonce le bon prochain (tour %d)" % [name, i], preview.size() > 0 and preview[0] == k)
			c.gauges[k] = 0.0
			seq.append(k)
		# chaque tranche de n tours contient chacun une fois
		for r in 6:
			var slice: Array = seq.slice(r * n, (r + 1) * n)
			var uniq := {}
			for k in slice: uniq[k] = true
			check("%s : manche %d, chacun joue une fois (%s)" % [name, r + 1, " ".join(slice)], uniq.size() == n)
		print(name, " → ", " ".join(seq.slice(0, n * 2)))
	# ordre stable : la même séquence à chaque manche ; vitesse décroissante ; à égalité, héros avant monstres
	for name in cases:
		var c3 = T.new(null, {}, null)
		c3.speeds = cases[name]
		c3.ensure_gauges()
		var n3: int = (cases[name] as Dictionary).size()
		var seq3: Array = []
		for i in n3 * 4:
			var k3: String = c3.advance_gauges_once()
			c3.gauges[k3] = 0.0
			seq3.append(k3)
		for r in 4:
			check("%s : manche %d identique à la manche 1" % [name, r + 1], seq3.slice(r * n3, (r + 1) * n3) == seq3.slice(0, n3))
		for i in range(1, n3):
			var sa: float = (cases[name] as Dictionary)[seq3[i - 1]]
			var sb: float = (cases[name] as Dictionary)[seq3[i]]
			check("%s : vitesses décroissantes (%s puis %s)" % [name, seq3[i - 1], seq3[i]], sa >= sb)
	# la mort d'un monstre ne change pas l'ordre des autres ; un bonus de vitesse le change
	var sp := {"char_a": 14, "char_b": 12, "char_c": 9, "char_d": 7, "mon_x#0": 12, "mon_x#1": 12, "mon_x#2": 12}
	var c4 = T.new(null, {}, null)
	c4.speeds = sp.duplicate()
	c4.ensure_gauges()
	var before: Array = c4.upcoming(7)
	var sp2 := sp.duplicate()
	sp2.erase("mon_x#0")
	var c5 = T.new(null, {}, null)
	c5.speeds = sp2
	c5.ensure_gauges()
	var after: Array = c5.upcoming(6)
	var expect: Array = before.filter(func(k): return k != "mon_x#0")
	check("mort d'un loup : les autres gardent leur ordre (%s → %s)" % [" ".join(before), " ".join(after)], after == expect)
	var sp3 := sp.duplicate()
	sp3["mon_x#1"] = 17
	var c6 = T.new(null, {}, null)
	c6.speeds = sp3
	c6.ensure_gauges()
	check("bonus de vitesse : le loup passe en tête", c6.upcoming(1)[0] == "mon_x#1")
	# ancienne règle (parties enregistrées avant 1.34.0) : jauges + alternance des camps
	var AV = load("res://scripts/core/app_version.gd")
	check("is_before 1.33.6 < 1.34.0", AV.is_before("1.33.6", "1.34.0"))
	check("is_before 1.34.0 n'est pas < 1.34.0", not AV.is_before("1.34.0", "1.34.0"))
	check("is_before 1.34.0-test2 n'est pas < 1.34.0", not AV.is_before("1.34.0-test2", "1.34.0"))
	check("is_before 1.9.0 < 1.34.0", AV.is_before("1.9.0", "1.34.0"))
	C.legacy_initiative = true
	var c7 = T.new(null, {}, null)
	c7.speeds = {"char_r": 14, "char_a": 12, "char_m": 9, "char_g": 7, "mon_x#0": 12, "mon_x#1": 12, "mon_x#2": 12}
	c7.ensure_gauges()
	var legacy_seq: Array = []
	for i in 7:
		var k7: String = c7.advance_gauges_once()
		c7.gauges[k7] = 0.0
		legacy_seq.append(k7)
	C.legacy_initiative = false
	check("ancienne règle : R L A L L M G (%s)" % " ".join(legacy_seq), legacy_seq == ["char_r", "mon_x#0", "char_a", "mon_x#1", "mon_x#2", "char_m", "char_g"])
	print("check_initiative : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
