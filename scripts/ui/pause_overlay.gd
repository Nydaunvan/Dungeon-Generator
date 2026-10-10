class_name PauseOverlay
extends CanvasLayer
## Pause du jeu (outil de test : captures d'écran). Fige tout (arbre en pause) ; seul un petit bandeau discret reste, pour reprendre
## (clic, ou touche P / Échap). Refusée en partie classée : figer le jeu y donnerait du temps de réflexion gratuit.
## Reprend d'elle-même si la scène change.

static var _inst: PauseOverlay = null
var _scene: Node

## Met le jeu en pause ou le reprend. `tree` : l'arbre de scènes courant.
static func toggle(tree: SceneTree) -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst.resume()
		return
	if RunLog.ranked():
		Dialogs.notice(tree.current_scene, L.t("ui.pause.label"), L.t("ui.pause.ranked"))
		return
	var o := PauseOverlay.new()
	o.process_mode = Node.PROCESS_MODE_ALWAYS
	o.layer = 120
	o._scene = tree.current_scene
	tree.root.add_child(o)
	_inst = o
	tree.paused = true

static func active() -> bool:
	return _inst != null and is_instance_valid(_inst)

func _ready() -> void:
	var b := Button.new()
	b.text = "⏸  " + L.t("ui.pause.label") + "   ·   ▶ " + L.t("ui.pause.resume")
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0.55)
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 6)
	b.pressed.connect(resume)
	add_child(b)

func _process(_d: float) -> void:
	if get_tree().current_scene != _scene:
		resume()

func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_P or ev.keycode == KEY_ESCAPE):
		resume()
		get_viewport().set_input_as_handled()

func resume() -> void:
	if get_tree() != null:
		get_tree().paused = false
	if _inst == self:
		_inst = null
	queue_free()
