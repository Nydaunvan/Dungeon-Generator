class_name AdminGeneral
extends RefCounted
## Onglet « Général » (`#adminGeneral` de l'original) : panneau par panneau, textes et bornes repris des `saveXxx` du HTML.
## Chaque bouton lit ses champs, applique les bornes exactes, écrit TOUTES les clés du panneau, enregistre puis réaffiche les
## valeurs corrigées. Le panneau Combat n'a pas de bouton : il enregistre à chaque modification.

## Indication `.hint` (marge haute -4 px par défaut, 12 px dessous).
## Réglages des méthodes / puzzles / butin : [clé, libellé, pas, min, max] ; "#" = intertitre ; clé finissant par « On » = interrupteur.
const TRAP_FIELDS := [
	["#", "admin.general.pieges_sec_methodes"],
	["methodCount", "admin.general.piege_nb_methodes", 1, 2, 4],
	["statBonus", "admin.general.piege_bonus_stat", 0.5, 0, 10],
	["forceBase", "admin.general.piege_force_base", 1, 0, 100],
	["forceFailPct", "admin.general.piege_force_echec", 5, 50, 300],
	["dispelBase", "admin.general.piege_dissiper_base", 1, 0, 100],
	["dispelStaCost", "admin.general.piege_dissiper_cout", 1, 0, 100],
	["probeBase", "admin.general.piege_sonder_base", 1, 0, 100],
	["probeBonus", "admin.general.piege_sonder_bonus", 1, 0, 50],
	["volunteerBase", "admin.general.piege_volontaire_base", 1, 0, 100],
	["volunteerDmgPct", "admin.general.piege_volontaire_degats", 5, 0, 100],
	["bypassBase", "admin.general.piege_contourner_base", 1, 0, 100],
	["bypassDmgPct", "admin.general.piege_contourner_degats", 5, 0, 100],
	["skipDmgPct", "admin.general.piege_passer_degats", 5, 100, 500],
	["#", "admin.general.pieges_sec_puzzles"],
	["puzzleChancePct", "admin.general.piege_puzzle_chance", 5, 0, 100],
	["puzzleTwistsOn", "admin.general.piege_variantes"],
	["puzzleRuneOn", "admin.general.piege_puzzle_runes"],
	["puzzleRuneLen", "admin.general.piege_runes_longueur", 1, 3, 8],
	["puzzleRuneErrors", "admin.general.piege_erreurs_permises_runes", 1, 0, 3],
	["puzzleWireOn", "admin.general.piege_puzzle_fils"],
	["puzzleWireCount", "admin.general.piege_fils_nombre", 1, 3, 6],
	["puzzleWireErrors", "admin.general.piege_erreurs_permises_fils", 1, 0, 3],
	["puzzleRiddleOn", "admin.general.piege_puzzle_enigme"],
	["puzzleRiddleCount", "admin.general.piege_enigmes_nombre", 1, 1, 4],
	["puzzleRiddleErrors", "admin.general.piege_erreurs_permises_enigme", 1, 0, 3],
	["puzzleTilesOn", "admin.general.piege_puzzle_dalles"],
	["puzzleTilesRows", "admin.general.piege_dalles_rangees", 1, 3, 6],
	["puzzleTilesErrors", "admin.general.piege_erreurs_permises_dalles", 1, 0, 3],
	["#", "admin.general.pieges_sec_butin"],
	["rewardChancePct", "admin.general.piege_butin_jet", 5, 0, 100],
	["rewardPerfectPct", "admin.general.piege_butin_parfait", 5, 0, 100],
	["puzzleRewardPct", "admin.general.piege_butin_puzzle", 5, 0, 100],
	["rewardGoldMin", "admin.general.piege_butin_or_min", 1, 0, 9999],
	["rewardGoldMax", "admin.general.piege_butin_or_max", 1, 0, 9999],
	["rewardXp", "admin.general.piege_butin_xp", 1, 0, 999],
	["rewardHealPct", "admin.general.piege_butin_soin", 5, 0, 100],
]

static func _h(b: Control, text: String, mt: float = -4.0) -> Label:
	return Form.note(b, text, mt, 12.0)

static func _sv(s: SpinBox, v: float) -> void:
	s.set_value_no_signal(v)

