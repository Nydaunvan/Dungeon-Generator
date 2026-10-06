class_name SettingsModal
extends RefCounted
## Menu « ⚙ Paramètres » : Graphismes (niveaux Auto / Faible / Moyen / Élevé / Ultra / Personnalisé, adaptation automatique,
## options détaillées), Affichage, Son, Accessibilité et Diagnostic. Les valeurs vivent dans l'autoload `Settings`.

const TABS := [["graphics", "ui.settings.tab_graphics"], ["display", "ui.settings.tab_display"], ["sound", "ui.settings.tab_sound"],
	["access", "ui.settings.tab_access"], ["diag", "ui.settings.tab_diag"]]
const WIDTH := 700.0

# choix proposés pour chaque option graphique (valeur, clé de texte ou libellé)
const RES_VALUES := [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.25]
const PARTICLE_VALUES := [0.25, 0.4, 0.55, 0.7, 1.0, 1.5]
const DISTANCE_VALUES := [["0.7", "short"], ["0.85", "medium"], ["1.0", "normal"], ["1.3", "long"]]
const TORCH_VALUES := [1, 2, 3, 4, 5, 6, 7]
const MSAA_VALUES := [0, 2, 4]
const ANISO_VALUES := [0, 2, 4, 8, 16]
const FLAME_VALUES := [20, 30, 60]

var _m: Modal
var _body: VBoxContainer
var _tab := "graphics"
var _tab_buttons: Dictionary = {}
var _timer: Timer
var _live: Dictionary = {}     # libellés de l'onglet Diagnostic mis à jour en direct

static func open(host: Node, tab: String = "graphics") -> Modal:
	return SettingsModal.new()._build(host, tab)

func _build(host: Node, tab: String) -> Modal:
	_m = Modal.open(host, L.t("ui.settings.title"), WIDTH)
	_m.set_meta("settings_ctl", self)      # garde ce contrôleur en vie tant que la fenêtre existe
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	_m.content.add_child(tabs)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = L.t(t[1])
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = t[0] == tab
		var id: String = t[0]
		b.pressed.connect(func(): _show(id))
		tabs.add_child(b)
		_tab_buttons[id] = b
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m.content.add_child(_body)
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.timeout.connect(_tick)
	_m.add_child(_timer)
	_show(tab)
	_m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): _m.close()}])
	return _m

func _show(tab: String) -> void:
	_tab = tab
	_live = {}
	_timer.stop()
	for ch in _body.get_children():
		_body.remove_child(ch)
		ch.queue_free()
	match tab:
		"display": _display()
		"sound": SoundModal.fill(_body)
		"access": _access()
		"diag": _diag()
		_: _graphics()
	_m.call_deferred("_fit")

## Reconstruit l'onglet après un changement (hors de l'événement en cours : la liste déroulante se referme d'abord).
func _refresh() -> void:
	call_deferred("_show", _tab)

# ------------------------------------------------------------------ éléments communs

func _section(text: String) -> void:
	_body.add_child(AdminUtil.label(text, 16, UiTheme.GOLD))

