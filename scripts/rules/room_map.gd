class_name RoomMap
extends RefCounted
## Repère les salles d'une carte (générée OU dessinée à la main dans l'éditeur) : une salle est une zone de sol d'au moins 2 x 2 cases,
## d'au moins 6 cases au total. Tout le reste du sol est couloir. Sert aux décorations et aux statistiques ; ne touche jamais au jeu.

const MIN_CELLS := 6

static func _open(rows: Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size():
		return false
	var row := str(rows[y])
	if x < 0 or x >= row.length():
		return false
	var ch := row[x]
	return ch != "#" and ch != "S" and ch != "D"

## Salles de la carte : [{id, cells: Array[Vector2i], rect: Rect2i}] (rect = rectangle englobant, en cases).
static func detect(rows: Array) -> Array:
	var inside := {}
	for y in rows.size() - 1:
		for x in str(rows[0]).length() - 1:
			if _open(rows, x, y) and _open(rows, x + 1, y) and _open(rows, x, y + 1) and _open(rows, x + 1, y + 1):
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					inside[Vector2i(x, y) + d] = true
	var seen := {}
	var out: Array = []
	var keys: Array = inside.keys()
	keys.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for k in keys:
		if seen.has(k):
			continue
		var comp: Array = []
		var stack: Array = [k]
		seen[k] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			comp.append(c)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if inside.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		if comp.size() < MIN_CELLS:
			continue
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := Vector2i(-1, -1)
		for c in comp:
			mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
			mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
		out.append({"id": out.size(), "cells": comp, "rect": Rect2i(mn, mx - mn + Vector2i.ONE)})
	return out

## Case -> numéro de salle (Vector2i -> int), pour savoir si une case est dans une salle.
static func index(rooms: Array) -> Dictionary:
	var out := {}
	for r in rooms:
		for c in r.cells:
			out[c] = int(r.id)
	return out
