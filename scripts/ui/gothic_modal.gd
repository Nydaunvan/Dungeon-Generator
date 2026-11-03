class_name GothicModal
extends Modal
## Fenêtre modale « Gothic Atlas Noir » : même interface que `Modal` (content, add_text, add_row, set_buttons, add_button, close, closed,
## esc_closes, fit_ratio), habillée par `GothicPanel`. Base de toutes les nouvelles fenêtres.

var gpanel: GothicPanel
## Sujet du guide expliqué par le « ? » de la fenêtre (« fenetres » par défaut : le style et les effets des fenêtres).
var help_topic: String = "fenetres"
var _sbar: GothicScrollBar

static func open(host: Node, title: String, width: float = 440.0) -> GothicModal:
	var m := GothicModal.new()
	m._width = width
	m._build(title)
	host.add_child(m)
	return m

func _build(title: String) -> void:
	Crumbs.mark("fenêtre gothic %s" % title)
	add_to_group("modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.gothic()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	gpanel = GothicPanel.new(title)
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	gpanel.custom_minimum_size = Vector2(minf(_width, vp.x - 24.0), 0)
	center.add_child(gpanel)
	var sbox := HBoxContainer.new()
	sbox.add_theme_constant_override("separation", 2)
	sbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gpanel.body.add_child(sbox)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sbox.add_child(_scroll)
	_sbar = GothicScrollBar.attach(_scroll)
	sbox.add_child(_sbar)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	_scroll.add_child(content)
	_buttons_row = VBoxContainer.new()
	gpanel.body.add_child(_buttons_row)
	gpanel.add_help_button(L.t("ui.gothic.help_tip"), _open_help)
	content.child_entered_tree.connect(func(_n: Node): call_deferred("_restyle"))
	call_deferred("_fit")
	call_deferred("_animate_in")

func _open_help() -> void:
	GuideBook.open(get_parent(), help_topic)

func _animate_in() -> void:
	# la fenêtre se déploie depuis le bas, avec un léger rebond
	var p: Control = gpanel
	p.pivot_offset = Vector2(p.size.x * 0.5, p.size.y)
	if Settings.reduced_motion:
		UiFx.pop_in(p, 0.1)
		return
	p.modulate.a = 0.0
	p.scale = Vector2(0.94, 0.9)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fit() -> void:
	var vp := get_viewport_rect().size
	var want := content.get_combined_minimum_size().y
	# la lancette consomme de la hauteur (arc, emblème, titre, boutons) : le corps défile pour que la fenêtre tienne à l'écran
	var overhead := gpanel.get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var cap := vp.y - 24.0 - maxf(overhead, 200.0)
	_scroll.custom_minimum_size = Vector2(0, minf(want, minf(cap, vp.y * fit_ratio)))
	gpanel.custom_minimum_size.x = minf(_width, vp.x - 24.0)
	_restyle()

func set_buttons(specs: Array, row: bool = false, stack: bool = false) -> void:
	super.set_buttons(specs, row, stack)
	_restyle()

func add_button(text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := super.add_button(text, cb, disabled)
	_restyle()
	return b

## Survol : léger gonflement et halo chaud (désactivé en mode « réduire les animations »).
static func hover_fx(b: Button) -> void:
	if Settings.reduced_motion:
		return
	b.mouse_entered.connect(func():
		if b.disabled:
			return
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2(1.02, 1.02), 0.12).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "modulate", Color(1.25, 1.12, 0.9), 0.12))
	b.mouse_exited.connect(func():
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12)
		tw.tween_property(b, "modulate", Color.WHITE, 0.12))

## Boutons du style de la page d'accueil (fond sombre, filet de cuivre, angles coupés, titres Cinzel, ambre au survol) : appliqué à
## tous les boutons de la fenêtre, y compris ceux que le contenu ajoute (les onglets à bascule gardent leur style).
func _restyle() -> void:
	if gpanel == null or not is_instance_valid(gpanel):
		return
	_restyle_node(gpanel)

func _restyle_node(n: Node) -> void:
	for c in n.get_children():
		if c is Button and not (c as Button).toggle_mode and not c.has_meta("gothic") and c != gpanel._help:
			_style_button(c as Button)
		_restyle_node(c)

func _style_button(b: Button) -> void:
	b.set_meta("gothic", true)
	var fc := b.get_theme_color("font_color")
	var kind := ""
	if b.has_theme_color_override("font_color"):
		if fc.is_equal_approx(Color("ffd88a")):
			kind = "accent"
		elif fc.is_equal_approx(Color("d9806a")):
			kind = "danger"
	Atlas.style_button(b, kind, 8.0)
	var fs := b.get_theme_font_size("font_size")
	b.add_theme_font_override("font", Atlas.title_font(false, 1))
	b.add_theme_font_size_override("font_size", maxi(13, fs - 1) if fs > 0 else 14)
	b.add_theme_color_override("font_color", Color("ffd88a") if kind == "accent" else (Color("d9806a") if kind == "danger" else Atlas.IVORY))
	b.add_theme_color_override("font_hover_color", Color("fff0c8") if kind != "danger" else Color("ff9d85"))
	b.add_theme_color_override("font_disabled_color", Color("7a6a50"))
	hover_fx(b)
