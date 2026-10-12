extends SceneTree
## Vérifie que l'onglet Graphismes suit l'adaptation automatique : le bouton du niveau réellement appliqué est enfoncé
## et la fenêtre se met à jour toute seule quand la qualité baisse.
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/check_settings_modal.gd
func pressed_names(m: Node) -> Array:
	var out: Array = []
	for b in m.find_children("*", "Button", true, false):
		if (b as Button).toggle_mode and (b as Button).button_pressed and (b as Button).button_group != null:
			out.append((b as Button).text)
	return out

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var st = root.get_node("Settings")
	st.set_preset("ultra")
	var host := Control.new()
	root.add_child(host)
	var m = load("res://scripts/ui/settings_modal.gd").open(host, "graphics")
	await create_timer(0.4).timeout
	var bad := 0
	var a := pressed_names(m)
	print("au départ : ", a)
	if not a.has(st.preset_name("ultra")):
		bad += 1
		print("ÉCHEC : Ultra devrait être enfoncé")
	st.level = "medium"
	st.auto_change = true
	st.changed.emit()
	st.auto_change = false
	await create_timer(0.5).timeout
	var b := pressed_names(m)
	print("après baisse automatique : ", b)
	if not b.has(st.preset_name("medium")) or b.has(st.preset_name("ultra")):
		bad += 1
		print("ÉCHEC : l'indicateur n'a pas suivi la baisse")
	m.close()
	await create_timer(0.3).timeout
	st.set_preset("auto")
	print("anomalies : ", bad)
	quit(1 if bad > 0 else 0)
