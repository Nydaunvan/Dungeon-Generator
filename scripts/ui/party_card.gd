class_name PartyCard
extends Control
## Fiche de personnage Atlas Noir : portrait en tête, nom (Cinzel), classe et niveau (Spectral), barres de PV et d'endurance nettes,
## fine ligne d'XP et jauge de tour. Sélection = filet ambre + losange ; cible possible = filet cuivre clair ; statut = filet teinté
## autour du portrait. Les détails (stats, XP exacte, statuts, équipement) sont dans l'infobulle au survol.
## Toutes les cotes suivent la hauteur réelle de la fiche (k = 1 % de la hauteur).

signal pressed
signal chest_pressed
signal context

const BASE_H := 88.0

var char_id: String = ""
var accent: Color = Color("a33")
var active: bool = false
var targetable: bool = false
var dead: bool = false
var ring_override: Color = Color(0, 0, 0, 0)    # filet du portrait teinté par un statut
var f: float = 1.0

var pic: TextureRect
var badge: Label                    # conservée pour compatibilité (remplacée par la rangée de pastilles)
var status_row: HBoxContainer      # une pastille (icône + tours restants) par statut actif
var _status_sig := ""
var _status_fs := 10
var name_lbl: Label
var cls_lbl: Label
var lvl_lbl: Label
var cls_ico: TextureRect            # conservée pour compatibilité, jamais affichée (la classe s'écrit sous le nom)
var chest: Button
var hp: TextBar
var sta: TextBar
var xp: TextBar
var gauge: TextBar
var dead_lbl: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(40, 40)
	pic = TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pic)
	badge = Label.new()
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	status_row = HBoxContainer.new()
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_theme_constant_override("separation", 2)
	status_row.z_index = 60                    # au-dessus de CardFxOverlay (z 50) : les flammes et le givre ne les cachent pas
	status_row.z_as_relative = false
	add_child(status_row)
	name_lbl = _label(Atlas.title_font(false, 2), Atlas.IVORY)
	cls_lbl = _label(Atlas.font(Atlas.F_BODY), Atlas.IVORY_DIM)
	lvl_lbl = _label(Atlas.font(Atlas.F_BODY_MED), Atlas.IVORY_DIM)
	cls_ico = TextureRect.new()
	cls_ico.visible = false
	cls_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cls_ico.size = Vector2(1, 1)
	cls_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cls_ico)
	chest = Button.new()
	chest.flat = true
	chest.focus_mode = Control.FOCUS_NONE
	chest.icon = UiTheme.tex("chest")
	chest.expand_icon = true
	chest.tooltip_text = L.t("ui.party_card.inventaire_de_ce_heros")
	chest.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		chest.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	chest.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.78))
	chest.add_theme_color_override("icon_hover_color", Color(1.25, 1.15, 0.95))
	chest.pressed.connect(func(): chest_pressed.emit())
	add_child(chest)
	hp = _bar(Atlas.HP, true, 1.0)
	sta = _bar(Atlas.MANA, true, 1.0)
	xp = _bar(Atlas.IVORY_DIM, false)
	gauge = _bar(Atlas.AMBER, false)
	dead_lbl = _label(Atlas.title_font(true, 1), Color.WHITE)
	dead_lbl.text = "Mort"
	dead_lbl.visible = false
	dead_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	dead_lbl.add_theme_constant_override("outline_size", 4)

func _label(font: Font, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l

func _bar(col: Color, with_text: bool, text_w: float = 0.0) -> TextBar:
	var b := TextBar.new(col, 10, 10)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.use_atlas(col, with_text, 0.0)
	if text_w > 0.0:
		b.set_meta("outside", true)
	add_child(b)
	return b

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			context.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()

## Taille de police des pastilles de statut ; reconstruit la rangée si elle change.
func _status_font(fs: int) -> void:
	if fs != _status_fs:
		_status_fs = fs
		_status_sig = ""

## Affiche une pastille par statut : `list` = [{"text": "🔥 3", "color": Color}], vide pour tout retirer.
func set_statuses(list: Array) -> void:
	var sig := str(_status_fs) + "|" + str(list)
	if sig == _status_sig:
		return
	_status_sig = sig
	for ch in status_row.get_children():
		ch.queue_free()
	for it in list:
		var col: Color = it.color
		var lb := Label.new()
		lb.text = str(it.text)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
		lb.add_theme_font_size_override("font_size", _status_fs)
		lb.add_theme_color_override("font_color", col.lightened(0.4))
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lb.add_theme_constant_override("outline_size", 3)
		var sb := UiTheme.box(Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.95), col, 1, 7)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		lb.add_theme_stylebox_override("normal", sb)
		status_row.add_child(lb)

