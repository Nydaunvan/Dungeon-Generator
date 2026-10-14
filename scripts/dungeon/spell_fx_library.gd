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

## id -> {label (clé de langue), styles, modes, script}. Le premier effet compatible est l'effet par défaut du style.
const CATALOG := {
	"arcane_crystal": {"label": "admin.spells.fx_arcane_crystal", "styles": ["arcane"], "modes": ["damage"], "script": ARCANE_SCRIPT},
	"arcane_orb": {"label": "admin.spells.fx_arcane_orb", "styles": ["arcane"], "modes": ["damage"], "script": ARCANE_SCRIPT},
	"arcane_beam": {"label": "admin.spells.fx_arcane_beam", "styles": ["arcane"], "modes": ["damage"], "script": ARCANE_SCRIPT},
	"fire_ball": {"label": "admin.spells.fx_fire_ball", "styles": ["fire"], "modes": ["damage"], "script": FIRE_SCRIPT},
	"fire_meteor": {"label": "admin.spells.fx_fire_meteor", "styles": ["fire"], "modes": ["damage", "damageGroup"], "script": FIRE_SCRIPT},
	"fire_column": {"label": "admin.spells.fx_fire_column", "styles": ["fire"], "modes": ["damage"], "script": FIRE_SCRIPT},
}

## Effet par défaut de chaque sort d'origine (quand le sort n'en a pas choisi un) ; sinon l'effet par défaut du style.
const SPELL_DEFAULT := {
	"spell_fire1": "fire_ball",
	"spell_elementalist1": "fire_meteor",
	"spell_elementalist3": "fire_column",
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
	var fx := str(ctx.get("fx", CLASSIC))
	if fx != CLASSIC and CATALOG.has(fx) and tier() > 0 and VisualFx.is_forward():
		if _play_custom(host, camera, spell_id, target, ctx, fx):
			return
	SpellFxStyles.cast_spell(host, camera, spell_id, target, ctx)

## Charge le script de l'effet à l'exécution : si ce script ne peut pas se charger, l'effet d'origine prend le relais.
static func _play_custom(host: Node, camera: Camera3D, spell_id: String, target: Dictionary, ctx: Dictionary, fx: String) -> bool:
	var scr := load(str(CATALOG[fx].script)) as GDScript
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
