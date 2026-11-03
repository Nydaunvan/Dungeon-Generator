class_name LivingSkills
extends RefCounted
## COMPÉTENCES VIVANTES : les sorts, talents et instincts des héros se souviennent, s'attachent, évoluent et se répondent.
## Règles complètes : docs/LIVING_SKILLS.md. Résumé :
##  - L'état vit dans `gs.living` (sauvegardé) : par compétence et par héros, une affinité (0-100), des traits qui dérivent, quelques souvenirs,
##    une éventuelle évolution choisie ; des relations entre compétences ; des fragments de lore ; un « registre » du combat en cours.
##  - Rien n'est joué au hasard : toutes les règles sont des conditions explicites. Le flux aléatoire de la partie n'est JAMAIS consommé ici.
##  - Les gains sont réglés en FIN de combat (`settle`) d'après le registre : plafonds par combat, poids du combat, nouveauté des adversaires
##    (contre le farming) ; aucune compétence ne progresse seulement parce qu'on l'utilise en boucle.
##  - Désactivable (option « Compétences vivantes ») et inactif en partie classée : toutes les fonctions rendent alors leur entrée inchangée,
##    les compétences jouent exactement comme avant. Les améliorations ne viennent que d'une évolution CHOISIE par le joueur.

const SCHEMA := 1
const TIER_AT := [0.0, 10.0, 25.0, 50.0, 80.0]      # paliers d'affinité : étrangère, familière, attachée, liée, fusionnelle
const EVOLVE_AFF := 25.0                           # affinité minimale pour éveiller une évolution
const TRAIT_MIN := 40                               # trait dominant requis pour voir une évolution
const AFF_CAP_COMBAT := 6.0                         # gain d'affinité maximal par compétence et par combat
const TRAIT_CAP_COMBAT := 4                         # dérive de traits maximale par compétence et par combat
const MEM_MAX := 6
const REL_AT := [3, 7, 14]                          # combats communs pour les niveaux 1, 2, 3 d'une relation
const REL_MAX := 24
const WINDOW := 3                                   # un sort « répond » à l'un des 3 derniers sorts lancés
const SAY_MAX := 2                                  # manifestations par combat
const MARK := "« "                                  # une manifestation du carnet est une ligne entre guillemets (le carnet ajoute déjà son propre ✦)
const SAY_GAP := 5                                  # sorts minimum entre deux manifestations
const SIG_TIER := 4                                 # palier « fusionnelle » : geste signature, une fois par combat
const LINK_AFF := 50.0                              # affinité (palier « liée ») pour éveiller une seconde évolution
const MULT_CAP := 1.8                               # plafond du produit des multiplicateurs de dégâts de ce système
const DECAY_AFTER := 12                             # combats sans usage avant que l'affinité s'étiole
const MOOD_INS := 45                                # instabilité à partir de laquelle une compétence s'agite quand son porteur est blessé
const LORE_AT := [2, 5, 9, 14, 20]                  # fragments nécessaires pour chaque fragment de lore

const MEM_PRIORITY := ["decisive", "first_boss", "saved", "narrow", "exceptional", "first_kill", "env", "resist"]

## Combos découverts par l'usage : `first` puis `second` lancés à moins de WINDOW sorts d'écart pendant un même combat. Chaque combo ne s'applique
## qu'après une relation de niveau 1 entre CES deux compétences. Les filtres reposent sur de vraies écoles et de vrais modes (voir les tests).
const COMBOS := {
	"embrasement": {"first": {"styles": ["fire"], "modes": ["damage", "damageGroup"]}, "second": {"styles": ["nature", "arcane"], "modes": ["damage", "damageGroup"]},
		"cond": "burn", "mult": 0.25},
	"givre_brise": {"first": {"styles": ["ice"], "modes": ["damage"]}, "second": {"styles": ["physical"], "modes": ["damage", "damageGroup"]},
		"cond": "chill", "mult": 0.25},
	"lame_chantee": {"first": {"styles": ["bard"], "modes": ["partyUtility", "selfBuff"]}, "second": {"styles": ["physical"], "modes": ["damage", "damageGroup"]},
		"cond": "", "mult": 0.15, "stamina": 3},
	"dormeur": {"first": {"modes": ["sleepGroup"]}, "second": {"styles": ["physical", "shadow"], "modes": ["damage", "damageGroup"]},
		"cond": "stunned", "mult": 0.3},
	"benediction": {"first": {"modes": ["shieldSingle"]}, "second": {"modes": ["healSingle"]}, "cond": "same_ally", "shield_pct": 8},
	"rempart_pacte": {"first": {"modes": ["shieldSingle"]}, "second": {"modes": ["damage", "damageGroup"]}, "cond": "shielded_caster", "mult": 0.15},
	"sauvetage": {"first": {"modes": ["healSingle", "healParty"]}, "second": {"modes": ["damage", "damageGroup"]}, "cond": "healed_low", "mult": 0.2},
	"equilibre": {"first": {"styles": ["holy"], "modes": ["damage", "damageGroup"]}, "second": {"styles": ["shadow"], "modes": ["damage", "damageGroup"]},
		"cond": "", "mult": 0.15, "recoil_pct": 3, "both": true},
}

static var ctx: Dictionary = {}      # sort en cours de résolution (renseigné par begin_cast, lu par les hooks de dégâts, de soin et de mort)

# ------------------------------------------------------------------ état

static func active(gs: GameState) -> bool:
	if gs == null or gs.run_seed != "":      # partie classée : règles d'origine, rejeu identique
		return false
	return Settings.living_skills

static func state(gs: GameState) -> Dictionary:
	if gs.living.is_empty():
		gs.living = {"v": SCHEMA, "sk": {}, "rel": {}, "fr": 0, "cb": 0, "led": {}, "log": []}
	return gs.living

static func _sk(gs: GameState, key: String) -> Dictionary:
	var sks: Dictionary = state(gs).sk
	if not sks.has(key):
		sks[key] = {"a": 0.0, "t": {}, "m": [], "e": "", "e2": "", "o": 0, "u": 0, "c": 0, "rp": [], "k": {}}
	return sks[key]

static func has_entry(gs: GameState, char_id: String, skill_id: String) -> bool:
	return state(gs).sk.has(LivingCatalog.key(char_id, skill_id))

static func affinity(gs: GameState, char_id: String, skill_id: String) -> float:
	var s: Dictionary = state(gs).sk.get(LivingCatalog.key(char_id, skill_id), {})
	return float(s.get("a", 0.0))

static func tier(a: float) -> int:
	var t := 0
	for i in TIER_AT.size():
		if a >= float(TIER_AT[i]):
			t = i
	return t

static func evolved(gs: GameState, char_id: String, skill_id: String) -> String:
	var s: Dictionary = state(gs).sk.get(LivingCatalog.key(char_id, skill_id), {})
	return str(s.get("e", ""))

## Évolutions éveillées d'une compétence : la première (dès « attachée »), et la seconde (dès « liée »).
static func evos_of(gs: GameState, char_id: String, skill_id: String) -> Array:
	var s: Dictionary = state(gs).sk.get(LivingCatalog.key(char_id, skill_id), {})
	var out: Array = []
	for k in ["e", "e2"]:
		if str(s.get(k, "")) != "":
			out.append(str(s.get(k, "")))
	return out

static func has_evo(gs: GameState, char_id: String, skill_id: String, kind: String) -> bool:
	return evos_of(gs, char_id, skill_id).has(kind)

## Geste signature (palier « fusionnelle ») : disponible une fois par combat pour une compétence d'affinité ≥ 80, selon sa famille.
static func sig_ready(gs: GameState, key: String) -> bool:
	return tier(float(_sk(gs, key).a)) >= SIG_TIER and not _led(gs).flags.has("sig|" + key)

## Dépense le geste signature : une ligne du carnet entre guillemets (famille : offense, technique, soin, defense, controle, soutien, passif, instinct).
static func _sig_spend(gs: GameState, key: String, who: String) -> void:
	_led(gs).flags["sig|" + key] = true
	var sid := key.split("|")[1]
	var prof := LivingCatalog.profile(gs.cfg, sid)
	if prof.is_empty():
		return
	GameState.living_log(gs, MARK + L.fa(L.t("ui.living.sig_log_%s" % str(prof.family)), [str(prof.name), who]) + " »")

