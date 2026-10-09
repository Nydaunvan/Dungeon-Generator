extends Node
## Vérifie la logique des mises à jour : comparaison de versions, choix de la publication (manifeste de la plateforme), liste des
## fichiers à télécharger (état installé, repli sur la somme), scripts de remplacement.

func _rel(tag: String, pre: bool, assets: Array = ["manifest-windows.json", "manifest-linux.json"]) -> Dictionary:
	var a: Array = []
	for n in assets:
		a.append({"name": n, "browser_download_url": "https://x/" + tag + "/" + n, "size": 10})
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
	var rels := [_rel("v1.32.0", true), _rel("v1.31.0", false), _rel("v1.30.0", false), _rel("V129_071026_Linux", true), _rel("v1.33.0", false, ["Dungeon-Generator-1.33.0-windows.zip"])]
	var p := Updater.pick(rels, "1.30.1", false, "windows")
	t.call("finale la plus récente", p.get("version", "") == "1.31.0")
	t.call("manifeste windows", str(p.get("manifest_url", "")).ends_with("manifest-windows.json"))
	t.call("manifeste linux", str(Updater.pick(rels, "1.30.1", false, "linux").get("manifest_url", "")).ends_with("manifest-linux.json"))
	t.call("avec préversions", Updater.pick(rels, "1.30.1", true, "windows").get("version", "") == "1.32.0")
	t.call("version ignorée", Updater.pick(rels, "1.30.1", false, "windows", "1.31.0").is_empty())
	t.call("à jour", Updater.pick(rels, "1.31.0", false, "windows").is_empty())
	t.call("ancien format écarté", Updater.pick([_rel("v1.40.0", false, ["Dungeon-Generator-1.40.0-windows.zip"])], "1.30.1", false, "windows").is_empty())
	# fichiers à télécharger
	var f := {"path": "packs/themes.pck", "asset": "themes.pck", "size": 100, "sha256": "aaa", "content": "c1"}
	var never := func(): return "zzz"
	t.call("absent → à télécharger", Updater.needs_download(f, {}, -1, never))
	t.call("état identique → rien", not Updater.needs_download(f, {"packs/themes.pck": {"content": "c1", "size": 90}}, 90, never))
	t.call("contenu différent → à télécharger", Updater.needs_download(f, {"packs/themes.pck": {"content": "c0", "size": 90}}, 90, never))
	t.call("taille locale différente → à télécharger", Updater.needs_download(f, {"packs/themes.pck": {"content": "c1", "size": 90}}, 80, never))
	t.call("sans état : somme égale → rien", not Updater.needs_download(f, {}, 100, func(): return "aaa"))
	t.call("sans état : somme différente → à télécharger", Updater.needs_download(f, {}, 100, func(): return "bbb"))
	# scripts
	var pairs := [["C:/U é/a.pck", "C:/J é/packs/a.pck"], ["C:/U é/e.exe", "C:/J é/g.exe"]]
	var bat := Updater.windows_script(pairs, "C:/J é/g.exe")
	t.call("script windows : copies", bat.contains("fso.CopyFile \"C:\\U é\\a.pck\", \"C:\\J é\\packs\\a.pck\", True") and bat.contains("fso.CopyFile \"C:\\U é\\e.exe\", \"C:\\J é\\g.exe\", True"))
	t.call("script windows : relance, sans cmd", bat.contains("sh.Run Chr(34) & \"C:\\J é\\g.exe\" & Chr(34)") and not bat.to_lower().contains("cmd"))
	var vb := Updater.vbs_bytes("é")
	t.call("VBS en UTF-16 avec marque", vb[0] == 0xFF and vb[1] == 0xFE and vb.size() == 4)
	var sh := Updater.linux_script([["/u/a.pck", "/o/packs/a.pck"]], "/o/g")
	t.call("script linux", sh.contains("mkdir -p '/o/packs' && cp -f '/u/a.pck' '/o/packs/a.pck'") and sh.contains("nohup '/o/g'"))
	t.call("exécutable en dernier", Updater._rank("/o/g.exe") > Updater._rank("/o/Dungeon Generator.pck") and Updater._rank("/o/Dungeon Generator.pck") > Updater._rank("/o/packs/a.pck"))
	print("OK : mises à jour" if bad == 0 else "%d écart(s)" % bad)
	get_tree().quit(1 if bad > 0 else 0)
