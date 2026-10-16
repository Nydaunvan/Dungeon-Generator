class_name SpellFxLibrary
extends RefCounted
## Bibliothèque d'effets visuels de sorts. Chaque sort garde son « style » (école de magie : il décide de la logique de combat,
## par exemple magique ou physique) ; l'aspect visuel est un champ à part, `fx`, choisi dans l'éditeur de sorts :
##   - `fx`      : identifiant d'un effet du catalogue, « classic » (l'effet d'origine en sprites) ou vide (= effet par défaut du style) ;
##   - `fxTint`  : teinte (couleur HTML) qui remplace la couleur d'origine de l'effet, vide = couleur d'origine ;
##   - `fxPower` : intensité (0,6 discret … 2 spectaculaire), 1 par défaut.
## Un effet inconnu (créé dans une version plus récente) ou incompatible avec le style / le mode retombe sur l'effet par défaut.
## Les effets du catalogue exigent le rendu Forward+ (Vulkan) et le halo (glow) ; sinon l'effet « classic » joue à la place.

const CLASSIC := "classic"
const ARCANE_SCRIPT := "res://scripts/dungeon/spell_fx_arcane.gd"
const FIRE_SCRIPT := "res://scripts/dungeon/spell_fx_fire.gd"
const ICE_SCRIPT := "res://scripts/dungeon/spell_fx_ice.gd"
const HOLY_SCRIPT := "res://scripts/dungeon/spell_fx_holy.gd"
const SHADOW_SCRIPT := "res://scripts/dungeon/spell_fx_shadow.gd"
const BARD_SCRIPT := "res://scripts/dungeon/spell_fx_bard.gd"
const PHYS_SCRIPT := "res://scripts/dungeon/spell_fx_physical.gd"
const NATURE_SCRIPT := "res://scripts/dungeon/spell_fx_nature.gd"
const MONSTER_SCRIPT := "res://scripts/dungeon/spell_fx_monster.gd"      # capacités lancées par un monstre (contexte « fromMonster »)

