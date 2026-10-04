extends SceneTree
## Changement de langue en pleine partie : godot --script res://tools/test_lang_switch.gd
## Lance une partie, avance d'un pas, bascule FR → EN → FR via le menu et contrôle que la partie (position, or, niveau)
## est conservée et que les textes suivent la langue.
var fails := 0
func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	data.set_lang("fr")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7)
	data.launch(cfg, "random")
	await create_timer(1.5).timeout
	var m = current_scene
	m.gs.gold = 123
	var title_fr := str(m.gs.cfg.get("title", ""))
	for lang in ["en", "fr"]:
		data.set_lang(lang)
		m._on_menu("Lang")
		await create_timer(1.5).timeout
		m = current_scene
		check(int(m.gs.gold) == 123, "or conservé après passage en %s" % lang)
		check(str(m.gs.cfg.get("title", "")) == title_fr, "titre du donjon inchangé (%s)" % lang)
		check(TranslationServer.translate("common.carte") == ("Map" if lang == "en" else "Carte"), "clé traduite en %s" % lang)
	print("ÉCHECS : %d" % fails)
	quit(1 if fails > 0 else 0)
