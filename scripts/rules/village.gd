class_name Village
extends RefCounted
## Village : place extérieure avec marchand, forgeron et Maître des Talents. Portage de buildVillageLevel.

const W := 15                      # largeur (cases) ; le village est tout en longueur
const H := 45
const STREET_X := 7                # colonne de la rue centrale (3 cases de large : 6 à 8)
const PLAZA := Rect2i(4, 18, 7, 9) # place pavée au milieu de la rue (x, y, largeur, hauteur)
const HOUSE := 3                   # maison = 3 × 3 cases
const HOUSE_ROWS := [2, 7, 12, 31, 36, 41]       # première ligne de chaque maison, de chaque côté de la rue

## Village : une longue rue entre deux portes, une place au milieu, des maisons de chaque côté, des barrières et une lisière d'arbres.
## Les maisons occupent des cases pleines ('#') : on les contourne. Tout le reste est jouable.
static func build_level() -> Dictionary:
	var grid: Array = []
	for y in H:
		var row := ""
		for x in W:
			row += "#" if (x == 0 or x == W - 1 or y == 0 or y == H - 1) else "."
		grid.append(row)
	var set_cell := func(x: int, y: int, c: String):
		grid[y] = (grid[y] as String).substr(0, x) + c + (grid[y] as String).substr(x + 1)
	set_cell.call(STREET_X, 0, "S")
	set_cell.call(STREET_X, H - 1, "S")
	var houses: Array = []
	for side in [0, 1]:
		var hx := 1 if side == 0 else W - 1 - HOUSE            # 1..3 à gauche, 11..13 à droite
		for hy in HOUSE_ROWS:
			var kind := "timber"
			var r := GameRng.f("village")
			if r < 0.38:
				kind = "brick"
			elif r > 0.93:
				kind = "ruin"
			houses.append({"x": hx, "y": hy, "w": HOUSE, "h": HOUSE, "face": "E" if side == 0 else "W", "kind": kind})
			for yy in range(hy, hy + HOUSE):
				for xx in range(hx, hx + HOUSE):
					set_cell.call(xx, yy, "#")
	var path := {}
	for y in range(1, H - 1):
		for x in range(STREET_X - 1, STREET_X + 2):
			path["%d,%d" % [x, y]] = true
	for hse in houses:                                        # allée de la porte de la maison jusqu'à la rue
		var dy: int = int(hse.y) + 1
		var xs: Array = range(4, 6) if hse.face == "E" else range(9, 11)
		for xx in xs:
			path["%d,%d" % [xx, dy]] = true
	var plaza: Array = []
	for yy in range(PLAZA.position.y, PLAZA.position.y + PLAZA.size.y):
		for xx in range(PLAZA.position.x, PLAZA.position.x + PLAZA.size.x):
			plaza.append("%d,%d" % [xx, yy])
	var sx := STREET_X
	var sy := PLAZA.position.y + PLAZA.size.y / 2
	# trois PNJ sur le pourtour de la place, dans un ordre tiré au hasard
	var spots_pool: Array = [Vector2i(5, 19), Vector2i(9, 19), Vector2i(5, 25), Vector2i(9, 25), Vector2i(4, 22), Vector2i(10, 22)]
	GameRng.shuffle("village", spots_pool)
	var spots: Array = spots_pool.slice(0, 3)
	var npc := {}
	for sp in spots:
		npc["%d,%d" % [sp.x, sp.y]] = true
	var trees: Array = []
	var chance := 0.16 + GameRng.f("village") * 0.1
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var key := "%d,%d" % [x, y]
			if grid[y][x] != "." or path.has(key) or npc.has(key) or plaza.has(key):
				continue
			if y <= 3 or y >= H - 4:      # abords des portes dégagés
				continue
			if x == 1 or x == W - 2:      # le long des barrières : rangée d'arbres plus dense
				if GameRng.f("village") < chance * 2.2:
					trees.append(key)
				continue
			if GameRng.f("village") < chance:
				trees.append(key)
	return {"id": "village_%d" % GameRng.i("ids"), "name": "Village", "plazaCells": plaza, "theme": "stone", "mapRows": grid, "outdoor": true,
		"streetX": STREET_X, "houses": houses,
		"startX": sx, "startY": sy, "startDir": 0, "doors": [], "monsters": [], "items": [],
		"stairs": [{"id": "village_exit", "x": STREET_X, "y": 0, "action": {"type": "villageExit"}},
			{"id": "village_return", "x": STREET_X, "y": H - 1, "action": {"type": "villageReturn"}}],
		"treeExcludeCells": [], "treeCells": trees, "pathCells": path.keys(),
		"travelingMerchant": {"x": spots[0].x, "y": spots[0].y, "patrolRadius": 0},
		"blacksmith": {"x": spots[1].x, "y": spots[1].y}, "talentMaster": {"x": spots[2].x, "y": spots[2].y}}

## Force du groupe par rapport à des héros nus de même niveau (sert à dimensionner le donjon suivant).
static func party_power(gs: GameState) -> float:
	if gs.party.is_empty():
		return 1.0
	var lv := 0.0
	var atk := 0.0
	var hp := 0.0
	for c in gs.party:
		lv += float(c.level)
		atk += (float(c.atkMin) + float(c.atkMax)) / 2.0
		hp += float(c.maxHp)
	var n := float(gs.party.size())
	var naked := Stats.char_base({"force": 10, "dex": 10, "con": 10, "level": lv / n})
	var naked_atk := (float(naked.baseAtkMin) + float(naked.baseAtkMax)) / 2.0
	var atk_ratio := (atk / n) / naked_atk if naked_atk > 0.0 else 1.0
	var hp_ratio := (hp / n) / float(naked.maxHp) if float(naked.maxHp) > 0.0 else 1.0
	return clampf(atk_ratio * 0.65 + hp_ratio * 0.35, 1.0, 3.0)

## Génère le donjon suivant (plus difficile) dans la configuration de la partie et remet l'état des niveaux à zéro.
static func next_dungeon(gs: GameState, mods: Array) -> void:
	gs.run_number += 1
	var cfg := gs.cfg
	var dims: Dictionary = cfg.get("genDims", {"numLevels": 3, "width": 13, "height": 11})
	var diff := str(cfg.get("genDifficulty", "normal"))
	var gen := DungeonGenerator.new(cfg, diff, gs.run_number, mods)
	var power := party_power(gs)
	var make := func():
		cfg["levels"] = gen.levels(int(dims.numLevels), int(dims.width), int(dims.height), power)
		cfg["title"] = DungeonGenerator.title()
	if gs.run_seed != "":      # partie classée : le donjon de l'expédition n°N est une fonction de la graine de la partie
		Seeds.with_global(Seeds.derive(Seeds.from_text(gs.run_seed), "expedition", gs.run_number), make)
	else:
		make.call()
	cfg["runModifierIds"] = mods.duplicate()
	gs.run_mods_chosen = true
	gs.level_states = {}
	gs.game_over = false
	gs.won = false
	gs.last_attacker_id = ""
	gs.in_village = false
	gs.village_prev = {}
	for c in gs.party:
		Characters.recompute(c, cfg)
	gs.add_log(L.fa(L.t("rules.village.le_groupe_enfonce_dans_un"), [cfg.title, gs.run_number]))
