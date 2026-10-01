extends SceneTree
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1280, 720)
	await process_frame
	root.get_node("Data").set_lang(str(args.get("lang", "fr")))
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var topic := str(args.get("topic", ""))
	if str(args.get("kind", "guide")) == "tutorial":
		DocModal.tutorial(host)
	else:
		DocModal.guide(host, topic)
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png(str(args.get("out", "/tmp/doc.png")))
	root.get_node("Data").set_lang("fr")
	quit()
