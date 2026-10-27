class_name ItemTip
extends RefCounted
## Infobulle d'objet (survol d'une case de la besace, du volet d'équipement ou de la forge), pour tous les types d'objets.
## Mise en page : cadre à la couleur de la rareté (filet intérieur, losanges d'angle, lueur en tête) ; en-tête (icône encadrée, nom,
## type, rareté, valeur) ; bloc principal des armes (dégâts par coup, écart en % avec l'arme équipée) ; lignes de bonus à icônes
## avec écart par rapport à l'objet équipé ; pouvoirs et résistances ; pied (équipé par / remplace, valeur de vente).

const W := 292.0                       # largeur du contenu
const ICON_W := 24.0
const PERK_COL := Color("86dcff")      # pouvoirs de rareté
const RESIST_COL := Color("8fe0b4")
const PERK_ICONS := {"crit": "💥", "dodge": "💨", "gold": "💰", "lifesteal": "🩸", "thorns": "🌵", "spell": "🔮",
	"execute": "🗡️", "bleed": "💧", "critdmg": "💢", "last_stand": "🛡️"}
const STAT_ICONS := {"atkMin": "⚔️", "atkMax": "⚔️", "hp": "❤️", "spellDmg": "✨", "force": "💪", "dex": "🎯", "con": "🛡️", "int": "🧠", "speed": "⚡"}
const WEAPON_KEYS := {"sword": "ui.bag.wt_sword", "axe": "ui.bag.wt_axe", "mace": "ui.bag.wt_mace", "dagger": "ui.bag.wt_dagger",
	"bow": "ui.bag.wt_bow", "staff": "ui.bag.wt_staff"}
const KIND_ICONS := {"potion": "🧪", "key": "🔑", "scroll": "📜"}


## Cadre : fond sombre teinté, bordure de rareté, filet intérieur, losanges d'angle et lueur en tête (tout est dessiné ici).
class Frame extends PanelContainer:
	var col := Color("a9793a")

	func _init() -> void:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 14
		e.content_margin_right = 14
		e.content_margin_top = 12
		e.content_margin_bottom = 12
		add_theme_stylebox_override("panel", e)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("0b0709").lerp(col.darkened(0.8), 0.55)
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.shadow_color = Color(0, 0, 0, 0.7)
		sb.shadow_size = 6
		draw_style_box(sb, r)
		var top := Color(col.r, col.g, col.b, 0.20)
		var none := Color(col.r, col.g, col.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(3, 3), Vector2(size.x - 3, 3), Vector2(size.x - 3, 90), Vector2(3, 90)]), PackedColorArray([top, top, none, none]))
		draw_rect(r.grow(-5), Color(col.r, col.g, col.b, 0.32), false, 1.0)
		for p in [Vector2(2, 2), Vector2(size.x - 2, 2), Vector2(2, size.y - 2), Vector2(size.x - 2, size.y - 2)]:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), col)


## Filet de séparation avec losange central.
class Divider extends Control:
	var col := Color("a9793a")

	func _init() -> void:
		custom_minimum_size = Vector2(0, 11)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var c := Color(col.r, col.g, col.b, 0.55)
		draw_line(Vector2(0, y), Vector2(size.x * 0.5 - 8, y), c, 1.0)
		draw_line(Vector2(size.x * 0.5 + 8, y), Vector2(size.x, y), c, 1.0)
		var m := Vector2(size.x * 0.5, y)
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -4), m + Vector2(4, 0), m + Vector2(0, 4), m + Vector2(-4, 0)]), col)


