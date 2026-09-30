class_name Interactions
extends Node
## Ce qui se passe quand le groupe marche sur une case ou touche un décor : ramassage, pièges, fontaines,
## leviers, portes verrouillées et clés, escaliers verrouillés, menus d'objets et fiche de personnage.

signal bag_changed
signal message(text: String)

var gs: GameState
var ctrl: CombatController
var rig: PlayerRig
var layout: GameLayout
var host: Node               # couche qui reçoit les fenêtres modales
var level: Dictionary = {}
var grid: DungeonGrid
var view: LevelView
var wand: Wanderers          # marchand itinérant (état et déplacements)

const TRAP_DEFAULTS := {"base": 15, "rogueBonus": 12, "assassinBonus": 6, "dexBonus": 0.5, "dexCap": 10, "min": 10, "max": 95,
	"critExtraDmg": 50, "dmgPctMin": 15, "dmgPctMax": 30}
const PICKUP_TYPES := ["potion", "weapon", "armor", "jewelry", "scroll", "key"]

func setup(state: GameState, controller: CombatController, r: PlayerRig, lay: GameLayout, modal_host: Node) -> void:
	gs = state
	ctrl = controller
	rig = r
	layout = lay
	host = modal_host

func bind_level(lvl: Dictionary, g: DungeonGrid, v: LevelView) -> void:
	level = lvl
	grid = g
	view = v

func _lid() -> String:
	return str(level.get("id", ""))

func _lstate() -> Dictionary:
	return gs.level_state(level)

func _log(msg: String, hit: bool = false) -> void:
	gs.add_log(msg, hit)

# ------------------------------------------------------------------ déplacement

## Après chaque pas : gain d'endurance puis objet éventuel sur la case.
func on_step() -> void:
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	gs.stats["moves"] = int(gs.stats.get("moves", 0)) + 1
	var interval := maxi(1, int(sta.get("moveInterval", 1)))
	if int(gs.stats.moves) % interval == 0:
		for c in gs.alive_party():
			c["stamina"] = mini(int(c.get("maxStamina", 100)), int(c.get("stamina", 0)) + int(sta.get("moveGain", 0)))
	var mm: Dictionary = wand.merchant() if wand != null else {}
	if not mm.is_empty() and int(mm.x) == rig.gx and int(mm.y) == rig.gy:
		_meet_merchant(mm)
		return
	for it in level.get("items", []):
		if int(it.x) != rig.gx or int(it.y) != rig.gy:
			continue
		var st := gs.item_state(_lid(), str(it.id))
		if st.get("taken", false) or st.get("disarmed", false) or st.get("hidden", bool(it.get("startHidden", false))):
			continue
		match str(it.get("type", "")):
			"trap": _prompt_trap(it)
			"fountain": _prompt_fountain(it)
			"switch": _trigger_switch(it)
			"decor": _activate_decor(it)
			_:
				if PICKUP_TYPES.has(str(it.get("type", ""))):
					_pickup(it)
		return

# ------------------------------------------------------------------ village

## Case bloquée par le décor du village (arbre ou PNJ) : on ne peut pas y entrer, on lui parle.
func blocks_cell(x: int, y: int) -> bool:
	if not bool(level.get("outdoor", false)):
		return false
	return (level.get("treeCells", []) as Array).has("%d,%d" % [x, y]) or npc_at(x, y) != ""

func npc_at(x: int, y: int) -> String:
	if not bool(level.get("outdoor", false)):
		return ""
	var mm: Dictionary = wand.merchant() if wand != null else {}
	if not mm.is_empty() and int(mm.x) == x and int(mm.y) == y:
		return "merchant"
	var bs = level.get("blacksmith")
	if bs is Dictionary and int(bs.x) == x and int(bs.y) == y:
		return "blacksmith"
	var tm = level.get("talentMaster")
	if tm is Dictionary and int(tm.x) == x and int(tm.y) == y:
		return "talent"
	return ""

