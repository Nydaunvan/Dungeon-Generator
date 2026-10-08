extends CanvasLayer
## Chargement du jeu (autoload `Loader`).
## - `boot()` : au lancement, charge tout (polices, images, textures de thèmes, sons et musiques) derrière l'écran de chargement ;
##   sur le Web, attend ensuite un geste de l'utilisateur (les navigateurs ne laissent sortir le son qu'à partir de là).
## - `go(scène, genre)` : changement de scène derrière l'écran de chargement ; la partie (`main.gd`) rend compte de son avancement
##   avec `step()` puis termine par `finish()`.

const ASSET_DIRS := ["home", "ui", "themes", "icons", "monsters", "portraits", "sheets", "misc"]
const IMAGE_EXT := ["png", "jpg", "jpeg", "webp"]
const HOME_SCENE := "res://scenes/home.tscn"

var screen: LoadingScreen
var booted := false
var _busy := false
var _keep: Array = []          # garde les ressources chargées en mémoire (le cache de Godot ne retient pas les ressources inutilisées)
var _token := 0
var _last_yield_us := 0
var _fade: Tween
var _f0 := 1.0                 # facteur d'échelle de l'interface au moment où l'écran apparaît

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

## Le jeu change l'échelle de l'interface en cours de chargement : on la compense pour que l'écran garde exactement la même taille.
func _process(_delta: float) -> void:
	if visible and screen != null:
		_fit()

func _fit() -> void:
	var win := get_window()
	var f := maxf(win.content_scale_factor, 0.001)
	var base := minf(win.size.x / 1280.0, win.size.y / 720.0)
	scale = Vector2.ONE * (_f0 / f)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.position = Vector2.ZERO
	screen.size = Vector2(win.size) / maxf(base * _f0, 0.001)

func is_active() -> bool:
	return _busy

# ------------------------------------------------------------------ écran

func _show(subtitle: String) -> void:
	# écran neuf à chaque chargement : aucun reste du précédent (barre, texte, fondu en cours)
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if screen != null:
		screen.queue_free()
	screen = LoadingScreen.new()
	add_child(screen)
	screen.set_subtitle(subtitle)
	_f0 = get_window().content_scale_factor
	_fit()
	visible = true
	_busy = true
	_token += 1

func _hide(fade: float = 0.4) -> void:
	_busy = false
	if screen == null or not visible:
		return
	var token := _token
	_fade = create_tween()
	_fade.tween_property(screen, "modulate:a", 0.0, fade)
	await _fade.finished
	if token == _token and not _busy:
		visible = false

## Rend la main à l'affichage dès que ~8 ms de calcul se sont écoulées (écran de chargement fluide).
func _slice() -> void:
	if Time.get_ticks_usec() - _last_yield_us > 8000:
		await get_tree().process_frame
		_last_yield_us = Time.get_ticks_usec()

## Pour le code qui travaille longtemps : `await Loader.slice()` rend la main à l'affichage (donc à l'épée) toutes les ~8 ms.
func slice() -> void:
	await _slice()

func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame

# ------------------------------------------------------------------ démarrage du programme

