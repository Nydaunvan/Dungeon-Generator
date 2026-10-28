class_name AtlasPanel
extends PanelContainer
## Panneau Atlas Noir : surface obsidienne, filet cuivre à angles coupés, titre en Cinzel (icône + capitales espacées) et filet de séparation.
## Même interface que l'ancien `OrnatePanel` (`body`, `header_row`, `title_label`) pour que les panneaux se remplacent sans rien toucher d'autre.

var body: VBoxContainer
var title_label: Label
var header_row: HBoxContainer
var medal: bool = false      # conservé pour compatibilité (sans effet)
var hooks: bool = false      # conservé pour compatibilité (sans effet)
var ornament: bool = true
var _box: AtlasBox
var _v: VBoxContainer

func _init(title: String = "", icon_name: String = "") -> void:
	_box = AtlasBox.new(10.0)
	# fond translucide : la vue 3D occupe toute la largeur de l'écran et se devine derrière les panneaux
	_box.fill_top = Color(0.035, 0.045, 0.05, 0.78)
	_box.fill_bottom = Color(0.02, 0.026, 0.03, 0.84)
	_box.border = Color(Atlas.COPPER, 0.55)
	_box.cut = 4.0
	_box.corners = Vector4(1, 0, 1, 0)
	_box.marks = Color(Atlas.COPPER, 0.7)
	add_theme_stylebox_override("panel", _box)
	clip_contents = false
	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 6)
	add_child(_v)
	if title != "":
		header_row = HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 8)
		_v.add_child(header_row)
		if icon_name != "" and GameIcons.has(icon_name):
			var ic := GameIcons.rect(icon_name, 16, Atlas.COPPER, 1.8)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			header_row.add_child(ic)
		title_label = Label.new()
		title_label.text = title.to_upper()
		title_label.add_theme_font_override("font", Atlas.title_font(false, 2))
		title_label.add_theme_font_size_override("font_size", 12)
		title_label.add_theme_color_override("font_color", Atlas.IVORY)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_label.clip_text = true
		header_row.add_child(title_label)
		var sep := ColorRect.new()
		sep.color = Color(Atlas.COPPER, 0.5)
		sep.custom_minimum_size = Vector2(0, 1)
		_v.add_child(sep)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	_v.add_child(body)

## Opacité du fond (0 = transparent) : la carte, à gauche, laisse voir la vue 3D derrière elle.
func set_fill_alpha(top: float, bottom: float) -> void:
	_box.fill_top.a = top
	_box.fill_bottom.a = bottom
	_box.emit_changed()

func _draw() -> void:
	if not ornament or header_row == null:
		return
	# petit losange sur le filet cuivre, en haut à droite : repère de cartographie
	var y := header_row.position.y + header_row.size.y * 0.5 + _v.position.y
	var x := size.x - 22.0
	draw_line(Vector2(x - 12.0, y), Vector2(x - 5.0, y), Color(Atlas.COPPER, 0.8), 1.0)
	Atlas.draw_diamond(self, Vector2(x, y), 3.0, Atlas.COPPER)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
