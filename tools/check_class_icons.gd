extends Node
## Toutes les classes (et donc toutes les fenêtres d'évolution) ont une icône qui s'affiche.
func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	var bad := 0
	for cls in Data.original_config.get("classes", []):
		var ico := str(cls.get("icon", ""))
		var tex := IconResolver.texture(ico)
		var ok := tex != null
		if not ok:
			bad += 1
		print(("OK     " if ok else "MANQUE "), cls.id, " ", ico)
	print("RESULTAT icônes de classes -> ", "OK" if bad == 0 else "%d manquante(s)" % bad)
	get_tree().quit()
