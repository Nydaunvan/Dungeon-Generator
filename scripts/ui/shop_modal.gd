class_name ShopModal
extends RefCounted
## Fenêtre de boutique (marchand ambulant ou marchand du village) : acheter, vendre, comparer avec l'équipement d'un personnage.

const CATS := [["items", "common.equipement"], ["potions", "Potions"], ["keys", "ui.shop_modal.cles_et_parchemins"]]

## `offers` est modifié en place (les objets achetés disparaissent). `on_change` est appelé après chaque transaction.
static func open(host: Node, gs: GameState, offers: Array, village: bool, on_change: Callable = Callable()) -> Modal:
	var m := Modal.open(host, L.t("ui.shop_modal.le_marchand") if village else L.t("ui.shop_modal.le_marchand_itinerant"), 760.0)
	var st := {"tab": "buy", "cat": "items", "who": str(gs.active_char_id), "qty": {}, "msg": ""}
	var gold := AdminUtil.label("", 17, UiTheme.GOLD)
	m.content.add_child(gold)
	var msg := AdminUtil.label("", 14, Color("e06a5a"))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.content.add_child(msg)
	var who_bar := AdminUtil.flow(m.content)
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	m.content.add_child(tab_bar)
	var cat_bar := HBoxContainer.new()
	cat_bar.add_theme_constant_override("separation", 6)
	m.content.add_child(cat_bar)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.content.add_child(list)

	var refresh := Callable()
	var done := func(err: String):
		st.msg = err
		if err == "" and on_change.is_valid():
			on_change.call()
		refresh.call()

	refresh = func():
		gold.text = L.fa(L.t("ui.shop_modal.pieces_or"), gs.gold)
		msg.text = str(st.msg)
		for box in [who_bar, tab_bar, cat_bar, list]:
			for ch in box.get_children():
				ch.queue_free()
		# personnage de comparaison
		who_bar.add_child(AdminUtil.label(L.t("ui.shop_modal.comparer_avec"), 13, UiTheme.DIM))
		var wg := ButtonGroup.new()
		for c in gs.party:
			var b := Button.new()
			b.text = str(c.name)
			b.toggle_mode = true
			b.button_group = wg
			b.button_pressed = str(c.id) == str(st.who)
			b.focus_mode = Control.FOCUS_NONE
			var cid: String = str(c.id)
			b.pressed.connect(func():
				st.who = cid
				refresh.call())
			who_bar.add_child(b)
		var tg := ButtonGroup.new()
		for t in [["buy", L.t("ui.shop_modal.acheter")], ["sell", L.t("ui.shop_modal.vendre")]]:
			var b := Button.new()
			b.text = t[1]
			b.toggle_mode = true
			b.button_group = tg
			b.button_pressed = st.tab == t[0]
			b.focus_mode = Control.FOCUS_NONE
			var tid: String = t[0]
			b.pressed.connect(func():
				st.tab = tid
				st.msg = ""
				refresh.call())
			tab_bar.add_child(b)
		var cg := ButtonGroup.new()
		for c in CATS:
			var b := Button.new()
			b.text = (L.t("common.parchemins") if (village and c[0] == "keys") else c[1])
			b.toggle_mode = true
			b.button_group = cg
			b.button_pressed = st.cat == c[0]
			b.focus_mode = Control.FOCUS_NONE
			var cat_id: String = c[0]
			b.pressed.connect(func():
				st.cat = cat_id
				refresh.call())
			cat_bar.add_child(b)
		_fill(list, gs, offers, st, done, refresh)
		m.call_deferred("_fit")
	refresh.call()
	m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): m.close()}])
	return m

static func _tip(it: Dictionary, gs: GameState, who: String) -> String:
	var lines: Array = [str(it.get("name", "?"))]
	lines.append_array(Inventory.describe(it, gs.cfg))
	var slot := Inventory.slot_of(it)
	var c := gs.char_by_id(who)
	if slot != "" and not c.is_empty():
		var eq_v = c.get("equipment", {}).get(slot)
		var eq: Dictionary = eq_v if eq_v is Dictionary else {}
		lines.append("")
		if eq.is_empty():
			lines.append(L.fa(L.t("ui.shop_modal.n_a_rien_equipe_a"), c.name))
		else:
			lines.append(L.fa(L.t("ui.shop_modal.equipe_sur"), [c.name, eq.get("name", "?")]))
			lines.append_array(Inventory.describe(eq, gs.cfg))
	return "\n".join(lines)

