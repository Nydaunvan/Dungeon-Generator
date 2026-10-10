class_name Chat
extends RefCounted
## Tchat des joueurs connectés (salons Général / Français / English).
##
## SÉCURITÉ : toutes les règles (longueur, débit, doublons, mots interdits, silence, blocages) sont appliquées par le serveur ; ce fichier
## ne fait que les appeler. Aucune table n'est lisible directement : tout passe par des fonctions (chat_send, chat_fetch…). Le nettoyage
## fait ici (`clean`) n'est qu'un confort : le serveur refait le sien.

const ROOMS := ["general", "fr", "en"]
const MAX_LEN := 300
const ROOM_KEYS := {"general": "ui.chat.room_general", "fr": "ui.chat.room_fr", "en": "ui.chat.room_en"}
const KEEP := 150               ## messages gardés à l'écran par salon

static func room_name(id: String) -> String:
	return L.t(ROOM_KEYS[id]) if ROOM_KEYS.has(id) else id

## Salon proposé par défaut : celui de la langue du jeu.
static func default_room() -> String:
	return "en" if Data.lang == "en" else "fr"

## Même nettoyage que le serveur : caractères de contrôle retirés, espaces réduits, 300 caractères au plus.
static func clean(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		if c < 32 or (c >= 127 and c < 160) or c == 0x200B or c == 0x200C or c == 0x200D or c == 0xFEFF \
				or (c >= 0x202A and c <= 0x202E) or (c >= 0x2066 and c <= 0x2069):
			out += " " if c == 10 or c == 9 else ""
		else:
			out += String.chr(c)
	var re := RegEx.create_from_string("\\s+")
	out = re.sub(out, " ", true).strip_edges()
	return out.substr(0, MAX_LEN)

## Derniers messages du salon (`after` = 0) ou ceux qui suivent le numéro `after`. `data` : tableau trié du plus ancien au plus récent.
static func fetch(room: String, after: int = 0, limit: int = 60) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/chat_fetch", {"p_room": room, "p_after": after, "p_limit": limit}, true)

static func send(room: String, body: String) -> Dictionary:
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/chat_send", {"p_room": room, "p_body": body}, true)
	if not r.ok and r.get("error_code", "") == "chat_mute":
		r["message"] = mute_message(r)
	return r

## Message « vous êtes réduit au silence jusqu'à … » à partir de la réponse du serveur (le champ `hint` donne la fin du silence).
static func mute_message(r: Dictionary) -> String:
	var d: Variant = r.get("data")
	var until := ""
	if d is Dictionary:
		until = format_time(str((d as Dictionary).get("hint", "")))
	if until == "":
		return L.t("ui.cloud.err.chat_mute")
	return L.t("ui.chat.muted_until") % until

static func report(message_id: int, reason: String = "") -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/chat_report", {"p_message_id": message_id, "p_reason": reason.substr(0, 200)}, true)

static func block(player_id: String) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/chat_block", {"p_player": player_id}, true)

static func unblock(player_id: String) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/chat_unblock", {"p_player": player_id}, true)

## Joueurs bloqués par le compte : [{player_id, pseudo}].
static func blocked() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/chat_blocked", {}, true)

## Date du serveur (« 2026-10-10T16:00:00+00:00 » ou « 2026-10-10 16:00:00+00 », UTC) -> « hh:mm » (aujourd'hui) ou « jj/mm hh:mm ».
static func format_time(v: String) -> String:
	if v.length() < 19:
		return ""
	var s := v.substr(0, 19).replace(" ", "T")
	var t := Time.get_unix_time_from_datetime_string(s)
	t += int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(int(t))
	var now := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system() + int(Time.get_time_zone_from_system().get("bias", 0)) * 60))
	if d.year == now.year and d.month == now.month and d.day == now.day:
		return "%02d:%02d" % [d.hour, d.minute]
	return "%02d/%02d %02d:%02d" % [d.day, d.month, d.hour, d.minute]
