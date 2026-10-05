extends Node
## Vérifie les générateurs de puzzles de piège : indice de fils toujours unique et vrai, chemin de dalles toujours valide.

func _ready() -> void:
	var TR = TrapRules
	var bad := 0
	for n in [3, 4, 5, 6]:
		for t in 500:
			var d: Dictionary = TR.make_wires(n)
			var cols: Array = d.colors
			var tg: int = d.target
			var alive: Array = range(n)
			for c in d.clues:
				var ok := func(j: int) -> bool:
					match str(c.k):
						"not_color": return cols[j] != str(c.a)
						"not_next": return not ((j > 0 and cols[j - 1] == str(c.a)) or (j < n - 1 and cols[j + 1] == str(c.a)))
						"gap": return (j >= 2 and cols[j - 2] == str(c.a)) or (j <= n - 3 and cols[j + 2] == str(c.a))
						"temp_warm": return ["red", "yellow"].has(cols[j])
						"temp_cold": return ["blue", "green", "violet"].has(cols[j])
						"temp_neutral": return not ["red", "yellow", "blue", "green", "violet"].has(cols[j])
						"between":
							var pr: PackedStringArray = str(c.a).split("|")
							return j > 0 and j < n - 1 and cols[j - 1] == pr[0] and cols[j + 1] == pr[1]
						"pos_not_end": return j != 0 and j != n - 1
						"pos_first_half": return j < n / 2
						"pos_last_half": return j >= n / 2
						"pos_nth": return j == int(c.a) - 1
						"below_color": return j > 0 and cols[j - 1] == str(c.a)
						"above_color": return j < n - 1 and cols[j + 1] == str(c.a)
					return false
				if not ok.call(tg):
					bad += 1
					print("indice faux ", n, " ", c)
				alive = alive.filter(func(j): return ok.call(j))
			if alive != [tg]:
				bad += 1
				print("indice non unique ", n, " ", d, " reste ", alive)
	for rows in [3, 4, 5, 6]:
		for t in 500:
			var p: Array = TR.make_tiles(rows)
			for i in range(1, p.size()):
				if absi(int(p[i]) - int(p[i - 1])) > 1:
					bad += 1
			if p.size() != rows:
				bad += 1
	var s: Dictionary = TR.cfg({})
	# l'offre d'un piège est tirée une fois puis retenue
	for t in 200:
		var st := {}
		var item := {"id": "trap_%d" % t, "trapKind": ["spikes", "dart", "pit", "gas"][t % 4]}
		var o1: Dictionary = TR.draw_offer(s, item, st)
		var o2: Dictionary = TR.draw_offer(s, item, st)
		if o1.methods != o2.methods or o1.puzzle != o2.puzzle or o1.kind.id != o2.kind.id:
			bad += 1
			print("offre instable ", o1, o2)
	var minc := 99
	for n in [3, 4, 5, 6]:
		for t in 300:
			minc = mini(minc, (TR.make_wires(n).clues as Array).size())
	print("indices minimum : ", minc)
	for id in ["disarm", "force", "dispel", "probe", "volunteer", "bypass", "sacrifice"]:
		pass
	print("TRAP RULES ", "OK" if bad == 0 else "%d erreurs" % bad)
	get_tree().quit()