static func build(gs: GameState, it: Dictionary, char_id: String) -> Control:
	var gear := ["weapon", "armor", "jewelry"].has(str(it.get("type", "")))
	var special := Rarity.is_special(it) and gear
	var col: Color = Rarity.color(it) if special else Color("a9793a")
	var soft: Color = col.lightened(0.55) if special else UiTheme.PARCH      # texte des bonus, teinté par la rareté
	var frame := Frame.new()
	frame.col = col
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size = Vector2(W, 0)
	frame.add_child(v)
	v.add_child(_header(it, gear, special, col))
	v.add_child(_divider(col))
	var c := gs.char_by_id(char_id)
	var slot := Inventory.slot_of(it)
	var eq = c.get("equipment", {}).get(slot) if slot != "" else null
	var worn: bool = eq != null and is_same(eq, it)       # déjà porté par ce héros : statistiques seules, sans comparaison
	if worn:
		eq = null
	if slot != "":
		var is_w := str(it.get("type", "")) == "weapon"
		if is_w:
			v.add_child(_damage_block(it, eq))
		_stat_rows(v, c, it, eq, is_w, soft)
		var extras := _perk_rows(it)
		if not extras.is_empty():
			v.add_child(_divider(col))
			for r in extras:
				v.add_child(r)
		v.add_child(_divider(col))
		var foot := L.fa(L.t("ui.bag.equipe_par"), str(c.get("name", ""))) if worn else (L.fa(L.t("ui.bag.remplace"), str(eq.get("name", ""))) if eq != null else L.t("ui.bag.emplacement_libre"))
		var fl := BagCommon._lbl(foot, 12, UiTheme.DIM, UiTheme.F_BODY_ITALIC)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(W, 0)
		v.add_child(fl)
	else:
		var icon: String = KIND_ICONS.get(str(it.get("type", "")), "•")
		for line in Inventory.describe(it, gs.cfg):
			var sl := _split_icon(str(line), icon)
			v.add_child(_row(sl[0], sl[1], UiTheme.PARCH, 14, true))
		v.add_child(_divider(col))
	v.add_child(_sell_row(it))
	return frame


static func _divider(col: Color) -> Control:
	var d := Divider.new()
	d.col = col
	return d


## En-tête : icône encadrée à gauche ; nom, type, rareté et valeur à droite.
static func _header(it: Dictionary, gear: bool, special: bool, col: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b0709").lerp(col.darkened(0.55), 0.6)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(5)
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var tr := TextureRect.new()
	tr.texture = IconResolver.texture(str(it.get("icon", "")))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.custom_minimum_size = Vector2(54, 54)
	pc.add_child(tr)
	h.add_child(pc)
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 1)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := BagCommon._lbl(L.c(str(it.get("name", ""))), 18, col.lightened(0.2) if special else UiTheme.GOLD, UiTheme.F_TITLE_BOLD)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(W - 64, 0)      # largeur connue d'emblée : la hauteur du texte est juste dès la première image
	t.add_child(name_l)
	t.add_child(BagCommon._lbl(_type_text(it), 13, UiTheme.PARCH, UiTheme.F_BODY_BOLD))
	if gear:
		t.add_child(BagCommon._lbl(Rarity.label(it), 13, col if special else UiTheme.DIM, UiTheme.F_BODY_BOLD))
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 5)
	pr.add_child(BagCommon.coin(13.0))
	pr.add_child(BagCommon._lbl(str(Shop.price(it)), 13, Color("ffd88a"), UiTheme.F_BODY_BOLD))
	t.add_child(pr)
	h.add_child(t)
	return h


## Sous-type lisible : « Épée » pour une arme (sinon « Arme »), emplacement pour une armure, etc.
static func _type_text(it: Dictionary) -> String:
	if str(it.get("type", "")) == "weapon" and WEAPON_KEYS.has(str(it.get("weaponType", ""))):
		return L.t(str(WEAPON_KEYS[str(it.weaponType)]))
	return EquipDock._base_type_label(it)


