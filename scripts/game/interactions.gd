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
	var diff := str(gs.cfg.get("genDifficulty", "normal")) if Data.play_origin == "random" else "normal"
	var healed := ExploreRegen.on_step(gs, Vector2i(rig.gx, rig.gy), diff, ctrl.model_in_combat())
	for cid in healed:
		ctrl.popup.emit("+%d" % int(healed[cid]), Color("7fe08a"), "char:" + str(cid))

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
			"pendulum": _cross_pendulum(it)
			"fountain":
				# fontaine logée dans un décroché : on l'utilise en avançant vers elle (comme une porte), pas en passant dessus
				if LevelBuilder.fountain_niche_dir(grid, int(it.x), int(it.y), str(it.id)) == Vector2i.ZERO or bool(level.get("outdoor", false)):
					_prompt_fountain(it)
			"chest", "switch":
				continue      # coffres et leviers s'actionnent au clic ou avec la touche d'action, plus en marchant dessus
			"decor": _activate_decor(it)
			_:
				if PICKUP_TYPES.has(str(it.get("type", ""))):
					_pickup(it)
					continue  # tout le butin de la case est ramassé d'un coup
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
				mm["offers"] = Shop.village_offers(gs.cfg, gs.run_number, gs.party)
			_open_shop(mm.offers, true, on_change)
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
		{"text": L.t("game.interactions.voir_son_etal"), "primary": true, "cb": func(): Flows.choose("marchand", 1)},
		{"text": L.t("game.interactions.continuer_sans_arreter"), "cb": func(): Flows.choose("marchand", 0)},
	])
	Flows.open("marchand", m, func(choice: Variant):
		if int(choice) == 1:
			open_merchant(mm)
		else:
			_walk_through(mm))

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
	rig.step(rel, true)
	if rig.gx != int(mm.x) or rig.gy != int(mm.y):
		_pass_merchant = false
		return
	await rig.moved
	_pass_merchant = false
	var v2: Vector2i = DungeonGrid.DIRS[posmod(rig.dir + rel, 4)]
	var nx := rig.gx + v2.x
	var ny := rig.gy + v2.y
	if rig.grid.is_walkable(nx, ny) and not (rig.extra_block.is_valid() and rig.extra_block.call(nx, ny)):
		rig.step(rel, true)

## Boutique : le jeu est en pause tant qu'elle est ouverte (monde 3D figé, délais de sorts et de fontaines gelés) ; seul le marchand est actif.
func _open_shop(offers: Array, village: bool, on_change: Callable) -> void:
	var resume := _freeze_world()
	var m := ShopModal.open(host, gs, offers, village, on_change)
	m.tree_exited.connect(resume)

## Fige le monde et renvoie la fonction qui le relance (en rendant le temps écoulé aux délais qui courent en temps réel).
func _freeze_world() -> Callable:
	if _frozen:
		return func(): pass
	_frozen = true
	GameClock.frozen += 1          # le temps de jeu (recharge des sorts, fontaines) s'arrête tant que le monde est figé
	if view != null:
		view.process_mode = Node.PROCESS_MODE_DISABLED
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	return func():
		_frozen = false
		if view != null and is_instance_valid(view):
			view.process_mode = Node.PROCESS_MODE_INHERIT
		if rig != null and is_instance_valid(rig):
			rig.process_mode = Node.PROCESS_MODE_INHERIT
		GameClock.frozen = maxi(0, GameClock.frozen - 1)
		ctrl.changed.emit()

var _frozen := false

func open_merchant(mm: Dictionary) -> void:
	if mm.get("offers") == null:
		mm["offers"] = Shop.merchant_offers(gs.cfg, level.get("travelingMerchant", {}), maxi(1, gs.run_number), gs.party)
	var on_change := func():
		bag_changed.emit()
		ctrl.changed.emit()
	_open_shop(mm.offers, false, on_change)

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

# ------------------------------------------------------------------ coffres

## Le groupe arrive sur la case d'un coffre : il s'ouvre (couvercle animé) et livre son or puis ses objets. Un objet qui ne tient plus dans
## le sac reste dans le coffre : on peut revenir le prendre plus tard (le coffre reste ouvert). État : opened, goldTaken, took{}, emptied.
## Contenu d'un coffre : objets embarqués (coffres générés) ou, pour un coffre posé dans l'éditeur, objets de la bibliothèque (`contentIds`).
func _chest_contents(it: Dictionary) -> Array:
	var out: Array = it.get("contents", []).duplicate()
	var slot := 0
	for id in it.get("contentIds", []):
		slot += 1
		if str(id) == "":
			continue
		for def in gs.cfg.get("itemLibrary", []):
			if def.get("id") == id:
				var c: Dictionary = def.duplicate(true)
				c["id"] = "chestlib_%s_%d" % [str(it.id), slot]
				out.append(c)
				break
	return out

