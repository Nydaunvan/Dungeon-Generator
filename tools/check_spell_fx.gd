extends SceneTree
## Effets de sorts avancés (SpellFxLibrary) : choix de l'effet (défaut du style, effet inconnu ou incompatible, « classique »),
## réglages (teinte, intensité), complétion des anciens sorts, paliers de qualité, puis lancer de chaque effet du catalogue
## (aucune erreur de script attendue, caméra recentrée après la secousse, plus aucun effet en cours à la fin).
## Rendu OpenGL : les effets sont joués mais certains éléments (décalque, brume) ne sont pas visibles.
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/check_spell_fx.gd
func _init() -> void:
	root.size = Vector2i(960, 600)
	await process_frame
	var bad := 0
	var lib = load("res://scripts/dungeon/spell_fx_library.gd")
	var vf = load("res://scripts/core/visual_fx.gd")
	vf.force_forward = true
	var st = root.get_node("Settings")
	var data = root.get_node("Data")

	# 1. choix de l'effet
	var cases := [
		[{"style": "arcane", "mode": "damage"}, "arcane_crystal", "sort arcane sans effet : effet par défaut du style"],
		[{"style": "arcane", "mode": "damage", "fx": "arcane_orb"}, "arcane_orb", "effet choisi"],
		[{"style": "arcane", "mode": "damage", "fx": "classic"}, "classic", "effet classique choisi"],
		[{"style": "arcane", "mode": "damage", "fx": "effet_du_futur"}, "arcane_crystal", "effet inconnu : retombe sur le défaut"],
		[{"style": "fire", "mode": "damage", "fx": "arcane_beam"}, "fire_ball", "effet d'un autre style : retombe sur le défaut du style"],
		[{"id": "spell_elementalist3", "style": "fire", "mode": "damage"}, "fire_column", "effet propre au sort d'origine"],
		[{"id": "spell_elementalist1", "style": "fire", "mode": "damageGroup"}, "fire_meteor", "effet propre au sort de zone"],
		[{"style": "arcane", "mode": "healSingle", "fx": "arcane_beam"}, "heal_soft", "effet d'un autre mode : retombe sur le classique"],
		[{"mode": "damage"}, "arcane_crystal", "sans style : arcane, comme en combat"],
	]
	for c in cases:
		var got: String = lib.resolve(c[0])
		if got != c[1]:
			bad += 1
			print("ÉCHEC : ", c[2], " (attendu ", c[1], ", obtenu ", got, ")")
	var keys: Dictionary = lib.fx_keys({"style": "arcane", "mode": "damage", "fxTint": "#4be07a", "fxPower": 1.5})
	if keys.fx != "arcane_crystal" or keys.fxTint != "#4be07a" or not is_equal_approx(float(keys.fxPower), 1.5):
		bad += 1
		print("ÉCHEC : clés d'effet du contexte : ", keys)
	var nat_opts: Array = lib.options("nature", "damage")
	var nat_ids: Array = nat_opts.map(func(o): return o[0])
	if not (nat_ids.has("nature_thorn") and nat_ids.has("nature_vines") and nat_ids.has("nature_lightning") and nat_ids.has("classic")):
		bad += 1
		print("ÉCHEC : l'école de nature doit proposer ses effets : ", nat_opts)
	if lib.default_for("nature", "healParty") != "nature_grove":
		bad += 1
		print("ÉCHEC : effet par défaut de nature (soin de groupe) : ", lib.default_for("nature", "healParty"))

	# 2. anciens sorts et sauvegardes : les champs sont ajoutés, rien d'autre ne change
	var cfg: Dictionary = data.original_config.duplicate(true)
	for s in cfg.spells:
		s.erase("fx")
		s.erase("fxTint")
		s.erase("fxPower")
	data.ensure_defaults(cfg)
	for s in cfg.spells:
		if str(s.get("fx", "?")) != "" or str(s.get("fxTint", "?")) != "" or not is_equal_approx(float(s.get("fxPower", 0.0)), 1.0):
			bad += 1
			print("ÉCHEC : sort non complété : ", s.get("id"))
			break

	# 3. paliers de qualité
	for pair in [["low", 0], ["medium", 1], ["high", 2], ["ultra", 3]]:
		st.set_preset(pair[0])
		if lib.tier() != pair[1]:
			bad += 1
			print("ÉCHEC : palier du niveau ", pair[0], " : ", lib.tier(), " au lieu de ", pair[1])

	# 4. lancer de chaque effet, à chaque palier
	var host := Node3D.new()
	root.add_child(host)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.9, 0)
	host.add_child(cam)
	cam.current = true
	var target := {"pos": Vector3(0, 0.95, -4.0), "h": 1.7, "w": 1.0}
	for level in ["medium", "ultra"]:
		st.set_preset(level)
		for id in lib.CATALOG:
			var e: Dictionary = lib.CATALOG[id]
			for tint in ["", "#4be07a"]:
				var ctx := {"style": e.styles[0], "mode": e.modes[0], "status": "", "targets": [], "ally": 0, "caster": 0,
					"fx": id, "fxTint": tint, "fxPower": 1.5}
				lib.cast(host, cam, "check", target, ctx)
			lib.cast(host, cam, "check", {}, {"style": e.styles[0], "mode": e.modes[0], "fx": id, "fxTint": "", "fxPower": 0.6})
		# capacités de monstres : toutes les écoles, quatre familles de mise en scène, avec et sans monstre à l'écran
		for school in ["fire", "ice", "holy", "shadow", "nature", "arcane", "physical", "bard"]:
			for fxid in ["", "fire_meteor", "fire_column", "phys_power"]:
				lib.cast(host, cam, "check", target, {"style": school, "mode": "damage", "fx": fxid, "fxTint": "", "fxPower": 1.0, "fromMonster": true, "victim": 2, "targets": []})
		lib.cast(host, cam, "check", {}, {"style": "nature", "mode": "damage", "fx": "", "fxTint": "#e04b4b", "fxPower": 1.5, "fromMonster": true, "victim": 0, "targets": []})
		await create_timer(4.5).timeout
		var spell_fx = load("res://scripts/dungeon/spell_fx_3d.gd")
		if spell_fx.busy():
			bad += 1
			print("ÉCHEC : des effets sont encore en cours après 4,5 s (niveau ", level, ")")
		if not is_zero_approx(cam.h_offset) or not is_zero_approx(cam.v_offset):
			bad += 1
			print("ÉCHEC : caméra décalée après la secousse (niveau ", level, ")")
		if host.get_child_count() != 1:
			bad += 1
			print("ÉCHEC : ", host.get_child_count() - 1, " nœud(s) d'effet restant(s) (niveau ", level, ")")
	print("anomalies : ", bad)
	quit(1 if bad > 0 else 0)