## Le groupe se heurte à un arbre ou à un PNJ du village. Renvoie true si quelque chose a réagi.
func bump_village(x: int, y: int) -> bool:
	if not bool(level.get("outdoor", false)):
		return false
	var on_change := func():
		bag_changed.emit()
		ctrl.changed.emit()
	if (level.get("treeCells", []) as Array).has("%d,%d" % [x, y]):
		_log("Un arbre bloque le passage.")
		message.emit("Un arbre bloque le passage")
		return true
	match npc_at(x, y):
		"merchant":
			var mm: Dictionary = wand.merchant()
			mm["discovered"] = true
			_log("🧙 Le marchand vous accueille et vous montre son étal.")
			if mm.get("offers") == null:
				mm["offers"] = Shop.village_offers(gs.cfg, gs.run_number)
			ShopModal.open(host, gs, mm.offers, true, on_change)
			return true
		"blacksmith":
			_log("🔨 Le forgeron vous accueille dans son atelier.")
			ForgeModal.open(host, gs, on_change)
			return true
		"talent":
			_log("📖 Le maître des talents vous invite à reconsidérer votre voie.")
			TalentModals.master(host, gs, on_change)
			return true
	return false

# ------------------------------------------------------------------ marchand itinérant

func _meet_merchant(mm: Dictionary) -> void:
	mm["discovered"] = true
	if wand != null:
		wand.merchant_moved.emit()
	_log("🧙 Un marchand itinérant croise la route du groupe.")
	var m := Modal.open(host, "Marchand itinérant", 400)
	m.add_text("Un marchand itinérant vous interpelle : « Équipement, potions, parchemins… tout se négocie. »")
	m.set_buttons([
		{"text": "Voir son étal", "cb": func():
			m.close()
			open_merchant(mm)},
		{"text": "Continuer", "cb": func(): m.close()},
	])

func open_merchant(mm: Dictionary) -> void:
	if mm.get("offers") == null:
		var run := maxi(0, (gs.cfg.get("levels", []) as Array).find(level))
		mm["offers"] = Shop.merchant_offers(gs.cfg, level.get("travelingMerchant", {}), run)
	var on_change := func():
		bag_changed.emit()
		ctrl.changed.emit()
	ShopModal.open(host, gs, mm.offers, false, on_change)

func _pickup(it: Dictionary) -> void:
	var inst := Inventory.make_instance(it)
	if not Inventory.has_space(gs, inst):
		_log("🎒 L'onglet %s est plein (%d/%d) ! Équipez ou jetez des objets pour faire de la place — %s reste au sol." % [
			Inventory.TAB_LABELS[Inventory.tab_of(inst)], Inventory.MAX_PER_TAB, Inventory.MAX_PER_TAB, it.get("name", "l'objet")])
		return
	Inventory.add(gs, inst)
	Sound.sfx("pickup")
	gs.item_state(_lid(), str(it.id))["taken"] = true
	_lstate().taken_items[str(it.id)] = true
	view.entities.remove_item(str(it.id))
	gs.stats["itemsFound"] = int(gs.stats.get("itemsFound", 0)) + 1
	_log("Le groupe ramasse %s." % it.get("name", "un objet"))
	message.emit("Ramassé : %s" % it.get("name", "objet"))
	bag_changed.emit()

# ------------------------------------------------------------------ portes et escaliers

## Le groupe se heurte à une porte fermée. Renvoie true si elle vient de s'ouvrir.
func try_door(x: int, y: int) -> bool:
	var d := grid.door_at(x, y)
	if d.is_empty() or grid.opened.has(str(d.id)):
		return false
	var ls := _lstate()
	var unlocked: Dictionary = ls.get_or_add("door_unlocked", {})
	var locked: bool = bool(d.get("locked", true)) and not unlocked.has(str(d.id))
	if locked:
		var k := Inventory.find_key(gs, str(d.id))
		if k < 0:
			Sound.sfx("door_locked")
			_log("🔒 Cette porte est verrouillée.")
			message.emit("🔒 Porte verrouillée")
			return false
		var key: Dictionary = gs.inventory[k]
		_log("🔑 Le groupe utilise %s pour déverrouiller la porte. La clé est consommée et disparaît de la besace." % key.get("name", "la clé"))
		gs.inventory.remove_at(k)
		unlocked[str(d.id)] = true
		bag_changed.emit()
	Sound.sfx("door_creak")
	open_door(str(d.id))
	return true

