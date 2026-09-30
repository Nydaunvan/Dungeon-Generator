class_name AdminClasses
extends RefCounted

static func build(host: VBoxContainer, admin: Node) -> void:
	var b := Form.panel(host, "Classes")
	Form.hint(b, "Cet onglet est en cours de portage.")
