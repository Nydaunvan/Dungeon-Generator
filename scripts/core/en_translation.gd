class_name EnTranslation
extends Translation
## Traduction anglaise : les textes de l'interface sont écrits en français ; le dictionnaire (tiré du JSON de l'original) associe
## chaque texte français à sa version anglaise. Godot traduit ainsi automatiquement libellés, boutons et infobulles.
## Un préfixe d'emoji / ponctuation est conservé tel quel (« 🏠 Accueil » → « 🏠 Home »).

var _map: Dictionary = {}
var _cache: Dictionary = {}
## Modèles à trous (« %s », « %d ») : regex du texte français → modèle anglais, pour les textes déjà formatés.
var _templates: Array = []
var _lower: Dictionary = {}

func load_dictionary(path: String) -> void:
	locale = "en"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_map = d
		# variantes sans préfixe d'emoji (l'original en met parfois, l'interface Godot parfois non)
		for k in _map.keys():
			var fr := str(k)
			var split := _split_prefix(fr)
			if split[0] != "" and not _map.has(split[1]):
				_map[split[1]] = _split_prefix(str(_map[k]))[1]
		for k2 in _map.keys():
			_lower[String(k2).to_lower()] = str(_map[k2])
		_build_templates()

func _build_templates() -> void:
	var specs := RegEx.new()
	specs.compile("%[sd]")
	for k in _map.keys():
		var fr := str(k)
		if not (fr.contains("%s") or fr.contains("%d")):
			continue
		var pattern := ""
		var rest := fr.replace("%%", "\u0001")
		var pos := 0
		for m in specs.search_all(rest):
			pattern += _esc(rest.substr(pos, m.get_start() - pos))
			pattern += "(.*?)" if m.get_string() == "%s" else "(-?\\d+)"
			pos = m.get_end()
		pattern += _esc(rest.substr(pos))
		pattern = "^" + pattern.replace("\u0001", "%") + "$"
		var re := RegEx.new()
		if re.compile(pattern) == OK:
			_templates.append({"re": re, "en": str(_map[k]).replace("%%", "\u0001"), "len": fr.length()})
	_templates.sort_custom(func(a, b): return a.len > b.len)

static func _esc(t: String) -> String:
	var out := ""
	for ch in t:
		if "\\.^$*+?()[]{}|".contains(ch):
			out += "\\"
		out += ch
	return out

## Valeur capturée par un « %s » : traduite à son tour si elle est connue (noms de statuts, de classes, fragments).
func _tr_part(v: String) -> String:
	if v == "" or v.is_valid_int():
		return v
	var out := String(_get_message(StringName(v), &""))
	return out if out != "" else v

func _from_template(s: String) -> String:
	for t in _templates:
		var m: RegExMatch = t.re.search(s)
		if m == null:
			continue
		var out: String = t.en
		var i := 1
		var parts := out.split("%")
		# remplace les %s / %d de l'anglais, dans l'ordre, par les groupes capturés
		var res := ""
		for j in parts.size():
			var seg: String = parts[j]
			if j == 0:
				res += seg
				continue
			if seg.begins_with("s") or seg.begins_with("d"):
				res += _tr_part(m.get_string(i) if i <= m.get_group_count() else "") + seg.substr(1)
				i += 1
			else:
				res += "%" + seg
		return res.replace("\u0001", "%")
	return ""

static func _split_prefix(s: String) -> Array:
	var i := 0
	while i < s.length():
		var c := s.unicode_at(i)
		var is_letter := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 0xC0 and c <= 0x24F)
		if is_letter:
			break
		i += 1
	return [s.substr(0, i), s.substr(i)]

func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if _cache.has(s):
		return _cache[s]
	var out := ""
	if _map.has(s):
		out = str(_map[s])
	else:
		var sp := _split_prefix(s)
		if sp[1] != "" and _map.has(sp[1]):
			out = sp[0] + str(_map[sp[1]])
		else:
			out = _from_template(s)
			if out == "" and s == s.to_upper() and _lower.has(s.to_lower()):
				out = String(_lower[s.to_lower()]).to_upper()
			if out == "" and s == s.to_upper() and sp[1] != "" and _lower.has(sp[1].to_lower()):
				out = sp[0] + String(_lower[sp[1].to_lower()]).to_upper()
			if out == "" and sp[1] != "" and sp[1] != s:
				var t2 := _from_template(sp[1])
				if t2 != "":
					out = sp[0] + t2
	_cache[s] = StringName(out)
	return _cache[s]
