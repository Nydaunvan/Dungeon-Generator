class_name CreditsRoll
extends Control
## Générique de fin : texte centré qui défile de bas en haut sur fond sombre, avec sa musique.
## Se ferme par un clic, Échap, la croix, ou tout seul à la fin du défilement.

const URL_RE := "https?://\\S+"

var _col: VBoxContainer
var _t: float = 0.0
var _travel: float = 0.0
var _speed: float = 60.0
var _end_hold: float = 0.0
var _closing: bool = false

static func open(host: Node) -> CreditsRoll:
	var c := CreditsRoll.new()
	host.add_child(c)
	return c

func _ready() -> void:
	add_to_group("modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.shared()
	clip_contents = true
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.012, 0.01, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_build_text()
	var hint := Label.new()
	hint.text = L.t("ui.credits.fermer_indice")
	hint.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	hint.add_theme_font_size_override("font_size", int(UiMetrics.css(13.0)))
	hint.add_theme_color_override("font_color", Color("6f5e44"))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.offset_top = -UiMetrics.css(30.0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_font_size_override("font_size", int(UiMetrics.css(24.0)))
	x.add_theme_color_override("font_color", Color("cbb083"))
	x.add_theme_color_override("font_hover_color", Color("f6e4bd"))
	x.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	x.offset_left = -UiMetrics.css(56.0)
	x.offset_top = UiMetrics.css(10.0)
	x.offset_right = -UiMetrics.css(10.0)
	x.offset_bottom = UiMetrics.css(54.0)
	x.pressed.connect(close)
	add_child(x)
	Sound.credits_music(true)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	call_deferred("_start_roll")

func _exit_tree() -> void:
	Sound.credits_music(false)

func _label(text: String, size: int, color: Color, font: String = UiTheme.F_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiTheme.font(font))
	l.add_theme_font_size_override("font_size", int(UiMetrics.css(float(size))))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _space(px: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, UiMetrics.css(px))
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(s)

func _build_text() -> void:
	var vp := get_viewport_rect().size
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", int(UiMetrics.css(8.0)))
	_col.custom_minimum_size.x = minf(UiMetrics.css(760.0), vp.x - 40.0)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)
	var gold := Color("e6c98a")
	var parch := Color("efe1c2")
	_col.add_child(_label(L.t("ui.credits.titre"), 64, gold, UiTheme.F_DISPLAY_BOLD))
	_space(36)
	_col.add_child(_label(L.t("ui.credits.par"), 30, parch, UiTheme.F_DISPLAY))
	_space(70)
	_col.add_child(_label(L.t("ui.credits.fait_avec"), 24, parch))
	_space(70)
	_col.add_child(_label(L.t("ui.credits.annee"), 34, gold, UiTheme.F_DISPLAY_BOLD))
	_space(110)
	_col.add_child(_label(L.t("ui.credits.merci_1"), 24, parch))
	_space(20)
	_col.add_child(_label(L.t("ui.credits.merci_2"), 24, parch))
	_space(110)
	_col.add_child(_about())
	_space(90)
	var cc := _label(L.t("ui.credits.modele_3d"), 20, parch)
	cc.modulate = Color(1, 1, 1, 0.85)
	_col.add_child(cc)
	_space(130)
	_col.add_child(_label(L.t("ui.credits.merci_fans"), 40, gold, UiTheme.F_DISPLAY_BOLD))

## Paragraphe de présentation : l'adresse est cliquable.
func _about() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	var fs := int(UiMetrics.css(22.0))
	r.add_theme_font_override("normal_font", UiTheme.font(UiTheme.F_BODY))
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_color_override("default_color", Color("efe1c2"))
	var rx := RegEx.create_from_string(URL_RE)
	var txt := L.t("ui.credits.a_propos")
	var out := ""
	var last := 0
	for m in rx.search_all(txt):
		out += txt.substr(last, m.get_start() - last).replace("[", "[lb]")
		out += "[color=#e6c98a][url=%s]%s[/url][/color]" % [m.get_string(), m.get_string()]
		last = m.get_end()
	out += txt.substr(last).replace("[", "[lb]")
	r.text = "[center]%s[/center]" % out
	r.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	r.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return r

func _start_roll() -> void:
	var vp := get_viewport_rect().size
	_col.size = Vector2(_col.custom_minimum_size.x, 0)
	var h := _col.get_combined_minimum_size().y
	_col.size = Vector2(_col.custom_minimum_size.x, h)
	_col.position = Vector2((vp.x - _col.size.x) * 0.5, vp.y)
	_travel = vp.y + h + UiMetrics.css(40.0)
	_speed = vp.y / 15.0   # un écran toutes les ~15 s : allure d'un générique de film
	_t = 0.0

func _process(delta: float) -> void:
	if _closing or _travel <= 0.0:
		return
	_t += delta
	var vp := get_viewport_rect().size
	_col.position.y = vp.y - _t * _speed
	_col.position.x = (vp.x - _col.size.x) * 0.5
	if _t * _speed >= _travel:
		_end_hold += delta
		if _end_hold >= 0.8:
			close()

func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		close()
	elif event is InputEventScreenTouch and event.pressed:
		close()

func _input(event: InputEvent) -> void:
	if not _closing and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