func open_door(id: String) -> void:
	gs.level_state(level).get_or_add("opened_doors", {})[id] = true
	view.open_door(id)

## Escalier verrouillé (grille d'arche) : consomme la clé correspondante.
func stairs_open(st: Dictionary) -> bool:
	if not bool(st.get("locked", false)):
		return true
	var unlocked: Dictionary = _lstate().get_or_add("door_unlocked", {})
	if unlocked.has(str(st.id)):
		return true
	var k := Inventory.find_key(gs, str(st.id))
	if k < 0:
		Sound.sfx("door_locked")
		_log("🔒 Une grille de fer ferme cette arche — il faut trouver la clé.")
		message.emit("🔒 Arche verrouillée")
		return false
	_log("🔑 Le groupe utilise %s pour ouvrir la grille de l'arche. La clé est consommée." % gs.inventory[k].get("name", "la clé"))
	gs.inventory.remove_at(k)
	unlocked[str(st.id)] = true
	bag_changed.emit()
	return true

# ------------------------------------------------------------------ décor

## Décor à effet (statue, brasero…) : marcher dessus donne un statut au groupe, une fois par visite.
func _activate_decor(it: Dictionary) -> void:
	var st := gs.item_state(_lid(), str(it.id))
	if st.get("taken", false):
		return
	st["taken"] = true
	var def: Dictionary = {}
	for d in Data.constants.get("DECOR_LIBRARY", []):
		if str(d.get("id", "")) == str(it.get("decorTypeId", "")):
			def = d
	var sdef := Statuses.def(str(def.get("status", "")))
	if not def.is_empty() and not sdef.is_empty():
		var dur := int(def.get("duration", 8))
		var power := int(def.get("power", 4))
		for c in gs.alive_party():
			var list: Array = c.get("statusEffects", [])
			var found := false
			for e in list:
				if str(e.type) == str(def.status):
					e["remaining"] = maxi(int(e.remaining), dur)
					e["power"] = power
					found = true
			if not found:
				list.append({"type": def.status, "remaining": dur, "power": power, "casterId": ""})
			c["statusEffects"] = list
			Characters.recompute(c, gs.cfg)
		Sound.sfx("pickup")
		_log("%s %s — %s %s %s !" % [it.get("icon", "") if not str(it.get("icon", "")).begins_with("@icon:") else "", it.get("name", ""), def.get("flavor", ""), sdef.get("icon", ""), sdef.get("label", "")])
		ctrl.changed.emit()
	else:
		_log("%s — %s" % [it.get("name", ""), def.get("flavor", "")])

# ------------------------------------------------------------------ levier

func _trigger_switch(it: Dictionary) -> void:
	var st := gs.item_state(_lid(), str(it.id))
	if st.get("triggered", false):
		return
	st["triggered"] = true
	ctrl.fx.emit("switch")
	_log("🔧 %s actionné !" % it.get("name", "Levier"))
	var did := str(it.get("switchOpensDoorId", ""))
	if did != "":
		_lstate().get_or_add("door_unlocked", {})[did] = true
		_log("🔓 Une porte se déverrouille au loin...")
	if str(it.get("message", "")) != "":
		_log(str(it.message))

# ------------------------------------------------------------------ fontaine

func _fountain_cooldown_ms() -> float:
	return maxf(5.0, float(gs.cfg.get("fountainCooldownMinutes", 10))) * 60000.0

