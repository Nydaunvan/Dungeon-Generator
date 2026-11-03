class_name LivingIntro
extends RefCounted
## Présentation guidée « Comment ça marche » des compétences vivantes : 4 pages (affinité, tempérament, évolutions, geste signature).
## S'ouvre une seule fois à la première progression, puis à la demande (fiche, bouton « ? », Paramètres).

const PAGES := ["affinity", "temper", "evo", "sig"]
const FLAMES := ["🕯", "🕯", "✦", "✧"]

var modal: GothicModal
var page := 0

static func open(host: Node) -> LivingIntro:
	var m := LivingIntro.new()
	m.modal = GothicModal.open(host, L.t("ui.living.intro_title"), 520)
	m.modal.help_topic = "vivantes"
	Settings.set_living_intro_seen(true)
	m._render()
	return m

func _render() -> void:
	for n in modal.content.get_children():
		n.queue_free()
	var id: String = PAGES[page]
	var head := Label.new()
	head.text = "%s  %s" % [FLAMES[page], L.t("ui.living.intro_%s_t" % id)]
	head.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", UiTheme.GOLD)
	modal.content.add_child(head)
	var line := ColorRect.new()
	line.color = UiTheme.BRONZE_DARK
	line.custom_minimum_size = Vector2(0, 1)
	modal.content.add_child(line)
	for suffix in ["a", "b", "c"]:
		var key := "ui.living.intro_%s_%s" % [id, suffix]
		if L.t(key) == key:
			continue
		var l := Label.new()
		l.text = L.t(key)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", UiTheme.PARCH if suffix != "c" else UiTheme.DIM)
		if suffix == "c":
			l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
		modal.content.add_child(l)
	var dots := Label.new()
	dots.text = "  ".join(PAGES.map(func(p): return "●" if p == id else "○"))
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.add_theme_color_override("font_color", UiTheme.GOLD)
	modal.content.add_child(dots)
	var specs: Array = []
	if page > 0:
		specs.append({"text": L.t("ui.living.intro_prev"), "cb": func():
			page -= 1
			_render()})
	if page < PAGES.size() - 1:
		specs.append({"text": L.t("ui.living.intro_next"), "cb": func():
			page += 1
			_render()})
	else:
		specs.append({"text": L.t("ui.living.intro_done"), "cb": func(): modal.close()})
	modal.set_buttons(specs, true)
