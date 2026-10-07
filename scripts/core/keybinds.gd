class_name Keybinds
extends RefCounted
## Touches du clavier : une action = jusqu'à 2 touches. Par défaut AZERTY en français (Z Q S D) et QWERTY en anglais (W A S D) ;
## chaque touche peut être changée dans Paramètres › Commandes (mémorisé dans user://settings.cfg, section [keys]).
## Une action jamais modifiée suit la langue du jeu ; une action modifiée garde le choix du joueur dans les deux langues.
## Les touches sont les touches « logiques » (celles qui s'impriment sur le clavier), sauf les chiffres de la rangée du haut :
## la touche « 1 » se reconnaît sans Maj, même sur AZERTY.

const CFG := "user://settings.cfg"
const SECTION := "keys"
const SLOTS := 2
const GROUPS := ["move", "combat", "interface"]

## id, groupe, touches par défaut en français et en anglais. Échap (fermer / annuler) et Alt+Entrée (plein écran) sont fixes.
const ACTIONS := [
	{"id": "forward", "group": "move", "fr": [KEY_Z, KEY_UP], "en": [KEY_W, KEY_UP]},
	{"id": "back", "group": "move", "fr": [KEY_S, KEY_DOWN], "en": [KEY_S, KEY_DOWN]},
	{"id": "turn_left", "group": "move", "fr": [KEY_Q, KEY_LEFT], "en": [KEY_A, KEY_LEFT]},
	{"id": "turn_right", "group": "move", "fr": [KEY_D, KEY_RIGHT], "en": [KEY_D, KEY_RIGHT]},
	{"id": "strafe_left", "group": "move", "fr": [KEY_A], "en": [KEY_Q]},
	{"id": "strafe_right", "group": "move", "fr": [KEY_E], "en": [KEY_E]},
	{"id": "attack", "group": "combat", "fr": [KEY_SPACE, KEY_X], "en": [KEY_SPACE, KEY_X]},
	{"id": "interact", "group": "combat", "fr": [KEY_F, KEY_ENTER], "en": [KEY_F, KEY_ENTER]},
	{"id": "flee", "group": "combat", "fr": [KEY_C], "en": [KEY_C]},
	{"id": "slot_1", "group": "combat", "fr": [KEY_1], "en": [KEY_1]},
	{"id": "slot_2", "group": "combat", "fr": [KEY_2], "en": [KEY_2]},
	{"id": "slot_3", "group": "combat", "fr": [KEY_3], "en": [KEY_3]},
	{"id": "slot_4", "group": "combat", "fr": [KEY_4], "en": [KEY_4]},
	{"id": "slot_5", "group": "combat", "fr": [KEY_5], "en": [KEY_5]},
	{"id": "slot_6", "group": "combat", "fr": [KEY_6], "en": [KEY_6]},
	{"id": "slot_7", "group": "combat", "fr": [KEY_7], "en": [KEY_7]},
	{"id": "inventory", "group": "interface", "fr": [KEY_I], "en": [KEY_I]},
	{"id": "map", "group": "interface", "fr": [KEY_M], "en": [KEY_M]},
	{"id": "perf", "group": "interface", "fr": [KEY_F3], "en": [KEY_F3]},
	{"id": "fullscreen", "group": "interface", "fr": [KEY_F11], "en": [KEY_F11]},
]

## Noms affichés des touches spéciales : [français, anglais]. Les autres viennent du moteur (« Z », « F3 »…).
const NAMES := {
	KEY_UP: ["↑", "↑"], KEY_DOWN: ["↓", "↓"], KEY_LEFT: ["←", "←"], KEY_RIGHT: ["→", "→"],
	KEY_SPACE: ["Espace", "Space"], KEY_ENTER: ["Entrée", "Enter"], KEY_TAB: ["Tab", "Tab"],
	KEY_BACKSPACE: ["Retour arrière", "Backspace"], KEY_DELETE: ["Suppr", "Delete"], KEY_INSERT: ["Inser", "Insert"],
	KEY_HOME: ["Début", "Home"], KEY_END: ["Fin", "End"], KEY_PAGEUP: ["Page ↑", "Page Up"], KEY_PAGEDOWN: ["Page ↓", "Page Down"],
}
const MODIFIERS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK]

static var cfg_path: String = CFG       # modifiable (tests)
static var lang_override: String = ""   # « fr » ou « en » (tests) ; vide : langue du jeu
static var _custom: Dictionary = {}     # action -> [touche, touche] (0 = vide), seulement pour les actions modifiées
static var _loaded: bool = false

# ------------------------------------------------------------------ lecture

static func ids() -> Array:
	var out: Array = []
	for a in ACTIONS:
		out.append(a.id)
	return out

static func group_of(id: String) -> String:
	for a in ACTIONS:
		if a.id == id:
			return a.group
	return ""