## Ce que la touche d'action (ou un clic sur l'objet) déclenche ici : coffre ou levier sur la case du groupe ou juste devant lui, ou objet au sol
## de la case. Renvoie {} s'il n'y a rien ; sinon {"it": définition, "kind": "chest"|"switch"|"pickup", "cell": Vector2i}.
func interact_target() -> Dictionary:
	if level.is_empty() or rig == null:
		return {}
	var v: Vector2i = DungeonGrid.DIRS[rig.dir]
	var cells: Array = [Vector2i(rig.gx, rig.gy), Vector2i(rig.gx + v.x, rig.gy + v.y)]
	for ci in cells.size():
		var c: Vector2i = cells[ci]
		for it in level.get("items", []):
			if int(it.x) != c.x or int(it.y) != c.y:
				continue
			var st := gs.item_state(_lid(), str(it.id))
			if st.get("taken", false) or st.get("disarmed", false) or st.get("hidden", bool(it.get("startHidden", false))):
				continue
			match str(it.get("type", "")):
				"chest":
					if not st.get("emptied", false):
						return {"it": it, "kind": "chest", "cell": c}
				"switch":
					if not st.get("triggered", false):
						return {"it": it, "kind": "switch", "cell": c}
				_:
					if ci == 0 and PICKUP_TYPES.has(str(it.get("type", ""))):
						return {"it": it, "kind": "pickup", "cell": c}
	return {}

## Texte d'invite affiché dans la vue (« [F] Ouvrir le coffre »), vide s'il n'y a rien à faire.
func interact_hint() -> String:
	var t := interact_target()
	if t.is_empty():
		return ""
	var key := Keybinds.text("interact").get_slice(" ", 0)
	match str(t.kind):
		"chest": return "[%s] %s" % [key, L.t("game.interactions.hint_chest")]
		"switch": return "[%s] %s" % [key, L.t("game.interactions.hint_switch")]
	return "[%s] %s" % [key, L.fa(L.t("game.interactions.hint_pickup"), str(t.it.get("name", "")))]

## Un clic de souris (coordonnées de la fenêtre) sur le coffre, le levier ou l'objet au sol désigné par `interact_target` les déclenche.
func click_interact(mouse: Vector2) -> bool:
	var t := interact_target()
	if t.is_empty() or rig == null or rig.camera == null or layout == null or layout.sub_container == null:
		return false
	var node: Node3D = null
	for e in view.entities.items.get(t.cell, []):
		if str(e.def.id) == str(t.it.id) and is_instance_valid(e.node):
			node = e.node
	if node == null or not node.visible:
		return false
	var cam := rig.camera
	var centre: Vector3 = node.global_position + Vector3(0.0, 0.35 if str(t.kind) == "chest" else 0.0, 0.0)
	if cam.is_position_behind(centre):
		return false
	var local := mouse - layout.sub_container.global_position
	var p := cam.unproject_position(centre)
	var edge := cam.unproject_position(centre + cam.global_transform.basis.x * 0.8)
	var radius := maxf(48.0, p.distance_to(edge))
	if local.distance_to(p) > radius:
		return false
	return interact_here()

## Touche d'action ou clic sur l'objet : exécute ce que `interact_target` désigne. Renvoie faux s'il n'y avait rien.
func interact_here() -> bool:
	var t := interact_target()
	if t.is_empty():
		return false
	match str(t.kind):
		"chest": _open_chest(t.it)
		"switch": _trigger_switch(t.it)
		"pickup": _pickup(t.it)
	return true

