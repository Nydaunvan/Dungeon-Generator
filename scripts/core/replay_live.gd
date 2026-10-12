class_name ReplayLive
extends Node
## Revoir une partie classée « comme dans le jeu » (réservé au développeur) : le VRAI jeu est lancé avec la graine de la partie et le
## journal d'actions lui est injecté au bon moment (même mécanique que le vérificateur, voir Replayer.step), mais à l'écran.
##   * lecture seule : un cache absorbe la souris, le clavier ne commande plus la partie (RunLog.replaying) ;
##   * jamais d'envoi au classement ni de sauvegarde (la partie du rejeu n'a pas d'identifiant de partie classée) ;
##   * pause, vitesses ×1 à ×16, avance / recul : le recul relance la partie et avance à vitesse maximale jusqu'au point voulu ;
##   * l'horloge de jeu n'est réglée qu'aux actions (comme le vérificateur) : les barres de temps avancent par à-coups ;
##   * capture d'écran (PNG) et capture vidéo (AVI Motion JPEG) à tout moment.

const SPEEDS := [1.0, 2.0, 4.0, 8.0, 16.0]
const FAST_SCALE := 8.0
const IDLE_CAP_MS := 2000            ## temps mort maximal entre deux actions quand « sauter les temps morts » est actif
const JUMP_MS := 30000
const REC_FPS := 15
const REC_MAX_SEC := 30
const REC_MAX_W := 1280

static var active: ReplayLive = null

var meta: Dictionary = {}
var cfg: Dictionary = {}
var log: Array = []
var total_ms := 0
var speed := 1.0
var paused := false
var skip_idle := true
var hide_bar := true                 ## cacher la barre pendant les captures
var _gen := 0
var _busy := false
var _closing := false
var _pos_ms := 0.0
var _applied := 0
var _seek_target := -1
var _seek_resume := true
var _ended := false
var _status := ""
var _bad := false
# interface
var _blocker_layer: CanvasLayer
var _bar_layer: CanvasLayer
var _bar: PanelContainer
var _slider: HSlider
var _time_label: Label
var _status_label: Label
var _pause_btn: Button
var _speed_btns: Array = []
var _rec_btn: Button
var _toast: Label
# vidéo
var _rec := false
var _rec_busy := false
var _rec_next := 0
var _rec_t0 := 0
var _rec_w := 0
var _rec_h := 0
var _rec_frames: Array[PackedByteArray] = []

## Ouvre le lecteur pour une partie `m` (réponse d'admin_run_log). Renvoie "" si tout va bien, sinon le texte de l'erreur.
static func open(m: Dictionary) -> String:
	if active != null and is_instance_valid(active):
		return L.t("ui.replay.already")
	var log_v: Variant = m.get("log")
	if not (log_v is Array) or (log_v as Array).is_empty():
		return L.t("ui.replay.no_log")
	var last := 0
	for e in (log_v as Array):
		if not (e is Array) or (e as Array).size() < 2 or int(e[0]) < last:
			return L.t("ui.replay.bad_log")
		last = int(e[0])
	var params: Dictionary = m.get("params", {}) if m.get("params") is Dictionary else {}
	var cfg_v: Dictionary = RankedRun.config_for(Data.original_config, str(m.get("seed", "")), params)
	if cfg_v.is_empty():
		return L.t("ui.replay.bad_settings")
	var r := ReplayLive.new()
	r.meta = m
	r.cfg = cfg_v
	r.log = log_v
	r.total_ms = last
	active = r
	(Engine.get_main_loop() as SceneTree).root.add_child(r)
	r._start_ui()
	r._play(-1)
	return ""

# ------------------------------------------------------------------ lecture

