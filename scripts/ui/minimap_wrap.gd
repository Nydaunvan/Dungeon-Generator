class_name MinimapWrap
extends PanelContainer
## Cadre de la mini-carte (.minimap-wrap) : fond #0b0907, bordure noire 2 px, liseré bronze, 170 px CSS de large au plus,
## hauteur suivant les proportions de la vue.

var minimap: Minimap
var _pad: float = 6.0

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiMetrics.register(self)
	rescale()

func rescale() -> void:
	var sb := AtlasBox.new(UiMetrics.css(5.0))
	sb.fill_top = Atlas.OBSIDIAN_DEEP
	sb.fill_bottom = Atlas.OBSIDIAN_DEEP
	sb.border = Atlas.COPPER_DIM
	sb.cut = 6.0
	sb.corners = Vector4(0, 1, 0, 1)
	add_theme_stylebox_override("panel", sb)
	_pad = UiMetrics.css(5.0)

func _process(_d: float) -> void:
	if minimap == null:
		return
	var avail := get_parent_area_size().x if get_parent() != null else 0.0
	var hr := get_viewport().get_visible_rect().size.y
	var maxw := 330.0 if hr > 820.0 else (260.0 if hr > 650.0 else 200.0)
	var w := minf(UiMetrics.css(maxw), maxf(40.0, avail))
	var inner := w - _pad * 2.0
	custom_minimum_size = Vector2(0, inner / minimap.view_aspect() + _pad * 2.0)