func _prompt_fountain(it: Dictionary) -> void:
	var st := gs.item_state(_lid(), str(it.id))
	var now := Time.get_unix_time_from_system() * 1000.0
	var ready_at := float(st.get("usedAt", 0.0)) + _fountain_cooldown_ms()
	if st.has("usedAt") and now < ready_at:
		_log("💧 %s est tarie pour l'instant. Elle se rechargera dans environ %d minute(s)." % [it.get("name", "La fontaine"), int(ceil((ready_at - now) / 60000.0))])
		return
	var m := Modal.open(host, "Fontaine", 400)
	m.add_text("Voulez-vous utiliser cette fontaine ? Elle restaure PV et endurance de tout le groupe (et ressuscite les personnages tombés), puis se tarit un moment.")
	m.set_buttons([
		{"text": "Utiliser", "cb": func():
			m.close()
			_use_fountain(it)},
		{"text": "Laisser", "cb": func(): m.close()},
	])

func _use_fountain(it: Dictionary) -> void:
	var st := gs.item_state(_lid(), str(it.id))
	st["usedAt"] = Time.get_unix_time_from_system() * 1000.0
	gs.stats["fountainsUsed"] = int(gs.stats.get("fountainsUsed", 0)) + 1
	var revived: Array[String] = []
	for c in gs.party:
		if int(c.hp) <= 0:
			revived.append(str(c.name))
		c["hp"] = c.maxHp
		c["stamina"] = c.get("maxStamina", 100)
	Sound.sfx("fountain")
	ctrl.fx.emit("fountain")
	_log("⛲ %s redonne toutes ses forces au groupe ! PV et endurance entièrement restaurés." % it.get("name", "La fontaine"))
	if not revived.is_empty():
		_log("✝️ %s %s ramené(s) à la vie par la fontaine !" % [", ".join(revived), "est" if revived.size() == 1 else "sont"])
	ctrl.popup.emit("✨ PV & Endurance restaurés ✨", Color("3aa8c8"))
	ctrl.changed.emit()

# ------------------------------------------------------------------ pièges

func _trap_cfg() -> Dictionary:
	var o: Dictionary = TRAP_DEFAULTS.duplicate()
	var c: Dictionary = gs.cfg.get("trapSettings", {})
	for k in o.keys():
		if c.has(k) and c[k] != null and str(c[k]) != "":
			o[k] = float(c[k])
	return o

## Chance de désamorçage (%) : base + bonus de classe + dextérité de l'équipe.
func trap_chance() -> int:
	var s := _trap_cfg()
	var raw: float = float(s.base)
	for c in gs.alive_party():
		var cid := str(c.get("classId", ""))
		if cid == "class_rogue" or cid == "class_thief":
			raw += float(s.rogueBonus)
		elif cid == "class_assassin":
			raw += float(s.assassinBonus)
		var above := maxf(0.0, float(c.get("effDex", c.get("dex", 10))) - 10.0)
		raw += minf(float(s.dexCap), above) * float(s.dexBonus)
	return int(round(clampf(raw, float(s.min), maxf(float(s.min), float(s.max)))))

static func trap_threshold(chance: int) -> int:
	return clampi(int(ceil(21.0 - chance / 5.0)), 2, 20)

func _prompt_trap(it: Dictionary) -> void:
	var chance := trap_chance()
	var m := Modal.open(host, "⚠ Piège : " + str(it.get("name", "")), 400)
	m.esc_closes = false
	m.add_text("Le groupe a repéré un piège. Tenter de le désamorcer ?")
	m.add_text("Chance de réussite : %d %%  (jet de d20 : %d ou plus)" % [chance, trap_threshold(chance)], UiTheme.GOLD)
	m.add_text("Un 20 naturel est une réussite parfaite, un 1 un échec critique.", UiTheme.DIM, 14, true)
	m.set_buttons([
		{"text": "Crocheter", "cb": func(): _roll_trap(m, it, chance)},
		{"text": "Passer", "cb": func():
			m.close()
			_apply_trap(it, 1.0, {})},
	])

