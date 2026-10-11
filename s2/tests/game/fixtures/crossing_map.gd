extends RefCounted
## The open-line stop with one way over the train, at the coupling in its middle.

const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")

const PLACE_ID: String = "mine_97"
const WAY_X: int = 30


static func build() -> Dictionary:
	var d: Dictionary = BareLine.build()
	var train: Rect2i = d["train"]
	var cells: Array = []
	for y in range(train.position.y, train.end.y):
		cells.append(Vector2i(WAY_X, y))
	d["crossings"] = [{"cells": cells, "who": {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false}}]
	return d
