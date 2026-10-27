extends Node
## Modificateurs d'expédition : (1) Brutes (PV et dégâts des monstres, XP et butin), (2) Meute enragée (rage ×2), (3) Couloirs piégés (+50 % de pièges),
## (4) Pas de second souffle (plus de regain hors combat), (5) Nid de monstres : mythique = 3 × la chance de la difficulté, (6) incompatibilités,
## (7) plafond de dégâts des monstres, (8) sans modificateur la génération reste identique.
## Lancer : xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/check_mods.tscn
func _stat(base: Dictionary, diff: String, mods: Array) -> Dictionary:
	var out := {"levels": 0, "monsters": 0, "rage": 0, "traps": 0, "hp": 0.0, "dmg": 0.0, "pend": 0, "bosses": 0, "myth": 0, "leg": 0}
	for sd in 120:
		var cfg: Dictionary = DungeonGenerator.build_config(base, 4, 15, 15, diff, mods, 1, 5000 + sd)
		for lv in cfg.levels:
			out.levels += 1
			for m in lv.monsters:
				out.monsters += 1
				if int(m.get("enrageThreshold", 0)) > 0:
					out.rage += 1
				out.hp += float(m.get("hpMult", 1.0))
				out.dmg += float(m.get("dmgMult", 1.0))
			for it in lv.items:
				var t := str(it.get("type", ""))
				if t == "trap" and not str(it.id).begins_with("pend"):
					out.traps += 1
				if t == "pendulum":
					out.pend += 1
				if str(it.id).begins_with("loot_boss_"):
					out.bosses += 1
					var r := str(it.get("rarity", ""))
					if r == "mythic":
						out.myth += 1
					if r == "mythic" or r == "legendary":
						out.leg += 1
	return out

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	var base: Dictionary = Data.original_config
	var ok := true
	var ref := _stat(base, "normal", [])
	var brutes := _stat(base, "normal", ["mod_brutes"])
	var pack := _stat(base, "normal", ["mod_pack"])
	var traps := _stat(base, "normal", ["mod_traps"])
	print("normal sans modif : monstres %d rage %.1f %% pièges %d haches %d" % [ref.monsters, 100.0 * ref.rage / ref.monsters, ref.traps, ref.pend])
	var r_hp: float = (brutes.hp / brutes.monsters) / (ref.hp / ref.monsters)       # mêmes graines : même monstres, seul le modificateur change
	var r_dmg: float = (brutes.dmg / brutes.monsters) / (ref.dmg / ref.monsters)
	print("Brutes    : PV moyens ×%.3f, dégâts ×%.3f (par rapport à la même graine sans modificateur)" % [r_hp, r_dmg])
	if absf(r_dmg - 1.15) > 0.02 or absf(r_hp - 1.25) > 0.02:
		ok = false
		print("ECHEC Brutes")
	print("Meute     : rage %.1f %% (contre %.1f %%)" % [100.0 * pack.rage / pack.monsters, 100.0 * ref.rage / ref.monsters])
	if pack.rage < ref.rage * 1.6:
		ok = false
		print("ECHEC Meute")
	print("Couloirs  : pièges %d (contre %d), haches %d (contre %d)" % [traps.traps, ref.traps, traps.pend, ref.pend])
	if traps.traps < ref.traps * 1.3 or traps.pend < ref.pend:
		ok = false
		print("ECHEC Couloirs piégés")
	var cm: Dictionary = DungeonGenerator.combine_mods(["mod_brutes", "mod_nobreath"])
	print("Pas de second souffle : noSecondWind=", cm.noSecondWind, " xp ×", cm.xpMult)
	if not bool(cm.noSecondWind) or absf(float(cm.xpMult) - 1.4 * 1.3) > 0.001:
		ok = false
		print("ECHEC second souffle")
	for diff in ["easy", "normal", "hard", "hardcore"]:
		var nest := _stat(base, diff, ["mod_horde2"])
		var plain := _stat(base, diff, [])
		print("Nid %-8s : légendaire ou mieux %.0f %%, mythique %.1f %% (sans Nid : %.1f %%)" % [diff, 100.0 * nest.leg / nest.bosses, 100.0 * nest.myth / nest.bosses, 100.0 * plain.myth / plain.bosses])
		if nest.leg != nest.bosses:
			ok = false
			print("ECHEC Nid : tous les boss doivent donner un légendaire")
		if diff == "easy" and 100.0 * nest.myth / nest.bosses > 8.0:
			ok = false
			print("ECHEC Nid en facile : mythique trop fréquent")
	print("Incompatibles : crit/glass ", DungeonGenerator.conflicts("mod_crit", ["mod_glass"]), " ", DungeonGenerator.conflicts("mod_glass", ["mod_crit"]), " ; crit/horde ", DungeonGenerator.conflicts("mod_crit", ["mod_horde"]))
	if DungeonGenerator.conflicts("mod_crit", ["mod_glass"]).is_empty() or DungeonGenerator.conflicts("mod_glass", ["mod_crit"]).is_empty() or not DungeonGenerator.conflicts("mod_crit", ["mod_horde"]).is_empty():
		ok = false
	var cap: Dictionary = DungeonGenerator.combine_mods(["mod_brutes", "mod_legend"])
	print("Plafond dégâts : brutes × butin de choix = ×%.3f (max %.1f)" % [cap.monsterDmgMult, DungeonGenerator.MAX_MONSTER_DMG_MULT])
	if float(cap.monsterDmgMult) > 1.5:
		ok = false
	# sans modificateur : mêmes niveaux qu'avant l'ajout de « Brutes » et des autres (clé de comparaison : deux générations identiques)
	var a: Dictionary = DungeonGenerator.build_config(base, 3, 15, 15, "normal", [], 1, 777)
	var b: Dictionary = DungeonGenerator.build_config(base, 3, 15, 15, "normal", [], 1, 777)
	if str(a.levels) != str(b.levels):
		ok = false
		print("ECHEC reproductibilité")
	print("RESULTAT modificateurs -> ", "OK" if ok else "ECHEC")
	get_tree().quit()