func _roll_trap(m: Modal, it: Dictionary, chance: int) -> void:
	var thr := trap_threshold(chance)
	var roll := randi_range(1, 20)
	var outcome := "crit" if roll == 1 else ("perfect" if roll == 20 else ("success" if roll >= thr else "fail"))
	for ch in m.content.get_children():
		ch.queue_free()
	m.add_text("🎲 Jet : %d / 20  (il fallait %d ou plus)" % [roll, thr], UiTheme.GOLD, 20)
	var hit := {}
	match outcome:
		"perfect": m.add_text("✨ Crochetage parfait !", Color("7fd17f"), 20)
		"success": m.add_text("🔓 Piège désamorcé", Color("7fd17f"), 20)
		"fail": m.add_text("❌ Le crochetage échoue", Color("ff8a6a"), 20)
		_: m.add_text("💥 Échec critique !", Color("ff5a4a"), 20)
	if outcome == "fail" or outcome == "crit":
		var mult := 1.0 + float(_trap_cfg().critExtraDmg) / 100.0 if outcome == "crit" else 1.0
		hit = _pick_victim(it, mult)
		m.add_text("🎯 %s subira %d dégâts" % [hit.victim.name, int(hit.dmg)], Color("ff8a6a"))
	m.set_buttons([{"text": "Continuer", "cb": func():
		m.close()
		if outcome == "perfect" or outcome == "success":
			gs.item_state(_lid(), str(it.id))["disarmed"] = true
			_log("🔓 %s désamorcé par le groupe." % it.get("name", "Le piège"))
			ctrl.changed.emit()
		else:
			if outcome == "crit":
				_log("💥 Échec critique ! Le piège frappe plus fort (+%d %%)." % int(_trap_cfg().critExtraDmg), true)
			_apply_trap(it, 1.0, hit)}])

func _pick_victim(it: Dictionary, mult: float) -> Dictionary:
	var alive := gs.alive_party()
	var victim: Dictionary = alive[randi() % alive.size()] if not alive.is_empty() else gs.char_by_id(gs.active_char_id)
	var s := _trap_cfg()
	var pct := randi_range(int(round(float(s.dmgPctMin))), int(round(float(s.dmgPctMax))))
	var pct_dmg := int(ceil(float(victim.get("maxHp", 1)) * pct / 100.0))
	var flat := randi_range(int(it.get("trapDmgMin", 1)), maxi(int(it.get("trapDmgMin", 1)), int(it.get("trapDmgMax", 4))))
	return {"victim": victim, "dmg": maxi(1, int(round(maxi(pct_dmg, flat) * mult)))}

func _apply_trap(it: Dictionary, mult: float, pre: Dictionary) -> void:
	if not bool(it.get("permanent", false)):
		gs.item_state(_lid(), str(it.id))["taken"] = true
	var hit: Dictionary = pre if not pre.is_empty() else _pick_victim(it, mult)
	var victim: Dictionary = hit.victim
	victim["hp"] = maxi(0, int(victim.hp) - int(hit.dmg))
	ctrl.fx.emit("trap")
	gs.stats["trapsTriggered"] = int(gs.stats.get("trapsTriggered", 0)) + 1
	gs.bump(victim.id, "damageTaken", int(hit.dmg))
	if int(victim.hp) <= 0:
		gs.bump(victim.id, "knockdowns")
	_log("⚠️ Piège déclenché : %s ! %s subit %d dégâts." % [it.get("name", ""), victim.name, int(hit.dmg)], true)
	ctrl.popup.emit("-%d" % int(hit.dmg), Color("ff6a6a"))
	if int(victim.hp) <= 0:
		_log("%s s'effondre, à terre !" % victim.name)
		if gs.alive_party().is_empty():
			gs.game_over = true
			_log("Le groupe est anéanti... les ténèbres l'emportent.")
			ctrl.game_over.emit()
		elif gs.active_char_id == str(victim.id):
			gs.active_char_id = str(gs.alive_party()[0].id)
	ctrl.changed.emit()

# ------------------------------------------------------------------ menu d'un objet de la besace

## Barre rapide de combat : le personnage actif boit la potion.
func use_potion_at(char_id: String, idx: int) -> void:
	if idx < 0 or idx >= gs.inventory.size():
		return
	var healed := Inventory.use_potion(gs, gs.char_by_id(char_id), idx)
	if healed >= 0:
		ctrl.potion_drunk(char_id, healed)
		bag_changed.emit()

