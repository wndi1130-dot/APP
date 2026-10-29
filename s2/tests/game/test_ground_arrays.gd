extends "res://addons/gut/test.gd"
## 2a: the stop loader's worker makes the ground's and the floors' arrays ahead (and the
## side path first, with the field's seed); the field lays them as they are, or works
## them out again here when the map changed since.

const Maps = preload("res://game/world/field_maps.gd")
const MapView = preload("res://game/world/map_view.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const SidePath = preload("res://game/world/side_path.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const PLACE := "mine_01"


func _ready_map(run_seed: int) -> Dictionary:
	return StopLoader.make_ready(load(Maps.path_of(PLACE)), run_seed)


## The ground as a SurfaceTool lays it, row by row, a cell's corners one call after
## another: what MapView wrote before it filled the arrays itself.
func _surface_tool_ground(g: FieldGrid, details: PackedFloat32Array) -> Dictionary:
	var banks := PackedVector2Array()
	for y in range(g.height + 1):
		for x in range(g.width + 1):
			banks.append(MapView.drift_uv(g, Vector2i(x, y)))
	var tools := {}
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			var tile := c / MapView.TILE
			if not tools.has(tile):
				var begun := SurfaceTool.new()
				begun.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[tile] = begun
			var st: SurfaceTool = tools[tile]
			var f := g.floor_at(c)
			var color: Color = MapView.FLOOR_COLORS[f]
			color.a = MapView.sky_alpha(g, c)
			var a := Vector3(x, 0, y)
			var quad := [a, a + Vector3(1, 0, 0), a + Vector3(1, 0, 1), a + Vector3(0, 0, 1)]
			var cell_detail: float = details[g.index(c)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var corner := Vector2i(int(quad[idx].x), int(quad[idx].z))
				st.set_color(color)
				st.set_normal(Vector3.UP)
				st.set_uv(banks[corner.y * (g.width + 1) + corner.x])
				var detail := cell_detail
				if cell_detail == 0.0 and (f == FieldGrid.Floor.SNOW or f == FieldGrid.Floor.DEEP_SNOW):
					detail = details[g.width * g.height + corner.y * (g.width + 1) + corner.x]
				st.set_uv2(Vector2(f + 1, detail))
				st.add_vertex(quad[idx])
	var out := {}
	for tile in tools:
		out[tile] = (tools[tile] as SurfaceTool).commit_to_arrays()
	return out


func test_the_workers_ground_arrays_are_the_ones_a_surface_tool_lays() -> void:
	var g: FieldGrid = Maps.build(PLACE)["grid"]
	var details := MapView.ground_details(g)
	var ahead := MapView.ground_arrays(g, details)
	var laid := _surface_tool_ground(g, details)
	assert_eq(ahead.keys(), laid.keys(), "the same tiles in the same order")
	assert_eq(ahead.size(), ceili(g.width / float(MapView.TILE)) * ceili(g.height / float(MapView.TILE)))
	var corners := 0
	for tile in ahead:
		assert_eq(ahead[tile], laid[tile], "tile %s as the SurfaceTool laid it" % tile)
		corners += (ahead[tile][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert_eq(corners, g.width * g.height * 6, "six corners a cell, none left out")
	assert_eq(ahead[Vector2i.ZERO][Mesh.ARRAY_TEX_UV2].size(), ahead[Vector2i.ZERO][Mesh.ARRAY_VERTEX].size(), "the floor kind rides in UV2")
	for slot: int in Mesh.ARRAY_MAX:
		var filled: bool = slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
		assert_eq(ahead[Vector2i.ZERO][slot] != null, filled, "slot %d" % slot)


func test_the_bank_rows_are_drift_uv_at_every_corner() -> void:
	var g: FieldGrid = Maps.build(PLACE)["grid"]
	var banks := PackedVector2Array()
	for y in range(g.height + 1):
		MapView.ground_bank_row(g, y, banks)
	assert_eq(banks.size(), (g.width + 1) * (g.height + 1))
	var wrong := 0
	var banked := 0
	for y in range(g.height + 1):
		for x in range(g.width + 1):
			var want := MapView.drift_uv(g, Vector2i(x, y))
			if banks[y * (g.width + 1) + x] != want:
				wrong += 1
			if want != Vector2.ZERO:
				banked += 1
	assert_eq(wrong, 0, "every corner as drift_uv answers it")
	assert_gt(banked, 0, "the map has corners where snow banks up")


func test_a_view_lays_the_loaders_arrays_and_works_out_a_changed_map_again() -> void:
	var d := _ready_map(-1)
	var floors: Array = (d["_floor_arrays"] as Dictionary).keys()
	var v = MapView.new()
	add_child_autofree(v)
	await v.setup(d)
	assert_true(v.ground_from_loader)
	for lv in floors:
		assert_true(bool(v.floor_from_loader.get(lv, false)), "level %d's floors" % lv)
	for key: String in ["_ground_arrays", "_ground_key", "_floor_arrays", "_floor_keys"]:
		assert_false(d.has(key), "%s is read once, not kept with the map" % key)
	var laid: int = v.level_roots[0].get_child_count()
	# Furniture painted in a room after the loader (room_stories.gd _paint): the ground
	# does not read it, so the arrays still fit.
	var furnished := _ready_map(-1)
	var fg: FieldGrid = furnished["grid"]
	for i in fg.solid.size():
		if fg.building[i] >= 0 and fg.solid[i] == FieldGrid.Solid.NONE:
			fg.solid[i] = FieldGrid.Solid.BLOCK
			break
	var in_room = MapView.new()
	add_child_autofree(in_room)
	await in_room.setup(furnished)
	assert_true(in_room.ground_from_loader, "a room's furniture leaves the ground's arrays fitting")
	# One cell changed after the arrays were made: the ground is worked out again here.
	var changed := _ready_map(-1)
	var g: FieldGrid = changed["grid"]
	var c := Vector2i(2, 2)
	g.floor[g.index(c)] = FieldGrid.Floor.GRAVEL if g.floor_at(c) != FieldGrid.Floor.GRAVEL else FieldGrid.Floor.SNOW
	var again = MapView.new()
	add_child_autofree(again)
	await again.setup(changed)
	assert_false(again.ground_from_loader)
	assert_eq(again.level_roots[0].get_child_count(), laid, "the same pieces either way")


func test_the_loader_puts_the_side_path_on_first_and_the_field_keeps_its_arrays() -> void:
	var s := -1
	var d := {}
	for k in range(1, 200):
		if not SidePath.rolls(PLACE, k):
			continue
		d = _ready_map(k)
		if d.has("side_path"):
			s = k
			break
	assert_gt(s, 0)
	assert_eq(int(d["_side_seed"]), s)
	assert_eq(d["_ground_key"], MapView.ground_key(d["grid"]), "the arrays fit the map the side path grew")
	var kept := FieldGame.with_side_path(d, s)
	assert_true(kept.has("_ground_arrays"), "the field neither puts it on again nor drops the arrays")
	var own := FieldGame.with_side_path(Maps.build(PLACE), s)
	assert_eq(kept["side_path"], own["side_path"], "the same way as the field would put on")
	assert_eq(kept["grid"].width, own["grid"].width)


func test_a_map_made_for_another_seed_is_made_again() -> void:
	var loader = StopLoader.new()
	add_child_autofree(loader)
	loader.prepare(PLACE, 3)
	if not loader.has_data():
		await wait_for_signal(loader.data_ready, 30)
	assert_eq(int(loader.data.get("_side_seed", -1)), 3, "made on the worker for that seed")
	loader.prepare(PLACE, 3)
	assert_true(loader.has_data(), "the same place and seed keeps what is under way")
	loader.prepare(PLACE, 4)
	assert_false(loader.has_data(), "another seed: made again")
	await wait_for_signal(loader.data_ready, 30)
	assert_eq(loader.seed_for, 4)
	assert_eq(int(loader.data.get("_side_seed", -1)), 4)
