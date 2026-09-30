class_name HangChain
extends Control
## Chaîne + crâne suspendus (« hang » de l'original : 48×120 px CSS, pivot en haut au centre, balancement ±3,5° sur 5 s).

var _tex: TextureRect
var _t: float = 0.0
var anchor_offset := Vector2(6, -12)   # px CSS (converti dans rescale)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	top_level = true
	_tex = TextureRect.new()
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_tex)
	UiMetrics.register(self)
	rescale()

func rescale() -> void:
	anchor_offset = UiMetrics.design_size(Vector2(6, -12))
	var sz := UiMetrics.design_size(Vector2(48, 120))
	custom_minimum_size = sz
	size = sz
	_tex.texture = UiMetrics.tex("hang", Vector2(48, 120))
	_tex.size = sz
	_tex.pivot_offset = Vector2(sz.x * 0.5, 0)

func _process(d: float) -> void:
	var par := get_parent() as Control
	if par != null:
		global_position = par.global_position + anchor_offset
	visible = par != null and par.is_visible_in_tree()
	_t += d
	# ease-in-out entre -3,5° et +3,5° sur un cycle de 5 s
	_tex.rotation_degrees = -3.5 * cos(_t * TAU / 5.0)
