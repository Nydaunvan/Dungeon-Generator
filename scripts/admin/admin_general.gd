class_name AdminGeneral
extends RefCounted
## Onglet « Général » (`#adminGeneral` de l'original) : panneau par panneau, textes et bornes repris des `saveXxx` du HTML.
## Chaque bouton lit ses champs, applique les bornes exactes, écrit TOUTES les clés du panneau, enregistre puis réaffiche les
## valeurs corrigées. Le panneau Combat n'a pas de bouton : il enregistre à chaque modification.

## Indication `.hint` (marge haute -4 px par défaut, 12 px dessous).
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
	var b := Form.panel(host, "Identité du jeu")
	var title_in := Form.text_row(b, "Nom du jeu", str(cfg.get("title", "")), 260.0)
	var act1 := func():
		var t := title_in.text.strip_edges()
		cfg["title"] = t if t != "" else "Sans titre"
		title_in.text = cfg["title"]
		save.call()
	Form.actions(b, [["💾 Enregistrer le titre", act1, true]])

	# ---- Sécurité
	b = Form.panel(host, "Sécurité")
	var pw_in := Form.text_row(b, "Mot de passe admin", str(cfg.get("adminPassword", "")), 200.0)
	_h(b, "⚠️ Protection basique côté appareil : évite les accès accidentels, ce n'est pas une sécurité de production.", 0.0)
	var pw_save := func():
		var t := pw_in.text.strip_edges()
		cfg["adminPassword"] = t if t != "" else "admin"
		pw_in.text = cfg["adminPassword"]
		save.call()
	Form.actions(b, [["💾 Enregistrer le mot de passe", pw_save, true], ["🚪 Se déconnecter", func(): admin.logout()]])

	# ---- Combat (enregistrement immédiat)
	b = Form.panel(host, "Combat")
	var chk := CheckBox.new()
	chk.text = "⏳ Limite de temps par tour (passe automatiquement le tour sinon)"
	chk.button_pressed = bool(cfg.get("turnTimerEnabled", true))
	chk.focus_mode = Control.FOCUS_NONE
	Form._place(b, chk, 0.0, 8.0)
	var sec := Form.num_row(b, "Durée (secondes)", float(cfg.get("turnTimerSeconds", 5)) if float(cfg.get("turnTimerSeconds", 5)) != 0.0 else 5.0)
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
	_h(b, "Évite qu'un joueur attende indéfiniment la fin d'un cooldown de sort avant d'agir. S'applique aux personnages comme aux monstres (barre rouge sous le bouton Fuite en combat).", 6.0)

	# ---- Endurance
	b = Form.panel(host, "Endurance")
	var sta: Dictionary = cfg.get("staminaSettings", {"attackCost": 10, "hitGain": 8, "moveGain": 2})
	var vic: Dictionary = Form.sub(sta, "victoryGainPct")
	_h(b, "S'applique à tous les personnages. L'endurance augmente quand un héros est touché, et diminue quand il attaque (arme ou sort).")
	_h(b, "L'endurance maximale se règle désormais individuellement pour chaque personnage dans l'onglet « Personnages ».", 0.0)
	var s_atk := Form.num_row(b, "Coût — attaque physique", float(sta.get("attackCost", 0)))
	_h(b, "Plafonné à 2 points maximum quel que soit ce réglage : l'attaque physique de base ne doit jamais totalement bloquer un personnage à sec d'endurance.")
	_h(b, "Le coût en endurance des sorts/capacités se règle désormais individuellement dans l'onglet « Sorts / Capacités ».", 0.0)
	var s_hit := Form.num_row(b, "Gain en étant touché", float(sta.get("hitGain", 0)))
	var s_move := Form.num_row(b, "Gain léger par déplacement", float(sta.get("moveGain", 2)))
	var s_int := Form.num_row(b, "Nombre de déplacements requis", float(sta.get("moveInterval", 1)))
	_h(b, "Ex : gain de 1, tous les 3 déplacements = régénération plus lente. Les donjons générés aléatoirement utilisent par défaut cet intervalle plus exigeant.", 0.0)
	_h(b, "En dessous du coût requis, un sort ou une capacité est bloqué jusqu'à récupération d'endurance (l'attaque physique de base, elle, reste toujours possible — voir la note ci-dessus).")
	_h(b, "Bonus d'endurance à la fin d'un combat, en % de l'endurance max de chaque personnage — varie selon la difficulté choisie en donjon aléatoire (le Donjon d'Origine et les donjons créés à la main utilisent la valeur « Normal »).", 10.0)
	var v_easy := Form.num_row(b, "Fin de combat — Facile (%)", float(vic.get("easy", 0)))
	var v_norm := Form.num_row(b, "Fin de combat — Normal (%)", float(vic.get("normal", 0)))
	var v_hard := Form.num_row(b, "Fin de combat — Difficile (%)", float(vic.get("hard", 0)))
	var v_hc := Form.num_row(b, "Fin de combat — Cauchemar (%)", float(vic.get("hardcore", 0)))
	_h(b, "Régénération partielle de PV/endurance à la première arrivée sur un niveau (escalier/arche), en % du max — accordée une seule fois par niveau et par partie.", 10.0)
	var t_hp := Form.num_row(b, "Arrivée sur un niveau — PV (%)", float(sta.get("levelTransitionHpPct", 0)))
	var t_sta := Form.num_row(b, "Arrivée sur un niveau — Endurance (%)", float(sta.get("levelTransitionStaPct", 0)))
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
	Form.actions(b, [["💾 Enregistrer", act2, true]])

	# ---- Progression au niveau
	b = Form.panel(host, "Progression au niveau")
	var grow: Dictionary = Form.sub(cfg, "levelUpGrowth")
	_h(b, "À chaque niveau gagné par un personnage, ses statistiques de base (Force/Dextérité/Constitution/Intelligence) et son endurance de base augmentent légèrement — les PV et les dégâts en profitent indirectement (via la Constitution/Force), en plus de leur propre progression déjà liée au niveau.")
	var g_stat := Form.num_row(b, "Stats de base — points cumulés par niveau", float(grow.get("statPerLevel", 0)), 0.1)
	_h(b, "Ex : 0.4 = Force/Dex/Con/Int augmentent ensemble de +1 tous les 2-3 niveaux (accumulation fractionnelle, jamais perdue).")
	var g_sta := Form.num_row(b, "Endurance de base — gain par niveau", float(grow.get("staminaPerLevel", 0)))
	_h(b, "Coût (en or) demandé par le Maître des Talents pour changer un talent déjà choisi — augmente avec le palier concerné (×1 au niveau 5, ×5 au niveau 25).", 10.0)
	var g_tm := Form.num_row(b, "Maître des Talents — coût de base (or)", float(cfg.get("talentMasterBaseCost", 0)))
	var act3 := func():
		cfg["levelUpGrowth"] = {"statPerLevel": _clamp(_num0(g_stat), 0, 5), "staminaPerLevel": _clamp(_num0(g_sta), 0, 20)}
		cfg["talentMasterBaseCost"] = maxf(0.0, _num0(g_tm))
		_sv(g_stat, cfg.levelUpGrowth.statPerLevel); _sv(g_sta, cfg.levelUpGrowth.staminaPerLevel); _sv(g_tm, cfg.talentMasterBaseCost)
		save.call()
	Form.actions(b, [["💾 Enregistrer", act3, true]])

	# ---- Fontaines
	b = Form.panel(host, "Fontaines")
	_h(b, "Placées dans les niveaux (type d'objet « Fontaine »), elles restaurent entièrement PV et endurance de tout le groupe, puis se rechargent après ce délai.")
	var f_cd := Form.num_row(b, "Délai de recharge (minutes)", float(cfg.get("fountainCooldownMinutes", 10)))
	var act4 := func():
		cfg["fountainCooldownMinutes"] = maxf(5.0, Form.val_or(f_cd, 10.0))
		_sv(f_cd, cfg["fountainCooldownMinutes"])
		save.call()
	Form.actions(b, [["💾 Enregistrer", act4, true]])

	# ---- Pièges — crochetage
	b = Form.panel(host, "Pièges — crochetage")
	var tr := _trap_cfg(cfg)
	_h(b, "Chance de désamorcer un piège avec l'ensemble du groupe (personnages vivants). Un 20 naturel réussit toujours, un 1 naturel échoue toujours.")
	var t_base := Form.num_row(b, "Chance de base (%)", tr.base)
	var t_rogue := Form.num_row(b, "Bonus par Roublard / Voleur (%)", tr.rogueBonus)
	var t_ass := Form.num_row(b, "Bonus Assassin (%)", tr.assassinBonus)
	var t_dex := Form.num_row(b, "Bonus de Dextérité (% par point au-dessus de 10)", tr.dexBonus, 0.5)
	var t_cap := Form.num_row(b, "Dextérité prise en compte (max de points au-dessus de 10, par personnage)", tr.dexCap)
	var t_min := Form.num_row(b, "Plafond minimum (%)", tr.min)
	var t_max := Form.num_row(b, "Plafond maximum (%)", tr.max)
	var t_crit := Form.num_row(b, "Surcoût de l'échec critique (% de dégâts)", tr.critExtraDmg)
	_h(b, "Dégâts d'un piège : pourcentage des PV max du personnage touché (tiré au sort). Les dégâts fixes réglés sur chaque piège servent de minimum garanti.", 10.0)
	var t_dmin := Form.num_row(b, "Dégâts d'un piège — minimum (% des PV max)", tr.dmgPctMin)
	var t_dmax := Form.num_row(b, "Dégâts d'un piège — maximum (% des PV max)", tr.dmgPctMax)
	var act5 := func():
		var mn := _clamp(_num0(t_min), 0, 100)
		var mx := maxf(mn, _clamp(_num0(t_max), 0, 100))
		var dmn := _clamp(_num0(t_dmin), 0, 100)
		var o := {"base": _clamp(_num0(t_base), 0, 100), "rogueBonus": _clamp(_num0(t_rogue), 0, 100), "assassinBonus": _clamp(_num0(t_ass), 0, 100),
			"dexBonus": _clamp(_num0(t_dex), 0, 10), "min": mn, "max": mx, "critExtraDmg": _clamp(_num0(t_crit), 0, 300),
			"dmgPctMin": dmn, "dmgPctMax": maxf(dmn, _clamp(_num0(t_dmax), 0, 100)), "dexCap": _clamp(_num0(t_cap), 0, 50)}
		cfg["trapSettings"] = o
		_sv(t_base, o.base); _sv(t_rogue, o.rogueBonus); _sv(t_ass, o.assassinBonus); _sv(t_dex, o.dexBonus); _sv(t_min, o.min)
		_sv(t_max, o.max); _sv(t_crit, o.critExtraDmg); _sv(t_dmin, o.dmgPctMin); _sv(t_dmax, o.dmgPctMax); _sv(t_cap, o.dexCap)
		save.call()
	Form.actions(b, [["💾 Enregistrer", act5, true]])

	# ---- Objets légendaires
	b = Form.panel(host, "✨ Objets légendaires")
	_h(b, "S'applique aux donjons générés aléatoirement : chance que le butin garanti d'un boss soit un objet légendaire (nom unique, statistiques boostées, bonus spécial). Les objets légendaires eux-mêmes (Vol de vie, Critique, Renvoi) se règlent aussi manuellement sur n'importe quelle arme/armure/bijou, dans les onglets Objets de base et Niveaux.")
	var l_ch := Form.num_row(b, "Chance sur le butin de boss (%)", float(cfg.get("legendaryChancePct", 25)))
	var act6 := func():
		cfg["legendaryChancePct"] = _clamp(l_ch.value, 0, 100)
		_sv(l_ch, cfg["legendaryChancePct"])
		save.call()
	Form.actions(b, [["💾 Enregistrer", act6, true]])

	# ---- Répartition de l'expérience
	b = Form.panel(host, "Répartition de l'expérience")
	var xp: Dictionary = cfg.get("xpSettings", {})
	_h(b, "La mort d'un monstre répartit son XP entre tous les personnages ayant contribué au combat (dégâts infligés, mais aussi soins prodigués), au prorata. Le ratio ci-dessous détermine combien de PV soignés valent 1 point de dégât pour ce calcul — utile pour valoriser les compétences et sorts de soin.")
	var x_ratio := Form.num_row(b, "Ratio soins → contribution", float(xp.get("healRatio", 0.8)), 0.1)
	var act7 := func():
		var v := x_ratio.value
		cfg["xpSettings"] = {"healRatio": 0.5 if is_nan(v) else _clamp(v, 0, 2)}
		_sv(x_ratio, cfg.xpSettings.healRatio)
		save.call()
	Form.actions(b, [["💾 Enregistrer", act7, true]])

	# ---- Configuration
	b = Form.panel(host, "Configuration")
	_h(b, "La configuration (personnages, classes, sorts, niveaux, monstres, objets, titre) est distincte de la progression d'une partie.")
	Form.actions(b, [
		["⬇ Exporter (JSON)", func(): export_config(admin)],
		["⬆ Importer (JSON)", func(): _import(admin)],
		["↩ Réinitialiser aux valeurs par défaut", func():
			Dialogs.confirm(admin.modals(), "", "Réinitialiser toute la configuration aux valeurs par défaut ?", func():
				Data.reset_config()
				admin.refresh_tab()
				admin.say(admin._now_message()))]])
	admin.admin_status = Form.status_label(b)

	# ---- Code de donjon
	b = Form.panel(host, "🔑 Code de donjon")
	_h(b, "Alternative à l'export/import de fichier : un long code de texte qui contient toute la configuration, à copier-coller directement (dans une conversation, un message...) sans fichier à joindre.")
	var out: TextEdit = null
	var status: Label = null
	Form.actions(b, [["📋 Générer le code de ce donjon", func(): Form.generate_code(Data.admin_config(), out, status)]])
	out = Form.code_area(b, "", true, 80.0, 8.0)
	out.visible = false
	status = Form.status_label(b)
	_h(b, "Coller ci-dessous un code reçu pour charger ce donjon dans l'admin (remplace la configuration actuelle) :", 14.0)
	var inp := Form.code_area(b, "Collez le code ici…", false, 80.0, 0.0)
	Form.actions(b, [["⬆ Charger ce code", func(): _load_code(admin, inp)]])