## Traits d'une compétence pour un héros : naissance (profil) + dérive vécue, bornés à 0-100.
static func traits(gs: GameState, char_id: String, skill_id: String) -> Dictionary:
	var prof := LivingCatalog.profile(gs.cfg, skill_id)
	var out := {}
	if prof.is_empty():
		return out
	var s: Dictionary = state(gs).sk.get(LivingCatalog.key(char_id, skill_id), {})
	var drift: Dictionary = s.get("t", {})
	for t in (prof.traits as Dictionary).keys():
		out[t] = clampi(int(prof.traits[t]) + int(drift.get(t, 0)), 0, 100)
	return out

static func dominant(gs: GameState, char_id: String, skill_id: String) -> String:
	var tr := traits(gs, char_id, skill_id)
	var best := ""
	var bv := -1
	for t in LivingCatalog.TRAITS:      # ordre fixe : égalité départagée de façon stable
		if tr.has(t) and int(tr[t]) > bv:
			bv = int(tr[t])
			best = t
	return best

## Compétences d'un héros qui comptent pour le système : sorts connus + ultime, talents choisis, instinct de sa famille.
static func skills_of(gs: GameState, c: Dictionary) -> Array:
	var out: Array = []
	for sid in c.get("spellsKnown", []):
		out.append(str(sid))
	var ult := Characters.ultimate_id(gs.cfg, c)
	if ult != "" and not out.has(ult):
		out.append(ult)
	for t in c.get("talents", []):
		out.append(str(t.id))
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	var fam := str(cls.get("evolvesFrom", cls.get("name", "")))
	if LivingCatalog.INSTINCT_FAMILIES.has(fam):
		out.append(LivingCatalog.instinct_id(fam))
	return out

# ------------------------------------------------------------------ registre du combat

static func _led(gs: GameState) -> Dictionary:
	var st := state(gs)
	if (st.led as Dictionary).is_empty():
		st.led = {"n": 0, "sk": {}, "ps": {}, "recent": [], "pairs": {}, "say": 0, "say_n": -99, "mon": [], "xp": 0, "boss": false, "hp_min": 1.0,
			"saved": {}, "flags": {}, "dmg_by": {}, "dmg_total": 0}
	return st.led

static func _lsk(gs: GameState, key: String) -> Dictionary:
	var led := _led(gs)
	if not (led.sk as Dictionary).has(key):
		led.sk[key] = {"c": 0, "dmg": 0, "heal": 0, "kills": 0, "boss": 0, "low": 0, "stat": 0, "risk": 0, "safe": 0, "newmon": 0, "party": 0, "self": 0, "mon": {}}
	return led.sk[key]

static func _lps(gs: GameState, char_id: String) -> Dictionary:
	var led := _led(gs)
	if not (led.ps as Dictionary).has(char_id):
		led.ps[char_id] = {"crit": 0, "melee": 0, "spell": 0, "hit": 0, "low": 0, "steal": 0, "inst": 0}
	return led.ps[char_id]

static func _theme(gs: GameState) -> String:
	var lv: Array = gs.cfg.get("levels", [])
	if gs.level_index >= 0 and gs.level_index < lv.size():
		return str(lv[gs.level_index].get("theme", ""))
	return ""

static func _hp_frac(c: Dictionary) -> float:
	return float(c.get("hp", 0)) / maxf(1.0, float(c.get("maxHp", 1)))

static func _party_low(gs: GameState, except_id: String = "", below: float = 0.35) -> bool:
	for p in gs.party:
		if str(p.id) != except_id and int(p.hp) > 0 and _hp_frac(p) < below:
			return true
	return false

## Évolution active d'un sort pour ce héros (« » si aucune).
static func evo_of(gs: GameState, char_id: String, skill_id: String) -> String:
	return evolved(gs, char_id, skill_id)

## Évolutions de passifs d'un héros : ensemble des clés actives.
static func passive_kinds(gs: GameState, c: Dictionary) -> Array:
	var out: Array = []
	for t in c.get("talents", []):
		out.append_array(evos_of(gs, str(c.id), str(t.id)))
	return out

# ------------------------------------------------------------------ hooks de combat

## Coût d'un sort : certaines évolutions coûtent un peu plus, une compétence agitée aussi. Jamais de refus : sans l'endurance du coût majoré
## (mais avec celle du coût de base), le sort se lance au coût de base, sans le bonus.
static func adjust_cost(gs: GameState, caster: Dictionary, spell: Dictionary, base: int) -> int:
	ctx = {}
	if not active(gs) or base <= 0:
		return base
	var cid := str(caster.id)
	var sid := str(spell.id)
	var evos := evos_of(gs, cid, sid)
	var mult := 1.0
	if evos.has("precision") or evos.has("domination"):
		mult += 0.1
	var mood := _mood(gs, caster, sid)
	if mood:
		mult += 0.25
	var wanted := int(ceil(float(base) * mult))
	var have := int(caster.get("stamina", 0))
	if wanted > base and have < wanted:
		mood = false
		wanted = base
	ctx = {"key": LivingCatalog.key(cid, sid), "mood": mood}
	return wanted

## Humeur : une compétence instable (trait au-delà de MOOD_INS) s'agite quand son porteur a moins de la moitié de ses PV : +20 % d'effet, +25 % de coût.
static func _mood(gs: GameState, caster: Dictionary, skill_id: String) -> bool:
	if LivingCatalog.profile(gs.cfg, skill_id).is_empty():
		return false
	var tr := traits(gs, str(caster.id), skill_id)
	return int(tr.get("ins", 0)) >= MOOD_INS and _hp_frac(caster) < 0.5

## Début d'un sort (après coût et recharge) : fixe le contexte, repère les combos répondant à un sort récent et note le tour.
static func begin_cast(gs: GameState, caster: Dictionary, spell: Dictionary, ally: Dictionary, target: Dictionary) -> void:
	if not active(gs):
		ctx = {}
		return
	var cid := str(caster.id)
	var sid := str(spell.id)
	var key := LivingCatalog.key(cid, sid)
	var led := _led(gs)
	led.n = int(led.n) + 1
	var evo := evolved(gs, cid, sid)
	var evos := evos_of(gs, cid, sid)
	var combo := _find_combo(gs, key, spell, ally)
	var mood: bool = bool(ctx.get("mood", false)) and ctx.get("key", "") == key
	ctx = {"key": key, "char": cid, "spell": spell, "evo": evo, "evos": evos, "sig": sig_ready(gs, key), "mood": mood, "combo": combo, "ally": str(ally.get("id", "")), "n": int(led.n),
		"target": str(target.get("id", "")), "fam": LivingCatalog.family_of_spell(spell), "mult": 1.0, "healed_low": false, "kill": false}
	var ls := _lsk(gs, key)
	ls.c = int(ls.c) + 1
	var hp := _hp_frac(caster)
	if hp < 0.4:
		ls.risk = int(ls.risk) + 1
	elif hp >= 0.8 and not _party_low(gs, "", 0.7):
		ls.safe = int(ls.safe) + 1
	if bool(target.get("isBoss", false)):
		(led as Dictionary)["boss"] = true
	if mood:
		_say(gs, "mood", key, [LivingCatalog.profile(gs.cfg, sid).name])

static func _match(m: Dictionary, spell: Dictionary) -> bool:
	if m.has("styles") and not (m.styles as Array).has(str(spell.get("style", ""))):
		return false
	if m.has("modes") and not (m.modes as Array).has(str(spell.get("mode", ""))):
		return false
	return true

## Combo applicable : un sort récent (des 3 derniers) correspond à `first`, ce sort à `second`, et la relation entre les deux est de niveau ≥ 1.
static func _find_combo(gs: GameState, key: String, spell: Dictionary, ally: Dictionary) -> Dictionary:
	var led := _led(gs)
	var recent: Array = led.recent
	for cid in COMBOS.keys():
		var cb: Dictionary = COMBOS[cid]
		if not _match(cb.second, spell):
			continue
		for i in range(recent.size() - 1, -1, -1):
			var r: Array = recent[i]
			if int(led.n) + 1 - int(r[1]) > WINDOW:
				break
			if str(r[0]) == key:
				continue
			var fs := _spell(gs, str(r[2]))
			if fs.is_empty() or not _match(cb.first, fs):
				continue
			var lvl := rel_level(gs, str(r[0]), key)
			if lvl < 1:
				continue
			if str(cb.cond) == "same_ally" and (str(r[3]) == "" or str(r[3]) != str(ally.get("id", ""))):
				continue
			if str(cb.cond) == "shielded_caster" and str(r[3]) != key.split("|")[0]:
				continue
			if str(cb.cond) == "healed_low" and not bool(r[4]):
				continue
			return {"id": cid, "lvl": lvl, "first": str(r[0])}
	return {}

