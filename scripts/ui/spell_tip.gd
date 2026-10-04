class_name SpellTip
extends PanelContainer
## Infobulle de sort (nom + fiche technique), affichée au-dessus d'un bouton. Port de showCardSpellTip.

static var _inst: SpellTip

var _label: RichTextLabel

static func lines(spell: Dictionary) -> Array[String]:
	var mode := str(spell.get("mode", "damage"))
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
		value = L.fa(L.t("ui.spell_tip.soin_pv"), [int(spell.get("healMin", 0)), int(spell.get("healMax", 0))])
	elif mode == "staminaRestoreSingle":
		value = L.fa(L.t("ui.spell_tip.endurance_restauree"), [int(spell.get("staminaMin", 0)), int(spell.get("staminaMax", 0))])
	elif mode == "damage" or mode == "damageGroup":
		value = L.fa(L.t("ui.spell_tip.degats"), [int(spell.get("dmgMin", 0)), int(spell.get("dmgMax", 0))])
		if mode == "damageGroup":
			value += L.t("ui.spell_tip.par_cible_touchee")
		if bool(spell.get("ignoreAllResist", false)):
			value += L.t("ui.spell_tip.ignore_toute_resistance")
	var out: Array[String] = ["Type : " + mode_label]
	if value != "":
		out.append(value)
	if int(spell.get("spellLifestealPct", 0)) > 0:
		out.append(L.fa(L.t("ui.spell_tip.vol_de_vie_des_degats"), int(spell.spellLifestealPct)))
	var se := str(spell.get("statusEffect", ""))
	if se != "" and not Statuses.def(se).is_empty():
		var sd := Statuses.def(se)
		var extra := " · %d/tour" % int(spell.statusPower) if int(spell.get("statusPower", 0)) > 0 else ""
		out.append(L.fa(L.t("ui.spell_tip.effet_de_statut_tour"), [sd.get("icon", ""), sd.get("label", se), int(spell.get("statusChance", 0)), int(spell.get("statusDuration", 0)), extra]))
	out.append(L.fa(L.t("ui.spell_tip.endurance_recharge_ds"), [int(spell.get("staminaCost", 15)), int(spell.get("cooldownSec", 6))]))
	return out

static func _inst_for(host: Control) -> SpellTip:
	if _inst == null or not is_instance_valid(_inst):
		_inst = SpellTip.new()
		_inst.name = "SpellTip"
		_inst.visible = false
		_inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inst.z_index = 4000
		_inst.add_theme_stylebox_override("panel", UiTheme.box(Color("140e08", 0.97), Color("8a6a3a"), 2, 6))
		_inst._label = RichTextLabel.new()
		_inst._label.bbcode_enabled = true
		_inst._label.fit_content = true
		_inst._label.scroll_active = false
		_inst._label.custom_minimum_size = Vector2(260, 0)
		_inst._label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inst._label.add_theme_font_size_override("normal_font_size", 14)
		_inst._label.add_theme_font_size_override("bold_font_size", 15)
		_inst.add_child(_inst._label)
		host.get_tree().root.add_child(_inst)
	return _inst

static func show_for(host: Control, spell: Dictionary, remaining_sec: int = 0) -> void:
	var t := _inst_for(host)
	var txt := "[b][color=#e8b45c]%s[/color][/b]\n%s" % [str(spell.get("name", "")), "\n".join(lines(spell))]
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

static func hide_tip() -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst.visible = false
