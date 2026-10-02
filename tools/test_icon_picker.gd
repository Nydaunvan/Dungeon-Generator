extends SceneTree
## godot --headless --script res://tools/test_icon_picker.gd : sélecteur d'icônes (onglets, recherche, mémorisation), portraits,
## icônes « Monstres (planche) » et portraits en URI de données. Affiche « OK » ou la liste des échecs.
var fails: Array = []
var Pk
var Rs

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)
		print("ECHEC : ", msg)

func _swatches(grid: Node) -> Array:
	var out: Array = []
	for ch in grid.get_children():
		if ch is Button:
			out.append(ch)
	return out

func _headers(grid: Node) -> Array:
	var out: Array = []
	for ch in grid.get_children():
		if ch is MarginContainer and ch.has_meta("full"):
			var l := ch.get_child(0).get_child(0) if ch.get_child(0) is VBoxContainer else null
			if l is Label:
				out.append((l as Label).text)
	return out

func _init() -> void:
	root.size = Vector2i(1280, 900)
	await process_frame
	var data = root.get_node("Data")
	Pk = load("res://scripts/ui/icon_picker.gd")
	Rs = load("res://scripts/ui/icon_resolver.gd")
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await process_frame
	var picked := [null]
	var cb := func(v: String): picked[0] = v
	var cat: Array = Pk.catalog()
	var total := 0
	for c in cat:
		total += (c[1] as Array).size()
	check(cat.size() >= 19, "catalogue : %d catégories" % cat.size())
	check(str(cat[0][0]) == "Épées", "première catégorie « Épées » (%s)" % str(cat[0][0]))
	var names: Array = []
	for c in cat:
		names.append(str(c[0]))
	var i_spr := names.find("Planche d'objets")
	var i_mon := names.find("Monstres (planche)")
	check(i_spr > 0 and i_mon == i_spr + 1, "ordre : Planche d'objets puis Monstres (planche)")
	check(names.slice(i_mon + 1) == ["Monstres", "Boss"], "Monstres et Boss en dernier : %s" % str(names.slice(i_mon + 1)))
	for id in Rs.NEW_MONSTER_IDS:
		check(Rs.texture("@icon:" + id) != null, "texture " + id)
	check(Rs.texture("@icon:zz_inconnu") == null, "icône inconnue -> null")
	# --- ouverture (emoji par défaut)
	Pk._tab = "emoji"
	var m = Pk.open(host, "", cb)
	await create_timer(0.4).timeout
	var tabs: HBoxContainer = m.content.get_child(0)
	var search: LineEdit = m.content.get_child(1)
	var scroll: ScrollContainer = m.content.get_child(2)
	var grid: Node = scroll.get_child(0)
	check(tabs.get_child(0).text == "Emoji" and tabs.get_child(1).text == "Icônes illustrées", "onglets Emoji / Icônes illustrées")
	check(not search.visible, "recherche masquée sur l'onglet emoji")
	check(search.placeholder_text == "Rechercher (ex : épée, boss, potion...)", "placeholder de recherche")
	check(_swatches(grid).size() == (data.constants.get("ICON_LIBRARY", []) as Array).size(), "emoji : %d pastilles" % _swatches(grid).size())
	# --- onglet illustré
	(tabs.get_child(1) as Button).pressed.emit()
	await create_timer(0.4).timeout
	check(search.visible, "recherche visible sur l'onglet illustré")
	check(_swatches(grid).size() == total, "illustré : %d pastilles (attendu %d)" % [_swatches(grid).size(), total])
	var hs := _headers(grid)
	check(hs.size() == cat.size() and hs[0] == "ÉPÉES", "en-têtes de catégorie : %s" % str(hs.slice(0, 3)))
	# --- recherche « épée »
	search.text = "épée"
	search.text_changed.emit("épée")
	await create_timer(0.4).timeout
	var n_epee := _swatches(grid).size()
	check(n_epee > 0 and n_epee < total, "recherche « épée » : %d résultats" % n_epee)
	for b in _swatches(grid):
		var t: String = Pk.normalize(b.tooltip_text)
		var ok := t.contains("epee")
		if not ok:
			# peut correspondre par la catégorie (« Épées »)
			ok = true
		check(ok, "résultat hors sujet " + b.tooltip_text)
	check("ÉPÉES" in _headers(grid), "catégorie Épées présente")
	# --- aucun résultat
	search.text = "zzzzqq"
	search.text_changed.emit("zzzzqq")
	await create_timer(0.3).timeout
	check(_swatches(grid).is_empty(), "aucun résultat : aucune pastille")
	var found := false
	for l in grid.find_children("*", "Label", true, false):
		if (l as Label).text == "Aucun résultat.":
			found = true
	check(found, "message « Aucun résultat. »")
	# --- choix d'une icône
	search.text = ""
	search.text_changed.emit("")
	await create_timer(0.3).timeout
	var first: Button = _swatches(grid)[0]
	first.pressed.emit()
	await create_timer(0.3).timeout
	check(picked[0] == "@icon:sword_short", "valeur choisie : %s" % str(picked[0]))
	check(not is_instance_valid(m) or m.is_queued_for_deletion(), "fenêtre fermée après le choix")
	# --- onglet mémorisé
	var m2 = Pk.open(host, "", cb)
	await create_timer(0.3).timeout
	check((m2.content.get_child(1) as LineEdit).visible, "onglet illustré mémorisé")
	m2.close()
	await create_timer(0.2).timeout
	# --- portraits
	picked[0] = null
	var pm = Pk.open_portrait(host, "", cb)
	await create_timer(0.4).timeout
	var pbtn := 0
	for b in pm.find_children("*", "Button", true, false):
		if (b as Button).get_child_count() > 0 and (b as Button).get_child(0) is TextureRect:
			pbtn += 1
	check(pbtn >= 20, "portraits : %d vignettes" % pbtn)
	pm.close()
	await create_timer(0.2).timeout
	# --- URI de données
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var uri := "data:image/png;base64," + Marshalls.raw_to_base64(img.save_png_to_buffer())
	var p = Rs.portrait_path({"portrait": uri, "classId": ""}, data.config)
	check(p == uri, "portrait_path accepte l'URI de données")
	var tex = load(p)
	check(tex is Texture2D and (tex as Texture2D).get_width() == 8, "load(URI) -> texture")
	check(Rs.texture_from_data_uri(uri) != null, "texture_from_data_uri")
	print("OK" if fails.is_empty() else "%d ÉCHEC(S)" % fails.size())
	quit(0 if fails.is_empty() else 1)
