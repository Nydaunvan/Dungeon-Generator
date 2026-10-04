class_name Form
extends RefCounted
## Petits constructeurs de formulaires (libellé + champ) qui écrivent directement dans un dictionnaire.
## `changed` (Callable sans argument, facultatif) est appelé après chaque modification.
##
## Mise en page = `.field-row` de l'original : libellé (min 140 px, 0.75rem, #b8a781) puis champ collé à gauche, écart de 8 px,
## retour à la ligne si ça ne tient pas, 10 px sous chaque rangée. Les marges verticales du CSS (rangée 10 px, indice -4/12 px,
## boutons d'action 14 px au-dessus…) sont reproduites avec leur fusion (`_place`) : l'espace entre deux éléments consécutifs d'un
## VBoxContainer est celui qu'aurait le navigateur.

const FIELD_W := 80.0           # input[type=number] de l'original : width:80px
const LABEL_MIN_W := 140.0      # .field-row label{min-width:140px}
const GAP_BASE := 4.0           # séparation native du corps d'un OrnatePanel

static var _mono: Font = null

## Pose `c` dans `parent` avec les marges CSS verticales `mt` / `mb` (px), fusionnées avec celles du frère précédent.
static func _place(parent: Control, c: Control, mt: float, mb: float) -> void:
	if parent is VBoxContainer:
		var n := parent.get_child_count()
		var prev_mb := 10.0                       # sous l'en-tête d'un panneau : h3 margin-bottom 10
		if n > 0:
			var last := parent.get_child(n - 1)
			prev_mb = float(last.get_meta("form_mb")) if last.has_meta("form_mb") else 0.0
		var gap := _collapse(prev_mb, mt)
		var extra := gap - GAP_BASE
		if extra > 0.5:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, UiMetrics.css(extra))
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sp.set_meta("form_mb", 0.0)
			parent.add_child(sp)
	c.set_meta("form_mb", mb)
	parent.add_child(c)

## Fusion de marges verticales adjacentes (positives : la plus grande ; négatives : la plus petite ; mixtes : la somme).
static func _collapse(a: float, b: float) -> float:
	if a >= 0.0 and b >= 0.0:
		return maxf(a, b)
	if a < 0.0 and b < 0.0:
		return minf(a, b)
	return a + b

## Indication (`p.hint`) : 0.74rem italique #b8a781. `mt` = NAN : ancien comportement (pas de marge propre).
static func hint(parent: Control, text: String, size: int = 13, mt: float = NAN, mb: float = 12.0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	l.add_theme_color_override("font_color", UiTheme.DIM)
	if is_nan(mt):
		parent.add_child(l)
	else:
		_place(parent, l, mt, mb)
	return l

## Indication au style de l'original (`.hint`, marges CSS explicites : défaut -4 px au-dessus, 12 px en dessous).
static func note(parent: Control, text: String, mt: float = -4.0, mb: float = 12.0) -> Label:
	return hint(parent, text, int(round(UiMetrics.rem(0.74))), mt, mb)

static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(UiMetrics.css(LABEL_MIN_W), 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.75))))
	l.add_theme_color_override("font_color", Color("b8a781"))
	return l

## `.field-row` : libellé + champ, alignés au centre, retour à la ligne si l'espace manque.
static func row(parent: Control, label: String, field: Control) -> Control:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", int(UiMetrics.css(8.0)))
	h.add_theme_constant_override("v_separation", int(UiMetrics.css(8.0)))
	h.add_child(_label(label))
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(field)
	_place(parent, h, 0.0, 10.0)
	return h

## Champ numérique autonome (sans dictionnaire) : plage très large, la borne exacte est appliquée par le bouton d'enregistrement
## (comme les `saveXxx` de l'original, qui lisent le champ puis bornent). Renvoie le SpinBox.
static func num_field(value: float, step: float = 1.0, width: float = FIELD_W) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = -1.0e9
	s.max_value = 1.0e9
	s.step = step
	s.allow_greater = true
	s.allow_lesser = true
	s.custom_minimum_size = Vector2(UiMetrics.css(width), 0)
	s.get_line_edit().add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.85))))
	s.value = value
	return s

## Rangée libellé + champ numérique autonome (voir `num_field`).
static func num_row(parent: Control, label: String, value: float, step: float = 1.0, width: float = FIELD_W) -> SpinBox:
	var s := num_field(value, step, width)
	row(parent, label, s)
	return s

