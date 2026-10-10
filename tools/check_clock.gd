extends SceneTree
## Horloge de jeu : avance par images, figée pendant une boutique, ne recule jamais, sauvegardée avec la partie.

var fails := 0

func _ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
		printerr("ÉCHEC : " + what)

func _initialize() -> void:
	GameClock.reset()
	for i in 10:
		GameClock.advance(0.1)
	_ok(GameClock.ms == 1000, "10 x 0,1 s = 1000 ms (%d)" % GameClock.ms)
	GameClock.advance(5.0)
	_ok(GameClock.ms == 2000, "une image longue compte au plus 1 s (%d)" % GameClock.ms)
	GameClock.frozen += 1
	GameClock.advance(0.5)
	_ok(GameClock.ms == 2000, "figée : n'avance pas")
	GameClock.frozen -= 1
	GameClock.set_ms(1500)
	_ok(GameClock.ms == 2000, "ne recule jamais")
	GameClock.set_ms(2500)
	_ok(GameClock.ms == 2500, "set_ms avance")
	# sauvegarde : l'horloge est restituée à l'identique ; une sauvegarde sans horloge remet les recharges à zéro
	var gs := GameState.create({"party": [], "levels": [], "title": "t"})
	GameClock.reset(123456)
	var d := gs.to_save()
	_ok(int(d.clock) == 123456, "to_save garde l'horloge")
	GameClock.reset(0)
	GameState.from_save({}, JSON.parse_string(JSON.stringify(d)))
	_ok(GameClock.ms == 123456, "from_save restitue l'horloge (%d)" % GameClock.ms)
	d.erase("clock")
	d["party"] = [{"id": "a", "spellCooldowns": {"x": 99999999}}]
	var old := GameState.from_save({}, d)
	_ok(GameClock.ms == 0 and (old.party[0].spellCooldowns as Dictionary).is_empty(), "ancienne sauvegarde : recharges remises à zéro")
	print("check_clock : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