## (Re)lance la partie et rejoue le journal. `target` >= 0 : avance à vitesse maximale jusqu'à ce temps de jeu puis se met en pause.
func _play(target: int) -> void:
	_gen += 1
	var my := _gen
	_seek_target = target
	while _busy:
		await get_tree().process_frame
	if _closing or my != _gen:
		return
	_busy = true
	_ended = false
	_applied = 0
	_pos_ms = 0.0
	RunLog.replaying = true
	GameClock.manual = true
	Engine.time_scale = 1.0
	_say(L.t("ui.replay.loading"))
	var tree := get_tree()
	var old_id: int = tree.current_scene.get_instance_id() if tree.current_scene != null else 0
	Data.launch(cfg, "random")
	var ok: bool = await Replayer._until(tree, func():
		var mm := Replayer.main_of(tree)
		return mm != null and mm.get_instance_id() != old_id and not mm.get("_loading") and mm.get("level_node") != null and not Loader.is_active(), Replayer.READY_TIMEOUT)
	var m := Replayer.main_of(tree) if ok else null
	if m == null or _closing or my != _gen:
		if m == null and not _closing and my == _gen:
			_say(L.t("ui.replay.start_failed"), true)
		_busy = false
		return
	var v_ms := 0.0
	var t_prev := Time.get_ticks_msec()
	var failed := ""
	for i in log.size():
		var e: Array = log[i]
		var ms := int(e[0])
		# attente jusqu'au moment de l'action (cadence de lecture), sauf en avance rapide
		while true:
			if _closing or my != _gen:
				break
			if _seek_target >= 0 and ms <= _seek_target:
				break
			if _seek_target >= 0 and ms > _seek_target:
				v_ms = float(_seek_target)
				_seek_target = -1
				paused = not _seek_resume
			var now := Time.get_ticks_msec()
			var dt := float(now - t_prev)
			t_prev = now
			if paused:
				Engine.time_scale = 0.0
				_pos_ms = v_ms
				await tree.process_frame
				continue
			Engine.time_scale = speed
			v_ms += dt * speed
			if skip_idle and float(ms) - v_ms > IDLE_CAP_MS:
				v_ms = float(ms - IDLE_CAP_MS)
			_pos_ms = v_ms
			if v_ms >= float(ms):
				break
			await tree.process_frame
		if _closing or my != _gen:
			break
		Engine.time_scale = FAST_SCALE if (_seek_target >= 0 and ms <= _seek_target) else speed
		if not is_instance_valid(m):
			break
		var why: String = await Replayer.step(tree, m, e, _applied)
		if why != "":
			failed = why
			break
		_applied += 1
		v_ms = maxf(v_ms, float(ms))
		_pos_ms = v_ms
	if _closing or my != _gen:
		_busy = false
		return
	Engine.time_scale = 1.0
	if failed != "":
		paused = true
		_bad = true
		_say(L.fa(L.t("ui.replay.diverged"), [failed, _applied, str(meta.get("game_version", "?")), AppVersion.number()]), true)
		_busy = false
		return
	if _seek_target >= 0:                          # cible au-delà de la fin du journal
		_seek_target = -1
	var wm: WeakRef = weakref(m)
	await Replayer._until(tree, func(): return wm.get_ref() == null or wm.get_ref().settled() or wm.get_ref().gs.game_over or wm.get_ref().gs.won, Replayer.SETTLE_TIMEOUT)
	if is_instance_valid(m) and not _closing and my == _gen:
		var res := {"ok": true, "taint": m.gs.run_taint, "summary": Replayer.summary(m.gs), "clock_ms": total_ms}
		var rank := RankedRun.ranking_of(res, meta.get("params", {}) if meta.get("params") is Dictionary else {})
		var mine := str(rank.get("score", "?"))
		var theirs := str(meta.get("score", "?")) if meta.get("score") != null else "—"
		_ended = true
		paused = true
		_pos_ms = float(total_ms)
		_say(L.fa(L.t("ui.replay.ended"), [mine, theirs]))
	_busy = false

func seek(ms: int) -> void:
	ms = clampi(ms, 0, total_ms)
	_seek_resume = not paused
	if float(ms) >= _pos_ms and not _ended and not _bad and _busy:
		_seek_target = ms                          # en avant : on accélère depuis la position actuelle
		paused = false
	else:
		_play(ms)                                  # en arrière (ou après la fin) : on relance la partie

func toggle_pause() -> void:
	if _ended or _bad:
		_seek_resume = true
		_play(-1)
		paused = false
		return
	paused = not paused

func set_speed(s: float) -> void:
	speed = s
	if _seek_target < 0 and not paused:
		Engine.time_scale = s

