class_name Files
extends RefCounted
## Échange de fichiers texte avec l'utilisateur : téléchargement (Web) / boîtes de dialogue natives (ordinateur).

static func save_text(host: Node, file_name: String, text: String, on_done: Callable = Callable()) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")
		if on_done.is_valid():
			on_done.call("Téléchargement lancé : %s" % file_name)
		return
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.current_file = file_name
	dlg.filters = PackedStringArray(["*.json ; Fichier JSON"])
	dlg.file_selected.connect(func(path: String):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(text)
		if on_done.is_valid():
			on_done.call("Fichier enregistré : %s" % path if f != null else "Échec de l'enregistrement.")
		dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	host.add_child(dlg)
	dlg.popup_centered_ratio(0.6)

## Choisit un fichier texte ; `on_text(text)` reçoit son contenu. Sur le Web, ouvre plutôt la fenêtre « coller le contenu ».
static func pick_text(host: Node, on_text: Callable) -> void:
	if OS.has_feature("web"):
		paste_dialog(host, "Importer un fichier JSON", "Ouvrez le fichier JSON dans un éditeur de texte, copiez tout son contenu et collez-le ci-dessous.", on_text)
		return
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.filters = PackedStringArray(["*.json ; Fichier JSON"])
	dlg.file_selected.connect(func(path: String):
		on_text.call(FileAccess.get_file_as_string(path))
		dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	host.add_child(dlg)
	dlg.popup_centered_ratio(0.6)

## Fenêtre avec une zone de texte à remplir ; `on_text` reçoit le contenu validé.
static func paste_dialog(host: Node, title: String, explain: String, on_text: Callable) -> Modal:
	var m := Modal.open(host, title, 520.0)
	m.add_text(explain, UiTheme.DIM, 14, true)
	var t := TextEdit.new()
	t.custom_minimum_size = Vector2(0, 160)
	t.placeholder_text = "Collez ici…"
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	m.content.add_child(t)
	var ok := func():
		var txt := t.text
		m.close()
		on_text.call(txt)
	m.set_buttons([{"text": "Valider", "cb": ok}, {"text": "Annuler", "cb": func(): m.close()}])
	return m

static func copy(text: String) -> void:
	DisplayServer.clipboard_set(text)
