extends Node
## Fenêtre des emplacements : après « Sauver ici », la liste doit se rafraîchir toute seule (le bouton « Charger » apparaît) au lieu de rester « vide ».
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/check_slots_ui.tscn

func _buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	Saves.delete_slot(Saves.SLOTS - 1)
	var before := 0
	for i in Saves.SLOTS:
		if not Saves.summary(i).is_empty():
			before += 1
	var host: Node = main._modals()
	SlotsModal.open(host, main.snapshot, Data.launch_save, Callable(), main._slot_opts())
	await get_tree().create_timer(0.5).timeout
	var bs: Array = []
	_buttons(host, bs)
	var here: Array = bs.filter(func(b): return (b as Button).text == L.t("ui.slots_modal.sauver_ici"))
	var bad := 0
	if here.is_empty():
		print("ÉCHEC : aucun bouton « Sauver ici »")
		bad += 1
	else:
		(here[here.size() - 1] as Button).pressed.emit()
		await get_tree().create_timer(3.2).timeout
		var after: Array = []
		_buttons(host, after)
		var loads: Array = after.filter(func(b): return is_instance_valid(b) and (b as Button).visible and (b as Button).text == L.t("ui.slots_modal.charger"))
		print("boutons Charger visibles : ", loads.size(), " (emplacements pleins avant : ", before, ")")
		if loads.size() != before + 1:
			print("ÉCHEC : la liste ne s'est pas rafraîchie après la sauvegarde")
			bad += 1
	Saves.delete_slot(Saves.SLOTS - 1)
	print("OK" if bad == 0 else "%d échec(s)" % bad)
	get_tree().quit(1 if bad else 0)
