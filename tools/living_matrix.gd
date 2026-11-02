extends Node
## Matrice d'audit des compétences vivantes : écrit docs/LIVING_SKILLS_MATRIX.md (classe, nom, identifiant, type, effet actuel, comportement vivant,
## tempéraments de naissance, évolutions, accords) à partir des DONNÉES RÉELLES du jeu, puis vérifie la couverture.
## Lancer : godot --headless --path . res://tools/living_matrix.tscn

const FAMILY_TXT := {
	"offense": "Sort de dégâts magiques : s'attache à qui l'emploie pour achever, oser ou ménager ; évolutions de ciblage et de risque.",
	"technique": "Geste physique : le savoir-faire se grave, évolutions de ciblage (brutes, groupes, cibles blessées) et de prudence.",
	"soin": "Soin : s'attache aux compagnons sauvés ; évolutions de secours (en danger), de sacrifice, de prévention, d'attachement.",
	"defense": "Bouclier : se tisse autour des plus fragiles ; évolutions de garde, de réaction et de rempart.",
	"controle": "Contrôle (sommeil, purification) : gagne en durée ou en ruse selon la patience ou l'audace de son porteur.",
	"soutien": "Soutien (chants, endurance, buffs) : se souvient des adversaires et des alliés ; évolutions de mémoire, de relais, de veille.",
	"passif": "Talent de classe : crédité par ce qu'il facilite (critiques, coups reçus, chutes évitées, vol de vie, sorts) ; évolution propre à son orientation.",
	"instinct": "Instinct de survie de la famille de classe : s'affine à chaque réflexe réussi ; évolutions de vigilance ou d'écho (jauge d'ultime).",
}

func _effect(sp: Dictionary) -> String:
	var m := str(sp.get("mode", ""))
	var st := str(sp.get("style", ""))
	var s := "%s · %s" % [m, st]
	if sp.has("dmgMin"):
		s += " · %d-%d dégâts" % [int(sp.dmgMin), int(sp.get("dmgMax", sp.dmgMin))]
	if sp.has("healMin"):
		s += " · soin %d-%d" % [int(sp.healMin), int(sp.get("healMax", sp.healMin))]
	if sp.has("shieldMin"):
		s += " · bouclier %d-%d" % [int(sp.shieldMin), int(sp.get("shieldMax", sp.shieldMin))]
	if str(sp.get("statusEffect", "")) != "":
		s += " · statut " + str(sp.statusEffect)
	if bool(sp.get("ultimate", false)):
		s += " · ULTIME (jauge)"
	else:
		s += " · %d endurance / %d s" % [int(sp.get("staminaCost", 0)), int(sp.get("cooldownSec", 0))]
	return s

func _combos_for(sp: Dictionary) -> String:
	var out: Array = []
	for cid in LivingSkills.COMBOS:
		var cb: Dictionary = LivingSkills.COMBOS[cid]
		if LivingSkills._match(cb.first, sp):
			out.append(L.t("ui.living.combo_%s" % cid) + " (1er)")
		if LivingSkills._match(cb.second, sp):
			out.append(L.t("ui.living.combo_%s" % cid) + " (2e)")
	return ", ".join(out) if not out.is_empty() else "—"

func _row(cfg: Dictionary, classes: String, id: String, kind: String, effect: String) -> String:
	var p := LivingCatalog.profile(cfg, id)
	var tr: Dictionary = p.traits
	var keys: Array = tr.keys()
	keys.sort_custom(func(a, b): return int(tr[a]) > int(tr[b]))
	var top := ", ".join(keys.slice(0, 2).map(func(k): return "%s %d" % [L.t("ui.living.trait_%s" % k), int(tr[k])]))
	var evo := ", ".join((p.branches as Array).map(func(b): return L.t("ui.living.k_%s_n" % b.kind) + " [" + L.t("ui.living.trait_%s" % b.trait) + "]"))
	var sp := {}
	for s in cfg.spells:
		if str(s.id) == id:
			sp = s
	var syn := _combos_for(sp) if not sp.is_empty() else "—"
	return "| %s | %s | `%s` | %s | %s | %s | %s | %s |\n" % [classes, str(p.name).replace("|", "/"), id, p.family, effect.replace("|", "/"), top, evo, syn]

func _ready() -> void:
	Data.set_lang("fr")
	var cfg: Dictionary = (Data.original_config as Dictionary).duplicate(true)
	var all := LivingCatalog.all_skills(cfg)
	var out := "# Compétences vivantes — matrice d'audit\n\n_Générée par `tools/living_matrix.gd` à partir des données réelles du jeu (%d compétences)._\n\n" % all.size()
	out += "## Familles\n\n"
	for f in FAMILY_TXT:
		out += "- **%s** — %s\n" % [f, FAMILY_TXT[f]]
	var cname := {}
	for c in cfg.classes:
		cname[str(c.id)] = str(c.name)
	var rows := {"spell": "", "talent": "", "instinct": ""}
	var counts := {"spell": 0, "talent": 0, "instinct": 0}
	var by_family := {}
	var missing: Array = []
	var head := "| Classe(s) | Nom | Identifiant | Famille | Effet actuel (inchangé) | Tempéraments de naissance | Évolutions possibles | Accords |\n|---|---|---|---|---|---|---|---|\n"
	for e in all:
		var id := str(e.id)
		var p := LivingCatalog.profile(cfg, id)
		if p.is_empty() or (p.branches as Array).is_empty():
			missing.append(id)
			continue
		by_family[p.family] = int(by_family.get(p.family, 0)) + 1
		var cl := ", ".join((e.classes as Array).map(func(x): return cname.get(str(x), str(x))))
		var effect := ""
		match str(e.kind):
			"spell":
				for s in cfg.spells:
					if str(s.id) == id:
						effect = _effect(s)
			"talent":
				var opt := LivingCatalog.talent_option(cfg, id)
				effect = Talents.effect_label(opt.get("effects", {})) + " (niv. %d)" % int(e.get("level", 0))
			"instinct":
				effect = "réflexe de survie de la famille"
		counts[str(e.kind)] += 1
		rows[str(e.kind)] += _row(cfg, cl if cl != "" else "—", id, str(e.kind), effect)
	out += "\n## Couverture\n\n- Sorts : %d · Talents : %d · Instincts : %d · Total : %d\n- Compétences sans profil ou sans évolution : %d %s\n\n" % [counts.spell, counts.talent, counts.instinct, all.size(), missing.size(), str(missing)]
	out += "Par famille : " + ", ".join(by_family.keys().map(func(k): return "%s %d" % [k, by_family[k]])) + "\n\n"
	out += "## Sorts (%d)\n\n%s%s\n## Talents de classe (%d)\n\n%s%s\n## Instincts (%d)\n\n%s%s" % [counts.spell, head, rows.spell, counts.talent, head, rows.talent, counts.instinct, head, rows.instinct]
	var f := FileAccess.open("res://docs/LIVING_SKILLS_MATRIX.md", FileAccess.WRITE)
	f.store_string(out)
	f.close()
	print("matrice : %d compétences, %d manquantes" % [all.size(), missing.size()])
	get_tree().quit(1 if missing.size() > 0 else 0)
