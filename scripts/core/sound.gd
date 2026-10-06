extends Node
## Audio du jeu (autoload `Sound`). Comme dans le build HTML, tous les sons sont synthétisés par le code : effets (sons courts
## mis en cache), ambiance par thème de donjon (nappe bouclée + petits sons aléatoires) et musique de boss (fichier OGG).

const RATE := 22050
const AMBIENT_RATE := 11025
const SETTINGS := "user://settings.cfg"

var enabled: bool = true
var sfx_volume: float = 0.6
var music_volume: float = 0.5

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_next: int = 0
var _music: AudioStreamPlayer
var _menu: AudioStreamPlayer          # musique de l'accueil (fichier OGG en boucle, lecture en flux)
var _menu_tween: Tween
var _credits: AudioStreamPlayer       # musique du générique
var _credits_tween: Tween
var _credits_on: bool = false
var _credits_resume_menu: bool = false
var _menu_wanted: bool = false
const CREDITS_MUSIC := "res://assets/music/credits.ogg"
const MENU_MUSIC := "res://assets/music/menu.ogg"
var _ambient_key: String = ""
var _shimmer: Timer
var _shimmer_kind: String = ""
var _bus_sfx: int = -1
var _bus_music: int = -1
var _last_yield_us: int = 0
var _yielding: bool = false     # pendant le préchargement : la synthèse rend la main entre deux étapes (barre de progression, page Web vivante)
var _unlocked: bool = false
var preloaded: bool = false

const THEME_AMBIENT := {
	"stone": {"freqs": [65.4, 98.0], "type": "sine", "gain": 0.16, "shimmer": ""},
	"dirt": {"freqs": [55.0, 82.4], "type": "triangle", "gain": 0.15, "shimmer": ""},
	"damp": {"freqs": [49.0, 73.4, 110.0], "type": "sine", "gain": 0.17, "shimmer": "drip"},
	"ruins": {"freqs": [73.4, 110.0], "type": "sine", "gain": 0.14, "shimmer": "wind"},
	"ice": {"freqs": [220.0, 330.0, 440.0], "type": "sine", "gain": 0.12, "shimmer": "shimmer"},
	"lava": {"freqs": [41.2, 61.7], "type": "triangle", "gain": 0.13, "shimmer": "crackle"},
	"temple": {"freqs": [130.8, 196.0, 261.6], "type": "sine", "gain": 0.14, "shimmer": "bell"},
}
const BOSS_MUSIC := "res://assets/music/boss.ogg"
const SWING_FREQ := {"sword": 1600.0, "axe": 1000.0, "dagger": 2000.0, "staff": 700.0, "bow": 1800.0, "mace": 800.0, "unarmed": 600.0}

# ------------------------------------------------------------------ mise en place

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_bus_sfx = _make_bus("SFX", 0.14)
	_bus_music = _make_bus("Music", 0.5)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 8500.0
	AudioServer.add_bus_effect(0, lp)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM   # Web : lecture « stream » (le mode « échantillon » ignore les bus créés par code)
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_music)
	_menu = AudioStreamPlayer.new()
	_menu.bus = "Music"
	_menu.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_menu)
	_credits = AudioStreamPlayer.new()
	_credits.bus = "Music"
	_credits.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_credits)
	_shimmer = Timer.new()
	_shimmer.timeout.connect(_on_shimmer)
	add_child(_shimmer)
	_apply_volumes()

func _make_bus(bus_name: String, wet: float) -> int:
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.8
	rev.damping = 0.5
	rev.wet = wet
	rev.dry = 1.0
	AudioServer.add_bus_effect(idx, rev)
	return idx

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		enabled = bool(cf.get_value("sound", "enabled", true))
		sfx_volume = float(cf.get_value("sound", "sfx", 0.6))
		music_volume = float(cf.get_value("sound", "music", 0.5))

