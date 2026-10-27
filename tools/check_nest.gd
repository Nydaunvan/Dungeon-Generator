extends Node
## Modificateur « Nid de monstres » : le butin du boss est toujours légendaire ou mythique, avec 3 fois la chance de mythique de la difficulté
## (Normale, 3 niveaux : 3 × 4 % × niveau, soit 0, 12 et 24 % : environ 12 % en moyenne).
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var leg := 0
	var myth := 0
	var other := 0
	for n in 60:
		var cfg: Dictionary = DungeonGenerator.build_config(Data.original_config, 3, 15, 15, "normal", ["mod_horde2"], 1, 9000 + n)
		for lv in cfg.levels:
			for it in lv.items:
				if str(it.get("id", "")).begins_with("loot_boss_"):
					match Rarity.of(it):
						"legendary": leg += 1
						"mythic": myth += 1
						_: other += 1
	var tot := leg + myth
	var pct := 100.0 * float(myth) / maxf(1.0, float(tot))
	print("NID légendaires=", leg, " mythiques=", myth, " autres=", other, " part mythique=", snappedf(pct, 0.1), " %")
	var ok := other == 0 and tot >= 150 and pct > 6.0 and pct < 18.0
	print("RESULTAT nid de monstres -> ", "OK" if ok else "ECHEC")
	get_tree().quit()
