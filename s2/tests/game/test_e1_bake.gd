extends "res://addons/gut/test.gd"
## 시야 변경, 소품 덩어리 선별, 상자의 덩어리 굽기, 지붕 시야의 부분 갱신을 본다.

const MapView = preload("res://game/world/map_view.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Props = preload("res://game/world/prop_models.gd")
const TEST_PROP: String = "res://tests/game/e1_synthetic_prop.glb"
var _was_props: Variant
var _was_buildings: Variant


class SeenSpy:
	extends Node3D
	var calls: int = 0
	var changed: PackedInt32Array = PackedInt32Array()

	func update_seen(_bytes: PackedByteArray, cells: PackedInt32Array = PackedInt32Array()) -> void:
		calls += 1
		changed = cells


func before_each() -> void:
	_was_props = ProjectSettings.get_setting(Props.MODE_SETTING, null)
	_was_buildings = ProjectSettings.get_setting(BuildingView.MODE_SETTING, null)
	ProjectSettings.set_setting(Props.MODE_SETTING, false)
	ProjectSettings.set_setting(BuildingView.MODE_SETTING, true)
	Props._batches[TEST_PROP] = {0: BoxMesh.new(), 1: BoxMesh.new()}


func after_each() -> void:
	ProjectSettings.set_setting(Props.MODE_SETTING, _was_props)
	ProjectSettings.set_setting(BuildingView.MODE_SETTING, _was_buildings)
	Props._batches.erase(TEST_PROP)


## 땅·열차를 만들지 않고 시험에 필요한 지도 그리기 상태만 둔다.
func _view() -> MapView:
	var view: MapView = MapView.new()
	add_child_autofree(view)
	view.set_process(false)
	view.grid = FieldGrid.new(180, 120)
	view.data = {"grid": view.grid, "containers": {}}
	for lv: int in [-1, 0, 1, 2]:
		view.levels[lv] = view.grid
		var root: Node3D = Node3D.new()
		view.add_child(root)
		view.level_roots[lv] = root
	view.vis_image = Image.create(view.grid.width, view.grid.height, false, Image.FORMAT_RGBA8)
	view.vis_texture = ImageTexture.create_from_image(view.vis_image)
	view.material = ShaderMaterial.new()
	view.material.shader = preload("res://game/world/world_vis.gdshader")
	view.material.set_shader_parameter("vis", view.vis_texture)
	view.material.set_shader_parameter("map_size", Vector2(view.grid.width, view.grid.height))
	return view


func _box(view: MapView, id: String, cell: Vector2i, lv: int = 0) -> void:
	view.data["containers"][id] = {"id": id, "name": "상자", "cell": cell, "level": lv,
		"items": ["scrap"], "searched": false, "locked": false}
	view.add_container(id)


func test_container_update_rebakes_only_its_chunk_and_floor() -> void:
	var view: MapView = _view()
	_box(view, "one", Vector2i(2, 2))
	_box(view, "same", Vector2i(8, 2))
	_box(view, "far", Vector2i(62, 2))
	_box(view, "upper", Vector2i(2, 2), 1)
	var before: Mesh = view.container_mesh("one")
	var far_mesh: Mesh = view.container_mesh("far")
	var upper_mesh: Mesh = view.container_mesh("upper")
	assert_eq(before, view.container_mesh("same"), "같은 층·덩어리는 메시 하나")
	view.data["containers"]["one"]["items"] = []
	view.data["containers"]["one"]["searched"] = true
	view.update_container("one")
	assert_ne(view.container_mesh("one"), before)
	assert_eq(view.container_mesh("one"), view.container_mesh("same"))
	assert_eq(view.container_mesh("far"), far_mesh, "다른 덩어리 보존")
	assert_eq(view.container_mesh("upper"), upper_mesh, "같은 칸의 다른 층 보존")
	_box(view, "heap", Vector2i(9, 2))
	assert_true(view.has_container("heap"), "플레이 중 추가")
	assert_eq(view.container_mesh("heap"), view.container_mesh("one"))
	assert_eq(view.container_mesh("far"), far_mesh)


func test_container_nodes_are_bounded_by_chunks_and_model_parents() -> void:
	var view: MapView = _view()
	for i in range(64):
		_box(view, "box_%d" % i, Vector2i(2 + i % 8, 2 + floori(i / 8.0)), i % 2)
	var count: int = 0
	for root: Node3D in view.level_roots.values():
		count += root.get_child_count()
	assert_true(view.container_nodes.is_empty(), "모델 없는 상자는 부모도 없다")
	assert_eq(count, view.container_chunks.size() + view.container_nodes.size())
	assert_lt(count, 16, "상자 64개보다 훨씬 적다")
	for id: String in view.data["containers"]:
		assert_true(view.has_container(id), id)
		assert_not_null(view.container_mesh(id), id)
	for chunk: Dictionary in view.container_chunks.values():
		assert_eq((chunk["node"] as MeshInstance3D).material_override, view.material)


func test_container_move_and_remove_rebake_source_and_destination_only() -> void:
	var view: MapView = _view()
	_box(view, "moving", Vector2i(2, 2))
	_box(view, "source", Vector2i(8, 2))
	_box(view, "target", Vector2i(92, 2), 1)
	_box(view, "far", Vector2i(62, 62))
	var source: Mesh = view.container_mesh("source")
	var target: Mesh = view.container_mesh("target")
	var far_mesh: Mesh = view.container_mesh("far")
	view.data["containers"]["moving"]["cell"] = Vector2i(94, 2)
	view.data["containers"]["moving"]["level"] = 1
	view.move_object_container("moving")
	assert_ne(view.container_mesh("source"), source)
	assert_ne(view.container_mesh("target"), target)
	assert_eq(view.container_mesh("moving"), view.container_mesh("target"))
	assert_eq(view.container_mesh("far"), far_mesh)
	target = view.container_mesh("target")
	view.data["containers"].erase("moving")
	view.remove_object_container("moving")
	assert_false(view.has_container("moving"))
	assert_null(view.container_mesh("moving"))
	assert_ne(view.container_mesh("target"), target)
	var chunk_count: int = view.container_chunks.size()
	view.data["containers"].erase("target")
	view.remove_object_container("target")
	assert_eq(view.container_chunks.size(), chunk_count - 1, "빈 덩어리 노드는 없앤다")
	assert_eq(view.container_mesh("far"), far_mesh)


func test_identical_visibility_skips_texture_and_roof_updates() -> void:
	var view: MapView = _view()
	var spy: SeenSpy = SeenSpy.new()
	view.add_child(spy)
	view.buildings = spy
	var n: int = view.grid.width * view.grid.height
	var memory: PackedByteArray = PackedByteArray()
	memory.resize(n * 4)
	var shown: Dictionary = {n + 7: true, n * 2 + 7: true}
	view.update_tracks({12: 210})
	view.update_vis(shown, memory, {8: 90})
	assert_eq(view.vis_upload_count, 1)
	assert_eq(spy.changed.size(), n, "첫 호출은 전 칸 변경")
	assert_eq(view.vis_lit.size(), 1, "여러 층의 같은 칸은 중복하지 않는다")
	view.update_vis(shown, memory, {8: 90})
	view.update_tracks({12: 210})
	view.update_vis({n * 2 + 7: true}, memory, {8: 90})
	assert_eq(view.vis_upload_count, 1, "최종 RGBA가 같으면 업로드 없음")
	assert_eq(spy.calls, 1, "지붕도 다시 계산하지 않는다")
	assert_true(view.track_wait.is_empty())
	view.update_tracks({12: 180})
	view.update_vis(shown, memory, {8: 90})
	assert_eq(view.vis_upload_count, 2)
	assert_eq(spy.changed, PackedInt32Array([12]), "눈 자국만 변경")
	view.update_vis(shown, memory)
	assert_eq(view.vis_upload_count, 3)
	assert_eq(spy.changed, PackedInt32Array([8]), "꺼진 불빛만 변경")
	view.update_vis({}, memory)
	assert_eq(view.vis_upload_count, 4)
	assert_eq(spy.changed, PackedInt32Array([7]), "시야에서 나간 칸만 변경")
	assert_eq(view.vis_bytes[7 * 4 + 1], 255, "본 칸의 G 값은 유지")
	view.update_vis({}, memory)
	assert_eq(view.vis_upload_count, 4)


func _prop(view: MapView, rect: Rect2i, lv: int) -> Dictionary:
	var prop: Dictionary = {"kind": "shelf", "rect": rect, "level": lv, "building": -1}
	view._add_object_batch(prop, TEST_PROP)
	return prop


func _instances(view: MapView) -> Dictionary:
	var out: Dictionary = {}
	var batch: Dictionary = view.prop_batches[TEST_PROP] as Dictionary
	for lod: int in batch["nodes"]:
		var mm: MultiMesh = (batch["nodes"][lod] as MultiMeshInstance3D).multimesh
		var transforms: Dictionary = {}
		for i in range(mm.visible_instance_count):
			var xf: Transform3D = mm.get_instance_transform(i)
			transforms[xf] = int(transforms.get(xf, 0)) + 1
		out[lod] = {"count": mm.visible_instance_count, "transforms": transforms}
	return out


func test_prop_tiles_match_full_scan_instances_and_lods() -> void:
	var view: MapView = _view()
	var n: int = view.grid.width * view.grid.height
	view._prop_memory.resize(n * 4)
	for lv: int in [-1, 0, 1, 2]:
		for y: int in [2, 30, 58, 86]:
			for x: int in [2, 30, 58, 86, 114, 142]:
				_prop(view, Rect2i(x, y, 2, 2), lv)
				var key: int = (lv + 1) * n + view.grid.index(Vector2i(x, y))
				if posmod(x + y + lv, 3) == 0:
					view._prop_memory[key] = 1
				elif posmod(x + y + lv, 3) == 1:
					view._prop_seen_now[key] = true
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var visible_count: int = 0
	for lv: int in [-1, 0, 2]:
		view.show_levels(lv)
		for focus: Vector3 in [Vector3(29.9, 0, 29.9), Vector3(60.1, 0, 60.1), Vector3(125, 0, 75)]:
			camera.position = focus + Vector3(45, sqrt(2.0) * 45 * tan(deg_to_rad(35.0)), 45)
			camera.look_at(focus)
			for mask_on: bool in [true, false]:
				view._props_mask_on = mask_on
				camera.size = 14.0 if mask_on else 36.0
				view._prop_tile_culling = true
				view.refresh_props(camera)
				var tiled: Dictionary = _instances(view)
				view._prop_tile_culling = false
				view.refresh_props(camera)
				assert_eq(tiled, _instances(view), "층 %d 가림 %s 초점 %s" % [lv, mask_on, focus])
				visible_count += int(tiled[0]["count"]) + int(tiled[1]["count"])
	assert_gt(visible_count, 0, "모두 숨긴 결과끼리 비교하지 않는다")
	view._prop_tile_culling = true
	camera.position = Vector3(40, 40, 40)
	camera.look_at(Vector3.ZERO)
	var batch: Dictionary = view.prop_batches[TEST_PROP] as Dictionary
	assert_lt(view._nearby_prop_items(batch, camera.global_position, -camera.global_transform.basis.z).size(), (batch["items"] as Array).size())


func test_prop_memory_and_tile_membership_follow_moves_and_removal() -> void:
	var view: MapView = _view()
	var prop: Dictionary = _prop(view, Rect2i(2, 2, 2, 2), 0)
	var batch: Dictionary = view.prop_batches[TEST_PROP] as Dictionary
	var item: Dictionary = batch["items"][0] as Dictionary
	var old_tile: Vector3i = item["tile"] as Vector3i
	var n: int = view.grid.width * view.grid.height
	var key: int = n + view.grid.index(Vector2i(2, 2))
	view._prop_memory.resize(n * 4)
	view._prop_seen_now[key] = true
	assert_true(view._prop_is_seen(prop["rect"], 0, item))
	assert_false(bool(item["remembered"]), "임시로 밝힌 방은 영구 기억이 아니다")
	view._prop_seen_now.clear()
	assert_false(view._prop_is_seen(prop["rect"], 0, item))
	view._props_mask_on = false
	assert_true(view._prop_is_seen(prop["rect"], 0, item))
	assert_false(bool(item["remembered"]), "가림을 끈 것만으로 기억하지 않는다")
	view._props_mask_on = true
	view._prop_memory[key] = 1
	assert_true(view._prop_is_seen(prop["rect"], 0, item))
	assert_true(bool(item["remembered"]))
	prop["rect"] = Rect2i(92, 62, 2, 2)
	prop["level"] = 1
	view.update_prop(prop)
	assert_false((batch["tiles"] as Dictionary).has(old_tile))
	assert_eq(item["tile"], Vector3i(3, 2, 1))
	assert_eq(item["level"], 1)
	assert_false(bool(item["remembered"]), "새 자리에서는 다시 기억을 확인")
	view.update_prop(prop, true)
	assert_true((batch["tiles"] as Dictionary).is_empty())
	assert_true((batch["items"] as Array).is_empty())
	for node: MultiMeshInstance3D in batch["nodes"].values():
		assert_eq(node.multimesh.instance_count, 0)
		assert_eq(node.multimesh.visible_instance_count, 0)


func _building_map(two_storey: bool = false) -> Dictionary:
	var grid: FieldGrid = FieldGrid.new(60, 16)
	var rows: Array = []
	for b in range(2):
		var rect: Rect2i = Rect2i(2 + b * 30, 2, 10, 8)
		rows.append({"id": b, "rect": rect})
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell: Vector2i = Vector2i(x, y)
				grid.building[grid.index(cell)] = b
				if x == rect.position.x or x == rect.end.x - 1 or y == rect.position.y or y == rect.end.y - 1:
					grid.set_solid(cell, FieldGrid.Solid.WALL)
		for x: int in [5 + b * 30, 7 + b * 30]:
			var cell: Vector2i = Vector2i(x, 9)
			grid.set_solid(cell, FieldGrid.Solid.DOOR)
			grid.doors[cell] = {"state": "closed", "hp": 3, "building": b, "key": ""}
		for cell: Vector2i in [Vector2i(9 + b * 30, 9), Vector2i(4 + b * 30, 2)]:
			grid.set_solid(cell, FieldGrid.Solid.WINDOW)
			grid.windows[cell] = {"broken": false, "glass": false, "building": b}
	var map_data: Dictionary = {"grid": grid, "levels": {0: grid}, "buildings": rows, "stoves": [], "stairs": []}
	if two_storey:
		var upper: FieldGrid = FieldGrid.new(grid.width, grid.height)
		upper.building = grid.building.duplicate()
		upper.solid = grid.solid.duplicate()
		upper.doors = grid.doors.duplicate(true)
		upper.windows = grid.windows.duplicate(true)
		map_data["levels"][1] = upper
		map_data["upper_rects"] = []
		for row: Dictionary in rows:
			map_data["upper_rects"].append({"building": int(row["id"]), "rect": row["rect"]})
	return map_data


func _kit(map_data: Dictionary) -> BuildingView:
	assert_true(BuildingView.can_draw(), "대응표와 조각을 읽는다")
	var kit: BuildingView = BuildingView.new()
	add_child_autofree(kit)
	kit.setup(map_data, ShaderMaterial.new())
	kit.set_process(false)
	return kit


func test_roof_seen_uses_changed_cells_and_keeps_full_scan_entry() -> void:
	var map_data: Dictionary = _building_map()
	var grid: FieldGrid = map_data["grid"] as FieldGrid
	var kit: BuildingView = _kit(map_data)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(grid.width * grid.height * 4)
	kit.update_seen(bytes)
	assert_eq(kit.seen_buildings_checked, kit.roofs.size())
	var cell_index: int = grid.index(Vector2i(5, 9))
	bytes[cell_index * 4] = 255
	bytes[cell_index * 4 + 1] = 255
	kit.update_seen(bytes, PackedInt32Array([cell_index]))
	assert_eq(kit.seen_buildings_checked, 1)
	assert_eq(kit._seen[0], Vector2.ONE)
	assert_eq(kit._seen[1], Vector2.ZERO)
	var partial: Dictionary = kit._seen.duplicate()
	kit.update_seen(bytes, PackedInt32Array())
	assert_eq(kit.seen_buildings_checked, kit.roofs.size(), "빈 changed는 기존 전체 경로")
	assert_eq(kit._seen, partial)
	kit.update_seen(bytes, PackedInt32Array([grid.index(Vector2i(20, 14))]))
	assert_eq(kit.seen_buildings_checked, 0, "건물에 닿지 않는 칸은 지붕을 보지 않는다")


func test_outer_cell_reverse_index_keeps_all_buildings_touching_it() -> void:
	var map_data: Dictionary = _building_map()
	var grid: FieldGrid = map_data["grid"] as FieldGrid
	var plan: Dictionary = BuildingView.plan(map_data)
	var cell_index: int = grid.index(Vector2i(5, 9))
	plan["outer"][1][cell_index] = true
	map_data["_building_plan"] = plan
	var kit: BuildingView = _kit(map_data)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(grid.width * grid.height * 4)
	bytes[cell_index * 4] = 255
	kit.update_seen(bytes, PackedInt32Array([cell_index]))
	assert_eq(kit.seen_buildings_checked, 2)
	assert_eq(kit._seen[0], Vector2(1, 0))
	assert_eq(kit._seen[1], Vector2(1, 0))
