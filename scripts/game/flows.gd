class_name Flows
extends RefCounted
## Fenêtres de DÉCISION (fontaine, talent, évolution, piège…) : les choix du joueur sont des commandes du journal (`["ui", flux, choix]`).
## Au rejeu, la fenêtre s'ouvre toute seule (la logique qui l'ouvre est la même) et les choix enregistrés y sont appliqués : on ne peut
## donc choisir QUE parmi ce que la fenêtre proposait réellement.
##
## Deux formes :
##  - décision unique : `Flows.open(flux, fenetre, gestionnaire, defaut)` puis `Flows.choose(flux, choix)` (ferme la fenêtre) ;
##    fermer la fenêtre autrement (Échap…) revient à choisir `defaut` (sans `defaut`, elle se ferme sans décision) ;
##  - fenêtre à étapes (piège) : `Flows.open(flux, fenetre, gestionnaire, null, peut)` puis `Flows.input(flux, entree)` à chaque action ;
##    `peut(entree)` dit si la fenêtre accepte l'entrée à cet instant (seules les entrées acceptées sont journalisées) ;
##    la fenêtre se termine par `Flows.close(flux)`.

static var _open: Dictionary = {}     # flux -> {"modal", "handler", "default", "can"}

static func open(flow: String, modal: Node, handler: Callable, default: Variant = null, can: Callable = Callable()) -> void:
	_open[flow] = {"modal": modal, "handler": handler, "default": default, "can": can}
	modal.set_meta("flow", flow)
	var gone := func():
		var e: Dictionary = _open.get(flow, {})
		if not e.is_empty() and e.modal == modal:
			if default == null:
				_open.erase(flow)        # fermée sans décision (changement de scène…) : rien n'est choisi
			else:
				choose(flow, default)
	if modal.has_signal("closed"):
		modal.connect("closed", gone)
	else:
		modal.tree_exiting.connect(func():
			var e: Dictionary = _open.get(flow, {})
			if not e.is_empty() and e.modal == modal:
				_open.erase(flow))

## Rejeu : applique un choix journalisé selon la forme de la fenêtre (étapes → input, décision unique → choose).
static func apply(flow: String, choice: Variant) -> bool:
	var e: Dictionary = _open.get(flow, {})
	if e.is_empty() or not is_open(flow):
		return false
	if (e.can as Callable).is_valid():
		return input(flow, choice)
	choose(flow, choice)
	return true

static func is_multi(flow: String) -> bool:
	var e: Dictionary = _open.get(flow, {})
	return not e.is_empty() and (e.can as Callable).is_valid()

static func is_open(flow: String) -> bool:
	var e: Dictionary = _open.get(flow, {})
	return not e.is_empty() and is_instance_valid(e.modal) and not (e.modal as Node).is_queued_for_deletion()

## Un flux est-il ouvert (n'importe lequel) ?
static func any_open() -> bool:
	for f in _open.keys():
		if is_open(str(f)):
			return true
	return false

## L'entrée est-elle acceptable maintenant ? (fenêtre à étapes)
static func can_input(flow: String, entry: Variant) -> bool:
	var e: Dictionary = _open.get(flow, {})
	if e.is_empty() or not is_open(flow):
		return false
	var can: Callable = e.can
	return not can.is_valid() or bool(can.call(entry))

static func choose(flow: String, choice: Variant) -> void:
	var e: Dictionary = _open.get(flow, {})
	if e.is_empty():
		return
	_open.erase(flow)
	RunLog.rec("ui", flow, choice)
	if is_instance_valid(e.modal) and (e.modal as Node).has_method("close") and not (e.modal as Node).is_queued_for_deletion():
		e.modal.call("close")
	RunLog.enter()
	(e.handler as Callable).call(choice)
	RunLog.leave()

## Entrée dans une fenêtre à étapes : journalisée si la fenêtre l'accepte, puis transmise.
static func input(flow: String, entry: Variant) -> bool:
	if not can_input(flow, entry):
		return false
	var e: Dictionary = _open[flow]
	RunLog.rec("ui", flow, entry)
	RunLog.enter()
	(e.handler as Callable).call(entry)
	RunLog.leave()
	return true

## Fin d'une fenêtre à étapes.
static func close(flow: String) -> void:
	_open.erase(flow)

static func reset() -> void:
	_open.clear()
