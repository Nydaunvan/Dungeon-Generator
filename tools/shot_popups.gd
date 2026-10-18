extends Node
## Capture des chiffres de dégâts empilés en lignes (monstre / cartes de héros).
## Usage : xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 res://tools/shot_popups.tscn -- out=/tmp/p

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var p: DamagePopups = main.dmg_popups
	var ids: Array = []
	for c in main.gs.party:
		ids.append("char:" + str(c.id))
	p.show_popup("-2", Color("ffd88a"), "")
	p.show_popup("Résiste", Color("8fc8e8"), "")
	p.show_popup("-3", Color("ff5050"), ids[0])
	p.show_popup("-4", Color("ff5050"), ids[0])
	p.show_popup("+5", Color("7fd17f"), ids[0])
	if ids.size() > 1:
		p.show_popup("-7", Color("c98bff"), ids[1])
	p.show_popup("Groupe soigné", Color("7fd17f"), "party")
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(str(args.get("out", "/tmp/p")) + ".png")
	get_tree().quit()
