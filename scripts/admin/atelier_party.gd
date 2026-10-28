class_name AtelierParty
extends RefCounted
## Section « Groupe et objets » : les héros de départ et la bibliothèque d'objets de base, réunis sous un même titre
## avec un sélecteur à deux sous-onglets.

## Sous-onglet affiché : "party" (groupe de départ) ou "items" (objets de base).
static var sub := "party"

static func build(host: Control, admin: Node) -> void:
	if sub == "items":
		AdminItems.build(host, admin)
	else:
		AdminChars.build(host, admin)

## Sélecteur segmenté « Groupe de départ | Objets de base » (maquettes Groupe et Objets).
static func switcher(admin: Node) -> Control:
	var f := Ax.seg([["party", L.t("ui.atelier.tab_party")], ["items", L.t("ui.atelier.tab_items")]], sub, func(id: String):
		if sub != id:
			Ax.flush()
			sub = id
			admin.refresh_tab())
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return f
