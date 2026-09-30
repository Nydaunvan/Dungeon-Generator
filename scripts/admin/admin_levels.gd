class_name AdminLevels
extends RefCounted

static func build(host: VBoxContainer, admin: Node) -> void:
	var b := Form.panel(host, "Levels")
	Form.hint(b, "Cet onglet est en cours de portage.")
