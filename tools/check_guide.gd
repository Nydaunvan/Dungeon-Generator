extends Node
## Guide en livre : tous les sujets (fr et en) s'ouvrent et se lisent, les nouveaux sujets existent, le démarrage vient en premier.
## Lancer : godot --path . res://tools/check_guide.tscn --quit-after 900

var fails := 0

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func settle(frames: int = 20) -> void:
	for i in frames:
		await get_tree().process_frame

func _plain(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\s+")
	return re.sub(s.strip_edges(), " ", true)

func _ready() -> void:
	var host := CanvasLayer.new()
	add_child(host)
	for lang in ["fr", "en"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/lang/help.%s.json" % lang))
		check("%s : tableau de sujets" % lang, data is Array and data.size() == 27)
		var ids := []
		for x in data:
			ids.append(x.id)
			var r := RichTextLabel.new()
			r.bbcode_enabled = true
			r.text = str(x.text)
			add_child(r)
			check("%s/%s : BBCode lisible" % [lang, x.id], r.get_parsed_text().length() > 100)
			r.queue_free()
		check("%s : démarrage en premier" % lang, ids[0] == "demarrage")
		for id in ["parametres", "compte", "defis", "recompenses", "tchat", "editeur", "versions", "admin_en_ligne"]:
			check("%s : sujet %s" % [lang, id], ids.has(id))
		var in_chapters := 0
		for ch in GuideBook.CHAPTERS:
			for id in ch.ids:
				check("%s : sujet de chapitre %s existe" % [lang, id], ids.has(id))
				in_chapters += 1
		check("%s : tous les sujets sont rangés dans un chapitre" % lang, in_chapters == ids.size())
	TranslationServer.set_locale("fr")
	var g := GuideBook.open(host, "tchat")
	for i in 600:
		await get_tree().process_frame
		if g._ready_pages:
			break
	check("pagination terminée", g._ready_pages and g.pages.size() > 27)
	# fidélité : les pages d'un sujet, mises bout à bout, redonnent exactement son texte
	for ti in g.topics.size():
		var joined := []
		for p in g.pages:
			if int(p.topic) == ti:
				joined.append(str(p.text))
		check("sujet %s : pages fidèles au texte" % g.topics[ti].id, _plain("\n".join(joined)) == _plain(str(g.topics[ti].text)))
	check("ouvert sur le sujet demandé", g.page_no == int(g.first_page["tchat"]) and str(g._page_text.get_parsed_text()).contains("tchat"))
	var n0 := g.page_no
	g.go_page(n0 + 1)
	check("page suivante", g.page_no == n0 + 1)
	g.go_page(-5)
	check("première page : pas de précédente", g.page_no == 0 and g._prev.disabled)
	g.go_page(9999)
	check("dernière page : pas de suivante", g.page_no == g.pages.size() - 1 and g._next.disabled)
	g.goto_topic("combat")
	check("aller à un sujet", g.page_no == int(g.first_page["combat"]) and g._open_chapter == 1)
	g._search.text = "charte"
	g._on_search("charte")
	check("la recherche liste les sujets concernés", g._toc_box.get_child_count() >= 1 and g._toc_box.get_child(0) is Button)
	g.modal.close()
	# petit écran : sommaire en tiroir
	var g2 := GuideBook.open(host, "")
	for i in 600:
		await get_tree().process_frame
		if g2._ready_pages:
			break
	check("reprise à la dernière page lue", g2._ready_pages)
	g2.modal.close()
	# tutoriel de création : même présentation en livre
	var tg := GuideBook.open(host, "levels", "tutorial")
	for i in 600:
		await get_tree().process_frame
		if tg._ready_pages:
			break
	check("tutoriel : pagination terminée", tg._ready_pages and tg.topics.size() == 8)
	check("tutoriel : ouvert sur « Niveaux »", tg._ready_pages and tg.page_no == int(tg.first_page["levels"]))
	for ti in tg.topics.size():
		var j2 := []
		for p in tg.pages:
			if int(p.topic) == ti:
				j2.append(str(p.text))
		check("tutoriel %s : pages fidèles" % tg.topics[ti].id, _plain("\n".join(j2)) == _plain(str(tg.topics[ti].text)))
	tg.modal.close()
	# journal des versions : une version = un sujet, regroupées par dizaines
	var cg := GuideBook.open(host, "", "changelog")
	for i in 900:
		await get_tree().process_frame
		if cg._ready_pages:
			break
	var nver: int = DocModal.load_data("changelog").size()
	check("journal : une rubrique par version", cg._ready_pages and cg.topics.size() == nver and nver > 100)
	check("journal : ouvert sur la version la plus récente", cg._ready_pages and cg.page_no == 0 and str(cg.topics[0].id) == AppVersion.number())
	check("journal : plusieurs chapitres", cg.chapters.size() >= 5)
	var all_pages := ""
	for p in cg.pages:
		all_pages += _plain(str(p.text)) + " "
	var all_src := ""
	for t in cg.topics:
		all_src += _plain(str(t.text)) + " "
	check("journal : aucune ligne perdue", _plain(all_pages) == _plain(all_src))
	cg.modal.close()
	print("check_guide : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
