extends RefCounted
## A map with only what a map must have, for test_field_maps.

const FieldGrid = preload("res://game/world/field_grid.gd")

const PLACE_ID: String = "mine_99"


static func build() -> Dictionary:
	var g := FieldGrid.new(8, 6)
	return {
		"grid": g, "levels": {0: g}, "stairs": [], "entries": {"road": [Vector2i(0, 5)]},
		"entry_gap": {"road": 0.6}, "spawns": {"squad": [Vector2i(3, 3)], "train_door": [Vector2i(4, 2)], "dead_yard": [Vector2i(6, 4), Vector2i(1, 4)], "dead_levels": []},
		"train": Rect2i(1, 1, 6, 1),
		"place_kind": "mine", "bands": {"upper": Rect2i(0, 0, 8, 1)},
	}
