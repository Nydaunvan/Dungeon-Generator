class_name LivingCatalog
extends RefCounted
## Compétences vivantes : catalogue. Dérive, des données réelles du jeu (sorts, talents de classe, instincts), le PROFIL vivant de chaque compétence :
## famille, traits dominants, évolutions possibles. Rien n'est dupliqué : les identifiants sont ceux des données, un sort créé dans l'éditeur
## est pris en compte automatiquement (profil calculé, jamais stocké). Tout est déterministe (hachage de l'identifiant, aucun hasard de partie).
##
## Familles : "offense" (sorts de dégâts), "technique" (dégâts physiques : savoir-faire plutôt qu'esprit), "soin", "defense" (boucliers),
## "controle" (sommeil, purification), "soutien" (utilitaires de groupe, buffs, endurance), "passif" (talents de classe), "instinct" (réflexe de classe).

const TRAITS := ["agg", "loy", "cur", "pru", "pro", "ind", "ins"]      # agressivité, loyauté, curiosité, prudence, protection, indépendance, instabilité

## Traits actifs par famille (les autres restent à 0 et ne progressent jamais : pas de statistiques inutiles).
const FAMILY_TRAITS := {
	"offense": ["agg", "pru", "ind", "ins"],
	"technique": ["agg", "pru", "ind"],
	"soin": ["pro", "loy", "ins"],
	"defense": ["pro", "loy", "pru"],
	"controle": ["pru", "ind", "cur"],
	"soutien": ["cur", "loy", "pru"],
	"passif": ["pru", "agg", "loy"],
	"instinct": ["pru", "cur", "loy"],
}

## Évolutions (clé = effet, voir LivingSkills) : trait qui la rend accessible (il doit être dominant), et si elle ne vaut que pour une portée.
const KINDS := {
	"acharnement": {"trait": "agg", "fam": ["offense", "technique"]},
	"precision": {"trait": "pru", "fam": ["offense", "technique"], "single": true},
	"tactique": {"trait": "ind", "fam": ["offense", "technique"]},
	"brutes": {"trait": "agg", "fam": ["offense", "technique"], "single": true},
	"temerite": {"trait": "ins", "fam": ["offense"]},
	"prudence": {"trait": "pru", "fam": ["offense", "technique"]},
	"vengeance": {"trait": "ind", "fam": ["offense", "technique"]},
	"balayage": {"trait": "agg", "fam": ["offense", "technique"], "group": true},
	"compassion": {"trait": "pro", "fam": ["soin"]},
	"sacrifice": {"trait": "ins", "fam": ["soin"]},
	"preventive": {"trait": "loy", "fam": ["soin"]},
	"attachee": {"trait": "loy", "fam": ["soin"]},
	"gardienne": {"trait": "pro", "fam": ["defense"]},
	"reactive": {"trait": "pru", "fam": ["defense"]},
	"rempart": {"trait": "loy", "fam": ["defense"]},
	"domination": {"trait": "ind", "fam": ["controle"]},
	"patience": {"trait": "pru", "fam": ["controle"]},
	"ruse": {"trait": "cur", "fam": ["controle"]},
	"memoire": {"trait": "cur", "fam": ["soutien"]},
	"relais": {"trait": "loy", "fam": ["soutien"]},
	"veille": {"trait": "pru", "fam": ["soutien"]},
	"p_focus": {"trait": "agg", "fam": ["passif"]},
	"p_ancre": {"trait": "loy", "fam": ["passif"]},
	"p_souffle": {"trait": "pru", "fam": ["passif"]},
	"p_veine": {"trait": "loy", "fam": ["passif"]},
	"p_sens": {"trait": "agg", "fam": ["passif"]},
	"i_vigil": {"trait": "pru", "fam": ["instinct"]},
	"i_echo": {"trait": "cur", "fam": ["instinct"]},
}

const FAMILY_KINDS := {
	"offense": ["acharnement", "precision", "tactique", "brutes", "temerite", "prudence", "vengeance", "balayage"],
	"technique": ["acharnement", "precision", "tactique", "brutes", "prudence", "vengeance", "balayage"],
	"soin": ["compassion", "sacrifice", "preventive", "attachee"],
	"defense": ["gardienne", "reactive", "rempart"],
	"controle": ["domination", "patience", "ruse"],
	"soutien": ["memoire", "relais", "veille"],
	"passif": ["p_focus", "p_ancre", "p_souffle", "p_veine", "p_sens"],
	"instinct": ["i_vigil", "i_echo"],
}

## Talent → évolution : l'effet du talent (clé de `effects`) oriente le profil du passif (celui qui pèse le plus parmi ses effets).
const PASSIVE_KIND_BY_EFFECT := {
	"critChance": "p_focus", "bonusAtkMax": "p_focus", "bonusAtkMin": "p_focus", "bonusDex": "p_focus", "bonusForce": "p_focus",
	"resistPhys": "p_ancre", "resistMagic": "p_ancre", "bonusCon": "p_ancre",
	"bonusHp": "p_souffle", "bonusStamina": "p_souffle",
	"lifestealPct": "p_veine",
	"bonusSpellDmg": "p_sens", "bonusInt": "p_sens",
}

const INSTINCT_FAMILIES := ["Guerrier", "Archer", "Roublard", "Mage", "Prêtre", "Druide", "Barde"]

static func hash_id(s: String) -> int:
	return absi(s.hash())

## Clé d'une compétence d'un héros dans l'état sauvegardé.
static func key(char_id: String, skill_id: String) -> String:
	return "%s|%s" % [char_id, skill_id]

