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
	# un donjon personnalisé garde sa bibliothèque
	var cu := {"config": {"itemLibrary": [], "spells": []}, "save": {}, "dungeonOrigin": "custom"}
	SaveMigrations.migrate(cu, Data.original_config)
	checks["donjon custom intact"] = (cu.config.itemLibrary as Array).is_empty()
	for k in checks:
		if not checks[k]:
			print("ÉCHEC : ", k)
			fails += 1
	Saves.delete_slot(SLOT)
	DirAccess.remove_absolute("%s/slot_%d.v1.bak" % [Saves.DIR, SLOT])
	print("OK : migrations de sauvegarde" if fails == 0 else "%d écart(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
