class_name GameRng
extends RefCounted
## Hasard des RÈGLES du jeu (combat, butin, marchand, pièges, errance des monstres…) : des flux nommés tirés d'une graine unique.
## Avec la même graine et les mêmes actions, la partie se déroule à l'identique : c'est la base de la vérification des parties
## classées (le serveur rejoue la partie). Chaque domaine a son propre flux : un tirage supplémentaire dans un domaine ne décale
## pas les autres.
##
## RÈGLE : tout hasard qui influence le résultat d'une partie passe ici (jamais randi()/randf()/shuffle() globaux). Le hasard
## purement visuel (étincelles, tremblement de caméra…) reste global : il ne doit JAMAIS être mélangé à ces flux.
##
## Flux : « combat » (dégâts, critiques, statuts, cibles), « loot » (butin, objets du marchand), « trap » (pièges et énigmes),
## « wander » (errance des monstres), « village », « ids » (identifiants d'objets : sans effet sur le jeu).

static var seed_value: int = 0
static var _streams: Dictionary = {}

## Nouvelle partie de graine donnée (partie classée) : tous les flux repartent de cette graine.
static func begin(new_seed: int) -> void:
	seed_value = new_seed & Seeds.MASK
	_streams = {}

## Nouvelle partie libre : graine tirée au hasard.
static func begin_random() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	begin(r.randi() | (r.randi() << 31))

static func stream(name: String) -> RandomNumberGenerator:
	if not _streams.has(name):
		if seed_value == 0 and _streams.is_empty():
			begin_random()
		var r := RandomNumberGenerator.new()
		r.seed = Seeds.derive(seed_value, "stream", 0) ^ Seeds.from_text(name)
		_streams[name] = r
	return _streams[name]

## Entier 32 bits non signé du flux (équivalent de randi()).
static func i(name: String) -> int:
	return stream(name).randi()

## Entier dans [lo, hi] inclus (équivalent de randi_range).
static func range_i(name: String, lo: int, hi: int) -> int:
	return stream(name).randi_range(lo, hi)

## Flottant dans [0, 1) (équivalent de randf()).
static func f(name: String) -> float:
	return stream(name).randf()

## Mélange `arr` sur place (Fisher-Yates avec le flux) : le shuffle() natif utilise le hasard global.
static func shuffle(name: String, arr: Array) -> void:
	var r := stream(name)
	for k in range(arr.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp = arr[k]
		arr[k] = arr[j]
		arr[j] = tmp

## Élément au hasard de `arr` (équivalent de pick_random()).
static func pick(name: String, arr: Array):
	return arr[stream(name).randi_range(0, arr.size() - 1)]

## État complet (graine + position de chaque flux) : sauvegardé avec la partie, pour qu'une partie reprise continue à l'identique.
## Les nombres sont écrits en TEXTE : le JSON lit tout nombre comme un flottant, ce qui abîmerait des entiers de 64 bits.
static func export_state() -> Dictionary:
	var states := {}
	for k in _streams:
		states[k] = str((_streams[k] as RandomNumberGenerator).state)
	return {"seed": str(seed_value), "states": states}

static func import_state(d: Dictionary) -> void:
	begin(str(d.get("seed", "0")).to_int())
	var states: Dictionary = d.get("states") if d.get("states") is Dictionary else {}
	for k in states:
		var r := stream(str(k))
		r.state = str(states[k]).to_int()
