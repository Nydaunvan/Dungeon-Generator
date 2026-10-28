class_name LogPanel
extends PanelContainer
## Carnet : journal de partie (suit GameState.log_lines) sur un fond de parchemin sobre — le seul élément clair de l'interface,
## réservé au récit. Texte sombre en Spectral, sous-titre en Cinzel.

const PAPER_TOP := Color("cfc09f")
const PAPER_BOTTOM := Color("b3a17d")
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
	# grain du papier (bruit doux) et bords assombris, pour un vrai parchemin sans grosse image
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	var grain := TextureRect.new()
	grain.texture = nt
	grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grain.stretch_mode = TextureRect.STRETCH_SCALE
	grain.modulate = Color(0.45, 0.32, 0.15, 0.10)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grain)
	var g := Gradient.new()
	g.set_color(0, Color(0.3, 0.2, 0.08, 0.0))
	g.set_color(1, Color(0.28, 0.18, 0.07, 0.35))
	g.set_offset(0, 0.55)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 128
	gt.height = 128
	var burn := TextureRect.new()
	burn.texture = gt
	burn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burn.stretch_mode = TextureRect.STRETCH_SCALE
	burn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(burn)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var head := Label.new()
	head.text = "◆  " + L.t("ui.atlas.journal").to_upper()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_theme_font_override("font", Atlas.title_font(true, 1))
	head.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.6)))
	head.add_theme_color_override("font_color", Color("4a3720"))
	col.add_child(head)
	var rule := Control.new()
	rule.custom_minimum_size = Vector2(0, 6)
	rule.draw.connect(func():
		rule.draw_line(Vector2(0, 3), Vector2(rule.size.x, 3), Color("6b5638"), 1.0, true))
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
	var safe := "✦  " + line.replace("[", "[lb]")
	if player_hit:
		text.append_text("[color=%s][b]%s[/b][/color]\n" % [INK_HIT, safe])
	else:
		text.append_text("[color=%s]%s[/color]\n" % [INK, safe])
