class_name AdminItems
extends RefCounted
## Onglet « Objets de base » : bibliothèque d'objets (potions, armes, armures, bijoux, clés, parchemins, pièges).

const TYPES := [["potion", "Potion"], ["weapon", "Arme"], ["armor", "Armure"], ["jewelry", "Bijou"], ["key", "Clé"], ["scroll", "Parchemin"], ["trap", "Piège"]]
const LEVEL_TYPES := [["potion", "Potion"], ["weapon", "Arme"], ["armor", "Armure"], ["jewelry", "Bijou"], ["key", "Clé"], ["scroll", "Parchemin"], ["trap", "Piège"], ["switch", "Interrupteur"], ["fountain", "Fontaine"]]
const PERKS := [["lifesteal", "Vol de vie"], ["crit", "Critique"], ["thorns", "Renvoi"]]
const STAT_FIELDS := ["bonusAtkMin", "bonusAtkMax", "bonusHp", "bonusSpellDmg", "heal", "trapDmgMin", "trapDmgMax", "bonusForce", "bonusDex", "bonusCon", "bonusInt", "bonusSpeed"]

static func build(host: VBoxContainer, admin: Node) -> void:
	var head := Form.panel(host, "Objets de base")
	Form.hint(head, "La bibliothèque d'objets : équipement de départ des personnages, butin, boutiques. Les objets placés dans les niveaux se règlent dans l'onglet « Niveaux ».")
	Form.buttons(head, [["Ajouter un objet", func(): _add(admin)], ["Enregistrer", admin.save]])
	for it in Data.config.get("itemLibrary", []):
		_card(host, admin, it)

static func _card(host: VBoxContainer, admin: Node, it: Dictionary) -> void:
	var b := Form.panel(host, str(it.get("name", "Objet")))
	var top := AdminUtil.flow(b)
	top.add_child(IconPicker.button(admin.modals(), it, "icon", Callable(), 36.0))
	var e := LineEdit.new()
	e.text = str(it.get("name", ""))
	e.custom_minimum_size = Vector2(200, 0)
	e.text_changed.connect(func(t: String): it["name"] = t)
	AdminUtil.chip(top, "Nom", e)
	var on_type := func(v):
		it["type"] = v
		admin.refresh_tab()
	AdminUtil.chip(top, "Type", AdminUtil.dropdown(TYPES, it.get("type", "potion"), on_type, 140.0))
	var rm := Button.new()
	rm.text = "Supprimer"
	rm.focus_mode = Control.FOCUS_NONE
	rm.pressed.connect(func(): _remove(admin, it))
	top.add_child(rm)
	fields(b, it, admin)

## Nombre borné selon le champ (mêmes règles que le HTML).
static func clamp_stat(it: Dictionary, field: String, value: float) -> int:
	var v := int(value)
	if ["heal", "trapDmgMin", "trapDmgMax"].has(field):
		return maxi(1, v)
	if (field == "bonusAtkMin" or field == "bonusAtkMax") and it.get("type") == "weapon":
		return maxi(1, v)
	if ["bonusForce", "bonusDex", "bonusCon", "bonusInt", "bonusSpeed"].has(field):
		return clampi(v, 0, 100)
	return maxi(0, v)

