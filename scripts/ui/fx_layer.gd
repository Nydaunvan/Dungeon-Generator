class_name FxLayer
extends Control
## Effets visuels d'action (coup d'épée, sort, impact…) : un emoji animé au centre de la vue, comme dans le HTML.

const ICONS := {"sword": "⚔️", "axe": "🪓", "dagger": "🗡️", "staff": "🔱", "bow": "🏹", "mace": "🔨", "unarmed": "👊",
	"spellfire": "🔥", "spellholy": "✨", "spellarcane": "💠", "spellice": "❄️", "spellnature": "🌿", "spellshadow": "🌑",
	"spellphysical": "💥", "spellbard": "🎵", "trap": "🩸", "hit": "💥", "switch": "🔧", "fountain": "⛲"}
const COLORS := {"spellfire": "#ff6a2f", "spellholy": "#ffd88a", "spellarcane": "#b46bff", "spellice": "#8fd0f0", "spellnature": "#7fd17f",
	"spellshadow": "#9b7fd4", "spellphysical": "#e0d0a8", "spellbard": "#e878c0", "trap": "#ff4d4d", "hit": "#ffffff", "sword": "#dfe6ee",
	"axe": "#e0a860", "dagger": "#dfe6ee", "staff": "#c9a8ff", "bow": "#c8e0a0", "mace": "#e0a860", "unarmed": "#dfc9a8",
	"switch": "#c9a86a", "fountain": "#3aa8c8"}
# images clés : [t, tx, ty (fractions de la taille), rotation°, échelle, opacité]
const ANIMS := {
	"slash": [0.5, [[0.0, -0.95, -0.5, -40, 0.6, 0.0], [0.3, -0.6, -0.5, -10, 1.0, 1.0], [0.6, -0.05, -0.5, 20, 1.3, 1.0], [1.0, 0.15, -0.5, 40, 1.0, 0.0]]],
	"stab": [0.42, [[0.0, -0.5, 0.9, 0, 0.6, 0.0], [0.4, -0.5, 0.2, 0, 1.0, 1.0], [0.6, -0.5, -0.5, 0, 1.25, 1.0], [1.0, -0.5, -0.75, 0, 1.0, 0.0]]],
	"chop": [0.55, [[0.0, -0.5, -1.3, -20, 0.7, 0.0], [0.4, -0.5, -0.8, -5, 1.0, 1.0], [0.7, -0.5, -0.4, 12, 1.3, 1.0], [1.0, -0.5, -0.3, 0, 1.0, 0.0]]],
	"poke": [0.5, [[0.0, -0.5, -0.5, 0, 0.5, 0.0], [0.5, -0.5, -0.5, 15, 1.3, 1.0], [1.0, -0.5, -0.5, -10, 1.0, 0.0]]],
	"arrow": [0.45, [[0.0, -1.5, -0.3, 0, 0.8, 0.0], [0.2, -1.1, -0.4, 0, 0.9, 1.0], [1.0, 0.5, -0.75, 0, 1.1, 0.0]]],
	"burst": [0.6, [[0.0, -0.5, -0.5, 0, 0.3, 0.0], [0.4, -0.5, -0.5, 0, 1.4, 1.0], [1.0, -0.5, -0.5, 0, 1.9, 0.0]]],
}
const KIND := {"sword": "slash", "dagger": "stab", "axe": "chop", "mace": "chop", "staff": "poke", "bow": "arrow", "unarmed": "stab", "spellphysical": "slash", "switch": "poke"}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func play(type: String) -> void:
	if not ICONS.has(type):
		type = "hit"
	var kind: String = KIND.get(type, "burst")
	var spec: Array = ANIMS[kind]
	var dur: float = 1.8 if type == "fountain" else float(spec[0])
	var frames: Array = spec[1]
	var l := Label.new()
	l.text = ICONS[type]
	l.add_theme_font_size_override("font_size", 52)
	var col := Color(str(COLORS.get(type, "#ffffff")))
	l.add_theme_color_override("font_outline_color", Color(col, 0.55))
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.size = l.get_minimum_size()
	l.pivot_offset = l.size * 0.5
	var center := Vector2(size.x * 0.5, size.y * 0.54)
	var step := func(t: float):
		var k := 0
		while k < frames.size() - 2 and t > float(frames[k + 1][0]):
			k += 1
		var a: Array = frames[k]
		var b: Array = frames[k + 1]
		var u := clampf((t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
		var v := func(i: int) -> float: return lerpf(float(a[i]), float(b[i]), u)
		l.position = center + Vector2(v.call(1) * l.size.x, v.call(2) * l.size.y)
		l.rotation_degrees = v.call(3)
		l.scale = Vector2.ONE * float(v.call(4))
		l.modulate.a = v.call(5)
	step.call(0.0)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, dur)
	tw.tween_callback(l.queue_free)
