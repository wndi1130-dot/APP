extends "res://addons/gut/test.gd"
## 자료만 만든다. MapView와 렌더러를 만들지 않는 전체 지도 계약 검사.

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const REQUIRED := [
	"grid", "levels", "stairs", "containers", "spots", "stoves", "entries", "train", "platform",
	"spawns", "labels", "trees", "low_blocks", "upper_rects", "train_cars", "lights", "buildings",
	"wagons", "manholes", "place_id", "place_kind", "bands", "train_doors", "crossings",
	"barricade_slots", "interior_kind_slots",
]


func test_registry_has_eighty_field_maps_and_the_first_stop() -> void:
	var ids := FieldMaps.ids()
	assert_eq(ids.size(), 81)
	assert_has(ids, FieldMaps.DEFAULT_PLACE)
	var unique: Dictionary = {}
	for id in ids:
		unique[id] = true
	assert_eq(unique.size(), ids.size())


func test_every_registered_map_builds_with_required_keys() -> void:
	for id in FieldMaps.ids():
		var data := FieldMaps.build(id)
		assert_false(data.is_empty(), id)
		for key: String in REQUIRED:
			assert_has(data, key, id + ": " + key)
		assert_eq(data.get("place_id", ""), id, "기본 지도로 조용히 대체되지 않음: " + id)
		var valid := data.get("grid") is FieldGrid and data.get("levels") is Dictionary
		assert_true(valid, id + ": grid/levels 자료형")
		if not valid:
			continue
		var grid: FieldGrid = data["grid"]
		assert_gt(grid.width, 0, id)
		assert_gt(grid.height, 0, id)
		assert_eq(grid.solid.size(), grid.width * grid.height, id)
		assert_eq(data["levels"].get(0), grid, id)
		assert_true(data.get("props", []) is Array, id)


func test_rock_wall_filter_rejects_featureless_buildings_and_cells_outside_rect() -> void:
	var grid := FieldGrid.new(8, 8)
	var inside := Vector2i(1, 1)
	var outside := Vector2i(5, 1)
	for c in [inside, outside]:
		grid.set_solid(c, FieldGrid.Solid.WALL)
		grid.building[grid.index(c)] = 0
	var building := {"id": 0, "rect": Rect2i(1, 1, 3, 3), "rooms": []}
	var data := {"grid": grid, "buildings": [building], "stairs": []}
	assert_true(BuildingView.plan(data)["pieces"].is_empty(), "문·창·방 없는 바위")
	building["rooms"].append({"rect": Rect2i(2, 2, 1, 1)})
	var plan := BuildingView.plan(data)
	var cells: Dictionary = plan["kinds"].get(Vector2i(0, 0), {})
	assert_true(cells.has(inside), "건물 rect 안")
	assert_false(cells.has(outside), "번호가 같아도 rect 밖은 회색 벽")
	assert_eq(grid.solid_at(outside), FieldGrid.Solid.WALL, "막힘 판정은 보존")
	assert_eq(grid.building_at(outside), 0, "자료의 번호는 보존")
