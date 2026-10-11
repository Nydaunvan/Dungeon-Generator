class_name CreateChoiceModal
extends RefCounted
## « Créer votre propre donjon » : trois départs possibles — donjon vide, base aléatoire, ou reprendre un de « Mes donjons ».

static func open(host: Node) -> Modal:
	var n := MyDungeons.count()
	var header: Array = [[L.t("ui.create_choice.intro"), UiTheme.PARCH, 14]]
	var opts: Array = [
		{"icon": "🕳", "title": L.t("ui.create_choice.empty_t"), "desc": L.t("ui.create_choice.empty_d"),
			"btn": L.t("ui.create_choice.empty_b"), "cb": func(): Data.create_empty_dungeon()},
		{"icon": "🎲", "title": L.t("ui.create_choice.random_t"), "desc": L.t("ui.create_choice.random_d"),
			"btn": L.t("ui.create_choice.random_b"), "cb": func(): Data.create_own_dungeon()},
		{"icon": "📚", "title": L.fa(L.t("ui.create_choice.mine_t"), n), "desc": L.t("ui.create_choice.mine_d"),
			"btn": L.t("ui.create_choice.mine_b"), "primary": n > 0, "cb": func(): MyDungeonsModal.open(host)},
	]
	return LeaveModal.open(host, L.t("ui.home_screen.creer_votre_propre_donjon"), header, opts, L.t("common.annuler"), true, 560.0)
