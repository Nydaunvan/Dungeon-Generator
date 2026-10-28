class_name AdminGeneral
extends RefCounted
## Pages de règles et de projet de l'atelier (maquettes Combat, Progression, Exploration, Pièges, Identité, Partage) :
## cartes à deux colonnes, réglages en ligne (libellé + « par défaut », curseur, valeur), interrupteurs, enregistrement automatique.
## Textes, bornes et clés de configuration repris des `saveXxx` du HTML d'origine.

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
	["exertBase", "admin.general.piege_effort_base", 1, 0, 100],
	["exertStaPct", "admin.general.piege_effort_cout", 5, 0, 100],
	["exertDmgPct", "admin.general.piege_effort_degats", 5, 0, 200],
	["skipDmgPct", "admin.general.piege_passer_degats", 5, 100, 500],
	["#", "admin.general.pieges_sec_pendule"],
	["pendulumChancePct", "admin.general.pendule_chance", 5, 0, 100],
	["pendulumMinLevel", "admin.general.pendule_niveau_min", 1, 1, 10],
	["pendulumDodgeBase", "admin.general.pendule_esquive_base", 1, 0, 100],
	["pendulumDexBonus", "admin.general.pendule_esquive_dex", 0.5, 0, 10],
	["pendulumMin", "admin.general.pendule_esquive_min", 1, 0, 100],
	["pendulumMax", "admin.general.pendule_esquive_max", 1, 0, 100],
	["pendulumDmgPct", "admin.general.pendule_degats", 5, 50, 400],
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


## Pages de l'atelier.
const PAGES := {
	"combat": ["combat"], "progress": ["progress"], "explore": ["explore"], "traps": ["traps"],
	"identity": ["identity"], "share": ["share"],
}

## Réglages affichés sur la page (chemin, valeur par défaut) : remise par défaut et décompte des réglages modifiés.
static var reg: Array = []
static var _count_lbl: Label = null
static var _cfg: Dictionary = {}
static var _preview: Array = []            ## aperçu d'esquive : [{"lbl": Label, "hero": Dictionary}]

static func build_page(host: Control, admin: Node, page: String) -> void:
	_cfg = Data.admin_config()
	_count_lbl = null
	_preview = []
	match page:
		"combat": _p_combat(host, admin)
		"progress": _p_progress(host, admin)
		"explore": _p_explore(host, admin)
		"traps": _p_traps(host, admin)
		"identity": _p_identity(host, admin)
		"share": _p_share(host, admin)

# ------------------------------------------------------------------ valeurs

## Valeur d'origine d'un réglage (donjon livré avec le jeu), ou null.
static func _orig(parts: PackedStringArray) -> Variant:
	var v: Variant = Data.original_config
	for k in parts:
		if v is Dictionary and (v as Dictionary).has(k):
			v = v[k]
		else:
			return null
	return v

## Dictionnaire qui porte le réglage `path` (sous-dictionnaires créés au besoin) et sa clé finale.
static func _at(cfg: Dictionary, parts: PackedStringArray) -> Dictionary:
	var d := cfg
	for i in parts.size() - 1:
		d = Form.sub(d, parts[i])
	return d

static func _default_of(parts: PackedStringArray, fb: Variant) -> Variant:
	var def: Variant = _orig(parts)
	if def == null and parts[0] == "trapSettings" and TrapRules.DEFAULTS.has(parts[parts.size() - 1]):
		def = TrapRules.DEFAULTS[parts[parts.size() - 1]]
	if def == null:
		def = fb
	return def

static func _differs(cur: Variant, def: Variant) -> bool:
	if cur is bool or def is bool:
		return bool(cur) != bool(def)
	return not is_equal_approx(float(cur), float(def))

static func _modified_count() -> int:
	var n := 0
	for e in reg:
		var parts: PackedStringArray = e.p
		var cur: Variant = _at(_cfg, parts).get(parts[parts.size() - 1], e.d)
		if _differs(cur, e.d):
			n += 1
	return n

## Une valeur vient de changer : décompte, aperçu et enregistrement différé.
static func _changed() -> void:
	if _count_lbl != null and is_instance_valid(_count_lbl):
		var n := _modified_count()
		_count_lbl.text = L.fa(L.t("ui.atelier.n_modified"), n) if n > 0 else ""
		_count_lbl.visible = n > 0
	_refresh_preview()
	Ax.changed()

