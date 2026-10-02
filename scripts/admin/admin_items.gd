class_name AdminItems
extends RefCounted
## Onglet « Objets de base » : tableau de la bibliothèque d'objets (potions, armes, armures, bijoux, clés, parchemins, pièges).
## Reproduit `renderLibItemTable` / `libItemDetailsHtml` / `statBoostFieldsHtml` / `legendaryFieldsHtml` / `clampItemStat` /
## `editLibItem` / `addLibItem` / `removeLibItem` de l'original.

const TYPES := [["potion", "Potion"], ["weapon", "Arme"], ["armor", "Armure"], ["jewelry", "Bijou"], ["key", "Clé"], ["scroll", "Parchemin"], ["trap", "Piège"]]
const LEVEL_TYPES := [["potion", "Potion"], ["weapon", "Arme"], ["armor", "Armure"], ["jewelry", "Bijou"], ["key", "Clé"], ["scroll", "Parchemin"], ["trap", "Piège"], ["switch", "Interrupteur"], ["fountain", "Fontaine"]]
const PERKS := [["lifesteal", "Vol de vie"], ["crit", "Critique"], ["thorns", "Renvoi"]]
## `LEGENDARY_PERKS` de l'original (icône + libellé FR), dans l'ordre de l'original.
const LEGENDARY_PERKS := [["lifesteal", "🩸 Vol de vie"], ["crit", "💥 Critique"], ["thorns", "🌵 Renvoi"]]
const STAT_FIELDS := ["bonusAtkMin", "bonusAtkMax", "bonusHp", "bonusSpellDmg", "heal", "trapDmgMin", "trapDmgMax", "bonusForce", "bonusDex", "bonusCon", "bonusInt", "bonusSpeed"]
const BOOST_FIELDS := ["bonusForce", "bonusDex", "bonusCon", "bonusInt", "bonusSpeed"]

const HEADERS := ["Icône", "Nom", "Type", "Détails", ""]
const MIN_W := [44, 90, 100, 345, 34]
## Colonnes qui se partagent l'espace libre : Nom, Type, Détails (proportions du tableau HTML : 311 / 160 / 535).
const STRETCH := {1: 3.11, 2: 1.6, 3: 5.35}

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	var p := Form.panel(host, "Objets de base")
	Form.hint(p, "Cette bibliothèque sert à définir l'équipement de départ des personnages (onglet Personnages). Ces objets ne sont pas liés à un niveau précis.")
	var grid := AdminTable.create(p, HEADERS, MIN_W)
	AdminCells.wrap_headers(grid, HEADERS.size())
	for col in STRETCH:
		var hd := grid.get_child(col) as Control
		hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd.size_flags_stretch_ratio = STRETCH[col]
	for it in cfg.get("itemLibrary", []):
		_row(grid, admin, it)
	var status_ref := [null]
	AdminCells.actions(p, [
		{"text": "+ Ajouter un objet", "cb": func(): _add(admin)},
		{"text": "💾 Enregistrer la configuration par défaut", "primary": true, "cb": func(): admin.confirm_save(status_ref[0])},
	])
	status_ref[0] = AdminCells.status_label(p)

static func _row(grid: GridContainer, admin: Node, it: Dictionary) -> void:
	var refresh := func(): admin.refresh_tab()
	AdminTable.cell(grid, IconPicker.button(admin.modals(), it, "icon", Callable(), 38.0))
	var name_edit := AdminCells.text(it, "name")
	name_edit.size_flags_stretch_ratio = STRETCH[1]
	AdminTable.cell(grid, name_edit)
	var type_sel := AdminCells.option(TYPES, it.get("type", ""), func(v):
		it["type"] = v
		refresh.call(), 100.0, "", 0.74)
	type_sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_sel.size_flags_stretch_ratio = STRETCH[2]
	AdminTable.cell(grid, type_sel)
	var d := _details(it, admin)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.size_flags_stretch_ratio = STRETCH[3]
	AdminTable.cell(grid, d)
	AdminTable.cell(grid, AdminCells.trash(func(): _remove(admin, it)))

## `clampItemStat` de l'original : bornage selon le champ, sans troncature (les décimales sont acceptées).
static func clamp_value(it: Dictionary, field: String, value: float) -> float:
	if ["heal", "trapDmgMin", "trapDmgMax"].has(field):
		return maxf(1.0, value)
	if (field == "bonusAtkMin" or field == "bonusAtkMax") and it.get("type") == "weapon":
		return maxf(1.0, value)
	if BOOST_FIELDS.has(field):
		return maxf(0.0, minf(100.0, value))
	if ["bonusAtkMin", "bonusAtkMax", "bonusHp", "bonusSpellDmg"].has(field):
		return maxf(0.0, value)
	return value