static func _clamp(v: float, lo: float, hi: float) -> float:
	return maxf(lo, minf(hi, v))

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	var save: Callable = func(): admin.save()

	# ---- Identité du jeu
	var b := Form.panel(host, L.t("admin.general.identite_du_jeu"))
	var title_in := Form.text_row(b, L.t("admin.general.nom_du_jeu"), str(cfg.get("title", "")), 260.0)
	var act1 := func():
		var t := title_in.text.strip_edges()
		cfg["title"] = t if t != "" else L.t("admin.general.sans_titre")
		title_in.text = cfg["title"]
		save.call()
	Form.actions(b, [[L.t("admin.general.enregistrer_le_titre"), act1, true]])

	# ---- Sécurité
	b = Form.panel(host, L.t("admin.general.securite"))
	var pw_in := Form.text_row(b, L.t("admin.general.mot_de_passe_admin"), str(cfg.get("adminPassword", "")), 200.0)
	_h(b, L.t("admin.general.protection_basique_cote_appareil"), 0.0)
	var pw_save := func():
		var t := pw_in.text.strip_edges()
		cfg["adminPassword"] = t if t != "" else "admin"
		pw_in.text = cfg["adminPassword"]
		save.call()
	Form.actions(b, [[L.t("admin.general.enregistrer_le_mot_de_passe"), pw_save, true], [L.t("admin.general.se_deconnecter"), func(): admin.logout()]])

	# ---- Combat (enregistrement immédiat)
	b = Form.panel(host, "Combat")
	var chk := CheckBox.new()
	chk.text = L.t("admin.general.limite_de_temps_par_tour")
	chk.button_pressed = bool(cfg.get("turnTimerEnabled", true))
	chk.focus_mode = Control.FOCUS_NONE
	Form._place(b, chk, 0.0, 8.0)
	var sec := Form.num_row(b, L.t("admin.general.duree_secondes"), float(cfg.get("turnTimerSeconds", 5)) if float(cfg.get("turnTimerSeconds", 5)) != 0.0 else 5.0)
	var timer_save := func():
		cfg["turnTimerEnabled"] = chk.button_pressed
		var v := sec.value
		if is_nan(v):
			v = 5.0
		var n := int(_clamp(roundf(v), 3.0, 10.0))
		cfg["turnTimerSeconds"] = n
		_sv(sec, n)
		save.call()
	chk.toggled.connect(func(_on): timer_save.call())
	sec.value_changed.connect(func(_v): timer_save.call())
	_h(b, L.t("admin.general.evite_qu_un_joueur_attende"), 6.0)

	# ---- Endurance
	b = Form.panel(host, L.t("common.endurance"))
	var sta: Dictionary = cfg.get("staminaSettings", {"attackCost": 10, "hitGain": 8, "moveGain": 2})
	var vic: Dictionary = Form.sub(sta, "victoryGainPct")
	_h(b, L.t("admin.general.applique_a_tous_les_personnages"))
	_h(b, L.t("admin.general.l_endurance_maximale_se_regle"), 0.0)
	var s_atk := Form.num_row(b, L.t("admin.general.cout_attaque_physique"), float(sta.get("attackCost", 0)))
	_h(b, L.t("admin.general.plafonne_a_2_points_maximum"))
	_h(b, L.t("admin.general.le_cout_en_endurance_des"), 0.0)
	var s_hit := Form.num_row(b, L.t("admin.general.gain_en_etant_touche"), float(sta.get("hitGain", 0)))
	var s_move := Form.num_row(b, L.t("admin.general.gain_leger_par_deplacement"), float(sta.get("moveGain", 2)))
	var s_int := Form.num_row(b, L.t("admin.general.nombre_de_deplacements_requis"), float(sta.get("moveInterval", 1)))
	_h(b, L.t("admin.general.ex_gain_de_1_tous"), 0.0)
	_h(b, L.t("admin.general.en_dessous_du_cout_requis"))
	_h(b, L.t("admin.general.bonus_endurance_a_la_fin"), 10.0)
	var v_easy := Form.num_row(b, L.t("admin.general.fin_de_combat_facile"), float(vic.get("easy", 0)))
	var v_norm := Form.num_row(b, L.t("admin.general.fin_de_combat_normal"), float(vic.get("normal", 0)))
	var v_hard := Form.num_row(b, L.t("admin.general.fin_de_combat_difficile"), float(vic.get("hard", 0)))
	var v_hc := Form.num_row(b, L.t("admin.general.fin_de_combat_cauchemar"), float(vic.get("hardcore", 0)))
	_h(b, L.t("admin.general.regeneration_partielle_de_pv"), 10.0)
	var t_hp := Form.num_row(b, L.t("admin.general.arrivee_sur_un_niveau_pv"), float(sta.get("levelTransitionHpPct", 0)))
	var t_sta := Form.num_row(b, L.t("admin.general.arrivee_sur_un_niveau_endurance"), float(sta.get("levelTransitionStaPct", 0)))
	var act2 := func():
		var ns: Dictionary = sta.duplicate(true)
		ns["attackCost"] = _num0(s_atk)
		ns["hitGain"] = _num0(s_hit)
		ns["moveGain"] = _num0(s_move)
		ns["moveInterval"] = maxf(1.0, _num0(s_int) if _num0(s_int) != 0.0 else 1.0)
		ns["victoryGainPct"] = {"easy": _clamp(_num0(v_easy), 0, 100), "normal": _clamp(_num0(v_norm), 0, 100),
			"hard": _clamp(_num0(v_hard), 0, 100), "hardcore": _clamp(_num0(v_hc), 0, 100)}
		ns["levelTransitionHpPct"] = _clamp(_num0(t_hp), 0, 100)
		ns["levelTransitionStaPct"] = _clamp(_num0(t_sta), 0, 100)
		cfg["staminaSettings"] = ns
		_sv(s_atk, ns.attackCost); _sv(s_hit, ns.hitGain); _sv(s_move, ns.moveGain); _sv(s_int, ns.moveInterval)
		_sv(v_easy, ns.victoryGainPct.easy); _sv(v_norm, ns.victoryGainPct.normal); _sv(v_hard, ns.victoryGainPct.hard); _sv(v_hc, ns.victoryGainPct.hardcore)
		_sv(t_hp, ns.levelTransitionHpPct); _sv(t_sta, ns.levelTransitionStaPct)
		save.call()
	Form.actions(b, [[L.t("admin.general.enregistrer"), act2, true]])

	# ---- Progression au niveau
	b = Form.panel(host, L.t("admin.general.progression_au_niveau"))
	var grow: Dictionary = Form.sub(cfg, "levelUpGrowth")
	_h(b, L.t("admin.general.a_chaque_niveau_gagne_par"))
	var g_stat := Form.num_row(b, L.t("admin.general.stats_de_base_points_cumules"), float(grow.get("statPerLevel", 0)), 0.1)
	_h(b, L.t("admin.general.ex_0_4_force_dex"))
	var g_sta := Form.num_row(b, L.t("admin.general.endurance_de_base_gain_par"), float(grow.get("staminaPerLevel", 0)))
	_h(b, L.t("admin.general.cout_en_or_demande_par"), 10.0)
	var g_tm := Form.num_row(b, L.t("admin.general.maitre_des_talents_cout_de"), float(cfg.get("talentMasterBaseCost", 0)))
	var act3 := func():
		cfg["levelUpGrowth"] = {"statPerLevel": _clamp(_num0(g_stat), 0, 5), "staminaPerLevel": _clamp(_num0(g_sta), 0, 20)}
		cfg["talentMasterBaseCost"] = maxf(0.0, _num0(g_tm))
		_sv(g_stat, cfg.levelUpGrowth.statPerLevel); _sv(g_sta, cfg.levelUpGrowth.staminaPerLevel); _sv(g_tm, cfg.talentMasterBaseCost)
		save.call()
	Form.actions(b, [[L.t("admin.general.enregistrer"), act3, true]])

	# ---- Fontaines
	b = Form.panel(host, L.t("admin.general.fontaines"))
	_h(b, L.t("admin.general.placees_dans_les_niveaux_type"))
	var f_cd := Form.num_row(b, L.t("admin.general.delai_de_recharge_minutes"), float(cfg.get("fountainCooldownMinutes", 10)))
	var act4 := func():
		cfg["fountainCooldownMinutes"] = maxf(5.0, Form.val_or(f_cd, 10.0))
		_sv(f_cd, cfg["fountainCooldownMinutes"])
		save.call()
	Form.actions(b, [[L.t("admin.general.enregistrer"), act4, true]])

	# ---- Pièges — crochetage
	b = Form.panel(host, L.t("admin.general.pieges_crochetage"))
	var tr := _trap_cfg(cfg)
	_h(b, L.t("admin.general.chance_de_desamorcer_un_piege"))
	var t_base := Form.num_row(b, L.t("admin.general.chance_de_base"), tr.base)
	var t_rogue := Form.num_row(b, L.t("admin.general.bonus_par_roublard_voleur"), tr.rogueBonus)
	var t_ass := Form.num_row(b, L.t("admin.general.bonus_assassin"), tr.assassinBonus)
	var t_dex := Form.num_row(b, L.t("admin.general.bonus_de_dexterite_par_point"), tr.dexBonus, 0.5)
	var t_cap := Form.num_row(b, L.t("admin.general.dexterite_prise_en_compte_max"), tr.dexCap)
	var t_min := Form.num_row(b, L.t("admin.general.plafond_minimum"), tr.min)
	var t_max := Form.num_row(b, L.t("admin.general.plafond_maximum"), tr.max)
	var t_crit := Form.num_row(b, L.t("admin.general.surcout_de_l_echec_critique"), tr.critExtraDmg)
	_h(b, L.t("admin.general.degats_un_piege_pourcentage_des"), 10.0)
	var t_dmin := Form.num_row(b, L.t("admin.general.degats_un_piege_minimum_des"), tr.dmgPctMin)
	var t_dmax := Form.num_row(b, L.t("admin.general.degats_un_piege_maximum_des"), tr.dmgPctMax)
	var act5 := func():
		var mn := _clamp(_num0(t_min), 0, 100)
		var mx := maxf(mn, _clamp(_num0(t_max), 0, 100))
		var dmn := _clamp(_num0(t_dmin), 0, 100)
		var o := {"base": _clamp(_num0(t_base), 0, 100), "rogueBonus": _clamp(_num0(t_rogue), 0, 100), "assassinBonus": _clamp(_num0(t_ass), 0, 100),
			"dexBonus": _clamp(_num0(t_dex), 0, 10), "min": mn, "max": mx, "critExtraDmg": _clamp(_num0(t_crit), 0, 300),
			"dmgPctMin": dmn, "dmgPctMax": maxf(dmn, _clamp(_num0(t_dmax), 0, 100)), "dexCap": _clamp(_num0(t_cap), 0, 50)}
		var tcur: Dictionary = Form.sub(cfg, "trapSettings")
		for k in o:
			tcur[k] = o[k]
		_sv(t_base, o.base); _sv(t_rogue, o.rogueBonus); _sv(t_ass, o.assassinBonus); _sv(t_dex, o.dexBonus); _sv(t_min, o.min)
		_sv(t_max, o.max); _sv(t_crit, o.critExtraDmg); _sv(t_dmin, o.dmgPctMin); _sv(t_dmax, o.dmgPctMax); _sv(t_cap, o.dexCap)
		save.call()
	Form.actions(b, [[L.t("admin.general.enregistrer"), act5, true]])

	# ---- Pièges — méthodes, puzzles et butin
	b = Form.panel(host, L.t("admin.general.pieges_methodes"))
	var ts: Dictionary = Form.sub(cfg, "trapSettings")
	var tr2 := _trap_cfg(cfg)
	_h(b, L.t("admin.general.pieges_methodes_aide"))
	var fields := {}
	var switches := {}
	for sp in TRAP_FIELDS:
		if sp[0] == "#":
			_h(b, L.t(sp[1]), 14.0)
		elif sp[0].ends_with("On"):
			switches[sp[0]] = Form.check(b, L.t(sp[1]), {"v": float(tr2[sp[0]]) > 0.5}, "v")
		else:
			fields[sp[0]] = Form.num_row(b, L.t(sp[1]), float(tr2[sp[0]]), float(sp[2]))
	var act_trap2 := func():
		for sp in TRAP_FIELDS:
			if sp[0] == "#":
				continue
			if sp[0].ends_with("On"):
				ts[sp[0]] = 1.0 if (switches[sp[0]] as CheckBox).button_pressed else 0.0
			else:
				ts[sp[0]] = _clamp(_num0(fields[sp[0]]), float(sp[3]), float(sp[4]))
				_sv(fields[sp[0]], ts[sp[0]])
		if float(ts.get("rewardGoldMax", 60)) < float(ts.get("rewardGoldMin", 15)):
			ts["rewardGoldMax"] = ts["rewardGoldMin"]
			_sv(fields["rewardGoldMax"], ts["rewardGoldMax"])
		save.call()
	Form.actions(b, [[L.t("admin.general.enregistrer"), act_trap2, true]])

	# ---- Objets légendaires
	b = Form.panel(host, L.t("admin.general.objets_legendaires"))
	_h(b, L.t("admin.general.applique_aux_donjons_generes"))
	var l_ch := Form.num_row(b, L.t("admin.general.chance_sur_le_butin_de"), float(cfg.get("legendaryChancePct", 25)))
	var act6 := func():
		cfg["legendaryChancePct"] = _clamp(l_ch.value, 0, 100)
		_sv(l_ch, cfg["legendaryChancePct"])
		save.call()
	Form.actions(b, [[L.t("admin.general.enregistrer"), act6, true]])

	# ---- Répartition de l'expérience
	b = Form.panel(host, L.t("admin.general.repartition_de_l_experience"))
	var xp: Dictionary = cfg.get("xpSettings", {})
	_h(b, L.t("admin.general.la_mort_un_monstre_repartit"))
	var x_ratio := Form.num_row(b, L.t("admin.general.ratio_soins_contribution"), float(xp.get("healRatio", 0.8)), 0.1)
	var act7 := func():
		var v := x_ratio.value
		cfg["xpSettings"] = {"healRatio": 0.5 if is_nan(v) else _clamp(v, 0, 2)}
		_sv(x_ratio, cfg.xpSettings.healRatio)
		save.call()
	Form.actions(b, [[L.t("admin.general.enregistrer"), act7, true]])

	# ---- Configuration
	b = Form.panel(host, "Configuration")
	_h(b, L.t("admin.general.la_configuration_personnages"))
	Form.actions(b, [
		[L.t("admin.general.exporter_json"), func(): export_config(admin)],
		[L.t("admin.general.importer_json"), func(): _import(admin)],
		[L.t("admin.general.reinitialiser_aux_valeurs_par"), func():
			Dialogs.confirm(admin.modals(), "", L.t("admin.general.reinitialiser_toute_la_configuration"), func():
				Data.reset_config()
				admin.refresh_tab()
				admin.say(admin._now_message()))]])
	admin.admin_status = Form.status_label(b)

	# ---- Code de donjon
	b = Form.panel(host, L.t("admin.general.code_de_donjon"))
	_h(b, L.t("admin.general.alternative_a_l_export_import"))
	var out: TextEdit = null
	var status: Label = null
	Form.actions(b, [[L.t("admin.general.generer_le_code_de_ce"), func(): Form.generate_code(Data.admin_config(), out, status)]])
	out = Form.code_area(b, "", true, 80.0, 8.0)
	out.visible = false
	status = Form.status_label(b)
	_h(b, L.t("admin.general.coller_ci_dessous_un_code"), 14.0)
	var inp := Form.code_area(b, L.t("admin.general.collez_le_code_ici"), false, 80.0, 0.0)
	Form.actions(b, [[L.t("admin.general.charger_ce_code"), func(): _load_code(admin, inp)]])