func _open_chest(it: Dictionary) -> void:
	var st := gs.item_state(_lid(), str(it.id))
	if st.get("emptied", false):
		return
	if not st.get("opened", false):
		st["opened"] = true
		Sound.sfx("wood_thud")
		view.entities.open_chest(str(it.id), true)
		_log(L.t("game.interactions.le_groupe_ouvre_un_coffre"))
		message.emit(L.t("game.interactions.coffre_ouvert"))
	var gold := int(it.get("gold", 0))
	if gold > 0 and not st.get("goldTaken", false):
		st["goldTaken"] = true
		gs.gold += gold
		gs.stats["goldEarnedTotal"] = int(gs.stats.get("goldEarnedTotal", 0)) + gold
		Sound.sfx("coins")
		_log(L.fa(L.t("game.interactions.coffre_or"), gold))
		ctrl.popup.emit("+%d 💰" % gold, Color("ffd76a"), "")
	var took: Dictionary = st.get_or_add("took", {})
	# Chaque objet jaillit du coffre d'un petit saut et retombe à sa propre place sur le sol (jamais empilés). Ceux qui tiennent dans la besace
	# y entrent d'eux-mêmes (le butin s'efface après l'atterrissage) ; les autres restent au sol, ramassables plus tard : rien n'est perdu.
	var wd: Vector2i = EntityLayer.WALL_SIDES.get(str(it.get("wall", "N")), EntityLayer.WALL_SIDES["N"])["d"]
	var away := atan2(float(wd.y), float(wd.x))      # direction du mur du coffre : le butin retombe devant lui
	var cell := Vector2i(int(it.x), int(it.y))
	var contents: Array = []
	for c in _chest_contents(it):
		if not took.has(str(c.id)):
			contents.append(c)
	var spill: Array = []
	var reserved: Array = []
	for c in contents:
		var inst := Inventory.make_instance(c)
		took[str(c.id)] = true
		var slot := Inventory.free_slot(level, cell.x, cell.y, reserved)
		reserved.append(slot)
		if Inventory.has_space(gs, inst):
			Inventory.add(gs, inst)
			Sound.sfx("pickup")
			gs.stats["itemsFound"] = int(gs.stats.get("itemsFound", 0)) + 1
			_log(L.fa(L.t("game.interactions.le_groupe_ramasse"), c.get("name", L.t("game.interactions.un_objet"))))
			spill.append({"def": c, "keep": false, "slot": slot})
		else:
			_log(L.fa(L.t("game.interactions.l_onglet_est_plein_equipez"), [
				Inventory.TAB_LABELS[Inventory.tab_of(inst)], Inventory.MAX_PER_TAB, Inventory.MAX_PER_TAB, c.get("name", "l'objet")]))
			var drop := Inventory.drop_to_floor(gs, level, c, cell.x, cell.y, away, slot)
			spill.append({"def": drop, "keep": true, "slot": slot})
	st["emptied"] = true
	view.entities.empty_chest(str(it.id))
	if not spill.is_empty():
		view.entities.spill_loot(str(it.id), cell, away, spill)
	bag_changed.emit()
	ctrl.changed.emit()

# ------------------------------------------------------------------ portes et escaliers

## Le groupe se heurte à une porte fermée. Renvoie true si elle vient de s'ouvrir.
func try_door(x: int, y: int) -> bool:
	var d := grid.door_at(x, y)
	if d.is_empty() or grid.is_open(str(d.id)) or grid.is_opening(str(d.id)):
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
	if grid.is_opening(str(st.id)):
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
	view.entities.pull_switch(str(it.id))
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
			ctrl.combat.mark_monsters_dirty()
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
	var pid := str(it.get("switchDisarmsId", ""))      # levier de contrepoids : bloque la hache pendulaire du niveau
	if pid != "":
		var pst := gs.item_state(_lid(), pid)
		if not pst.get("disarmed", false):
			pst["disarmed"] = true
			view.entities.disarm_item(pid)
			_log(L.t("game.interactions.pendule_bloque"))
	if str(it.get("message", "")) != "":
		_log(str(it.message))

# ------------------------------------------------------------------ hache pendulaire

## Le groupe entre sous la hache : chaque héros tente de l'esquiver (Dextérité, voir `TrapRules.pendulum_dodge`), les autres sont touchés.
## Le piège reste actif à chaque passage tant que le levier de contrepoids (`leverId`) n'a pas été tiré. Aucune fenêtre : tout est tiré dans
## le flux « trap », donc rejouable à l'identique.
func _cross_pendulum(it: Dictionary) -> void:
	gs.stats["pendulumTicks"] = 0
	var s := _trap_cfg()
	var st := gs.item_state(_lid(), str(it.id))
	_log(L.t("game.interactions.pendule_balaie"))
	var hits: Array = []
	var dodged: Array = []
	for c in gs.alive_party():
		if GameRng.f("trap") * 100.0 < float(TrapRules.pendulum_dodge(c, s)):
			dodged.append(str(c.name))
			ctrl.popup.emit(L.t("rules.combat.esquive"), Color("9fd8ff"), "char:" + str(c.id))
		else:
			hits.append(_hit_for(it, c, float(s.pendulumDmgPct) / 100.0))
	if not st.get("known", false):       # première fois : les gravures des fentes mettent sur la piste du levier
		st["known"] = true
		var lever := _find_item(str(it.get("leverId", "")))
		if not lever.is_empty():
			var dx := int(lever.x) - int(it.x)
			var dy := int(lever.y) - int(it.y)
			var key := ("game.interactions.cap_est" if dx > 0 else "game.interactions.cap_ouest") if absi(dx) > absi(dy) else ("game.interactions.cap_sud" if dy > 0 else "game.interactions.cap_nord")
			_log(L.fa(L.t("game.interactions.pendule_indice"), L.t(key)))
	if hits.is_empty():
		_log(L.t("game.interactions.pendule_indemne"))
		return
	if not dodged.is_empty():
		_log(L.fa(L.t("game.interactions.pendule_esquive"), ", ".join(PackedStringArray(dodged))))
	_apply_trap_hits(it, hits)