static func _spell(gs: GameState, sid: String) -> Dictionary:
	for s in gs.cfg.get("spells", []):
		if str(s.id) == sid:
			return s
	return {}

## Multiplicateur des dégâts d'un coup de sort (évolution, humeur, combo, adversaire apprécié, passif). Plafonné par MULT_CAP.
static func mod_damage(gs: GameState, attacker: Dictionary, spell: Dictionary, target: Dictionary, holder: Dictionary, st: Dictionary, dmg: int, aoe: bool, resist: int) -> int:
	if not active(gs) or spell.is_empty() or dmg <= 0 or ctx.is_empty() or str(ctx.get("char", "")) != str(attacker.id) or str(ctx.get("spell", {}).get("id", "")) != str(spell.id):
		return dmg
	var m := 1.0
	var mon_hp := float(holder.get("hp", 0)) / maxf(1.0, float(holder.get("maxHp", st.get("maxHp", 1))))
	var is_boss := bool(target.get("isBoss", false))
	var is_group := bool(target.get("isGroup", false))
	var statused: bool = not (holder.get("statusEffects", []) as Array).is_empty()
	for ev in ctx.evos:
		match ev:
			"acharnement":
				if mon_hp <= 0.5:
					m *= 1.25
			"precision":
				if not aoe and resist > 0:
					m *= 1.0 + minf(0.6, float(resist) * 0.4 / maxf(1.0, 100.0 - float(resist)))
			"tactique":
				m *= 1.3 if statused else 0.9
			"brutes":
				m *= 1.25 if (is_boss or is_group) else 0.9
			"temerite":
				if _hp_frac(attacker) > 0.3:
					m *= 1.35
			"prudence":
				m *= 0.85
			"vengeance":
				m *= 1.3 if _party_low(gs, str(attacker.id)) else 0.95
			"balayage":
				var alive := 1
				if st.has("members"):
					alive = 0
					for mem in st.members:
						if bool(mem.alive):
							alive += 1
				m *= 1.0 + 0.12 * float(maxi(0, alive - 1)) if alive > 1 else 0.92
	if bool(ctx.mood):
		m *= 1.2
	# geste signature (fusionnelle) : le coup passe la résistance (jusqu'à ×1,6) ; sans résistance, un coup un peu plus juste (×1,15)
	if bool(ctx.get("sig", false)) and ["offense", "technique"].has(str(ctx.get("fam", ""))):
		m *= minf(1.6, 100.0 / maxf(40.0, 100.0 - float(resist))) if resist > 0 else 1.15
		ctx["sig_used"] = true
	# combo
	var cmb: Dictionary = ctx.get("combo", {})
	if not cmb.is_empty():
		var cd: Dictionary = COMBOS[str(cmb.id)]
		var ok := true
		match str(cd.cond):
			"burn":
				ok = Statuses.has(holder, "burn")
			"chill":
				ok = Statuses.has(holder, "freeze") or Statuses.has(holder, "slow")
			"stunned":
				ok = Statuses.has(holder, "stun") or Statuses.has(holder, "slow")
		if ok and float(cd.get("mult", 0.0)) > 0.0:
			m *= 1.0 + float(cd.mult) * (0.8 + 0.25 * float(int(cmb.lvl)))      # niveau 1 : ×1,05 de la valeur, niveau 2 : ×1,3, niveau 3 : ×1,55
			ctx["combo_hit"] = true
	# adversaire apprécié : 3 victoires contre la même espèce
	var sk := _sk(gs, str(ctx.key))
	if int((sk.k as Dictionary).get(str(target.get("id", "")), 0)) >= 3:
		m *= 1.08
		ctx["pref"] = true
	# passifs éveillés du porteur
	var pk := passive_kinds(gs, attacker)
	if pk.has("p_sens") and Resist.of_monster(target, Resist.style_key(str(spell.get("style", "")))) < 0:
		m *= 1.12
	m = minf(m, MULT_CAP)
	ctx["mult"] = m
	return maxi(1, int(round(float(dmg) * m)))

## Bonus de coup critique des passifs éveillés (p_focus : +6 points contre un adversaire déjà croisé au moins 3 fois).
static func crit_bonus(gs: GameState, attacker: Dictionary, target: Dictionary) -> int:
	if not active(gs) or not passive_kinds(gs, attacker).has("p_focus"):
		return 0
	return 6 if _seen_count(gs, str(target.get("id", ""))) >= 3 else 0

## Coup porté : registre (dégâts, adversaire, coup critique, attaque sans sort).
static func note_hit(gs: GameState, attacker: Dictionary, spell: Dictionary, target: Dictionary, dmg: int, crit: bool, resist: int) -> void:
	if not active(gs) or dmg <= 0:
		return
	var led := _led(gs)
	var cid := str(attacker.id)
	var ps := _lps(gs, cid)
	ps.hit = int(ps.hit) + 1
	if crit:
		ps.crit = int(ps.crit) + 1
	led.dmg_total = int(led.dmg_total) + dmg
	led.dmg_by[cid] = int(led.dmg_by.get(cid, 0)) + dmg
	var mid := str(target.get("id", ""))
	if not (led.mon as Array).has(mid):
		(led.mon as Array).append(mid)
	if spell.is_empty():
		ps.melee = int(ps.melee) + 1
		return
	ps.spell = int(ps.spell) + 1
	if ctx.is_empty() or str(ctx.get("char", "")) != cid:
		return
	var ls := _lsk(gs, str(ctx.key))
	ls.dmg = int(ls.dmg) + dmg
	if bool(target.get("isBoss", false)):
		ls.boss = int(ls.boss) + 1
	if resist >= 25:
		_remember(gs, str(ctx.key), "resist", mid)
	var mon: Dictionary = ls.mon
	mon[mid] = int(mon.get(mid, 0)) + 1

## Un monstre meurt : la compétence du coup fatal s'en souvient, et la compétence apprécie désormais cet adversaire.
static func note_kill(gs: GameState, def: Dictionary, xp: int) -> void:
	if not active(gs):
		return
	var led := _led(gs)
	led.xp = int(led.xp) + xp
	if ctx.is_empty() or not ctx.has("char"):
		return
	var key := str(ctx.key)
	var ls := _lsk(gs, key)
	ls.kills = int(ls.kills) + 1
	var mid := str(def.get("id", ""))
	var sk := _sk(gs, key)
	var kk: Dictionary = sk.k
	kk[mid] = int(kk.get(mid, 0)) + 1
	if kk.size() > 5:      # peu de places : on oublie l'adversaire le moins croisé
		var worst := ""
		var wn := 1 << 30
		for k2 in kk.keys():
			if int(kk[k2]) < wn and str(k2) != mid:
				wn = int(kk[k2])
				worst = str(k2)
		kk.erase(worst)
	var prof := LivingCatalog.profile(gs.cfg, str(ctx.spell.id))
	if int(kk[mid]) == 3:
		_say(gs, "pref", key, [prof.get("name", "")])
	var first := not _has_mem(gs, key, "first_kill")
	if first:
		_remember(gs, key, "first_kill", mid)
	if bool(def.get("isBoss", false)):
		ls.boss = int(ls.boss) + 1
		_remember(gs, key, "first_boss", mid)
		_remember(gs, key, "decisive", mid)
		_say(gs, "memory", key, [prof.get("name", "")])
	ctx["kill"] = true

