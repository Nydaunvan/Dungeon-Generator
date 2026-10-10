class_name Crumbs
extends RefCounted
## Fil d'Ariane de diagnostic : quelques lignes (niveau chargé, combat, appel au serveur…) écrites tout de suite dans user://trace.log.
## Après un plantage du programme, la dernière ligne dit ce que le jeu faisait. Aucune donnée personnelle : jamais de jeton ni de contenu.
## Le fichier est tronqué au-delà de 64 Ko (l'ancien contenu est repris sur la moitié récente).

const PATH := "user://trace.log"
const MAX := 65536

static func mark(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(PATH, FileAccess.WRITE)
		if f == null:
			return
	elif f.get_length() > MAX:
		f.seek(f.get_length() / 2)
		var tail := f.get_buffer(f.get_length() - f.get_position())
		f.close()
		f = FileAccess.open(PATH, FileAccess.WRITE)
		if f == null:
			return
		f.store_buffer(tail)
	else:
		f.seek_end()
	f.store_line("%s  %s" % [Time.get_datetime_string_from_system(false, true), text])
	f.flush()
