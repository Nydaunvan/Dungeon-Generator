class_name AccountModal
extends RefCounted
## Fenêtre « Compte » (partie en ligne, facultative) : connexion, création de compte, mot de passe oublié ; une fois connecté :
## pseudo, email, déconnexion, suppression du compte. Le jeu reste entièrement jouable sans compte.

var _modal: Modal
var _mode := "login"          # login | signup | account
var _busy := false
var _email: LineEdit
var _pass: LineEdit
var _pseudo: LineEdit
var _status: Label
var _offline_note := ""

static func open(host: Node) -> AccountModal:
	var a := AccountModal.new()
	a._modal = Modal.open(host, L.t("ui.cloud.title"), 440.0)
	a._mode = "account" if Cloud.is_signed_in() else "login"
	a._build()
	if Cloud.is_signed_in():
		a._check_session()
	return a

## Vérifie en arrière-plan que la session mémorisée est encore valable (sans bloquer la fenêtre).
func _check_session() -> void:
	var r: Dictionary = await Cloud.restore_session()
	if not is_instance_valid(_modal) or _modal.is_queued_for_deletion():
		return
	if r.ok:
		await Cloud.load_profile()
	elif r.offline:
		_offline_note = L.t("ui.cloud.offline_note")
	else:
		_mode = "login"
	if is_instance_valid(_modal) and not _modal.is_queued_for_deletion():
		_build()

func _clear() -> void:
	for c in _modal.content.get_children():
		_modal.content.remove_child(c)
		c.queue_free()

func _build() -> void:
	_clear()
	if not Cloud.is_configured():
		_modal.add_text(L.t("ui.cloud.err.not_configured"), UiTheme.PARCH, 15)
		_modal.set_buttons([{"text": L.t("common.ok"), "cb": func(): _modal.close()}])
		return
	if _mode == "account":
		_build_account()
	else:
		_build_form()

# ------------------------------------------------------------------ formulaire

func _build_form() -> void:
	var signup := _mode == "signup"
	var c := _modal.content
	_modal.add_text(L.t("ui.cloud.intro_signup") if signup else L.t("ui.cloud.intro_login"), UiTheme.DIM, 14, true)
	_email = Form.text_row(c, L.t("ui.cloud.email"), "", 220.0)
	_email.placeholder_text = "nom@exemple.fr"
	_email.text_submitted.connect(func(_t): _submit())
	if signup:
		_pseudo = Form.text_row(c, L.t("ui.cloud.pseudo"), "", 220.0)
		_pseudo.max_length = 20
		_pseudo.text_submitted.connect(func(_t): _submit())
	_pass = Form.text_row(c, L.t("ui.cloud.password"), "", 220.0)
	_pass.secret = true
	_pass.text_submitted.connect(func(_t): _submit())
	if signup:
		Form.note(c, L.t("ui.cloud.signup_rules"))
	_status = Form.status_label(c)
	var specs: Array = [
		{"text": L.t("ui.cloud.btn_signup") if signup else L.t("ui.cloud.btn_login"), "primary": true, "cb": _submit},
		{"text": L.t("ui.cloud.switch_to_login") if signup else L.t("ui.cloud.switch_to_signup"),
			"cb": func(): _switch("login" if signup else "signup")},
	]
	if not signup:
		specs.append({"text": L.t("ui.cloud.forgot"), "cb": _forgot})
	specs.append({"text": L.t("common.fermer"), "cb": func(): _modal.close()})
	_modal.set_buttons(specs)
	(func(): if is_instance_valid(_email) and _email.is_inside_tree(): _email.grab_focus()).call_deferred()

func _switch(mode: String) -> void:
	if _busy:
		return
	_mode = mode
	_build()

func _say(text: String, bad: bool = false) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text
		_status.add_theme_color_override("font_color", Color("e08a7a") if bad else Color("9cc79a"))

func _set_busy(on: bool) -> void:
	_busy = on
	if _status != null and is_instance_valid(_status) and on:
		_say(L.t("ui.cloud.working"))

func _valid_email(s: String) -> bool:
	return RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}$").search(s.strip_edges()) != null