func close() -> void:
	if _closing:
		return
	_closing = true
	_gen += 1
	_stop_recording(false)
	while _busy:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	RunLog.replaying = false
	GameClock.manual = false
	if is_instance_valid(_blocker_layer):
		_blocker_layer.queue_free()
	if is_instance_valid(_bar_layer):
		_bar_layer.queue_free()
	active = null
	Data.go_home()
	queue_free()

# ------------------------------------------------------------------ interface

func _say(t: String, bad: bool = false) -> void:
	_status = t
	_bad = _bad or bad
	if is_instance_valid(_status_label):
		_status_label.text = t
		_status_label.add_theme_color_override("font_color", Color("e08a7a") if bad else UiTheme.DIM)

func _btn(parent: Control, text: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _check(parent: Control, text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	parent.add_child(c)
	return c

func _start_ui() -> void:
	# cache : empêche la souris d'atteindre l'interface du jeu (le rejeu est en lecture seule)
	_blocker_layer = CanvasLayer.new()
	_blocker_layer.layer = 80
	add_child(_blocker_layer)
	var blk := Control.new()
	blk.set_anchors_preset(Control.PRESET_FULL_RECT)
	blk.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker_layer.add_child(blk)
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 81
	add_child(_bar_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.shared()
	_bar_layer.add_child(root)
	_bar = PanelContainer.new()
	_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = 12
	_bar.offset_right = -12
	_bar.offset_top = 8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.035, 0.02, 0.88)
	sb.border_color = UiTheme.BRONZE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	_bar.add_theme_stylebox_override("panel", sb)
	root.add_child(_bar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_bar.add_child(v)
	# ligne 1 : titre + quitter
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	v.add_child(r1)
	var title := Label.new()
	var mode := SuperAdminModal.mode_name(str(meta.get("difficulty", "")), str(meta.get("kind", "")))
	title.text = L.fa(L.t("ui.replay.title"), [str(meta.get("pseudo", "?")), mode, str(meta.get("game_version", "?"))])
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("ffd98a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	r1.add_child(title)
	_btn(r1, L.t("ui.replay.quit"), close)
	# ligne 2 : curseur de position
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	v.add_child(r2)
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = maxi(total_ms, 1)
	_slider.step = 100
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.drag_ended.connect(func(changed: bool):
		if changed:
			seek(int(_slider.value)))
	r2.add_child(_slider)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 14)
	r2.add_child(_time_label)
	# ligne 3 : commandes
	var r3 := HFlowContainer.new()
	r3.add_theme_constant_override("h_separation", 6)
	r3.add_theme_constant_override("v_separation", 4)
	v.add_child(r3)
	_btn(r3, "⏮", func(): _play(-1), L.t("ui.replay.restart"))
	_btn(r3, "⏪ 30 s", func(): seek(int(_pos_ms) - JUMP_MS), L.t("ui.replay.back"))
	_pause_btn = _btn(r3, "⏸", toggle_pause, L.t("ui.replay.pause_tip"))
	_btn(r3, "30 s ⏩", func(): seek(int(_pos_ms) + JUMP_MS), L.t("ui.replay.fwd"))
	for s in SPEEDS:
		var sp: float = s
		var b := _btn(r3, "×%d" % int(sp), func(): set_speed(sp))
		b.toggle_mode = true
		_speed_btns.append([sp, b])
	_check(r3, L.t("ui.replay.skip_idle"), skip_idle, func(on: bool): skip_idle = on)
	_btn(r3, "📷", func(): capture_image(), L.t("ui.replay.shot_tip"))
	_rec_btn = _btn(r3, "🎥", toggle_recording, L.t("ui.replay.rec_tip"))
	_check(r3, L.t("ui.replay.hide_bar"), hide_bar, func(on: bool): hide_bar = on)
	# ligne 4 : état
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", UiTheme.DIM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status_label)
	if str(meta.get("game_version", "")) != AppVersion.number():
		_status_label.text = L.fa(L.t("ui.replay.version_warn"), [str(meta.get("game_version", "?")), AppVersion.number()])
	# message temporaire (capture vidéo)
	var tl := CanvasLayer.new()
	tl.layer = 82
	add_child(tl)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 150
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color("ffd98a"))
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.visible = false
	tl.add_child(_toast)

func _fmt(ms: float) -> String:
	var s := int(ms / 1000.0)
	return "%d:%02d" % [s / 60, s % 60]

func _process(_d: float) -> void:
	if not is_instance_valid(_slider):
		return
	if not _slider.has_focus() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_slider.set_value_no_signal(_pos_ms)
	_time_label.text = "%s / %s" % [_fmt(_pos_ms), _fmt(total_ms)]
	_pause_btn.text = "▶" if (paused or _ended or _bad) else "⏸"
	for sb in _speed_btns:
		(sb[1] as Button).button_pressed = is_equal_approx(float(sb[0]), speed)
	if not _bad and not _ended and _status != "" and _seek_target < 0 and not _busy:
		pass
	if _rec and not _rec_busy and Time.get_ticks_msec() >= _rec_next:
		_grab_frame()

func _input(event: InputEvent) -> void:
	if _closing or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_SPACE:
			toggle_pause()
		KEY_LEFT:
			seek(int(_pos_ms) - 10000)
		KEY_RIGHT:
			seek(int(_pos_ms) + 10000)
		KEY_F9:
			capture_image()
		KEY_F10:
			toggle_recording()
		_:
			return
	get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ captures

func _stamp() -> String:
	return "%s_%s" % [str(meta.get("pseudo", "joueur")).to_lower().replace(" ", "_"), _fmt(_pos_ms).replace(":", "m")]

func _toast_say(t: String, secs: float = 2.5) -> void:
	_toast.text = t
	_toast.visible = true
	await get_tree().create_timer(secs, true, false, true).timeout
	if is_instance_valid(_toast):
		_toast.visible = false

## Capture d'écran (PNG) de l'instant, avec ou sans la barre de commandes.
func capture_image() -> void:
	var was := _bar.visible
	if hide_bar:
		_bar.visible = false
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_bar.visible = was
	Files.save_bytes(self, "rejeu_%s.png" % _stamp(), img.save_png_to_buffer(), func(msg: String): _say(msg), "image/png", "*.png ; Image PNG")

func toggle_recording() -> void:
	if _rec:
		_stop_recording(true)
		return
	if hide_bar:
		_toast_say(L.t("ui.replay.rec_soon"), 3.0)
		await get_tree().create_timer(3.0, true, false, true).timeout
		if _closing or _rec:
			return
		_bar.visible = false
	_rec = true
	_rec_frames = []
	_rec_w = 0
	_rec_t0 = Time.get_ticks_msec()
	_rec_next = 0
	_rec_btn.text = "⏹"
	_say(L.t("ui.replay.rec_on"))

## Une image de la vidéo (cadence REC_FPS, temps réel).
func _grab_frame() -> void:
	_rec_busy = true
	_rec_next = Time.get_ticks_msec() + 1000 / REC_FPS
	await RenderingServer.frame_post_draw
	if not _rec:
		_rec_busy = false
		return
	var img := get_viewport().get_texture().get_image()
	if _rec_w == 0:
		var w := mini(img.get_width(), REC_MAX_W)
		var h := int(round(float(img.get_height()) * w / float(img.get_width())))
		_rec_w = w - (w % 2)
		_rec_h = h - (h % 2)
	if img.get_width() != _rec_w or img.get_height() != _rec_h:
		img.resize(_rec_w, _rec_h, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)
	_rec_frames.append(img.save_jpg_to_buffer(0.85))
	_rec_busy = false
	if (Time.get_ticks_msec() - _rec_t0) / 1000.0 >= REC_MAX_SEC:
		_stop_recording(true)

func _stop_recording(save: bool) -> void:
	if not _rec:
		return
	_rec = false
	if is_instance_valid(_bar):
		_bar.visible = true
	if is_instance_valid(_rec_btn):
		_rec_btn.text = "🎥"
	if save and _rec_frames.size() > 1:
		var secs := maxf(0.5, (Time.get_ticks_msec() - _rec_t0) / 1000.0)
		var fps := clampi(int(round(_rec_frames.size() / secs)), 1, 60)
		var avi := AviWriter.new(_rec_w, _rec_h, fps)
		for f in _rec_frames:
			avi.add_jpeg(f)
		Files.save_bytes(self, "rejeu_%s.avi" % _stamp(), avi.finish(), func(msg: String): _say(msg), "video/x-msvideo", "*.avi ; Vidéo AVI (MJPEG)")
	_rec_frames = []