## Soin : multiplicateur d'évolution/humeur/attachement. `frac` = PV de la cible avant le soin.
static func mod_heal(gs: GameState, caster: Dictionary, spell: Dictionary, ally: Dictionary, amt: int) -> int:
	if not active(gs) or ctx.is_empty() or str(ctx.get("char", "")) != str(caster.id) or amt <= 0:
		return amt
	var m := 1.0
	var frac := _hp_frac(ally)
	for ev in ctx.evos:
		match ev:
			"compassion":
				m *= 1.4 if frac < 0.35 else (0.8 if frac >= 0.7 else 1.0)
			"sacrifice":
				if _hp_frac(caster) >= 0.25:
					m *= 1.3
					ctx["recoil"] = maxf(float(ctx.get("recoil", 0.0)), 0.05)
			"attachee":
				m *= 1.25 if _bond_with(gs, str(ctx.key)) == str(ally.get("id", "")) else 0.9
	if bool(ctx.mood):
		m *= 1.2
	if frac < 0.35:
		ctx["healed_low"] = true
		(_led(gs).saved as Dictionary)[str(ally.id)] = str(ctx.key)
	ctx["heal_amt"] = maxi(int(ctx.get("heal_amt", 0)), int(round(float(amt) * m)))
	return int(round(float(amt) * m))

## Après un soin : registre, surplus converti en bouclier (préventive).
static func note_heal(gs: GameState, caster: Dictionary, ally: Dictionary, amt: int, healed: int) -> void:
	if not active(gs) or ctx.is_empty() or str(ctx.get("char", "")) != str(caster.id):
		return
	var ls := _lsk(gs, str(ctx.key))
	ls.heal = int(ls.heal) + healed
	if bool(ctx.get("healed_low", false)):
		ls.low = int(ls.low) + 1
	if str(ally.id) == str(caster.id):
		ls.self = int(ls.self) + 1
	if (ctx.evos as Array).has("preventive") and amt > healed:
		var sh := mini(int(round(float(ally.maxHp) * 0.15)), amt - healed)
		if sh > 0:
			ally["shieldAmount"] = int(ally.get("shieldAmount", 0)) + sh
			GameState.living_log(gs, L.fa(L.t("ui.living.fx_preventive"), [ally.name, sh]))

## Bouclier : multiplicateur d'évolution/humeur.
static func mod_shield(gs: GameState, caster: Dictionary, spell: Dictionary, ally: Dictionary, amt: int) -> int:
	if not active(gs) or ctx.is_empty() or str(ctx.get("char", "")) != str(caster.id) or amt <= 0:
		return amt
	var m := 1.0
	var frac := _hp_frac(ally)
	for ev in ctx.evos:
		match ev:
			"gardienne":
				m *= 1.25
				ctx["guard"] = true
			"reactive":
				m *= 1.6 if frac < 0.5 else 0.85
	if bool(ctx.mood):
		m *= 1.2
	if frac < 0.35:
		ctx["healed_low"] = true
		(_led(gs).saved as Dictionary)[str(ally.id)] = str(ctx.key)
	ctx["shield_amt"] = int(round(float(amt) * m))
	return int(ctx.shield_amt)

## Fin d'un sort : effets secondaires des évolutions et des combos, relations, registre.
static func end_cast(gs: GameState, caster: Dictionary, spell: Dictionary, ally: Dictionary, target: Dictionary) -> void:
	if not active(gs) or ctx.is_empty() or str(ctx.get("char", "")) != str(caster.id):
		return
	var key := str(ctx.key)
	var led := _led(gs)
	var mode := str(spell.get("mode", ""))
	var ls := _lsk(gs, key)
	# effets secondaires
	for evo in ctx.evos:
		match evo:
			"temerite":
				if mode == "damage" or mode == "damageGroup":
					_strain(gs, caster, 0.04)
			"prudence":
				if mode == "damage" or mode == "damageGroup":
					var cap := int(round(float(caster.maxHp) * 0.3))
					caster["shieldAmount"] = mini(cap, int(caster.get("shieldAmount", 0)) + int(round(float(caster.maxHp) * 0.12)))
			"sacrifice":
				if float(ctx.get("recoil", 0.0)) > 0.0:
					_strain(gs, caster, float(ctx.recoil))
			"gardienne":
				if bool(ctx.get("guard", false)) and not ally.is_empty() and str(ally.id) != str(caster.id):
					caster["shieldAmount"] = int(caster.get("shieldAmount", 0)) + int(round(float(ctx.get("shield_amt", 0)) * 0.4))
			"rempart":
				if mode == "shieldSingle" and not ally.is_empty():
					var other: Dictionary = {}
					var lo := 2.0
					for p in gs.party:
						if int(p.hp) > 0 and str(p.id) != str(ally.id) and str(p.id) != str(caster.id) and _hp_frac(p) < lo:
							lo = _hp_frac(p)
							other = p
					if not other.is_empty():
						other["shieldAmount"] = int(other.get("shieldAmount", 0)) + int(round(float(ctx.get("shield_amt", 0)) * 0.35))
			"domination", "patience":
				if mode == "dispelSingle" and not ally.is_empty() and bool(ctx.get("applied", false)):
					Statuses.give(ally, "vigor", 2 if evo == "domination" else 1, str(caster.id))      # l'allié délivré garde une brève Vigueur
					Characters.recompute(ally, gs.cfg)
				if evo == "patience" and not spell.get("ultimate", false):
					var cds: Dictionary = caster.get("spellCooldowns", {})
					var ready := int(cds.get(str(spell.id), 0))
					var extra := int(float(spell.get("cooldownSec", 6)) * 250.0)      # prix de la patience : recharge allongée d'un quart
					cds[str(spell.id)] = ready + extra
					caster["spellCooldowns"] = cds
			"veille":
				if mode == "dispelSingle" and not ally.is_empty():
					ally["shieldAmount"] = int(ally.get("shieldAmount", 0)) + int(round(float(ally.maxHp) * 0.08))
			"relais":
				if mode == "partyUtility":      # relais : les recharges raccourcies le sont de moitié de plus
					var cut := int(float(spell.get("cooldownReductionSec", 0)) * 500.0)
					if cut > 0:
						for p in gs.alive_party():
							var cds: Dictionary = p.get("spellCooldowns", {})
							for sid in cds.keys():
								cds[sid] = maxi(GameClock.ms, int(cds[sid]) - cut)
				elif mode == "staminaRestoreSingle" and not ally.is_empty():
					ally["stamina"] = mini(int(ally.get("maxStamina", 100)), int(ally.get("stamina", 0)) + 4)
			"memoire":
				var mid := str(target.get("id", ""))
				if mid != "" and _seen_count(gs, mid) >= 3:
					caster["stamina"] = mini(int(caster.get("maxStamina", 100)), int(caster.get("stamina", 0)) + 8)
			"ruse":
				if bool(ctx.get("applied", false)):
					caster["stamina"] = mini(int(caster.get("maxStamina", 100)), int(caster.get("stamina", 0)) + 5)
	_sig_end_cast(gs, caster, spell, ally, key)
	var cmb: Dictionary = ctx.get("combo", {})
	if not cmb.is_empty():
		var cd: Dictionary = COMBOS[str(cmb.id)]
		var fired := bool(ctx.get("combo_hit", false)) or str(cd.cond) in ["same_ally", "shielded_caster", "healed_low", ""]
		if fired:
			if cd.has("stamina"):
				caster["stamina"] = mini(int(caster.get("maxStamina", 100)), int(caster.get("stamina", 0)) + int(cd.stamina))
			if cd.has("shield_pct") and not ally.is_empty():
				ally["shieldAmount"] = int(ally.get("shieldAmount", 0)) + int(round(float(ally.maxHp) * float(cd.shield_pct) / 100.0))
			if cd.has("recoil_pct"):
				_strain(gs, caster, float(cd.recoil_pct) / 100.0)
			_say(gs, "combo", key, [str(cmb.id), LivingCatalog.profile(gs.cfg, str(spell.id)).get("name", "")])
			(led.pairs as Dictionary)[_pair(str(cmb.first), key)] = true
	# relations : un sort qui fait suite à un sort récent, dans le cadre d'un combo possible, prépare une relation (réglée en fin de combat)
	for r in (led.recent as Array):
		if int(led.n) - int(r[1]) > WINDOW or str(r[0]) == key:
			continue
		var fs := _spell(gs, str(r[2]))
		if fs.is_empty():
			continue
		for cid2 in COMBOS.keys():
			var cb2: Dictionary = COMBOS[cid2]
			if _match(cb2.first, fs) and _match(cb2.second, spell):
				(led.pairs as Dictionary)[_pair(str(r[0]), key)] = true
	var applied := bool(ctx.get("applied", false))
	if applied:
		ls.stat = int(ls.stat) + 1
	# ce sort rejoint la liste des sorts récents (6 au plus)
	(led.recent as Array).append([key, int(led.n), str(spell.id), str(ally.get("id", "")) if not ally.is_empty() else str(caster.id), bool(ctx.get("healed_low", false))])
	if (led.recent as Array).size() > 6:
		(led.recent as Array).pop_front()
	var all_alive := gs.alive_party().size()
	if all_alive >= 3 and (mode == "partyUtility" or mode == "healParty"):
		ls.party = int(ls.party) + 1
	ctx = {}

