class_name AdminTable
extends RefCounted
## Tableau « .data-table » de l'original : défilement horizontal, en-têtes dorés en capitales (0,62 rem), filet #5a4526 sous
## l'en-tête, filets très discrets entre les lignes. Les cellules sont de simples contrôles ajoutés ligne après ligne.

## Crée le tableau dans `parent` ; `headers` = libellés, `min_widths` = largeur minimale de chaque colonne (px CSS, 0 = auto).
## Renvoie le GridContainer : y ajouter les cellules DANS L'ORDRE (une ligne = headers.size() cellules), avec `end_row`
## entre deux lignes pour tracer le filet.
static func create(parent: Control, headers: Array, min_widths: Array = []) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var g := GridContainer.new()
	g.columns = headers.size()
	g.add_theme_constant_override("h_separation", int(UiMetrics.css(10.0)))
	g.add_theme_constant_override("v_separation", int(UiMetrics.css(8.0)))
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	for i in headers.size():
		var l := Label.new()
		l.text = str(headers[i]).to_upper()
		l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.62)))
		l.add_theme_color_override("font_color", Color("b8893f"))
		l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
		var w: float = float(min_widths[i]) if i < min_widths.size() else 0.0
		if w > 0.0:
			l.custom_minimum_size.x = UiMetrics.css(w)
		g.add_child(l)
	return g

## Cellule de texte (valeur en lecture seule, ex. « Position 9,7 », aperçu).
static func text_cell(grid: GridContainer, text: String, dim: bool = false, size_rem: float = 0.76) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(UiMetrics.rem(size_rem)))
	l.add_theme_color_override("font_color", UiTheme.DIM if dim else UiTheme.PARCH)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	return l

## Ajoute n'importe quel contrôle comme cellule (centré verticalement).
static func cell(grid: GridContainer, c: Control) -> Control:
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(c)
	return c
