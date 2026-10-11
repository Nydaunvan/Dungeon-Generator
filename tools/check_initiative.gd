extends SceneTree
## Initiative : jauges + plafond. Personne ne rejoue avant que tous les autres vivants aient joué ; héros et monstres s'intercalent à égalité.
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
	# égalité : alternance des camps
	var c2 = T.new(null, {}, null)
	c2.speeds = cases["vitesses égales"]
	c2.ensure_gauges()
	var sides: Array = []
	for i in 8:
		var k: String = c2.advance_gauges_once()
		c2.gauges[k] = 0.0
		sides.append(0 if k.begins_with("char_") else 1)
	var run := 1
	var maxrun := 1
	for i in range(1, sides.size()):
		run = run + 1 if sides[i] == sides[i - 1] else 1
		maxrun = maxi(maxrun, run)
	check("vitesses égales : les camps alternent (série max %d)" % maxrun, maxrun <= 1)
	print("check_initiative : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
