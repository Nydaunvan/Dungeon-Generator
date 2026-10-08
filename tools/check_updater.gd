extends Node
## Vérifie la logique des mises à jour : comparaison de versions, choix de la publication, sommes SHA-256, scripts de remplacement.

func _rel(tag: String, pre: bool, assets: Array = ["Dungeon-Generator-%s-windows.zip", "Dungeon-Generator-%s-linux.tar.gz"]) -> Dictionary:
	var v := tag.trim_prefix("v")
	var a: Array = []
	for n in assets:
		a.append({"name": n % v if "%s" in n else n, "browser_download_url": "https://x/" + (n % v if "%s" in n else n), "size": 10})
	return {"tag_name": tag, "prerelease": pre, "draft": false, "assets": a, "body": "### Notes\n- un", "html_url": "https://x/r"}

func _ready() -> void:
	var bad := 0
	var t := func(name: String, ok: bool):
		if not ok:
			print("ÉCHEC : ", name)
			bad += 1
	t.call("1.30.2 > 1.30.1", Updater.compare("1.30.2", "1.30.1") == 1)
	t.call("1.31.0 > 1.30.9", Updater.compare("1.31.0", "1.30.9") == 1)
	t.call("10 > 9", Updater.compare("1.10.0", "1.9.0") == 1)
	t.call("test < finale", Updater.compare("1.30.1-test1", "1.30.1") == -1)
	t.call("test2 > test1", Updater.compare("1.30.1-test2", "1.30.1-test1") == 1)
	t.call("égalité", Updater.compare("v1.30.1", "1.30.1") == 0)
	t.call("tag invalide", Updater.parse_version("V129_071026_Linux").is_empty())
	var rels := [_rel("v1.32.0", true), _rel("v1.31.0", false), _rel("v1.30.0", false), _rel("V129_071026_Linux", true), _rel("v1.33.0", false, ["autre.zip"])]
	var p := Updater.pick(rels, "1.30.1", false, "windows")
	t.call("finale la plus récente", p.get("version", "") == "1.31.0")
	t.call("asset windows", str(p.get("asset", "")) == "Dungeon-Generator-1.31.0-windows.zip")
	t.call("asset linux", str(Updater.pick(rels, "1.30.1", false, "linux").get("asset", "")).ends_with("-linux.tar.gz"))
	t.call("avec préversions", Updater.pick(rels, "1.30.1", true, "windows").get("version", "") == "1.32.0")
	t.call("version ignorée", Updater.pick(rels, "1.30.1", false, "windows", "1.31.0").is_empty())
	t.call("à jour", Updater.pick(rels, "1.31.0", false, "windows").is_empty())
	t.call("sans asset adapté", Updater.pick([_rel("v1.40.0", false, ["autre.zip"])], "1.30.1", false, "windows").is_empty())
	var sums := "AAA111  Dungeon-Generator-1.31.0-windows.zip\nbbb222 *Dungeon-Generator-1.31.0-linux.tar.gz\n"
	t.call("somme windows", Updater.expected_sum(sums, "Dungeon-Generator-1.31.0-windows.zip") == "aaa111")
	t.call("somme linux", Updater.expected_sum(sums, "Dungeon-Generator-1.31.0-linux.tar.gz") == "bbb222")
	t.call("somme absente", Updater.expected_sum(sums, "x.zip") == "")
	var bat := Updater.windows_script("C:/J é/g.exe.new", "C:/J é/g.exe")
	t.call("script windows", bat.contains("fso.CopyFile \"C:\\J é\\g.exe.new\", \"C:\\J é\\g.exe\", True") and bat.contains("sh.Run Chr(34) & \"C:\\J é\\g.exe\" & Chr(34)") and not bat.to_lower().contains("cmd"))
	var vb := Updater.vbs_bytes("é")
	t.call("VBS en UTF-16 avec marque", vb[0] == 0xFF and vb[1] == 0xFE and vb.size() == 4)
	var sh := Updater.linux_script("/o/g.new", "/o/g")
	t.call("script linux", sh.contains("mv -f '/o/g.new' '/o/g'") and sh.contains("nohup '/o/g'"))
	# extraction d'une archive Windows factice
	var dir := ProjectSettings.globalize_path("user://update_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var zp := dir + "/t.zip"
	var zw := ZIPPacker.new()
	zw.open(zp)
	zw.start_file("Dungeon Generator.exe")
	zw.write_file("MZ-fake".to_utf8_buffer())
	zw.close_file()
	zw.close()
	var zr := ZIPReader.new()
	t.call("zip lisible", zr.open(zp) == OK and zr.read_file("Dungeon Generator.exe").get_string_from_utf8() == "MZ-fake")
	zr.close()
	t.call("sha256", FileAccess.get_sha256(zp).length() == 64)
	DirAccess.remove_absolute(zp)
	DirAccess.remove_absolute(dir)
	print("OK : mises à jour" if bad == 0 else "%d écart(s)" % bad)
	get_tree().quit(1 if bad > 0 else 0)