static func _num(parent: Control, label: String, it: Dictionary, key: String, hi: float = 9999.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = 0
	s.max_value = hi
	s.step = 1
	s.custom_minimum_size = Vector2(84, 0)
	s.value = float(it.get(key, 0))
	s.value_changed.connect(func(v: float): it[key] = clamp_stat(it, key, v))
	AdminUtil.chip(parent, label, s)
	return s

## Champs propres au type de l'objet (partagés avec l'éditeur de niveaux).
static func fields(parent: Control, it: Dictionary, admin: Node, lvl: Dictionary = {}) -> void:
	var f := AdminUtil.flow(parent)
	match str(it.get("type", "potion")):
		"potion":
			_num(f, "Soin (PV)", it, "heal")
			_num(f, "Endurance", it, "staminaRestore")
		"weapon":
			var wt: Array = []
			for w in AdminUtil.weapon_types():
				wt.append([w.id, w.label])
			var on_w := func(v): it["weaponType"] = v
			AdminUtil.chip(f, "Type d'arme", AdminUtil.dropdown(wt, it.get("weaponType", "sword"), on_w, 170.0))
			_num(f, "Attaque min", it, "bonusAtkMin")
			_num(f, "max", it, "bonusAtkMax")
			_boosts(parent, it)
			_legendary(parent, it, admin)
		"armor":
			var slots: Array = []
			for sl in Data.constants.get("SLOT_TYPES", []):
				if sl.id != "weapon" and sl.id != "accessory":
					slots.append([sl.id, sl.label])
			var on_slot := func(v): it["slot"] = v
			AdminUtil.chip(f, "Emplacement", AdminUtil.dropdown(slots, it.get("slot", "body"), on_slot, 150.0))
			_num(f, "PV", it, "bonusHp")
			_num(f, "Attaque min", it, "bonusAtkMin")
			_num(f, "max", it, "bonusAtkMax")
			_num(f, "Sort", it, "bonusSpellDmg")
			_boosts(parent, it)
			_legendary(parent, it, admin)
		"jewelry":
			_num(f, "PV", it, "bonusHp")
			_num(f, "Attaque min", it, "bonusAtkMin")
			_num(f, "max", it, "bonusAtkMax")
			_num(f, "Sort", it, "bonusSpellDmg")
			_boosts(parent, it)
			_legendary(parent, it, admin)
		"trap":
			_num(f, "Dégâts min", it, "trapDmgMin")
			_num(f, "max", it, "trapDmgMax")
			var cb := CheckBox.new()
			cb.text = "Permanent (pointes)"
			cb.focus_mode = Control.FOCUS_NONE
			cb.button_pressed = bool(it.get("permanent", false))
			cb.toggled.connect(func(on: bool): it["permanent"] = on)
			f.add_child(cb)
		"key":
			if lvl.is_empty():
				f.add_child(AdminUtil.label("Se lie à une porte une fois placée dans un niveau.", 13, UiTheme.DIM))
			else:
				var on_door := func(v): it["opensDoorId"] = v
				AdminUtil.chip(f, "Ouvre", AdminUtil.dropdown(door_options(lvl), it.get("opensDoorId", ""), on_door, 200.0))
		"switch":
			var on_d := func(v): it["switchOpensDoorId"] = v
			AdminUtil.chip(f, "Ouvre la porte", AdminUtil.dropdown(door_options(lvl), it.get("switchOpensDoorId", ""), on_d, 190.0))
			var mons: Array = [["", "— aucun —"]]
			for m in lvl.get("monsters", []):
				mons.append([m.id, str(m.get("name", "?"))])
			var on_m := func(v): it["switchRevealMonsterId"] = v
			AdminUtil.chip(f, "Révèle le monstre", AdminUtil.dropdown(mons, it.get("switchRevealMonsterId", ""), on_m, 200.0))
			var its: Array = [["", "— aucun —"]]
			for o in lvl.get("items", []):
				if o.id != it.id and str(o.get("type", "")) != "decor":
					its.append([o.id, str(o.get("name", "?"))])
			var on_i := func(v): it["switchRevealItemId"] = v
			AdminUtil.chip(f, "Révèle l'objet", AdminUtil.dropdown(its, it.get("switchRevealItemId", ""), on_i, 200.0))
			var msg := LineEdit.new()
			msg.placeholder_text = "Message affiché"
			msg.text = str(it.get("message", ""))
			msg.custom_minimum_size = Vector2(260, 0)
			msg.text_changed.connect(func(t: String): it["message"] = t)
			AdminUtil.chip(f, "Message", msg)
		"fountain":
			f.add_child(AdminUtil.label("Restaure PV et endurance du groupe. Délai réglable dans « Général ».", 13, UiTheme.DIM))
		"scroll":
			var so: Array = []
			for s in Data.config.get("spells", []):
				so.append([s.id, AdminUtil.spell_label(s)])
			var on_sp := func(v):
				it["spellId"] = v
				if admin != null:
					admin.refresh_tab()
			AdminUtil.chip(f, "Sort enseigné", AdminUtil.dropdown(so, it.get("spellId", ""), on_sp, 260.0))
			var names: Array = []
			for c in AdminUtil.classes_allowing(str(it.get("spellId", ""))):
				names.append(c.name)
			Form.hint(parent, "Classes compatibles : " + (", ".join(names) if not names.is_empty() else "aucune"))

static func door_options(lvl: Dictionary) -> Array:
	var out: Array = [["", "— aucune —"]]
	for d in lvl.get("doors", []):
		out.append([d.id, "Porte (%d,%d)" % [int(d.x), int(d.y)]])
	return out

static func _boosts(parent: Control, it: Dictionary) -> void:
	var f := AdminUtil.flow(parent)
	for x in [["Force", "bonusForce"], ["Dex", "bonusDex"], ["Con", "bonusCon"], ["Int", "bonusInt"], ["Vitesse", "bonusSpeed"]]:
		_num(f, x[0], it, x[1], 100.0)

static func _legendary(parent: Control, it: Dictionary, admin: Node) -> void:
	var f := AdminUtil.flow(parent)
	var cb := CheckBox.new()
	cb.text = "Légendaire"
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(it.get("legendary", false))
	cb.toggled.connect(func(on: bool):
		it["legendary"] = on
		if on and not it.has("legendaryPerk"):
			it["legendaryPerk"] = "lifesteal"
		if admin != null:
			admin.refresh_tab())
	f.add_child(cb)
	if bool(it.get("legendary", false)):
		var on_perk := func(v): it["legendaryPerk"] = v
		AdminUtil.chip(f, "Bonus", AdminUtil.dropdown(PERKS, it.get("legendaryPerk", "lifesteal"), on_perk, 150.0))
		var s := SpinBox.new()
		s.min_value = 1
		s.max_value = 50
		s.value = float(it.get("legendaryValue", 15))
		s.custom_minimum_size = Vector2(84, 0)
		s.value_changed.connect(func(v: float): it["legendaryValue"] = int(v))
		AdminUtil.chip(f, "Valeur (%)", s)

static func _add(admin: Node) -> void:
	Data.config.itemLibrary.append({"id": AdminUtil.new_id("lib"), "name": "Nouvel objet", "icon": "💎", "type": "potion", "heal": 5})
	admin.refresh_tab()

static func _remove(admin: Node, it: Dictionary) -> void:
	var go := func():
		var cfg: Dictionary = Data.config
		(cfg.itemLibrary as Array).erase(it)
		for p in cfg.get("party", []):
			var se: Dictionary = p.get("startEquipment", {})
			for slot in se.keys():
				if se[slot] == it.id:
					se[slot] = ""
		admin.refresh_tab()
	Dialogs.confirm(admin.modals(), "Supprimer l'objet", "Supprimer %s de la bibliothèque ?" % it.name, go, "Supprimer")
