extends SceneTree
## Guide : tous les sujets (fr et en) s'ouvrent et se lisent, les nouveaux sujets existent, le démarrage vient en premier.
## Lancer (Xvfb requis) : xvfb-run -a godot --path . --script res://tools/check_guide.gd

var fails := 0

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func settle(frames: int = 20) -> void:
	for i in frames:
		await process_frame

func _init() -> void:
	await process_frame
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var DM: GDScript = load("res://scripts/ui/doc_modal.gd")
	for lang in ["fr", "en"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/lang/help.%s.json" % lang))
		check("%s : tableau de sujets" % lang, data is Array and data.size() == 27)
		var ids := []
		for x in data:
			ids.append(x.id)
			var r := RichTextLabel.new()
			r.bbcode_enabled = true
			r.text = str(x.text)
			root.add_child(r)
			check("%s/%s : BBCode lisible" % [lang, x.id], r.get_parsed_text().length() > 100)
			r.queue_free()
		check("%s : démarrage en premier" % lang, ids[0] == "demarrage")
		for id in ["parametres", "compte", "defis", "recompenses", "tchat", "editeur", "versions", "admin_en_ligne"]:
			check("%s : sujet %s" % [lang, id], ids.has(id))
	TranslationServer.set_locale("fr")
	var m = DM.guide(host, "tchat")
	await settle()
	var found := false
	for rt in m.find_children("*", "RichTextLabel", true, false):
		if (rt as RichTextLabel).get_parsed_text().contains("charte du tchat"):
			found = true
	check("guide ouvert sur le sujet demandé", found)
	m.close()
	print("check_guide : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
