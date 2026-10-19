extends Node
## Volet « Détails et sorts » de la fiche héros : sa hauteur doit coller à son contenu (aucun vide en bas).
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	var gs: GameState = main.gs
	var dock: EquipDock = main.dock
	var id := str(gs.party[2].id)
	dock.open_for(id)
	await get_tree().create_timer(0.8).timeout
	dock._toggle_details()
	await get_tree().create_timer(1.6).timeout
	var inner: VBoxContainer = dock._drawer_inner
	var clip: Control = dock._drawer_clip
	var need := inner.get_combined_minimum_size().y
	print("VOLET hauteur=%.1f contenu=%.1f vide=%.1f" % [clip.custom_minimum_size.y, need, clip.custom_minimum_size.y - need])
	dock._scroll.scroll_vertical = 100000
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/drawer.png")
	var ok: bool = clip.custom_minimum_size.y - need < 12.0
	print("RESULTAT volet -> %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()
