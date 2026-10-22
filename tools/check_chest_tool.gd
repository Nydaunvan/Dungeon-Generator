extends Node
## Vérifie le coffre posé à la main : contenu pris dans la bibliothèque, identifiants uniques, côté du mur automatique.

func _ready() -> void:
	var bad := 0
	var lib: Array = Data.config.get("itemLibrary", [])
	if lib.size() < 2:
		print("ÉCHEC : bibliothèque trop petite")
		get_tree().quit(1)
		return
	var gs := GameState.new()
	gs.cfg = {"itemLibrary": lib}
	var ia := Interactions.new()
	ia.gs = gs
	var chest := {"id": "c1", "type": "chest", "x": 1, "y": 1, "gold": 25, "contentIds": [lib[0].id, "", lib[1].id, "inconnu"]}
	var got: Array = ia._chest_contents(chest)
	if got.size() != 2 or str(got[0].id) == str(got[1].id) or str(got[0].id) != "chestlib_c1_1" or str(got[1].id) != "chestlib_c1_3":
		bad += 1
		print("ÉCHEC contenu : ", got.map(func(c): return c.id))
	var rows := ["###", "#.#", "#.."]
	var lvl := {"mapRows": rows}
	var w1 := AdminLevels._chest_auto_wall(lvl, 1, 1)
	var w2 := AdminLevels._chest_auto_wall(lvl, 2, 2)
	if w1 != "N" or w2 != "N":
		bad += 1
		print("ÉCHEC mur auto : ", w1, " ", w2)
	var w3 := AdminLevels._chest_auto_wall({"mapRows": ["...", ".#.", "..."]}, 1, 0)
	if w3 != "N":      # hors carte = mur
		bad += 1
		print("ÉCHEC mur hors carte : ", w3)
	var w4 := AdminLevels._chest_auto_wall({"mapRows": ["...", ".#.", "..."]}, 0, 1)
	if w4 != "E":
		bad += 1
		print("ÉCHEC mur E : ", w4)
	print("check_chest_tool : ", "OK" if bad == 0 else "%d échec(s)" % bad)
	get_tree().quit(1 if bad > 0 else 0)
