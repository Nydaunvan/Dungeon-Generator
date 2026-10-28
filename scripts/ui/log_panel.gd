class_name LogPanel
extends PanelContainer
## Carnet : journal de partie (suit GameState.log_lines) sur un fond de parchemin sobre — le seul élément clair de l'interface,
## réservé au récit. Texte sombre en Spectral, sous-titre en Cinzel.

const PAPER_TOP := Color("cdbd96")
const PAPER_BOTTOM := Color("b9a67c")
const INK := "#2b2014"
const INK_HIT := "#6a1d12"

var text: RichTextLabel

func setup(gs: GameState) -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 30)
	var sb := AtlasBox.new(UiMetrics.css(10.0))
	sb.fill_top = PAPER_TOP
	sb.fill_bottom = PAPER_BOTTOM
	sb.border = Color("6b5638")
	sb.cut = 6.0
	sb.corners = Vector4(0, 1, 0, 1)
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var head := Label.new()
	head.text = L.t("ui.atlas.journal").to_upper()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", Atlas.title_font(true, 1))
	head.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.6)))
	head.add_theme_color_override("font_color", Color("4a3720"))
	col.add_child(head)
	var rule := Control.new()
	rule.custom_minimum_size = Vector2(0, 6)
	rule.draw.connect(func():
		Atlas.draw_rule(rule, Vector2(0, 3), Vector2(rule.size.x, 3), Color("7a6342"), 1.0, true))
	col.add_child(rule)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_following = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", Atlas.font(Atlas.F_BODY_MED))
	text.add_theme_font_override("bold_font", Atlas.font(Atlas.F_BODY_BOLD))
	text.add_theme_color_override("default_color", Color(INK))
	# ≈ 14 px en paysage (0,78 rem), un peu moins en portrait où l'échelle est déjà relevée
	text.add_theme_font_size_override("normal_font_size", int(UiMetrics.rem(0.7 if UiMetrics.portrait else 0.78)))
	col.add_child(text)
	for l in gs.log_lines:
		_add(l, false)
	gs.log_added.connect(_add)

func _add(line: String, player_hit: bool) -> void:
	var safe := line.replace("[", "[lb]")
	if player_hit:
		text.append_text("[color=%s][b]%s[/b][/color]\n" % [INK_HIT, safe])
	else:
		text.append_text("[color=%s]%s[/color]\n" % [INK, safe])
