class_name Village
extends RefCounted
## Village : place extérieure avec marchand, forgeron et Maître des Talents. Portage de buildVillageLevel.

static func build_level() -> Dictionary:
	var rows := ["#####S#####", "#.........#", "#.........#", "#.........#", "#.........#", "#.........#", "#####S#####"]
	var exclude := ["5,1", "4,1", "6,1", "5,2", "5,4", "5,5", "4,5", "6,5"]   # jamais d'arbre devant une arche
	var sx := 5
	var sy := 3
	var row_pool := [1, 2, 3, 4, 5]
	row_pool.shuffle()
	var spots: Array = []
	for k in 3:
		var y: int = row_pool[k]
		var xs: Array = []
		for x in range(1, 10):
			if (x == sx and y == sy) or exclude.has("%d,%d" % [x, y]):
				continue
			xs.append(x)
		spots.append(Vector2i(xs[randi() % xs.size()], y))
	var path := {}
	for y in 7:
		path["5,%d" % y] = true
	for sp in spots:
		var dir := 1 if sp.x > 5 else -1
		var x := 5
		while x != sp.x + dir:
			path["%d,%d" % [x, sp.y]] = true
			x += dir
	var npc := {}
	for sp in spots:
		npc["%d,%d" % [sp.x, sp.y]] = true
	var chance := 0.28 + randf() * 0.22
	var trees: Array = []
	for y in range(1, 6):
		for x in range(1, 10):
			var key := "%d,%d" % [x, y]
			if (x == sx and y == sy) or exclude.has(key) or npc.has(key) or path.has(key):
				continue
			if randf() < chance:
				trees.append(key)
	return {"id": "village_%d" % Time.get_ticks_msec(), "name": "Village", "theme": "stone", "mapRows": rows, "outdoor": true,
		"startX": sx, "startY": sy, "startDir": 0, "doors": [], "monsters": [], "items": [],
		"stairs": [{"id": "village_exit", "x": 5, "y": 0, "action": {"type": "villageExit"}},
			{"id": "village_return", "x": 5, "y": 6, "action": {"type": "villageReturn"}}],
		"treeExcludeCells": exclude, "treeCells": trees, "pathCells": path.keys(),
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
	cfg["levels"] = gen.levels(int(dims.numLevels), int(dims.width), int(dims.height), party_power(gs))
	cfg["title"] = DungeonGenerator.title()
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
