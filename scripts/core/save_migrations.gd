class_name SaveMigrations
extends RefCounted
## Migrations de sauvegarde. Chaque fichier porte un numéro de schéma (« schema ») ; une sauvegarde sans numéro est en version 1.
## Au chargement, `migrate` applique dans l'ordre les étapes manquantes : la partie récupère ainsi les nouveautés du jeu
## (objets, sorts, réglages, icônes) sans qu'il faille recommencer.
##
## POUR AJOUTER UNE ÉVOLUTION : incrémenter SCHEMA, ajouter une branche dans `migrate` et écrire la fonction `_vN_to_vM`
## (elle modifie le dictionnaire {config, save, …} sur place et renvoie la liste des changements en clair).
## `tools/check_saves.tscn` rejoue ces migrations sur une sauvegarde d'ancienne version.

const SCHEMA := 2

## Anciennes icônes d'éléments fournis par le jeu, remplacées : {id de sort : [ancienne icône, nouvelle icône]}.
const SPELL_ICON_CHANGES := {"spell_bard2": ["🎶", "@icon:spell_sonicnote"]}

static func schema_of(d: Dictionary) -> int:
	return int(d.get("schema", 1))

static func needs_migration(d: Dictionary) -> bool:
	return schema_of(d) < SCHEMA

## Met `d` (fichier complet : config, save, dungeonOrigin…) au schéma courant. `defaults` : configuration d'origine du jeu.
## Renvoie la liste des changements (vide s'il n'y avait rien à faire).
static func migrate(d: Dictionary, defaults: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var v := schema_of(d)
	while v < SCHEMA:
		match v:
			1:
				notes.append_array(_v1_to_v2(d, defaults))
		v += 1
	d["schema"] = SCHEMA
	return notes

## Configuration enregistrée sur l'appareil (user://config.json, celle qui sert aux donjons aléatoires) : même mise à niveau que
## pour une sauvegarde, repérée par « configSchema ». Renvoie la liste des changements (vide : rien à faire, ou déjà à jour).
static func migrate_config(cfg: Dictionary, defaults: Dictionary) -> Array[String]:
	var v := int(cfg.get("configSchema", 1))
	if v >= SCHEMA:
		return []
	var whole := {"config": cfg, "dungeonOrigin": "random", "schema": v}
	var notes := migrate(whole, defaults)
	cfg["configSchema"] = SCHEMA
	return notes

## v1 → v2 : la configuration enregistrée dans la partie reçoit les objets et sorts ajoutés depuis, les réglages manquants
## et les icônes remplacées. Un donjon « custom » (modifié par le joueur) garde sa bibliothèque et ses sorts tels quels.
static func _v1_to_v2(d: Dictionary, defaults: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var cfg = d.get("config")
	if not (cfg is Dictionary) or (cfg as Dictionary).is_empty():
		return notes
	var c: Dictionary = cfg
	var custom := str(d.get("dungeonOrigin", "random")) == "custom"
	if not custom:
		for key in ["itemLibrary", "spells"]:
			var mine = c.get(key)
			var theirs = defaults.get(key)
			if not (mine is Array) or not (theirs is Array):
				continue
			var have := {}
			for e in mine:
				if e is Dictionary:
					have[str(e.get("id", ""))] = true
			var added := 0
			for e in theirs:
				if e is Dictionary and not have.has(str(e.get("id", ""))):
					(mine as Array).append((e as Dictionary).duplicate(true))
					added += 1
			if added > 0:
				notes.append("%s : %d ajouté(s)" % [key, added])
	var icons := 0
	for s in c.get("spells", []):
		if s is Dictionary and SPELL_ICON_CHANGES.has(str(s.get("id", ""))):
			var ch: Array = SPELL_ICON_CHANGES[str(s.id)]
			if str(s.get("icon", "")) == ch[0]:
				s["icon"] = ch[1]
				icons += 1
	if icons > 0:
		notes.append("icônes de sorts : %d mise(s) à jour" % icons)
	var keys := 0
	for k in defaults:
		if k in ["levels", "party", "classes", "title", "adminPassword"]:
			continue
		if not c.has(k):
			c[k] = (defaults[k].duplicate(true) if (defaults[k] is Dictionary or defaults[k] is Array) else defaults[k])
			keys += 1
	if keys > 0:
		notes.append("réglages ajoutés : %d" % keys)
	return notes
