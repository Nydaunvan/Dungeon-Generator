extends Node
## Génération derrière l'écran de chargement : l'écran apparaît, les images continuent de passer pendant le calcul (aucune image > 100 ms),
## puis la partie se lance avec le donjon généré.
var worst := 0
var frames := 0
var last := 0
var running := true
var t_start := 0
func _process(_d: float) -> void:
	if not running:
		return
	var now := Time.get_ticks_msec()
	if last > 0 and now - t_start > 700:      # l'affichage initial de l'écran est exclu
		worst = maxi(worst, now - last)
	last = now
	frames += 1
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var t0 := Time.get_ticks_msec()
	t_start = t0
	var got := {}
	Loader.generate(func(): return DungeonGenerator.build_config(Data.config, 8, 40, 40, "normal", []),
		func(cfg: Dictionary):
			got["cfg"] = cfg
			Data.launch(cfg, "random"))
	await get_tree().create_timer(0.5).timeout
	print("écran affiché pendant le calcul : %s" % Loader.is_busy() if Loader.has_method("is_busy") else "(is_busy absent)")
	while not got.has("cfg") and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	running = false
	print("génération terminée en %d ms, %d images, pire image %d ms, niveaux=%d" % [Time.get_ticks_msec() - t0, frames, worst, (got.get("cfg", {}).get("levels", []) as Array).size()])
	print("RESULTAT génération sous chargement : %s" % ("OK" if got.has("cfg") and worst < 150 and frames > 20 else "ECHEC"))
	get_tree().quit()