static func is_instinct(skill_id: String) -> bool:
	return skill_id.begins_with("instinct:")

static func instinct_id(family: String) -> String:
	return "instinct:" + family

static func family_of_spell(sp: Dictionary) -> String:
	var mode := str(sp.get("mode", "damage"))
	match mode:
		"damage", "damageGroup":
			return "technique" if str(sp.get("style", "")) == "physical" else "offense"
		"healSingle", "healParty":
			return "soin"
		"shieldSingle":
			return "defense"
		"sleepGroup", "dispelSingle":
			return "controle"
	return "soutien"      # partyUtility, selfBuff, staminaRestoreSingle (et tout nouveau mode d'utilité)

## Option de talent par identifiant (données de la partie, sinon données d'origine).
static func talent_option(cfg: Dictionary, talent_id: String) -> Dictionary:
	return Talents.find_option(cfg, talent_id)

static func passive_kind(opt: Dictionary) -> String:
	var best := ""
	var best_w := -1.0
	for k in (opt.get("effects", {}) as Dictionary).keys():
		var kind: String = PASSIVE_KIND_BY_EFFECT.get(str(k), "")
		if kind == "":
			continue
		var w := absf(float(opt.effects[k])) + float(hash_id(str(opt.get("id", "")) + str(k)) % 100) * 0.001      # égalité : départage stable
		if w > best_w:
			best_w = w
			best = kind
	return best if best != "" else "p_souffle"

## Profil d'une compétence. `skill_id` : identifiant d'un sort, d'un talent (option) ou « instinct:<famille> ».
## Renvoie {} si l'identifiant n'existe pas dans les données.
static func profile(cfg: Dictionary, skill_id: String) -> Dictionary:
	var fam := ""
	var name := ""
	var icon := ""
	var kinds: Array = []
	var group := false
	var kind_hint := ""
	if is_instinct(skill_id):
		var fn := skill_id.substr(9)
		if not INSTINCT_FAMILIES.has(fn):
			return {}
		fam = "instinct"
		name = L.fa(L.t("ui.living.instinct_name"), L.c(fn))
		icon = "👁"
	else:
		var sp := _spell(cfg, skill_id)
		if not sp.is_empty():
			fam = family_of_spell(sp)
			name = str(sp.get("name", skill_id))
			icon = str(sp.get("icon", ""))
			group = str(sp.get("mode", "")) == "damageGroup"
		else:
			var opt := talent_option(cfg, skill_id)
			if opt.is_empty():
				return {}
			fam = "passif"
			name = str(opt.get("labelFr", skill_id))
			icon = str(opt.get("icon", ""))
			kind_hint = passive_kind(opt)
	var pool: Array = FAMILY_KINDS[fam]
	var allowed: Array = []
	for k in pool:
		var kd: Dictionary = KINDS[k]
		if (bool(kd.get("group", false)) and not group) or (bool(kd.get("single", false)) and group):
			continue
		allowed.append(k)
	# trois évolutions par compétence (moins si la famille en propose moins) : l'orientation du passif vient de ses effets, le reste du hachage de l'identifiant
	var scored: Array = []
	for k in allowed:
		scored.append([hash_id(skill_id + "|" + str(k)) + (-1000000000 if str(k) == kind_hint else 0), k])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	kinds = scored.slice(0, mini(3, scored.size())).map(func(e): return e[1])
	# traits de départ : familles → traits actifs ; valeur de base 12 à 28 selon le hachage (chaque compétence a son tempérament de naissance)
	var traits := {}
	var act: Array = FAMILY_TRAITS[fam]
	for i in act.size():
		traits[act[i]] = 12 + hash_id(skill_id + "|t|" + str(act[i])) % 17
	var branches: Array = []
	for k in kinds:
		branches.append({"kind": k, "trait": KINDS[k].trait})
	return {"id": skill_id, "family": fam, "name": name, "icon": icon, "traits": traits, "branches": branches}

static func _spell(cfg: Dictionary, spell_id: String) -> Dictionary:
	for s in cfg.get("spells", []):
		if str(s.id) == spell_id:
			return s
	return {}

## Toutes les compétences vivantes existantes dans les données : sorts, talents de classe (options), instincts.
## Renvoie des {id, kind: "spell"|"talent"|"instinct", classes: [ids de classe]}.
static func all_skills(cfg: Dictionary) -> Array:
	var out: Array = []
	var by_spell := {}
	for c in cfg.get("classes", []):
		for sid in c.get("allowedSpellIds", []):
			if not by_spell.has(str(sid)):
				by_spell[str(sid)] = []
			by_spell[str(sid)].append(str(c.id))
		var ult := str(c.get("ultimateSpellId", ""))
		if ult != "":
			if not by_spell.has(ult):
				by_spell[ult] = []
			by_spell[ult].append(str(c.id))
	for s in cfg.get("spells", []):
		out.append({"id": str(s.id), "kind": "spell", "classes": by_spell.get(str(s.id), [])})
	var tal: Dictionary = cfg.get("classTalents", {})
	if tal.is_empty():
		tal = Data.class_talents
	for cid in tal.keys():
		for tier in tal[cid]:
			for o in tier.options:
				out.append({"id": str(o.id), "kind": "talent", "classes": [str(cid)], "level": int(tier.level)})
	for f in INSTINCT_FAMILIES:
		out.append({"id": instinct_id(f), "kind": "instinct", "classes": []})
	return out