## Champ numérique d'un objet : bornage `clampItemStat` puis la valeur bornée est renvoyée dans le champ.
static func _stat(it: Dictionary, key: String, w: float, tip: String, default_value: float = 0.0, or_default: bool = true) -> LineEdit:
	var o := {"w": w, "tip": tip, "or": or_default, "echo": true, "fix": func(v: float) -> float: return clamp_value(it, key, v)}
	if BOOST_FIELDS.has(key):
		o["lo"] = 0
		o["hi"] = 100
	return AdminCells.num(it, key, default_value, o)

static func _line() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f

## Colonne « Détails » selon le type (`libItemDetailsHtml`).
static func _details(it: Dictionary, admin: Node) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var refresh := func(): admin.refresh_tab()
	match str(it.get("type", "")):
		"potion":
			var f := _line()
			f.add_child(_stat(it, "heal", 48, "Soin"))
			f.add_child(AdminCells.inline("PV soin"))
			var e := AdminCells.num(it, "staminaRestore", 0, {"w": 48, "or": true, "tip": "Endurance"})
			f.add_child(e)
			f.add_child(AdminCells.inline("End."))
			v.add_child(f)
		"weapon":
			var wt: Array = []
			for w in AdminUtil.weapon_types():
				wt.append([w.id, w.label])
			var sel := AdminCells.option(wt, it.get("weaponType", ""), func(x): it["weaponType"] = x)
			sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(sel)
			var f := _line()
			f.add_child(_stat(it, "bonusAtkMin", 36, ""))
			f.add_child(AdminCells.inline("-"))
			f.add_child(_stat(it, "bonusAtkMax", 36, ""))
			v.add_child(f)
			_boosts(v, it)
			_legendary(v, it, refresh)
		"armor":
			var slots: Array = []
			for sl in Data.constants.get("SLOT_TYPES", []):
				if sl.id != "weapon" and sl.id != "accessory":
					slots.append([sl.id, sl.label])
			var sel := AdminCells.option(slots, it.get("slot", ""), func(x): it["slot"] = x)
			sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(sel)
			_gear_line(v, it, "Bonus PV (tank)", "Bonus attaque min (guerrier/archer)", "Bonus attaque max", "Bonus dégâts de sort (mage)")
			_boosts(v, it)
			_legendary(v, it, refresh)
		"jewelry":
			_gear_line(v, it, "Bonus PV", "Bonus attaque min", "Bonus attaque max", "Bonus dégâts de sort")
			_boosts(v, it)
			_legendary(v, it, refresh)
		"trap":
			var f := _line()
			f.add_child(_stat(it, "trapDmgMin", 36, "", 1.0))
			f.add_child(AdminCells.inline("-"))
			f.add_child(_stat(it, "trapDmgMax", 36, "", 4.0))
			f.add_child(AdminCells.inline("dégâts"))
			var cb := AdminCells.check("Permanent (pointes)", bool(it.get("permanent", false)), func(on: bool): it["permanent"] = on)
			f.add_child(cb)
			v.add_child(f)
		"key":
			v.add_child(AdminCells.inline("Se lie à une porte une fois placé dans un niveau", true, 0.74, true))
		"scroll":
			var cfg: Dictionary = Data.admin_config()
			var so: Array = []
			for s in cfg.get("spells", []):
				so.append([s.id, AdminUtil.spell_label(s)])
			if so.is_empty():
				so.append(["", "— Aucun sort défini —"])
			var sel := AdminCells.option(so, it.get("spellId", ""), func(x):
				it["spellId"] = x
				refresh.call())
			sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(sel)
			var sid := str(it.get("spellId", ""))
			var txt := "—"
			if sid != "":
				var names: Array = []
				for c in cfg.get("classes", []):
					if (c.get("allowedSpellIds", []) as Array).has(sid):
						names.append(str(c.get("name", "")))
				txt = ", ".join(names) if not names.is_empty() else "aucune"
			v.add_child(AdminCells.inline("Classes compatibles : " + txt, true, 0.74, true))
		_:
			v.add_child(AdminCells.inline("—", true, 0.7))
	return v