## id -> {label (clé de langue), styles, modes, script}. Le premier effet compatible est l'effet par défaut du style.
const CATALOG := {
	"arcane_crystal": {"label": "admin.spells.fx_arcane_crystal", "styles": ["arcane"], "modes": ["damage"], "script": ARCANE_SCRIPT},
	"arcane_orb": {"label": "admin.spells.fx_arcane_orb", "styles": ["arcane"], "modes": ["damage"], "script": ARCANE_SCRIPT},
	"arcane_beam": {"label": "admin.spells.fx_arcane_beam", "styles": ["arcane"], "modes": ["damage"], "script": ARCANE_SCRIPT},
	"fire_ball": {"label": "admin.spells.fx_fire_ball", "styles": ["fire"], "modes": ["damage"], "script": FIRE_SCRIPT},
	"fire_meteor": {"label": "admin.spells.fx_fire_meteor", "styles": ["fire"], "modes": ["damage", "damageGroup"], "script": FIRE_SCRIPT},
	"fire_column": {"label": "admin.spells.fx_fire_column", "styles": ["fire"], "modes": ["damage"], "script": FIRE_SCRIPT},
	"ice_shard": {"label": "admin.spells.fx_ice_shard", "styles": ["ice"], "modes": ["damage"], "script": ICE_SCRIPT},
	"ice_hail": {"label": "admin.spells.fx_ice_hail", "styles": ["ice"], "modes": ["damage"], "script": ICE_SCRIPT},
	"holy_light": {"label": "admin.spells.fx_holy_light", "styles": ["holy"], "modes": ["damage"], "script": HOLY_SCRIPT},
	"holy_smite": {"label": "admin.spells.fx_holy_smite", "styles": ["holy"], "modes": ["damage"], "script": HOLY_SCRIPT},
	"holy_judgment": {"label": "admin.spells.fx_holy_judgment", "styles": ["holy"], "modes": ["damage"], "script": HOLY_SCRIPT},
	"holy_aura": {"label": "admin.spells.fx_holy_aura", "styles": ["holy"], "modes": ["damage"], "script": HOLY_SCRIPT},
	"holy_purify": {"label": "admin.spells.fx_holy_purify", "styles": ["holy"], "modes": ["damage"], "script": HOLY_SCRIPT},
	"holy_anathema": {"label": "admin.spells.fx_holy_anathema", "styles": ["holy"], "modes": ["damage"], "script": HOLY_SCRIPT},
	"heal_soft": {"label": "admin.spells.fx_heal_soft", "styles": ["holy", "bard", "arcane"], "modes": ["healSingle"], "script": HOLY_SCRIPT},
	"heal_haste": {"label": "admin.spells.fx_heal_haste", "styles": ["holy", "bard", "arcane"], "modes": ["healSingle"], "script": HOLY_SCRIPT},
	"heal_blessing": {"label": "admin.spells.fx_heal_blessing", "styles": ["holy", "bard", "arcane"], "modes": ["healSingle"], "script": HOLY_SCRIPT},
	"heal_group": {"label": "admin.spells.fx_heal_group", "styles": ["holy", "bard", "arcane"], "modes": ["healParty"], "script": HOLY_SCRIPT},
	"heal_sanctuary": {"label": "admin.spells.fx_heal_sanctuary", "styles": ["holy", "bard", "arcane"], "modes": ["healParty"], "script": HOLY_SCRIPT},
	"shadow_orb": {"label": "admin.spells.fx_shadow_orb", "styles": ["shadow"], "modes": ["damage", "damageGroup"], "script": SHADOW_SCRIPT},
	"shadow_fatal": {"label": "admin.spells.fx_shadow_fatal", "styles": ["shadow"], "modes": ["damage"], "script": SHADOW_SCRIPT},
	"shadow_drain": {"label": "admin.spells.fx_shadow_drain", "styles": ["shadow"], "modes": ["damage"], "script": SHADOW_SCRIPT},
	"shadow_step": {"label": "admin.spells.fx_shadow_step", "styles": ["shadow"], "modes": ["damage"], "script": SHADOW_SCRIPT},
	"shadow_execute": {"label": "admin.spells.fx_shadow_execute", "styles": ["shadow"], "modes": ["damage"], "script": SHADOW_SCRIPT},
	"shadow_blade": {"label": "admin.spells.fx_shadow_blade", "styles": ["shadow"], "modes": ["damage"], "script": SHADOW_SCRIPT},
	"shadow_ambush": {"label": "admin.spells.fx_shadow_ambush", "styles": ["shadow"], "modes": ["damage"], "script": SHADOW_SCRIPT},
	"shadow_flurry": {"label": "admin.spells.fx_shadow_flurry", "styles": ["shadow"], "modes": ["damage"], "script": SHADOW_SCRIPT},
	"shadow_curse": {"label": "admin.spells.fx_shadow_curse", "styles": ["shadow"], "modes": ["damage"], "script": SHADOW_SCRIPT},
	"shadow_pact": {"label": "admin.spells.fx_shadow_pact", "styles": ["shadow"], "modes": ["damage"], "script": SHADOW_SCRIPT},
	"shadow_apocalypse": {"label": "admin.spells.fx_shadow_apocalypse", "styles": ["shadow"], "modes": ["damage", "damageGroup"], "script": SHADOW_SCRIPT},
	"bard_pierce": {"label": "admin.spells.fx_bard_pierce", "styles": ["bard"], "modes": ["damage"], "script": BARD_SCRIPT},
	"bard_breath": {"label": "admin.spells.fx_bard_breath", "styles": ["bard"], "modes": ["staminaRestoreSingle", "healSingle"], "script": BARD_SCRIPT},
	"bard_armor": {"label": "admin.spells.fx_bard_armor", "styles": ["bard"], "modes": ["shieldSingle"], "script": BARD_SCRIPT},
	"bard_warcry": {"label": "admin.spells.fx_bard_warcry", "styles": ["bard"], "modes": ["damageGroup", "damage"], "script": BARD_SCRIPT},
	"bard_epic": {"label": "admin.spells.fx_bard_epic", "styles": ["bard"], "modes": ["selfBuff"], "script": BARD_SCRIPT},
	"bard_lullaby": {"label": "admin.spells.fx_bard_lullaby", "styles": ["bard"], "modes": ["sleepGroup"], "script": BARD_SCRIPT},
	"bard_ballad": {"label": "admin.spells.fx_bard_ballad", "styles": ["bard"], "modes": ["shieldSingle"], "script": BARD_SCRIPT},
	"bard_requiem": {"label": "admin.spells.fx_bard_requiem", "styles": ["bard"], "modes": ["partyUtility", "healParty"], "script": BARD_SCRIPT},
	"bard_dispel": {"label": "admin.spells.fx_bard_dispel", "styles": ["bard"], "modes": ["dispelSingle"], "script": BARD_SCRIPT},
	"phys_power": {"label": "admin.spells.fx_phys_power", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_archer": {"label": "admin.spells.fx_phys_archer", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_sneak": {"label": "admin.spells.fx_phys_sneak", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_rage": {"label": "admin.spells.fx_phys_rage", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_frenzy": {"label": "admin.spells.fx_phys_frenzy", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_decisive": {"label": "admin.spells.fx_phys_decisive", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_fury": {"label": "admin.spells.fx_phys_fury", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_discord": {"label": "admin.spells.fx_phys_discord", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_lowblow": {"label": "admin.spells.fx_phys_lowblow", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_poison": {"label": "admin.spells.fx_phys_poison", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_crusader": {"label": "admin.spells.fx_phys_crusader", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_dance": {"label": "admin.spells.fx_phys_dance", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_whirl": {"label": "admin.spells.fx_phys_whirl", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_step": {"label": "admin.spells.fx_phys_step", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"phys_deadly": {"label": "admin.spells.fx_phys_deadly", "styles": ["physical"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"arcane_slow": {"label": "admin.spells.fx_arcane_slow", "styles": ["arcane"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"arcane_arrow": {"label": "admin.spells.fx_arcane_arrow", "styles": ["arcane"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"arcane_volley": {"label": "admin.spells.fx_arcane_volley", "styles": ["arcane"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"arcane_stars": {"label": "admin.spells.fx_arcane_stars", "styles": ["arcane"], "modes": ["damage"], "script": PHYS_SCRIPT},
	"nature_thorn": {"label": "admin.spells.fx_nature_thorn", "styles": ["nature"], "modes": ["damage"], "script": NATURE_SCRIPT},
	"nature_vines": {"label": "admin.spells.fx_nature_vines", "styles": ["nature"], "modes": ["damage"], "script": NATURE_SCRIPT},
	"nature_lightning": {"label": "admin.spells.fx_nature_lightning", "styles": ["nature"], "modes": ["damage"], "script": NATURE_SCRIPT},
	"nature_swarm": {"label": "admin.spells.fx_nature_swarm", "styles": ["nature"], "modes": ["damage", "damageGroup"], "script": NATURE_SCRIPT},
	"nature_bloom": {"label": "admin.spells.fx_nature_bloom", "styles": ["nature", "holy", "bard", "arcane"], "modes": ["healSingle"], "script": NATURE_SCRIPT},
	"nature_grove": {"label": "admin.spells.fx_nature_grove", "styles": ["nature", "holy", "bard", "arcane"], "modes": ["healParty"], "script": NATURE_SCRIPT},
}

## Effet par défaut de chaque sort d'origine (quand le sort n'en a pas choisi un) ; sinon l'effet par défaut du style.
const SPELL_DEFAULT := {
	"spell_fire1": "fire_ball",
	"spell_elementalist1": "fire_meteor",
	"spell_elementalist3": "fire_column",
	"spell_frost1": "ice_shard",
	"spell_elementalist2": "ice_hail",
	"spell_holy1": "holy_light",
	"spell_paladin1": "holy_smite",
	"spell_crusader1": "holy_judgment",
	"spell_paladin2": "holy_aura",
	"spell_cleric3": "holy_purify",
	"spell_crusader3": "holy_anathema",
	"spell_heal1": "heal_soft",
	"spell_haste1": "heal_haste",
	"spell_cleric2": "heal_blessing",
	"spell_heal2": "heal_group",
	"spell_cleric4": "heal_sanctuary",
	"spell_assassin1": "shadow_fatal",
	"spell_warlock1": "shadow_drain",
	"spell_thief3": "shadow_step",
	"spell_thief4": "shadow_execute",
	"spell_assassin2": "shadow_blade",
	"spell_assassin3": "shadow_ambush",
	"spell_assassin4": "shadow_flurry",
	"spell_warlock2": "shadow_curse",
	"spell_warlock3": "shadow_pact",
	"spell_warlock4": "shadow_apocalypse",
	"spell_bard1": "bard_breath",
	"spell_bard2": "bard_pierce",
	"spell_skald2": "bard_armor",
	"spell_skald3": "bard_warcry",
	"spell_skald4": "bard_epic",
	"spell_minstrel1": "bard_lullaby",
	"spell_minstrel2": "bard_ballad",
	"spell_minstrel3": "bard_requiem",
	"spell_minstrel4": "bard_dispel",
	"spell_warrior1": "phys_power",
	"spell_archer1": "phys_archer",
	"spell_rogue1": "phys_sneak",
	"spell_berserker1": "phys_rage",
	"spell_berserker2": "phys_frenzy",
	"spell_berserker3": "phys_decisive",
	"spell_berserker4": "phys_fury",
	"spell_skald1": "phys_discord",
	"spell_thief1": "phys_lowblow",
	"spell_thief2": "phys_poison",
	"spell_crusader2": "phys_crusader",
	"spell_bladedancer1": "phys_dance",
	"spell_bladedancer2": "phys_whirl",
	"spell_bladedancer3": "phys_step",
	"spell_bladedancer4": "phys_deadly",
	"spell_slow1": "arcane_slow",
	"spell_magearcher1": "arcane_arrow",
	"spell_magearcher2": "arcane_volley",
	"spell_magearcher3": "arcane_stars",
	"spell_nature1": "nature_thorn",
	"spell_nature2": "nature_vines",
	"spell_nature3": "nature_lightning",
	"spell_nature4": "nature_swarm",
	"spell_nature5": "nature_bloom",
	"spell_nature6": "nature_grove",
}

## Teintes proposées dans l'éditeur : [couleur, clé de langue]. La teinte tourne les couleurs de l'effet en gardant ses nuances.
const TINTS := [
	["", "admin.spells.teinte_defaut"],
	["#4f8cff", "admin.spells.teinte_bleu"],
	["#3ee0ff", "admin.spells.teinte_cyan"],
	["#4be07a", "admin.spells.teinte_vert"],
	["#ffc83a", "admin.spells.teinte_or"],
	["#ff5a4a", "admin.spells.teinte_rouge"],
	["#ff6fb5", "admin.spells.teinte_rose"],
]

## Intensités proposées : [valeur, clé de langue].
const POWERS := [
	[0.6, "admin.spells.intensite_discrete"],
	[1.0, "admin.spells.intensite_normale"],
	[1.5, "admin.spells.intensite_intense"],
	[2.0, "admin.spells.intensite_spectaculaire"],
]

static func _fits(id: String, style: String, mode: String) -> bool:
	var e: Dictionary = CATALOG[id]
	return (e.styles as Array).has(style) and (e.modes as Array).has(mode)

static func _norm_style(spell: Dictionary) -> String:
	var style := str(spell.get("style", "arcane"))
	return "arcane" if style == "" else style

static func _norm_mode(spell: Dictionary) -> String:
	var mode := str(spell.get("mode", "damage"))
	return "damage" if mode == "" else mode

## Effets proposés pour ce style et ce mode : [[id, libellé]], l'effet « Classique » en dernier.
static func options(style: String, mode: String) -> Array:
	var out: Array = []
	for id in CATALOG:
		if _fits(id, style, mode):
			out.append([id, L.t(str(CATALOG[id].label))])
	out.append([CLASSIC, L.t("admin.spells.fx_classique")])
	return out

static func default_for(style: String, mode: String) -> String:
	for id in CATALOG:
		if _fits(id, style, mode):
			return id
	return CLASSIC

## Effet réellement joué pour ce sort (valeur enregistrée si valide, sinon effet par défaut du style).
static func resolve(spell: Dictionary) -> String:
	var fx := str(spell.get("fx", ""))
	if fx == CLASSIC:
		return CLASSIC
	if CATALOG.has(fx) and _fits(fx, _norm_style(spell), _norm_mode(spell)):
		return fx
	var own := str(SPELL_DEFAULT.get(str(spell.get("id", "")), ""))
	if own != "" and CATALOG.has(own) and _fits(own, _norm_style(spell), _norm_mode(spell)):
		return own
	return default_for(_norm_style(spell), _norm_mode(spell))

## Clés d'effet à ajouter au contexte d'un sort lancé.
static func fx_keys(spell: Dictionary) -> Dictionary:
	return {"fx": resolve(spell), "fxTint": str(spell.get("fxTint", "")), "fxPower": float(spell.get("fxPower", 1.0))}

## Contexte complet d'un sort (aperçu de l'éditeur, outils).
static func ctx_for(spell: Dictionary) -> Dictionary:
	var ctx := {"style": _norm_style(spell), "mode": _norm_mode(spell), "status": str(spell.get("statusEffect", "")),
		"targets": [], "ally": 0, "caster": 0}
	ctx.merge(fx_keys(spell))
	return ctx

## Palier de qualité des effets avancés, d'après les options graphiques :
## 0 = effet d'origine (sans halo) · 1 = particules GPU et halo · 2 = + lumières, brume éclairée, décalque au sol · 3 = + distorsion de l'écran.
static func tier() -> int:
	if not bool(Settings.opt("fx_glow")):
		return 0
	var t := 1
	if bool(Settings.opt("spell_lamps")):
		t = 2
		if float(Settings.opt("particles")) >= 1.25:
			t = 3
	return t

## Joue l'effet d'un sort : effet du catalogue si possible, sinon effet d'origine (SpellFxStyles).
static func cast(host: Node, camera: Camera3D, spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	if camera == null:
		return
	if bool(ctx.get("fromMonster", false)):
		# capacité d'un monstre : `target` est le monstre, `ctx.victim` la place du héros visé. Pas d'effet d'origine pour ce sens de tir
		# (celui des héros va vers les monstres) : sans rendu avancé, seule l'animation du coup reçu joue.
		if tier() > 0 and VisualFx.is_forward():
			_play_script(host, camera, spell_id, target, ctx, MONSTER_SCRIPT)
		return
	var fx := str(ctx.get("fx", CLASSIC))
	if fx != CLASSIC and CATALOG.has(fx) and tier() > 0 and VisualFx.is_forward():
		if _play_script(host, camera, spell_id, target, ctx, str(CATALOG[fx].script)):
			return
	SpellFxStyles.cast_spell(host, camera, spell_id, target, ctx)

## Charge le script de l'effet à l'exécution : si ce script ne peut pas se charger, l'effet d'origine prend le relais.
static func _play_script(host: Node, camera: Camera3D, spell_id: String, target: Dictionary, ctx: Dictionary, script_path: String) -> bool:
	var scr := load(script_path) as GDScript
	if scr == null or not scr.can_instantiate():
		return false
	var node = scr.new()
	var fxn := node as SpellFx3D
	if fxn == null:
		if node is Node:
			(node as Node).queue_free()
		return false
	fxn.name = "SpellFx"
	fxn.cam = camera
	host.add_child(fxn)
	fxn.call("play", spell_id, target, ctx)
	fxn._started = true
	return true