## `trapCfg` : réglages de crochetage avec leurs valeurs par défaut (champ absent / vide / illisible → défaut).
static func _trap_cfg(cfg: Dictionary) -> Dictionary:
	return TrapRules.cfg(cfg)

## `Number(champ.value)||0`.
static func _num0(s: SpinBox) -> float:
	var v := s.value
	return 0.0 if is_nan(v) else v

## `exportConfig` : téléchargement de <titre>.json (indentation 2), sans copie dans le presse-papiers.
static func export_config(admin: Node) -> void:
	Files.save_text(admin.modals(), Data.export_name(str(Data.admin_config().get("title", ""))), Data.export_json())

## `importConfigFile` : accepte {config, save} ou une configuration nue.
static func _import(admin: Node) -> void:
	Files.pick_text(admin.modals(), func(text: String):
		if not Saves.is_valid_json(text):
			Form.alert(admin.modals(), L.t("admin.general.ce_fichier_n_est_pas"))
			return
		var data := Saves.parse_import(text)
		var cfg: Dictionary = data.get("config", {}) if data.get("config") is Dictionary else {}
		if cfg.is_empty():
			Form.alert(admin.modals(), L.t("admin.general.ce_fichier_ne_contient_pas"))
			return
		Data.ensure_defaults(cfg)
		Data.set_admin_config(cfg)
		Data.save_config()
		admin.refresh_tab())

## `loadDungeonCodeIntoAdmin`.
static func _load_code(admin: Node, inp: TextEdit) -> void:
	if inp.text.strip_edges() == "":
		return
	Dialogs.confirm(admin.modals(), "", L.t("admin.general.charger_ce_code_remplacera_entierement"), func():
		var cfg := Data.decode_code(inp.text)
		if cfg.is_empty():
			Form.alert(admin.modals(), L.t("common.ce_code_est_invalide_ou"))
			return
		Data.ensure_defaults(cfg)
		Data.set_admin_config(cfg)
		Data.save_config()
		inp.text = ""
		admin.refresh_tab())
