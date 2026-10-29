class_name SpellTip
extends PanelContainer
## Infobulle de sort (nom + fiche technique), affichée au-dessus d'un bouton. Port de showCardSpellTip.

static var _inst: SpellTip
static var _layer: CanvasLayer

var _label: RichTextLabel

static func lines(spell: Dictionary, caster: Dictionary = {}) -> Array[String]:
	var mode := str(spell.get("mode", "damage"))
	var sb: Dictionary = Stats.spell_bonus(caster, mode) if not caster.is_empty() else {"total": 0}
	var add := int(sb.total)
	var mode_label := L.t("common.degats")
	match mode:
		"healSingle": mode_label = L.t("common.soin_sur_un_allie")
		"healParty": mode_label = L.t("common.soin_de_groupe")
		"staminaRestoreSingle": mode_label = L.t("common.restauration_endurance_sur_un")
		"damageGroup": mode_label = L.t("common.degats_de_zone_tout_le")
		"shieldSingle": mode_label = L.t("common.bouclier_sur_un_allie")
		"dispelSingle": mode_label = L.t("common.purification_un_allie")
	var value := ""
	if mode == "healSingle" or mode == "healParty":
		value = L.fa(L.t("ui.spell_tip.soin_pv"), [int(spell.get("healMin", 0)) + add, int(spell.get("healMax", 0)) + add])
	elif mode == "staminaRestoreSingle":
		value = L.fa(L.t("ui.spell_tip.endurance_restauree"), [int(spell.get("staminaMin", 0)) + add, int(spell.get("staminaMax", 0)) + add])
	elif mode == "damage" or mode == "damageGroup":
		value = L.fa(L.t("ui.spell_tip.degats"), [int(spell.get("dmgMin", 0)) + add, int(spell.get("dmgMax", 0)) + add])
		if mode == "damageGroup":
			value += L.t("ui.spell_tip.par_cible_touchee")
		if bool(spell.get("ignoreAllResist", false)):
			value += L.t("ui.spell_tip.ignore_toute_resistance")
	var out: Array[String] = ["Type : " + mode_label]
	if value != "":
		out.append(value)
	if mode == "shieldSingle":
		out.append(L.fa(L.t("ui.spell_tip.bouclier_points"), [int(spell.get("shieldMin", 0)) + add, int(spell.get("shieldMax", 0)) + add]))
	if not caster.is_empty():
		var lo := 0
		var hi := 0
		match mode:
			"healSingle", "healParty": lo = int(spell.get("healMin", 0)); hi = int(spell.get("healMax", 0))
			"staminaRestoreSingle": lo = int(spell.get("staminaMin", 0)); hi = int(spell.get("staminaMax", 0))
			"shieldSingle": lo = int(spell.get("shieldMin", 0)); hi = int(spell.get("shieldMax", 0))
			"damage", "damageGroup": lo = int(spell.get("dmgMin", 0)); hi = int(spell.get("dmgMax", 0))
		if hi > 0:
			out.append(L.fa(L.t("ui.spell_tip.base_plus"), [lo, hi, add, lo + add, hi + add]))
		if mode == "shieldSingle" or mode == "staminaRestoreSingle":
			out.append(L.t("ui.spell_tip.int_seule"))
	if not caster.is_empty() and add > 0:
		out.append(L.fa(L.t("ui.spell_tip.puissance_lanceur"), [str(caster.get("name", "")), add, int(sb.power), int(sb.gear), int(sb.level)]))
	if (mode == "damage" or mode == "damageGroup") and not bool(spell.get("ignoreAllResist", false)):
		out.append(L.t("ui.spell_tip.reduit_par_cible"))
	if int(spell.get("spellLifestealPct", 0)) > 0:
		out.append(L.fa(L.t("ui.spell_tip.vol_de_vie_des_degats"), int(spell.spellLifestealPct)))
	var se := str(spell.get("statusEffect", ""))
	if se != "" and not Statuses.def(se).is_empty():
		var sd := Statuses.def(se)
		var extra := " · %d/tour" % int(spell.statusPower) if int(spell.get("statusPower", 0)) > 0 else ""
		out.append(L.fa(L.t("ui.spell_tip.effet_de_statut_tour"), [sd.get("icon", ""), sd.get("label", se), int(spell.get("statusChance", 0)), int(spell.get("statusDuration", 0)), extra]))
	if bool(spell.get("ultimate", false)):
		var desc := str(spell.get("descEn" if Data.lang == "en" else "descFr", ""))
		if desc != "":
			out.append(desc)
		var hits := int(spell.get("hits", 1))
		if hits > 1:
			out.append(L.fa(L.t("ui.spell_tip.ultime_frappes"), hits))
		if not caster.is_empty():
			var mx := float(Characters.ult_cfg(Data.config).max)
			out.append(L.fa(L.t("ui.spell_tip.ultime_jauge"), [int(round(Characters.ult_charge(caster) / mx * 100.0))]))
		else:
			out.append(L.t("ui.spell_tip.ultime_sans_cout"))
		return out
	out.append(L.fa(L.t("ui.spell_tip.endurance_recharge_ds"), [int(spell.get("staminaCost", 15)), int(spell.get("cooldownSec", 6))]))
	return out

