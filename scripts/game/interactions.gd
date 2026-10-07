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
		_log(L.t("game.interactions.un_mur_de_pierre_froide"))
	last_bump = k

## Avancer contre le mur d'un décroché de fontaine : propose de l'utiliser. Renvoie true si c'était le cas.
func bump_fountain(tx: int, ty: int) -> bool:
	if bool(level.get("outdoor", false)):
		return false
	for it in level.get("items", []):
		if str(it.get("type", "")) != "fountain" or int(it.x) != rig.gx or int(it.y) != rig.gy:
			continue
		var st := gs.item_state(_lid(), str(it.id))
		if st.get("taken", false) or st.get("hidden", bool(it.get("startHidden", false))):
			continue
		if LevelBuilder.fountain_niche_dir(grid, int(it.x), int(it.y), str(it.id)) != Vector2i(tx - rig.gx, ty - rig.gy):
			continue
		_prompt_fountain(it)
		return true
	return false

## Après chaque pas : gain d'endurance puis objet éventuel sur la case.
func step_stamina() -> void:
	last_bump = ""
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	gs.stats["moves"] = int(gs.stats.get("moves", 0)) + 1
	var interval := maxi(1, int(sta.get("moveInterval", 1)))
	if int(gs.stats.moves) % interval == 0:
		for c in gs.alive_party():
			c["stamina"] = mini(int(c.get("maxStamina", 100)), int(c.get("stamina", 0)) + int(sta.get("moveGain", 2)))

## Ordre de l'original : déplacement, endurance, statuts (step_tick), puis objet de la case et marchand.
func step_items() -> void:
	# un seul objet par pas (le premier de la case), puis le marchand ambulant s'il est là (hors village)
	for it in level.get("items", []):
		if int(it.x) != rig.gx or int(it.y) != rig.gy:
			continue
		var st := gs.item_state(_lid(), str(it.id))
		if st.get("taken", false) or st.get("disarmed", false) or st.get("hidden", bool(it.get("startHidden", false))):
			continue
		match str(it.get("type", "")):
			"trap": _prompt_trap(it)
			"fountain":
				# fontaine logée dans un décroché : on l'utilise en avançant vers elle (comme une porte), pas en passant dessus
				if LevelBuilder.fountain_niche_dir(grid, int(it.x), int(it.y), str(it.id)) == Vector2i.ZERO or bool(level.get("outdoor", false)):
					_prompt_fountain(it)
			"switch": _trigger_switch(it)
			"decor": _activate_decor(it)
			_:
				if PICKUP_TYPES.has(str(it.get("type", ""))):
					_pickup(it)
		break

# ------------------------------------------------------------------ village

## Case bloquée par le décor du village (arbre ou PNJ) : on ne peut pas y entrer, on lui parle.
var _pass_merchant := false

func blocks_cell(x: int, y: int) -> bool:
	if not bool(level.get("outdoor", false)):
		return npc_at(x, y) == "merchant" and not _pass_merchant and merchant_niche_dir() == Vector2i.ZERO   # marchand ambulant : fixe contre un mur, on le heurte au lieu de marcher dessus
	return (level.get("treeCells", []) as Array).has("%d,%d" % [x, y]) or npc_at(x, y) != ""

func npc_at(x: int, y: int) -> String:
	var mm: Dictionary = wand.merchant() if wand != null else {}
	if not mm.is_empty() and int(mm.x) == x and int(mm.y) == y:
		return "merchant"
	if not bool(level.get("outdoor", false)):
		return ""
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
		var tm: Dictionary = wand.merchant() if wand != null else {}
		if npc_at(x, y) == "merchant" and not tm.is_empty() and merchant_niche_dir() == Vector2i.ZERO:
			_meet_merchant(tm)
			return true
		return false
	var on_change := func():
		bag_changed.emit()
		ctrl.changed.emit()
	if (level.get("treeCells", []) as Array).has("%d,%d" % [x, y]):
		if last_bump != "%d,%d" % [x, y]:
			_log(L.t("game.interactions.un_arbre_bloque_le_passage"))
		last_bump = "%d,%d" % [x, y]
		message.emit("Un arbre bloque le passage")
		return true
	match npc_at(x, y):
		"merchant":
			var mm: Dictionary = wand.merchant()
			mm["discovered"] = true
			_log(L.t("game.interactions.le_marchand_vous_accueille_et"))
			if mm.get("offers") == null:
				mm["offers"] = Shop.village_offers(gs.cfg, gs.run_number)
			ShopModal.open(host, gs, mm.offers, true, on_change)
			return true
		"blacksmith":
			_log(L.t("game.interactions.le_forgeron_vous_accueille_dans"))
			ForgeModal.open(host, gs, on_change)
			return true
		"talent":
			_log(L.t("game.interactions.le_maitre_des_talents_vous"))
			TalentModals.master(host, gs, on_change)
			return true
	return false

