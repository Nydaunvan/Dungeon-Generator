class_name UpdateModal
extends RefCounted
## Fenêtres de mise à jour : annonce d'une nouvelle version (notes, Mettre à jour / Plus tard / Ignorer), progression du
## téléchargement, échec. `check` lance la vérification ; `force` = demande du joueur (Paramètres) : on répond toujours.

static func check(host: Node, force: bool = false) -> void:
	var u := Updater.new()
	host.add_child(u)
	u.check_done.connect(func(r: Dictionary):
		u.queue_free()
		if r.has("error"):
			if force:
				Dialogs.notice(host, L.t("ui.update.titre_verif"), L.t("ui.update.erreur_reseau"))
		elif r.is_empty():
			if force:
				Dialogs.notice(host, L.t("ui.update.titre_verif"), L.fa(L.t("ui.update.a_jour"), AppVersion.number()))
		else:
			open(host, r))
	u.check(force)

static func open(host: Node, info: Dictionary) -> Modal:
	var m := Modal.open(host, L.t("ui.update.titre"), 520.0)
	m.esc_closes = true
	var pre := " (" + L.t("ui.update.prerelease") + ")" if bool(info.get("prerelease", false)) else ""
	m.add_text(L.fa(L.t("ui.update.texte"), [str(info.version) + pre, AppVersion.number()]), UiTheme.PARCH, 15, false)
	if int(info.get("download_size", 0)) > 0:
		m.add_text(L.fa(L.t("ui.update.taille"), maxi(1, int(info.download_size) / 1048576)), UiTheme.DIM, 13, true)
	m.add_text(L.t("ui.update.sauvegardes"), UiTheme.DIM, 13, true)
	var shown := 0
	for line in str(info.get("notes", "")).split("\n"):
		var t := line.strip_edges()
		if t == "" or shown >= 24:
			continue
		shown += 1
		if t.begins_with("#"):
			m.add_text(t.lstrip("#").strip_edges(), UiTheme.GOLD, 15)
		else:
			var l := m.add_text("• " + t.trim_prefix("- "), UiTheme.PARCH, 13)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.set_buttons([
		{"text": L.t("ui.update.maj"), "primary": true, "cb": func(): _start(host, m, info)},
		{"text": L.t("ui.update.plus_tard"), "cb": func(): m.close()},
		{"text": L.t("ui.update.ignorer"), "cb": func():
			Updater.set_pref("ignored", str(info.version))
			m.close()}])
	return m

static func _start(host: Node, m: Modal, info: Dictionary) -> void:
	if not Updater.can_self_update() or (info.get("plan", []) as Array).is_empty():
		OS.shell_open(str(info.get("page", "")))     # éditeur, autre plateforme : page de la publication
		m.close()
		return
	for ch in m.content.get_children():
		ch.queue_free()
	m.esc_closes = false
	var label := m.add_text(L.t("ui.update.telechargement"), UiTheme.PARCH, 15)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, UiMetrics.css(18.0))
	m.content.add_child(bar)
	var u := Updater.new()
	m.add_child(u)
	u.progress.connect(func(done: int, total: int):
		bar.value = float(done) / float(total) if total > 0 else 0.0
		label.text = L.fa(L.t("ui.update.mo"), [done / 1048576, maxi(total, done) / 1048576]))
	u.finished.connect(func(ok: bool, msg: String):
		if ok:
			label.text = L.t("ui.update.installation")
			bar.value = 1.0
			m.set_buttons([])
			await host.get_tree().create_timer(0.8).timeout
			host.get_tree().quit()
		else:
			m.close()
			Dialogs.notice(host, L.t("ui.update.titre"), L.fa(L.t("ui.update.echec"), msg))
			OS.shell_open(str(info.get("page", ""))))
	m.set_buttons([{"text": L.t("common.annuler"), "cb": func():
		u.cancel()
		m.close()}])
	u.download(info)
