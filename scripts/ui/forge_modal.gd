class_name ForgeModal
extends RefCounted
## Atelier du forgeron : +1 à chaque statistique numérique d'un objet (arme, armure ou bijou) contre de l'or.

const FIELDS := {"bonusAtkMin": "common.degats_min", "bonusAtkMax": "common.degats_max", "bonusHp": "common.pv", "bonusSpellDmg": "common.degats_soin_de_sort",
	"bonusForce": "common.force", "bonusDex": "common.dexterite", "bonusCon": "common.constitution", "bonusInt": "common.intelligence", "bonusSpeed": "common.vitesse"}

static func cost(it: Dictionary) -> int:
	return 40 + int(it.get("enchantLevel", 0)) * 30

## Améliore l'objet `it` ; `owner` est le personnage qui le porte ({} si dans la besace). Renvoie "" si réussi.
static func upgrade(gs: GameState, it: Dictionary, owner: Dictionary) -> String:
	var c := cost(it)
	if gs.gold < c:
		return L.t("common.pas_assez_or")
	gs.gold -= c
	it["enchantLevel"] = int(it.get("enchantLevel", 0)) + 1
	for k in FIELDS:
		if it.has(k) and float(it[k]) != 0.0:
			it[k] = snappedf(float(it[k]) + 1.0, 0.1)
			if float(it[k]) == floorf(float(it[k])):
				it[k] = int(it[k])
	gs.add_log(L.fa(L.t("ui.forge_modal.ameliore"), [it.name, int(it.enchantLevel)]))
	if not owner.is_empty():
		Characters.recompute(owner, gs.cfg)
	return ""

static func _detail(it: Dictionary) -> String:
	var parts: Array = []
	for k in FIELDS:
		if it.has(k) and float(it[k]) != 0.0:
			parts.append("%s %s → %s" % [FIELDS[k], str(it[k]), str(snappedf(float(it[k]) + 1.0, 0.1))])
	return " · ".join(parts) if not parts.is_empty() else L.t("ui.forge_modal.aucune_statistique_numerique")

static func open(host: Node, gs: GameState, on_change: Callable = Callable()) -> Modal:
	var m := Modal.open(host, L.t("ui.forge_modal.la_forge"), 640.0)
	var st := {"tab": "char_" + (str(gs.party[0].id) if not gs.party.is_empty() else "")}
	var gold := AdminUtil.label("", 16, UiTheme.GOLD)
	m.content.add_child(gold)
	var tabs := AdminUtil.flow(m.content)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	m.content.add_child(body)
	var render := Callable()
	render = func():
		gold.text = L.fa(L.t("common.pieces_or"), gs.gold)
		for ch in tabs.get_children():
			ch.queue_free()
		for ch in body.get_children():
			ch.queue_free()
		var all_tabs: Array = []
		for c in gs.party:
			all_tabs.append(["char_" + str(c.id), "%s %s" % [c.get("icon", ""), c.name]])
		all_tabs.append(["bag", L.t("ui.forge_modal.besace")])
		for t in all_tabs:
			var tid: String = t[0]
			var tb := Button.new()
			tb.text = t[1]
			tb.toggle_mode = true
			tb.button_pressed = st.tab == tid
			tb.focus_mode = Control.FOCUS_NONE
			tb.pressed.connect(func():
				st.tab = tid
				render.call())
			tabs.add_child(tb)
		var entries: Array = []   # [item, owner]
		if st.tab == "bag":
			for it in gs.inventory:
				if ["weapon", "armor", "jewelry"].has(str(it.get("type", ""))):
					entries.append([it, {}])
		else:
			var c := gs.char_by_id(str(st.tab).trim_prefix("char_"))
			for slot in Characters.SLOTS:
				var it = c.get("equipment", {}).get(slot)
				if it != null:
					entries.append([it, c])
		if entries.is_empty():
			var e := AdminUtil.label(L.t("ui.forge_modal.aucun_objet_ameliorable_ici") if st.tab == "bag" else L.t("ui.forge_modal.aucun_equipement_porte_par_ce"), 14, UiTheme.DIM)
			e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.add_child(e)
		for en in entries:
			var it: Dictionary = en[0]
			var owner: Dictionary = en[1]
			var row := VBoxContainer.new()
			var top := HBoxContainer.new()
			top.add_theme_constant_override("separation", 8)
			top.add_child(IconPicker.icon_control(str(it.get("icon", "")), 32.0))
			var nm := AdminUtil.label("%s%s" % [it.name, ("  +%d" % int(it.enchantLevel)) if int(it.get("enchantLevel", 0)) > 0 else ""], 15, UiTheme.PARCH)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(nm)
			var ub := Button.new()
			ub.text = L.fa(L.t("ui.forge_modal.cout_or"), cost(it))
			ub.disabled = gs.gold < cost(it)
			ub.focus_mode = Control.FOCUS_NONE
			ub.pressed.connect(func():
				upgrade(gs, it, owner)
				if on_change.is_valid():
					on_change.call()
				render.call())
			top.add_child(ub)
			row.add_child(top)
			var d := AdminUtil.label(_detail(it), 13, UiTheme.DIM)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(d)
			body.add_child(row)
			body.add_child(HSeparator.new())
	render.call()
	m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): m.close()}])
	return m
