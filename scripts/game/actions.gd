class_name Actions
extends RefCounted
## Façade des actions du joueur sur la partie (inventaire, équipement, potions…). L'interface ET le rejeu passent par ici :
##  - la commande est journalisée (RunLog) à l'endroit où la logique l'accepte ;
##  - les conditions d'acceptation (« pas d'équipement en plein combat »…) vivent ICI et non dans l'interface, sinon un journal
##    falsifié les contournerait au rejeu.

static var gs: GameState = null
static var ctrl: CombatController = null

static func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller

## Partie classée : une action n'est acceptée qu'au repos du jeu (même ordre des événements en direct et en rejeu).
static func _allowed() -> bool:
	if gs == null or ctrl == null or gs.game_over:
		return false
	if RunLog.ranked() and not RunLog.replaying and not ctrl.is_settled():
		return false
	return true

static func _fighting() -> bool:
	return ctrl.model_in_combat()

## Équiper l'objet n° `idx` de la besace sur le personnage (hors combat).
static func equip(char_id: String, idx: int) -> bool:
	if not _allowed() or _fighting():
		return false
	var c := gs.char_by_id(char_id)
	if c.is_empty():
		return false
	RunLog.rec("eq", char_id, idx)
	RunLog.enter()
	var ok := Inventory.equip(gs, c, idx)
	RunLog.leave()
	if ok:
		ctrl.changed.emit()
	return ok

static func unequip(char_id: String, slot: String) -> bool:
	if not _allowed() or _fighting():
		return false
	var c := gs.char_by_id(char_id)
	if c.is_empty():
		return false
	RunLog.rec("un", char_id, slot)
	RunLog.enter()
	var ok := Inventory.unequip(gs, c, slot)
	RunLog.leave()
	if ok:
		ctrl.changed.emit()
	return ok

static func discard(idx: int) -> bool:
	if not _allowed() or _fighting():
		return false
	RunLog.rec("drop", idx)
	RunLog.enter()
	var ok := Inventory.discard(gs, idx)
	RunLog.leave()
	return ok

## Range un onglet de la besace (par type, puissance ou nom).
static func sort(tab: String, mode: String) -> void:
	if not _allowed() or _fighting() or not Inventory.SORT_MODES.has(mode):
		return
	RunLog.rec("sort", tab, mode)
	RunLog.enter()
	Inventory.sort_tab(gs, tab, mode)
	RunLog.leave()

## Un personnage boit la potion n° `idx`. En combat, seul le personnage actif peut boire. Renvoie les PV rendus (-1 si impossible).
static func drink(char_id: String, idx: int) -> int:
	if not _allowed():
		return -1
	var c := gs.char_by_id(char_id)
	if c.is_empty() or (_fighting() and char_id != gs.active_char_id):
		return -1
	RunLog.rec("drink", char_id, idx)
	RunLog.enter()
	var healed := Inventory.use_potion(gs, c, idx)
	RunLog.leave()
	if healed >= 0:
		ctrl.potion_drunk(char_id, healed)
	return healed
