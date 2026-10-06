extends CanvasLayer
## Compteur de performances en direct (images/s, RAM, mémoire vidéo) : bouton « 📊 » de l'en-tête ou touche F3.
## Le choix est mémorisé entre deux sessions (user://settings.cfg, via `Settings`).

var _label: Label
var _panel: PanelContainer
var _t := 0.0
var _on := false

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.border_color = Color("7a5a2c")
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color("e8dcc0"))
	_panel.add_child(_label)
	add_child(_panel)
	_on = Settings.perf_overlay
	_apply()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()

func is_on() -> bool:
	return _on

func toggle() -> void:
	_on = not _on
	Settings.set_perf_overlay(_on)
	_apply()

func _apply() -> void:
	_panel.visible = _on
	set_process(_on)
	if _on:
		_t = 0.0
		_refresh()

func _process(d: float) -> void:
	_t -= d
	if _t <= 0.0:
		_t = 0.5
		_refresh()

func _refresh() -> void:
	var fps := Engine.get_frames_per_second()
	var ram := float(OS.get_static_memory_usage()) / 1048576.0
	var vram := float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0
	var calls := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	_label.text = "FPS  %d\nRAM  %.0f Mo\nVRAM %.0f Mo\nDraw %d" % [fps, ram, vram, calls]
	_panel.reset_size()
	_panel.position = Vector2(8, get_viewport().get_visible_rect().size.y - _panel.size.y - 8)   # coin bas-gauche : ne masque ni l'en-tête ni la vue 3D
	_label.add_theme_color_override("font_color", Color("9be07a") if fps >= 55 else (Color("ffd98a") if fps >= 30 else Color("ff7a6a")))