## Regroupe les objets empilables (potions simples, parchemins identiques) ; renvoie [{rep, idxs, key}].
static func _groups(items: Array, cat: String) -> Array:
	var out: Array = []
	var by_key := {}
	for i in items.size():
		var it: Dictionary = items[i]
		if Inventory.tab_of(it) != cat:
			continue
		var k := Inventory.stack_key(it)
		if k == "":
			out.append({"rep": it, "idxs": [i], "key": ""})
		elif by_key.has(k):
			by_key[k].idxs.append(i)
		else:
			var g := {"rep": it, "idxs": [i], "key": k}
			by_key[k] = g
			out.append(g)
	return out

static func _fill(list: VBoxContainer, gs: GameState, offers: Array, st: Dictionary, done: Callable, refresh: Callable) -> void:
	var buy: bool = st.tab == "buy"
	var groups := _groups(offers if buy else gs.inventory, str(st.cat))
	if groups.is_empty():
		list.add_child(AdminUtil.label(L.t("ui.shop_modal.le_marchand_n_a_plus") if buy else L.t("ui.shop_modal.votre_besace_est_vide"), 14, UiTheme.DIM))
		return
	for g in groups:
		var rep: Dictionary = g.rep
		var idxs: Array = g.idxs
		var count := idxs.size()
		var gk := ("buy:" if buy else "sell:") + str(g.key if g.key != "" else rep.get("id", rep.get("uid", "")))
		var qty := clampi(int(st.qty.get(gk, 1)), 1, count)
		st.qty[gk] = qty
		var unit := int(rep.get("price", 0)) if buy else Shop.sell_price(rep)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = _tip(rep, gs, str(st.who))
		row.add_child(IconPicker.icon_control(str(rep.get("icon", "")), 40.0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(AdminUtil.label(("✨ " if rep.get("legendary", false) else "") + str(rep.get("name", "?")), 15, UiTheme.GOLD if rep.get("legendary", false) else UiTheme.PARCH))
		var sub := AdminUtil.label(Shop.summary(rep, gs.cfg) + (L.fa(L.t("ui.shop_modal.en_stock"), count) if count > 1 else ""), 12, UiTheme.DIM)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(sub)
		row.add_child(info)
		if count > 1:
			for d in [-1, 1]:
				if d == 1:
					var q := AdminUtil.label(str(qty), 15)
					q.custom_minimum_size = Vector2(26, 0)
					q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					row.add_child(q)
				var sb := Button.new()
				sb.text = "−" if d < 0 else "+"
				sb.focus_mode = Control.FOCUS_NONE
				var dd: int = d
				sb.pressed.connect(func():
					st.qty[gk] = clampi(qty + dd, 1, count)
					refresh.call())
				row.add_child(sb)
		var is_key: bool = (not buy) and str(rep.get("type", "")) == "key"
		if is_key:
			row.add_child(AdminUtil.label(L.t("ui.shop_modal.ne_peut_pas_etre_vendue"), 12, UiTheme.DIM))
		else:
			var total := unit * qty
			var pl := AdminUtil.label("%d or" % total, 15, UiTheme.GOLD)
			pl.custom_minimum_size = Vector2(64, 0)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(pl)
			var b := Button.new()
			b.text = L.t("ui.shop_modal.acheter") if buy else L.t("ui.shop_modal.vendre")
			b.focus_mode = Control.FOCUS_NONE
			b.disabled = buy and gs.gold < total
			var take: Array = idxs.slice(0, qty)
			var gkey: String = gk
			b.pressed.connect(func():
				var err := ""
				take.sort()
				take.reverse()   # indices décroissants : les retraits ne décalent pas les suivants
				var bought := 0
				var paid := 0
				var rep_name := str(gs.inventory[int(take[0])].get("name", "")) if not buy else str(offers[int(take[0])].get("name", ""))
				for ix in take:
					var unit_p := int(offers[int(ix)].get("price", 0)) if buy else Shop.sell_price(gs.inventory[int(ix)])
					err = Shop.buy(gs, offers, int(ix), true) if buy else Shop.sell(gs, int(ix), true)
					if err != "":
						if buy and err.contains("plein"):
							gs.add_log(err.trim_suffix(".") + L.t("ui.shop_modal.impossible_acheter_davantage"))
						break
					bought += 1
					paid += unit_p
				if bought > 0:
					gs.add_log(L.fa(L.t("ui.shop_modal.pour_pieces_or"), [L.t("ui.shop_modal.le_groupe_achete") if buy else L.t("ui.shop_modal.le_groupe_vend"), "%d× " % bought if bought > 1 else "", rep_name, paid]))
				st.qty.erase(gkey)
				done.call(err if bought == 0 else ""))
			row.add_child(b)
		list.add_child(row)