## Barre rapide de combat : choix d'un parchemin à lire par le personnage actif.
func open_scroll_picker(char_id: String) -> void:
	var groups: Array = []
	for i in gs.inventory.size():
		var it: Dictionary = gs.inventory[i]
		if str(it.get("type", "")) != "scroll":
			continue
		var found := false
		for g in groups:
			if str(g.it.get("spellId", "")) == str(it.get("spellId", "")):
				g.count += 1
				found = true
				break
		if not found:
			groups.append({"it": it, "idx": i, "count": 1})
	if groups.is_empty():
		return
	var m := Modal.open(host, "📜 Choisir un parchemin", 420)
	for g in groups:
		var it2: Dictionary = g.it
		var idx2: int = g.idx
		var sp := ctrl.combat.spell_def(str(it2.get("spellId", "")))
		var label := str(sp.get("name", it2.get("name", "Parchemin")))
		if int(g.count) > 1:
			label += "  ×%d" % int(g.count)
		m.add_row(IconResolver.texture(str(it2.get("icon", ""))), "\n".join(SpellTip.lines(sp)) if not sp.is_empty() else "Parchemin illisible")
		m.add_button(label, func():
			m.close()
			ctrl.read_scroll(char_id, idx2)
			bag_changed.emit())

func open_item_menu(idx: int) -> void:
	if idx < 0 or idx >= gs.inventory.size():
		return
	var it: Dictionary = gs.inventory[idx]
	var m := Modal.open(host, str(it.get("name", "Objet")), 400)
	m.add_row(IconResolver.texture(str(it.get("icon", ""))), "\n".join(Inventory.describe(it, gs.cfg)))
	var type := str(it.get("type", ""))
	var alive := gs.alive_party()
	if type == "potion":
		m.add_text("Faire boire à :", UiTheme.DIM, 14, true)
		for c in alive:
			var cid: String = str(c.id)
			m.add_button("%s  (%d/%d PV · %d/%d End.)" % [c.name, int(c.hp), int(c.maxHp), int(c.get("stamina", 0)), int(c.get("maxStamina", 100))],
				func():
					var healed := Inventory.use_potion(gs, gs.char_by_id(cid), idx)
					m.close()
					if healed >= 0:
						ctrl.potion_drunk(cid, healed)
						bag_changed.emit())
	elif type == "scroll":
		m.add_text("Faire lire à :", UiTheme.DIM, 14, true)
		for c in alive:
			var cid2: String = str(c.id)
			m.add_button(str(c.name), func():
				m.close()
				ctrl.read_scroll(cid2, idx)
				bag_changed.emit())
	elif Inventory.can_equip(it):
		m.add_text("Équiper sur :", UiTheme.DIM, 14, true)
		for c in gs.party:
			var cid3: String = str(c.id)
			var cur = c.get("equipment", {}).get(Inventory.slot_of(it))
			var label := "%s" % c.name
			if cur != null:
				label += "  (remplace %s)" % cur.get("name", "")
			m.add_button(label, func():
				m.close()
				Inventory.equip(gs, gs.char_by_id(cid3), idx)
				ctrl.changed.emit()
				bag_changed.emit())
	var buttons: Array = []
	if type != "key":
		buttons.append({"text": "Jeter", "cb": func():
			m.close()
			Inventory.discard(gs, idx)
			bag_changed.emit()})
	buttons.append({"text": "Fermer", "cb": func(): m.close()})
	m.set_buttons(buttons)

# ------------------------------------------------------------------ fiche de personnage

