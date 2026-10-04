class_name ScanUtil
extends RefCounted
## Relève tous les textes visibles (libellés, boutons, infobulles, listes) sous un nœud, pour le contrôle des langues.

static func dump(root: Node, path: String) -> void:
	var out: Array = []
	_walk(root, out)
	var f := FileAccess.open(path, FileAccess.WRITE)
	for t in out:
		f.store_line(str(t).replace("\n", "\\n"))

static func _walk(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Label and (n as Label).text != "":
		out.append(n.atr((n as Label).text))
	elif n is Button and (n as Button).text != "":
		out.append(n.atr((n as Button).text))
	elif n is RichTextLabel:
		out.append((n as RichTextLabel).get_parsed_text())
	elif n is LineEdit:
		var l := n as LineEdit
		if l.placeholder_text != "":
			out.append(n.atr(l.placeholder_text))
	if n is Control and (n as Control).tooltip_text != "":
		out.append("[tip] " + n.atr((n as Control).tooltip_text))
	if n is OptionButton:
		var ob := n as OptionButton
		for i in ob.item_count:
			out.append(n.atr(ob.get_item_text(i)))
	for c in n.get_children():
		_walk(c, out)
