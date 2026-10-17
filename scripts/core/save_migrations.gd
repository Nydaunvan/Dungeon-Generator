class_name SaveMigrations
extends RefCounted
## Migrations de sauvegarde. Chaque fichier porte un numéro de schéma (« schema ») ; une sauvegarde sans numéro est en version 1.
## Au chargement, `migrate` applique dans l'ordre les étapes manquantes : la partie récupère ainsi les nouveautés du jeu
## (objets, sorts, réglages, icônes) sans qu'il faille recommencer.
##
## POUR AJOUTER UNE ÉVOLUTION : incrémenter SCHEMA, ajouter une branche dans `migrate` et écrire la fonction `_vN_to_vM`
## (elle modifie le dictionnaire {config, save, …} sur place et renvoie la liste des changements en clair).
## `tools/check_saves.tscn` rejoue ces migrations sur une sauvegarde d'ancienne version.

const SCHEMA := 13

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
			5:
				notes.append_array(_v5_to_v6(d))
			6:
				notes.append_array(_v6_to_v7(d))
			7:
				notes.append_array(_v7_to_v8(d))
			8:
				notes.append_array(_v8_to_v9(d, defaults))
			9:
				notes.append_array(_v9_to_v10(d, defaults))
			10:
				notes.append_array(_v10_to_v11(d))
			11:
				notes.append_array(_v11_to_v12(d))
			12:
				notes.append_array(_v12_to_v13(d))
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

## v5 → v6 : le piège à fléchettes devient un mécanisme mural qui reste en place (comme la vapeur) : réussite = désactivé, échec = toujours actif.
static func _v5_to_v6(d: Dictionary) -> Array[String]:
	return _make_permanent(d, "dart", "pièges à fléchettes permanents : %d")

## v6 → v7 : la fosse devient un trou béant qui reste en place : réussite = franchie (planches) et désactivée, échec = toujours ouverte.
static func _v6_to_v7(d: Dictionary) -> Array[String]:
	return _make_permanent(d, "pit", "fosses permanentes : %d")

## v7 → v8 : la rune de flammes devient un cercle gravé qui reste en place : réussite = éteinte, échec = toujours active.
static func _v7_to_v8(d: Dictionary) -> Array[String]:
	return _make_permanent(d, "rune", "pièges à runes permanents : %d")