## Bloc principal d'une arme : « 2 – 3  Dégâts par coup (+67 %) » (écart sur la moyenne avec l'arme équipée).
static func _damage_block(it: Dictionary, eq) -> Control:
	var mn := int(it.get("bonusAtkMin", 0))
	var mx := int(it.get("bonusAtkMax", 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(BagCommon._lbl("%d – %d" % [mn, mx], 24, Color("f4ead2"), UiTheme.F_TITLE_BOLD))
	var lab := BagCommon._lbl(L.t("ui.bag.tip_degats"), 14, UiTheme.PARCH, UiTheme.F_BODY_BOLD)
	lab.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(lab)
	if eq != null:
		var avg := (mn + mx) / 2.0
		var eavg := (int(eq.get("bonusAtkMin", 0)) + int(eq.get("bonusAtkMax", 0))) / 2.0
		if eavg > 0.0:
			var pct := int(round((avg - eavg) / eavg * 100.0))
			if pct != 0:
				var d := BagCommon._lbl("(%+d %%)" % pct, 14, BagCommon.UP if pct > 0 else BagCommon.DOWN, UiTheme.F_BODY_BOLD)
				d.size_flags_vertical = Control.SIZE_SHRINK_END
				h.add_child(d)
	return h


## Lignes de caractéristiques : icône, « +4 Force », écart avec l'objet équipé à droite, puis la conséquence pour le héros en petit.
static func _stat_rows(v: VBoxContainer, c: Dictionary, it: Dictionary, eq, is_w: bool, soft: Color) -> void:
	var rn: Array = EquipDock.stat_rows(it, is_w)
	var re: Array = EquipDock.stat_rows(eq, is_w) if eq != null else []
	var emap := {}
	for r in re:
		emap[r.key] = r.value
	var keys: Array = []
	var seen := {}
	for r in rn + re:
		if is_w and (r.key == "atkMin" or r.key == "atkMax"):
			continue       # déjà dans le bloc principal
		if not seen.has(r.key):
			seen[r.key] = true
			keys.append(r)
	for r in keys:
		var val := 0
		for x in rn:
			if x.key == r.key:
				val = int(x.value)
		var delta := ""
		var dcol := UiTheme.DIM
		var net := val - int(emap.get(r.key, 0))
		if eq != null and net != 0:
			delta = "(%s)" % (("+%d" % net) if net > 0 else str(net))
			dcol = BagCommon.UP if net > 0 else BagCommon.DOWN
		v.add_child(_row(str(STAT_ICONS.get(r.key, "•")), "%s%d %s" % ["+" if val > 0 else "", val, str(r.label)], soft, 14, false, delta, dcol))
		var hint: String = BagCommon._effect_hint(c, str(r.key), net)
		if hint != "":
			var hl := BagCommon._lbl(hint, 11, UiTheme.DIM, UiTheme.F_BODY_ITALIC)
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.custom_minimum_size = Vector2(W - ICON_W - 6, 0)
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_left", int(ICON_W + 6))
			pad.add_child(hl)
			v.add_child(pad)


## Pouvoirs de rareté (bleu clair) puis résistances (vert).
static func _perk_rows(it: Dictionary) -> Array:
	var out: Array = []
	for p in Rarity.perks_of(it):
		var sp := _split_icon(Rarity.perk_line(p), str(PERK_ICONS.get(str(p.get("id", "")), "✦")))
		out.append(_row(sp[0], sp[1], PERK_COL, 14, true))
	if it.get("resists") is Dictionary:
		for k in Resist.KEYS:
			var rv := int((it.resists as Dictionary).get(k, 0))
			if rv != 0:
				var sr := _split_icon(L.fa(L.t(str(Resist.ITEM_KEYS[k])), rv).replace("+-", "-"), str(Resist.ICONS.get(k, "•")))
				out.append(_row(sr[0], sr[1], RESIST_COL, 14, true))
	return out


## Les textes de langue commencent souvent par leur émoji : on le sépare du texte pour l'afficher dans la colonne d'icônes.
static func _split_icon(text: String, fallback: String) -> Array:
	var sp := text.find(" ")
	if sp > 0 and text.unicode_at(0) > 0x2000:
		return [text.substr(0, sp), text.substr(sp + 1)]
	return [fallback, text]


static func _row(icon: String, text: String, col: Color, size: int, wrap: bool, delta: String = "", dcol: Color = Color.WHITE) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var ic := BagCommon._lbl(icon, size + 1, Color.WHITE, UiTheme.F_BODY_BOLD)
	ic.custom_minimum_size = Vector2(ICON_W, 0)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	h.add_child(ic)
	var l := BagCommon._lbl(text, size, col, UiTheme.F_BODY_BOLD if not wrap else UiTheme.F_BODY)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(W - ICON_W - 6, 0)
	h.add_child(l)
	if delta != "":
		h.add_child(BagCommon._lbl(delta, 14, dcol, UiTheme.F_BODY_BOLD))
	return h


## Pied : valeur de vente, alignée à droite, avec la pièce d'or.
static func _sell_row(it: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	var l := BagCommon._lbl(L.t("ui.bag.tip_vente"), 12, UiTheme.DIM, UiTheme.F_BODY_ITALIC)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(BagCommon._lbl(str(Shop.sell_price(it)), 13, Color("ffd88a"), UiTheme.F_BODY_BOLD))
	h.add_child(BagCommon.coin(13.0))
	return h
