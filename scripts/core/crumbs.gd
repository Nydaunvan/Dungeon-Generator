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

const CLEAN := "fermeture normale"

## Vrai si la dernière session s'est terminée proprement (ou s'il n'y a pas d'historique) ; sinon c'est un arrêt brutal.
static func last_exit_clean() -> bool:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null or f.get_length() < 2:
		return true
	f.seek(maxi(0, f.get_length() - 200))
	var lines := f.get_as_text().strip_edges().split("\n")
	return lines.size() == 0 or lines[lines.size() - 1].ends_with(CLEAN)

## État du moteur : images/s, mémoire vidéo, nombre d'objets… écrit à intervalle régulier pour voir ce qui précède un arrêt brutal.
static func sample() -> void:
	var mb := 1.0 / 1048576.0
	mark("état %d i/s | vidéo %.0f Mo (textures %.0f, tampons %.0f) | mémoire %.0f Mo | nœuds %d | objets 3D %d | appels %d" % [
		int(Engine.get_frames_per_second()),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) * mb,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) * mb,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) * mb,
		OS.get_static_memory_usage() * mb,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))])