func _hint(text: String) -> Label:
	var l := AdminUtil.label(text, 13, UiTheme.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(220, 0)
	_body.add_child(l)
	return l

func _row(text: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := AdminUtil.label(text, 14, UiTheme.PARCH)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	h.add_child(control)
	_body.add_child(h)
	return h

func _check(text: String, on: bool, cb: Callable, disabled: bool = false) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.disabled = disabled
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	_body.add_child(c)
	return c

func _drop(options: Array, current: Variant, cb: Callable, disabled: bool = false) -> OptionButton:
	var o := AdminUtil.dropdown(options, current, cb, 190.0)
	o.disabled = disabled
	return o

func _kv(key: String, value: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var k := AdminUtil.label(key, 14, UiTheme.DIM)
	k.custom_minimum_size = Vector2(120, 0)
	row.add_child(k)
	var v := AdminUtil.label(value, 14, UiTheme.PARCH)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.custom_minimum_size = Vector2(140, 0)
	row.add_child(v)
	_body.add_child(row)
	return v

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_body.add_child(b)
	return b

# ------------------------------------------------------------------ Graphismes

func _graphics() -> void:
	var custom: bool = Settings.preset == "custom"
	_section(L.t("ui.settings.quality_title"))
	var flow := AdminUtil.flow(_body)
	var group := ButtonGroup.new()
	for p in Settings.PRESET_IDS:
		var b := Button.new()
		b.text = Settings.preset_name(p)
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = p == Settings.preset
		var id: String = p
		b.pressed.connect(func():
			Settings.set_preset(id)
			_refresh())
		flow.add_child(b)
	_hint(L.t("ui.settings.preset_hint_%s" % Settings.preset))
	var lvl := Settings.level_name("custom" if custom else Settings.level)
	if Settings.dyn_scale < 0.999 and not custom:
		_hint(L.t("ui.settings.current_level_dyn") % [lvl, roundi(Settings.dyn_scale * 100.0)])
	else:
		_hint(L.t("ui.settings.current_level") % lvl)

	_section(L.t("ui.settings.adapt_title"))
	_check(L.t("ui.settings.adapt_check"), Settings.auto_adapt, func(v: bool):
		Settings.set_auto_adapt(v)
		_refresh(), custom)
	_hint(L.t("ui.settings.adapt_unavailable") if custom else L.t("ui.settings.adapt_hint"))
	_row(L.t("ui.settings.adapt_target"), _drop([[30, "30"], [45, "45"], [60, "60"]], Settings.target_fps,
		func(v): Settings.set_target_fps(int(v)), custom or not Settings.auto_adapt))

	_section(L.t("ui.settings.details_title"))
	var res_opts: Array = []
	for v in RES_VALUES:
		res_opts.append([v, "%d %%" % roundi(v * 100.0)])
	_row(L.t("ui.settings.opt_res_scale"), _opt("res_scale", res_opts))
	var msaa_opts: Array = []
	for v in MSAA_VALUES:
		msaa_opts.append([v, L.t("ui.settings.off") if v == 0 else "%d×" % v])
	_row(L.t("ui.settings.opt_msaa"), _opt("msaa", msaa_opts))
	var aniso_opts: Array = []
	for v in ANISO_VALUES:
		aniso_opts.append([v, L.t("ui.settings.off") if v == 0 else "%d×" % v])
	_row(L.t("ui.settings.opt_aniso"), _opt("aniso", aniso_opts))
	var torch_opts: Array = []
	for v in TORCH_VALUES:
		torch_opts.append([v, str(v)])
	_row(L.t("ui.settings.opt_torch_lights"), _opt("torch_lights", torch_opts))
	var part_opts: Array = []
	for v in PARTICLE_VALUES:
		part_opts.append([v, "%d %%" % roundi(v * 100.0)])
	_row(L.t("ui.settings.opt_particles"), _opt("particles", part_opts))
	_row(L.t("ui.settings.opt_spell_lamps"), _opt("spell_lamps", [[false, L.t("ui.settings.off")], [true, L.t("ui.settings.on")]]))
	var dist_opts: Array = []
	for d in DISTANCE_VALUES:
		dist_opts.append([float(d[0]), L.t("ui.settings.dist_%s" % d[1])])
	_row(L.t("ui.settings.opt_view_distance"), _opt("view_distance", dist_opts))
	_row(L.t("ui.settings.opt_texture_hd"), _opt("texture_hd", [[false, L.t("ui.settings.tex_standard")], [true, L.t("ui.settings.tex_high")]]))
	_hint(L.t("ui.settings.tex_note"))
	var flame_opts: Array = []
	for v in FLAME_VALUES:
		flame_opts.append([v, L.t("ui.settings.fps_unit") % v])
	_row(L.t("ui.settings.opt_flame_fps"), _opt("flame_fps", flame_opts))

func _opt(key: String, options: Array) -> OptionButton:
	return _drop(options, Settings.opt(key), func(v):
		Settings.set_option(key, v)
		_refresh())

# ------------------------------------------------------------------ Affichage

func _display() -> void:
	_section(L.t("ui.settings.tab_display"))
	if Settings.is_web():
		_hint(L.t("ui.settings.display_web_note"))
		return
	_row(L.t("ui.settings.win_mode"), _drop([[1, L.t("ui.settings.win_full")], [0, L.t("ui.settings.win_windowed")]],
		1 if Settings.is_fullscreen() else 0, func(v): Settings.set_fullscreen(int(v) == 1)))
	_hint(L.t("ui.settings.win_hint"))
	_check(L.t("ui.settings.vsync"), Settings.vsync, func(v: bool): Settings.set_vsync(v))
	var cap_opts: Array = []
	for v in Settings.FPS_CAPS:
		cap_opts.append([v, L.t("ui.settings.unlimited") if v == 0 else L.t("ui.settings.fps_unit") % v])
	_row(L.t("ui.settings.fps_cap"), _drop(cap_opts, Settings.fps_cap, func(v): Settings.set_fps_cap(int(v))))
	_hint(L.t("ui.settings.fps_cap_hint"))

# ------------------------------------------------------------------ Accessibilité

func _access() -> void:
	_section(L.t("ui.settings.tab_access"))
	_check(L.t("ui.settings.reduced_motion"), Settings.reduced_motion, func(v: bool): Settings.set_reduced_motion(v))
	_hint(L.t("ui.settings.reduced_motion_hint"))

# ------------------------------------------------------------------ Diagnostic

func _diag() -> void:
	var info: Dictionary = Settings.detect_info
	_section(L.t("ui.settings.diag_machine"))
	var gpu := str(info.get("gpu", ""))
	_kv(L.t("ui.settings.diag_gpu"), gpu if gpu != "" else L.t("ui.settings.unknown"))
	_kv(L.t("ui.settings.diag_renderer"), L.t("ui.settings.renderer_compat") if RenderingServer.get_current_rendering_method() == "gl_compatibility" else RenderingServer.get_current_rendering_method())
	_kv(L.t("ui.settings.diag_platform"), L.t("ui.settings.platform_%s" % str(info.get("platform", "pc"))))
	var ram := float(info.get("ram_gb", 0.0))
	_kv(L.t("ui.settings.diag_ram"), L.t("ui.settings.ram_value") % ram if ram > 0.0 else L.t("ui.settings.unknown"))
	_kv(L.t("ui.settings.diag_cpus"), str(info.get("cpus", 0)))
	_kv(L.t("ui.settings.diag_detected"), Settings.level_name(str(info.get("level", "medium"))))

	_section(L.t("ui.settings.diag_live"))
	_live["fps"] = _kv(L.t("ui.settings.diag_fps"), "")
	_live["level"] = _kv(L.t("ui.settings.diag_level"), "")
	_live["res"] = _kv(L.t("ui.settings.diag_res"), "")
	_live["calib"] = _kv(L.t("ui.settings.diag_calib"), "")
	_live["last"] = _kv(L.t("ui.settings.diag_last"), "")
	_tick()
	_timer.start()

	_check(L.t("ui.settings.diag_perf"), PerfOverlay.is_on(), func(v: bool):
		if v != PerfOverlay.is_on():
			PerfOverlay.toggle())
	_button(L.t("ui.settings.btn_redetect"), func():
		Settings.redetect()
		_refresh())
	_button(L.t("ui.settings.btn_reset"), func():
		Settings.reset_graphics()
		_refresh())

func _tick() -> void:
	if _live.is_empty() or not is_instance_valid(_live.get("fps")):
		return
	(_live.fps as Label).text = "%d" % roundi(Engine.get_frames_per_second())
	(_live.level as Label).text = Settings.level_name("custom" if Settings.preset == "custom" else Settings.level)
	(_live.res as Label).text = "%d %%" % roundi(Settings.res_scale() * 100.0)
	(_live.calib as Label).text = Settings.calib_text()
	(_live.last as Label).text = _event_text()

func _event_text() -> String:
	var e: Dictionary = Settings.last_event
	if e.is_empty():
		return L.t("ui.settings.diag_none")
	return "%s · %s" % [e.get("time", ""), L.f("ui.settings.event_%s" % str(e.get("reason", "down")), {"level": Settings.level_name(str(e.get("level", "")))})]
