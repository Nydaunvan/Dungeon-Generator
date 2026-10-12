class_name ServerNotice
extends RefCounted
## Annonce globale et état de maintenance du serveur, lus sans compte (publics). Sert à afficher une bannière dans le Mode en ligne et un
## message à l'ouverture du jeu. Hors ligne ou serveur sans la mise à jour : rien n'est affiché.

static var announcement: Dictionary = {}       ## {id, body, created_at, expires_at} ou {}
static var state: Dictionary = {}              ## {ranked_closed, chat_closed, message} ou {}
static var _at := -1000000

## Relit l'annonce et l'état (au plus une fois par minute, sauf `force`).
static func refresh(force: bool = false) -> void:
	if not force and Time.get_ticks_msec() - _at < 60000:
		return
	_at = Time.get_ticks_msec()
	var a: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/announcement_current", {})
	announcement = a.data if a.ok and a.data is Dictionary else {}
	var s: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/server_state_get", {})
	state = s.data if s.ok and s.data is Dictionary else {}

static func ranked_closed() -> bool:
	return bool(state.get("ranked_closed", false))

static func chat_closed() -> bool:
	return bool(state.get("chat_closed", false))

## Texte de la bannière (annonce, puis maintenance), "" s'il n'y a rien à dire.
static func banner_text() -> String:
	var lines: Array[String] = []
	if not announcement.is_empty():
		lines.append("📢 " + str(announcement.get("body", "")))
	if ranked_closed() or chat_closed():
		var what: Array[String] = []
		if ranked_closed():
			what.append(L.t("ui.notice.ranked"))
		if chat_closed():
			what.append(L.t("ui.notice.chat"))
		var t := "🔧 " + L.fa(L.t("ui.notice.maintenance"), ", ".join(what))
		var m := str(state.get("message", ""))
		lines.append(t + (" — " + m if m != "" else ""))
	return "\n".join(lines)

## Au démarrage : affiche l'annonce du développeur une seule fois par annonce (retenue dans les préférences de mise à jour).
static func popup_once(host: Node) -> void:
	await refresh()
	if announcement.is_empty() or not is_instance_valid(host):
		return
	var id := int(announcement.get("id", 0))
	if id <= int(Updater.pref("last_notice", 0)):
		return
	Updater.set_pref("last_notice", id)
	var m := Modal.open(host, L.t("ui.notice.title"), 460.0)
	m.add_text(str(announcement.get("body", "")), UiTheme.PARCH, 16)
	m.set_buttons([{"text": L.t("common.fermer"), "primary": true, "cb": func(): m.close()}])
