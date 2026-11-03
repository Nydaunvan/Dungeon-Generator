class_name LivingIntro
extends RefCounted
## Présentation guidée « Comment ça marche » des compétences vivantes : 4 pages (affinité, tempérament, évolutions, geste signature).
## S'ouvre une seule fois à la première progression, puis à la demande (fiche, bouton « ? », Paramètres).

const PAGES := ["affinity", "temper", "evo", "sig"]
const FLAMES := ["🕯", "🕯", "✦", "✧"]

var modal: GothicModal
var page := 0
var _demo: Dictionary = {}          # héros, sort et fiche d'exemple (partie jetable : ne touche jamais à la vraie partie)

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
	_illustrate(id)
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

## Partie d'exemple, jetable : un sort offensif du premier héros avec une affinité, un tempérament et une évolution plausibles.
func _make_demo(aff: float, evolved: int) -> Dictionary:
	var cfg: Dictionary = (Data.original_config as Dictionary).duplicate(true)
	var gs := GameState.create(cfg)
	var hero: Dictionary = gs.party[0]
	var sp: Dictionary = {}
	for x in (cfg.spells as Array):
		if str(x.get("mode", "")) == "damage" and not LivingCatalog.profile(cfg, str(x.id)).is_empty():
			sp = x
			break
	if sp.is_empty():
		return {}
	var sid := str(sp.id)
	var prof := LivingCatalog.profile(cfg, sid)
	var sk := LivingSkills._sk(gs, LivingCatalog.key(str(hero.id), sid))
	sk.a = aff
	var br: Array = prof.get("branches", [])
	if br.size() > 0:
		sk.t[str(br[0].trait)] = 30
	if br.size() > 1:
		sk.t[str(br[1].trait)] = 12
	if evolved >= 1 and br.size() > 0:
		sk.e = str(br[0].kind)
	if evolved >= 2 and br.size() > 1:
		sk["e2"] = str(br[1].kind)
	var icon := str(sp.get("icon", "✨"))
	return {"desc": LivingSkills.describe(gs, str(hero.id), sid), "name": str(prof.get("name", "")),
		"tex": IconResolver.texture(icon) if icon.begins_with("@icon:") else null, "glyph": icon}

func _disc(tier: int, evos: int, alert: bool, caption: String, dm: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var d := SpellDisc.new()
	d.custom_minimum_size = Vector2(70, 74)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := str(dm.get("glyph", "✨"))
	d.set_state("" if dm.get("tex") != null else (glyph if not glyph.begins_with("@icon:") else "✨"), dm.get("tex"), "", 1.0)
	d.set_living(tier, evos, alert)
	box.add_child(d)
	var l := Label.new()
	l.text = caption
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiTheme.DIM)
	box.add_child(l)
	return box

func _disc_row(specs: Array, dm: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for sp in specs:
		row.add_child(_disc(int(sp[0]), int(sp[1]), bool(sp[2]), str(sp[3]), dm))
	modal.content.add_child(row)

func _bar(label: String, value: int, hot: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiTheme.GOLD if hot else UiTheme.DIM)
	h.add_child(l)
	var back := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = UiTheme.BRONZE_DARK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	back.add_theme_stylebox_override("panel", sb)
	back.custom_minimum_size = Vector2(0, 12)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = UiTheme.GOLD if hot else UiTheme.BRONZE_LIGHT
	fill.custom_minimum_size = Vector2(0, 8)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.add_child(fill)
	back.resized.connect(func(): fill.custom_minimum_size.x = maxf(0.0, (back.size.x - 4.0) * clampf(float(value) / 100.0, 0.0, 1.0)))
	h.add_child(back)
	var r := Label.new()
	r.text = str(value)
	r.custom_minimum_size = Vector2(36, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_theme_font_size_override("font_size", 13)
	r.add_theme_color_override("font_color", UiTheme.GOLD if hot else UiTheme.DIM)
	h.add_child(r)
	modal.content.add_child(h)

## Illustrations reprises de la fenêtre « Vie de la compétence » (frise, tempérament, arbre) et des disques de sorts.
func _illustrate(id: String) -> void:
	match id:
		"affinity":
			var dm := _make_demo(55.0, 0)
			_disc_row([[0, 0, false, L.t("ui.living.tier_0")], [1, 0, false, L.t("ui.living.tier_1")], [2, 0, false, L.t("ui.living.tier_2")],
				[3, 0, false, L.t("ui.living.tier_3")], [4, 0, false, L.t("ui.living.tier_4")]], dm)
			modal.content.add_child(LivingViz.timeline(55.0))
		"temper":
			var dm := _make_demo(40.0, 0)
			if dm.is_empty():
				return
			var tr_: Dictionary = dm.desc.traits
			for t in LivingCatalog.TRAITS:
				if tr_.has(t):
					_bar(L.t("ui.living.trait_%s" % t), int(tr_[t]), t == str(dm.desc.dominant))
			if str(dm.desc.dominant) != "":
				var dl := Label.new()
				dl.text = L.fa(L.t("ui.living.dominant"), L.t("ui.living.trait_%s" % str(dm.desc.dominant)))
				dl.add_theme_color_override("font_color", UiTheme.GOLD)
				modal.content.add_child(dl)
		"evo":
			var dm := _make_demo(60.0, 1)
			if dm.is_empty():
				return
			modal.content.add_child(LivingViz.tree(str(dm.name), dm.tex, dm.desc))
			_disc_row([[2, 0, true, L.t("ui.living.intro_cap_ready")], [3, 1, false, L.t("ui.living.intro_cap_ring")], [3, 1, true, L.t("ui.living.intro_cap_second")]], dm)
		"sig":
			var dm := _make_demo(88.0, 2)
			_disc_row([[4, 2, true, L.t("ui.living.intro_cap_sig")]], dm)
			var tip := Label.new()
			tip.text = L.t("ui.living.tip_sig")
			tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tip.add_theme_color_override("font_color", UiTheme.GOLD)
			modal.content.add_child(tip)
			modal.content.add_child(LivingViz.timeline(88.0))