func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("sound", "enabled", enabled)
	cf.set_value("sound", "sfx", sfx_volume)
	cf.set_value("sound", "music", music_volume)
	cf.save(SETTINGS)

func _apply_volumes() -> void:
	AudioServer.set_bus_mute(0, not enabled)
	AudioServer.set_bus_volume_db(_bus_sfx, linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(_bus_music, linear_to_db(maxf(music_volume, 0.0001)))

func set_enabled(v: bool) -> void:
	enabled = v
	_apply_volumes()
	_save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

# ------------------------------------------------------------------ lecture

func _play(stream: AudioStream) -> void:
	if not enabled or stream == null:
		return
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stream = stream
	p.play()

## Bruit de dés qui roulent (fichier OGG, chargé une fois).
const FILE_SOUNDS := {"dice": "res://assets/sounds/dice.ogg", "coins": "res://assets/sounds/coins.ogg", "map_open": "res://assets/sounds/map_open.ogg"}

func _file_sfx(key: String) -> void:
	if not _cache.has(key):
		_cache[key] = load(FILE_SOUNDS[key])
	_play(_cache[key])

func dice() -> void:
	_file_sfx("dice")

## Pièces d'or (gain dans une énigme ou un piège, achat et vente chez le marchand).
func coins() -> void:
	_file_sfx("coins")

## Ouverture de la grande carte.
func map_open() -> void:
	_file_sfx("map_open")

## Joue un effet. `arg` : type d'arme (swing), style du sort (spell), montée (stairs).
func sfx(name: String, arg = null) -> void:
	if not enabled:
		return
	_play(_sfx_stream(name, arg))

func _sfx_stream(name: String, arg) -> AudioStreamWAV:
	var key := name + "|" + str(arg)
	if not _cache.has(key):
		_cache[key] = _build_sfx(name, arg)
	return _cache[key]

func sfx_later(delay: float, name: String, arg = null) -> void:
	get_tree().create_timer(delay).timeout.connect(func(): sfx(name, arg))

func _build_sfx(name: String, arg) -> AudioStreamWAV:
	var b := Synth.new(RATE)
	match name:
		"door_creak": b.creak()
		"door_locked":
			b.tone(140.0, 0.05, "square", 0.16, 0.012, 0.05)
			b.tone(110.0, 0.05, "square", 0.14, 0.012, 0.08, 0.07)
		"swing": b.noise(0.09, "bandpass", SWING_FREQ.get(str(arg), 1200.0), 1.1, 0.13, 0.002, 0.06)
		"hit":
			b.noise(0.06, "lowpass", 220.0, 0.6, 0.16, 0.001, 0.09)
			b.tone(90.0, 0.05, "sine", 0.13, 0.012, 0.1)
		"spell": _spell(b, str(arg if arg != null else "arcane"))
		"monster_attack":
			b.noise(0.1, "lowpass", 400.0, 0.6, 0.14, 0.004, 0.1)
			b.tone(130.0, 0.12, "sawtooth", 0.1, 0.012, 0.14, 0.0, 60.0)
		"pickup":
			b.tone(1046.0, 0.05, "triangle", 0.12, 0.012, 0.08, 0.0, 0.0, true)
			b.tone(1568.0, 0.06, "triangle", 0.10, 0.012, 0.10, 0.05, 0.0, true)
		"level_up":
			for i in 4:
				b.tone([523.0, 659.0, 784.0, 1046.0][i], 0.1, "triangle", 0.13, 0.012, 0.14, i * 0.08, 0.0, true)
		"evolve":
			for i in 5:
				b.tone([392.0, 523.0, 659.0, 784.0, 988.0][i], 0.12, "sine", 0.13, 0.012, 0.2, i * 0.07, 0.0, true)
		"down": b.tone(220.0, 0.18, "sawtooth", 0.13, 0.012, 0.2, 0.0, 60.0)
		"game_over":
			for i in 4:
				b.tone([330.0, 294.0, 262.0, 220.0][i], 0.28, "sawtooth", 0.12, 0.012, 0.22, i * 0.22)
		"victory":
			for i in 5:
				b.tone([523.0, 659.0, 784.0, 1046.0, 1318.0][i], 0.16, "triangle", 0.14, 0.012, 0.22, i * 0.12, 0.0, true)
		"fountain":
			for i in 4:
				b.tone([1200.0, 1500.0, 1800.0, 2200.0][i], 0.14, "sine", 0.08, 0.012, 0.3, i * 0.06, 0.0, true)
		"heal":
			b.tone(700.0, 0.1, "sine", 0.12, 0.012, 0.18, 0.0, 0.0, true)
			b.tone(1050.0, 0.1, "sine", 0.09, 0.012, 0.2, 0.06, 0.0, true)
		"stairs":
			var f: Array = [180.0, 210.0, 245.0, 285.0] if bool(arg) else [285.0, 245.0, 210.0, 180.0]
			for i in 4:
				b.tone(f[i], 0.05, "square", 0.07, 0.012, 0.04, i * 0.09)
			b.tone(400.0, 0.1, "sine", 0.10, 0.012, 0.2, 4 * 0.09 + 0.05, 900.0)
		"blocked": b.tone(150.0, 0.06, "square", 0.08, 0.012, 0.06)
		"combat_start":
			b.tone(90.0, 0.22, "sawtooth", 0.22, 0.012, 0.18)
			b.tone(620.0, 0.08, "square", 0.14, 0.012, 0.08, 0.02)
			b.tone(190.0, 0.14, "sawtooth", 0.16, 0.012, 0.16, 0.1, 70.0)
	return b.to_stream(false)

func _spell(b: Synth, style: String) -> void:
	match style:
		"fire":
			b.noise(0.18, "highpass", 1600.0, 0.5, 0.15, 0.004, 0.14)
			b.tone(200.0, 0.16, "sawtooth", 0.12, 0.012, 0.12, 0.0, 70.0)
		"ice":
			b.tone(1500.0, 0.12, "sine", 0.11, 0.012, 0.22, 0.0, 0.0, true)
			b.tone(2100.0, 0.1, "sine", 0.08, 0.012, 0.24, 0.05, 0.0, true)
		"holy":
			b.tone(900.0, 0.14, "sine", 0.13, 0.012, 0.3, 0.0, 0.0, true)
			b.tone(1350.0, 0.14, "sine", 0.09, 0.012, 0.32, 0.03, 0.0, true)
		"nature": b.noise(0.14, "bandpass", 2200.0, 2.0, 0.11, 0.004, 0.12)
		"shadow":
			b.tone(160.0, 0.22, "sine", 0.14, 0.012, 0.25)
			b.tone(80.0, 0.22, "sine", 0.10, 0.012, 0.3, 0.02)
		"physical": b.noise(0.09, "bandpass", 1600.0, 1.1, 0.13, 0.002, 0.06)
		"bard":
			for i in 4:
				b.tone([660.0, 880.0, 1100.0, 1320.0][i], 0.08 if i < 3 else 0.1, "triangle", [0.12, 0.11, 0.10, 0.09][i], 0.012, [0.1, 0.1, 0.12, 0.16][i], i * 0.05, 0.0, i == 3)
		_: b.tone(500.0, 0.1, "sawtooth", 0.10, 0.012, 0.18, 0.0, 1400.0)   # arcane

# ------------------------------------------------------------------ ambiance et musique

## Musique du générique : elle prend la place de la musique d'accueil ou de l'ambiance du donjon (mises en pause), puis les rend.
func credits_music(on: bool) -> void:
	if on == _credits_on:
		return
	_credits_on = on
	if _credits_tween != null:
		_credits_tween.kill()
	if on:
		_credits_resume_menu = _menu_wanted
		if _credits_resume_menu:
			menu_music(false, 0.6)
		_music.stream_paused = true
		_shimmer.paused = true
		var st = load(CREDITS_MUSIC)
		if st == null:
			return
		_credits.stream = st
		_credits.volume_db = -60.0
		_credits.play()
		_credits_tween = create_tween()
		_credits_tween.tween_property(_credits, "volume_db", 0.0, 1.0)
	else:
		_credits_tween = create_tween()
		_credits_tween.tween_property(_credits, "volume_db", -60.0, 0.8)
		_credits_tween.tween_callback(_credits.stop)
		_music.stream_paused = false
		_shimmer.paused = false
		if _credits_resume_menu:
			menu_music(true, 1.5)

## Musique de l'accueil. `on` = true : fondu d'entrée (elle continue d'un écran du menu à l'autre) ; false : fondu de sortie.
## Sur le Web, rien ne sort avant le premier geste du joueur : la demande est mémorisée et jouée par unlock().
func menu_music(on: bool, fade: float = 1.2) -> void:
	_menu_wanted = on
	if on and (OS.has_feature("web") and not _unlocked):
		return
	if _menu_tween != null:
		_menu_tween.kill()
	if on:
		if _menu.playing and _menu.volume_db > -30.0:
			return
		if _menu.stream == null:
			var st = load(MENU_MUSIC)
			if st == null:
				return
			if st is AudioStreamOggVorbis:
				st.loop = true
			_menu.stream = st
		if not _menu.playing:
			_menu.volume_db = -60.0
			_menu.play()
		_menu_tween = create_tween()
		_menu_tween.tween_property(_menu, "volume_db", 0.0, fade)
	elif _menu.playing:
		_menu_tween = create_tween()
		_menu_tween.tween_property(_menu, "volume_db", -60.0, fade)
		_menu_tween.tween_callback(_menu.stop)

## Lance l'ambiance du thème (ou la musique de boss). Sans effet si déjà en cours.
## (Coroutine : si la musique n'a pas été préchargée, elle est synthétisée ici ; sinon tout est immédiat.)
func ambient(theme: String, boss: bool = false) -> void:
	var key := "boss" if boss else (theme if THEME_AMBIENT.has(theme) else "stone")
	if key == _ambient_key:
		return
	stop_ambient()
	_ambient_key = key
	if not _cache.has("amb|" + key):
		var built: AudioStream
		if boss:
			built = _boss_stream()
		else:
			built = await _build_ambient(THEME_AMBIENT[key])
		_cache["amb|" + key] = built
		if _ambient_key != key:
			return   # une autre ambiance a été demandée entre-temps
	_music.stream = _cache["amb|" + key]
	_music.play()
	if not boss:
		_shimmer_kind = str(THEME_AMBIENT[key].shimmer)
		if _shimmer_kind != "":
			_shimmer.start(3.2)

func stop_ambient() -> void:
	_music.stop()
	_shimmer.stop()
	_ambient_key = ""

func _on_shimmer() -> void:
	if not enabled or randf() > 0.45:
		return
	_play(_shimmer_stream(_shimmer_kind, randi() % SHIMMER_VARIANTS))

const SHIMMER_VARIANTS := 4

## Petit son aléatoire de l'ambiance, en quelques hauteurs prédéfinies (toutes préchargées, aucun calcul pendant le jeu).
func _shimmer_stream(kind: String, v: int) -> AudioStreamWAV:
	var key := "shim|%s|%d" % [kind, v]
	if _cache.has(key):
		return _cache[key]
	var r := float(v) / float(SHIMMER_VARIANTS - 1)
	var b := Synth.new(RATE)
	match kind:
		"shimmer": b.tone(1800.0 + r * 800.0, 0.3, "sine", 0.05, 0.012, 0.5, 0.0, 0.0, true)
		"drip": b.tone(900.0 + r * 300.0, 0.08, "sine", 0.055, 0.012, 0.15)
		"crackle": b.noise(0.05, "highpass", 2500.0, 1.0, 0.05, 0.004, 0.05)
		"wind": b.noise(0.6, "lowpass", 500.0, 0.4, 0.035, 0.3, 0.4)
		"bell": b.tone(1046.0 + r * 400.0, 0.5, "sine", 0.04, 0.012, 0.8, 0.0, 0.0, true)
	var st := b.to_stream(false)
	_cache[key] = st
	return st

## Laisse respirer la page pendant le préchargement (une image) : la barre avance, le navigateur ne se fige pas.
func _breath() -> void:
	await _tick()

## Rend la main à l'affichage dès que ~7 ms de calcul se sont écoulées : l'écran de chargement reste fluide, sans perdre de temps
## à attendre une image entre deux petits calculs.
func _tick() -> void:
	if _yielding and Time.get_ticks_usec() - _last_yield_us > 7000:
		await get_tree().process_frame
		_last_yield_us = Time.get_ticks_usec()

func _build_ambient(cfg: Dictionary) -> AudioStreamWAV:   # coroutine (voir _breath)
	var seconds := 8.0
	var b := Synth.new(AMBIENT_RATE, seconds)
	var freqs: Array = cfg.freqs
	for i in freqs.size():
		var vg: float = float(cfg.gain) / (i + 1) / 2.0
		var f: float = maxf(1.0, round(float(freqs[i]) * seconds)) / seconds   # nombre entier de périodes : boucle sans raccord
		var lfo: float = maxf(1.0, round((0.05 + i * 0.02 + 0.01) * seconds)) / seconds
		for dt in [-5.0, 5.0]:
			var from_i := 0
			while from_i < b.fixed_len:
				var to_i := mini(from_i + 6000, b.fixed_len)
				b.pad_voice(f * pow(2.0, dt / 1200.0), str(cfg.type), vg, lfo, vg * 0.35, from_i, to_i)
				from_i = to_i
				await _tick()
	return b.to_stream(true)

## Musique de boss : fichier OGG en boucle, lu en flux.
func _boss_stream() -> AudioStream:
	var st = load(BOSS_MUSIC)
	if st is AudioStreamOggVorbis:
		st.loop = true
	return st

# ------------------------------------------------------------------ préchargement

const PRELOAD_SWINGS := ["sword", "axe", "dagger", "staff", "bow", "mace", "unarmed"]
const PRELOAD_SPELLS := ["fire", "ice", "holy", "nature", "shadow", "physical", "bard", "arcane"]
const PRELOAD_PLAIN := ["door_creak", "door_locked", "hit", "monster_attack", "pickup", "level_up", "evolve", "down",
	"game_over", "victory", "fountain", "heal", "blocked", "combat_start"]

## Synthétise à l'avance tous les sons du jeu : effets, petits sons d'ambiance, nappes de chaque thème, musique de boss.
## `progress.call(fraction, texte)` est appelé au fil de l'eau ; la synthèse rend la main à chaque étape (page Web vivante).
func preload_all(progress: Callable = Callable()) -> void:
	if preloaded:
		if progress.is_valid():
			progress.call(1.0, "")
		return
	var jobs: Array = []   # {label, w, fn}
	var lbl_sfx := L.t("loading.sons_effets")
	var lbl_amb := L.t("loading.sons_ambiances")
	var lbl_boss := L.t("loading.sons_boss")
	for n in PRELOAD_PLAIN:
		jobs.append({"label": lbl_sfx, "w": 1.0, "fn": func(): _sfx_stream(n, null)})
	for w in PRELOAD_SWINGS:
		jobs.append({"label": lbl_sfx, "w": 0.6, "fn": func(): _sfx_stream("swing", w)})
	for st in PRELOAD_SPELLS:
		jobs.append({"label": lbl_sfx, "w": 0.8, "fn": func(): _sfx_stream("spell", st)})
	for fk in FILE_SOUNDS:
		jobs.append({"label": lbl_sfx, "w": 0.4, "fn": func(): _cache[fk] = load(FILE_SOUNDS[fk])})
	for up in [true, false]:
		jobs.append({"label": lbl_sfx, "w": 1.0, "fn": func(): _sfx_stream("stairs", up)})
	for kind in ["shimmer", "drip", "crackle", "wind", "bell"]:
		for v in SHIMMER_VARIANTS:
			jobs.append({"label": lbl_amb, "w": 0.4, "fn": func(): _shimmer_stream(kind, v)})
	for key in THEME_AMBIENT:
		jobs.append({"label": lbl_amb, "w": 6.0, "fn": func(): await _preload_music(key, false)})
	jobs.append({"label": lbl_boss, "w": 0.5, "fn": func(): await _preload_music("boss", true)})
	var total := 0.0
	for j in jobs:
		total += float(j.w)
	var done := 0.0
	_yielding = true
	_last_yield_us = Time.get_ticks_usec()
	var t0 := Time.get_ticks_msec()
	for j in jobs:
		if progress.is_valid():
			progress.call(done / total, j.label)
		await j.fn.call()
		done += float(j.w)
		await _tick()
	_yielding = false
	preloaded = true
	if progress.is_valid():
		progress.call(1.0, "")
	print("[Sound] %d sons préchargés en %.1f s" % [_cache.size(), (Time.get_ticks_msec() - t0) / 1000.0])

func _preload_music(key: String, boss: bool) -> void:
	if _cache.has("amb|" + key):
		return
	if boss:
		_cache["amb|boss"] = _boss_stream()
	else:
		_cache["amb|" + key] = await _build_ambient(THEME_AMBIENT[key])

## À appeler après un geste de l'utilisateur (clic, touche, toucher) : les navigateurs n'autorisent le son qu'à partir de là.
## Joue un petit carillon de confirmation et trace l'état de l'audio dans la console du navigateur (F12).
func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	print("[Sound] audio : sortie « %s », %d Hz, latence %.0f ms, %d bus, lecture %s, son %s" % [
		AudioServer.get_output_device(), int(AudioServer.get_mix_rate()), AudioServer.get_output_latency() * 1000.0,
		AudioServer.bus_count, "stream", "activé" if enabled else "coupé"])
	sfx("pickup")
	if _menu_wanted:
		menu_music(true)

# ------------------------------------------------------------------ synthèse

class Synth:
	var rate: int
	var data: PackedFloat32Array = PackedFloat32Array()
	var fixed_len: int = 0

	func _init(r: int, fixed_seconds: float = 0.0) -> void:
		rate = r
		if fixed_seconds > 0.0:
			fixed_len = int(round(fixed_seconds * r))
			data.resize(fixed_len)

	func _ensure(n: int) -> void:
		if fixed_len == 0 and data.size() < n:
			data.resize(n)

	func _put(i: int, v: float) -> void:
		if fixed_len > 0:
			i = i % fixed_len   # les queues de note rebouclent au début (musique bouclée)
		data[i] += v

	static func _wave(kind: String, p: float) -> float:
		var f := p - floorf(p)
		match kind:
			"square": return 1.0 if f < 0.5 else -1.0
			"sawtooth": return 2.0 * f - 1.0
			"triangle": return 4.0 * absf(f - 0.5) - 1.0
		return sin(TAU * p)

	## Enveloppe exponentielle : montée sur `attack`, puis descente sur `dur + release` (Web Audio exponentialRamp).
	static func _env(t: float, gain: float, attack: float, total: float) -> float:
		if t < 0.0:
			return 0.0
		var g := maxf(gain, 0.001)
		if t < attack:
			return 0.0001 * pow(g / 0.0001, t / maxf(attack, 0.0001))
		var u := (t - attack) / maxf(total, 0.0001)
		if u >= 1.0:
			return 0.0
		return g * pow(0.0001 / g, u)

	func tone(freq: float, dur: float, kind: String, gain: float, attack: float, release: float, delay: float = 0.0, slide_to: float = 0.0, chorus: bool = false) -> void:
		var total := dur + release
		var start := int(delay * rate)
		var n := int((attack + total + 0.05) * rate)
		_ensure(start + n)
		var voices: Array = [-6.0, 6.0] if chorus else [0.0]
		for dt in voices:
			var vg := gain / voices.size()
			var f0 := freq * pow(2.0, float(dt) / 1200.0)
			var phase := 0.0
			for i in n:
				var t := float(i) / rate
				var f := f0
				if slide_to > 0.0:
					f = f0 * pow(maxf(1.0, slide_to) / f0, minf(t / dur, 1.0))
				phase += f / rate
				var e := _env(t, vg, attack, total)
				if e <= 0.0 and t > attack:
					break
				_put(start + i, _wave(kind, phase) * e)

	func noise(dur: float, ftype: String, ffreq: float, q: float, gain: float, attack: float, release: float, delay: float = 0.0) -> void:
		var start := int(delay * rate)
		var n := maxi(1, int(dur * rate))
		_ensure(start + n)
		# filtre biquad (RBJ)
		var w0 := TAU * minf(ffreq, rate * 0.45) / rate
		var alpha := sin(w0) / (2.0 * maxf(q, 0.01))
		var cw := cos(w0)
		var b0 := 0.0
		var b1 := 0.0
		var b2 := 0.0
		match ftype:
			"lowpass":
				b0 = (1.0 - cw) / 2.0
				b1 = 1.0 - cw
				b2 = (1.0 - cw) / 2.0
			"highpass":
				b0 = (1.0 + cw) / 2.0
				b1 = -(1.0 + cw)
				b2 = (1.0 + cw) / 2.0
			_:
				b0 = alpha
				b1 = 0.0
				b2 = -alpha
		var a0 := 1.0 + alpha
		var a1 := -2.0 * cw
		var a2 := 1.0 - alpha
		b0 /= a0
		b1 /= a0
		b2 /= a0
		a1 /= a0
		a2 /= a0
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		var total := release + dur * 0.4
		for i in n:
			var x := randf() * 2.0 - 1.0
			var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			_put(start + i, y * _env(float(i) / rate, gain, attack, total))

	func creak() -> void:
		var n := int(0.7 * rate)
		_ensure(n)
		var lp := 0.0
		var a := 1.0 - exp(-TAU * 700.0 / rate)
		var phase := 0.0
		for i in n:
			var t := float(i) / rate
			var f := 180.0 - 90.0 * minf(t / 0.55, 1.0)
			phase += f / rate
			lp += a * (_wave("sawtooth", phase) - lp)
			_put(i, lp * _env(t, 0.09, 0.06, 0.59))

	## Voix continue d'une nappe (gain modulé par un LFO) sur la durée fixe de la boucle.
	func pad_voice(freq: float, kind: String, gain: float, lfo_freq: float, lfo_depth: float, from_i: int = 0, to_i: int = -1) -> void:
		var inc := freq / rate
		var lfo_w := TAU * lfo_freq / rate
		var phase := inc * from_i
		if to_i < 0:
			to_i = fixed_len
		if kind == "sine":
			for i in range(from_i, to_i):
				phase += inc
				data[i] += sin(TAU * phase) * (gain + sin(lfo_w * i) * lfo_depth)
		else:
			for i in range(from_i, to_i):
				phase += inc
				data[i] += _wave(kind, phase) * (gain + sin(lfo_w * i) * lfo_depth)

	func to_stream(loop: bool) -> AudioStreamWAV:
		var st := AudioStreamWAV.new()
		st.format = AudioStreamWAV.FORMAT_16_BITS
		st.mix_rate = rate
		st.stereo = false
		var n := data.size()
		var bytes := PackedByteArray()
		bytes.resize(n * 2)
		for i in n:
			bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
		st.data = bytes
		if loop:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = n
		return st