func boot() -> void:
	Sound.menu_music(true, 2.0)   # bureau : dès le lancement ; Web : à l'entrée (premier clic)
	_show(L.t("loading.sous_titre_jeu"))
	await _frames(2)
	var web := OS.has_feature("web")
	# poids de chaque étape dans la barre : les sons (synthétisés par le code) sont de loin les plus longs
	var phases := [
		{"label": L.t("loading.polices"), "w": 0.04},
		{"label": L.t("loading.images"), "w": 0.17},
		{"label": L.t("loading.moteur"), "w": 0.12},
		{"label": L.t("loading.decor"), "w": 0.04},
		{"label": L.t("loading.shaders"), "w": 0.08},
		{"label": L.t("loading.sons_effets"), "w": 0.55},
	]
	var base := 0.0
	# 1. polices
	screen.set_progress(base, phases[0].label)
	await _load_fonts()
	base += float(phases[0].w)
	# 2. images
	screen.set_progress(base, phases[1].label)
	await _load_images(base, float(phases[1].w))
	base += float(phases[1].w)
	# 3. code du jeu : tous les scripts et les scènes sont compilés maintenant, pas au premier clic sur « Jouer »
	screen.set_progress(base, phases[2].label)
	await _preload_code(base, float(phases[2].w))
	base += float(phases[2].w)
	# 4. textures procédurales et matériaux des thèmes
	screen.set_progress(base, phases[3].label)
	await _build_decor()
	base += float(phases[3].w)
	# 5. shaders : une mini-scène (murs, portes, torches, fontaine, monstres, sorts) est dessinée hors écran une fois
	screen.set_progress(base, phases[4].label)
	await WarmUp.run(self, func(f: float): screen.set_progress(base + float(phases[4].w) * f))
	base += float(phases[4].w)
	# 6. sons et musiques
	var sound_w := float(phases[5].w)
	await Sound.preload_all(func(f: float, text: String):
		screen.set_progress(base + sound_w * f, text))
	screen.set_progress(1.0, L.t("loading.pret"))
	while not screen.is_full():
		await get_tree().process_frame
	await _check_updates()
	if web:
		screen.show_gate()
		await screen.entered
		Sound.unlock()
	else:
		await get_tree().create_timer(0.25).timeout
	booted = true

## Recherche de mise à jour au lancement (Windows et Linux) : sablier derrière lequel le jeu interroge GitHub ; s'il y a du
## nouveau, la fenêtre s'affiche au-dessus de l'écran de chargement et le jeu attend la réponse du joueur ; sinon on continue.
func _check_updates() -> void:
	if not Updater.can_self_update() or not bool(Updater.pref("auto_check", true)):
		return
	screen.show_hourglass(L.t("ui.update.recherche"))
	var u := Updater.new()
	add_child(u)
	var t0 := Time.get_ticks_msec()
	var got: Array = []
	u.check_done.connect(func(d: Dictionary): got.append(d))
	u.check()
	while got.is_empty():
		await get_tree().process_frame
	var r: Dictionary = got[0]
	u.queue_free()
	var left := 900 - (Time.get_ticks_msec() - t0)      # le sablier reste visible au moins un instant
	if left > 0:
		await get_tree().create_timer(left / 1000.0).timeout
	screen.hide_hourglass()
	if r.is_empty() or r.has("error"):
		return
	var host := CanvasLayer.new()
	host.layer = layer + 50
	get_tree().root.add_child(host)
	var m := UpdateModal.open(host, r)
	await m.closed

## Après le chargement initial : bascule vers l'accueil puis lève le rideau.
func finish_boot() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)
	await _frames(3)
	_hide(0.5)

# ------------------------------------------------------------------ changements de scène

## Change de scène derrière l'écran de chargement. genre : "game" (nouvelle partie), "save" (partie chargée), "admin", "home".
func go(path: String, kind: String = "game") -> void:
	if _busy:
		return
	_show(_subtitle(kind))
	Sound.menu_music(kind == "home" or kind == "admin", 1.0)
	await _frames(2)
	screen.set_progress(0.04)
	get_tree().change_scene_to_file(path)
	if kind == "game" or kind == "save":
		var token := _token
		# garde-fou : si la scène de jeu ne rend jamais la main, on ne laisse pas l'écran bloqué
		await get_tree().create_timer(60.0).timeout
		if _busy and token == _token:
			_hide(0.3)
	else:
		await _frames(3)
		screen.set_progress(1.0)
		await get_tree().create_timer(0.15).timeout
		_hide(0.3)

func _subtitle(kind: String) -> String:
	match kind:
		"game": return L.t("loading.sous_titre_partie")
		"save": return L.t("loading.sous_titre_sauvegarde")
		"admin": return L.t("loading.sous_titre_editeur")
		"home": return L.t("loading.sous_titre_accueil")
	return L.t("loading.sous_titre_jeu")

