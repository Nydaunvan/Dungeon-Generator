class_name MyDungeons
extends RefCounted
## « Mes donjons » : l'espace personnel du joueur. Chaque donjon qu'il crée est enregistré automatiquement sur l'appareil
## (user://my_dungeons/) et, s'il est connecté, copié dans son compte (table `dungeons`, privée par défaut) : on le retrouve sur
## un autre appareil. Un donjon peut être publié dans la galerie de la communauté (`is_public`), téléchargé par les autres joueurs
## (copie dans leurs propres donjons) et signalé.
##
## Fichiers : `index.json` (une fiche par donjon, sans la configuration) + `<id>.json` (la configuration complète).
## Fiche : {id, cloud_id, title, desc, created, updated, dirty, public, levels, game_version, cloud_updated}.

const DIR := "user://my_dungeons"
const INDEX := DIR + "/index.json"
const MAX_TITLE := 60
const MAX_DESC := 500
const PUSH_DELAY_SEC := 6.0

## Donjon en cours d'édition dans l'administration ("" : aucun, ou nouveau donjon pas encore modifié).
static var current_id := ""
## Nouveau donjon ouvert mais pas encore modifié : il n'est enregistré qu'à la première modification (pas de doublons vides).
static var _pending_new := false
static var _initial_hash := 0
static var _push_scheduled := false
static var _syncing := false

# ------------------------------------------------------------------ fiches locales

static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _index() -> Array:
	var d = _read_json(INDEX)
	return d as Array if d is Array else []

static func _write_index(items: Array) -> void:
	_ensure_dir()
	var f := FileAccess.open(INDEX, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(items))

static func _cfg_path(id: String) -> String:
	return "%s/%s.json" % [DIR, id]

static func _new_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()

## Les donjons du joueur, le plus récemment modifié d'abord.
static func list() -> Array:
	var items := _index()
	items.sort_custom(func(a, b): return float(a.get("updated", 0)) > float(b.get("updated", 0)))
	return items

static func meta(id: String) -> Dictionary:
	for m in _index():
		if str(m.get("id", "")) == id:
			return m
	return {}

static func count() -> int:
	return _index().size()

static func load_config(id: String) -> Dictionary:
	var d = _read_json(_cfg_path(id))
	return d as Dictionary if d is Dictionary else {}

static func _clean_title(t: String) -> String:
	var s := t.strip_edges()
	if s == "":
		s = L.t("ui.mydun.untitled")
	return s.left(MAX_TITLE)

static func _levels_of(cfg: Dictionary) -> int:
	return (cfg.get("levels", []) as Array).size() if cfg.get("levels") is Array else 0

## Crée un donjon à partir d'une configuration. Renvoie son identifiant local.
static func create(cfg: Dictionary, cloud_id: String = "", desc: String = "", is_public: bool = false, from_gallery: String = "") -> String:
	_ensure_dir()
	var id := _new_id()
	cfg["title"] = _clean_title(str(cfg.get("title", "")))
	var f := FileAccess.open(_cfg_path(id), FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(Saves.stringify(cfg))
	var now := Time.get_unix_time_from_system()
	var items := _index()
	items.append({"id": id, "cloud_id": cloud_id, "title": cfg.title, "desc": desc.left(MAX_DESC), "created": now, "updated": now,
		"dirty": cloud_id == "", "public": is_public, "levels": _levels_of(cfg), "game_version": AppVersion.number(), "cloud_updated": "",
		"from_gallery": from_gallery, "cleared": false})
	_write_index(items)
	schedule_push()
	return id

## Enregistre la configuration d'un donjon (titre et nombre de niveaux de la fiche mis à jour, copie en ligne à renvoyer).
static func save(id: String, cfg: Dictionary) -> void:
	var items := _index()
	for m in items:
		if str(m.get("id", "")) != id:
			continue
		cfg["title"] = _clean_title(str(cfg.get("title", "")))
		var f := FileAccess.open(_cfg_path(id), FileAccess.WRITE)
		if f == null:
			return
		f.store_string(Saves.stringify(cfg))
		m["title"] = cfg.title
		m["levels"] = _levels_of(cfg)
		m["updated"] = Time.get_unix_time_from_system()
		m["dirty"] = true
		m["game_version"] = AppVersion.number()
		_write_index(items)
		schedule_push()
		return

static func set_description(id: String, desc: String) -> void:
	var items := _index()
	for m in items:
		if str(m.get("id", "")) == id:
			m["desc"] = desc.strip_edges().left(MAX_DESC)
			m["dirty"] = true
			_write_index(items)
			schedule_push()
			return

static func rename(id: String, title: String) -> void:
	var cfg := load_config(id)
	if cfg.is_empty():
		return
	cfg["title"] = title
	save(id, cfg)

## Copie d'un donjon (nouvelle fiche, pas encore en ligne). Renvoie l'identifiant de la copie.
static func duplicate(id: String) -> String:
	var cfg := load_config(id)
	if cfg.is_empty():
		return ""
	cfg["title"] = _clean_title(L.fa(L.t("ui.mydun.copy_of"), str(cfg.get("title", "")))).left(MAX_TITLE)
	return create(cfg, "", str(meta(id).get("desc", "")), false)

## Supprime le donjon de l'appareil et, s'il est connecté, de son compte (et donc de la galerie).
static func delete(id: String) -> Dictionary:
	var m := meta(id)
	var res := {"ok": true}
	if str(m.get("cloud_id", "")) != "" and Cloud.is_signed_in():
		res = await Cloud.request(HTTPClient.METHOD_DELETE, "/rest/v1/dungeons?id=eq.%s" % str(m.cloud_id), null, true)
		if not res.ok and not res.offline:
			return res
		if not res.ok:
			_remember_deletion(str(m.cloud_id))
	elif str(m.get("cloud_id", "")) != "":
		_remember_deletion(str(m.cloud_id))
	var items := _index().filter(func(x): return str(x.get("id", "")) != id)
	_write_index(items)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_cfg_path(id)))
	if current_id == id:
		current_id = ""
	return {"ok": true}

