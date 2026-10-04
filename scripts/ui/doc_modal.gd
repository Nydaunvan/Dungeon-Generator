class_name DocModal
extends RefCounted
## Fenêtres de documentation : guide de l'aventurier, tutoriel de création et journal des versions.
## Les textes viennent de data/help.json, data/tutorial.json et data/changelog.json (extraits du jeu HTML).

static var _cache: Dictionary = {}

static func _load(name: String) -> Array:
	if not _cache.has(name):
		var f := FileAccess.open("res://data/%s.json" % name, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		_cache[name] = parsed if parsed is Array else []
	return _cache[name]

static func _rich(text: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(300, 0)
	r.add_theme_color_override("default_color", UiTheme.PARCH)
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_font_size_override("bold_font_size", 15)
	r.text = text
	return r

## Fenêtre à sujets : boutons de navigation en haut, texte en dessous.
static func topics(host: Node, title: String, data_name: String, start_id: String = "") -> Modal:
	var items := _load(data_name)
	var m := Modal.open(host, title, 780.0)
	var nav := HFlowContainer.new()
	nav.add_theme_constant_override("h_separation", 4)
	nav.add_theme_constant_override("v_separation", 4)
	m.content.add_child(nav)
	var doc := _rich("")
	m.content.add_child(doc)
	var group := ButtonGroup.new()
	var en: bool = TranslationServer.get_locale().begins_with("en")
	var show := func(i: int):
		doc.text = str(items[i].get("textEn", items[i].text)) if en else str(items[i].text)
		m.call_deferred("_fit")
	for i in items.size():
		var b := Button.new()
		b.text = str(items[i].get("labelEn", items[i].label)) if en else str(items[i].label)
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		var ix: int = i
		b.pressed.connect(func(): show.call(ix))
		nav.add_child(b)
		if (start_id == "" and i == 0) or str(items[i].id) == start_id:
			b.button_pressed = true
			show.call(i)
	m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): m.close()}])
	return m

static func guide(host: Node, start_id: String = "") -> Modal:
	return topics(host, L.t("ui.doc_modal.guide_de_l_aventurier"), "help", start_id)

static func tutorial(host: Node) -> Modal:
	return topics(host, L.t("common.tutoriel_de_creation"), "tutorial")

static func changelog(host: Node) -> Modal:
	var m := Modal.open(host, L.t("ui.doc_modal.journal_des_versions"), 720.0)
	var out := ""
	for e in _load("changelog"):
		out += "[font_size=18][color=#e8b45c]Version %s[/color][/font_size]\n" % str(e.version)
		for c in e.changes:
			var s := str(c)
			if s.begins_with("## "):
				out += "\n[b]%s[/b]\n" % s.substr(3)
			else:
				out += "  • %s\n" % s
		out += "\n"
	m.content.add_child(_rich(out))
	m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): m.close()}])
	return m
