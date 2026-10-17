extends Node
## Vérifie les migrations de sauvegarde : une sauvegarde de schéma 1 (sans numéro) retrouve ses objets, icônes et réglages,
## est copiée en .bak, réécrite au schéma courant, et une seconde lecture ne change plus rien.

const SLOT := 9

func _ready() -> void:
	var fails := 0
	if Saves.summary(SLOT).size() > 0:
		print("IGNORÉ : l'emplacement %d n'est pas vide" % SLOT)
		get_tree().quit(0)
		return
	var cfg: Dictionary = Data.original_config.duplicate(true)
	var removed_id := str(cfg.itemLibrary[cfg.itemLibrary.size() - 1].id)
	cfg.itemLibrary.pop_back()
	cfg.erase("legendaryChancePct")
	for s in cfg.spells:
		if s.id == "spell_bard2":
			s.icon = "🎶"
	DirAccess.make_dir_recursive_absolute(Saves.DIR)
	var f := FileAccess.open("%s/slot_%d.json" % [Saves.DIR, SLOT], FileAccess.WRITE)
	f.store_string(Saves.stringify({"format": "godot-1", "config": cfg, "save": {"level_index": 0, "party": []}, "dungeonOrigin": "random"}))
	f.close()
	var d := Saves.read_slot(SLOT)
	var ids := []
	for it in d.config.itemLibrary:
		ids.append(it.id)
	var icon := ""
	for s in d.config.spells:
		if s.id == "spell_bard2":
			icon = s.icon
	var checks := {
		"schéma courant": int(d.get("schema", 0)) == SaveMigrations.SCHEMA,
		"objet restauré": ids.has(removed_id),
		"icône du barde": icon == "@icon:spell_sonicnote",
		"réglage ajouté": d.config.has("legendaryChancePct"),
		"copie .bak": FileAccess.file_exists("%s/slot_%d.v1.bak" % [Saves.DIR, SLOT]),
		"fichier réécrit": Saves.read_slot(SLOT).get("schema", 0) == SaveMigrations.SCHEMA,
		"2e lecture sans migration": not SaveMigrations.needs_migration(Saves.read_slot(SLOT)),
	}
	# icônes de classes du barde : ancienne icône emoji → image (classes, équipe de config, héros sauvegardés)
	var oldc := {"config": {"classes": [{"id": "class_skald", "icon": "🪓"}, {"id": "class_berserker", "icon": "🪓"}],
		"party": [{"classId": "class_bard", "icon": "🪕"}]}, "save": {"party": [{"classId": "class_minstrel", "icon": "🎼"}]},
		"schema": 2, "dungeonOrigin": "random"}
	SaveMigrations.migrate(oldc, Data.original_config)
	checks["icône de classe skalde"] = oldc.config.classes[0].icon == "@icon:class_skald"
	checks["berserker : emoji → image du jeu (v5)"] = oldc.config.classes[1].icon == "@icon:axe_double"
	checks["icône de classe barde (équipe) : luth → cor (v16)"] = oldc.config.party[0].icon == "@icon:spr_103"
	checks["icône de classe ménestrel (sauvegarde)"] = oldc.save.party[0].icon == "@icon:class_minstrel"
	# piège de vapeur permanent (v3 → v4) : niveaux et bibliothèque ; les autres pièges ne changent pas
	var gas := {"config": {"levels": [{"items": [{"id": "g", "type": "trap", "trapKind": "gas", "permanent": false}, {"id": "d", "type": "trap", "trapKind": "dart", "permanent": false}]}],
		"itemLibrary": [{"id": "lg", "type": "trap", "trapKind": "gas", "permanent": false}]}, "save": {}, "schema": 3, "dungeonOrigin": "random"}
	SaveMigrations.migrate(gas, Data.original_config)
	checks["vapeur permanente (niveau)"] = bool(gas.config.levels[0].items[0].permanent)
	checks["fléchettes permanentes au passage v5 → v6"] = bool(gas.config.levels[0].items[1].permanent)
	checks["vapeur permanente (bibliothèque)"] = bool(gas.config.itemLibrary[0].permanent)
	# fléchettes murales (v5 → v6) : permanentes (niveaux et bibliothèque) ; fosse et pointes inchangées
	var dt := {"config": {"levels": [{"items": [{"id": "d", "type": "trap", "trapKind": "dart", "permanent": false}, {"id": "p", "type": "trap", "trapKind": "pit", "permanent": false}]}],
		"itemLibrary": [{"id": "ld", "type": "trap", "trapKind": "dart", "permanent": false}]}, "save": {}, "schema": 5, "dungeonOrigin": "random"}
	SaveMigrations.migrate(dt, Data.original_config)
	checks["fléchettes permanentes (niveau)"] = bool(dt.config.levels[0].items[0].permanent)
	checks["fléchettes permanentes (bibliothèque)"] = bool(dt.config.itemLibrary[0].permanent)
	checks["fosse permanente au passage v6 → v7"] = bool(dt.config.levels[0].items[1].permanent)
	var ru := {"config": {"levels": [{"items": [{"id": "r", "type": "trap", "trapKind": "rune", "permanent": false}, {"id": "s", "type": "trap", "trapKind": "spikes", "permanent": false}]}],
		"itemLibrary": [{"id": "lr", "type": "trap", "trapKind": "rune", "permanent": false}]}, "save": {}, "schema": 7, "dungeonOrigin": "random"}
	SaveMigrations.migrate(ru, Data.original_config)
	checks["rune permanente (niveau)"] = bool(ru.config.levels[0].items[0].permanent)
	checks["rune permanente (bibliothèque)"] = bool(ru.config.itemLibrary[0].permanent)
	checks["pointes inchangées par v8"] = not bool(ru.config.levels[0].items[1].permanent)
	# icônes de classes (v4 → v5) : un emoji ou une icône introuvable sur une classe du jeu devient l'image du jeu ; classe du créateur et héros personnalisé intacts
	var ci := {"config": {"classes": [{"id": "class_thief", "icon": "🗝️"}, {"id": "class_cleric", "icon": ""}, {"id": "class_assassin", "icon": "@icon:dagger_void"},
		{"id": "class_perso", "icon": "🧝"}], "party": [{"classId": "class_thief", "icon": "🗝️"}, {"classId": "class_thief", "icon": "🐱"}]},
		"save": {"party": [{"classId": "class_cleric", "icon": ""}]}, "schema": 4, "dungeonOrigin": "random"}
	SaveMigrations.migrate(ci, Data.original_config)
	checks["icône voleur (emoji → image)"] = ci.config.classes[0].icon == "@icon:dagger_wavy"
	checks["icône clerc (vide → image)"] = ci.config.classes[1].icon == "@icon:helm_winged"
	checks["icône assassin intacte"] = ci.config.classes[2].icon == "@icon:dagger_void"
	checks["classe du créateur intacte"] = ci.config.classes[3].icon == "🧝"
	checks["héros qui suivait l'icône de sa classe"] = ci.config.party[0].icon == "@icon:dagger_wavy"
	checks["héros à icône perso intact"] = ci.config.party[1].icon == "🐱"
	checks["héros de la sauvegarde"] = ci.save.party[0].icon == "@icon:helm_winged"
	# école de nature (v8 → v9) : les sorts manquants sont ajoutés une seule fois, un sort déjà présent n'est pas dupliqué
	var na := {"config": {"spells": [{"id": "spell_nature1", "name": "Mon épine", "style": "nature", "mode": "damage"}]}, "save": {}, "schema": 8, "dungeonOrigin": "random"}
	SaveMigrations.migrate(na, Data.original_config)
	var nat_ids := {}
	for sp in na.config.spells:
		nat_ids[sp.id] = int(nat_ids.get(sp.id, 0)) + 1
	checks["sorts de nature ajoutés"] = nat_ids.has("spell_nature2") and nat_ids.has("spell_nature6")
	checks["sort de nature existant non dupliqué ni écrasé"] = int(nat_ids.get("spell_nature1", 0)) == 1 and na.config.spells[0].name == "Mon épine"
	# classe Druide (v9 → v10) : classes et sorts ajoutés, icônes des sorts de nature en image, rien d'écrasé ni de doublé
	var dr := {"config": {"classes": [{"id": "class_priest", "name": "Prêtre"}], "spells": [{"id": "spell_nature1", "name": "Épine Venimeuse", "icon": "🌿", "style": "nature", "mode": "damage"},
		{"id": "spell_nature2", "name": "Mes ronces", "icon": "🌟", "style": "nature", "mode": "damage"}]}, "save": {}, "schema": 9, "dungeonOrigin": "random"}
	SaveMigrations.migrate(dr, Data.original_config)
	var dr_cls := {}
	for c in dr.config.classes:
		dr_cls[c.id] = int(dr_cls.get(c.id, 0)) + 1
	var dr_sp := {}
	for sp in dr.config.spells:
		dr_sp[sp.id] = sp
	checks["druide : 3 classes ajoutées"] = dr_cls.get("class_druid", 0) == 1 and dr_cls.get("class_warden", 0) == 1 and dr_cls.get("class_stormcaller", 0) == 1
	checks["druide : sorts ajoutés"] = dr_sp.has("spell_nature7") and dr_sp.has("spell_nature11")
	checks["druide : icône de sort de nature en image"] = dr_sp.spell_nature1.icon == "@icon:spell_nature1"
	checks["druide : icône choisie par le créateur intacte"] = dr_sp.spell_nature2.icon == "🌟" and dr_sp.spell_nature2.name == "Mes ronces"
	var dr2 := {"config": {"classes": [{"id": "class_mien", "name": "Druide"}], "spells": []}, "save": {}, "schema": 9, "dungeonOrigin": "random"}
	SaveMigrations.migrate(dr2, Data.original_config)
	var mine := 0
	for c in dr2.config.classes:
		if c.name == "Druide":
			mine += 1
	checks["druide : classe du créateur de même nom non doublée"] = mine == 1 and not (dr2.config.classes as Array).any(func(c): return c.id == "class_druid")
	var dr3 := {"config": {"classes": [], "spells": []}, "save": {}, "schema": 9, "dungeonOrigin": "custom"}
	SaveMigrations.migrate(dr3, Data.original_config)
	checks["druide : donjon custom intact"] = (dr3.config.classes as Array).is_empty()
	# un donjon personnalisé garde sa bibliothèque
	var cu := {"config": {"itemLibrary": [], "spells": []}, "save": {}, "dungeonOrigin": "custom"}
	SaveMigrations.migrate(cu, Data.original_config)
	checks["donjon custom intact"] = (cu.config.itemLibrary as Array).is_empty()
	# configuration de l'appareil (donjons aléatoires)
	var dev: Dictionary = Data.original_config.duplicate(true)
	for sp in dev.spells:
		if sp.id == "spell_bard2":
			sp.icon = "🎶"
	SaveMigrations.migrate_config(dev, Data.original_config)
	var dev_icon := ""
	for sp in dev.spells:
		if sp.id == "spell_bard2":
			dev_icon = sp.icon
	checks["config appareil : icône du barde"] = dev_icon == "@icon:spell_sonicnote"
	checks["config appareil : schéma"] = int(dev.get("configSchema", 0)) == SaveMigrations.SCHEMA
	for k in checks:
		if not checks[k]:
			print("ÉCHEC : ", k)
			fails += 1
	Saves.delete_slot(SLOT)
	DirAccess.remove_absolute("%s/slot_%d.v1.bak" % [Saves.DIR, SLOT])
	print("OK : migrations de sauvegarde" if fails == 0 else "%d écart(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