# suppressions en ligne à rejouer plus tard (hors ligne au moment de supprimer)
const PENDING_DEL := DIR + "/pending_delete.json"

static func _remember_deletion(cloud_id: String) -> void:
	_ensure_dir()
	var d = _read_json(PENDING_DEL)
	var a: Array = d if d is Array else []
	if not a.has(cloud_id):
		a.append(cloud_id)
	var f := FileAccess.open(PENDING_DEL, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(a))

# ------------------------------------------------------------------ édition (administration)

## Hash de la configuration : sert à savoir si le joueur a modifié un nouveau donjon.
static func _hash_of(cfg: Dictionary) -> int:
	return Saves.stringify(cfg).hash()

## Un nouveau donjon vient d'être ouvert dans l'administration : enregistré dès la première modification.
static func begin_new(cfg: Dictionary) -> void:
	current_id = ""
	_pending_new = true
	_initial_hash = _hash_of(cfg)

## Un donjon existant est ouvert dans l'administration.
static func begin_existing(id: String) -> void:
	current_id = id
	_pending_new = false

static func end_editing() -> void:
	current_id = ""
	_pending_new = false

## Appelé à chaque enregistrement de la configuration d'administration (Data.save_config) et en quittant : sauvegarde automatique.
static func autosave(cfg: Dictionary) -> void:
	if current_id != "":
		save(current_id, cfg)
	elif _pending_new and _hash_of(cfg) != _initial_hash:
		current_id = create(cfg.duplicate(true))
		_pending_new = false

# ------------------------------------------------------------------ synchronisation avec le compte

static func online() -> bool:
	return Cloud.is_configured() and Cloud.is_signed_in()

static func schedule_push() -> void:
	if _push_scheduled or not online():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_push_scheduled = true
	await tree.create_timer(PUSH_DELAY_SEC).timeout
	_push_scheduled = false
	await sync()

static func _body(m: Dictionary, cfg: Dictionary) -> Dictionary:
	return {"title": _clean_title(str(m.get("title", ""))), "description": str(m.get("desc", "")).left(MAX_DESC),
		"code": Data.encode_code(cfg), "game_version": AppVersion.number(), "schema_version": SaveMigrations.SCHEMA,
		"is_public": bool(m.get("public", false))}

## Envoie les donjons modifiés et récupère ceux qui ne sont que dans le compte (autre appareil). Renvoie {ok, message, pushed, pulled}.
static func sync() -> Dictionary:
	if not online():
		return {"ok": false, "offline": true, "message": L.t("ui.mydun.need_account")}
	if _syncing:
		return {"ok": true, "pushed": 0, "pulled": 0}
	_syncing = true
	var out := await _sync_inner()
	_syncing = false
	return out

