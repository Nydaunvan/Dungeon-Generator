class_name SaveMigrations
extends RefCounted
## Migrations de sauvegarde. Chaque fichier porte un numéro de schéma (« schema ») ; une sauvegarde sans numéro est en version 1.
## Au chargement, `migrate` applique dans l'ordre les étapes manquantes : la partie récupère ainsi les nouveautés du jeu
## (objets, sorts, réglages, icônes) sans qu'il faille recommencer.
##
## POUR AJOUTER UNE ÉVOLUTION : incrémenter SCHEMA, ajouter une branche dans `migrate` et écrire la fonction `_vN_to_vM`
## (elle modifie le dictionnaire {config, save, …} sur place et renvoie la liste des changements en clair).
## `tools/check_saves.tscn` rejoue ces migrations sur une sauvegarde d'ancienne version.

const SCHEMA := 5

## Anciennes icônes d'éléments fournis par le jeu, remplacées : {id de sort : [ancienne icône, nouvelle icône]}.
const SPELL_ICON_CHANGES := {"spell_bard2": ["🎶", "@icon:spell_sonicnote"]}

## v3 : icônes claires des sorts du Barde, du Skalde et du Ménestrel.
const SPELL_ICON_CHANGES_V3 := {
	"spell_bard1": ["🎵", "@icon:spell_bard1"], "spell_skald1": ["🥁", "@icon:spell_skald1"], "spell_skald2": ["📯", "@icon:spell_skald2"],
	"spell_skald3": ["📣", "@icon:spell_skald3"], "spell_skald4": ["🔥", "@icon:spell_skald4"], "spell_minstrel1": ["😴", "@icon:spell_minstrel1"],
	"spell_minstrel2": ["🎼", "@icon:spell_minstrel2"], "spell_minstrel3": ["🎺", "@icon:spell_minstrel3"], "spell_minstrel4": ["🎐", "@icon:spell_minstrel4"],
}

## v3 : icônes de classe du Barde, du Skalde et du Ménestrel (classId → [ancienne icône, nouvelle icône]).
const CLASS_ICON_CHANGES_V3 := {
	"class_bard": ["🪕", "@icon:class_bard"], "class_skald": ["🪓", "@icon:class_skald"], "class_minstrel": ["🎼", "@icon:class_minstrel"],
}

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
			2:
				notes.append_array(_v2_to_v3(d))
			3:
				notes.append_array(_v3_to_v4(d))
			4:
				notes.append_array(_v4_to_v5(d, defaults))
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

## v2 → v3 : nouvelles icônes des sorts du Barde et de ses évolutions (seulement si le joueur n'avait pas mis la sienne).
static func _v2_to_v3(d: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var cfg = d.get("config")
	if not (cfg is Dictionary):
		return notes
	var icons := 0
	for s in (cfg as Dictionary).get("spells", []):
		if s is Dictionary and SPELL_ICON_CHANGES_V3.has(str(s.get("id", ""))):
			var ch: Array = SPELL_ICON_CHANGES_V3[str(s.id)]
			if str(s.get("icon", "")) == ch[0]:
				s["icon"] = ch[1]
				icons += 1
	if icons > 0:
		notes.append("icônes de sorts du barde : %d mise(s) à jour" % icons)
	var cls_n := _fix_class_icons((cfg as Dictionary).get("classes", []), "id")
	cls_n += _fix_class_icons((cfg as Dictionary).get("party", []), "classId")
	var sv = d.get("save")
	if sv is Dictionary:
		cls_n += _fix_class_icons((sv as Dictionary).get("party", []), "classId")
	if cls_n > 0:
		notes.append("icônes de classes du barde : %d mise(s) à jour" % cls_n)
	return notes

## Remplace l'ancienne icône emoji d'une classe (ou d'un héros de cette classe) par l'image ; `key` : champ qui donne l'id de classe.
static func _fix_class_icons(list: Variant, key: String) -> int:
	var n := 0
	if not (list is Array):
		return 0
	for e in list:
		if e is Dictionary and CLASS_ICON_CHANGES_V3.has(str(e.get(key, ""))):
			var ch: Array = CLASS_ICON_CHANGES_V3[str(e.get(key))]
			if str(e.get("icon", "")) == ch[0]:
				e["icon"] = ch[1]
				n += 1
	return n

## v3 → v4 : le piège de vapeur reste en place quand le jet échoue (il se redéclenche si on repasse dessus) : ses objets deviennent « permanents »
## (objets des niveaux et de la bibliothèque). Une seule fois : le choix du créateur reste libre ensuite.
static func _v3_to_v4(d: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var cfg = d.get("config")
	if not (cfg is Dictionary):
		return notes
	var n := 0
	var lists: Array = [(cfg as Dictionary).get("itemLibrary", [])]
	for lvl in (cfg as Dictionary).get("levels", []):
		if lvl is Dictionary:
			lists.append(lvl.get("items", []))
	for lst in lists:
		if not (lst is Array):
			continue
		for it in lst:
			if it is Dictionary and str(it.get("type", "")) == "trap" and str(it.get("trapKind", "")) == "gas" and not bool(it.get("permanent", false)):
				it["permanent"] = true
				n += 1
	if n > 0:
		notes.append("pièges de vapeur permanents : %d" % n)
	return notes

## v4 → v5 : toute classe fournie par le jeu doit avoir une icône en image. Les anciennes icônes emoji (ou introuvables) des classes évoluées
## n'apparaissaient pas dans le choix d'évolution : elles reprennent l'icône du jeu. Les héros qui portaient l'ancienne icône de leur classe
## la suivent ; une icône choisie par le créateur sur une classe à lui (ou sur un héros) n'est jamais touchée.
static func _v4_to_v5(d: Dictionary, defaults: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var cfg = d.get("config")
	if not (cfg is Dictionary):
		return notes
	var changed := repair_class_icons(cfg, defaults)
	var n := 0
	for k in changed:
		var pair: Array = changed[k]
		var lists: Array = [(cfg as Dictionary).get("party", [])]
		var sv = d.get("save")
		if sv is Dictionary:
			lists.append((sv as Dictionary).get("party", []))
		for lst in lists:
			if lst is Array:
				for h in lst:
					if h is Dictionary and str(h.get("classId", "")) == str(k) and str(h.get("icon", "")) == str(pair[0]):
						h["icon"] = pair[1]
						n += 1
	if not changed.is_empty():
		notes.append("icônes de classes : %d mise(s) à jour" % (changed.size() + n))
	return notes

## Icône en image qui s'affiche vraiment ?
static func class_icon_ok(icon: String) -> bool:
	return icon.begins_with("@icon:") and IconResolver.texture(icon) != null

## Redonne l'icône du jeu aux classes fournies par le jeu dont l'icône n'est pas une image qui s'affiche. Renvoie {id de classe : [ancienne, nouvelle]}.
static func repair_class_icons(cfg: Dictionary, defaults: Dictionary) -> Dictionary:
	var out := {}
	var ref := {}
	for c in defaults.get("classes", []):
		if c is Dictionary:
			ref[str(c.get("id", ""))] = str(c.get("icon", ""))
	for c in cfg.get("classes", []):
		if not (c is Dictionary) or not ref.has(str(c.get("id", ""))):
			continue
		var cur := str(c.get("icon", ""))
		if not class_icon_ok(cur) and class_icon_ok(str(ref[str(c.id)])):
			out[str(c.id)] = [cur, str(ref[str(c.id)])]
			c["icon"] = str(ref[str(c.id)])
	return out
