class_name NotifDot
extends Control
## Petite bulle rouge « nouveau message » posée dans le coin d'un bouton. Affiche le nombre (9+ au-delà) ; invisible à zéro.
## `count_fn` : fonction sans argument qui renvoie le nombre à montrer (par défaut, tous les messages non lus du tchat).

var count_fn: Callable = Callable()
var refresh_fn: Callable = Callable()   ## optionnel, asynchrone : met à jour la source de `count_fn` (au départ, puis toutes les minutes)
var _n := 0

## Ajoute une bulle en haut à droite de `target` (bouton). Renvoie la bulle.
static func attach(target: Control, fn: Callable = Callable(), small: bool = false, refresh: Callable = Callable()) -> NotifDot:
	var d := NotifDot.new()
	d.count_fn = fn
	d.refresh_fn = refresh
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.anchor_left = 1.0
	d.anchor_right = 1.0
	d.anchor_top = 0.0
	d.anchor_bottom = 0.0
	var s := 12.0 if small else 18.0
	d.offset_left = -s * 0.7
	d.offset_right = s * 0.3
	d.offset_top = -s * 0.3
	d.offset_bottom = s * 0.7
	target.add_child(d)
	return d

func _poll() -> void:
	await refresh_fn.call()
	if is_instance_valid(self) and is_inside_tree():
		_update()

func _ready() -> void:
	if refresh_fn.is_valid():                       # pastille à source propre (ex. super admin) : pas de surveillance du tchat
		var t := Timer.new()
		t.wait_time = 60.0
		t.timeout.connect(_poll)
		add_child(t)
		t.start()
		_poll()
		_update()
		return
	ChatAlerts.watch(true)
	ChatAlerts.changed.connect(_update)
	tree_exiting.connect(func(): ChatAlerts.watch(false))
	_update()
	if Cloud.is_signed_in() and not Cloud._transport.is_valid():
		ChatAlerts.refresh()

func _update() -> void:
	_n = int(count_fn.call()) if count_fn.is_valid() else ChatAlerts.effective()
	visible = _n > 0
	queue_redraw()

func _draw() -> void:
	if _n <= 0:
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, Color("1a0b08"))
	draw_circle(c, r - 1.5, Color("e5392b"))
	if size.x >= 16.0:
		var font := ThemeDB.fallback_font
		var t := str(_n) if _n < 10 else "9+"
		var fs := int(r * 1.05)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
