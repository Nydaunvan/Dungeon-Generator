extends Node
func _ready() -> void:
	var t = IconResolver.texture("@icon:ring_gold")
	print("RESULTAT anneau : ", "OK " + str(t.get_size()) if t != null and not (t is AtlasTexture) else "ANCIENNE VIGNETTE ou absent")
	get_tree().quit()