## Appelé à chaque pas de monstres (0,5 s) : tant que le groupe reste sur la case d'une hache encore armée, la lame repasse
## toutes les PENDULUM_REPEAT_TICKS pas et chaque héros retente son esquive (même jet que lors de la traversée).
const PENDULUM_REPEAT_TICKS := 4
func pendulum_idle_tick() -> void:
	if gs.game_over or gs.won:
		return
	for it in level.get("items", []):
		if str(it.get("type", "")) != "pendulum" or int(it.x) != rig.gx or int(it.y) != rig.gy:
			continue
		var st := gs.item_state(_lid(), str(it.id))
		if st.get("taken", false) or st.get("disarmed", false) or st.get("hidden", bool(it.get("startHidden", false))):
			continue
		var n := int(gs.stats.get("pendulumTicks", 0)) + 1
		if n >= PENDULUM_REPEAT_TICKS:
			_cross_pendulum(it)      # remet le compteur à zéro
		else:
			gs.stats["pendulumTicks"] = n
		return
	gs.stats["pendulumTicks"] = 0

func _find_item(id: String) -> Dictionary:
	for d in level.get("items", []):
		if str(d.id) == id:
			return d
	return {}

# ------------------------------------------------------------------ fontaine

func _fountain_cooldown_ms() -> float:
	return maxf(5.0, float(gs.cfg.get("fountainCooldownMinutes", 10))) * 60000.0

func _prompt_fountain(it: Dictionary) -> void:
	var st := gs.item_state(_lid(), str(it.id))
	var now := float(GameClock.ms)
	var ready_at := float(st.get("usedAt", 0.0)) + _fountain_cooldown_ms()
	if st.has("usedAt") and now < ready_at:
		_log(L.fa(L.t("game.interactions.est_tarie_pour_l_instant"), [it.get("name", L.t("game.interactions.la_fontaine")), int(ceil((ready_at - now) / 60000.0))]))
		return
	var m := Modal.open(host, L.t("game.interactions.fontaine"), 400)
	m.add_text(L.t("game.interactions.voulez_vous_utiliser_cette_fontaine"), UiTheme.PARCH, 14, true)
	m.set_buttons([
		{"text": L.t("game.interactions.utiliser_la_fontaine"), "primary": true, "cb": func(): Flows.choose("fontaine", 1)},
		{"text": L.t("game.interactions.passer_sans_l_utiliser"), "primary": false, "cb": func(): Flows.choose("fontaine", 0)},
	])
	Flows.open("fontaine", m, func(choice: Variant):
		if int(choice) == 1:
			_use_fountain(it), 0)

