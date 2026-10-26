extends Node
## Capture de la fenêtre Groupe avec deux statuts actifs : /tmp/party_status.png
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var gs: GameState = main.gs
	var h: Dictionary = gs.party[0]
	h["statusEffects"] = [{"type": "burn", "remaining": 3, "power": 4, "casterId": "x", "look": ""}, {"type": "freeze", "remaining": 2, "power": 1, "casterId": "x", "look": ""}]
	main.inter.open_sheet(str(h.id))
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/party_status.png")
	get_tree().quit()
