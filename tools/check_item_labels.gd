extends Node
## Aucun texte d'objet ne doit montrer une clé de langue brute (« ui.equip_dock.bottes ») : lignes de type de chaque emplacement, de chaque type d'objet,
## et libellés d'emplacement du groupe et du marchand, dans les deux langues.
var _re := RegEx.new()

func _raw(s: String) -> bool:
	return _re.search(s) != null

func _ready() -> void:
	_re.compile("^[a-z_]+\\.[a-z_0-9]+(\\.[a-z_0-9]+)*$")
	var bad: Array = []
	for loc in ["fr", "en"]:
		TranslationServer.set_locale(loc)
		for tier in Rarity.ORDER:
			for slot in ["head", "body", "hands", "feet"]:
				var it := {"type": "armor", "slot": slot, "rarity": tier}
				var t: String = EquipDock.type_label(it)
				if _raw(t) or t.contains("ui.") or t.contains("common.") or t.contains("rules."):
					bad.append("%s armor/%s/%s -> %s" % [loc, slot, tier, t])
			for ty in ["weapon", "jewelry", "potion", "key", "scroll", "autre"]:
				var t2: String = EquipDock.type_label({"type": ty, "rarity": tier})
				if _raw(t2) or t2.contains("ui.") or t2.contains("common.") or t2.contains("rules."):
					bad.append("%s %s/%s -> %s" % [loc, ty, tier, t2])
		for slot in Inventory.SLOT_LABELS:
			var l: String = L.c(str(Inventory.SLOT_LABELS[slot]))
			if _raw(l):
				bad.append("%s emplacement %s -> %s" % [loc, slot, l])
		for d in EquipDock.SLOT_DEFS:
			var l2: String = L.t(str(d.label))
			if _raw(l2):
				bad.append("%s SLOT_DEFS %s -> %s" % [loc, d.id, l2])
	for b in bad:
		print("ITEMLABEL ", b)
	print("ITEMLABELS ", "OK" if bad.is_empty() else "ECHEC (%d)" % bad.size())
	get_tree().quit(0 if bad.is_empty() else 1)
