class_name Library
extends RefCounted
## Bibliothèque de monstres : un dossier par monstre sous user://studio/.

const ROOT := "user://studio"
const EXTS := ["png", "webp", "jpg", "jpeg"]

static func slugify(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")

static func list_all() -> Array[Monster]:
	var out: Array[Monster] = []
	DirAccess.make_dir_recursive_absolute(ROOT)
	var d := DirAccess.open(ROOT)
	if d == null:
		return out
	for n in d.get_directories():
		var m := Monster.new()
		m.slug = n
		m.title = n
		m.load_meta()
		out.append(m)
	out.sort_custom(func(a: Monster, b: Monster): return a.title.naturalnocasecmp_to(b.title) < 0)
	return out

## Importe une image (png, webp, jpg) : crée le monstre et enregistre la source en PNG. Renvoie null si l'image est illisible.
static func import_image(path: String) -> Monster:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	var base := slugify(path.get_file().get_basename())
	if base == "":
		base = "monstre"
	var slug := base
	var n := 2
	while DirAccess.dir_exists_absolute(ROOT + "/" + slug):
		slug = "%s_%d" % [base, n]
		n += 1
	var m := Monster.new()
	m.slug = slug
	m.title = path.get_file().get_basename()
	DirAccess.make_dir_recursive_absolute(m.dir())
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(m.source_path())
	m.save()
	return m

static func delete(m: Monster) -> void:
	var d := DirAccess.open(m.dir())
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(m.dir())