func _submit() -> void:
	if _busy or _mode == "account":
		return
	var mail := _email.text.strip_edges()
	var pw := _pass.text
	if not _valid_email(mail):
		_say(L.t("ui.cloud.err.invalid_email"), true)
		return
	if _mode == "login":
		if pw == "":
			_say(L.t("ui.cloud.err.invalid_credentials"), true)
			return
		_set_busy(true)
		var r: Dictionary = await Cloud.sign_in(mail, pw)
		_set_busy(false)
		_after(r)
		return
	var pseudo := _pseudo.text.strip_edges()
	if not RegEx.create_from_string("^[A-Za-z0-9_-]{3,20}$").search(pseudo):
		_say(L.t("ui.cloud.err.pseudo_invalide"), true)
		return
	if pw.length() < 8:
		_say(L.t("ui.cloud.err.weak_password"), true)
		return
	_set_busy(true)
	var r2: Dictionary = await Cloud.sign_up(mail, pw, pseudo)
	_set_busy(false)
	if r2.ok and r2.get("needs_confirmation", false):
		if is_instance_valid(_modal):
			_mode = "login"
			_build()
			_say(L.t("ui.cloud.confirm_sent"))
		return
	_after(r2)

func _after(r: Dictionary) -> void:
	if not is_instance_valid(_modal) or _modal.is_queued_for_deletion():
		return
	if not r.ok:
		_say(str(r.message), true)
		return
	_mode = "account"
	_build()

func _forgot() -> void:
	if _busy:
		return
	var mail := _email.text.strip_edges()
	if not _valid_email(mail):
		_say(L.t("ui.cloud.forgot_need_email"), true)
		return
	_set_busy(true)
	var r: Dictionary = await Cloud.reset_password(mail)
	_set_busy(false)
	if not is_instance_valid(_modal) or _modal.is_queued_for_deletion():
		return
	_say(L.t("ui.cloud.reset_sent") if r.ok else str(r.message), not r.ok)

# ------------------------------------------------------------------ compte connecté

func _build_account() -> void:
	var c := _modal.content
	_modal.add_text(L.fa(L.t("ui.cloud.signed_in_as"), Cloud.pseudo()), Color("ffd98a"), 18)
	_modal.add_text(Cloud.email(), UiTheme.DIM, 14)
	if _offline_note != "":
		_modal.add_text(_offline_note, Color("e0b87a"), 13, true)
	_modal.add_text(L.t("ui.cloud.optional_note"), UiTheme.DIM, 13, true)
	_status = Form.status_label(c)
	var specs: Array = [{"text": L.t("ui.challenges.btn_rewards"), "primary": true, "cb": func(): RewardsModal.open(_modal.get_parent())}]
	# Menu « Super admin » : affiché seulement si le SERVEUR a confirmé le rôle (il le revérifie de toute façon à chaque appel).
	if SuperAdmin.cached() == 1:
		specs.append({"text": L.t("ui.sadmin.btn"), "cb": func(): SuperAdminModal.open(_modal.get_parent())})
	elif SuperAdmin.cached() == -1:
		_probe_admin()
	specs.append_array([
		{"text": L.t("ui.cloud.btn_logout"), "cb": _logout},
		{"text": L.t("ui.cloud.btn_delete"), "cb": _ask_delete},
		{"text": L.t("common.fermer"), "cb": func(): _modal.close()},
	])
	_modal.set_buttons(specs)

## Demande au serveur si le compte est super admin ; ne reconstruit la fenêtre que pour AJOUTER le bouton.
func _probe_admin() -> void:
	if await SuperAdmin.check() and is_instance_valid(_modal) and not _modal.is_queued_for_deletion() and _mode == "account":
		_build()

func _logout() -> void:
	if _busy:
		return
	_set_busy(true)
	SuperAdmin.forget()
	await Cloud.sign_out()
	_set_busy(false)
	if is_instance_valid(_modal) and not _modal.is_queued_for_deletion():
		_mode = "login"
		_offline_note = ""
		_build()

func _ask_delete() -> void:
	if _busy:
		return
	Dialogs.confirm(_modal.get_parent(), L.t("ui.cloud.delete_title"), L.t("ui.cloud.delete_text"), _delete, L.t("ui.cloud.delete_yes"))

func _delete() -> void:
	_set_busy(true)
	var r: Dictionary = await Cloud.delete_account()
	_set_busy(false)
	if not is_instance_valid(_modal) or _modal.is_queued_for_deletion():
		return
	if r.ok:
		_mode = "login"
		_build()
		_say(L.t("ui.cloud.deleted"))
	else:
		_say(str(r.message), true)