func _pad() -> float:
	return size.y * 0.07

## Rectangle du portrait (px locaux).
func _pic_rect() -> Rect2:
	var p := _pad()
	var h := size.y - p * 2.0
	return Rect2(p, p, minf(h * 0.86, size.x * 0.4), h)

func _layout() -> void:
	var k := size.y / 100.0
	f = maxf(0.2, size.y / UiMetrics.css(BASE_H)) if UiMetrics.css(BASE_H) > 0.0 else 1.0
	var pr := _pic_rect()
	pic.position = pr.position
	pic.size = pr.size
	var x0 := pr.end.x + 9.0 * k
	var right := size.x - 9.0 * k
	var bw := maxf(10.0, right - x0)
	# rangée haute : nom à gauche, niveau à droite
	var lfs := maxi(7, int(13.0 * k))
	lvl_lbl.add_theme_font_size_override("font_size", lfs)
	var lw := lvl_lbl.get_theme_font("font").get_string_size(lvl_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x + 2.0
	lvl_lbl.size = Vector2(lw, 19.0 * k)
	lvl_lbl.position = Vector2(right - lw, 6.0 * k)
	_put(name_lbl, x0, 6.0 * k, maxf(10.0, lvl_lbl.position.x - x0 - 4.0 * k), 19.0 * k, 15.0 * k)
	_fit_name(name_lbl.size.x)
	# classe sous le nom, coffre à droite sur la même ligne
	var ch := 17.0 * k
	chest.size = Vector2(ch, ch)
	chest.position = Vector2(right - ch, 27.0 * k + (16.0 * k - ch) * 0.5)
	_put(cls_lbl, x0, 27.0 * k, maxf(10.0, chest.position.x - x0 - 4.0 * k), 16.0 * k, 12.5 * k)
	# barres : petit repère à gauche, barre en biais, chiffre à droite (hors de la barre)
	var ico := 11.0 * k
	var tw := 46.0 * k
	var bx := x0 + ico + 4.0 * k
	var bbw := maxf(10.0, right - tw - bx)
	_bar_at(hp, bx, 49.0 * k, bbw, 13.0 * k, 12.0 * k, tw)
	_bar_at(sta, bx, 71.0 * k, bbw, 13.0 * k, 12.0 * k, tw)
	_bar_at(xp, x0, 90.0 * k, bw, 2.0 * k, 1.0, 0.0)
	_bar_at(gauge, x0, 93.0 * k, bw, 2.0 * k, 1.0, 0.0)
	status_row.position = Vector2(pr.position.x + 2.0 * k, pr.end.y - 13.0 * k)
	_status_font(maxi(8, int(12.0 * k)))
	dead_lbl.size = Vector2(size.x, 30.0 * k)
	dead_lbl.position = Vector2(0, (size.y - 30.0 * k) * 0.5)
	dead_lbl.add_theme_font_size_override("font_size", maxi(9, int(24.0 * k)))

## Réduit la police du nom jusqu'à ce qu'il tienne sur sa ligne (jamais en dessous de 60 %).
func _fit_name(w: float) -> void:
	var fs := name_lbl.get_theme_font_size("font_size")
	var font := name_lbl.get_theme_font("font")
	var wanted := font.get_string_size(name_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if wanted > w and wanted > 0.0:
		name_lbl.add_theme_font_size_override("font_size", maxi(6, int(floorf(fs * maxf(0.6, w / wanted)))))

func _put(l: Label, x: float, y: float, w: float, h: float, fs: float) -> void:
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.add_theme_font_size_override("font_size", maxi(7, int(fs)))

func _bar_at(b: TextBar, x: float, y: float, w: float, h: float, fs: float, text_w: float) -> void:
	b.position = Vector2(x, y)
	if text_w > 0.0:
		b.use_atlas(b.get_theme_stylebox("fill").color, true, text_w)
	b.size = Vector2(w, h)
	b.custom_minimum_size = Vector2(0, h)
	b.set_font_size(maxi(1, int(fs)), 0.12)

# ------------------------------------------------------------------ dessin

func _draw() -> void:
	var k := size.y / 100.0
	var r := Rect2(Vector2.ZERO, size)
	var lit := active or targetable
	var sk := Unlocks.skin_color()
	var edge: Color = Atlas.AMBER if active else (Atlas.AMBER_DIM if targetable else Atlas.COPPER_DIM)
	if sk.a > 0.0 and not lit:
		edge = sk.darkened(0.5)
	elif sk.a > 0.0 and active:
		edge = sk
	var w := maxf(1.0, 1.4 * k) if lit else maxf(1.0, k)
	# cadre : fond noir translucide ; la fiche active a le coin haut-gauche coupé en biais et un filet ambre
	var cut := 12.0 * k
	var corners := Vector4(1, 0, 0, 0) if active else Vector4(0, 0, 0, 0)
	Atlas.draw_box(self, r, Color(0.04, 0.05, 0.055, 0.88), Color(0.025, 0.03, 0.034, 0.92), edge, w, cut if active else 4.0, corners)
	if active:
		draw_line(Vector2(w + 1.0, cut + 5.0 * k), Vector2(cut + 5.0 * k, w + 1.0), Color(Atlas.AMBER, 0.8), 1.0, true)
	else:
		# équerres intérieures aux angles (repères de cartographie)
		var m := 4.0 * k
		var l := 7.0 * k
		var mc := Color(Atlas.COPPER, 0.55)
		draw_polyline(PackedVector2Array([Vector2(size.x - m - l, m), Vector2(size.x - m, m), Vector2(size.x - m, m + l)]), mc, 1.0, true)
		draw_polyline(PackedVector2Array([Vector2(size.x - m - l, size.y - m), Vector2(size.x - m, size.y - m), Vector2(size.x - m, size.y - m - l)]), mc, 1.0, true)
	# petits repères en losange à gauche de chaque barre
	var k2 := size.y / 100.0
	var pr0 := _pic_rect()
	var ix := pr0.end.x + 9.0 * k2 + 5.5 * k2
	for bar in [hp, sta]:
		var c2 := Vector2(ix, bar.position.y + bar.size.y * 0.5)
		var rr := 5.5 * k2
		draw_colored_polygon(PackedVector2Array([c2 + Vector2(0, -rr), c2 + Vector2(rr, 0), c2 + Vector2(0, rr), c2 + Vector2(-rr, 0)]), Color(0.08, 0.1, 0.1, 0.95))
		var inner: Color = hp.get_theme_stylebox("fill").color if bar == hp else sta.get_theme_stylebox("fill").color
		draw_colored_polygon(PackedVector2Array([c2 + Vector2(0, -rr * 0.55), c2 + Vector2(rr * 0.55, 0), c2 + Vector2(0, rr * 0.55), c2 + Vector2(-rr * 0.55, 0)]), inner.lightened(0.25))
	# portrait : filet fin (teinté par un statut, ambre si actif)
	var pr := _pic_rect()
	var pe: Color = ring_override if ring_override.a > 0.0 else (Atlas.AMBER if active else Atlas.COPPER_DIM)
	draw_rect(pr.grow(maxf(1.0, 1.5 * k)), Color("070908"))
	draw_rect(pr, Atlas.OBSIDIAN_DEEP)
	draw_rect(pr.grow(maxf(1.0, 1.5 * k)), pe, false, maxf(1.0, k * (1.6 if ring_override.a > 0.0 else 1.0)))
	# repère de sélection : losange sur le bord gauche
	if active:
		Atlas.draw_diamond(self, Vector2(0.0, size.y * 0.5), 5.0 * k, Atlas.AMBER)
	if dead:
		draw_colored_polygon(Atlas.chamfer(r, 8.0 * k), Color(0.55, 0.08, 0.08, 0.45))