static func _sync_inner() -> Dictionary:
	var pushed := 0
	var pulled := 0
	# suppressions en attente
	var pd = _read_json(PENDING_DEL)
	if pd is Array and not (pd as Array).is_empty():
		var left: Array = []
		for cid in pd:
			var r0: Dictionary = await Cloud.request(HTTPClient.METHOD_DELETE, "/rest/v1/dungeons?id=eq.%s" % str(cid), null, true)
			if not r0.ok:
				left.append(cid)
		if left.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_DEL))
	var rr: Dictionary = await Cloud.request(HTTPClient.METHOD_GET,
		"/rest/v1/dungeons?owner_id=eq.%s&select=id,updated_at,is_public,description&limit=500" % Cloud.user_id(), null, true)
	if not rr.ok or not (rr.data is Array):
		return {"ok": false, "message": str(rr.get("message", "")), "offline": bool(rr.get("offline", false))}
	var remote := {}
	for row in rr.data:
		remote[str(row.id)] = row
	var items := _index()
	var known := {}
	for m in items:
		var cid := str(m.get("cloud_id", ""))
		if cid != "":
			known[cid] = true
		var cfg_local := load_config(str(m.id))
		if cfg_local.is_empty():
			continue
		var in_cloud := cid != "" and remote.has(cid)
		if not in_cloud:
			m["cloud_id"] = ""
			cid = ""
		if cid == "":
			var ins: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/dungeons",
				_body(m, cfg_local).merged({"owner_id": Cloud.user_id()}), true, PackedStringArray(["Prefer: return=representation"]))
			if ins.ok and ins.data is Array and not (ins.data as Array).is_empty():
				m["cloud_id"] = str(ins.data[0].id)
				m["cloud_updated"] = str(ins.data[0].get("updated_at", ""))
				m["dirty"] = false
				pushed += 1
			else:
				m["sync_error"] = str(ins.get("message", ""))
		elif bool(m.get("dirty", false)):
			var up: Dictionary = await Cloud.request(HTTPClient.METHOD_PATCH, "/rest/v1/dungeons?id=eq.%s" % cid,
				_body(m, cfg_local), true, PackedStringArray(["Prefer: return=representation"]))
			if up.ok and up.data is Array and not (up.data as Array).is_empty():
				m["cloud_updated"] = str(up.data[0].get("updated_at", ""))
				m["dirty"] = false
				pushed += 1
			else:
				m["sync_error"] = str(up.get("message", ""))
		else:
			m["public"] = bool(remote[cid].get("is_public", false))
	# donjons présents seulement dans le compte : copie locale
	for cid in remote:
		if known.has(cid):
			continue
		var g: Dictionary = await Cloud.request(HTTPClient.METHOD_GET,
			"/rest/v1/dungeons?id=eq.%s&select=id,title,description,code,is_public,updated_at" % cid, null, true)
		if not g.ok or not (g.data is Array) or (g.data as Array).is_empty():
			continue
		var row: Dictionary = g.data[0]
		var cfg := Data.decode_code(str(row.get("code", "")))
		if cfg.is_empty():
			continue
		Data.ensure_defaults(cfg)
		cfg["title"] = str(row.get("title", ""))
		var nid := create(cfg, cid, str(row.get("description", "")), bool(row.get("is_public", false)))
		var items2 := _index()
		for m2 in items2:
			if str(m2.id) == nid:
				m2["cloud_updated"] = str(row.get("updated_at", ""))
				m2["dirty"] = false
		_write_index(items2)
		pulled += 1
	# fiches relues : create() a pu modifier l'index pendant la boucle d'envoi, on fusionne les champs de synchronisation
	var fresh := _index()
	for m in items:
		for f2 in fresh:
			if str(f2.id) == str(m.id):
				var edited_meanwhile := float(f2.get("updated", 0)) != float(m.get("updated", 0))
				for k in ["cloud_id", "cloud_updated", "dirty", "public", "sync_error"]:
					if m.has(k):
						f2[k] = m[k]
				if edited_meanwhile:
					f2["dirty"] = true      # modifié pendant l'envoi : à renvoyer
	_write_index(fresh)
	return {"ok": true, "pushed": pushed, "pulled": pulled}

## Publie ou retire un donjon de la galerie (le copie d'abord dans le compte). Renvoie {ok, message}.
static func set_public(id: String, on: bool, desc: String = "") -> Dictionary:
	if not online():
		return {"ok": false, "message": L.t("ui.mydun.need_account")}
	var items := _index()
	for m in items:
		if str(m.get("id", "")) == id:
			m["public"] = on
			if on:
				m["desc"] = desc.strip_edges().left(MAX_DESC)
			m["dirty"] = true
			_write_index(items)
	var r := await sync()
	if not r.ok:
		return r
	var after := meta(id)
	if str(after.get("cloud_id", "")) == "" or bool(after.get("dirty", false)):
		return {"ok": false, "message": str(after.get("sync_error", L.t("ui.cloud.err.generic")))}
	return {"ok": true}

# ------------------------------------------------------------------ galerie de la communauté