## Geste signature d'une compétence fusionnelle (affinité ≥ 80), une fois par combat, propre à sa famille. Aucun n'est un simple pourcentage de dégâts :
## offense/technique (dans mod_damage) : le coup passe la résistance ; soin : le compagnon le plus blessé reçoit aussi la moitié du soin (un soin de groupe
## pose un voile de 8 % PV max sur chacun) ; défense : la moitié du bouclier couvre aussi le reste du groupe ; contrôle : un tour de plus (sommeil) ou 2 tours de
## Vigueur à l'allié délivré ; soutien : +8 d'endurance à tout le groupe.
static func _sig_end_cast(gs: GameState, caster: Dictionary, spell: Dictionary, ally: Dictionary, key: String) -> void:
	if not bool(ctx.get("sig", false)):
		return
	var fam := str(ctx.get("fam", ""))
	var mode := str(spell.get("mode", ""))
	var who := str(ally.get("name", caster.name)) if not ally.is_empty() else str(caster.name)
	var spent := false
	match fam:
		"offense", "technique":
			spent = bool(ctx.get("sig_used", false))
		"soin":
			if mode == "healParty":
				for p in gs.alive_party():
					p["shieldAmount"] = int(p.get("shieldAmount", 0)) + int(round(float(p.maxHp) * 0.08))
				spent = true
			elif mode == "healSingle" and not ally.is_empty():
				var other: Dictionary = {}
				var lo := 1.0
				for p in gs.party:
					if int(p.hp) > 0 and str(p.id) != str(ally.id) and _hp_frac(p) < lo:
						lo = _hp_frac(p)
						other = p
				if not other.is_empty() and int(ctx.get("heal_amt", 0)) > 1:
					var h := maxi(1, int(round(float(ctx.heal_amt) * 0.5)))
					other["hp"] = mini(int(other.maxHp), int(other.hp) + h)
					who = str(other.name)
					spent = true
		"defense":
			if int(ctx.get("shield_amt", 0)) > 1:
				for p in gs.alive_party():
					if str(p.id) != str(ally.get("id", "")):
						p["shieldAmount"] = int(p.get("shieldAmount", 0)) + int(round(float(ctx.shield_amt) * 0.5))
				spent = true
		"controle":
			if mode == "dispelSingle" and not ally.is_empty() and bool(ctx.get("applied", false)):
				Statuses.give(ally, "vigor", 2, str(caster.id))
				Characters.recompute(ally, gs.cfg)
				spent = true
			elif mode == "sleepGroup" and bool(ctx.get("sig_used", false)) and bool(ctx.get("applied", false)):
				spent = true
		"soutien":
			for p in gs.alive_party():
				p["stamina"] = mini(int(p.get("maxStamina", 100)), int(p.get("stamina", 0)) + 8)
			spent = true
	if spent:
		_sig_spend(gs, key, who)

## Tours d'effet supplémentaires d'un sort de contrôle (sommeil) : Domination et Patience allongent d'un tour.
static func status_bonus(gs: GameState, caster: Dictionary, spell: Dictionary) -> int:
	if not active(gs):
		return 0
	var evos := evos_of(gs, str(caster.id), str(spell.id))
	var n := 1 if evos.has("domination") or evos.has("patience") else 0
	if not ctx.is_empty() and str(ctx.get("char", "")) == str(caster.id) and bool(ctx.get("sig", false)) and str(ctx.get("fam", "")) == "controle":
		ctx["sig_used"] = true      # geste signature du contrôle : un tour de plus
		n += 1
	return n

## Un sort de statut a posé son effet (utilisé par ruse, patience et le registre).
static func note_status_applied() -> void:
	if not ctx.is_empty():
		ctx["applied"] = true

static func _strain(gs: GameState, c: Dictionary, pct: float) -> void:
	var loss := maxi(1, int(round(float(c.maxHp) * pct)))
	c["hp"] = maxi(1, int(c.hp) - loss)      # jamais mortel : le contrecoup laisse toujours 1 PV
	GameState.living_log(gs, L.fa(L.t("ui.living.fx_strain"), [c.name, loss]))

## Un héros subit un coup de monstre : registre (protection, passifs) et frémissement d'une compétence protectrice.
static func on_party_hurt(gs: GameState, victim: Dictionary, dmg: int) -> void:
	if not active(gs) or dmg <= 0:
		return
	var led := _led(gs)
	var f := _hp_frac(victim)
	led.hp_min = minf(float(led.hp_min), f)
	var ps := _lps(gs, str(victim.id))
	ps.hit = int(ps.hit) + 1
	if f < 0.35:
		ps.low = int(ps.low) + 1
		for p in gs.party:      # une compétence de protection d'un autre héros frémit quand un compagnon est blessé
			if int(p.hp) > 0 and str(p.id) != str(victim.id):
				for sid in skills_of(gs, p):
					var prof := LivingCatalog.profile(gs.cfg, sid)
					if prof.is_empty() or not ["soin", "defense"].has(str(prof.family)):
						continue
					var key := LivingCatalog.key(str(p.id), sid)
					if tier(float(_sk(gs, key).a)) >= 2 and _say(gs, "protect", key, [prof.name, victim.name]):
						return

## Réduction de dégâts reçus : passif « ancre » éveillé, tant qu'un compagnon est en danger.
static func mod_incoming(gs: GameState, victim: Dictionary, dmg: int) -> int:
	if not active(gs) or dmg <= 1 or not passive_kinds(gs, victim).has("p_ancre"):
		return dmg
	return maxi(1, int(round(float(dmg) * 0.92))) if _party_low(gs, str(victim.id)) else dmg

## Début du tour d'un héros : « second souffle » (passif éveillé), une fois par combat.
static func on_turn(gs: GameState, c: Dictionary) -> void:
	if not active(gs) or int(c.hp) <= 0:
		return
	# geste signature d'un talent fusionnel : une fois par combat, un souffle de vie sous 40 % de PV (8 % PV max)
	if _hp_frac(c) < 0.4:
		for t in c.get("talents", []):
			var tk := LivingCatalog.key(str(c.id), str(t.id))
			if sig_ready(gs, tk):
				var h := maxi(1, int(round(float(c.maxHp) * 0.08)))
				c["hp"] = mini(int(c.maxHp), int(c.hp) + h)
				_sig_spend(gs, tk, str(c.name))
				break
	if _hp_frac(c) >= 0.25 or not passive_kinds(gs, c).has("p_souffle"):
		return
	var flags: Dictionary = _led(gs).flags
	var fk := "souffle|" + str(c.id)
	if flags.has(fk):
		return
	flags[fk] = true
	var heal := maxi(1, int(round(float(c.maxHp) * 0.1)))
	c["hp"] = mini(int(c.maxHp), int(c.hp) + heal)
	GameState.living_log(gs, L.fa(L.t("ui.living.fx_souffle"), [c.name, heal]))

## Vol de vie d'un héros ayant le passif « veine » éveillé : 30 % du montant soigne aussi le compagnon le plus blessé.
static func on_lifesteal(gs: GameState, c: Dictionary, healed: int) -> void:
	if not active(gs) or healed <= 0:
		return
	_lps(gs, str(c.id)).steal = int(_lps(gs, str(c.id)).steal) + healed
	if not passive_kinds(gs, c).has("p_veine"):
		return
	var worst: Dictionary = {}
	var lo := 2.0
	for p in gs.party:
		if int(p.hp) > 0 and str(p.id) != str(c.id) and _hp_frac(p) < lo and _hp_frac(p) < 1.0:
			lo = _hp_frac(p)
			worst = p
	if not worst.is_empty():
		var h := maxi(1, int(round(float(healed) * 0.3)))
		worst["hp"] = mini(int(worst.maxHp), int(worst.hp) + h)