## Réglage numérique en ligne. `path` = chemin pointé dans la configuration ; `fb` = défaut si ni le donjon d'origine ni les règles
## de pièges n'en donnent un ; `post(valeur)` applique une contrainte entre champs (ex. maximum ≥ minimum).
static func _s(b: Control, label: String, path: String, lo: float, hi: float, step: float, fb: float = 0.0, unit: String = "", post: Callable = Callable()) -> Control:
	var parts := path.split(".")
	var key := parts[parts.size() - 1]
	var def := float(_default_of(parts, fb))
	reg.append({"p": parts, "d": def})
	var cur := float(_at(_cfg, parts).get(key, def))
	var write := func(v: float):
		_at(_cfg, parts)[key] = int(v) if (step >= 1.0 and is_equal_approx(v, roundf(v))) else v
		if post.is_valid():
			post.call(v)
		_changed()
	return Ax.setting(b, label, clampf(cur, lo, hi), lo, hi, step, def, unit, write)

## Interrupteur lié à `path` (défaut : valeur d'origine, sinon `fb`).
static func _c(b: Control, label: String, path: String, fb: bool = true, detail: String = "") -> Control:
	var parts := path.split(".")
	var key := parts[parts.size() - 1]
	var def := bool(_default_of(parts, fb))
	reg.append({"p": parts, "d": def})
	var cur := bool(_at(_cfg, parts).get(key, def))
	return Ax.switch_row(b, label, cur, func(on: bool):
		_at(_cfg, parts)[key] = on
		_changed(), detail)

static func _note(b: Control, text: String) -> Label:
	var l := Ax.para(text, 12, Ax.MUTED)
	b.add_child(l)
	return l

## Intertitre à l'intérieur d'une carte.
static func _sub(b: Control, text: String, top: int = 6) -> void:
	var k := Ax.kicker(text, 11)
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	k.custom_minimum_size.x = 60
	b.add_child(Ax.margin(k, 0, top, 0, 0))

## Après avoir écrit une valeur : le maximum ne descend pas sous le minimum (et réciproquement), dans la configuration.
static func _keep_order(lo_path: String, hi_path: String) -> Callable:
	return func(_v: float):
		var lp := lo_path.split(".")
		var hp := hi_path.split(".")
		var ld := _at(_cfg, lp)
		var hd := _at(_cfg, hp)
		var lv := float(ld.get(lp[lp.size() - 1], 0.0))
		var hv := float(hd.get(hp[hp.size() - 1], 0.0))
		if hv < lv:
			hd[hp[hp.size() - 1]] = lv

# ------------------------------------------------------------------ en-tête, ancres, colonnes