const GALLERY_PAGE := 20

## Donjons publics. `sort` : "recent" ou "popular". `query` : mot du titre. Renvoie {ok, data:[{id,title,description,downloads,created_at,owner_id,pseudo,game_version}]}.
static func gallery(query: String, sort: String, offset: int) -> Dictionary:
	var q := "/rest/v1/dungeons?is_public=eq.true&select=id,title,description,downloads,created_at,owner_id,game_version,profiles(pseudo)"
	var term := query.strip_edges().replace("*", "").replace(",", " ").replace("(", " ").replace(")", " ").uri_encode()
	if term != "":
		q += "&title=ilike.*%s*" % term
	q += "&order=" + ("downloads.desc,created_at.desc" if sort == "popular" else "created_at.desc")
	q += "&limit=%d&offset=%d" % [GALLERY_PAGE, offset]
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_GET, q, null, Cloud.is_signed_in())
	if r.ok and r.data is Array:
		for row in r.data:
			var p = row.get("profiles")
			row["pseudo"] = str((p as Dictionary).get("pseudo", "?")) if p is Dictionary else "?"
	return r

## Télécharge un donjon de la galerie dans « Mes donjons ». Renvoie {ok, id (local), message}.
static func download(cloud_id: String) -> Dictionary:
	var g: Dictionary = await Cloud.request(HTTPClient.METHOD_GET,
		"/rest/v1/dungeons?id=eq.%s&is_public=eq.true&select=title,description,code" % cloud_id, null, Cloud.is_signed_in())
	if not g.ok:
		return g
	if not (g.data is Array) or (g.data as Array).is_empty():
		return {"ok": false, "message": L.t("ui.gallery.gone")}
	var row: Dictionary = g.data[0]
	var cfg := Data.decode_code(str(row.get("code", "")))
	if cfg.is_empty():
		return {"ok": false, "message": L.t("common.ce_code_est_invalide_ou")}
	Data.ensure_defaults(cfg)
	cfg["title"] = str(row.get("title", ""))
	var id := create(cfg, "", str(row.get("description", "")), false, cloud_id)
	if Cloud.is_signed_in():
		Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/count_download", {"dungeon": cloud_id}, true)
	return {"ok": id != "", "id": id, "message": ""}

## Donjon de la semaine (le plus téléchargé en 7 jours) : {ok, data: {id,title,description,downloads,created_at,owner_id,pseudo,week_downloads} ou null}.
static func featured() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/gallery_featured", {}, Cloud.is_signed_in())

## Victoire dans le donjon « Mes donjons » en cours d'édition : si c'est un donjon téléchargé de la galerie, le serveur le compte une fois
## (badges « Testeur »). Sans compte ou sans réseau, rien n'est envoyé et le jeu continue.
static func report_gallery_clear() -> void:
	if current_id == "" or not online():
		return
	var m := meta(current_id)
	var gid := str(m.get("from_gallery", ""))
	if gid == "" or bool(m.get("cleared", false)):
		return
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/record_gallery_clear", {"p_dungeon": gid}, true)
	if not r.ok:
		return
	var items := _index()
	for it in items:
		if str(it.get("id", "")) == str(m.get("id", "")):
			it["cleared"] = true
	_write_index(items)

static func report(cloud_id: String, reason: String) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/dungeon_reports",
		{"dungeon_id": cloud_id, "reporter_id": Cloud.user_id(), "reason": reason.strip_edges().left(500)}, true)

# ------------------------------------------------------------------ donjon vide

## Configuration d'un donjon VIDE : les règles du jeu (classes, sorts, objets, groupe) mais un seul niveau ENTIÈREMENT plein
## (murs partout, sauf la case de départ du groupe), sans monstre, sans objet, sans escalier : tout reste à creuser.
## Pas de grande salle ouverte au départ : les salles ne sont pas encore autorisées et le joueur ne doit pas y jouer par accident.
static func empty_config() -> Dictionary:
	var c: Dictionary = Data.original_config.duplicate(true)
	var w := 11
	var h := 9
	var rows: Array = []
	for y in h:
		var s := ""
		for x in w:
			s += "." if (x == 1 and y == 1) else "#"
		rows.append(s)
	c["levels"] = [{"id": "lvl_1", "name": L.t("ui.mydun.level_1"), "theme": "stone", "mapRows": rows, "startX": 1, "startY": 1, "startDir": 1,
		"stairs": [], "doors": [], "monsters": [], "items": []}]
	c["title"] = L.t("ui.mydun.new_title")
	for k in ["runModifierIds", "genDims", "genDifficulty"]:
		c.erase(k)
	return c
