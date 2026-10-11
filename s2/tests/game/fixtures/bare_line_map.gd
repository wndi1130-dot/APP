extends RefCounted
## A train stopped on open line: ground on both sides, no platform, no
## building, nothing to search, no sewer. What a map must have and no more.

const FieldGrid = preload("res://game/world/field_grid.gd")

const PLACE_ID: String = "mine_98"
const WIDTH: int = 60
const HEIGHT: int = 30


static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var train := Rect2i(14, 14, 32, 3)
	for y in range(train.position.y, train.end.y):
		for x in range(WIDTH):
			g.floor[g.index(Vector2i(x, y))] = FieldGrid.Floor.RAIL
		for x in range(train.position.x, train.end.x):
			g.set_solid(Vector2i(x, y), FieldGrid.Solid.BLOCK)
	g.refresh_paths()
	return {
		"grid": g, "levels": {0: g}, "stairs": [], "train": train,
		"train_doors": {"upper": [Vector2i(20, 13), Vector2i(36, 13)], "lower": [Vector2i(20, 17), Vector2i(36, 17)]},
		"entries": {"track_west": [Vector2i(0, 15), Vector2i(0, 14)], "field_south": [Vector2i(30, HEIGHT - 1), Vector2i(31, HEIGHT - 1)]},
		"entry_gap": {"track_west": 0.6, "field_south": 0.6},
		"spawns": {"squad": [Vector2i(20, 19), Vector2i(21, 19), Vector2i(22, 19), Vector2i(23, 19)], "train_door": [Vector2i(20, 17), Vector2i(36, 17)]},
		"place_kind": "mine",
	}