## Valeur d'un champ comme `Number(input.value)||d` (0, vide ou NaN → d).
static func val_or(s: SpinBox, d: float) -> float:
	var v := s.value
	return d if (is_nan(v) or v == 0.0) else v

static func number(parent: Control, label: String, target: Dictionary, key: String, lo: float, hi: float,
		step: float = 1.0, default_value: float = 0.0, changed: Callable = Callable()) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(UiMetrics.css(FIELD_W), 0)
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
	e.custom_minimum_size = Vector2(UiMetrics.css(width), 0)
	e.text_changed.connect(func(t: String):
		target[key] = t
		if changed.is_valid():
			changed.call())
	row(parent, label, e)
	return e

## Champ texte autonome (non lié à un dictionnaire) dans une rangée.
static func text_row(parent: Control, label: String, value: String, width: float = 260.0) -> LineEdit:
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size = Vector2(UiMetrics.css(width), 0)
	e.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.85))))
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

## Zone de texte monospace de l'original (code de donjon : 0.7rem, pleine largeur, 80 px de haut minimum).
static func code_area(parent: Control, placeholder: String, read_only: bool, min_h: float = 80.0, mt: float = 0.0) -> TextEdit:
	var t := TextEdit.new()
	t.placeholder_text = placeholder
	t.editable = not read_only
	t.custom_minimum_size = Vector2(0, UiMetrics.css(min_h))
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _mono == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["monospace", "DejaVu Sans Mono", "Courier New"])
		_mono = sf
	t.add_theme_font_override("font", _mono)
	t.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.7))))
	_place(parent, t, mt, 0.0)
	return t

## Étiquette d'état `.save-status` : 0.7rem, #7a6a52, 6 px au-dessus, 1 em de haut minimum.
static func status_label(parent: Control, mt: float = 6.0) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(0, UiMetrics.rem(0.7) * 1.5)
	l.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.7))))
	l.add_theme_color_override("font_color", Color("7a6a52"))
	_place(parent, l, mt, 0.0)
	return l

## Rangée de boutons : [[texte, Callable, primary?], …] (un 3e élément vrai met le bouton en avant : doré).
static func buttons(parent: Control, specs: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for sp in specs:
		h.add_child(_button(sp))
	parent.add_child(h)
	return h

static func _button(sp: Array) -> Button:
	var b := Button.new()
	b.text = str(sp[0])
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(sp[1])
	if sp.size() > 2 and bool(sp[2]):
		b.add_theme_color_override("font_color", Color("ffd88a"))
		b.add_theme_color_override("font_hover_color", Color("fff0c8"))
	return b

## `.admin-actions` : rangée de boutons qui passe à la ligne (écart 8 px), 14 px au-dessus.
static func actions(parent: Control, specs: Array, mt: float = 14.0) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", int(UiMetrics.css(8.0)))
	h.add_theme_constant_override("v_separation", int(UiMetrics.css(8.0)))
	for sp in specs:
		h.add_child(_button(sp))
	_place(parent, h, mt, 0.0)
	return h

## `generateShareCode` : génère le code DGZ1 de `cfg`, l'affiche dans `out`, le copie dans le presse-papiers et écrit l'état dans `status`.
static func generate_code(cfg: Dictionary, out: TextEdit, status: Label) -> void:
	status.text = L.t("admin.form.generation_du_code")
	await status.get_tree().process_frame
	var code := Data.encode_code(cfg)
	if code == "":
		status.text = L.t("admin.form.echec_de_la_generation_du")
		return
	out.visible = true
	out.text = code
	out.select_all()
	DisplayServer.clipboard_set(code)
	status.text = L.fa(L.t("admin.form.code_copie_dans_le_presse"), code.length())

## Alerte de l'original (`showAlert`) : message + bouton « OK ».
static func alert(host: Node, message: String) -> Modal:
	var m := Modal.open(host, "", 420.0)
	m.add_text(message, UiTheme.PARCH, 15)
	m.set_buttons([{"text": "OK", "primary": true, "cb": func(): m.close()}])
	return m

## Sous-dictionnaire (créé si absent).
static func sub(target: Dictionary, key: String) -> Dictionary:
	if not (target.get(key) is Dictionary):
		target[key] = {}
	return target[key]

## Panneau titré ajouté à `parent` ; renvoie le corps où poser les champs.
static func panel(parent: Control, title: String) -> VBoxContainer:
	var p := OrnatePanel.new(title)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if p.title_label != null:
		p.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT      # `.panel h3` : aligné à gauche
	parent.add_child(p)
	return p.body
