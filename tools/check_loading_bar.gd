extends Node
## Barre de chargement : mouvement continu (jamais d'arrêt ni de saut), vitesse qui varie progressivement, ne recule jamais, finit à 100 %.
func _ready() -> void:
	var ls := LoadingScreen.new()
	add_child(ls)
	await get_tree().process_frame
	ls.reset()
	var prev := 0.0
	var prev_v := 0.0
	var worst_acc := 0.0
	var max_v := 0.0
	var back := false
	var stall_move := 0.0
	var t := 0.0
	# scénario : paliers brusques, longue étape bloquée, grosse image perdue au milieu
	var steps := [[0.0, 0.04], [0.5, 0.17], [1.5, 0.29], [1.6, 0.34], [7.0, 0.34], [7.1, 0.9], [9.0, 0.9], [9.5, 1.0]]
	var si := 0
	var stall_start := -1.0
	while t < 14.0:
		while si < steps.size() and t >= float(steps[si][0]):
			ls._target = float(steps[si][1])
			si += 1
		var d := 1.0 / 60.0
		if absf(t - 3.3) < 0.01:
			d = 0.2          # image perdue (gros calcul) : ne doit pas faire sauter la barre
		ls._advance(d)
		t += d
		var v: float = (ls._shown - prev) / d
		if ls._shown < prev - 1e-9:
			back = true
		if d <= 1.0 / 60.0 + 1e-6:
			worst_acc = maxf(worst_acc, absf(v - prev_v) / d)
		max_v = maxf(max_v, v)
		if t > 2.0 and t < 6.5:         # longue étape bloquée à 34 % : la barre doit continuer d'avancer, sans dépasser la cible + avance
			if stall_start < 0.0:
				stall_start = ls._shown
			stall_move = ls._shown - stall_start
		prev = ls._shown
		prev_v = v
	var ok: bool = not back and worst_acc < 1.0 and max_v < 0.6 and stall_move > 0.02 and ls._shown >= 0.999
	print("LOADBAR retour=", back, " accel_max=", snappedf(worst_acc, 0.01), " vmax=", snappedf(max_v, 0.01), " reptation=", snappedf(stall_move, 0.001), " fin=", ls._shown, " -> ", "OK" if ok else "ECHEC")
	get_tree().quit(0 if ok else 1)
