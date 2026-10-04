class_name SoundModal
extends RefCounted
## Réglage du son : activation, volume des effets et de la musique d'ambiance.

static func open(host: Node) -> Modal:
	var m := Modal.open(host, "🔊 Son", 380.0)
	var on := CheckButton.new()
	on.text = L.t("ui.sound_modal.son_active")
	on.button_pressed = Sound.enabled
	on.toggled.connect(func(v: bool):
		Sound.set_enabled(v)
		if v:
			Sound.sfx("pickup"))
	m.content.add_child(on)
	_slider(m, L.t("ui.sound_modal.effets_sonores"), Sound.sfx_volume, func(v: float):
		Sound.set_sfx_volume(v), func(): Sound.sfx("hit"))
	_slider(m, L.t("ui.sound_modal.musique_ambiance"), Sound.music_volume, func(v: float):
		Sound.set_music_volume(v), Callable())
	m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): m.close()}])
	return m

static func _slider(m: Modal, title: String, value: float, on_change: Callable, on_release: Callable) -> void:
	m.content.add_child(AdminUtil.label(title, 14, UiTheme.DIM))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(300, 28)
	s.value_changed.connect(on_change)
	if on_release.is_valid():
		s.drag_ended.connect(func(_c): on_release.call())
	m.content.add_child(s)