## Résultat d'un instinct (« ok », « perfect », « fail ») : registre ; les instincts éveillés prolongent la fenêtre ou chargent l'ultime.
static func note_instinct(gs: GameState, victim: Dictionary, outcome: String) -> void:
	if not active(gs):
		return
	var cls := Characters.class_def(gs.cfg, str(victim.get("classId", "")))
	var fam := str(cls.get("evolvesFrom", cls.get("name", "")))
	var sid := LivingCatalog.instinct_id(fam)
	var key := LivingCatalog.key(str(victim.id), sid)
	var ls := _lsk(gs, key)
	if outcome == "ok" or outcome == "perfect":
		ls.c = int(ls.c) + 1
		ls.dmg = int(ls.dmg) + (2 if outcome == "perfect" else 1)
	if outcome == "perfect" and sig_ready(gs, key):      # geste signature de l'instinct fusionnel : le premier réflexe parfait du combat charge l'ultime
		Characters.ult_gain(gs.cfg, victim, "gainTaken")
		_sig_spend(gs, key, str(victim.name))
	if (outcome == "ok" or outcome == "perfect") and has_evo(gs, str(victim.id), sid, "i_echo"):
		Characters.ult_gain(gs.cfg, victim, "gainTaken")

## Instinct « veille » éveillé : +6 points de chance de réussite.
static func instinct_bonus(gs: GameState, victim: Dictionary) -> float:
	if not active(gs):
		return 0.0
	var cls := Characters.class_def(gs.cfg, str(victim.get("classId", "")))
	var fam := str(cls.get("evolvesFrom", cls.get("name", "")))
	return 6.0 if has_evo(gs, str(victim.id), LivingCatalog.instinct_id(fam), "i_vigil") else 0.0

# ------------------------------------------------------------------ souvenirs

static func _has_mem(gs: GameState, key: String, kind: String) -> bool:
	for m in _sk(gs, key).m:
		if str(m[0]) == kind:
			return true
	return false

static func _remember(gs: GameState, key: String, kind: String, detail: String) -> void:
	var mems: Array = _sk(gs, key).m
	for m in mems:
		if str(m[0]) == kind and str(m[1]) == detail:
			m[2] = mini(99, int(m[2]) + 1)
			return
	if kind in ["first_kill", "first_boss", "env"] and _count_kind(mems, kind) >= 3:
		return
	mems.append([kind, detail, 1])
	while mems.size() > MEM_MAX:      # trop de souvenirs : on oublie le moins important, à égalité le plus ancien
		var worst := 0
		var wp := -1
		for i in mems.size():
			var p := MEM_PRIORITY.find(str(mems[i][0]))
			if p < 0:
				p = MEM_PRIORITY.size()
			if p > wp:
				wp = p
				worst = i
		mems.remove_at(worst)

static func _count_kind(mems: Array, kind: String) -> int:
	var n := 0
	for m in mems:
		if str(m[0]) == kind:
			n += 1
	return n

## Compagnon le plus sauvé par cette compétence (≥ 2 sauvetages), « » sinon.
static func _bond_with(gs: GameState, key: String) -> String:
	var best := ""
	var bn := 1
	for m in _sk(gs, key).m:
		if str(m[0]) == "saved" and int(m[2]) > bn:
			bn = int(m[2])
			best = str(m[1])
	return best

static func _seen_count(gs: GameState, mon_id: String) -> int:
	var b = gs.bestiary.get(mon_id, 0)
	if b is Dictionary:
		return int((b as Dictionary).get("kills", (b as Dictionary).get("seen", 0)))
	return int(b)

# ------------------------------------------------------------------ relations

static func _pair(a: String, b: String) -> String:
	return "%s~%s" % ([a, b] if a < b else [b, a])

static func rel_level(gs: GameState, a: String, b: String) -> int:
	var r: Dictionary = state(gs).rel.get(_pair(a, b), {})
	var v := int(r.get("v", 0))
	var lvl := 0
	for i in REL_AT.size():
		if v >= int(REL_AT[i]):
			lvl = i + 1
	return lvl

## Nature d'une relation d'après les deux compétences (voir docs/LIVING_SKILLS.md).
static func rel_type(gs: GameState, a: String, b: String, lvl: int) -> String:
	var ka := a.split("|")
	var kb := b.split("|")
	var sa := _spell(gs, ka[1])
	var sb := _spell(gs, kb[1])
	if sa.is_empty() or sb.is_empty():
		return "complementaire"
	var st_a := str(sa.get("style", ""))
	var st_b := str(sb.get("style", ""))
	if [["fire", "ice"], ["ice", "fire"], ["holy", "shadow"], ["shadow", "holy"]].has([st_a, st_b]):
		return "antagoniste"
	var fa := LivingCatalog.family_of_spell(sa)
	var fb := LivingCatalog.family_of_spell(sb)
	if ka[0] == kb[0] and st_a == st_b and lvl >= 3:
		return "fusionnelle"
	if ka[0] != kb[0] and fa == fb:
		return "rivale"
	if (["soin", "defense"].has(fa) and ["offense", "technique"].has(fb)) or (["soin", "defense"].has(fb) and ["offense", "technique"].has(fa)):
		return "protectrice"
	return "complementaire"

static func relations_of(gs: GameState, key: String) -> Array:
	var out: Array = []
	for pk in state(gs).rel.keys():
		var parts := str(pk).split("~")
		if parts.size() == 2 and (parts[0] == key or parts[1] == key):
			var other := parts[1] if parts[0] == key else parts[0]
			var lvl := rel_level(gs, parts[0], parts[1])
			out.append({"with": other, "level": lvl, "v": int(state(gs).rel[pk].v), "type": rel_type(gs, parts[0], parts[1], lvl)})
	return out

# ------------------------------------------------------------------ manifestations (carnet)

## Message rare dans le carnet : au plus SAY_MAX par combat, SAY_GAP sorts d'écart ; variante choisie par hachage (aucun hasard).
static func _say(gs: GameState, id: String, key: String, args: Array) -> bool:
	var led := _led(gs)
	if int(led.say) >= SAY_MAX or int(led.n) - int(led.say_n) < SAY_GAP:
		return false
	var prof := LivingCatalog.profile(gs.cfg, key.split("|")[1])
	var geste := ["technique", "passif", "instinct"].has(str(prof.get("family", "")))
	var base := "ui.living.say_%s_%s%%d" % [id, "g" if geste else "e"]
	var variants := 2
	var pick := LivingCatalog.hash_id(key + "|" + id + "|" + str(state(gs).cb)) % variants
	var tkey: String = base % (pick + 1)
	var txt := L.t(tkey)
	if txt == tkey:      # clé absente : jamais de texte brut dans le carnet
		return false
	led.say = int(led.say) + 1
	led.say_n = int(led.n)
	var a: Array = []
	for x in args:
		a.append(x)
	if id == "combo":
		a[0] = L.t("ui.living.combo_%s" % str(args[0]))
	var cnt := txt.count("%s")
	while a.size() < cnt:
		a.append("")
	GameState.living_log(gs, MARK + L.fa(txt, a.slice(0, cnt)) + " »")
	return true

# ------------------------------------------------------------------ règlement de fin de combat

## Nouveautés à montrer au joueur (palier franchi, évolution éveillable) : {key, kind: "tier"|"evo", tier}. Effacées quand la fiche du héros est ouverte.
static func push_news(gs: GameState, key: String, kind: String, t: int) -> void:
	var news: Array = state(gs).get_or_add("news", [])
	for n in news:
		if str(n.key) == key and str(n.kind) == kind:
			n["tier"] = t
			return
	news.append({"key": key, "kind": kind, "tier": t})

static func news(gs: GameState, char_id: String = "") -> Array:
	var out: Array = []
	for n in (state(gs).get("news", []) as Array):
		if char_id == "" or str(n.key).begins_with(char_id + "|"):
			out.append(n)
	return out

