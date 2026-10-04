class_name LangTranslation
extends Translation
## Fichier de langue (data/lang/<langue>.json) servi au moteur de traduction.
## - section « ui » : clé → texte (`L.t("admin.main.tabs_general")`) ;
## - section « content » : textes des données du jeu (noms de classes, sorts, objets…). Ces données gardent le français comme
##   texte de référence ; le moteur retrouve leur version dans la langue demandée en rapprochant les deux fichiers par clé.

var _ui: Dictionary = {}
var _content_by_fr: Dictionary = {}   # texte français → texte dans cette langue

func load_language(code: String, fr_content: Dictionary) -> void:
	locale = code
	var f := FileAccess.open("res://data/lang/%s.json" % code, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return
	_ui = d.get("ui", {})
	var content: Dictionary = d.get("content", {})
	for k in content.keys():
		if fr_content.has(k):
			_content_by_fr[str(fr_content[k])] = str(content[k])

func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if _ui.has(s):
		return StringName(str(_ui[s]))
	var r := _content(s)
	return StringName(r) if r != "" else &""

## Texte de données : exact, puis après un préfixe d'emoji/ponctuation (« ✨ Sacré »), puis version MAJUSCULES.
func _content(s: String) -> String:
	if _content_by_fr.has(s):
		return _content_by_fr[s]
	var i := 0
	while i < s.length() and not _is_word_char(s[i]):
		i += 1
	if i > 0 and i < s.length():
		var rest := s.substr(i)
		if _content_by_fr.has(rest):
			return s.substr(0, i) + _content_by_fr[rest]
	if s == s.to_upper() and s != s.to_lower():
		var cap := s.to_lower().capitalize()
		if _content_by_fr.has(cap):
			return str(_content_by_fr[cap]).to_upper()
	return ""

static func _is_word_char(ch: String) -> bool:
	return ch.to_upper() != ch.to_lower() or (ch >= "0" and ch <= "9")

## Toutes les clés « ui » (outil de contrôle).
func ui_keys() -> Array:
	return _ui.keys()
