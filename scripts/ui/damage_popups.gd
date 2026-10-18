class_name DamagePopups
extends Control
## Chiffres de dégâts / soins / résistances empilés en LIGNES (jamais les uns sur les autres).
## Cible "" : colonne au-dessus du monstre (centre de la vue 3D) ; "char:<id>" : colonne sur le cadre de la carte du héros ;
## "party" : colonne au-dessus du bandeau d'équipe. Chaque ligne prend la plus haute place libre de sa colonne, dans l'ordre d'arrivée.

const LINE_H := 34.0
const HERO_LINE_H := 25.0       ## les cartes sont basses : lignes plus serrées
const LIFE := 1.6
const FADE := 0.5

var gs: Object
var view: Control                 ## vue 3D encadrée (ancre des popups du monstre)
var hud: PartyHud                 ## bandeau d'équipe (ancre des popups de héros)
var _cols: Dictionary = {}        ## clé de cible -> Array de {lbl, slot}

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_popup(text: String, color: Color, on: String) -> void:
	var anchor := _anchor(on)
	var col: Array = _cols.get(on, [])
	_cols[on] = col
	var used := {}
	for e in col:
		used[int(e.slot)] = true
	var slot := 0
	while used.has(slot):
		slot += 1
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.5)) if on == "" else int(UiMetrics.rem(1.0)))
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lh := HERO_LINE_H if on.begins_with("char:") else LINE_H
	lbl.size = Vector2(anchor.size.x, lh)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	lbl.global_position = Vector2(anchor.position.x, anchor.position.y + slot * lh)
	var entry := {"lbl": lbl, "slot": slot}
	col.append(entry)
	var t := create_tween()
	t.tween_interval(LIFE - FADE)
	t.tween_property(lbl, "modulate:a", 0.0, FADE)
	t.tween_callback(func():
		col.erase(entry)
		lbl.queue_free())

## Rectangle (pixels de la fenêtre) dont le haut est la première ligne de la colonne.
func _anchor(on: String) -> Rect2:
	if on.begins_with("char:") and hud != null and gs != null:
		var id := on.substr(5)
		var i := 0
		for c in gs.party:
			if str(c.id) == id:
				var rs: Array = hud.card_rects()
				if i < rs.size():
					var r: Rect2 = rs[i]
					return Rect2(r.position + Vector2(0, r.size.y * 0.08), Vector2(r.size.x, LINE_H))
			i += 1
	if on == "party" and hud != null:
		var rs2: Array = hud.card_rects()
		if not rs2.is_empty():
			var u: Rect2 = rs2[0]
			for r2 in rs2:
				u = u.merge(r2)
			return Rect2(u.position + Vector2(0, -LINE_H * 1.2), Vector2(u.size.x, LINE_H))
	var v := view.get_global_rect() if view != null else get_viewport_rect()
	return Rect2(v.position + Vector2(0, v.size.y * 0.30), Vector2(v.size.x, LINE_H))
