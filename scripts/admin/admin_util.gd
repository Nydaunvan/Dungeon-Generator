class_name AdminUtil
extends RefCounted
## Aides communes aux onglets d'administration (classes, sorts, objets).

const BASE_ARCHETYPES := ["Guerrier", "Archer", "Roublard", "Mage", "Prêtre", "Barde"]

static func is_base(cls: Dictionary) -> bool:
	return BASE_ARCHETYPES.has(str(cls.get("name", "")))

static func base_of(cls: Dictionary) -> Dictionary:
	var from := str(cls.get("evolvesFrom", ""))
	if from == "":
		return {}
	for c in Data.config.get("classes", []):
		if str(c.get("name", "")) == from and is_base(c):
			return c
	return {}

static func eff_weapons(cls: Dictionary) -> Array:
	var out: Array = (cls.get("allowedWeaponTypes", []) as Array).duplicate()
	for w in base_of(cls).get("allowedWeaponTypes", []):
		if not out.has(w):
			out.append(w)
	return out

static func eff_spells(cls: Dictionary) -> Array:
	return cls.get("allowedSpellIds", [])

## Sort appris automatiquement à un niveau > 1 : ne peut pas être attribué au départ. Renvoie le niveau ou 0.
static func locked_level(cls: Dictionary, spell_id: String) -> int:
	var lvl := 0
	for p in cls.get("spellProgression", []):
		if str(p.get("spellId", "")) == spell_id and int(p.get("level", 1)) > 1:
			if lvl == 0 or int(p.level) < lvl:
				lvl = int(p.level)
	return lvl

static func classes_allowing(spell_id: String) -> Array:
	var out: Array = []
	for c in Data.config.get("classes", []):
		if eff_spells(c).has(spell_id):
			out.append(c)
	return out

static func is_emoji_icon(icon: String) -> bool:
	return icon != "" and not icon.begins_with("@icon:")

## Libellé « 🔥 Boule de feu » (l'emoji seulement si l'icône en est un).
static func spell_label(s: Dictionary) -> String:
	var ic := str(s.get("icon", ""))
	return ("%s %s" % [ic, s.get("name", "?")]) if is_emoji_icon(ic) else str(s.get("name", "?"))

static func item_label(it: Dictionary) -> String:
	var ic := str(it.get("icon", ""))
	return ("%s %s" % [ic, it.get("name", "?")]) if is_emoji_icon(ic) else str(it.get("name", "?"))

static func weapon_types() -> Array:
	return Data.constants.get("WEAPON_TYPES", [])

static func weapon_label(id: String) -> String:
	for w in weapon_types():
		if str(w.id) == id:
			return str(w.label)
	return id

## Nouvel identifiant unique.
static func new_id(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, Time.get_ticks_msec(), randi() % 1000]

static func label(text: String, size: int = 14, color: Color = UiTheme.PARCH) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Petit champ numérique compact (libellé au-dessus non affiché : le libellé est fourni dans la rangée).
static func mini_number(target: Dictionary, key: String, lo: float, hi: float, default_value: float = 0.0, changed: Callable = Callable(), width: float = 84.0, step: float = 1.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(width, 0)
	s.value = float(target.get(key, default_value))
	s.value_changed.connect(func(v: float):
		target[key] = int(v) if step >= 1.0 else v
		if changed.is_valid():
			changed.call())
	return s

## Rangée horizontale « libellé + champ » pour ranger plusieurs champs sur une ligne.
static func chip(parent: Control, text: String, field: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(label(text, 13, UiTheme.DIM))
	h.add_child(field)
	parent.add_child(h)
	return h

static func flow(parent: Control) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 12)
	f.add_theme_constant_override("v_separation", 6)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(f)
	return f

## Liste déroulante autonome : options [[valeur, libellé], …]; `on_pick` reçoit la valeur.
static func dropdown(options: Array, current, on_pick: Callable, width: float = 0.0) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	if width > 0.0:
		o.custom_minimum_size = Vector2(width, 0)
	var sel := 0
	for i in options.size():
		o.add_item(str(options[i][1]))
		if str(options[i][0]) == str(current):
			sel = i
	if options.size() > 0:
		o.select(sel)
	o.item_selected.connect(func(i: int): on_pick.call(options[i][0]))
	return o
