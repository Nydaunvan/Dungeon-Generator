class_name RunExport
extends RefCounted
## Export d'une partie classée en CSV structuré (une ligne par action du journal) : sert à analyser une partie dans un tableur.
## Séparateur « ; » et BOM UTF-8 (le tableur français ouvre ainsi les accents et les colonnes correctement).
## Colonnes : partie, joueur, mode, periode, version, graine, statut, n, temps_ms, temps, commande, action, arg1, arg2, arg3.

const HEADER := ["partie", "joueur", "mode", "periode", "version", "graine", "statut", "n", "temps_ms", "temps", "commande", "action", "arg1", "arg2", "arg3"]
const RELATIVE := ["avancer", "pas à droite", "reculer", "pas à gauche"]

## Temps de jeu en « m:ss.mmm ».
static func fmt_time(ms: int) -> String:
	return "%d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]

## Libellé lisible d'une commande du journal (voir RunLog et Replayer.apply).
static func label(e: Array) -> String:
	var a1: Variant = e[2] if e.size() > 2 else null
	var a2: Variant = e[3] if e.size() > 3 else null
	match str(e[1]):
		"m": return "Déplacement : " + str(RELATIVE[posmod(int(a1), 4)])
		"t": return "Rotation à droite" if int(a1) == 1 else "Rotation à gauche"
		"i": return "Interaction"
		"atk": return "Attaque"
		"cast": return "Sort" + (" sur un allié" if a2 != null else "")
		"scroll": return "Parchemin"
		"flee": return "Fuite"
		"skip": return "Tour passé"
		"tgt": return "Choix de la cible"
		"sel": return "Choix du personnage"
		"ui": return "Décision (fenêtre)"
		"eq": return "Équipement"
		"un": return "Déséquipement"
		"drop": return "Objet jeté"
		"sort": return "Tri de l'inventaire"
		"forge": return "Forge"
		"tm": return "Talent choisi"
		"drink": return "Potion bue"
		"w": return "Déplacement d'un monstre errant"
		"e": return "Engagement d'un combat"
	return str(e[1])

static func _cell(v: Variant) -> String:
	if v == null:
		return ""
	var t := JSON.stringify(v) if (v is Array or v is Dictionary) else str(v)
	if t.contains(";") or t.contains('"') or t.contains("\n"):
		return '"%s"' % t.replace('"', '""')
	return t

static func _mode(meta: Dictionary) -> String:
	return SuperAdminModal.mode_name(str(meta.get("difficulty", "")), str(meta.get("kind", "")))

## Texte CSV complet (BOM compris) pour une partie `meta` (réponse d'admin_run_log).
static func to_csv(meta: Dictionary) -> String:
	var base := [str(meta.get("id", "")), str(meta.get("pseudo", "")), _mode(meta), str(meta.get("period", "")) if meta.get("period") != null else "",
		str(meta.get("game_version", "")), str(meta.get("seed", "")), str(meta.get("status", ""))]
	var lines := PackedStringArray([";".join(HEADER)])
	var log: Array = meta.get("log", []) if meta.get("log") is Array else []
	for i in log.size():
		var e: Array = log[i]
		if e.size() < 2:
			continue
		var ms := int(e[0])
		var row: Array = []
		for c in base:
			row.append(_cell(c))
		row.append_array([str(i + 1), str(ms), fmt_time(ms), str(e[1]), _cell(label(e)),
			_cell(e[2] if e.size() > 2 else null), _cell(e[3] if e.size() > 3 else null), _cell(e[4] if e.size() > 4 else null)])
		lines.append(";".join(PackedStringArray(row.map(func(x): return str(x)))))
	return "﻿" + "\r\n".join(lines) + "\r\n"

## Nom de fichier : rejeu_<pseudo>_<jour>_<id court>.<ext>
static func file_name(meta: Dictionary, ext: String) -> String:
	var who := str(meta.get("pseudo", "joueur")).to_lower()
	var clean := ""
	for ch in who:
		clean += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	var day := str(meta.get("started_at", ""))
	return "partie_%s_%s_%s.%s" % [clean, day.substr(0, 10), str(meta.get("id", "")).substr(0, 8), ext]