## `trapCfg` : réglages de crochetage avec leurs valeurs par défaut (champ absent / vide / illisible → défaut).
static func _trap_cfg(cfg: Dictionary) -> Dictionary:
	var d := {"base": 15.0, "rogueBonus": 12.0, "assassinBonus": 6.0, "dexBonus": 0.5, "dexCap": 10.0, "min": 10.0, "max": 95.0, "critExtraDmg": 50.0, "dmgPctMin": 15.0, "dmgPctMax": 30.0}
	var c: Dictionary = cfg.get("trapSettings", {}) if cfg.get("trapSettings") is Dictionary else {}
	var o := {}
	for k in d:
		var v = c.get(k)
		o[k] = d[k] if (v == null or not (v is float or v is int)) else float(v)
	if o.max < o.min:
		o.max = o.min
	if o.dmgPctMax < o.dmgPctMin:
		o.dmgPctMax = o.dmgPctMin
	if o.dexCap < 0:
		o.dexCap = 0.0
	return o

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
			Form.alert(admin.modals(), "Ce fichier n'est pas un JSON de configuration valide.")
			return
		var data := Saves.parse_import(text)
		var cfg: Dictionary = data.get("config", {}) if data.get("config") is Dictionary else {}
		if cfg.is_empty():
			Form.alert(admin.modals(), "Ce fichier ne contient pas de configuration reconnue.")
			return
		Data.ensure_defaults(cfg)
		Data.set_admin_config(cfg)
		Data.save_config()
		admin.refresh_tab())

## `loadDungeonCodeIntoAdmin`.
static func _load_code(admin: Node, inp: TextEdit) -> void:
	if inp.text.strip_edges() == "":
		return
	Dialogs.confirm(admin.modals(), "", "Charger ce code remplacera entièrement la configuration actuelle (personnages, classes, sorts, niveaux, objets, titre). Continuer ?", func():
		var cfg := Data.decode_code(inp.text)
		if cfg.is_empty():
			Form.alert(admin.modals(), "Ce code est invalide ou illisible.")
			return
		Data.ensure_defaults(cfg)
		Data.set_admin_config(cfg)
		Data.save_config()
		inp.text = ""
		admin.refresh_tab())
