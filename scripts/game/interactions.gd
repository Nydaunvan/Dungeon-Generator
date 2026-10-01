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

var last_bump: String = ""

## Un mur barre la route : le message n'est écrit qu'une fois tant qu'on insiste sur la même case (lastWallBump de l'original).
func bump_wall(x: int, y: int) -> void:
	var k := "%d,%d" % [x, y]
	if last_bump != k:
		_log("Un mur de pierre froide bloque le passage.")
	last_bump = k

## Après chaque pas : gain d'endurance puis objet éventuel sur la case.
func on_step() -> void:
	last_bump = ""
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	gs.stats["moves"] = int(gs.stats.get("moves", 0)) + 1
	var interval := maxi(1, int(sta.get("moveInterval", 1)))
	if int(gs.stats.moves) % interval == 0:
		for c in gs.alive_party():
			c["stamina"] = mini(int(c.get("maxStamina", 100)), int(c.get("stamina", 0)) + int(sta.get("moveGain", 2)))
	# un seul objet par pas (le premier de la case), puis le marchand ambulant s'il est là (hors village)
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
		break
	var mm: Dictionary = wand.merchant() if wand != null else {}
	if not mm.is_empty() and int(mm.x) == rig.gx and int(mm.y) == rig.gy and not bool(level.get("outdoor", false)):
		_meet_merchant(mm)

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
		if last_bump != "%d,%d" % [x, y]:
			_log("Un arbre bloque le passage.")
		last_bump = "%d,%d" % [x, y]
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
	_log("🧙 Un marchand ambulant vous salue et déballe son étal.")
	var m := Modal.open(host, "🧙 Marchand ambulant", 380)
	m.add_text("Vous croisez le marchand ambulant. Souhaitez-vous consulter son étal ?", UiTheme.DIM, 15, true)
	m.set_buttons([
		{"text": "🛒 Voir son étal", "primary": true, "cb": func():
			m.close()
			open_merchant(mm)},
		{"text": "Continuer sans s'arrêter", "cb": func(): m.close()},
	])

func open_merchant(mm: Dictionary) -> void:
	if mm.get("offers") == null:
		mm["offers"] = Shop.merchant_offers(gs.cfg, level.get("travelingMerchant", {}), maxi(1, gs.run_number))
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
	if d.is_empty() or grid.opened.has(str(d.id)) or view.opening.has(str(d.id)):
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
	if view.opening.has(str(st.id)):
		return false      # la grille est en train de remonter
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
	open_door(str(st.id))     # la grille de l'arche remonte ; on ne passe qu'une fois ouverte
	return false

# ------------------------------------------------------------------ décor

