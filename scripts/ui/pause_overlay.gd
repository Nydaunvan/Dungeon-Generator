class_name PauseOverlay
extends CanvasLayer
## Pause du jeu (outil de test : captures d'écran). Fige tout (arbre en pause) ; un grand symbole ⏸ s'affiche au centre. On reprend
## par un clic n'importe où, ou avec P, Échap, Espace ou Entrée. Disponible dans tous les modes ; en partie classée / défi, le temps passé en pause est ajouté au temps de jeu du classement.
## Reprend d'elle-même si la scène change. Quoi qu'il arrive (fermeture comprise), l'arbre n'est jamais laissé en pause.

static var _inst: PauseOverlay = null
var _scene: Node
var _done := false
var _since_ms := 0

## Met le jeu en pause ou le reprend. `tree` : l'arbre de scènes courant.
static func toggle(tree: SceneTree) -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst.resume()
		return
	var o := PauseOverlay.new()
	o.process_mode = Node.PROCESS_MODE_ALWAYS
	o.layer = 120
	o._scene = tree.current_scene
	o._since_ms = Time.get_ticks_msec()
	tree.root.add_child(o)
	_inst = o
	tree.paused = true

static func active() -> bool:
	return _inst != null and is_instance_valid(_inst)

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP          # le clic ne traverse pas vers le jeu
	shade.gui_input.connect(_on_click)
	add_child(shade)
	# symbole « pause » dessiné (deux barres) : aucune dépendance à une police
	var box := CenterContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 22)
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bars)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.96, 0.9, 0.75, 0.9)
		bar.custom_minimum_size = Vector2(26, 96)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(bar)
	var lab := Label.new()
	lab.text = L.t("ui.pause.resume_hint")
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(0.96, 0.9, 0.75, 0.85))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(lab)

func _on_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		resume()
	elif ev is InputEventScreenTouch and ev.pressed:
		resume()

func _process(_d: float) -> void:
	if get_tree().current_scene != _scene:
		resume()

func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_P, KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		resume()

func resume() -> void:
	if _done:
		return
	_done = true
	_count_pause_time()
	if get_tree() != null:
		get_tree().paused = false
	if _inst == self:
		_inst = null
	queue_free()

## Parties classées et défis : le temps passé en pause compte dans le temps de jeu envoyé au classement (la pause ne fait pas gagner de secondes).
func _count_pause_time() -> void:
	if RunLog.ranked() and RunLog.gs != null:
		var secs := float(Time.get_ticks_msec() - _since_ms) / 1000.0
		RunLog.gs.stats["playSeconds"] = float(RunLog.gs.stats.get("playSeconds", 0.0)) + maxf(0.0, secs)

func _exit_tree() -> void:
	if not _done:
		_done = true
		_count_pause_time()
		if _inst == self:
			_inst = null
		if get_tree() != null:
			get_tree().paused = false
