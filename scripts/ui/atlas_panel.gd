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
	_box.fill_top = Color("151a18")
	_box.fill_bottom = Atlas.OBSIDIAN
	_box.border = Atlas.COPPER_DIM
	_box.cut = 9.0
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
		sep.color = Color(Atlas.COPPER, 0.35)
		sep.custom_minimum_size = Vector2(0, 1)
		_v.add_child(sep)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	_v.add_child(body)

func _draw() -> void:
	if not ornament or header_row == null:
		return
	# petit losange sur le filet cuivre, en haut à droite : repère de cartographie
	var p := Vector2(size.x - 18.0, 0.0)
	Atlas.draw_diamond(self, p + Vector2(0, 0.5), 3.0, Atlas.COPPER)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
