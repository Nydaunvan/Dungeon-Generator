class_name CombatBanner
extends PanelContainer
## Plaque du monstre engagé, collée au bord haut de la vue (« ⚔ Rat »). Un clic ouvre sa fiche ; la partie est en pause tant qu'elle est ouverte.

signal pressed(def: Dictionary, st: Dictionary)
var ctrl: CombatController
var _label: Label
var _normal: StyleBoxFlat
var _hover: StyleBoxFlat

func setup(controller: CombatController) -> void:
	ctrl = controller
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = L.t("ui.combat_banner.voir_la_fiche_du_monstre")
	_normal = _style(Color("2a0e0a"))
	_hover = _style(Color("3d140e"))
	add_theme_stylebox_override("panel", _normal)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	_label.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.82)))
	_label.add_theme_color_override("font_color", Color("ffd88a"))
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	mouse_entered.connect(func(): add_theme_stylebox_override("panel", _hover))
	mouse_exited.connect(func(): add_theme_stylebox_override("panel", _normal))

func _style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color("070504")
	var b := maxi(1, roundi(UiMetrics.css(2.0)))
	sb.border_width_left = b
	sb.border_width_right = b
	sb.border_width_bottom = b
	sb.corner_radius_bottom_left = int(UiMetrics.css(4.0))
	sb.corner_radius_bottom_right = int(UiMetrics.css(4.0))
	sb.content_margin_left = UiMetrics.css(18.0)
	sb.content_margin_right = UiMetrics.css(18.0)
	sb.content_margin_top = UiMetrics.css(5.0)
	sb.content_margin_bottom = UiMetrics.css(6.0)
	sb.shadow_color = Color(0, 0, 0, 0.8)
	sb.shadow_size = int(UiMetrics.css(5.0))
	sb.shadow_offset = Vector2(0, UiMetrics.css(4.0))
	return sb

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var eng := ctrl.combat.engaged()
		if not eng.is_empty():
			pressed.emit(eng.monster, ctrl.combat.lstate().monsters[str(eng.monster.id)])

func _process(_d: float) -> void:
	var on := ctrl != null and ctrl.combat != null and ctrl.in_combat()
	visible = on
	if not on:
		return
	var eng := ctrl.combat.engaged()
	if eng.is_empty():
		return
	var def: Dictionary = eng.monster
	var st: Dictionary = ctrl.combat.lstate().monsters[str(def.id)]
	var nm := str(def.get("name", "Monstre")) + (" (Boss)" if bool(def.get("isBoss", false)) else "")
	_label.text = "⚔️ " + nm + ("  😡" if st.get("enraged", false) else "")
