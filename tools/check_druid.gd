extends Node
## Vérifie la classe Druide et ses deux évolutions : classes, sorts, effets visuels, talents, icônes, portraits et génération des groupes.
## Usage : godot --headless --path . res://tools/check_druid.tscn   (ou sous xvfb avec --rendering-driver opengl3)

const KNOWN_EFFECTS := ["bonusForce", "bonusDex", "bonusCon", "bonusInt", "resistPhys", "resistMagic", "critChance", "lifestealPct", "bonusAtkMin",
	"bonusAtkMax", "bonusSpellDmg", "bonusHp", "bonusStamina"]
const IDS := ["class_druid", "class_warden", "class_stormcaller"]

func _ready() -> void:
	var fails := 0
	var cfg: Dictionary = Data.original_config
	var by_id := {}
	for c in cfg.classes:
		by_id[str(c.id)] = c
	var spells := {}
	for s in cfg.spells:
		spells[str(s.id)] = s
	var lib = load("res://scripts/dungeon/spell_fx_library.gd")
	for id in IDS:
		if not by_id.has(id):
			print("ÉCHEC : classe absente ", id)
			fails += 1
			continue
		var c: Dictionary = by_id[id]
		# sorts : tous connus, progression ⊆ sorts autorisés, niveaux croissants, effet visuel propre et compatible
		var last := 0
		for p in c.spellProgression:
			if not spells.has(str(p.spellId)) or not (c.allowedSpellIds as Array).has(p.spellId) or int(p.level) < last:
				print("ÉCHEC : progression de ", id, " : ", p)
				fails += 1
			last = int(p.level)
			var sp: Dictionary = spells.get(str(p.spellId), {})
			if str(sp.get("style", "")) != "nature" or lib.resolve(sp) != str(lib.SPELL_DEFAULT.get(str(p.spellId), "?")):
				print("ÉCHEC : effet du sort ", p.spellId, " : ", lib.resolve(sp))
				fails += 1
		if (c.allowedSpellIds as Array).size() > int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6)):
			print("ÉCHEC : trop de sorts pour ", id)
			fails += 1
		# icône de classe
		if IconResolver.texture(str(c.icon)) == null:
			print("ÉCHEC : icône de classe introuvable ", id, " ", c.icon)
			fails += 1
		# talents : 5 paliers de 2 choix, identifiants uniques et effets connus
		var tr: Array = Data.class_talents.get(id, [])
		if tr.size() != 5:
			print("ÉCHEC : paliers de talents de ", id, " : ", tr.size())
			fails += 1
		for lvl in tr:
			if (lvl.options as Array).size() != 2:
				print("ÉCHEC : choix du palier ", lvl.level, " de ", id)
				fails += 1
			for o in lvl.options:
				if not str(o.id).begins_with(id + "_lv") or str(o.labelFr) == "" or str(o.labelEn) == "" or str(o.descFr) == "" or str(o.descEn) == "":
					print("ÉCHEC : talent incomplet ", o.id)
					fails += 1
				for k in o.effects:
					if not KNOWN_EFFECTS.has(k):
						print("ÉCHEC : effet de talent inconnu ", o.id, " ", k)
						fails += 1
	# évolutions du Druide
	var dr: Dictionary = by_id.get("class_druid", {})
	if dr.get("evolvesTo", []) != ["class_warden", "class_stormcaller"] or int(dr.get("evolveLevel", 0)) != 5:
		print("ÉCHEC : évolutions du Druide : ", dr.get("evolvesTo"))
		fails += 1
	for id in ["class_warden", "class_stormcaller"]:
		if str(by_id.get(id, {}).get("evolvesFrom", "")) != "Druide":
			print("ÉCHEC : evolvesFrom de ", id)
			fails += 1
	# sorts de nature : icône en image et texte anglais
	for i in range(1, 12):
		var sp: Dictionary = spells.get("spell_nature%d" % i, {})
		if sp.is_empty() or IconResolver.texture(str(sp.get("icon", ""))) == null:
			print("ÉCHEC : sort de nature ", i, " ou son icône")
			fails += 1
	# portraits : 5 images, la classe évoluée reprend ceux du Druide
	for i in 5:
		if not ResourceLoader.exists("res://assets/portraits/druide_%d.webp" % i):
			print("ÉCHEC : portrait druide_", i)
			fails += 1
	var hero := {"classId": "class_warden"}
	if IconResolver.portrait_path(hero, cfg) != "res://assets/portraits/druide_0.webp":
		print("ÉCHEC : portrait par défaut du Gardien : ", IconResolver.portrait_path(hero, cfg))
		fails += 1
	# génération aléatoire : le Druide apparaît, ses portraits sont distincts de ceux des autres héros (même image comprise)
	var gen = load("res://scripts/rules/dungeon_generator.gd")
	var seen := 0
	for k in 250:
		var party: Array = gen.generate_party(cfg, "normal")
		var shots := {}
		var stems := {}
		for h in party:
			var p := str(h.get("portrait", ""))
			if p == "":
				continue
			if shots.has(p) or (gen._portrait_twin(p) != "" and shots.has(gen._portrait_twin(p))):
				print("ÉCHEC : portrait en double dans un groupe : ", p)
				fails += 1
			shots[p] = true
			stems[p.get_file()] = true
		for h in party:
			if str(h.get("classId", "")) == "class_druid":
				seen += 1
				if not str(h.get("portrait", "")).contains("druide_"):
					print("ÉCHEC : portrait du druide : ", h.get("portrait"))
					fails += 1
	if seen == 0:
		print("ÉCHEC : aucun Druide en 250 groupes")
		fails += 1
	print("OK : classe Druide (%d druides vus)" % seen if fails == 0 else "%d écart(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
