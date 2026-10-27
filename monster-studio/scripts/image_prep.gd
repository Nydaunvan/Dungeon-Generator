class_name ImagePrep
extends RefCounted
## Préparation de l'image avant TripoSR : détourage d'un fond uni (ce que TripoSR fait mal sur du vert vif, d'où des contours
## « approximatifs »), recadrage serré, mise à l'échelle (le sujet occupe 85 % de l'image) et pose sur gris neutre,
## exactement ce que TripoSR attend quand on lui passe --no-remove-bg.

const SIZE := 512
const RATIO := 0.85
const WORK := 768                 # côté max de travail (plus rapide, largement suffisant)
const TOL_LOW := 0.14             # écart de couleur en dessous duquel c'est du fond
const TOL_HIGH := 0.30            # au-dessus, c'est sûrement le sujet

## Écrit `dst` (PNG carré, sujet sur gris). Renvoie "" si OK, sinon la raison pour laquelle on garde l'image d'origine.
static func prepare(src: String, dst: String) -> String:
	var img := Image.load_from_file(src)
	if img == null or img.is_empty():
		return "image illisible"
	img.convert(Image.FORMAT_RGBA8)
	var m := maxi(img.get_width(), img.get_height())
	if m > WORK:
		var k := float(WORK) / float(m)
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var has_alpha := false
	for i in range(3, d.size(), 4):
		if d[i] < 250:
			has_alpha = true
			break
	# Fond : transparence déjà présente, sinon couleur uniforme sur le pourtour.
	var bg := Vector3.ZERO
	if not has_alpha:
		var ring: Array = []
		for t in 3:
			for x in w:
				ring.append(_px(d, w, x, t))
				ring.append(_px(d, w, x, h - 1 - t))
			for y in h:
				ring.append(_px(d, w, t, y))
				ring.append(_px(d, w, w - 1 - t, y))
		bg = Vector3(_median(ring, 0), _median(ring, 1), _median(ring, 2))   # médiane : insensible au sujet qui touche le bord
		var near := 0
		for c in ring:
			if (c as Vector3).distance_to(bg) < TOL_LOW:
				near += 1
		if float(near) / float(ring.size()) < 0.8:
			return "fond non uniforme (TripoSR le détourera lui-même)"
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			var o := (y * w + x) * 4
			var on := false
			if has_alpha:
				on = d[o + 3] > 128
			else:
				var dist := (_px(d, w, x, y) - bg).length()
				on = dist > (TOL_LOW + TOL_HIGH) * 0.5
			mask[y * w + x] = 1 if on else 0
	mask = _erode(mask, w, h)
	mask = _keep_big(mask, w, h)
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			if mask[y * w + x] == 1:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if x1 < x0 or (x1 - x0) < 8 or (y1 - y0) < 8:
		return "sujet introuvable"
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	out.fill(Color(0.5, 0.5, 0.5))
	var sub := Image.create(x1 - x0 + 1, y1 - y0 + 1, false, Image.FORMAT_RGBA8)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if mask[y * w + x] == 1:
				var o2 := (y * w + x) * 4
				sub.set_pixel(x - x0, y - y0, Color8(d[o2], d[o2 + 1], d[o2 + 2], 255))
			else:
				sub.set_pixel(x - x0, y - y0, Color(0.5, 0.5, 0.5, 1.0))
	var sc := float(SIZE) * RATIO / float(maxi(sub.get_width(), sub.get_height()))
	sub.resize(maxi(1, int(sub.get_width() * sc)), maxi(1, int(sub.get_height() * sc)), Image.INTERPOLATE_LANCZOS)
	sub.convert(Image.FORMAT_RGB8)
	out.blit_rect(sub, Rect2i(0, 0, sub.get_width(), sub.get_height()), Vector2i((SIZE - sub.get_width()) / 2, (SIZE - sub.get_height()) / 2))
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	return "" if out.save_png(dst) == OK else "écriture impossible"

static func _px(d: PackedByteArray, w: int, x: int, y: int) -> Vector3:
	var o := (y * w + x) * 4
	return Vector3(d[o], d[o + 1], d[o + 2]) / 255.0

## Retire un pixel de pourtour au sujet (supprime la frange de couleur du fond).
static func _erode(mask: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var out := mask.duplicate()
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				continue
			if x == 0 or y == 0 or x == w - 1 or y == h - 1 \
					or mask[y * w + x - 1] == 0 or mask[y * w + x + 1] == 0 or mask[(y - 1) * w + x] == 0 or mask[(y + 1) * w + x] == 0:
				out[y * w + x] = 0
	return out

## Ne garde que les morceaux d'au moins 2 % du plus gros (écarte filigrane, poussières).
static func _keep_big(mask: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var label := PackedInt32Array()
	label.resize(w * h)
	var sizes: Array = [0]
	var cur := 0
	for s in w * h:
		if mask[s] == 0 or label[s] != 0:
			continue
		cur += 1
		var cnt := 0
		var stack: Array = [s]
		label[s] = cur
		while not stack.is_empty():
			var p: int = stack.pop_back()
			cnt += 1
			var px := p % w
			var py := p / w
			for nb in [[px - 1, py], [px + 1, py], [px, py - 1], [px, py + 1]]:
				if nb[0] < 0 or nb[1] < 0 or nb[0] >= w or nb[1] >= h:
					continue
				var q: int = nb[1] * w + nb[0]
				if mask[q] == 1 and label[q] == 0:
					label[q] = cur
					stack.append(q)
		sizes.append(cnt)
	var big := 0
	for i in range(1, sizes.size()):
		big = maxi(big, int(sizes[i]))
	var out := PackedByteArray()
	out.resize(w * h)
	for s2 in w * h:
		var l := label[s2]
		if l > 0 and int(sizes[l]) >= big * 0.02:
			out[s2] = 1
	return out

static func _median(vals: Array, axis: int) -> float:
	var a: Array = vals.map(func(v): return (v as Vector3)[axis])
	a.sort()
	return float(a[a.size() / 2])