static func news_clear(gs: GameState, char_id: String) -> void:
	var keep: Array = []
	for n in (state(gs).get("news", []) as Array):
		if not str(n.key).begins_with(char_id + "|"):
			keep.append(n)
	state(gs)["news"] = keep

## À appeler à la fin d'un combat (`outcome` : "win" ou "flee"). Convertit le registre en affinité, traits, souvenirs, relations, fragments.
static func settle(gs: GameState, outcome: String) -> void:
	if not active(gs):
		return
	var st := state(gs)
	var led: Dictionary = st.led
	if led.is_empty():
		return
	st.cb = int(st.cb) + 1
	var cb := int(st.cb)
	var lvl_avg := 0.0
	for p in gs.party:
		lvl_avg += float(p.level)
	lvl_avg /= maxf(1.0, float(gs.party.size()))
	var w := clampf(float(led.xp) / (8.0 + 3.0 * lvl_avg), 0.2, 2.0)      # poids du combat : un combat trivial rapporte peu
	var narrow := outcome == "win" and float(led.hp_min) <= 0.25
	var main_mon := str((led.mon as Array)[0]) if not (led.mon as Array).is_empty() else ""
	var theme := _theme(gs)
	for key in (led.sk as Dictionary).keys():
		var ls: Dictionary = led.sk[key]
		var sk := _sk(gs, str(key))
		var parts: PackedStringArray = str(key).split("|")
		var cid := parts[0]
		var sid := parts[1]
		var raw := minf(float(ls.c), 6.0) * 0.25
		if int(ls.dmg) > 0 or int(ls.heal) > 0 or int(ls.stat) > 0:
			raw += 1.0
		if int(ls.kills) > 0:
			raw += 1.0
		if int(ls.boss) > 0:
			raw += 1.5
		var saves := 0
		for ally_id in (led.saved as Dictionary).keys():
			if str(led.saved[ally_id]) == str(key):
				var ally := gs.char_by_id(str(ally_id))
				if not ally.is_empty() and int(ally.hp) > 0:      # un sauvetage ne compte que si le compagnon est encore debout
					saves += 1
					_remember(gs, str(key), "saved", str(ally_id))
		raw += minf(3.0, float(saves) * 1.5)
		if narrow and int(ls.c) > 0:
			raw += 1.5
			_remember(gs, str(key), "narrow", main_mon)
		var rp: Array = sk.rp
		var seen := 0
		for m in rp:
			if str(m) == main_mon:
				seen += 1
		var novelty := 1.0 if seen < 2 else (0.5 if seen < 4 else 0.3)      # même adversaire encore et encore : gain réduit
		if main_mon != "":
			rp.append(main_mon)
			while rp.size() > 6:
				rp.pop_front()
		var gain := clampf(raw * w * novelty, 0.0, AFF_CAP_COMBAT)
		if outcome == "flee":
			gain = minf(gain, 1.0)
		var before := tier(float(sk.a))
		sk.a = clampf(float(sk.a) + gain, 0.0, 100.0)
		sk.c = int(sk.c) + int(ls.c)
		sk.u = cb
		if theme != "" and int(ls.c) > 0 and _count_kind(sk.m, "env") < 3 and not _has_detail(sk.m, "env", theme):
			_remember(gs, str(key), "env", theme)
		_drift(gs, str(key), sid, ls, saves, outcome)
		var after := tier(float(sk.a))
		var prof := LivingCatalog.profile(gs.cfg, sid)
		if after > before and after >= 1:
			_say(gs, "tier", str(key), [prof.get("name", "")])
			push_news(gs, str(key), "tier", after)
		if int(sk.o) == 0 and float(sk.a) >= EVOLVE_AFF and not available_branches(gs, cid, sid).is_empty():
			sk.o = 1
			push_news(gs, str(key), "evo", after)
			_say(gs, "evo", str(key), [prof.get("name", "")])
			_fragment(gs, 1)
	# passifs : chaque talent choisi est crédité par les événements qui lui correspondent
	for p in gs.party:
		var ps: Dictionary = (led.ps as Dictionary).get(str(p.id), {})
		if ps.is_empty() and float(led.hp_min) > 0.25:
			continue
		for t in p.get("talents", []):
			var key2 := LivingCatalog.key(str(p.id), str(t.id))
			var opt := LivingCatalog.talent_option(gs.cfg, str(t.id))
			var kind := LivingCatalog.passive_kind(opt)
			var pts := 0.0
			match kind:
				"p_focus":
					pts = float(int(ps.get("crit", 0))) * 0.6 + minf(3.0, float(int(ps.get("melee", 0))) * 0.2)
				"p_ancre":
					pts = minf(3.0, float(int(ps.get("hit", 0))) * 0.25) + (1.0 if _party_low_ever(led) else 0.0)
				"p_souffle":
					pts = (2.0 if float(led.hp_min) <= 0.25 and int(p.hp) > 0 else 0.0) + minf(1.5, float(int(ps.get("low", 0))) * 0.5)
				"p_veine":
					pts = minf(3.0, float(int(ps.get("steal", 0))) / 8.0)
				"p_sens":
					pts = minf(3.0, float(int(ps.get("spell", 0))) * 0.4)
			if pts <= 0.0:
				continue
			var sk2 := _sk(gs, key2)
			var g2 := clampf(pts * w, 0.0, 3.0)      # les passifs gagnent moins par combat que les sorts
			var b2 := tier(float(sk2.a))
			sk2.a = clampf(float(sk2.a) + g2, 0.0, 100.0)
			sk2.u = cb
			var tkey: String = {"p_focus": "agg", "p_ancre": "loy", "p_souffle": "pru", "p_veine": "loy", "p_sens": "agg"}.get(kind, "pru")
			sk2.t[tkey] = mini(60, int(sk2.t.get(tkey, 0)) + (1 if g2 >= 1.0 else 0))
			if tier(float(sk2.a)) > b2:
				_say(gs, "tier", key2, [str(opt.get("labelFr", ""))])
				push_news(gs, key2, "tier", tier(float(sk2.a)))
			if int(sk2.o) == 0 and float(sk2.a) >= EVOLVE_AFF and not available_branches(gs, str(p.id), str(t.id)).is_empty():
				sk2.o = 1
				push_news(gs, key2, "evo", tier(float(sk2.a)))
				_say(gs, "evo", key2, [str(opt.get("labelFr", ""))])
				_fragment(gs, 1)
	# instincts : traits dérivent peu
	# relations
	var rels: Dictionary = st.rel
	for pk in (led.pairs as Dictionary).keys():
		if not rels.has(pk) and rels.size() >= REL_MAX:
			continue
		var r: Dictionary = rels.get_or_add(pk, {"v": 0})
		var l0 := rel_level(gs, str(pk).split("~")[0], str(pk).split("~")[1])
		r.v = int(r.v) + 1
		var l1 := rel_level(gs, str(pk).split("~")[0], str(pk).split("~")[1])
		if l1 > l0:
			var pr := str(pk).split("~")
			var na := str(LivingCatalog.profile(gs.cfg, pr[0].split("|")[1]).get("name", ""))
			var nb := str(LivingCatalog.profile(gs.cfg, pr[1].split("|")[1]).get("name", ""))
			_say(gs, "relation", pr[0], [na, nb])
			_fragment(gs, l1)
	# étiolement : les compétences délaissées s'attiédissent lentement
	for key3 in st.sk.keys():
		var sk3: Dictionary = st.sk[key3]
		if cb - int(sk3.u) > DECAY_AFTER and float(sk3.a) > 0.0 and cb % 3 == 0:
			sk3.a = maxf(0.0, float(sk3.a) - 0.5)
	if outcome == "win" and bool(led.boss):
		_fragment(gs, 1)
	st.led = {}

static func _has_detail(mems: Array, kind: String, detail: String) -> bool:
	for m in mems:
		if str(m[0]) == kind and str(m[1]) == detail:
			return true
	return false

static func _party_low_ever(led: Dictionary) -> bool:
	return float(led.hp_min) < 0.35

