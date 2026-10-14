extends CanvasLayer
## Compteur de performances en direct (images/s, RAM, mémoire vidéo) : bouton « 📊 » de l'en-tête ou touche F3.
## Le choix est mémorisé entre deux sessions (user://settings.cfg, via `Settings`).

var _label: Label
var _t := 0.0
var _on := false

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	# une seule ligne, tout en haut à gauche, sans cadre ni fond : le texte porte son propre liseré sombre pour rester lisible
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(6, 2)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color("e8dcc0"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_on = Settings.perf_overlay
	_apply()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and Keybinds.matches("perf", e):
		toggle()
		get_viewport().set_input_as_handled()

func is_on() -> bool:
	return _on

func toggle() -> void:
	_on = not _on
	Settings.set_perf_overlay(_on)
	_apply()

func _apply() -> void:
	_label.visible = _on
	set_process(_on)
	if _on:
		_t = 0.0
		_fit()
		_refresh()

## Taille constante partout : celle de la scène de jeu (zone de conception 1600 x 1000), même au lancement et dans le menu d'accueil,
## où l'échelle de l'interface est différente. Le texte est donc compensé par le rapport entre les deux échelles.
func _fit() -> void:
	var win := get_window()
	var sz := Vector2(win.size)
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var f := maxf(win.content_scale_factor, 0.001)
	var g := f
	if sz.x >= sz.y * 1.05:      # paysage : facteur de la scène de jeu (voir Data._update_scale) ; en portrait, l'échelle est déjà la même
		g = minf(sz.x / Data.GAME_DESIGN.x, sz.y / Data.GAME_DESIGN.y) / minf(sz.x / 1280.0, sz.y / 720.0)
	var k := g / f
	_label.scale = Vector2.ONE * k
	_label.position = Vector2(6.0, 2.0) * k

func _process(d: float) -> void:
	_fit()
	_t -= d
	if _t <= 0.0:
		_t = 0.5
		_refresh()

func _refresh() -> void:
	var fps := Engine.get_frames_per_second()
	var ram := ProcMem.mb()
	var vram := float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0
	var calls := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var ram_txt := "%.0f Mo" % ram if ram > 0.0 else "…"          # « … » : première mesure en cours (Windows / macOS)
	_label.text = "FPS %d  ·  RAM %s  ·  VRAM %.0f Mo  ·  Draw %d" % [fps, ram_txt, vram, calls]
	_label.add_theme_color_override("font_color", Color("9be07a") if fps >= 55 else (Color("ffd98a") if fps >= 30 else Color("ff7a6a")))
