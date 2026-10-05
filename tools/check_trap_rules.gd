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
	for id in ["disarm", "force", "dispel", "probe", "volunteer", "bypass", "sacrifice"]:
		pass
	print("TRAP RULES ", "OK" if bad == 0 else "%d erreurs" % bad)
	get_tree().quit()
