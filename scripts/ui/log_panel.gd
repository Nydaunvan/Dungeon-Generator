class_name LogPanel
extends PanelContainer
## Journal de partie (suit GameState.log_lines), dans un cadre encastré.

var text: RichTextLabel

func setup(gs: GameState) -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 30)
	add_theme_stylebox_override("panel", UiTheme.tbox("inset", [8, 8, 8, 8], [10, 8, 10, 8]))
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_following = true
	# ≈ 14 px en paysage (0,78 rem), un peu moins en portrait où l'échelle est déjà relevée (le 0,9 rem d'avant était trop gros)
	text.add_theme_font_size_override("normal_font_size", int(UiMetrics.rem(0.7 if UiMetrics.portrait else 0.78)))
	add_child(text)
	for l in gs.log_lines:
		_add(l, false)
	gs.log_added.connect(_add)

func _add(line: String, player_hit: bool) -> void:
	var col := "#f5ecd8" if player_hit else "#c9b990"
	text.append_text("[color=%s]%s[/color]\n" % [col, line.replace("[", "[lb]")])