## Dérive des traits d'une compétence d'après ce qu'elle a vécu pendant le combat (plafond TRAIT_CAP_COMBAT).
static func _drift(gs: GameState, key: String, skill_id: String, ls: Dictionary, saves: int, outcome: String) -> void:
	var prof := LivingCatalog.profile(gs.cfg, skill_id)
	if prof.is_empty():
		return
	var sk := _sk(gs, key)
	var fam := str(prof.family)
	var d: Dictionary = {}
	var add := func(t: String, n: int):
		if (prof.traits as Dictionary).has(t):
			d[t] = int(d.get(t, 0)) + n
	match fam:
		"offense", "technique":
			add.call("agg", mini(3, int(ls.kills) + (2 if int(ls.boss) > 0 else 0)))
			if int(ls.risk) > 0:
				add.call("ins", mini(2, int(ls.risk)))
				add.call("agg", 1)
			if int(ls.safe) > 1:
				add.call("pru", 1)
			var share := 0.0
			var cid := key.split("|")[0]
			if int(_led(gs).dmg_total) > 0:
				share = float(int(_led(gs).dmg_by.get(cid, 0))) / float(_led(gs).dmg_total)
			if share >= 0.6 and gs.party.size() > 1:
				add.call("ind", 1)
		"soin", "defense":
			add.call("pro", mini(4, int(ls.low) * 2 + (1 if int(ls.heal) > 0 or int(ls.c) > 0 else 0)))
			add.call("loy", mini(3, saves * 2))
			if int(ls.self) > 0:
				add.call("pru", 1)
			if int(ls.risk) > 0:
				add.call("ins", 1)
		"controle":
			add.call("pru", mini(2, int(ls.stat)))
			add.call("ind", 1 if int(ls.boss) > 0 else 0)
			add.call("cur", mini(2, (ls.mon as Dictionary).size()))
		"soutien":
			add.call("cur", mini(2, (ls.mon as Dictionary).size()) + (1 if int(ls.c) > 0 and (_led(gs).mon as Array).size() > 1 else 0))
			add.call("loy", mini(2, int(ls.party)))
			add.call("pru", 1 if int(ls.safe) > 0 else 0)
		"instinct":
			add.call("pru", 1 if int(ls.c) > 0 else 0)
			add.call("cur", 1 if int(ls.dmg) > int(ls.c) else 0)
			add.call("loy", 1 if int(ls.c) > 1 else 0)
	if outcome == "flee":
		for t in d.keys():
			d[t] = maxi(0, int(d[t]) - 1)
	var budget := TRAIT_CAP_COMBAT
	for t in d.keys():
		var n := mini(int(d[t]), budget)
		budget -= n
		if n > 0:
			(sk.t as Dictionary)[t] = mini(60, int(sk.t.get(t, 0)) + n)

# ------------------------------------------------------------------ évolutions, pactes, lore

## Évolutions qu'une compétence peut éveiller maintenant : affinité suffisante, trait associé dominant (≥ TRAIT_MIN), pas déjà éveillée.
static func available_branches(gs: GameState, char_id: String, skill_id: String) -> Array:
	var out: Array = []
	var s: Dictionary = state(gs).sk.get(LivingCatalog.key(char_id, skill_id), {})
	var a := float(s.get("a", 0.0))
	var have := evos_of(gs, char_id, skill_id)
	# premier emplacement dès « attachée » (25), second dès « liée » (50) ; au plus deux évolutions
	if have.size() >= 2 or a < (EVOLVE_AFF if have.is_empty() else LINK_AFF):
		return out
	var prof := LivingCatalog.profile(gs.cfg, skill_id)
	var tr := traits(gs, char_id, skill_id)
	for b in prof.get("branches", []):
		if int(tr.get(str(b.trait), 0)) >= TRAIT_MIN and not have.has(str(b.kind)):
			out.append(str(b.kind))
	return out

## Éveille une évolution (irréversible). Renvoie "" si réussi, sinon le motif.
static func evolve(gs: GameState, char_id: String, skill_id: String, kind: String) -> String:
	if not active(gs):
		return L.t("ui.living.err_off")
	if not available_branches(gs, char_id, skill_id).has(kind):
		return L.t("ui.living.err_not_available")
	var sk := _sk(gs, LivingCatalog.key(char_id, skill_id))
	if str(sk.get("e", "")) == "":
		sk.e = kind
	else:
		sk["e2"] = kind
	var c := gs.char_by_id(char_id)
	var prof := LivingCatalog.profile(gs.cfg, skill_id)
	gs.add_log(L.fa(L.t("ui.living.log_evolve"), [c.get("name", ""), prof.get("name", ""), L.t("ui.living.k_%s_n" % kind)]))
	_fragment(gs, 2)
	return ""

## Pacte d'apaisement : l'or calme une compétence instable (instabilité −15, recommence à zéro l'humeur). Renvoie "" si réussi.
static func appease_cost(gs: GameState, c: Dictionary) -> int:
	return 20 + 5 * int(c.get("level", 1))

static func appease(gs: GameState, char_id: String, skill_id: String) -> String:
	if not active(gs):
		return L.t("ui.living.err_off")
	var c := gs.char_by_id(char_id)
	var key := LivingCatalog.key(char_id, skill_id)
	var sk := _sk(gs, key)
	var cost := appease_cost(gs, c)
	if int(traits(gs, char_id, skill_id).get("ins", 0)) < 20:
		return L.t("ui.living.err_calm")
	if gs.gold < cost:
		return L.t("ui.living.err_gold")
	gs.gold -= cost
	sk.t["ins"] = int(sk.t.get("ins", 0)) - 15
	gs.add_log(L.fa(L.t("ui.living.log_appease"), [LivingCatalog.profile(gs.cfg, skill_id).get("name", ""), cost]))
	return ""

## Fragments d'une ancienne conscience (lore) : le total grandit avec les événements marquants ; chaque seuil de LORE_AT révèle une ligne du carnet.
static func _fragment(gs: GameState, n: int) -> void:
	var st := state(gs)
	var before := int(st.fr)
	st.fr = before + n
	for i in LORE_AT.size():
		if before < int(LORE_AT[i]) and int(st.fr) >= int(LORE_AT[i]):
			(st.log as Array).append(i)
			var txt := L.t("ui.living.lore_%d" % (i + 1))
			GameState.living_log(gs, MARK + txt + " »")

static func lore_unlocked(gs: GameState) -> int:
	return (state(gs).log as Array).size()

## Fiche complète pour le panneau de détails.
static func describe(gs: GameState, char_id: String, skill_id: String) -> Dictionary:
	var key := LivingCatalog.key(char_id, skill_id)
	var s: Dictionary = state(gs).sk.get(key, {})
	var prof := LivingCatalog.profile(gs.cfg, skill_id)
	var a := float(s.get("a", 0.0))
	return {"key": key, "profile": prof, "affinity": a, "tier": tier(a), "traits": traits(gs, char_id, skill_id), "dominant": dominant(gs, char_id, skill_id),
		"memories": (s.get("m", []) as Array).duplicate(true), "evolved": str(s.get("e", "")), "evolved2": str(s.get("e2", "")), "available": available_branches(gs, char_id, skill_id),
		"relations": relations_of(gs, key), "mood": int(traits(gs, char_id, skill_id).get("ins", 0)) >= MOOD_INS, "uses": int(s.get("c", 0))}

## Nom lisible d'un monstre (cherché dans tous les niveaux), à défaut son identifiant.
static func monster_name(gs: GameState, mon_id: String) -> String:
	for lv in gs.cfg.get("levels", []):
		for m in lv.get("monsters", []):
			if str(m.id) == mon_id:
				return str(m.get("name", mon_id))
	return mon_id

## Texte d'un souvenir pour la fiche : [type, détail, nombre].
static func memory_text(gs: GameState, m: Array) -> String:
	var kind := str(m[0])
	var detail := str(m[1])
	if kind == "saved":
		detail = str(gs.char_by_id(detail).get("name", detail))
	elif kind != "env":
		detail = monster_name(gs, detail)
	var txt := L.fa(L.t("ui.living.mem_%s" % kind), detail)
	return txt + (" ×%d" % int(m[2]) if int(m[2]) > 1 else "")

## Nom lisible d'une clé « héros|compétence ».
static func key_name(gs: GameState, key: String) -> String:
	var parts := key.split("|")
	var prof := LivingCatalog.profile(gs.cfg, parts[1])
	return "%s (%s)" % [prof.get("name", parts[1]), gs.char_by_id(parts[0]).get("name", parts[0])]