func _use_fountain(it: Dictionary) -> void:
	var st := gs.item_state(_lid(), str(it.id))
	st["usedAt"] = float(GameClock.ms)
	gs.stats["fountainsUsed"] = int(gs.stats.get("fountainsUsed", 0)) + 1
	var revived: Array[String] = []
	for c in gs.party:
		if int(c.hp) <= 0:
			revived.append(str(c.name))
		c["hp"] = c.maxHp
		c["stamina"] = c.get("maxStamina", 100)
	Sound.fountain()
	view.entities.refresh_fountains()
	ctrl.fx.emit("fountain")
	_log(L.fa(L.t("game.interactions.redonne_toutes_ses_forces_au"), it.get("name", L.t("game.interactions.la_fontaine"))))
	if not revived.is_empty():
		_log(L.fa(L.t("game.interactions.ramene_a_la_vie_par"), [", ".join(revived), "est" if revived.size() == 1 else "sont"]))
	ctrl.popup.emit(L.t("game.interactions.pv_endurance_restaures"), Color("3aa8c8"), "")
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
	Flows.open("trap", m, func(a: Variant): m.apply_input(a as Array), null, func(a: Variant): return a is Array and m.can_input(a as Array))
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
	for e in res.get("sta_list", []):       # « Effort collectif » : chaque héros vivant paie
		var ce := gs.char_by_id(str(e.id))
		if not ce.is_empty():
			ce["stamina"] = maxi(0, int(ce.stamina) - int(e.amt))
	var sac := int(res.get("sac_idx", -1))
	if sac >= 0 and sac < gs.inventory.size():
		var gone: Dictionary = gs.inventory[sac]
		gs.inventory.remove_at(sac)
		_log(L.fa(L.t("game.interactions.piege_objet_sacrifie"), L.c(str(gone.get("name", "?")))))
		bag_changed.emit()
	if bool(res.get("disarm", false)):
		gs.item_state(_lid(), str(it.id))["disarmed"] = true
		view.entities.disarm_item(str(it.id))
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
			ctrl.popup.emit("+%d 💰" % int(rw.amount), Color("ffd76a"), "")
		"xp":
			for c in gs.alive_party():
				Characters.award_xp(gs, c, int(rw.amount))
			gs.stats["xpEarnedTotal"] = int(gs.stats.get("xpEarnedTotal", 0)) + int(rw.amount)
			_log(L.fa(L.t("game.interactions.piege_butin_xp"), int(rw.amount)))
			ctrl.popup.emit("+%d XP" % int(rw.amount), Color("8fd0ff"), "")
		"heal":
			for c in gs.alive_party():
				c["hp"] = mini(int(c.maxHp), int(c.hp) + int(ceil(float(c.maxHp) * float(rw.amount) / 100.0)))
			_log(L.fa(L.t("game.interactions.piege_butin_soin"), int(rw.amount)))
			ctrl.popup.emit("+%d %% PV" % int(rw.amount), Color("7fe08a"), "")
			Sound.sfx("heal")

func _pick_victim(it: Dictionary, mult: float) -> Dictionary:
	var alive := gs.alive_party()
	var victim: Dictionary = alive[GameRng.i("trap") % alive.size()] if not alive.is_empty() else gs.char_by_id(gs.active_char_id)
	return _hit_for(it, victim, mult)

## Dégâts du piège sur un personnage donné : le plus fort du pourcentage de PV max et du forfait de l'objet, × mult.
func _hit_for(it: Dictionary, victim: Dictionary, mult: float) -> Dictionary:
	var s := _trap_cfg()
	var pct := GameRng.range_i("trap", int(round(float(s.dmgPctMin))), int(round(float(s.dmgPctMax))))
	var pct_dmg := int(ceil(float(victim.get("maxHp", 1)) * pct / 100.0))
	var dmin := int(it.get("trapDmgMin", 0)) if int(it.get("trapDmgMin", 0)) > 0 else 1
	var dmax := int(it.get("trapDmgMax", 0)) if int(it.get("trapDmgMax", 0)) > 0 else 4
	var flat := GameRng.range_i("trap", dmin, maxi(dmin, dmax))
	return {"victim": victim, "dmg": maxi(1, int(round(maxi(pct_dmg, flat) * mult)))}

func _apply_trap(it: Dictionary, mult: float, pre: Dictionary) -> void:
	_apply_trap_hits(it, [pre if not pre.is_empty() else _pick_victim(it, mult)])

## Le piège se déclenche : il disparaît (sauf piège permanent) et chaque coup de `hits` est appliqué.
func _apply_trap_hits(it: Dictionary, hits: Array) -> void:
	if not bool(it.get("permanent", false)):
		gs.item_state(_lid(), str(it.id))["taken"] = true
		view.entities.remove_item(str(it.id))     # piège à usage unique : il disparaît une fois déclenché
	view.entities.fire_item(str(it.id))
	ctrl.fx.emit("trap")
	gs.stats["trapsTriggered"] = int(gs.stats.get("trapsTriggered", 0)) + 1
	for hit in hits:
		var victim: Dictionary = hit.victim
		victim["hp"] = maxi(0, int(victim.hp) - int(hit.dmg))
		gs.bump(victim.id, "damageTaken", int(hit.dmg))
		if int(victim.hp) <= 0:
			gs.bump(victim.id, "knockdowns")
		_log(L.fa(L.t("game.interactions.piege_declenche_subit_degats"), [it.get("name", ""), victim.name, int(hit.dmg)]), true)
		ctrl.popup.emit("-%d" % int(hit.dmg), Color("ff6a6a"), "char:" + str(victim.id))
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
	if Actions.drink(char_id, idx) >= 0:
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
					var healed := Actions.drink(cid, idx)
					m.close()
					if healed >= 0:
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
				Actions.equip(cid3, idx)
				bag_changed.emit())
	var buttons: Array = []
	if type != "key" and not fighting:
		buttons.append({"text": L.t("common.jeter"), "cb": func():
			m.close()
			Actions.discard(idx)
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
