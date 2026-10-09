extends Node
## Capture d'écran de l'accueil avec la fenêtre « Défis » (faux serveur). Usage : … res://tools/shot_challenges.tscn -- <png>
var rows: Array = []
func fake(_m: int, url: String, _h: PackedStringArray, _b: String) -> Dictionary:
	var data: Variant = []
	if "/rest/v1/challenges" in url:
		data = [{"id": "c1", "slug": "le-plus-profond", "title": "Le plus profond", "theme": "Exploration", "mode": "declared", "unit": "niveaux",
			"description": "Qui ira le plus loin dans des donjons aléatoires ? Chaque niveau franchi (escalier pris) compte, expéditions successives comprises. À égalité, le temps de jeu le plus court l'emporte.",
			"rules": {}, "starts_at": "2020-01-01T00:00:00+00:00", "ends_at": null}]
	elif "/rest/v1/classement" in url:
		data = rows
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": JSON.stringify(data).to_utf8_buffer()}
func _ready() -> void:
	var names := ["Eldrin", "Nyra", "Bob_le_Preux", "Kaelith", "Mordrake", "Sylvaine", "Tobias", "Grimbald", "Ysolde", "Fenrir", "Aveline"]
	for i in names.size():
		rows.append({"pseudo": names[i], "player_id": "p%d" % i, "score": 24 - i * 2, "seconds": 3100 + i * 240, "verified": false, "details": {"expeditions": 4 - i / 4, "difficulty": "hard", "kills": 120 - i * 7}})
	Cloud._transport = Callable(self, "fake")
	Cloud.url = "https://exemple.supabase.co"; Cloud.key = "k"
	Cloud.session = {"access_token": "A", "refresh_token": "R", "expires_at": Time.get_unix_time_from_system() + 3000.0, "user_id": "p9", "email": "n@e.org", "pseudo": "Fenrir"}
	var home = load("res://scenes/home.tscn").instantiate()
	add_child(home)
	await get_tree().create_timer(1.0).timeout
	home._on_action("random")
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