## Décor à effet (statue, brasero…) : marcher dessus donne un statut au groupe, une fois par visite.
func _activate_decor(it: Dictionary) -> void:
	var st := gs.item_state(_lid(), str(it.id))
	if st.get("taken", false):
		return
	st["taken"] = true
	view.entities.remove_item(str(it.id))
	var def: Dictionary = {}
	for d in Data.constants.get("DECOR_LIBRARY", []):
		if str(d.get("id", "")) == str(it.get("decorTypeId", "")):
			def = d
	var sdef := Statuses.def(str(def.get("status", "")))
	if not def.is_empty() and not sdef.is_empty():
		var dur := int(def.get("duration", 0)) if int(def.get("duration", 0)) > 0 else 8
		var power := int(def.get("power", 0)) if int(def.get("power", 0)) > 0 else 4
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
	var mid := str(it.get("switchRevealMonsterId", ""))
	if mid != "":
		var mst: Dictionary = _lstate().monsters.get(mid, {})
		if not mst.is_empty() and mst.get("hidden", false):
			mst["hidden"] = false
			view.entities.set_monster_visible(mid, true)
			_log("👹 Une présence hostile se révèle non loin...")
	var iid := str(it.get("switchRevealItemId", ""))
	if iid != "":
		var ist := gs.item_state(_lid(), iid)
		var def_hidden := false
		for d in level.get("items", []):
			if str(d.id) == iid:
				def_hidden = bool(d.get("startHidden", false))
		if ist.get("hidden", def_hidden):
			ist["hidden"] = false
			view.entities.set_item_visible(iid, true)
			_log("✨ Un objet apparaît, jusque-là invisible...")
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
	var m := Modal.open(host, "⛲ Fontaine", 400)
	m.add_text("Voulez-vous utiliser cette fontaine ? Elle restaure PV et endurance de tout le groupe (et ressuscite les personnages tombés), puis se recharge pendant un certain temps.", UiTheme.PARCH, 14, true)
	m.set_buttons([
		{"text": "✨ Utiliser la fontaine", "primary": true, "cb": func():
			m.close()
			_use_fountain(it)},
		{"text": "Passer sans l'utiliser", "primary": false, "cb": func(): m.close()},
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
	o["max"] = maxf(o.max, o.min)
	o["dmgPctMax"] = maxf(o.dmgPctMax, o.dmgPctMin)
	o["dexCap"] = maxf(o.dexCap, 0.0)
	return o

## Détail du calcul de chance : base + bonus de classe + dextérité de l'équipe (comme computeTrapBreakdown).
func trap_breakdown() -> Dictionary:
	var s := _trap_cfg()
	var lines: Array = []
	var dex_parts: Array = []
	var raw: float = float(s.base)
	var dex_total := 0.0
	for c in gs.alive_party():
		var cid := str(c.get("classId", ""))
		var b := 0.0
		if cid == "class_rogue" or cid == "class_thief":
			b = float(s.rogueBonus)
		elif cid == "class_assassin":
			b = float(s.assassinBonus)
		if b != 0.0:
			lines.append({"name": c.name, "cls": str(Characters.class_def(gs.cfg, cid).get("name", cid)), "val": b})
			raw += b
		var dx := float(c.get("effDex", c.get("dex", 10)))
		var above := maxf(0.0, dx - 10.0)
		var d := minf(float(s.dexCap), above) * float(s.dexBonus)
		if d > 0.0:
			dex_parts.append({"name": c.name, "dex": dx, "val": d, "capped": above > float(s.dexCap)})
			dex_total += d
	raw += dex_total
	var chance := int(round(clampf(raw, float(s.min), maxf(float(s.min), float(s.max)))))
	var down := 0
	for c in gs.party:
		if int(c.hp) <= 0:
			down += 1
	return {"s": s, "lines": lines, "dexParts": dex_parts, "dexTotal": dex_total, "raw": int(round(raw)), "chance": chance, "down": down}

func trap_chance() -> int:
	return int(trap_breakdown().chance)

static func trap_threshold(chance: int) -> int:
	return clampi(int(ceil(21.0 - chance / 5.0)), 2, 20)

func _prompt_trap(it: Dictionary) -> void:
	var m := TrapModal.open(host, it, trap_breakdown(), func(mult: float): return _pick_victim(it, mult))
	m.skipped.connect(func(): _apply_trap(it, 1.0, {}))
	m.resolved.connect(func(outcome: String, hit: Dictionary):
		if outcome == "perfect" or outcome == "success":
			gs.item_state(_lid(), str(it.id))["disarmed"] = true
			view.entities.remove_item(str(it.id))
			_log("🔓 %s désamorcé par le groupe." % it.get("name", "Le piège"))
			ctrl.changed.emit()
		else:
			if outcome == "crit":
				_log("💥 Échec critique ! Le piège frappe plus fort (+%d %%)." % int(_trap_cfg().critExtraDmg), true)
			_apply_trap(it, 1.0, hit))

func _pick_victim(it: Dictionary, mult: float) -> Dictionary:
	var alive := gs.alive_party()
	var victim: Dictionary = alive[randi() % alive.size()] if not alive.is_empty() else gs.char_by_id(gs.active_char_id)
	var s := _trap_cfg()
	var pct := randi_range(int(round(float(s.dmgPctMin))), int(round(float(s.dmgPctMax))))
	var pct_dmg := int(ceil(float(victim.get("maxHp", 1)) * pct / 100.0))
	var dmin := int(it.get("trapDmgMin", 0)) if int(it.get("trapDmgMin", 0)) > 0 else 1
	var dmax := int(it.get("trapDmgMax", 0)) if int(it.get("trapDmgMax", 0)) > 0 else 4
	var flat := randi_range(dmin, maxi(dmin, dmax))
	return {"victim": victim, "dmg": maxi(1, int(round(maxi(pct_dmg, flat) * mult)))}

func _apply_trap(it: Dictionary, mult: float, pre: Dictionary) -> void:
	if not bool(it.get("permanent", false)):
		gs.item_state(_lid(), str(it.id))["taken"] = true
		view.entities.remove_item(str(it.id))     # piège à usage unique : il disparaît une fois déclenché
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
	var fighting := ctrl.in_combat()
	if type == "potion":
		m.add_text("Faire boire à :", UiTheme.DIM, 14, true)
		for c in alive:
			if fighting and str(c.id) != gs.active_char_id:
				continue
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
	elif Inventory.can_equip(it) and not fighting:
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
	if type != "key" and not fighting:
		buttons.append({"text": "Jeter", "cb": func():
			m.close()
			Inventory.discard(gs, idx)
			bag_changed.emit()})
	buttons.append({"text": "Fermer", "cb": func(): m.close()})
	m.set_buttons(buttons)

# ------------------------------------------------------------------ fiche de personnage

func open_sheet(char_id: String) -> void:
	if gs.char_by_id(char_id).is_empty():
		return
	PartyModal.open(host, gs, char_id)

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