## PV / Atq min-max / Sort (armures et bijoux).
static func _gear_line(v: Control, it: Dictionary, t_hp: String, t_min: String, t_max: String, t_sp: String) -> void:
	var f := _line()
	f.add_child(_stat(it, "bonusHp", 34, t_hp))
	f.add_child(AdminCells.inline("PV"))
	f.add_child(_stat(it, "bonusAtkMin", 30, t_min))
	f.add_child(AdminCells.inline("-"))
	f.add_child(_stat(it, "bonusAtkMax", 30, t_max))
	f.add_child(AdminCells.inline("Atq"))
	f.add_child(_stat(it, "bonusSpellDmg", 30, t_sp))
	f.add_child(AdminCells.inline("Sort"))
	v.add_child(f)

## `statBoostFieldsHtml` : For / Dex / Con / Int / Vit sur une ligne (libellés 0,62 rem, grisés).
static func _boosts(v: Control, it: Dictionary) -> void:
	var f := _line()
	for x in [["For", "bonusForce", "Bonus Force"], ["Dex", "bonusDex", "Bonus Dextérité"], ["Con", "bonusCon", "Bonus Constitution"],
			["Int", "bonusInt", "Bonus Intelligence"], ["Vit", "bonusSpeed", "Bonus Vitesse (initiative)"]]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 2)
		pair.add_child(AdminCells.inline(x[0], true, 0.62))
		pair.add_child(_stat(it, x[1], 26, x[2]))
		f.add_child(pair)
	v.add_child(f)

## `legendaryFieldsHtml` : filet pointillé, case « ✨ Légendaire » ; si cochée : bonus (liste) + valeur en %. Comme l'original, le
## bonus n'est mémorisé que lorsqu'on le choisit dans la liste (la coche seule ne l'écrit pas).
static func _legendary(v: Control, it: Dictionary, refresh: Callable) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, UiMetrics.css(3.0))
	v.add_child(sp)
	AdminCells.dash_line(v)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, UiMetrics.css(3.0))
	v.add_child(sp2)
	v.add_child(AdminCells.check("✨ Légendaire", bool(it.get("legendary", false)), func(on: bool):
		it["legendary"] = on
		refresh.call()))
	if bool(it.get("legendary", false)):
		var f := _line()
		f.add_child(AdminCells.option(LEGENDARY_PERKS, it.get("legendaryPerk", ""), func(x): it["legendaryPerk"] = x, 150.0))
		f.add_child(AdminCells.num(it, "legendaryValue", 15, {"w": 44, "or": true, "lo": 1, "hi": 50, "tip": "Valeur du bonus (%)"}))
		f.add_child(AdminCells.inline("%"))
		v.add_child(f)


## --- API historique (onglet « Niveaux » : fiche d'objet placé dans un niveau) ---

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
			_legacy_boosts(parent, it)
			_legacy_legendary(parent, it, admin)
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
			_legacy_boosts(parent, it)
			_legacy_legendary(parent, it, admin)
		"jewelry":
			_num(f, "PV", it, "bonusHp")
			_num(f, "Attaque min", it, "bonusAtkMin")
			_num(f, "max", it, "bonusAtkMax")
			_num(f, "Sort", it, "bonusSpellDmg")
			_legacy_boosts(parent, it)
			_legacy_legendary(parent, it, admin)
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
			for s in Data.admin_config().get("spells", []):
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

static func _legacy_boosts(parent: Control, it: Dictionary) -> void:
	var f := AdminUtil.flow(parent)
	for x in [["Force", "bonusForce"], ["Dex", "bonusDex"], ["Con", "bonusCon"], ["Int", "bonusInt"], ["Vitesse", "bonusSpeed"]]:
		_num(f, x[0], it, x[1], 100.0)

static func _legacy_legendary(parent: Control, it: Dictionary, admin: Node) -> void:
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
	var cfg: Dictionary = Data.admin_config()
	if not (cfg.get("itemLibrary") is Array):
		cfg["itemLibrary"] = []
	(cfg.itemLibrary as Array).append({"id": AdminUtil.new_id("lib"), "name": "Nouvel objet", "icon": "💎", "type": "potion", "heal": 5})
	admin.refresh_tab()

## `removeLibItem` : confirmation sans titre, puis l'objet disparaît de la bibliothèque et de l'équipement de départ des personnages.
static func _remove(admin: Node, it: Dictionary) -> void:
	var go := func():
		var cfg: Dictionary = Data.admin_config()
		(cfg.itemLibrary as Array).erase(it)
		for p in cfg.get("party", []):
			var se = p.get("startEquipment")
			if se is Dictionary:
				for slot in se.keys():
					if se[slot] == it.id:
						se[slot] = ""
		admin.refresh_tab()
	Dialogs.confirm(admin.modals(), "", "Supprimer %s de la bibliothèque ?" % it.get("name", ""), go)
