class_name AdminSpells
extends RefCounted
## Onglet « Sorts / Capacités » : mode, dégâts ou soins, statut, vol de vie, coût d'endurance, recharge.

const MODES := [
	["damage", "Dégâts (sur ennemi)"],
	["damageGroup", "Dégâts de zone (tout le groupe ennemi)"],
	["healSingle", "Soin individuel"],
	["healParty", "Soin de groupe"],
	["staminaRestoreSingle", "Restauration d'endurance (sur allié)"],
	["shieldSingle", "Bouclier (sur allié)"],
	["dispelSingle", "Dissipation (retire les statuts négatifs d'un allié)"],
	["sleepGroup", "Sommeil/ralentissement (sur le monstre engagé)"],
	["partyUtility", "Soutien de groupe (instantané, tout le groupe)"],
	["selfBuff", "Buff sur soi (instantané)"],
]

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.config
	var head := Form.panel(host, "Sorts et capacités")
	Form.hint(head, "Tous les sorts et compétences du jeu. Les classes choisissent ensuite ceux qu'elles peuvent utiliser (onglet « Classes »).")
	Form.buttons(head, [["Ajouter un sort", func(): _add(admin)], ["Enregistrer", admin.save]])
	var spells: Array = cfg.get("spells", [])
	for s in spells:
		_card(host, admin, s)

static func _card(host: VBoxContainer, admin: Node, s: Dictionary) -> void:
	var b := Form.panel(host, str(s.get("name", "Sort")))
	var top := AdminUtil.flow(b)
	top.add_child(IconPicker.button(admin.modals(), s, "icon", Callable(), 36.0))
	var e := LineEdit.new()
	e.text = str(s.get("name", ""))
	e.custom_minimum_size = Vector2(190, 0)
	e.text_changed.connect(func(t: String): s["name"] = t)
	AdminUtil.chip(top, "Nom", e)
	var styles: Array = []
	for st in Data.constants.get("SPELL_STYLES", []):
		styles.append([st.id, st.label])
	var on_style := func(v): s["style"] = v
	AdminUtil.chip(top, "Style", AdminUtil.dropdown(styles, s.get("style", "arcane"), on_style, 190.0))
	var on_mode := func(v):
		s["mode"] = v
		admin.refresh_tab()
	AdminUtil.chip(top, "Type", AdminUtil.dropdown(MODES, s.get("mode", "damage"), on_mode, 330.0))
	var rm := Button.new()
	rm.text = "Supprimer"
	rm.focus_mode = Control.FOCUS_NONE
	rm.pressed.connect(func(): _remove(admin, s))
	top.add_child(rm)

	var mode := str(s.get("mode", "damage"))
	var f := AdminUtil.flow(b)
	match mode:
		"damage", "damageGroup":
			AdminUtil.chip(f, "Dégâts min", AdminUtil.mini_number(s, "dmgMin", 0, 9999))
			AdminUtil.chip(f, "max", AdminUtil.mini_number(s, "dmgMax", 0, 9999))
			var cb := CheckBox.new()
			cb.text = "Ignore les résistances (dégâts vrais)"
			cb.focus_mode = Control.FOCUS_NONE
			cb.button_pressed = bool(s.get("ignoreAllResist", false))
			cb.toggled.connect(func(on: bool): s["ignoreAllResist"] = on)
			f.add_child(cb)
		"staminaRestoreSingle":
			AdminUtil.chip(f, "Endurance min", AdminUtil.mini_number(s, "staminaMin", 0, 9999))
			AdminUtil.chip(f, "max", AdminUtil.mini_number(s, "staminaMax", 0, 9999))
		"shieldSingle":
			AdminUtil.chip(f, "Bouclier min", AdminUtil.mini_number(s, "shieldMin", 0, 9999))
			AdminUtil.chip(f, "max", AdminUtil.mini_number(s, "shieldMax", 0, 9999))
		"partyUtility":
			AdminUtil.chip(f, "Réduction de recharge (s)", AdminUtil.mini_number(s, "cooldownReductionSec", 0, 600))
			f.add_child(AdminUtil.label("+ Vigueur", 13, UiTheme.DIM))
		"dispelSingle", "sleepGroup", "selfBuff":
			f.add_child(AdminUtil.label("Aucun réglage spécifique.", 13, UiTheme.DIM))
		_:
			AdminUtil.chip(f, "Soin min", AdminUtil.mini_number(s, "healMin", 0, 9999))
			AdminUtil.chip(f, "max", AdminUtil.mini_number(s, "healMax", 0, 9999))
	if mode == "damage":
		AdminUtil.chip(f, "Vol de vie (%)", AdminUtil.mini_number(s, "spellLifestealPct", 0, 100))
	var g := AdminUtil.flow(b)
	AdminUtil.chip(g, "Coût d'endurance", AdminUtil.mini_number(s, "staminaCost", 0, 50, 15))
	AdminUtil.chip(g, "Recharge (s)", AdminUtil.mini_number(s, "cooldownSec", 0, 60, 6))
	if mode == "damage":
		var defs: Dictionary = Data.constants.get("STATUS_DEFS", {})
		var sopts: Array = [["", "— aucun —"]]
		for id in defs:
			var d: Dictionary = defs[id]
			sopts.append([id, "%s %s" % [d.get("icon", ""), d.get("label", id)]])
		var on_status := func(v):
			if v == "":
				s.erase("statusEffect")
			else:
				s["statusEffect"] = v
			admin.refresh_tab()
		AdminUtil.chip(g, "Statut infligé", AdminUtil.dropdown(sopts, s.get("statusEffect", ""), on_status, 210.0))
		var cur := str(s.get("statusEffect", ""))
		if cur != "" and defs.has(cur):
			AdminUtil.chip(g, "Chance (%)", AdminUtil.mini_number(s, "statusChance", 0, 100, 30))
			AdminUtil.chip(g, "Durée (tours)", AdminUtil.mini_number(s, "statusDuration", 1, 10, 3))
			if bool(defs[cur].get("dot", false)):
				AdminUtil.chip(g, "Dégâts/tour", AdminUtil.mini_number(s, "statusPower", 1, 20, 3))

static func _add(admin: Node) -> void:
	Data.config.spells.append({"id": AdminUtil.new_id("spell"), "name": "Nouveau sort", "icon": "✨", "style": "arcane", "mode": "damage", "dmgMin": 3, "dmgMax": 7, "healMin": 5, "healMax": 10, "staminaCost": 15, "cooldownSec": 6})
	admin.refresh_tab()

static func _remove(admin: Node, s: Dictionary) -> void:
	var go := func():
		var cfg: Dictionary = Data.config
		(cfg.spells as Array).erase(s)
		for c in cfg.get("classes", []):
			(c.get("allowedSpellIds", []) as Array).erase(s.id)
			var keep: Array = []
			for p in c.get("spellProgression", []):
				if p.get("spellId") != s.id:
					keep.append(p)
			c["spellProgression"] = keep
		for p in cfg.get("party", []):
			(p.get("spellsKnown", []) as Array).erase(s.id)
		admin.refresh_tab()
	Dialogs.confirm(admin.modals(), "Supprimer le sort", "Supprimer le sort/capacité %s ?" % s.name, go, "Supprimer")
