extends SceneTree
func _init() -> void:
	await process_frame
	var data = root.get_node("Data")
	data.admin_unlocked = true
	var adm: Node = load("res://scenes/admin.tscn").instantiate()
	root.add_child(adm)
	await create_timer(1.5).timeout
	load("res://scripts/admin/atelier_party.gd").set("sub", "items")
	adm._select_tab("party")
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png("/tmp/claude-0/sh_items.png")
	quit()
