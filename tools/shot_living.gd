extends Control
## Capture de la fiche d'une compétence vivante : godot --path . res://tools/shot_living.tscn -- out=/chemin/nom [w=1280 h=900] [case=sort|talent|instinct]
func _ready() -> void:
	var a := {"w": "1280", "h": "900", "out": "/tmp/living", "case": "sort"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	get_window().size = Vector2i(int(a.w), int(a.h))
	await get_tree().process_frame
	Settings.living_skills = true
	var cfg: Dictionary = (Data.original_config as Dictionary).duplicate(true)
	var gs := GameState.create(cfg)
	var hero: Dictionary = gs.party[0]
	var sid := ""
	match a.case:
		"talent":
			hero["talents"] = [{"id": str(Data.class_talents[str(hero.classId)][0].options[0].id), "level": 5}]
			sid = str(hero.talents[0].id)
		"instinct":
			sid = LivingCatalog.instinct_id(str(Characters.class_def(cfg, str(hero.classId)).get("evolvesFrom", Characters.class_def(cfg, str(hero.classId)).name)))
		_:
			hero["spellsKnown"] = (cfg.spells as Array).filter(func(sp): return str(sp.get("mode", "")) == "damage").map(func(sp): return str(sp.id))
			sid = str(hero.spellsKnown[0])
	var key := LivingCatalog.key(str(hero.id), sid)
	var sk := LivingSkills._sk(gs, key)
	sk.a = 38.0
	var prof := LivingCatalog.profile(cfg, sid)
	sk.t[str(prof.branches[0].trait)] = 46
	sk.t["ins"] = 40
	sk.m = [["first_kill", "g2", 1], ["narrow", "veilleur1", 2], ["env", "crypte", 1]]
	var other := LivingCatalog.key(str(gs.party[1].id), sid)
	LivingSkills.state(gs).rel[LivingSkills._pair(key, other)] = {"v": 8}
	LivingSkills._fragment(gs, 6)
	gs.gold = 200
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	LivingModal.open(host, gs, str(hero.id), sid)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(str(a.out) + ".png")
	get_tree().quit()
