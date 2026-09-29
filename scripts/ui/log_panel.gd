class_name LogPanel
extends RichTextLabel
## Journal de partie (suit GameState.log_lines).

func setup(gs: GameState) -> void:
	bbcode_enabled = true
	scroll_following = true
	fit_content = false
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 80)
	add_theme_font_size_override("normal_font_size", 14)
	for l in gs.log_lines:
		_add(l, false)
	gs.log_added.connect(_add)

func _add(text: String, player_hit: bool) -> void:
	var col := "#f5ecd8" if player_hit else "#c9b990"
	append_text("[color=%s]%s[/color]\n" % [col, text.replace("[", "[lb]")])
