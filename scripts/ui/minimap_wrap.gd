class_name MinimapWrap
extends PanelContainer
## Cadre de la mini-carte (.minimap-wrap) : fond #0b0907, bordure noire 2 px, liseré bronze, 170 px CSS de large au plus,
## hauteur suivant les proportions de la vue.

var minimap: Minimap
var _pad: float = 6.0

func _init() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiMetrics.register(self)
	rescale()

func rescale() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b0907")
	sb.border_color = Color("070504")
	sb.set_border_width_all(maxi(1, roundi(UiMetrics.css(2.0))))
	sb.set_corner_radius_all(int(UiMetrics.css(2.0)))
	sb.set_content_margin_all(UiMetrics.css(6.0))
	sb.shadow_color = Color("4a3a28")
	sb.shadow_size = maxi(1, roundi(UiMetrics.css(1.0)))
	sb.anti_aliasing = false
	add_theme_stylebox_override("panel", sb)
	_pad = UiMetrics.css(6.0 + 2.0)

func _process(_d: float) -> void:
	if minimap == null:
		return
	var avail := get_parent_area_size().x if get_parent() != null else 0.0
	var hr := get_viewport().get_visible_rect().size.y * UiMetrics.s
	var maxw := 170.0 if hr > 820.0 else (105.0 if hr > 650.0 else 80.0)   # @media (max-height:820px / 650px)
	var w := minf(UiMetrics.css(maxw), maxf(40.0, avail))
	var inner := w - _pad * 2.0
	custom_minimum_size = Vector2(w, inner / minimap.view_aspect() + _pad * 2.0)
