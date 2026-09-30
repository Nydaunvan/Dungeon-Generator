class_name AdminItems
extends RefCounted

static func build(host: VBoxContainer, admin: Node) -> void:
	var b := Form.panel(host, "Items")
	Form.hint(b, "Cet onglet est en cours de portage.")
