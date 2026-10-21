extends Node
## Retour au mode en ligne : l'accueil rouvre la fenêtre quand la partie en venait ; la victoire du défi de la semaine ne propose que le retour.
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	Data.hub_return = true
	var was := Cloud.is_configured()
	Data.hub_open_pending = Data.hub_return and was
	var layer := CanvasLayer.new()
	add_child(layer)
	var gs := GameState.new()
	gs.cfg = {"rankedKind": "weekly", "title": "t"}
	var m := Dialogs.victory(layer, gs, func(): pass, func(): pass)
	await get_tree().process_frame
	var texts: Array = []
	_buttons(m.get_parent() if m.get_parent() != null else m, texts)
	print("BOUTONS ", texts, " configuré=", was)
	var ok: bool = texts.size() == 1 and (str(texts[0]).contains("accueil") or str(texts[0]).contains("home"))
	print("RESULTAT retour en ligne -> %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()
func _buttons(n: Node, out: Array) -> void:
	if n is Button and (n as Button).text != "":
		out.append((n as Button).text)
	for c in n.get_children():
		_buttons(c, out)
