class_name AdminGeneral
extends RefCounted
## Onglet « Général » : identité, sécurité, combat, endurance, progression, fontaines, pièges, légendaires, XP, configuration.

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.config
	var save: Callable = admin.save

	var b := Form.panel(host, "Identité du jeu")
	Form.text(b, "Nom du jeu", cfg, "title")
	Form.buttons(b, [["Enregistrer le titre", save]])

	b = Form.panel(host, "Sécurité")
	Form.hint(b, "Protection basique côté appareil : évite les accès accidentels, ce n'est pas une sécurité de production.")
	Form.buttons(b, [["Enregistrer le mot de passe", save], ["Se déconnecter", admin.logout]])

	b = Form.panel(host, "Combat")
	Form.check(b, "Limite de temps par tour (passe automatiquement le tour sinon)", cfg, "turnTimerEnabled", true)
	Form.number(b, "Durée (secondes)", cfg, "turnTimerSeconds", 3, 10, 1, 5)
	Form.hint(b, "Évite qu'un joueur attende indéfiniment la fin d'un temps de recharge de sort avant d'agir. S'applique aux personnages comme aux monstres (barre rouge sous le bouton Fuir).")
	Form.buttons(b, [["Enregistrer", save]])

	b = Form.panel(host, "Endurance")
	var sta := Form.sub(cfg, "staminaSettings")
	Form.hint(b, "S'applique à tous les personnages. L'endurance augmente quand un héros est touché, et diminue quand il attaque (arme ou sort). L'endurance maximale se règle pour chaque personnage dans l'onglet « Personnages », le coût des sorts dans « Sorts / Capacités ».")
	Form.number(b, "Coût — attaque physique", sta, "attackCost", 0, 100)
	Form.hint(b, "Plafonné à 2 points maximum quel que soit ce réglage : l'attaque physique de base ne doit jamais totalement bloquer un personnage à sec d'endurance.")
	Form.number(b, "Gain en étant touché", sta, "hitGain", 0, 100)
	Form.number(b, "Gain léger par déplacement", sta, "moveGain", 0, 100)
	Form.number(b, "Nombre de déplacements requis", sta, "moveInterval", 1, 100, 1, 1)
	Form.hint(b, "Ex : gain de 1, tous les 3 déplacements = régénération plus lente. Les donjons générés aléatoirement utilisent par défaut cet intervalle plus exigeant.")
	var vic := Form.sub(sta, "victoryGainPct")
	Form.hint(b, "Endurance récupérée après chaque victoire, en % du maximum, selon la difficulté du donjon.")
	Form.number(b, "Victoire — Facile (%)", vic, "easy", 0, 100, 1, 4)
	Form.number(b, "Victoire — Normale (%)", vic, "normal", 0, 100, 1, 6)
	Form.number(b, "Victoire — Difficile (%)", vic, "hard", 0, 100, 1, 9)
	Form.number(b, "Victoire — Hardcore (%)", vic, "hardcore", 0, 100, 1, 13)
	Form.hint(b, "Régénération partielle de PV/endurance à la première arrivée sur un niveau (escalier/arche), en % du max — accordée une seule fois par niveau et par partie.")
	Form.number(b, "Arrivée sur un niveau — PV (%)", sta, "levelTransitionHpPct", 0, 100, 1, 25)
	Form.number(b, "Arrivée sur un niveau — Endurance (%)", sta, "levelTransitionStaPct", 0, 100, 1, 35)
	Form.buttons(b, [["Enregistrer", save]])

	b = Form.panel(host, "Progression au niveau")
	var grow := Form.sub(cfg, "levelUpGrowth")
	Form.hint(b, "À chaque niveau gagné, les statistiques de base (Force/Dextérité/Constitution/Intelligence) et l'endurance de base augmentent légèrement — les PV et les dégâts en profitent indirectement.")
	Form.number(b, "Stats de base — points cumulés par niveau", grow, "statPerLevel", 0, 5, 0.1, 0.4)
	Form.hint(b, "Ex : 0.4 = Force/Dex/Con/Int augmentent ensemble de +1 tous les 2-3 niveaux (accumulation fractionnelle, jamais perdue).")
	Form.number(b, "Endurance de base — gain par niveau", grow, "staminaPerLevel", 0, 20, 1, 2)
	Form.hint(b, "Coût (en or) demandé par le Maître des Talents pour changer un talent déjà choisi — augmente avec le palier concerné (×1 au niveau 5, ×5 au niveau 25).")
	Form.number(b, "Maître des Talents — coût de base (or)", cfg, "talentMasterBaseCost", 0, 100000, 1, 80)
	Form.buttons(b, [["Enregistrer", save]])

	b = Form.panel(host, "Fontaines")
	Form.hint(b, "Placées dans les niveaux (objet « Fontaine »), elles restaurent entièrement PV et endurance de tout le groupe, puis se rechargent après ce délai.")
	Form.number(b, "Délai de recharge (minutes)", cfg, "fountainCooldownMinutes", 5, 1000, 1, 10)
	Form.buttons(b, [["Enregistrer", save]])

	b = Form.panel(host, "Pièges — crochetage")
	var tr := Form.sub(cfg, "trapSettings")
	Form.hint(b, "Chance de désamorcer un piège avec l'ensemble du groupe (personnages vivants). Un 20 naturel réussit toujours, un 1 naturel échoue toujours.")
	Form.number(b, "Chance de base (%)", tr, "base", 0, 100, 1, 15)
	Form.number(b, "Bonus par Roublard / Voleur (%)", tr, "rogueBonus", 0, 100, 1, 12)
	Form.number(b, "Bonus Assassin (%)", tr, "assassinBonus", 0, 100, 1, 6)
	Form.number(b, "Bonus de Dextérité (% par point au-dessus de 10)", tr, "dexBonus", 0, 10, 0.5, 0.5)
	Form.number(b, "Dextérité prise en compte (max de points au-dessus de 10)", tr, "dexCap", 0, 50, 1, 10)
	Form.number(b, "Plafond minimum (%)", tr, "min", 0, 100, 1, 10)
	Form.number(b, "Plafond maximum (%)", tr, "max", 0, 100, 1, 95)
	Form.number(b, "Surcoût de l'échec critique (% de dégâts)", tr, "critExtraDmg", 0, 300, 1, 50)
	Form.hint(b, "Dégâts d'un piège : pourcentage des PV max du personnage touché (tiré au sort). Les dégâts fixes réglés sur chaque piège servent de minimum garanti.")
	Form.number(b, "Dégâts d'un piège — minimum (% des PV max)", tr, "dmgPctMin", 0, 100, 1, 15)
	Form.number(b, "Dégâts d'un piège — maximum (% des PV max)", tr, "dmgPctMax", 0, 100, 1, 30)
	Form.buttons(b, [["Enregistrer", save]])

	b = Form.panel(host, "Objets légendaires")
	Form.hint(b, "S'applique aux donjons générés aléatoirement : chance que le butin garanti d'un boss soit un objet légendaire (nom unique, statistiques boostées, bonus spécial : Vol de vie, Critique, Renvoi).")
	Form.number(b, "Chance sur le butin de boss (%)", cfg, "legendaryChancePct", 0, 100, 1, 25)
	Form.buttons(b, [["Enregistrer", save]])

	b = Form.panel(host, "Répartition de l'expérience")
	var xp := Form.sub(cfg, "xpSettings")
	Form.hint(b, "La mort d'un monstre répartit son XP entre tous les personnages ayant contribué au combat (dégâts infligés, mais aussi soins prodigués), au prorata. Ce ratio détermine combien de PV soignés valent 1 point de dégât pour ce calcul.")
	Form.number(b, "Ratio soins → contribution", xp, "healRatio", 0, 2, 0.1, 0.8)
	Form.buttons(b, [["Enregistrer", save]])

	b = Form.panel(host, "Configuration")
	Form.hint(b, "La configuration (personnages, classes, sorts, niveaux, monstres, objets, titre) est distincte de la progression d'une partie.")
	var do_reset := func():
		Data.reset_config()
		admin.say("Configuration réinitialisée.")
		admin.refresh_tab()
	var reset := func():
		Dialogs.confirm(admin.modals(), "Réinitialiser", "Réinitialiser toute la configuration aux valeurs par défaut ?", do_reset, "Réinitialiser")
	Form.buttons(b, [["Exporter (JSON)", func(): _export(admin)], ["Importer (JSON)", func(): _import(admin)], ["Réinitialiser", reset]])

	b = Form.panel(host, "Code de donjon")
	Form.hint(b, "Alternative à l'export/import de fichier : un long code de texte qui contient toute la configuration, à copier-coller directement (dans une conversation, un message…) sans fichier à joindre.")
	var out := TextEdit.new()
	out.editable = false
	out.visible = false
	out.custom_minimum_size = Vector2(0, 80)
	out.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var gen := func():
		var code := Data.encode_code(Data.config)
		out.text = code
		out.visible = true
		Files.copy(code)
		admin.say("Code copié dans le presse-papiers (%d caractères)." % code.length())
	Form.buttons(b, [["Générer le code de ce donjon", gen]])
	b.add_child(out)
	Form.hint(b, "Coller ci-dessous un code reçu pour charger ce donjon dans l'administration (remplace la configuration actuelle) :")
	var inp := TextEdit.new()
	inp.placeholder_text = "Collez le code ici…"
	inp.custom_minimum_size = Vector2(0, 80)
	inp.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	b.add_child(inp)
	var load_code := func():
		var loaded := Data.decode_code(inp.text)
		if loaded.is_empty() or not loaded.has("levels"):
			admin.say("Code invalide ou non reconnu.")
			return
		Data.config = loaded
		Data.save_config()
		admin.say("Donjon chargé depuis le code.")
		admin.refresh_tab()
	Form.buttons(b, [["Charger ce code", load_code]])

static func _export(admin: Node) -> void:
	var text := Data.export_json()
	Files.copy(text)
	Files.save_text(admin, "donjon-config.json", text, admin.say)

static func _import(admin: Node) -> void:
	var apply := func(text: String):
		var err := Data.import_json(text)
		if err != "":
			admin.say(err)
			return
		Data.save_config()
		admin.say("Configuration importée.")
		admin.refresh_tab()
	Files.pick_text(admin, apply)