## Colonnes de cartes : deux sur écran large, une sur écran étroit (les deux renvoient alors la même).
static func _two(page: VBoxContainer, admin: Node) -> Array:
	if admin.size.x < 1000.0:
		var one := Ax.vbox(20)
		page.add_child(one)
		return [one, one]
	var row := Ax.hbox(20)
	page.add_child(row)
	var l := Ax.vbox(20)
	var r := Ax.vbox(20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(r)
	return [l, r]

## En-tête : « RÈGLES DU JEU » + titre, état d'enregistrement et « Remettre par défaut ».
static func _head(page: VBoxContainer, admin: Node, id: String, reset: bool = true) -> void:
	reg.clear()
	var row := BoxContainer.new()
	row.vertical = admin.size.x < 860.0
	row.add_theme_constant_override("separation", 20)
	page.add_child(row)
	var h := Ax.head(Atelier.kicker_of(id), Atelier.title_of(id), 30)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(h)
	if not reset:
		return
	var right := Ax.hbox(10)
	right.size_flags_vertical = Control.SIZE_SHRINK_END
	_count_lbl = Ax.lab("", 13, Ax.GOLD)
	_count_lbl.visible = false
	_count_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(_count_lbl)
	var st := Ax.lab(L.t("ui.atelier.autosave"), 13, Ax.MUTED)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(st)
	admin.set("admin_status", st)
	right.add_child(Ax.btn(L.t("ui.atelier.reset_page"), func():
		Dialogs.confirm(admin.modals(), "", L.t("ui.atelier.reset_confirm"), func(): reset_page(admin)), "ghost", 38.0, 14))
	row.add_child(right)

## Rangée d'ancres (une pastille par carte) qui fait défiler jusqu'à la carte.
static func _anchors(page: VBoxContainer, admin: Node, items: Array) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	page.add_child(flow)
	page.move_child(flow, 1)
	for i in items.size():
		var card: Control = (items[i][1] as Control).get_meta("card")
		var b := Ax.pill(str(items[i][0]), i == 0, Callable(), Ax.GOLD, 34.0, 13, 14)
		b.pressed.connect(func():
			var sc: ScrollContainer = admin._scroll
			if sc != null and is_instance_valid(sc):
				sc.scroll_vertical = maxi(0, int(card.global_position.y - sc.global_position.y + sc.scroll_vertical) - 12)
			for j in flow.get_child_count():
				Ax.pill_set(flow.get_child(j) as Button, flow.get_child(j) == b))
		flow.add_child(b)

## « Remettre cette page par défaut » : réécrit les réglages affichés avec leur valeur d'origine.
static func reset_page(admin: Node) -> void:
	for e in reg:
		var parts: PackedStringArray = e.p
		_at(Data.admin_config(), parts)[parts[parts.size() - 1]] = e.d
	admin.save()
	admin.refresh_tab()

# ------------------------------------------------------------------ Combat

static func _p_combat(host: Control, admin: Node) -> void:
	var page := Ax.scroll_page(host, admin, 40, 28, 18)
	_head(page, admin, "combat")
	var cols := _two(page, admin)
	# ---- Tour par tour
	var t := Ax.card(cols[0], L.t("ui.atelier.card_turn"), L.t("admin.general.evite_qu_un_joueur_attende"))
	_c(t, L.t("admin.general.limite_de_temps_par_tour"), "turnTimerEnabled", true)
	_s(t, L.t("admin.general.duree_secondes"), "turnTimerSeconds", 3, 10, 1, 5, " s")
	# ---- Endurance
	var e := Ax.card(cols[1], L.t("common.endurance"), L.t("admin.general.applique_a_tous_les_personnages"))
	_note(e, L.t("admin.general.l_endurance_maximale_se_regle"))
	_s(e, L.t("admin.general.cout_attaque_physique"), "staminaSettings.attackCost", 0, 2, 1, 2)
	_note(e, L.t("admin.general.plafonne_a_2_points_maximum"))
	_s(e, L.t("admin.general.gain_en_etant_touche"), "staminaSettings.hitGain", 0, 50, 1, 8)
	_s(e, L.t("admin.general.gain_leger_par_deplacement"), "staminaSettings.moveGain", 0, 20, 1, 2)
	_s(e, L.t("admin.general.nombre_de_deplacements_requis"), "staminaSettings.moveInterval", 1, 20, 1, 1)
	_note(e, L.t("admin.general.ex_gain_de_1_tous"))
	_note(e, L.t("admin.general.en_dessous_du_cout_requis"))
	_sub(e, L.t("admin.general.bonus_endurance_a_la_fin"))
	_s(e, L.t("admin.general.fin_de_combat_facile"), "staminaSettings.victoryGainPct.easy", 0, 100, 1, 4, " %")
	_s(e, L.t("admin.general.fin_de_combat_normal"), "staminaSettings.victoryGainPct.normal", 0, 100, 1, 6, " %")
	_s(e, L.t("admin.general.fin_de_combat_difficile"), "staminaSettings.victoryGainPct.hard", 0, 100, 1, 9, " %")
	_s(e, L.t("admin.general.fin_de_combat_cauchemar"), "staminaSettings.victoryGainPct.hardcore", 0, 100, 1, 13, " %")
	# ---- Rage et effets des monstres
	var r := Ax.card(cols[0], L.t("ui.atelier.card_rage"), L.t("admin.general.rage_des_monstres_aide"))
	_s(r, L.t("admin.general.rage_chance_monstres"), "monsterRageChancePct", 0, 100, 1, 25, " %")
	_c(r, L.t("admin.general.rage_boss_systematique"), "bossRage", true)
	_sub(r, L.t("admin.general.effets_monstres"), 10)
	_note(r, L.t("admin.general.effets_monstres_aide"))
	_s(r, L.t("admin.general.effets_monstres_chance"), "monsterStatusChancePct", 0, 100, 1, 60, " %")
	_c(r, L.t("admin.general.effets_boss_systematique"), "bossStatus", true)
	# ---- Boss et résistances
	var b := Ax.card(cols[1], L.t("ui.atelier.card_boss"), L.t("admin.general.boss_aide"))
	_s(b, L.t("admin.general.boss_pv"), "bossHpMult", 0.5, 10, 0.1, 1.8, " ×")
	_s(b, L.t("admin.general.boss_pv_final"), "bossFinalHpMult", 0.5, 10, 0.1, 2.2, " ×")
	_s(b, L.t("admin.general.boss_degats"), "bossDmgPct", 0, 200, 1, 10, " %")
	_s(b, L.t("admin.general.boss_recompense"), "bossRewardPct", 0, 300, 1, 25, " %")
	_sub(b, L.t("admin.general.resistances"), 10)
	_note(b, L.t("admin.general.resistances_aide"))
	_c(b, L.t("admin.general.resistances_boss"), "bossResist", true)
	_anchors(page, admin, [[L.t("ui.atelier.card_turn"), t], [L.t("common.endurance"), e], [L.t("ui.atelier.card_rage"), r], [L.t("ui.atelier.card_boss"), b]])

# ------------------------------------------------------------------ Progression

static func _p_progress(host: Control, admin: Node) -> void:
	var page := Ax.scroll_page(host, admin, 40, 28, 18)
	_head(page, admin, "progress")
	var cols := _two(page, admin)
	var g := Ax.card(cols[0], L.t("admin.general.progression_au_niveau"), L.t("admin.general.a_chaque_niveau_gagne_par"))
	_s(g, L.t("admin.general.stats_de_base_points_cumules"), "levelUpGrowth.statPerLevel", 0, 5, 0.1, 0.4)
	_note(g, L.t("admin.general.ex_0_4_force_dex"))
	_s(g, L.t("admin.general.endurance_de_base_gain_par"), "levelUpGrowth.staminaPerLevel", 0, 20, 1, 2)
	var x := Ax.card(cols[1], L.t("admin.general.repartition_de_l_experience"), L.t("admin.general.la_mort_un_monstre_repartit"))
	_s(x, L.t("admin.general.ratio_soins_contribution"), "xpSettings.healRatio", 0, 2, 0.1, 0.8)
	var c := Ax.card(cols[0], L.t("ui.atelier.card_costs"), L.t("admin.general.cout_en_or_demande_par"))
	_s(c, L.t("admin.general.maitre_des_talents_cout_de"), "talentMasterBaseCost", 0, 1000, 5, 80, " " + L.t("ui.atelier.gold_unit"))
	var l := Ax.card(cols[1], L.t("admin.general.objets_legendaires"), L.t("admin.general.applique_aux_donjons_generes"))
	_s(l, L.t("admin.general.chance_sur_le_butin_de"), "legendaryChancePct", 0, 100, 1, 25, " %")
	_anchors(page, admin, [[L.t("admin.general.progression_au_niveau"), g], [L.t("admin.general.repartition_de_l_experience"), x], [L.t("ui.atelier.card_costs"), c], [L.t("admin.general.objets_legendaires"), l]])

# ------------------------------------------------------------------ Exploration

static func _p_explore(host: Control, admin: Node) -> void:
	var page := Ax.scroll_page(host, admin, 40, 28, 18)
	_head(page, admin, "explore")
	var cols := _two(page, admin)
	var r := Ax.card(cols[0], L.t("ui.atelier.card_regen_walk"), L.t("admin.general.regeneration_partielle_de_pv"), 20, 16)
	_c(r, L.t("admin.general.regen_exploration"), "staminaSettings.exploreRegen", true)
	_note(r, L.t("admin.general.regen_exploration_hint"))
	var a := Ax.card(cols[1], L.t("ui.atelier.card_arrive"), "", 20, 16)
	_s(a, L.t("admin.general.arrivee_sur_un_niveau_pv"), "staminaSettings.levelTransitionHpPct", 0, 100, 1, 25, " %")
	_s(a, L.t("admin.general.arrivee_sur_un_niveau_endurance"), "staminaSettings.levelTransitionStaPct", 0, 100, 1, 25, " %")
	var f := Ax.card(cols[1], L.t("admin.general.fontaines"), L.t("admin.general.placees_dans_les_niveaux_type"), 20, 16)
	_s(f, L.t("admin.general.delai_de_recharge_minutes"), "fountainCooldownMinutes", 5, 120, 1, 10, " min")

# ------------------------------------------------------------------ Pièges et puzzles

## Champ de pièges [clé, libellé, pas, min, max] de `TRAP_FIELDS` par sa clé.
static func _tf(key: String) -> Array:
	for sp in TRAP_FIELDS:
		if sp[0] == key:
			return sp
	return []

## Section de `TRAP_FIELDS` (clé de l'intertitre) → ses champs, dans l'ordre.
static func _section_fields(head_key: String) -> Array:
	var out: Array = []
	var on := false
	for sp in TRAP_FIELDS:
		if sp[0] == "#":
			on = sp[1] == head_key
		elif on:
			out.append(sp)
	return out

static func _trap_row(b: Control, sp: Array, tr2: Dictionary) -> void:
	var key: String = sp[0]
	var post := Callable()
	if key == "rewardGoldMin" or key == "rewardGoldMax":
		post = _keep_order("trapSettings.rewardGoldMin", "trapSettings.rewardGoldMax")
	elif key == "pendulumMin" or key == "pendulumMax":
		post = _keep_order("trapSettings.pendulumMin", "trapSettings.pendulumMax")
	_s(b, L.t(sp[1]), "trapSettings." + key, float(sp[3]), float(sp[4]), float(sp[2]), float(tr2[key]), "", post)

static func _p_traps(host: Control, admin: Node) -> void:
	var page := Ax.scroll_page(host, admin, 40, 28, 18)
	_head(page, admin, "traps")
	var cols := _two(page, admin)
	var tr2 := _trap_cfg(_cfg)
	Form.sub(_cfg, "trapSettings")
	# ---- Crochetage
	var lk := Ax.card(cols[0], L.t("ui.atelier.card_lock"), L.t("admin.general.chance_de_desamorcer_un_piege"))
	_s(lk, L.t("admin.general.chance_de_base"), "trapSettings.base", 0, 100, 1, 15, " %")
	_s(lk, L.t("admin.general.bonus_par_roublard_voleur"), "trapSettings.rogueBonus", 0, 100, 1, 12, " %")
	_s(lk, L.t("admin.general.bonus_assassin"), "trapSettings.assassinBonus", 0, 100, 1, 6, " %")
	_s(lk, L.t("admin.general.bonus_de_dexterite_par_point"), "trapSettings.dexBonus", 0, 10, 0.5, 0.5)
	_s(lk, L.t("admin.general.dexterite_prise_en_compte_max"), "trapSettings.dexCap", 0, 50, 1, 10)
	_s(lk, L.t("admin.general.plafond_minimum"), "trapSettings.min", 0, 100, 1, 10, " %", _keep_order("trapSettings.min", "trapSettings.max"))
	_s(lk, L.t("admin.general.plafond_maximum"), "trapSettings.max", 0, 100, 1, 95, " %", _keep_order("trapSettings.min", "trapSettings.max"))
	_s(lk, L.t("admin.general.surcout_de_l_echec_critique"), "trapSettings.critExtraDmg", 0, 300, 5, 50, " %")
	_sub(lk, L.t("admin.general.degats_un_piege_pourcentage_des"), 8)
	_s(lk, L.t("admin.general.degats_un_piege_minimum_des"), "trapSettings.dmgPctMin", 0, 100, 1, 15, " %", _keep_order("trapSettings.dmgPctMin", "trapSettings.dmgPctMax"))
	_s(lk, L.t("admin.general.degats_un_piege_maximum_des"), "trapSettings.dmgPctMax", 0, 100, 1, 30, " %", _keep_order("trapSettings.dmgPctMin", "trapSettings.dmgPctMax"))
	# ---- Hache pendulaire
	var pe := Ax.card(cols[0], "", "", 20, 16)
	var ph := Ax.hbox(12)
	var pbadge := Ax.panel(Ax.GOLD_BG, Color(0.91, 0.706, 0.361, 0.4), 10, 9, 9)
	pbadge.add_child(Ax.ico("pendulum", 22, Ax.GOLD, 1.7))
	ph.add_child(pbadge)
	var pt := Ax.vbox(2)
	pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pt.add_child(Ax.title(L.t("ui.atelier.card_pendulum"), 17))
	pt.add_child(Ax.para(L.t("admin.general.pieges_methodes_aide"), 12, Ax.MUTED))
	ph.add_child(pt)
	pe.add_child(ph)
	for sp in _section_fields("admin.general.pieges_sec_pendule"):
		_trap_row(pe, sp, tr2)
	_pendulum_preview(pe)
	# ---- Butin
	var lo := Ax.card(cols[0], L.t("ui.atelier.card_loot"), "", 20, 16)
	for sp in _section_fields("admin.general.pieges_sec_butin"):
		_trap_row(lo, sp, tr2)
	# ---- Méthodes de désamorçage
	var me := Ax.card(cols[1], L.t("ui.atelier.card_methods"), L.t("admin.general.pieges_methodes_aide"), 20, 16)
	for sp in _section_fields("admin.general.pieges_sec_methodes"):
		_trap_row(me, sp, tr2)
	# ---- Puzzles de désamorçage
	var pz := Ax.card(cols[1], L.t("ui.atelier.card_puzzles"), "", 20, 14)
	for sp in _section_fields("admin.general.pieges_sec_puzzles"):
		var key: String = sp[0]
		if key == "puzzleChancePct":
			_trap_row(pz, sp, tr2)
		elif key == "puzzleTwistsOn":
			_trap_switch(pz, key, L.t(sp[1]), "", tr2)
	for z in [["Rune", "pz_runes", "pz_runes_u"], ["Wire", "pz_wires", "pz_wires_u"], ["Riddle", "pz_riddle", "pz_riddle_u"], ["Tiles", "pz_tiles", "pz_tiles_u"]]:
		_puzzle_row(pz, str(z[0]), str(z[1]), str(z[2]), tr2)
	_anchors(page, admin, [[L.t("ui.atelier.card_lock"), lk], [L.t("ui.atelier.card_pendulum"), pe], [L.t("ui.atelier.card_puzzles"), pz], [L.t("ui.atelier.card_loot"), lo]])

## Interrupteur de pièges stocké en 1.0 / 0.0 dans `trapSettings`.
static func _trap_switch(b: Control, key: String, label: String, detail: String, tr2: Dictionary) -> Control:
	var ts: Dictionary = Form.sub(_cfg, "trapSettings")
	reg.append({"p": PackedStringArray(["trapSettings", key]), "d": TrapRules.DEFAULTS.get(key, 1.0)})
	return Ax.switch_row(b, label, float(tr2[key]) > 0.5, func(on: bool):
		ts[key] = 1.0 if on else 0.0
		_changed(), detail)

## Ligne d'un puzzle : interrupteur, nom, description, et deux petits champs (nombre d'éléments, erreurs permises).
static func _puzzle_row(b: Control, name: String, key_detail: String, key_unit: String, tr2: Dictionary) -> void:
	var ts: Dictionary = Form.sub(_cfg, "trapSettings")
	var on_key := "puzzle%sOn" % name
	var n_key := "puzzle%s%s" % [name, "Len" if name == "Rune" else ("Count" if name in ["Wire", "Riddle"] else "Rows")]
	var e_key := "puzzle%sErrors" % name
	var nf := _tf(n_key)
	var ef := _tf(e_key)
	reg.append({"p": PackedStringArray(["trapSettings", on_key]), "d": TrapRules.DEFAULTS.get(on_key, 1.0)})
	reg.append({"p": PackedStringArray(["trapSettings", n_key]), "d": TrapRules.DEFAULTS.get(n_key, 3.0)})
	reg.append({"p": PackedStringArray(["trapSettings", e_key]), "d": TrapRules.DEFAULTS.get(e_key, 0.0)})
	var on := float(tr2[on_key]) > 0.5
	var p := Ax.panel(Color(0.118, 0.086, 0.051, 0.9) if on else Color(0.07, 0.051, 0.031, 0.6), Ax.LINE2 if on else Color("2a2014"), 12, 14, 12)
	p.set_meta("setting", L.t("admin.general.piege_puzzle_" + {"Rune": "runes", "Wire": "fils", "Riddle": "enigme", "Tiles": "dalles"}[name]))
	var h := Ax.hbox(14)
	p.add_child(h)
	h.add_child(Ax.switch(on, func(v: bool):
		ts[on_key] = 1.0 if v else 0.0
		_changed()))
	var tx := Ax.vbox(2)
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tx.add_child(Ax.para(L.t("admin.general.piege_puzzle_" + {"Rune": "runes", "Wire": "fils", "Riddle": "enigme", "Tiles": "dalles"}[name]), 14, Ax.CREAM, 600))
	tx.add_child(Ax.para(L.t("ui.atelier." + key_detail), 12, Ax.MUTED))
	h.add_child(tx)
	var steps := Ax.vbox(6)
	steps.custom_minimum_size.x = 150
	h.add_child(steps)
	var mk := func(f: Array, key: String, fmt_key: String, ref: Dictionary) -> Control:
		var cur := clampf(float(ref.get(key, f[3])), float(f[3]), float(f[4]))
		var unit_txt := " " + L.t(fmt_key).replace("%d", "").strip_edges()
		var st := Ax.stepper(cur, float(f[3]), float(f[4]), float(f[2]), func(v: float):
			ts[key] = v
			_changed(), 30.0, unit_txt)
		st.set_meta("setting", L.t(f[1]))
		return st
	steps.add_child(mk.call(nf, n_key, key_unit, tr2))
	steps.add_child(mk.call(ef, e_key, "ui.atelier.pz_err_u", tr2))
	b.add_child(p)

## Aperçu : chance d'esquive de la hache pour chaque héros du groupe de départ.
static func _pendulum_preview(b: Control) -> void:
	var box := Ax.panel(Ax.FIELD, Ax.LINE, 12, 14, 12)
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	var v := Ax.vbox(8)
	box.add_child(v)
	v.add_child(Ax.kicker(L.t("ui.atelier.dodge_preview"), 12))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	v.add_child(row)
	for hero in (_cfg.get("party", []) as Array):
		var cell := Ax.panel(Color("1e160d"), Ax.CLEAR, 10, 10, 8, 0)
		cell.custom_minimum_size.x = 118
		var cv := Ax.vbox(2)
		cell.add_child(cv)
		var cls := Data.class_by_id(str(hero.get("classId", "")))
		cv.add_child(Ax.lab("%s · Dex %s" % [str(cls.get("name", hero.get("name", ""))), Ax.fmt(float(hero.get("dex", 10)))], 12, Ax.MUTED))
		var pct := Ax.lab("", 16, Ax.GOLD_L, 600)
		cv.add_child(pct)
		row.add_child(cell)
		_preview.append({"lbl": pct, "hero": hero})
	_refresh_preview()
	b.add_child(box)

static func _refresh_preview() -> void:
	if _preview.is_empty():
		return
	var s := _trap_cfg(_cfg)
	for e in _preview:
		var l: Label = e.lbl
		if is_instance_valid(l):
			l.text = "%d %%" % TrapRules.pendulum_dodge(e.hero, s)

# ------------------------------------------------------------------ Identité et sécurité

static func _p_identity(host: Control, admin: Node) -> void:
	var page := Ax.scroll_page(host, admin, 40, 28, 20)
	_head(page, admin, "identity", false)
	var cfg := _cfg
	var row := BoxContainer.new()
	row.vertical = admin.size.x < 1000.0
	row.add_theme_constant_override("separation", 20)
	page.add_child(row)
	# ---- Identité du jeu
	var a := Ax.card(row, L.t("admin.general.identite_du_jeu"), L.t("ui.atelier.id_title_hint"), 22, 14)
	var title_in := Ax.field(str(cfg.get("title", "")), Callable(), 44, 15)
	a.add_child(Ax.labeled(L.t("admin.general.nom_du_jeu"), title_in, 6))
	var pv := Ax.panel(Color("1a130c"), Ax.LINE, 14, 10, 10)
	pv.custom_minimum_size.y = 120
	var pc := Ax.vbox(4)
	pc.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(pc)
	var k := Ax.kicker(L.t("ui.atelier.id_preview"), 11)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(k)
	var pt := Ax.title(str(cfg.get("title", "")), 26, Ax.GOLD_L)
	pt.add_theme_font_override("font", Ax.cinzel(2))
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(pt)
	a.add_child(pv)
	title_in.text_changed.connect(func(t: String): pt.text = t)
	var save_title := func(_x = ""):
		var t := title_in.text.strip_edges()
		cfg["title"] = t if t != "" else L.t("admin.general.sans_titre")
		title_in.text = cfg["title"]
		pt.text = cfg["title"]
		admin.save()
	title_in.text_submitted.connect(save_title)
	title_in.focus_exited.connect(save_title)
	var bt := Ax.hbox(10)
	bt.alignment = BoxContainer.ALIGNMENT_END
	bt.add_child(Ax.btn(L.t("ui.atelier.id_save_title"), save_title, "primary", 40.0, 18))
	a.add_child(bt)
	# ---- Mot de passe
	var b := Ax.card(row, L.t("ui.atelier.pw_title"), L.t("admin.general.protection_basique_cote_appareil"), 22, 14)
	var pw_in := Ax.field(str(cfg.get("adminPassword", "")), Callable(), 44, 15, "", true)
	b.add_child(Ax.labeled(L.t("ui.atelier.pw_new"), pw_in, 6))
	var ses := Ax.panel(Ax.FIELD, Ax.LINE, 10, 12, 10)
	var sh := Ax.hbox(10)
	ses.add_child(sh)
	sh.add_child(Ax.ico("lock", 18, Ax.GOLD, 1.8))
	sh.add_child(Ax.lab(L.t("ui.atelier.pw_session"), 13, Ax.MUTED))
	b.add_child(ses)
	var save_pw := func(_x = ""):
		var t := pw_in.text.strip_edges()
		cfg["adminPassword"] = t if t != "" else "admin"
		pw_in.text = cfg["adminPassword"]
		admin.save()
	pw_in.text_submitted.connect(save_pw)
	pw_in.focus_exited.connect(save_pw)
	var bb := Ax.hbox(10)
	bb.add_child(Ax.btn(L.t("admin.general.se_deconnecter"), func(): admin.logout(), "ghost", 40.0, 16))
	bb.add_child(Ax.spacer())
	bb.add_child(Ax.btn(L.t("ui.atelier.pw_save"), save_pw, "primary", 40.0, 18))
	b.add_child(bb)
	row.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.get_child(0).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.get_child(1).size_flags_vertical = Control.SIZE_SHRINK_BEGIN

# ------------------------------------------------------------------ Partage et sauvegarde

static func _p_share(host: Control, admin: Node) -> void:
	var page := Ax.scroll_page(host, admin, 40, 28, 20)
	_head(page, admin, "share", false)
	var narrow: bool = admin.size.x < 1000.0
	# ---- Code de donjon / Charger un code
	var top := Ax.card(page, "", "", 22, 14)
	var cols := BoxContainer.new()
	cols.vertical = narrow
	cols.add_theme_constant_override("separation", 28)
	top.add_child(cols)
	var l := Ax.vbox(12)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(l)
	var lh := Ax.vbox(2)
	lh.add_child(Ax.title(L.t("ui.atelier.sh_code"), 17))
	lh.add_child(Ax.para(L.t("ui.atelier.sh_code_d"), 12, Ax.MUTED))
	l.add_child(lh)
	var out := Ax.area("", "", 76, true)
	out.add_theme_font_size_override("font_size", 12)
	var status := Ax.lab("", 12, Ax.MUTED)
	l.add_child(Ax.btn(L.t("ui.atelier.sh_gen"), func():
		status.text = L.t("admin.form.generation_du_code")
		await out.get_tree().process_frame
		var code := Data.encode_code(Data.admin_config())
		if code == "":
			status.text = L.t("admin.form.echec_de_la_generation_du")
			return
		out.text = code
		DisplayServer.clipboard_set(code)
		status.text = L.fa(L.t("admin.form.code_copie_dans_le_presse"), code.length()), "primary", 44.0, 16, 14))
	l.add_child(out)
	l.add_child(Ax.btn(L.t("ui.atelier.sh_copy"), func():
		if out.text != "":
			DisplayServer.clipboard_set(out.text), "ghost", 38.0))
	l.add_child(status)
	var r := Ax.vbox(12)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(r)
	var rh := Ax.vbox(2)
	rh.add_child(Ax.title(L.t("ui.atelier.sh_load"), 17))
	rh.add_child(Ax.para(L.t("ui.atelier.sh_load_d"), 12, Ax.MUTED))
	r.add_child(rh)
	var inp := Ax.area("", L.t("ui.atelier.sh_paste"), 130)
	r.add_child(inp)
	r.add_child(Ax.btn(L.t("ui.atelier.sh_load_btn"), func(): _load_code(admin, inp), "gold", 44.0, 16, 14))
	# ---- Sauvegarde complète
	var bk := Ax.card(page, L.t("ui.atelier.sh_backup"), L.t("ui.atelier.sh_backup_d"), 22, 14)
	var br := BoxContainer.new()
	br.vertical = narrow
	br.add_theme_constant_override("separation", 12)
	bk.add_child(br)
	var be := Ax.btn(L.t("ui.atelier.sh_export"), func(): export_config(admin), "ghost", 48.0, 16, 14, "download")
	var bi := Ax.btn(L.t("ui.atelier.sh_import"), func(): _import(admin), "ghost", 48.0, 16, 14, "upload")
	be.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(be)
	br.add_child(bi)
	# ---- Zone dangereuse
	var dz := Ax.panel(Color(0.235, 0.078, 0.063, 0.35), Ax.RED_LINE, 16, 22, 22)
	var dh := Ax.hbox(20)
	dz.add_child(dh)
	dh.add_child(Ax.ico("warn", 28, Ax.RED, 1.7))
	var dt := Ax.vbox(2)
	dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dt.add_child(Ax.para(L.t("ui.atelier.sh_danger"), 14, Color("ffb3a6"), 600))
	dt.add_child(Ax.para(L.t("ui.atelier.sh_danger_d"), 12, Color("c9a49c")))
	dh.add_child(dt)
	dh.add_child(Ax.btn(L.t("ui.atelier.sh_reset"), func():
		Dialogs.confirm(admin.modals(), "", L.t("admin.general.reinitialiser_toute_la_configuration"), func():
			Data.reset_config()
			admin.refresh_tab()
			admin.say(admin._now_message())), "danger", 42.0, 18))
	page.add_child(dz)

# ------------------------------------------------------------------ outils

## `trapCfg` : réglages de crochetage avec leurs valeurs par défaut (champ absent / vide / illisible → défaut).
static func _trap_cfg(cfg: Dictionary) -> Dictionary:
	return TrapRules.cfg(cfg)

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