# ------------------------------------------------------------------ marchand itinérant

## Direction du mur où l'étal du marchand est logé (ZERO : pas de niche, il se tient sur sa case).
func merchant_niche_dir() -> Vector2i:
	if wand == null or bool(level.get("outdoor", false)):
		return Vector2i.ZERO
	var mm: Dictionary = wand.merchant()
	if mm.is_empty():
		return Vector2i.ZERO
	return LevelBuilder.merchant_niche_dir(grid, int(mm.x), int(mm.y))

## Le groupe, debout devant l'étal, avance contre le mur creusé : le marchand l'accueille. Renvoie true si c'est le cas.
func bump_merchant(tx: int, ty: int) -> bool:
	var nd := merchant_niche_dir()
	if nd == Vector2i.ZERO:
		return false
	var mm: Dictionary = wand.merchant()
	if rig.gx != int(mm.x) or rig.gy != int(mm.y) or Vector2i(tx - rig.gx, ty - rig.gy) != nd:
		return false
	mm["discovered"] = true
	if wand != null:
		wand.merchant_moved.emit()
	_log(L.t("game.interactions.un_marchand_ambulant_vous_salue"))
	open_merchant(mm)      # l'étal est dans le mur : on ne peut pas passer, donc pas de choix « continuer »
	return true

func _meet_merchant(mm: Dictionary) -> void:
	mm["discovered"] = true
	if wand != null:
		wand.merchant_moved.emit()
	_log(L.t("game.interactions.un_marchand_ambulant_vous_salue"))
	var m := Modal.open(host, L.t("common.marchand_ambulant"), 380)
	m.add_text(L.t("game.interactions.vous_croisez_le_marchand_ambulant"), UiTheme.DIM, 15, true)
	m.set_buttons([
		{"text": L.t("game.interactions.voir_son_etal"), "primary": true, "cb": func():
			m.close()
			open_merchant(mm)},
		{"text": L.t("game.interactions.continuer_sans_arreter"), "cb": func():
			m.close()
			_walk_through(mm)},
	])

