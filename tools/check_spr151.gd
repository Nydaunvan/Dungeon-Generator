extends Node
## Le collier à crocs (spr_151) est servi par l'icône individuelle complétée (plus de coupure à droite).
func _ready() -> void:
	var tex: Texture2D = IconResolver.texture("@icon:spr_151")
	var im: Image = tex.get_image() if tex != null else null
	var xs := 0
	if im != null:
		for x in range(100, im.get_width()):
			for y in im.get_height():
				if im.get_pixel(x, y).a > 0.5:
					xs = maxi(xs, x)
	print("RESULTAT spr_151 : x max opaque = %d -> %s" % [xs, "OK" if xs >= 118 else "ECHEC"])
	get_tree().quit()
