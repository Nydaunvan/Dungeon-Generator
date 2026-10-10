extends Node
## Vérifie que la génération d'un donjon est REPRODUCTIBLE : mêmes (graine, paramètres) = même donjon, même groupe, mêmes titres,
## et qu'une graine différente donne un autre donjon. Affiche une empreinte par cas : lancée deux fois (deux processus), les
## empreintes doivent être identiques (rien ne dépend de l'ordre de la mémoire ou de l'heure).
## Lancer : godot --headless --path . res://tools/check_determinism.tscn

var fails := 0

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func fingerprint(cfg: Dictionary) -> String:
	return JSON.stringify(cfg, "", true).md5_text()      # clés triées : indépendant de l'ordre d'insertion

## Empreinte de la partie « logique » d'une structure : sans les textes affichés (noms, titres, descriptions), qui suivent la langue.
func _logic_print(v: Variant) -> String:
	return JSON.stringify(_strip_text(v), "", true).md5_text()

func _strip_text(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			if str(k) in ["name", "title", "description", "text", "label", "desc"]:
				continue
			out[k] = _strip_text(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x): return _strip_text(x))
	return v

func _ready() -> void:
	var base: Dictionary = Data.original_config
	var cases := [
		[3, 13, 11, "normal", []], [1, 7, 7, "easy", []], [8, 25, 21, "hard", []], [4, 13, 11, "hardcore", []],
	]
	var prints: Array = []
	for c in cases:
		for sd in [1, 42, 987654321012]:
			var a := DungeonGenerator.build_config(base, c[0], c[1], c[2], c[3], c[4], 1, sd)
			var b := DungeonGenerator.build_config(base, c[0], c[1], c[2], c[3], c[4], 1, sd)
			var fa := fingerprint(a)
			check("même graine, même donjon (%s, %d niveaux, graine %d)" % [c[3], c[0], sd], fa == fingerprint(b))
			prints.append(fa.substr(0, 8))
		var x := fingerprint(DungeonGenerator.build_config(base, c[0], c[1], c[2], c[3], c[4], 1, 1))
		var y := fingerprint(DungeonGenerator.build_config(base, c[0], c[1], c[2], c[3], c[4], 1, 2))
		check("graines différentes, donjons différents (%s)" % c[3], x != y)
	# expéditions successives : la graine de la partie + le numéro d'expédition suffisent
	var d1 := DungeonGenerator.build_config(base, 3, 13, 11, "normal", [], 1, 7)
	var d2 := DungeonGenerator.build_config(base, 3, 13, 11, "normal", [], 2, 7)
	check("expédition 1 et 2 de la même partie diffèrent", fingerprint(d1) != fingerprint(d2))
	# les modificateurs font partie des paramètres
	var mods: Array = DungeonGenerator.run_modifiers().slice(0, 2).map(func(m): return str(m.id))
	var m1 := DungeonGenerator.build_config(base, 3, 13, 11, "normal", mods, 1, 5)
	var m2 := DungeonGenerator.build_config(base, 3, 13, 11, "normal", mods, 1, 5)
	check("avec modificateurs : reproductible", fingerprint(m1) == fingerprint(m2))
	prints.append(fingerprint(m1).substr(0, 8))
	# la langue ne change pas la logique (seulement les textes)
	var lang := Data.lang
	Data.set_lang("fr")
	var fr := DungeonGenerator.build_config(base, 3, 13, 11, "normal", [], 1, 9)
	Data.set_lang("en")
	var en := DungeonGenerator.build_config(base, 3, 13, 11, "normal", [], 1, 9)
	Data.set_lang(lang)
	check("niveaux identiques quelle que soit la langue (hors textes affichés)", _logic_print(fr.levels) == _logic_print(en.levels))
	# le hasard global n'est pas resté figé
	var r1 := randi()
	DungeonGenerator.build_config(base, 3, 13, 11, "normal", [], 1, 9)
	var r2 := randi()
	DungeonGenerator.build_config(base, 3, 13, 11, "normal", [], 1, 9)
	var r3 := randi()
	check("le hasard global reste imprévisible après une génération", r1 != r2 and r2 != r3)
	print("empreintes : ", " ".join(prints))
	print("check_determinism : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