## « Continuer sans s'arrêter » : le groupe passe sur la case du marchand, puis poursuit d'une case si elle est libre.
func _walk_through(mm: Dictionary) -> void:
	var rel := -1
	for r in 4:
		var v: Vector2i = DungeonGrid.DIRS[posmod(rig.dir + r, 4)]
		if rig.gx + v.x == int(mm.x) and rig.gy + v.y == int(mm.y):
			rel = r
	if rel < 0:
		return
	_pass_merchant = true
	rig.step(rel)
	if rig.gx != int(mm.x) or rig.gy != int(mm.y):
		_pass_merchant = false
		return
	await rig.moved
	_pass_merchant = false
	var v2: Vector2i = DungeonGrid.DIRS[posmod(rig.dir + rel, 4)]
	var nx := rig.gx + v2.x
	var ny := rig.gy + v2.y
	if rig.grid.is_walkable(nx, ny) and not (rig.extra_block.is_valid() and rig.extra_block.call(nx, ny)):
		rig.step(rel)

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
		_log(L.fa(L.t("game.interactions.l_onglet_est_plein_equipez"), [
			Inventory.TAB_LABELS[Inventory.tab_of(inst)], Inventory.MAX_PER_TAB, Inventory.MAX_PER_TAB, it.get("name", "l'objet")]))
		return
	Inventory.add(gs, inst)
	Sound.sfx("pickup")
	gs.item_state(_lid(), str(it.id))["taken"] = true
	_lstate().taken_items[str(it.id)] = true
	view.entities.remove_item(str(it.id))
	gs.stats["itemsFound"] = int(gs.stats.get("itemsFound", 0)) + 1
	_log(L.fa(L.t("game.interactions.le_groupe_ramasse"), it.get("name", L.t("game.interactions.un_objet"))))
	message.emit(L.fa(L.t("game.interactions.ramasse"), it.get("name", L.t("game.interactions.objet"))))
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
			_log(L.t("game.interactions.cette_porte_est_verrouillee"))
			message.emit(L.t("game.interactions.porte_verrouillee"))
			return false
		var key: Dictionary = gs.inventory[k]
		_log(L.fa(L.t("game.interactions.le_groupe_utilise_pour_deverrouiller"), key.get("name", L.t("game.interactions.la_cle"))))
		gs.inventory.remove_at(k)
		unlocked[str(d.id)] = true
		bag_changed.emit()
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
		_log(L.t("game.interactions.une_grille_de_fer_ferme"))
		message.emit(L.t("game.interactions.arche_verrouillee"))
		return false
	_log(L.fa(L.t("game.interactions.le_groupe_utilise_pour_ouvrir"), gs.inventory[k].get("name", L.t("game.interactions.la_cle"))))
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
	_log(L.fa(L.t("game.interactions.actionne"), it.get("name", "Levier")))
	var did := str(it.get("switchOpensDoorId", ""))
	if did != "":
		_lstate().get_or_add("door_unlocked", {})[did] = true
		_log(L.t("game.interactions.une_porte_se_deverrouille_au"))
	var mid := str(it.get("switchRevealMonsterId", ""))
	if mid != "":
		var mst: Dictionary = _lstate().monsters.get(mid, {})
		if not mst.is_empty() and mst.get("hidden", false):
			mst["hidden"] = false
			view.entities.set_monster_visible(mid, true)
			_log(L.t("game.interactions.une_presence_hostile_se_revele"))
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
			_log(L.t("game.interactions.un_objet_apparait_jusque_la"))
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
		_log(L.fa(L.t("game.interactions.est_tarie_pour_l_instant"), [it.get("name", L.t("game.interactions.la_fontaine")), int(ceil((ready_at - now) / 60000.0))]))
		return
	var m := Modal.open(host, L.t("game.interactions.fontaine"), 400)
	m.add_text(L.t("game.interactions.voulez_vous_utiliser_cette_fontaine"), UiTheme.PARCH, 14, true)
	m.set_buttons([
		{"text": L.t("game.interactions.utiliser_la_fontaine"), "primary": true, "cb": func():
			m.close()
			_use_fountain(it)},
		{"text": L.t("game.interactions.passer_sans_l_utiliser"), "primary": false, "cb": func(): m.close()},
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
	view.entities.refresh_fountains()
	ctrl.fx.emit("fountain")
	_log(L.fa(L.t("game.interactions.redonne_toutes_ses_forces_au"), it.get("name", L.t("game.interactions.la_fontaine"))))
	if not revived.is_empty():
		_log(L.fa(L.t("game.interactions.ramene_a_la_vie_par"), [", ".join(revived), "est" if revived.size() == 1 else "sont"]))
	ctrl.popup.emit(L.t("game.interactions.pv_endurance_restaures"), Color("3aa8c8"))
	ctrl.changed.emit()

# ------------------------------------------------------------------ pièges

func _trap_cfg() -> Dictionary:
	return TrapRules.cfg(gs.cfg)

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
	var s := _trap_cfg()
	var hit_random := func(mult: float): return _pick_victim(it, mult)
	var hit_char := func(id: String, mult: float): return _hit_for(it, gs.char_by_id(id), mult)
	var hit_all := func(mult: float):
		var out: Array = []
		for c in gs.alive_party():
			out.append(_hit_for(it, c, mult))
		return out
	var ctx := {"gs": gs, "s": s, "bd": trap_breakdown(), "offer": TrapRules.draw_offer(s, it, gs.item_state(_lid(), str(it.id))),
		"hit_random": hit_random, "hit_char": hit_char, "hit_all": hit_all}
	var m := TrapModal.open(host, it, ctx)
	m.skipped.connect(func():
		_log(L.t("game.interactions.piege_passe_en_force"), true)
		_apply_trap(it, float(s.skipDmgPct) / 100.0, {}))
	m.resolved.connect(func(res: Dictionary): _trap_resolved(it, res))

## Applique le résultat de la fenêtre : coût (endurance, objet sacrifié), désamorçage ou dégâts, puis butin.
func _trap_resolved(it: Dictionary, res: Dictionary) -> void:
	var sta: Dictionary = res.get("sta", {})
	if not sta.is_empty() and int(sta.get("amt", 0)) > 0:
		var c := gs.char_by_id(str(sta.id))
		if not c.is_empty():
			c["stamina"] = maxi(0, int(c.stamina) - int(sta.amt))
	var sac := int(res.get("sac_idx", -1))
	if sac >= 0 and sac < gs.inventory.size():
		var gone: Dictionary = gs.inventory[sac]
		gs.inventory.remove_at(sac)
		_log(L.fa(L.t("game.interactions.piege_objet_sacrifie"), L.c(str(gone.get("name", "?")))))
		bag_changed.emit()
	if bool(res.get("disarm", false)):
		gs.item_state(_lid(), str(it.id))["disarmed"] = true
		view.entities.remove_item(str(it.id))
		_log(L.fa(L.t("game.interactions.desamorce_par_le_groupe"), it.get("name", L.t("game.interactions.le_piege"))))
	else:
		_apply_trap_hits(it, res.get("hits", []))
	var rw: Dictionary = res.get("reward", {})
	if not rw.is_empty():
		_give_trap_reward(rw)
	ctrl.changed.emit()

func _give_trap_reward(rw: Dictionary) -> void:
	match str(rw.kind):
		"gold":
			gs.gold += int(rw.amount)
			gs.stats["goldEarnedTotal"] = int(gs.stats.get("goldEarnedTotal", 0)) + int(rw.amount)
			_log(L.fa(L.t("game.interactions.piege_butin_or"), int(rw.amount)))
			ctrl.popup.emit("+%d 💰" % int(rw.amount), Color("ffd76a"))
		"xp":
			for c in gs.alive_party():
				Characters.award_xp(gs, c, int(rw.amount))
			gs.stats["xpEarnedTotal"] = int(gs.stats.get("xpEarnedTotal", 0)) + int(rw.amount)
			_log(L.fa(L.t("game.interactions.piege_butin_xp"), int(rw.amount)))
			ctrl.popup.emit("+%d XP" % int(rw.amount), Color("8fd0ff"))
		"heal":
			for c in gs.alive_party():
				c["hp"] = mini(int(c.maxHp), int(c.hp) + int(ceil(float(c.maxHp) * float(rw.amount) / 100.0)))
			_log(L.fa(L.t("game.interactions.piege_butin_soin"), int(rw.amount)))
			ctrl.popup.emit("+%d %% PV" % int(rw.amount), Color("7fe08a"))
			Sound.sfx("heal")

func _pick_victim(it: Dictionary, mult: float) -> Dictionary:
	var alive := gs.alive_party()
	var victim: Dictionary = alive[randi() % alive.size()] if not alive.is_empty() else gs.char_by_id(gs.active_char_id)
	return _hit_for(it, victim, mult)

## Dégâts du piège sur un personnage donné : le plus fort du pourcentage de PV max et du forfait de l'objet, × mult.
func _hit_for(it: Dictionary, victim: Dictionary, mult: float) -> Dictionary:
	var s := _trap_cfg()
	var pct := randi_range(int(round(float(s.dmgPctMin))), int(round(float(s.dmgPctMax))))
	var pct_dmg := int(ceil(float(victim.get("maxHp", 1)) * pct / 100.0))
	var dmin := int(it.get("trapDmgMin", 0)) if int(it.get("trapDmgMin", 0)) > 0 else 1
	var dmax := int(it.get("trapDmgMax", 0)) if int(it.get("trapDmgMax", 0)) > 0 else 4
	var flat := randi_range(dmin, maxi(dmin, dmax))
	return {"victim": victim, "dmg": maxi(1, int(round(maxi(pct_dmg, flat) * mult)))}

func _apply_trap(it: Dictionary, mult: float, pre: Dictionary) -> void:
	_apply_trap_hits(it, [pre if not pre.is_empty() else _pick_victim(it, mult)])

## Le piège se déclenche : il disparaît (sauf piège permanent) et chaque coup de `hits` est appliqué.
func _apply_trap_hits(it: Dictionary, hits: Array) -> void:
	if not bool(it.get("permanent", false)):
		gs.item_state(_lid(), str(it.id))["taken"] = true
		view.entities.remove_item(str(it.id))     # piège à usage unique : il disparaît une fois déclenché
	ctrl.fx.emit("trap")
	gs.stats["trapsTriggered"] = int(gs.stats.get("trapsTriggered", 0)) + 1
	for hit in hits:
		var victim: Dictionary = hit.victim
		victim["hp"] = maxi(0, int(victim.hp) - int(hit.dmg))
		gs.bump(victim.id, "damageTaken", int(hit.dmg))
		if int(victim.hp) <= 0:
			gs.bump(victim.id, "knockdowns")
		_log(L.fa(L.t("game.interactions.piege_declenche_subit_degats"), [it.get("name", ""), victim.name, int(hit.dmg)]), true)
		ctrl.popup.emit("-%d" % int(hit.dmg), Color("ff6a6a"))
		if int(victim.hp) <= 0:
			_log(L.fa(L.t("common.effondre_a_terre"), victim.name))
	if gs.alive_party().is_empty():
		gs.game_over = true
		_log(L.t("common.le_groupe_est_aneanti_les"))
		ctrl.game_over.emit()
	elif gs.char_by_id(gs.active_char_id).is_empty() or int(gs.char_by_id(gs.active_char_id).hp) <= 0:
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
	var m := Modal.open(host, L.t("game.interactions.choisir_un_parchemin"), 420)
	for g in groups:
		var it2: Dictionary = g.it
		var idx2: int = g.idx
		var sp := ctrl.combat.spell_def(str(it2.get("spellId", "")))
		var label := str(sp.get("name", it2.get("name", L.t("common.parchemin"))))
		if int(g.count) > 1:
			label += "  ×%d" % int(g.count)
		m.add_row(IconResolver.texture(str(it2.get("icon", ""))), "\n".join(SpellTip.lines(sp)) if not sp.is_empty() else L.t("game.interactions.parchemin_illisible"))
		m.add_button(label, func():
			m.close()
			ctrl.read_scroll(char_id, idx2)
			bag_changed.emit())

func open_item_menu(idx: int) -> void:
	if idx < 0 or idx >= gs.inventory.size():
		return
	var it: Dictionary = gs.inventory[idx]
	var m := Modal.open(host, str(it.get("name", L.t("common.objet"))), 400)
	m.add_row(IconResolver.texture(str(it.get("icon", ""))), "\n".join(Inventory.describe(it, gs.cfg)))
	var type := str(it.get("type", ""))
	var alive := gs.alive_party()
	var fighting := ctrl.in_combat()
	if type == "potion":
		m.add_text(L.t("game.interactions.faire_boire_a"), UiTheme.DIM, 14, true)
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
		m.add_text(L.t("game.interactions.faire_lire_a"), UiTheme.DIM, 14, true)
		for c in alive:
			var cid2: String = str(c.id)
			m.add_button(str(c.name), func():
				m.close()
				ctrl.read_scroll(cid2, idx)
				bag_changed.emit())
	elif Inventory.can_equip(it) and not fighting:
		m.add_text(L.t("game.interactions.equiper_sur"), UiTheme.DIM, 14, true)
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
		buttons.append({"text": L.t("common.jeter"), "cb": func():
			m.close()
			Inventory.discard(gs, idx)
			bag_changed.emit()})
	buttons.append({"text": L.t("common.fermer"), "cb": func(): m.close()})
	m.set_buttons(buttons)

# ------------------------------------------------------------------ fiche de personnage

func open_sheet(char_id: String) -> void:
	if gs.char_by_id(char_id).is_empty():
		return
	PartyModal.open(host, gs, char_id)

static func spell_effect(sp: Dictionary) -> String:
	match str(sp.get("mode", "")):
		"damage": return L.fa(L.t("game.interactions.degats"), [int(sp.get("dmgMin", 0)), int(sp.get("dmgMax", 0))])
		"damageGroup": return L.fa(L.t("game.interactions.degats_de_groupe"), [int(sp.get("dmgMin", 0)), int(sp.get("dmgMax", 0))])
		"healSingle": return L.fa(L.t("game.interactions.soin"), [int(sp.get("healMin", 0)), int(sp.get("healMax", 0))])
		"healParty": return L.fa(L.t("game.interactions.soin_de_groupe"), [int(sp.get("healMin", 0)), int(sp.get("healMax", 0))])
		"staminaRestoreSingle": return L.fa(L.t("game.interactions.endurance"), [int(sp.get("staminaMin", 0)), int(sp.get("staminaMax", 0))])
		"shieldSingle": return L.fa(L.t("game.interactions.bouclier"), [int(sp.get("shieldMin", 0)), int(sp.get("shieldMax", 0))])
		"dispelSingle": return L.t("game.interactions.retire_les_statuts_negatifs_un")
		"sleepGroup": return L.fa(L.t("game.interactions.endort_l_ennemi_engage_de"), int(sp.get("statusChance", 0)))
		"selfBuff": return L.fa(L.t("game.interactions.ameliore_le_lanceur_tours"), int(sp.get("statusDuration", 0)))
		"partyUtility": return L.fa(L.t("game.interactions.recharges_et_vigueur_pour_tout"), int(sp.get("cooldownReductionSec", 0)))
	return str(sp.get("mode", L.t("game.interactions.effet_special")))
