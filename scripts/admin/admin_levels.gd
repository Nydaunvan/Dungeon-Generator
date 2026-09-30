class_name AdminLevels
extends RefCounted
## Onglet « Niveaux » : liste des niveaux, carte (pinceaux, redimensionnement, placement), monstres, objets, réglages.

const THEMES := [["stone", "Pierre (classique)"], ["dirt", "Pyramide"], ["damp", "Cachot humide"], ["ruins", "Ruines effondrées"], ["ice", "Glace"], ["lava", "Lave"], ["temple", "Temple ancien"]]
const DIRS := [[0, "Nord"], [1, "Est"], [2, "Sud"], [3, "Ouest"]]
const MAX_LEVELS := 8

static var _sel := ""
static var _tab := "map"
static var _brush := "."
static var _allow_rooms := false
## Cible de placement en cours : {kind: monster|item|merchant|start, id: String} ou vide.
static var _placement: Dictionary = {}

static func _levels() -> Array:
	return Data.config.get("levels", [])

static func _current() -> Dictionary:
	for l in _levels():
		if l.id == _sel:
			return l
	var ls := _levels()
	if ls.is_empty():
		return {}
	_sel = str(ls[0].id)
	return ls[0]

static func build(host: VBoxContainer, admin: Node) -> void:
	var lvl := _current()
	# ------------------------------------------------ liste des niveaux
	var lp := Form.panel(host, "Niveaux du donjon")
	var levels := _levels()
	for i in levels.size():
		var l: Dictionary = levels[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, l.get("name", "?")]
		b.toggle_mode = true
		b.button_pressed = l.id == _sel
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var lid: String = l.id
		b.pressed.connect(func():
			_sel = lid
			_placement = {}
			admin.refresh_tab())
		row.add_child(b)
		var idx := i
		for mv in [["↑", -1], ["↓", 1]]:
			var mb := Button.new()
			mb.text = mv[0]
			mb.focus_mode = Control.FOCUS_NONE
			var d: int = mv[1]
			mb.disabled = (idx + d < 0) or (idx + d >= levels.size())
			mb.pressed.connect(func():
				var tmp = levels[idx]
				levels[idx] = levels[idx + d]
				levels[idx + d] = tmp
				admin.refresh_tab())
			row.add_child(mb)
		lp.add_child(row)
	Form.buttons(lp, [["+ Ajouter un niveau", func(): _add_level(admin)]])
	if lvl.is_empty():
		return

	# ------------------------------------------------ éditeur du niveau
	var ep := Form.panel(host, "Édition du niveau")
	var name_edit := LineEdit.new()
	name_edit.text = str(lvl.get("name", ""))
	name_edit.custom_minimum_size = Vector2(300, 0)
	name_edit.text_changed.connect(func(t: String): lvl["name"] = t)
	name_edit.focus_exited.connect(func(): admin.refresh_tab())
	Form.row(ep, "Nom du niveau", name_edit)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for t in [["map", "Carte"], ["mon", "Monstres"], ["item", "Objets"], ["cfg", "Réglages"]]:
		var tb := Button.new()
		tb.text = t[1]
		tb.toggle_mode = true
		tb.button_group = group
		tb.button_pressed = _tab == t[0]
		tb.focus_mode = Control.FOCUS_NONE
		var id: String = t[0]
		tb.pressed.connect(func():
			_tab = id
			admin.refresh_tab())
		tabs.add_child(tb)
	ep.add_child(tabs)
	if not lvl.has("doors"):
		lvl["doors"] = []
	_ensure_stairs(lvl)
	if not lvl.has("monsters"):
		lvl["monsters"] = []
	if not lvl.has("items"):
		lvl["items"] = []
	match _tab:
		"map": _map_tab(ep, admin, lvl)
		"mon": _monsters_tab(ep, admin, lvl)
		"item": _items_tab(ep, admin, lvl)
		"cfg": _cfg_tab(ep, admin, lvl)
	var actions := Form.buttons(ep, [["Enregistrer la configuration par défaut", admin.save], ["Supprimer ce niveau", func(): _delete_level(admin)]])
	actions.add_theme_constant_override("separation", 10)

