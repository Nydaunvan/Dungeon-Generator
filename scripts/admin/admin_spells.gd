class_name AdminSpells
extends RefCounted

static func build(host: VBoxContainer, admin: Node) -> void:
	var b := Form.panel(host, "Spells")
	Form.hint(b, "Cet onglet est en cours de portage.")