static func lang() -> String:
	if lang_override != "":
		return lang_override
	return "en" if str(Data.lang) == "en" else "fr"

static func defaults(id: String) -> Array:
	var out: Array = []
	for a in ACTIONS:
		if a.id == id:
			out = (a[lang()] as Array).duplicate()
	while out.size() < SLOTS:
		out.append(0)
	return out

static func is_custom(id: String) -> bool:
	_load()
	return _custom.has(id)

## Touches de l'action (SLOTS valeurs, 0 = emplacement vide).
static func slots(id: String) -> Array:
	_load()
	if _custom.has(id):
		return (_custom[id] as Array).duplicate()
	return defaults(id)

## Touches affichables de l'action, sans les emplacements vides.
static func keys(id: String) -> Array:
	var out: Array = []
	for c in slots(id):
		if int(c) != 0:
			out.append(int(c))
	return out

## « Z / ↑ » ; « — » si aucune touche.
static func text(id: String) -> String:
	var parts: Array = []
	for c in keys(id):
		parts.append(label(int(c)))
	return " / ".join(parts) if not parts.is_empty() else "—"

static func label(code: int) -> String:
	if code == 0:
		return "—"
	if NAMES.has(code):
		return str(NAMES[code][0 if lang() == "fr" else 1])
	return OS.get_keycode_string(code as Key)

## Code mémorisé pour un événement clavier : touche logique, chiffre de la rangée du haut tel quel, Entrée du pavé = Entrée.
static func code_of(ev: InputEventKey) -> int:
	var phys: int = ev.physical_keycode
	if phys >= KEY_0 and phys <= KEY_9:
		return phys
	var k: int = ev.keycode if ev.keycode != KEY_NONE else phys
	if k == KEY_KP_ENTER:
		return KEY_ENTER
	return k

static func is_modifier(code: int) -> bool:
	return MODIFIERS.has(code)

static func matches(id: String, ev: InputEventKey) -> bool:
	if ev.alt_pressed or ev.ctrl_pressed or ev.meta_pressed:
		return false
	var c := code_of(ev)
	return c != 0 and slots(id).has(c)

## Première action liée à la touche de l'événement, ou "".
static func action_for(ev: InputEventKey) -> String:
	if ev.alt_pressed or ev.ctrl_pressed or ev.meta_pressed:
		return ""
	var c := code_of(ev)
	if c == 0:
		return ""
	for a in ACTIONS:
		if slots(a.id).has(c):
			return str(a.id)
	return ""

# ------------------------------------------------------------------ modification

## Lie `code` à l'emplacement `slot` de l'action. La touche est retirée des autres actions qui l'utilisaient ;
## renvoie leurs identifiants (pour prévenir le joueur).
static func assign(id: String, slot: int, code: int) -> Array:
	_load()
	var lost: Array = []
	for other in ids():
		if other == id:
			continue
		var s := slots(other)
		var hit := false
		for i in SLOTS:
			if int(s[i]) == code:
				s[i] = 0
				hit = true
		if hit:
			_store(other, s)
			lost.append(other)
	var cur := slots(id)
	for i in SLOTS:
		if i != slot and int(cur[i]) == code:
			cur[i] = 0
	cur[clampi(slot, 0, SLOTS - 1)] = code
	_store(id, cur)
	_save()
	return lost

static func clear_slot(id: String, slot: int) -> void:
	_load()
	var cur := slots(id)
	cur[clampi(slot, 0, SLOTS - 1)] = 0
	_store(id, cur)
	_save()

static func reset(id: String) -> void:
	_load()
	_custom.erase(id)
	_save()

static func reset_all() -> void:
	_load()
	_custom.clear()
	_save()

## Mémorise l'action ; si elle redevient identique aux touches par défaut, elle suit de nouveau la langue.
static func _store(id: String, s: Array) -> void:
	if s == defaults(id):
		_custom.erase(id)
	else:
		_custom[id] = s

# ------------------------------------------------------------------ fichier

static func reload() -> void:
	_loaded = false
	_load()

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_custom = {}
	var cf := ConfigFile.new()
	if cf.load(cfg_path) != OK or not cf.has_section(SECTION):
		return
	for id in ids():
		if not cf.has_section_key(SECTION, id):
			continue
		var v: Variant = cf.get_value(SECTION, id)
		if v is Array:
			var a: Array = []
			for i in SLOTS:
				a.append(int(v[i]) if i < (v as Array).size() else 0)
			_custom[id] = a

static func _save() -> void:
	var cf := ConfigFile.new()
	cf.load(cfg_path)   # garde les autres sections (graphismes, son…)
	if cf.has_section(SECTION):
		cf.erase_section(SECTION)
	for id in _custom:
		cf.set_value(SECTION, id, _custom[id])
	cf.save(cfg_path)