## Précise le genre de chargement en cours (ex. partie chargée depuis une sauvegarde).
func set_kind(kind: String) -> void:
	if _busy and screen != null:
		screen.set_subtitle(_subtitle(kind))

## Avancement du chargement de la partie (appelé par main.gd). Sans effet hors chargement.
func step(v: float, text: String = "") -> void:
	if not _busy or screen == null:
		return
	screen.set_progress(v, text)
	await _frames(2)

## La partie est prête : l'écran de chargement s'efface.
func finish() -> void:
	if not _busy or screen == null:
		return
	screen.set_progress(1.0, L.t("loading.pret"))
	# quelques images derrière l'écran : les premières compilations de shaders se font ici, pas devant le joueur
	await _frames(5)
	_hide(0.45)

# ------------------------------------------------------------------ étapes de chargement

func _load_fonts() -> void:
	var names := _list("res://assets/fonts", ["ttf", "otf"])
	for n in names:
		UiTheme.font("res://assets/fonts/" + n)
		await _slice()

func _load_images(base: float, weight: float) -> void:
	var paths: Array = []
	for d in ASSET_DIRS:
		for n in _list("res://assets/" + d, IMAGE_EXT):
			paths.append("res://assets/%s/%s" % [d, n])
	var total := maxi(paths.size(), 1)
	for i in paths.size():
		var res := load(paths[i])
		if res != null:
			_keep.append(res)
		screen.set_progress(base + weight * float(i + 1) / total)
		await _slice()
	screen.set_progress(base + weight)

## Compile chaque script du jeu puis charge les scènes principales, un fichier à la fois (l'écran reste animé).
func _preload_code(base: float, weight: float) -> void:
	var paths: Array = []
	_collect("res://scripts", ["gd"], paths)
	for sc in ["main", "admin", "home"]:
		paths.append("res://scenes/%s.tscn" % sc)
	var total := maxi(paths.size(), 1)
	for i in paths.size():
		var res := load(paths[i])
		if res != null:
			_keep.append(res)
		screen.set_progress(base + weight * float(i + 1) / total)
		await _slice()

func _collect(dir: String, exts: Array, out: Array) -> void:
	for n in ResourceLoader.list_directory(dir):
		var name := String(n)
		if name.ends_with("/"):
			_collect(dir + "/" + name.trim_suffix("/"), exts, out)
			continue
		for suf in [".import", ".remap"]:
			if name.ends_with(suf):
				name = name.trim_suffix(suf)
		var path := dir + "/" + name
		if exts.has(name.get_extension().to_lower()) and not out.has(path):
			out.append(path)

func _build_decor() -> void:
	_keep.append(ProceduralTextures.glow())
	_keep.append(ProceduralTextures.smoke())
	_keep.append(ProceduralTextures.flame())
	_keep.append(ProceduralTextures.arch())
	await _slice()
	for theme in ["stone", "dirt", "damp", "ruins", "ice", "lava", "temple"]:
		_keep.append(ThemeMaterials.for_theme(theme))
		_keep.append(ProceduralTextures.grille_material(theme))
		_keep.append(ProceduralTextures.door(theme))
		await _slice()

## Noms de fichiers d'un dossier (sans les suffixes .import / .remap des exports), filtrés par extension.
func _list(dir: String, exts: Array) -> Array:
	var out: Array = []
	var seen := {}
	var names: PackedStringArray = ResourceLoader.list_directory(dir)
	for n in names:
		var name := String(n)
		if name.ends_with("/"):
			continue
		for suf in [".import", ".remap"]:
			if name.ends_with(suf):
				name = name.trim_suffix(suf)
		if not exts.has(name.get_extension().to_lower()) or seen.has(name):
			continue
		seen[name] = true
		out.append(name)
	out.sort()
	return out