static func _inst_for(host: Control) -> SpellTip:
	if _inst == null or not is_instance_valid(_inst):
		_inst = SpellTip.new()
		_inst.name = "SpellTip"
		_inst.visible = false
		_inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inst.z_index = 4000
		_inst.add_theme_stylebox_override("panel", FloatingTip.TipBox.new())
		_inst._label = RichTextLabel.new()
		_inst._label.bbcode_enabled = true
		_inst._label.fit_content = true
		_inst._label.scroll_active = false
		_inst._label.custom_minimum_size = Vector2(260, 0)
		_inst._label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inst._label.add_theme_font_override("normal_font", UiTheme.font(UiTheme.F_BODY))
		_inst._label.add_theme_font_override("bold_font", UiTheme.font(UiTheme.F_TITLE_BOLD))
		_inst._label.add_theme_color_override("default_color", Color("efe1c2"))
		_inst._label.add_theme_font_size_override("normal_font_size", 14)
		_inst._label.add_theme_font_size_override("bold_font_size", 15)
		_inst.add_child(_inst._label)
		# couche dédiée : sans elle l'infobulle serait dessinée SOUS les CanvasLayer de l'interface
		_layer = CanvasLayer.new()
		_layer.name = "SpellTipLayer"
		_layer.layer = 210
		_layer.add_child(_inst)
		host.get_tree().root.add_child(_layer)
	return _inst

static func show_for(host: Control, spell: Dictionary, remaining_sec: int = 0, caster: Dictionary = {}) -> void:
	var t := _inst_for(host)
	var txt := "[b][color=#e8b45c]%s[/color][/b]\n%s" % [str(spell.get("name", "")), "\n".join(lines(spell, caster))]
	if remaining_sec > 0:
		txt += L.fa(L.t("ui.spell_tip.pret_dans_ds"), remaining_sec)
	t._label.text = txt
	t.size = Vector2.ZERO
	t.visible = true
	await host.get_tree().process_frame
	if not is_instance_valid(t) or not is_instance_valid(host):
		return
	var r := host.get_global_rect()
	var vs := host.get_viewport().get_visible_rect().size
	var x := clampf(r.position.x + r.size.x * 0.5 - t.size.x * 0.5, 4.0, maxf(4.0, vs.x - t.size.x - 4.0))
	var y := r.position.y - t.size.y - 6.0
	if y < 4.0:
		y = r.end.y + 6.0
	t.position = Vector2(x, y)

## Infobulle de l'attaque de base du héros : dégâts, critique, vol de vie, endurance (sans les touches du clavier).
static func show_attack(host: Control, caster: Dictionary, attack_cost: int) -> void:
	if caster.is_empty():
		return
	var t := _inst_for(host)
	var ls: Array[String] = [L.fa(L.t("ui.spell_tip.degats"), [int(caster.get("atkMin", 0)), int(caster.get("atkMax", 0))]),
		L.fa(L.t("ui.spell_tip.attaque_crit"), Stats.crit_total(caster))]
	var ls_pct := int(caster.get("talentLifestealPct", 0)) + int(caster.get("perkLifesteal", 0))
	if ls_pct > 0:
		ls.append(L.fa(L.t("ui.spell_tip.vol_de_vie_des_degats"), ls_pct))
	ls.append(L.t("ui.spell_tip.reduit_par_cible"))
	ls.append(L.fa(L.t("ui.spell_tip.attaque_endurance"), attack_cost))
	t._label.text = "[b][color=#e8b45c]%s[/color][/b]\n%s" % [L.t("ui.spell_tip.attaque_base"), "\n".join(ls)]
	t.size = Vector2.ZERO
	t.visible = true
	await host.get_tree().process_frame
	if not is_instance_valid(t) or not is_instance_valid(host):
		return
	var r := host.get_global_rect()
	var vs := host.get_viewport().get_visible_rect().size
	var x := clampf(r.position.x + r.size.x * 0.5 - t.size.x * 0.5, 4.0, maxf(4.0, vs.x - t.size.x - 4.0))
	var y := r.position.y - t.size.y - 6.0
	if y < 4.0:
		y = r.end.y + 6.0
	t.position = Vector2(x, y)

## Infobulle du disque d'ultime verrouillé (héros de classe de base).
static func show_locked(host: Control) -> void:
	var t := _inst_for(host)
	t._label.text = "[b][color=#e8b45c]%s[/color][/b]\n%s" % [L.t("ui.spell_tip.ultime_titre"), L.t("ui.spell_tip.ultime_verrouille")]
	t.size = Vector2.ZERO
	t.visible = true
	await host.get_tree().process_frame
	if not is_instance_valid(t) or not is_instance_valid(host):
		return
	var r := host.get_global_rect()
	var vs := host.get_viewport().get_visible_rect().size
	t.position = Vector2(clampf(r.position.x + r.size.x * 0.5 - t.size.x * 0.5, 4.0, maxf(4.0, vs.x - t.size.x - 4.0)), maxf(4.0, r.position.y - t.size.y - 6.0))

static func hide_tip() -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst.visible = false
