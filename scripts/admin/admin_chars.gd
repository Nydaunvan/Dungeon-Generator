class_name AdminChars
extends RefCounted

static func build(host: VBoxContainer, admin: Node) -> void:
	var b := Form.panel(host, "Chars")
	Form.hint(b, "Cet onglet est en cours de portage.")
