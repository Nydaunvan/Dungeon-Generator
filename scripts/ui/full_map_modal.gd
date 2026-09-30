class_name FullMapModal
extends RefCounted
## Carte du niveau en plein écran (touche M) avec sa légende.

static func open(host: Node, grid: DungeonGrid, rig: PlayerRig, gs: GameState, merchant_cell: Callable) -> Modal:
	var m := Modal.open(host, "🗺️ " + str(grid.level.get("name", "Carte")), 760.0)
	var mp := Minimap.new()
	mp.full = true
	mp.grid = grid
	mp.rig = rig
	mp.gs = gs
	mp.merchant_cell = merchant_cell
	var vp := host.get_viewport().get_visible_rect().size
	var side := minf(vp.y * 0.42, 460.0)
	var ratio := float(grid.width) / float(grid.height)
	mp.custom_minimum_size = Vector2(minf(side * ratio, vp.x - 80.0), side)
	mp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.content.add_child(mp)
	var rows := [["▲", "Votre position et direction actuelles"], ["🚪", "Porte"], ["✨", "Escalier (changement de niveau ou victoire)"],
		["⛲", "Fontaine (soin, endurance, résurrection)"], ["🔴", "Monstre repéré"], ["🟡", "Boss repéré"]]
	if grid.level.has("travelingMerchant"):
		rows.append(["🧙", "Marchand ambulant"])
	var leg := HFlowContainer.new()
	leg.add_theme_constant_override("h_separation", 16)
	for r in rows:
		leg.add_child(AdminUtil.label("%s  %s" % [r[0], r[1]], 12, UiTheme.DIM))
	m.content.add_child(leg)
	m.set_buttons([{"text": "Fermer", "cb": func(): m.close()}])
	return m