# ------------------------------------------------------------------ données

static func _ensure_stairs(lvl: Dictionary) -> void:
	if lvl.has("stairs"):
		return
	lvl["stairs"] = []
	var rows: Array = lvl.mapRows
	for y in rows.size():
		for x in str(rows[y]).length():
			if str(rows[y])[x] == "S":
				lvl.stairs.append({"id": "stairs_%d_%d" % [x, y], "x": x, "y": y, "action": {"type": "victory"}})

static func _add_level(admin: Node) -> void:
	if _levels().size() >= MAX_LEVELS:
		Dialogs.notice(admin.modals(), "Limite atteinte", "Un donjon ne peut pas dépasser %d niveaux." % MAX_LEVELS)
		return
	var rows: Array = []
	for y in 8:
		rows.append("#".repeat(8))
	var id := AdminUtil.new_id("lvl")
	_levels().append({"id": id, "name": "Nouveau niveau", "theme": "stone", "mapRows": rows, "startX": 1, "startY": 1, "startDir": 1, "stairs": [], "doors": [], "monsters": [], "items": []})
	_sel = id
	_tab = "map"
	admin.refresh_tab()

static func _delete_level(admin: Node) -> void:
	if _levels().size() <= 1:
		Dialogs.notice(admin.modals(), "Suppression impossible", "Il doit rester au moins un niveau.")
		return
	var go := func():
		var removed := _sel
		var ls := _levels()
		for i in range(ls.size() - 1, -1, -1):
			if ls[i].id == removed:
				ls.remove_at(i)
		for l in ls:
			for st in l.get("stairs", []):
				var a: Dictionary = st.get("action", {})
				if a.get("type") == "level" and a.get("targetId") == removed:
					st["action"] = {"type": "victory"}
		_sel = str(ls[0].id)
		admin.refresh_tab()
	Dialogs.confirm(admin.modals(), "Supprimer le niveau", "Supprimer ce niveau définitivement ?", go, "Supprimer")

static func _too_close_to_stairs(lvl: Dictionary, x: int, y: int, min_dist: int = 3) -> bool:
	var rows: Array = lvl.mapRows
	for sy in rows.size():
		for sx in str(rows[sy]).length():
			if str(rows[sy])[sx] == "S" and maxi(absi(sx - x), absi(sy - y)) < min_dist:
				return true
	return false

static func _would_make_room(lvl: Dictionary, x: int, y: int) -> bool:
	var rows: Array = lvl.mapRows
	var is_open := func(cx: int, cy: int) -> bool:
		if cx == x and cy == y:
			return true
		if cy < 0 or cy >= rows.size() or cx < 0 or cx >= str(rows[0]).length():
			return false
		return str(rows[cy])[cx] != "#"
	for dx in [-1, 0]:
		for dy in [-1, 0]:
			var bx: int = x + dx
			var by: int = y + dy
			if is_open.call(bx, by) and is_open.call(bx + 1, by) and is_open.call(bx, by + 1) and is_open.call(bx + 1, by + 1):
				return true
	return false

static func _find(list: Array, id: String) -> Dictionary:
	for e in list:
		if e.id == id:
			return e
	return {}

# ------------------------------------------------------------------ onglet Carte

static func _placement_name(lvl: Dictionary) -> String:
	match str(_placement.get("kind", "")):
		"monster": return str(_find(lvl.monsters, str(_placement.id)).get("name", "le monstre"))
		"item": return str(_find(lvl.items, str(_placement.id)).get("name", "l'objet"))
		"merchant": return "le marchand ambulant"
	return "le point de départ"

