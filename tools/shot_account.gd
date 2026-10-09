extends Node
## Capture d'écran de l'accueil avec la fenêtre « Compte » (inscription), pour contrôle visuel. Usage : … res://tools/shot_account.tscn -- <png> [signup|account]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var home = load("res://scenes/home.tscn").instantiate()
	add_child(home)
	await get_tree().create_timer(1.0).timeout
	var layer: Node = home.get("_modal_layer")
	var a := AccountModal.open(layer)
	if args.size() > 1 and args[1] == "signup":
		a._switch("signup")
	elif args.size() > 1 and args[1] == "account":
		Cloud.session = {"access_token": "A", "refresh_token": "R", "expires_at": Time.get_unix_time_from_system() + 3000.0, "user_id": "u", "email": "nyra@example.org", "pseudo": "Nyra"}
		Cloud.session_changed.emit()
		a._mode = "account"
		a._build()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(args[0])
	get_tree().quit()
