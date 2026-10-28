extends Node
## Captures de l'écran « Mode en ligne » (style jeu vidéo) : onglet Jouer sur chaque mode, puis les autres onglets, en 1280×720 et en portrait.
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/shot_online_hub.tscn -- <préfixe>
func fake(_m: int, url: String, _h: PackedStringArray, _b: String) -> Dictionary:
	var data: Variant = []
	if "/rest/v1/player_xp" in url or "my_xp" in url:
		data = [{"xp": 1560}]
	elif "/rest/v1/classement" in url:
		for i in 8:
			data.append({"pseudo": ["Eldrin", "Nyra", "Bob", "Kaelith", "Mordrake", "Sylvaine", "Tobias", "Grimbald"][i], "player_id": "p%d" % i, "score": 24 - i * 2, "seconds": 3100 + i * 240, "level": 5 - i / 2, "metrics": {}})
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": JSON.stringify(data).to_utf8_buffer()}

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)

func _ready() -> void:
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/hub"
	Cloud._transport = Callable(self, "fake")
	Cloud.url = "https://exemple.supabase.co"; Cloud.key = "k"
	Cloud.session = {"access_token": "A", "refresh_token": "R", "expires_at": Time.get_unix_time_from_system() + 3000.0, "user_id": "p9", "email": "n@e.org", "pseudo": "Nydaunvan"}
	var layer := CanvasLayer.new()
	add_child(layer)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(host)
	var h = load("res://scripts/ui/online_hub.gd").open(host, func(): pass, "play")
	await get_tree().create_timer(1.2).timeout
	_shot(pre + "_play_free.png")
	h._mode = "hardcore"
	h._rules_open = true
	h._show("play")
	await get_tree().create_timer(0.8).timeout
	_shot(pre + "_play_hardcore_rules.png")
	h._mode = "ranked"
	h._rules_open = false
	h._show("play")
	await get_tree().create_timer(0.8).timeout
	_shot(pre + "_play_ranked.png")
	for t in ["boards", "rewards", "runs", "friends"]:
		h._show(t)
		await get_tree().create_timer(1.0).timeout
		_shot("%s_%s.png" % [pre, t])
	get_tree().quit()
