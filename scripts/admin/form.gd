class_name Form
extends RefCounted
## Petits constructeurs de formulaires (libellé + champ) qui écrivent directement dans un dictionnaire.
## `changed` (Callable sans argument, facultatif) est appelé après chaque modification.

const FIELD_W := 130.0

static func hint(parent: Control, text: String, size: int = 13) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	l.add_theme_color_override("font_color", UiTheme.DIM)
	parent.add_child(l)
	return l

static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

static func row(parent: Control, label: String, field: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_label(label))
	h.add_child(field)
	parent.add_child(h)
	return h

static func number(parent: Control, label: String, target: Dictionary, key: String, lo: float, hi: float,
		step: float = 1.0, default_value: float = 0.0, changed: Callable = Callable()) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(FIELD_W, 0)
	s.value = float(target.get(key, default_value))
	s.value_changed.connect(func(v: float):
		target[key] = int(v) if step >= 1.0 else v
		if changed.is_valid():
			changed.call())
	row(parent, label, s)
	return s

static func text(parent: Control, label: String, target: Dictionary, key: String, changed: Callable = Callable(), width: float = 260.0) -> LineEdit:
	var e := LineEdit.new()
	e.text = str(target.get(key, ""))
	e.custom_minimum_size = Vector2(width, 0)
	e.text_changed.connect(func(t: String):
		target[key] = t
		if changed.is_valid():
			changed.call())
	row(parent, label, e)
	return e

static func check(parent: Control, label: String, target: Dictionary, key: String, default_value: bool = false, changed: Callable = Callable()) -> CheckBox:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = bool(target.get(key, default_value))
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool):
		target[key] = on
		if changed.is_valid():
			changed.call())
	parent.add_child(c)
	return c

## Liste déroulante : `options` = [[valeur, libellé], …].
static func option(parent: Control, label: String, target: Dictionary, key: String, options: Array, changed: Callable = Callable(), width: float = 220.0) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(width, 0)
	o.focus_mode = Control.FOCUS_NONE
	var sel := 0
	for i in options.size():
		o.add_item(str(options[i][1]))
		if str(options[i][0]) == str(target.get(key, "")):
			sel = i
	o.select(sel)
	o.item_selected.connect(func(i: int):
		target[key] = options[i][0]
		if changed.is_valid():
			changed.call())
	row(parent, label, o)
	return o

static func area(parent: Control, target: Dictionary, key: String, min_h: float = 90.0, changed: Callable = Callable()) -> TextEdit:
	var t := TextEdit.new()
	t.text = str(target.get(key, ""))
	t.custom_minimum_size = Vector2(0, min_h)
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_changed.connect(func():
		target[key] = t.text
		if changed.is_valid():
			changed.call())
	parent.add_child(t)
	return t

## Rangée de boutons : [[texte, Callable], …] (le premier peut être mis en avant avec `primary`).
static func buttons(parent: Control, specs: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for sp in specs:
		var b := Button.new()
		b.text = str(sp[0])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(sp[1])
		h.add_child(b)
	parent.add_child(h)
	return h

## Sous-dictionnaire (créé si absent).
static func sub(target: Dictionary, key: String) -> Dictionary:
	if not (target.get(key) is Dictionary):
		target[key] = {}
	return target[key]

## Panneau titré ajouté à `parent` ; renvoie le corps où poser les champs.
static func panel(parent: Control, title: String) -> VBoxContainer:
	var p := OrnatePanel.new(title)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	return p.body