static func _map_tab(ep: VBoxContainer, admin: Node, lvl: Dictionary) -> void:
	if not _placement.is_empty():
		var banner := HBoxContainer.new()
		banner.add_theme_constant_override("separation", 10)
		banner.add_child(AdminUtil.label("Cliquez sur la carte pour placer : " + _placement_name(lvl), 15, UiTheme.GOLD))
		var cancel := Button.new()
		cancel.text = "Annuler"
		cancel.focus_mode = Control.FOCUS_NONE
		cancel.pressed.connect(func():
			_placement = {}
			admin.refresh_tab())
		banner.add_child(cancel)
		ep.add_child(banner)
	# dimensions
	var rows: Array = lvl.mapRows
	var dims := {"w": str(rows[0]).length(), "h": rows.size()}
	var dl := AdminUtil.flow(ep)
	AdminUtil.chip(dl, "Largeur (max 60)", AdminUtil.mini_number(dims, "w", 4, 60, 8))
	AdminUtil.chip(dl, "Hauteur (max 60)", AdminUtil.mini_number(dims, "h", 4, 60, 8))
	var resize := Button.new()
	resize.text = "Redimensionner"
	resize.focus_mode = Control.FOCUS_NONE
	resize.pressed.connect(func():
		var W := clampi(int(dims.w), 4, 60)
		var H := clampi(int(dims.h), 4, 60)
		var old: Array = lvl.mapRows
		var nr: Array = []
		for y in H:
			var row := ""
			for x in W:
				row += str(old[y])[x] if (y < old.size() and x < str(old[0]).length()) else "#"
			nr.append(row)
		lvl["mapRows"] = nr
		admin.refresh_tab())
	dl.add_child(resize)
	# pinceaux
	var bl := AdminUtil.flow(ep)
	bl.add_child(AdminUtil.label("Pinceau :", 14, UiTheme.DIM))
	var group := ButtonGroup.new()
	for br in [[".", "Sol"], ["#", "Mur"], ["D", "Porte"], ["S", "Escalier"]]:
		var b := Button.new()
		b.text = br[1]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = _brush == br[0]
		b.focus_mode = Control.FOCUS_NONE
		var ch: String = br[0]
		b.pressed.connect(func(): _brush = ch)
		bl.add_child(b)
	var cb := CheckBox.new()
	cb.text = "Autoriser les salles (test)"
	cb.tooltip_text = "Désactive temporairement la règle « couloirs d'une seule case de large »."
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = _allow_rooms
	cb.toggled.connect(func(on: bool): _allow_rooms = on)
	bl.add_child(cb)
	# grille
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := MapEditorGrid.new()
	scroll.add_child(grid)
	grid.set_level(lvl)
	ep.add_child(scroll)
	grid.cell_pressed.connect(func(x: int, y: int, badge: String): _on_press(admin, lvl, grid, x, y, badge))
	grid.cell_dragged.connect(func(x: int, y: int):
		if _placement.is_empty() and (_brush == "." or _brush == "#"):
			_paint(admin, lvl, grid, x, y))
	Form.hint(ep, "Cliquez ou faites glisser pour peindre. Les pastilles dans les coins indiquent un monstre (en haut à gauche) ou un objet (en bas à droite) : cliquez dessus pour le retirer du niveau.")

static func _on_press(admin: Node, lvl: Dictionary, grid: MapEditorGrid, x: int, y: int, badge: String) -> void:
	if not _placement.is_empty():
		_place(admin, lvl, x, y)
		return
	if badge.begins_with("mon:"):
		var id := badge.substr(4)
		var arr: Array = lvl.monsters
		for i in range(arr.size() - 1, -1, -1):
			if arr[i].id == id:
				arr.remove_at(i)
		grid.refresh()
		return
	if badge.begins_with("item:"):
		var id2 := badge.substr(5)
		var items: Array = lvl.items
		for i in range(items.size() - 1, -1, -1):
			if items[i].id == id2:
				items.remove_at(i)
		for m in lvl.monsters:
			if m.get("lootItemId") == id2:
				m["lootItemId"] = ""
			if m.get("lootItemId2") == id2:
				m["lootItemId2"] = ""
		grid.refresh()
		return
	_paint(admin, lvl, grid, x, y)

