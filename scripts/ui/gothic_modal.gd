class_name GothicModal
extends Modal
## Fenêtre modale « Gothic Atlas Noir » : même interface que `Modal` (content, add_text, add_row, set_buttons, add_button, close, closed,
## esc_closes, fit_ratio), habillée par `GothicPanel`. Base de toutes les nouvelles fenêtres.

var gpanel: GothicPanel

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
	theme = UiTheme.shared()
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
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gpanel.body.add_child(_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	_scroll.add_child(content)
	_buttons_row = VBoxContainer.new()
	gpanel.body.add_child(_buttons_row)
	call_deferred("_fit")
	call_deferred("_animate_in")

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

func set_buttons(specs: Array, row: bool = false, stack: bool = false) -> void:
	super.set_buttons(specs, row, stack)
	for b in _buttons_row.get_children():
		if b is Button:
			hover_fx(b)

func add_button(text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := super.add_button(text, cb, disabled)
	hover_fx(b)
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