func open_sheet(char_id: String) -> void:
	var c := gs.char_by_id(char_id)
	if c.is_empty():
		return
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	var m := Modal.open(host, str(c.name), 460)
	var pp := IconResolver.portrait_path(c, gs.cfg)
	m.add_row(load(pp) if pp != "" else null, "%s — niveau %d\nXP %d / %d" % [cls.get("name", ""), int(c.level), int(c.get("xp", 0)), int(c.get("xpToNext", 1))], UiTheme.GOLD)
	m.add_text("PV %d/%d   ·   Endurance %d/%d   ·   Vitesse %d" % [int(c.hp), int(c.maxHp), int(c.get("stamina", 0)), int(c.get("maxStamina", 100)), int(c.get("effSpeed", 10))])
	m.add_text("Force %d   Dextérité %d   Constitution %d   Intelligence %d" % [int(c.get("effForce", 0)), int(c.get("effDex", 0)), int(c.get("effCon", 0)), int(c.get("effInt", 0))])
	m.add_text("Attaque %d – %d   ·   Dégâts de sort +%d" % [int(c.atkMin), int(c.atkMax), int(c.get("bonusSpellDmg", 0))])
	m.add_text("Équipement (toucher pour retirer)", UiTheme.DIM, 14, true)
	var eq: Dictionary = c.get("equipment", {})
	for slot in Characters.SLOTS:
		var item = eq.get(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lab := Label.new()
		lab.text = str(Inventory.SLOT_LABELS[slot])
		lab.custom_minimum_size = Vector2(70, 0)
		lab.add_theme_color_override("font_color", UiTheme.DIM)
		row.add_child(lab)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if item == null:
			b.text = "— vide —"
			b.disabled = true
		else:
			b.text = "%s   (%s)" % [item.get("name", ""), ", ".join(Inventory.describe(item, gs.cfg))]
			b.icon = IconResolver.texture(str(item.get("icon", "")))
			b.expand_icon = true
			b.clip_text = true
			var sl: String = slot
			b.pressed.connect(func():
				if Inventory.unequip(gs, gs.char_by_id(char_id), sl):
					ctrl.changed.emit()
					bag_changed.emit()
					m.close()
					open_sheet(char_id))
		row.add_child(b)
		m.content.add_child(row)
	m.add_text("Compétences", UiTheme.DIM, 14, true)
	var known: Array = c.get("spellsKnown", [])
	if known.is_empty():
		m.add_text("Aucune compétence apprise.", UiTheme.DIM, 14, true)
	for sid in known:
		for sp in gs.cfg.get("spells", []):
			if sp.get("id") == sid:
				var ic := str(sp.get("icon", ""))
				m.add_text("%s %s — %s, endurance %d, recharge %d s" % [("" if ic.begins_with("@icon:") else ic), sp.name, spell_effect(sp), int(sp.get("staminaCost", 0)), int(sp.get("cooldownSec", 0))], UiTheme.PARCH, 14)
	m.set_buttons([{"text": "Fermer", "cb": func(): m.close()}])

static func spell_effect(sp: Dictionary) -> String:
	match str(sp.get("mode", "")):
		"damage": return "dégâts %d–%d" % [int(sp.get("dmgMin", 0)), int(sp.get("dmgMax", 0))]
		"damageGroup": return "dégâts de groupe %d–%d" % [int(sp.get("dmgMin", 0)), int(sp.get("dmgMax", 0))]
		"healSingle": return "soin %d–%d" % [int(sp.get("healMin", 0)), int(sp.get("healMax", 0))]
		"healParty": return "soin de groupe %d–%d" % [int(sp.get("healMin", 0)), int(sp.get("healMax", 0))]
		"staminaRestoreSingle": return "endurance +%d–%d" % [int(sp.get("staminaMin", 0)), int(sp.get("staminaMax", 0))]
		"shieldSingle": return "bouclier %d–%d" % [int(sp.get("shieldMin", 0)), int(sp.get("shieldMax", 0))]
		"dispelSingle": return "retire les statuts négatifs d'un allié"
		"sleepGroup": return "endort l'ennemi engagé (%d%% de chance)" % int(sp.get("statusChance", 0))
		"selfBuff": return "améliore le lanceur (%d tours)" % int(sp.get("statusDuration", 0))
		"partyUtility": return "recharges −%d s et vigueur pour tout le groupe" % int(sp.get("cooldownReductionSec", 0))
	return str(sp.get("mode", "effet spécial"))
