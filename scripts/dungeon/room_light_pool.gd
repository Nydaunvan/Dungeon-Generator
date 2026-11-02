class_name RoomLightPool
extends Node3D
## Lumières des salles gothic : un petit nombre fixe (N) d'OmniLight3D sans ombre, réaffectées en continu aux foyers de la salle les plus proches de la caméra
## (candélabres, bougies, lustres, braseros, plus une lumière de remplissage froide par grande salle). Le nombre de lumières dynamiques ne dépend donc jamais
## de la taille du niveau. Purement visuel : aucune incidence sur le jeu, les sauvegardes ni le rejeu.

const N := 4                    # lumières simultanées (en plus des torches murales et de la torche du groupe)
const REFRESH := 0.2
const FADE := 1.6               # énergie par seconde (≈ 0,6 s pour s'allumer ou s'éteindre)
const ACTIVATE_R := 26.0

class Slot:
	var light: OmniLight3D
	var em := -1
	var level := 0.0
	var target := 0.0

var emitters: Array = []        # {p, col, energy, range, atten, phase}
var _slots: Array = []
var _tick := 0.0
var _time := 0.0

func _init() -> void:
	name = "RoomLights"

func _ready() -> void:
	for i in N:
		var s := Slot.new()
		s.light = OmniLight3D.new()
		s.light.shadow_enabled = false
		s.light.light_energy = 0.0
		s.light.visible = false
		add_child(s.light)
		_slots.append(s)

## p : position dans le repère de ce nœud.
func add_emitter(p: Vector3, col: Color, energy: float, rng: float, atten := 1.2) -> void:
	emitters.append({"p": p, "col": col, "energy": energy, "range": rng, "atten": atten, "phase": float(absi(int(p.x * 13.0 + p.z * 29.0)) % 628) * 0.01})

func _process(delta: float) -> void:
	_time += delta
	_tick += delta
	if _tick >= REFRESH:
		_tick = 0.0
		_refresh()
	var mk := Settings.motion_k()
	for s in _slots:
		var sl: Slot = s
		sl.level = move_toward(sl.level, sl.target, delta * FADE)
		if sl.em < 0:
			continue
		if sl.level <= 0.0 and sl.target <= 0.0:
			sl.em = -1
			sl.light.visible = false
			sl.light.light_energy = 0.0
			continue
		var e: Dictionary = emitters[sl.em]
		var p := _time * 1.7 + float(e.phase)
		var flick := 1.0 + (sin(p) * 0.07 + sin(p * 2.9) * 0.04) * mk * (1.0 if e.col.r > e.col.b else 0.0)      # le remplissage froid ne vacille pas
		sl.light.light_energy = float(e.energy) * smoothstep(0.0, 1.0, sl.level) * flick

func _refresh() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or emitters.is_empty():
		return
	var cp := to_local(cam.global_position)
	var cand: Array = []
	for i in emitters.size():
		var e: Dictionary = emitters[i]
		var d := cp.distance_to(e.p)
		if d <= ACTIVATE_R + float(e.range) * 0.5:
			cand.append([d - float(e.range) * 0.35, i])      # un foyer à grande portée l'emporte un peu sur un petit foyer à même distance
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var want := {}
	for k in mini(N, cand.size()):
		want[int(cand[k][1])] = true
	for s in _slots:
		var sl: Slot = s
		if sl.em >= 0 and not want.has(sl.em):
			sl.target = 0.0
		elif sl.em >= 0:
			sl.target = 1.0
			want.erase(sl.em)
	for ei in want:
		for s in _slots:
			var sl: Slot = s
			if sl.em < 0:
				sl.em = int(ei)
				sl.level = 0.0
				sl.target = 1.0
				var e: Dictionary = emitters[sl.em]
				sl.light.position = e.p
				sl.light.light_color = e.col
				sl.light.omni_range = float(e.range)
				sl.light.omni_attenuation = float(e.atten)
				sl.light.visible = true
				break
