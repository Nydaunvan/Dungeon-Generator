class_name InitiativeBar
extends HBoxContainer
## Chaîne d'initiative : ordre des prochaines actions (combat), premier entouré d'or.

var gs: GameState
var ctrl: CombatController
var _sig: String = ""
var icon_size: float = 40.0

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.changed.connect(rebuild)

func _process(_d: float) -> void:
	if ctrl != null and ctrl.combat != null and ctrl.in_combat():
		rebuild()

func rebuild() -> void:
	var keys: Array = []
	if ctrl.combat != null and ctrl.in_combat():
		keys = ctrl.combat.upcoming(12)
	var sig := ",".join(keys)
	if sig == _sig:
		return
	_sig = sig
	for ch in get_children():
		ch.queue_free()
	for i in keys.size():
		var key: String = keys[i]
		var tex: Texture2D = null
		var ring := UiTheme.BRONZE
		if key.begins_with("char_"):
			var c := gs.char_by_id(key.substr(5))
			if c.is_empty():
				continue
			var pp := IconResolver.portrait_path(c, gs.cfg)
			tex = load(pp) if pp != "" else null
			ring = UiTheme.HP_GREEN
		else:
			var rest := key.substr(4)
			var mid := rest.split("#")[0]
			var def := ctrl.combat.monster_def(mid)
			tex = IconResolver.texture(str(def.get("icon", "")))
			ring = UiTheme.RED
		if i == 0:
			ring = UiTheme.GOLD
		add_child(UiTheme.portrait(tex, ring, icon_size + (8 if i == 0 else 0)))