static func _place(admin: Node, lvl: Dictionary, x: int, y: int) -> void:
	var kind := str(_placement.get("kind", ""))
	match kind:
		"monster":
			if _too_close_to_stairs(lvl, x, y):
				admin.say("Un monstre ne peut pas être placé à moins de 3 cases d'un escalier : le joueur ne doit jamais tomber sur un combat en changeant de niveau.")
				return
			var m := _find(lvl.monsters, str(_placement.id))
			m["x"] = x
			m["y"] = y
		"item":
			var it := _find(lvl.items, str(_placement.id))
			it["x"] = x
			it["y"] = y
		"merchant":
			if not (lvl.get("travelingMerchant") is Dictionary):
				lvl["travelingMerchant"] = {"x": x, "y": y, "patrolRadius": 4, "lootSlotCount": 6, "lootItemIds": []}
			else:
				lvl.travelingMerchant["x"] = x
				lvl.travelingMerchant["y"] = y
		"start":
			lvl["startX"] = x
			lvl["startY"] = y
	_placement = {}
	admin.refresh_tab()

static func _paint(admin: Node, lvl: Dictionary, grid: MapEditorGrid, x: int, y: int) -> void:
	var rows: Array = lvl.mapRows
	if _brush == "." and not _allow_rooms and _would_make_room(lvl, x, y):
		admin.say("Impossible : cela créerait une salle de plusieurs cases de sol adjacentes. Les couloirs doivent rester larges d'une seule case.")
		return
	var row := str(rows[y])
	if row[x] == _brush:
		return
	rows[y] = row.substr(0, x) + _brush + row.substr(x + 1)
	var doors: Array = lvl.doors
	var stairs: Array = lvl.stairs
	for i in range(doors.size() - 1, -1, -1):
		if int(doors[i].x) == x and int(doors[i].y) == y:
			doors.remove_at(i)
	for i in range(stairs.size() - 1, -1, -1):
		if int(stairs[i].x) == x and int(stairs[i].y) == y:
			stairs.remove_at(i)
	if _brush == "D":
		doors.append({"id": "door_%d_%d_%d" % [x, y, Time.get_ticks_msec()], "x": x, "y": y, "locked": true})
	elif _brush == "S":
		stairs.append({"id": "stairs_%d_%d_%d" % [x, y, Time.get_ticks_msec()], "x": x, "y": y, "action": {"type": "victory"}})
	grid.refresh()

# ------------------------------------------------------------------ onglet Monstres

static func _loot_options(lvl: Dictionary) -> Array:
	var out: Array = [["", "— aucun —"]]
	for it in lvl.items:
		if str(it.get("type", "")) != "decor":
			out.append([it.id, AdminUtil.item_label(it)])
	return out

