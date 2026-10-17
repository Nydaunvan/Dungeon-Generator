extends Node
## Effets des monstres : tirage à la génération (parfois oui, parfois non), boss systématiques, coup d'un monstre qui inflige son statut à un héros.
func _ready() -> void:
	var fam := 0
	var with := 0
	var bosses := 0
	var boss_fx := 0
	var no_fam_bad := 0
	for s in 40:
		var cfg := DungeonGenerator.build_config(Data.active(), 3, 13, 11, "normal", [], 1, 900 + s)
		for lv in cfg.levels:
			for m in lv.monsters:
				var icon := str(m.get("icon", "")).trim_prefix("@icon:")
				if m.get("isBoss", false):
					bosses += 1
					boss_fx += 1 if str(m.get("hitStatus", "")) != "" else 0
				elif MonsterEffects.FAMILY.has(icon):
					fam += 1
					with += 1 if str(m.get("hitStatus", "")) != "" else 0
				elif str(m.get("hitStatus", "")) != "":
					no_fam_bad += 1
	var pct := 100.0 * with / maxf(1.0, fam)
	# application sur un héros : 100 coups, chance 100 %
	var gs := GameState.new()
	var hero := {"id": "h", "name": "Test", "hp": 50, "maxHp": 50, "statusEffects": []}
	var sp := MonsterEffects.spell_of({"hitStatus": "stun", "hitStatusLook": "sleep", "hitStatusDuration": 2, "hitStatusPower": 2})
	var applied := Statuses.apply_from_spell(gs, sp, hero, "Test", "m", true)
	var sleep_ok: bool = applied and Statuses.active(hero).size() == 1 and str(Statuses.active(hero)[0].look) == "sleep"
	var good: bool = fam > 100 and pct > 40.0 and pct < 80.0 and bosses == boss_fx and no_fam_bad == 0 and sleep_ok
	print("EFFETS familles=", fam, " avec_effet=", snappedf(pct, 0.1), "% boss=", boss_fx, "/", bosses, " hors_famille=", no_fam_bad, " sommeil_heros=", sleep_ok, " -> ", "OK" if good else "ECHEC")
	get_tree().quit(0 if good else 1)
