extends Node
## Entrée en rage d'un monstre : mesure la durée des images autour du moment où la rage démarre (à vide, ou après le préchauffage complet du chargement).
## Usage : WARM=1 xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/check_rage_hitch.tscn   (sans WARM : pas de préchauffage)

var _deltas: Array = []
var _rec := false

func _process(d: float) -> void:
	if _rec:
		_deltas.append(d * 1000.0)

func _stats(label: String) -> void:
	var mx := 0.0
	var at := 0
	var sum := 0.0
	for i in _deltas.size():
		sum += float(_deltas[i])
		if float(_deltas[i]) > mx:
			mx = float(_deltas[i])
			at = i
	print("%s : %d images, moyenne %.1f ms, pire image %.1f ms (n°%d)" % [label, _deltas.size(), sum / maxf(1.0, _deltas.size()), mx, at])
	_deltas.clear()

func _ready() -> void:
	if OS.get_environment("WARM") != "":
		await WarmUp.run(self, func(_f): pass)
		print("préchauffage fait")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	var g: DungeonGrid = main.grid
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var found := false
	for m in main.level.monsters:
		var stt: Dictionary = lst.get(str(m.id), {})
		if stt.is_empty() or not stt.alive or m.get("isGroup", false):
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(stt.x), int(stt.y)) - v
			if g.is_walkable(from.x, from.y):
				main.rig.place(g, from.x, from.y, d)
				found = true
				break
		if found:
			break
	main.ctrl.refresh()
	await get_tree().create_timer(2.5).timeout
	var eng: Dictionary = main.ctrl.combat.engaged()
	_rec = true
	await get_tree().create_timer(1.5).timeout
	_stats("sans rage (repère)")
	var st: Dictionary = main.ctrl.combat.lstate().monsters[str(eng.monster.id)]
	st["enraged"] = true
	main.ctrl.refresh()
	await get_tree().create_timer(2.0).timeout
	_stats("entrée en rage")
	get_tree().quit()