## v8 → v9 : l'école de nature (6 sorts : épine venimeuse, ronces, foudre sauvage, essaim, bourgeon de vie, souffle de la forêt) : les sorts
## du jeu qui manquent à la configuration de la partie ou de l'appareil y sont ajoutés (un donjon « custom » garde ses sorts tels quels).
## Aucune classe ne les reçoit : les monstres peuvent les utiliser (capacité spéciale) et le créateur peut les attribuer à une classe.
static func _v8_to_v9(d: Dictionary, defaults: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var cfg = d.get("config")
	var theirs = defaults.get("spells")
	if not (cfg is Dictionary) or not (theirs is Array) or str(d.get("dungeonOrigin", "random")) == "custom":
		return notes
	var mine = (cfg as Dictionary).get("spells")
	if not (mine is Array):
		return notes
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
		notes.append("sorts de nature : %d ajouté(s)" % added)
	return notes

## Anciennes icônes (emoji) des sorts de nature, remplacées par des images : {id de sort : emoji d'origine}.
const NATURE_ICON_OLD := {
	"spell_nature1": "🌿", "spell_nature2": "🌱", "spell_nature3": "⚡", "spell_nature4": "🐝", "spell_nature5": "🌸", "spell_nature6": "🍃",
}

## Classes ajoutées par le jeu en v10 (le Druide et ses deux évolutions).
const DRUID_CLASS_IDS := ["class_druid", "class_warden", "class_stormcaller"]

## v9 → v10 : la classe Druide et ses évolutions (Gardien de la Forêt, Druide de la Tempête), les 5 sorts de nature qui complètent leur
## progression, et les icônes en image des sorts de nature. Un donjon « custom » garde ses classes et ses sorts tels quels ; une classe
## du créateur qui porte déjà le même identifiant ou le même nom n'est jamais remplacée ni doublonnée.
static func _v9_to_v10(d: Dictionary, defaults: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var cfg = d.get("config")
	if not (cfg is Dictionary) or str(d.get("dungeonOrigin", "random")) == "custom":
		return notes
	# sorts manquants (les 5 nouveaux ; tout sort du jeu absent de la configuration)
	var n_sp := _v8_to_v9(d, defaults)
	var spells = (cfg as Dictionary).get("spells")
	var n_icons := 0
	if spells is Array:
		for e in spells:
			if e is Dictionary and NATURE_ICON_OLD.has(str(e.get("id", ""))) and str(e.get("icon", "")) == str(NATURE_ICON_OLD[str(e.id)]):
				e["icon"] = "@icon:%s" % str(e.id)
				n_icons += 1
	# classes manquantes
	var classes = (cfg as Dictionary).get("classes")
	var theirs = defaults.get("classes")
	var added := 0
	if classes is Array and theirs is Array:
		var ids := {}
		var names := {}
		for c in classes:
			if c is Dictionary:
				ids[str(c.get("id", ""))] = true
				names[str(c.get("name", ""))] = true
		for c in theirs:
			if c is Dictionary and DRUID_CLASS_IDS.has(str(c.get("id", ""))) and not ids.has(str(c.id)) and not names.has(str(c.get("name", ""))):
				(classes as Array).append((c as Dictionary).duplicate(true))
				added += 1
	if added > 0:
		notes.append("classe Druide et évolutions : %d classe(s) ajoutée(s)" % added)
	for n in n_sp:
		notes.append(n)
	if n_icons > 0:
		notes.append("icônes des sorts de nature : %d mise(s) à jour" % n_icons)
	return notes

## v10 → v11 : la rage devient possible pour tout monstre (seuil de PV > 0). Avant, seuls les boss s'enrageaient et le seuil des autres monstres
## était ignoré : on le remet à 0 pour que les niveaux existants gardent leur comportement. Réglages de rage ajoutés à la configuration.
static func _v10_to_v11(d: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var cfg = d.get("config")
	if not (cfg is Dictionary):
		return notes
	var n := 0
	for lvl in (cfg as Dictionary).get("levels", []):
		if not (lvl is Dictionary):
			continue
		for m in lvl.get("monsters", []):
			if m is Dictionary and not bool(m.get("isBoss", false)) and int(m.get("enrageThreshold", 0)) > 0:
				m["enrageThreshold"] = 0
				n += 1
	if not (cfg as Dictionary).has("monsterRageChancePct"):
		cfg["monsterRageChancePct"] = 25
	if not (cfg as Dictionary).has("bossRage"):
		cfg["bossRage"] = true
	if n > 0:
		notes.append("rage des monstres ordinaires inchangée (désactivée) : %d" % n)
	return notes

## v3 → v4 : le piège de vapeur reste en place quand le jet échoue (il se redéclenche si on repasse dessus) : ses objets deviennent « permanents »
## (objets des niveaux et de la bibliothèque). Une seule fois : le choix du créateur reste libre ensuite.
static func _v3_to_v4(d: Dictionary) -> Array[String]:
	return _make_permanent(d, "gas", "pièges de vapeur permanents : %d")

## Rend permanents les pièges d'un type (objets des niveaux et de la bibliothèque) ; renvoie la note de migration s'il y en a.
static func _make_permanent(d: Dictionary, kind: String, note: String) -> Array[String]:
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
			if it is Dictionary and str(it.get("type", "")) == "trap" and str(it.get("trapKind", "")) == kind and not bool(it.get("permanent", false)):
				it["permanent"] = true
				n += 1
	if n > 0:
		notes.append(note % n)
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


## Sorts de dégâts du Druide rééquilibrés (v1.36) : {id : [dégâts min, max, recharge, chance de statut]} avant puis après.
## Un sort modifié par le créateur (valeurs différentes des anciennes) n'est pas touché.
const DRUID_OLD := {"spell_nature1": [8, 14, 6, 40], "spell_nature2": [10, 18, 8, 60], "spell_nature3": [16, 26, 9, 20],
	"spell_nature4": [9, 15, 11, 30], "spell_nature10": [16, 26, 10, 50], "spell_nature11": [28, 42, 13, 25]}
const DRUID_NEW := {"spell_nature1": [6, 11, 7, 30], "spell_nature2": [8, 14, 9, 45], "spell_nature3": [12, 20, 10, 15],
	"spell_nature4": [6, 11, 13, 25], "spell_nature10": [11, 18, 12, 40], "spell_nature11": [20, 30, 15, 20]}

static func _v11_to_v12(d: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var cfg = d.get("config")
	if not (cfg is Dictionary):
		return notes
	var n := 0
	for sp in (cfg as Dictionary).get("spells", []):
		if not (sp is Dictionary) or not DRUID_OLD.has(str(sp.get("id", ""))):
			continue
		var o: Array = DRUID_OLD[str(sp.id)]
		if int(sp.get("dmgMin", -1)) != o[0] or int(sp.get("dmgMax", -1)) != o[1]:
			continue
		var nw: Array = DRUID_NEW[str(sp.id)]
		sp["dmgMin"] = nw[0]
		sp["dmgMax"] = nw[1]
		sp["cooldownSec"] = nw[2]
		if sp.has("statusChance"):
			sp["statusChance"] = nw[3]
		n += 1
	if n > 0:
		notes.append("sorts de dégâts du Druide rééquilibrés : %d" % n)
	return notes


## v12 → v13 : effets des monstres selon leur famille (réglages de la configuration). Les niveaux existants ne changent pas : leurs monstres n'ont aucun effet
## tant que le créateur n'en choisit pas un (colonne « Effet » de l'éditeur de niveaux).
static func _v12_to_v13(d: Dictionary) -> Array[String]:
	var cfg = d.get("config")
	if cfg is Dictionary:
		if not (cfg as Dictionary).has("monsterStatusChancePct"):
			cfg["monsterStatusChancePct"] = 60
		if not (cfg as Dictionary).has("bossStatus"):
			cfg["bossStatus"] = true
	return []