static func _monsters_tab(ep: VBoxContainer, admin: Node, lvl: Dictionary) -> void:
	var add_mon := func():
		lvl.monsters.append({"id": AdminUtil.new_id("mon"), "name": "Nouveau monstre", "icon": "@icon:mon_orc", "x": int(lvl.startX), "y": int(lvl.startY), "force": 8, "dex": 8, "con": 8, "speed": 8, "resistPhys": 0, "resistMagic": 0, "xpReward": 10, "goldReward": 5, "abilitySpellId": "", "abilityChance": 30, "enrageThreshold": 0, "patrolRadius": 3, "attackSpeed": 2, "opensDoorId": "", "startHidden": false, "isBoss": false, "lootItemId": "", "lootChance": 100, "lootItemId2": "", "lootChance2": 100})
		admin.refresh_tab()
	Form.buttons(ep, [["+ Ajouter un monstre", add_mon]])
	if (lvl.monsters as Array).is_empty():
		Form.hint(ep, "Aucun monstre sur ce niveau.")
	var damage_spells: Array = [["", "— attaque simple —"]]
	for s in Data.config.get("spells", []):
		if s.get("mode", "damage") == "damage":
			damage_spells.append([s.id, AdminUtil.spell_label(s)])
	for m in lvl.monsters:
		var b := Form.panel(ep, str(m.get("name", "Monstre")))
		var top := AdminUtil.flow(b)
		top.add_child(IconPicker.button(admin.modals(), m, "icon", Callable(), 36.0))
		var e := LineEdit.new()
		e.text = str(m.get("name", ""))
		e.custom_minimum_size = Vector2(190, 0)
		e.text_changed.connect(func(t: String): m["name"] = t)
		AdminUtil.chip(top, "Nom", e)
		top.add_child(AdminUtil.label("Position %d,%d" % [int(m.x), int(m.y)], 14, UiTheme.DIM))
		var place := Button.new()
		place.text = "Placer sur la carte"
		place.focus_mode = Control.FOCUS_NONE
		var mid: String = m.id
		place.pressed.connect(func():
			_placement = {"kind": "monster", "id": mid}
			_tab = "map"
			admin.refresh_tab())
		top.add_child(place)
		var rm := Button.new()
		rm.text = "Supprimer"
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(func():
			(lvl.monsters as Array).erase(m)
			admin.refresh_tab())
		top.add_child(rm)

		var st := AdminUtil.flow(b)
		var preview := AdminUtil.label("", 14, UiTheme.DIM)
		var upd := func():
			var hp := 5.0 + float(m.get("con", 8)) * 2.8
			var amin := maxi(1, int(floor(float(m.get("force", 8)) / 2.5)))
			var amax := amin + 1 + int(floor(float(m.get("dex", 8)) / 3.3))
			preview.text = "PV %d · Attaque %d-%d" % [int(hp), amin, amax]
		AdminUtil.chip(st, "Force", AdminUtil.mini_number(m, "force", 1, 999, 8, upd))
		AdminUtil.chip(st, "Dex", AdminUtil.mini_number(m, "dex", 1, 999, 8, upd))
		AdminUtil.chip(st, "Con", AdminUtil.mini_number(m, "con", 1, 999, 8, upd))
		var spd := AdminUtil.mini_number(m, "speed", 0, 99, 8)
		spd.tooltip_text = "Détermine l'ordre de passage dans la file d'initiative, pas la cadence d'attaque."
		AdminUtil.chip(st, "Vitesse", spd)
		st.add_child(preview)
		upd.call()
		var rs := AdminUtil.flow(b)
		AdminUtil.chip(rs, "Résist. phys. (%)", AdminUtil.mini_number(m, "resistPhys", 0, 100))
		AdminUtil.chip(rs, "Résist. magique (%)", AdminUtil.mini_number(m, "resistMagic", 0, 100))
		AdminUtil.chip(rs, "XP", AdminUtil.mini_number(m, "xpReward", 0, 99999, 10))
		AdminUtil.chip(rs, "Or", AdminUtil.mini_number(m, "goldReward", 0, 99999))
		var ab := AdminUtil.flow(b)
		var on_ab := func(v):
			m["abilitySpellId"] = v
			admin.refresh_tab()
		AdminUtil.chip(ab, "Capacité spéciale", AdminUtil.dropdown(damage_spells, m.get("abilitySpellId", ""), on_ab, 240.0))
		if str(m.get("abilitySpellId", "")) != "":
			AdminUtil.chip(ab, "Chance (%)", AdminUtil.mini_number(m, "abilityChance", 0, 100, 30))
		AdminUtil.chip(ab, "Rage à PV (%)", AdminUtil.mini_number(m, "enrageThreshold", 0, 100))
		AdminUtil.chip(ab, "Rayon de patrouille", AdminUtil.mini_number(m, "patrolRadius", 0, 20))
		var sp := HBoxContainer.new()
		var slider := HSlider.new()
		slider.min_value = 1.0
		slider.max_value = 3.0
		slider.step = 0.1
		slider.value = float(m.get("attackSpeed", 2))
		slider.custom_minimum_size = Vector2(130, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sl := AdminUtil.label("%.1f s" % slider.value, 14)
		slider.value_changed.connect(func(v: float):
			m["attackSpeed"] = v
			sl.text = "%.1f s" % v)
		sp.add_theme_constant_override("separation", 6)
		sp.add_child(slider)
		sp.add_child(sl)
		sp.tooltip_text = "Temps entre deux attaques automatiques."
		AdminUtil.chip(ab, "Cadence d'attaque", sp)
		var on_door := func(v): m["opensDoorId"] = v
		AdminUtil.chip(ab, "Ouvre à sa mort", AdminUtil.dropdown(AdminItems.door_options(lvl), m.get("opensDoorId", ""), on_door, 190.0))
		var lo := AdminUtil.flow(b)
		var lopts := _loot_options(lvl)
		var on_l1 := func(v): m["lootItemId"] = v
		var on_l2 := func(v): m["lootItemId2"] = v
		AdminUtil.chip(lo, "Butin 1", AdminUtil.dropdown(lopts, m.get("lootItemId", ""), on_l1, 200.0))
		AdminUtil.chip(lo, "Chance (%)", AdminUtil.mini_number(m, "lootChance", 0, 100, 100))
		AdminUtil.chip(lo, "Butin 2", AdminUtil.dropdown(lopts, m.get("lootItemId2", ""), on_l2, 200.0))
		AdminUtil.chip(lo, "Chance (%)", AdminUtil.mini_number(m, "lootChance2", 0, 100, 100))
		var fl := AdminUtil.flow(b)
		var boss := CheckBox.new()
		boss.text = "Boss"
		boss.tooltip_text = "Monstre de fin de niveau, affichage imposant (incompatible avec un groupe)."
		boss.focus_mode = Control.FOCUS_NONE
		boss.button_pressed = bool(m.get("isBoss", false))
		boss.disabled = bool(m.get("isGroup", false))
		boss.toggled.connect(func(on: bool):
			m["isBoss"] = on
			if on:
				m["isGroup"] = false
			admin.refresh_tab())
		fl.add_child(boss)
		var grp := CheckBox.new()
		grp.text = "Groupe"
		grp.tooltip_text = "Apparaît en groupe de 2 ou 3 exemplaires (incompatible avec un boss)."
		grp.focus_mode = Control.FOCUS_NONE
		grp.button_pressed = bool(m.get("isGroup", false))
		grp.disabled = bool(m.get("isBoss", false))
		grp.toggled.connect(func(on: bool):
			m["isGroup"] = on
			if on:
				m["isBoss"] = false
				if not m.has("groupSize"):
					m["groupSize"] = 2
			admin.refresh_tab())
		fl.add_child(grp)
		if bool(m.get("isGroup", false)):
			var on_gs := func(v): m["groupSize"] = int(v)
			AdminUtil.chip(fl, "Taille", AdminUtil.dropdown([[2, "2"], [3, "3"]], m.get("groupSize", 2), on_gs, 70.0))
		Form.check(fl, "Caché (révélé par un interrupteur)", m, "startHidden")

# ------------------------------------------------------------------ onglet Objets

static func _items_tab(ep: VBoxContainer, admin: Node, lvl: Dictionary) -> void:
	var add_item := func():
		lvl.items.append({"id": AdminUtil.new_id("item"), "name": "Nouvel objet", "icon": "@icon:potion_heal", "x": int(lvl.startX), "y": int(lvl.startY), "type": "potion", "heal": 5, "startHidden": false})
		admin.refresh_tab()
	Form.buttons(ep, [["+ Ajouter un objet", add_item]])
	var any := false
	for it in lvl.items:
		if str(it.get("type", "")) == "decor":
			continue
		any = true
		var b := Form.panel(ep, str(it.get("name", "Objet")))
		var top := AdminUtil.flow(b)
		top.add_child(IconPicker.button(admin.modals(), it, "icon", Callable(), 36.0))
		var e := LineEdit.new()
		e.text = str(it.get("name", ""))
		e.custom_minimum_size = Vector2(190, 0)
		e.text_changed.connect(func(t: String): it["name"] = t)
		AdminUtil.chip(top, "Nom", e)
		var on_type := func(v):
			it["type"] = v
			admin.refresh_tab()
		AdminUtil.chip(top, "Type", AdminUtil.dropdown(AdminItems.LEVEL_TYPES, it.get("type", "potion"), on_type, 150.0))
		top.add_child(AdminUtil.label("Position %d,%d" % [int(it.x), int(it.y)], 14, UiTheme.DIM))
		var place := Button.new()
		place.text = "Placer sur la carte"
		place.focus_mode = Control.FOCUS_NONE
		var iid: String = it.id
		place.pressed.connect(func():
			_placement = {"kind": "item", "id": iid}
			_tab = "map"
			admin.refresh_tab())
		top.add_child(place)
		var rm := Button.new()
		rm.text = "Supprimer"
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(func():
			(lvl.items as Array).erase(it)
			for m in lvl.monsters:
				if m.get("lootItemId") == iid:
					m["lootItemId"] = ""
				if m.get("lootItemId2") == iid:
					m["lootItemId2"] = ""
			admin.refresh_tab())
		top.add_child(rm)
		AdminItems.fields(b, it, admin, lvl)
		Form.check(b, "Caché tant qu'un interrupteur ne le révèle pas (ou réservé au butin d'un monstre)", it, "startHidden")
	if not any:
		Form.hint(ep, "Aucun objet sur ce niveau.")

# ------------------------------------------------------------------ onglet Réglages

static func _slider(parent: Control, label: String, target: Dictionary, key: String, lo: float, hi: float, def: float) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(target.get(key, def)) if target.get(key) != null else def
	s.custom_minimum_size = Vector2(200, 0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := AdminUtil.label("%.2f" % s.value, 14)
	s.value_changed.connect(func(x: float):
		target[key] = x
		v.text = "%.2f" % x)
	h.add_child(s)
	h.add_child(v)
	Form.row(parent, label, h)

static func _cfg_tab(ep: VBoxContainer, admin: Node, lvl: Dictionary) -> void:
	var on_theme := func(v): lvl["theme"] = v
	Form.row(ep, "Thème visuel", AdminUtil.dropdown(THEMES, lvl.get("theme", "stone"), on_theme, 240.0))
	_slider(ep, "Lumière ambiante", lvl, "lightAmbient", 0.1, 1.6, 1.1)
	_slider(ep, "Intensité des torches", lvl, "lightTorch", 0.2, 2.6, 1.4)
	var sf := AdminUtil.flow(ep)
	AdminUtil.chip(sf, "Départ X", AdminUtil.mini_number(lvl, "startX", 0, 59, 1))
	AdminUtil.chip(sf, "Y", AdminUtil.mini_number(lvl, "startY", 0, 59, 1))
	var on_dir := func(v): lvl["startDir"] = int(v)
	AdminUtil.chip(sf, "Direction", AdminUtil.dropdown(DIRS, int(lvl.get("startDir", 1)), on_dir, 110.0))
	var pick := Button.new()
	pick.text = "Choisir le départ sur la carte"
	pick.focus_mode = Control.FOCUS_NONE
	pick.pressed.connect(func():
		_placement = {"kind": "start"}
		_tab = "map"
		admin.refresh_tab())
	sf.add_child(pick)

	ep.add_child(AdminUtil.label("Escaliers de ce niveau", 15, UiTheme.GOLD))
	var stairs: Array = lvl.stairs
	if stairs.is_empty():
		Form.hint(ep, "Aucun escalier sur ce niveau pour l'instant. Peignez un escalier sur la carte, puis choisissez sa destination ici.")
	var others: Array = []
	for l in _levels():
		if l.id != lvl.id:
			others.append([l.id, str(l.get("name", "?"))])
	for st in stairs:
		var box := Form.panel(ep, "Escalier en (%d,%d)" % [int(st.x), int(st.y)])
		var act: Dictionary = Form.sub(st, "action")
		var on_type := func(v):
			if v == "victory":
				st["action"] = {"type": "victory"}
			else:
				st["action"] = {"type": "level", "targetId": others[0][0] if not others.is_empty() else ""}
			admin.refresh_tab()
		Form.row(box, "Action", AdminUtil.dropdown([["victory", "Terminer la partie (victoire)"], ["level", "Aller vers un autre niveau"]], act.get("type", "victory"), on_type, 280.0))
		if act.get("type") == "level":
			var on_target := func(v): act["targetId"] = v
			Form.row(box, "Niveau cible", AdminUtil.dropdown(others, act.get("targetId", ""), on_target, 260.0))
			var af := AdminUtil.flow(box)
			for k in [["Arrivée X", "targetX"], ["Y", "targetY"]]:
				var key: String = k[1]
				var le := LineEdit.new()
				le.placeholder_text = "départ"
				le.custom_minimum_size = Vector2(80, 0)
				le.text = str(act[key]) if act.has(key) and str(act[key]) != "" else ""
				le.text_changed.connect(func(t: String):
					if t.strip_edges() == "":
						act.erase(key)
					elif t.strip_edges().is_valid_int():
						act[key] = int(t))
				AdminUtil.chip(af, k[0], le)
			var dir_opts: Array = [["", "Par défaut du niveau"]]
			for d in DIRS:
				dir_opts.append([str(d[0]), d[1]])
			var cur_dir := ""
			if act.has("targetDir") and str(act.targetDir) != "":
				cur_dir = str(int(act.targetDir))
			var on_td := func(v):
				if v == "":
					act.erase("targetDir")
				else:
					act["targetDir"] = int(v)
			AdminUtil.chip(af, "Direction d'arrivée", AdminUtil.dropdown(dir_opts, cur_dir, on_td, 190.0))
			Form.hint(box, "Laissez X/Y vides pour arriver au point de départ du niveau. Pour un aller-retour, ajoutez un second escalier dans le niveau cible réglé pour revenir ici.")

	ep.add_child(AdminUtil.label("Marchand ambulant", 15, UiTheme.GOLD))
	var tm = lvl.get("travelingMerchant")
	if not (tm is Dictionary):
		Form.hint(ep, "Aucun marchand sur ce niveau.")
		var add_tm := func():
			lvl["travelingMerchant"] = {"x": int(lvl.startX), "y": int(lvl.startY), "patrolRadius": 4, "lootSlotCount": 6, "lootItemIds": []}
			admin.refresh_tab()
		Form.buttons(ep, [["Ajouter un marchand ambulant sur ce niveau", add_tm]])
		return
	var mf := AdminUtil.flow(ep)
	mf.add_child(AdminUtil.label("Position %d,%d" % [int(tm.x), int(tm.y)], 14, UiTheme.DIM))
	var pm := Button.new()
	pm.text = "Placer sur la carte"
	pm.focus_mode = Control.FOCUS_NONE
	pm.pressed.connect(func():
		_placement = {"kind": "merchant"}
		_tab = "map"
		admin.refresh_tab())
	mf.add_child(pm)
	AdminUtil.chip(mf, "Rayon de patrouille", AdminUtil.mini_number(tm, "patrolRadius", 0, 30, 4))
	var count := 8 if int(tm.get("lootSlotCount", 6)) == 8 else 6
	var on_cnt := func(v):
		tm["lootSlotCount"] = int(v)
		admin.refresh_tab()
	AdminUtil.chip(mf, "Objets en vente", AdminUtil.dropdown([[6, "6"], [8, "8"]], count, on_cnt, 70.0))
	Form.hint(ep, "Emplacements laissés vides : le marchand proposera un objet aléatoire à la place, comme le marchand itinérant généré automatiquement.")
	if not (tm.get("lootItemIds") is Array):
		tm["lootItemIds"] = []
	var ids: Array = tm.lootItemIds
	var lib: Array = [["", "— vide —"]]
	for it in Data.config.get("itemLibrary", []):
		lib.append([it.id, AdminUtil.item_label(it)])
	var sf2 := AdminUtil.flow(ep)
	for i in count:
		var slot := i
		while ids.size() <= slot:
			ids.append("")
		var on_slot := func(v): ids[slot] = v
		AdminUtil.chip(sf2, "Emplacement %d" % (i + 1), AdminUtil.dropdown(lib, ids[slot], on_slot, 220.0))
	var rm_tm := func():
		lvl["travelingMerchant"] = null
		admin.refresh_tab()
	Form.buttons(ep, [["Retirer le marchand de ce niveau", rm_tm]])
