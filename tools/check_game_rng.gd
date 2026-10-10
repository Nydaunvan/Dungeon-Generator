extends Node
## Vérifie le hasard des règles (GameRng) : flux reproductibles et indépendants, état sauvegardable (même après un aller-retour
## JSON), valeurs de référence figées (« golden ») pour détecter tout changement de moteur ou de plateforme.
## À lancer aussi sur Windows/Linux avant de s'appuyer sur la vérification : les valeurs doivent être identiques partout.
## Lancer : godot --headless --path . res://tools/check_game_rng.tscn

var fails := 0

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func draw(name: String, n: int) -> Array:
	var out: Array = []
	for k in n:
		out.append(GameRng.range_i(name, 1, 1000))
	return out

func _ready() -> void:
	# flux reproductibles
	GameRng.begin(12345)
	var a := draw("combat", 20)
	GameRng.begin(12345)
	var b := draw("combat", 20)
	check("même graine : même suite", a == b)
	GameRng.begin(12346)
	check("graine voisine : autre suite", draw("combat", 20) != a)

	# indépendance des flux
	GameRng.begin(7)
	var c1 := draw("combat", 10)
	var l1 := draw("loot", 10)
	GameRng.begin(7)
	draw("loot", 3)                # tirages supplémentaires dans un AUTRE flux
	draw("trap", 5)
	check("un autre flux ne décale pas « combat »", draw("combat", 10) == c1)
	GameRng.begin(7)
	check("le flux « loot » est indépendant de « combat »", draw("loot", 10) == l1 and l1 != c1)

	# mélange et choix reproductibles
	GameRng.begin(99)
	var arr1 := [1, 2, 3, 4, 5, 6, 7, 8]
	GameRng.shuffle("trap", arr1)
	var p1 = GameRng.pick("trap", [10, 20, 30, 40])
	GameRng.begin(99)
	var arr2 := [1, 2, 3, 4, 5, 6, 7, 8]
	GameRng.shuffle("trap", arr2)
	check("mélange reproductible", arr1 == arr2 and arr1 != [1, 2, 3, 4, 5, 6, 7, 8])
	check("choix reproductible", GameRng.pick("trap", [10, 20, 30, 40]) == p1)
	var sorted := arr2.duplicate()
	sorted.sort()
	check("le mélange est une permutation", sorted == [1, 2, 3, 4, 5, 6, 7, 8])

	# état : sauvegarde / reprise, y compris à travers le JSON (nombres 64 bits)
	GameRng.begin(Seeds.from_text("graine-serveur-xyz"))
	draw("combat", 7)
	draw("loot", 3)
	var state := GameRng.export_state()
	var suite := draw("combat", 15) + draw("loot", 15)
	var over_json: Dictionary = JSON.parse_string(JSON.stringify(state))
	GameRng.begin(1)               # on « perd » tout, puis on reprend la sauvegarde
	GameRng.import_state(over_json)
	check("reprise après JSON : même suite", draw("combat", 15) + draw("loot", 15) == suite)

	# valeurs de référence figées (si l'une change, la vérification serveur ne serait plus fiable)
	var d := [Seeds.derive(1, "expedition", 1), Seeds.derive(1, "expedition", 2), Seeds.from_text("abc"), Seeds.derive(Seeds.from_text("abc"), "stream", 0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var r := [rng.randi(), rng.randi_range(1, 100), rng.randi_range(-5, 5), int(rng.randf() * 1000000.0)]
	GameRng.begin(Seeds.from_text("golden"))
	var g := draw("combat", 5)
	print("golden seeds : ", d)
	print("golden rng   : ", r)
	print("golden stream: ", g)
	check("valeurs de référence : graines dérivées", d == GOLDEN_SEEDS)
	check("valeurs de référence : générateur natif", r == GOLDEN_RNG)
	check("valeurs de référence : flux de jeu", g == GOLDEN_STREAM)
	print("check_game_rng : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)

const GOLDEN_SEEDS := [2018574139777513531, 8351741462801058856, 5933606740773078275, 3350612501988426496]
const GOLDEN_RNG := [1748751541, 38, -5, 467168]
const GOLDEN_STREAM := [167, 367, 577, 809, 510]
