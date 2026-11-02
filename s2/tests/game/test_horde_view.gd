extends "res://addons/gut/test.gd"
## PNG 없이 배치/칸 표/연결 계약을 확인한다. 굽기·그림 확인은 별도 문지기 실행.

const Horde = preload("res://game/world/horde_view.gd")
const Field = preload("res://game/field_game.gd")
const Switch = preload("res://game/perf_switch.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const Bake = preload("res://tools/horde_bake.gd")
const Grid = preload("res://game/world/field_grid.gd")
const Pace = preload("res://game/world/build_pace.gd")
const Loader = preload("res://game/stop_loader.gd")
const Shots = preload("res://tools/horde_shots.gd")


class LateField:
	extends Node3D
	signal built
	var player: Node3D
	var paused: bool = false
	var ended: bool = false
	var is_built: bool = false
	var pace: Pace

	# 진짜 필드처럼 처리 함수가 있어 is_processing()이 켜진다.
	func _process(_delta: float) -> void:
		pass


class FixtureHorde:
	extends Horde
	var fixture: Dictionary = {}
	var table_failure: String = ""
	var read_frames: Array[int] = []
	var after_table: Callable

	func _read_table_result() -> Dictionary:
		read_frames.append(Engine.get_process_frames())
		if after_table.is_valid():
			after_table.call()
		return {"table": fixture, "error": table_failure}

	func _request_asset(path: String) -> void:
		if path == ATLAS_PATH:
			stats["resource_loads"] = int(stats["resource_loads"]) + 1
			return
		super._request_asset(path)

	func _load_atlas() -> Texture2D:
		read_frames.append(Engine.get_process_frames())
		var texture := PlaceholderTexture2D.new()
		texture.size = Vector2(ATLAS_SIZE)
		return texture

	func _load_shader() -> Shader:
		read_frames.append(Engine.get_process_frames())
		return await super._load_shader()


func _walls(height: float = 3.0) -> Array:
	return [
		{"id": "north", "a": Vector2(4, 0), "b": Vector2(76, 0), "out": Vector2(0, -1), "kind": "wall_sheet", "height": height},
		{"id": "west", "a": Vector2(0, 4), "b": Vector2(0, 52), "out": Vector2(-1, 0), "kind": "wall_stack", "height": height},
	]


func _layout(walls: Array) -> Array[Dictionary]:
	var node: Horde = Horde.new()
	add_child_autofree(node)
	return await node.build_layout(walls, {"map_size": Vector2(120, 80)})


## 셰이더처럼 단정도로 한 번 반올림한 값.
func _f32(value: float) -> float:
	var one := PackedFloat32Array([value])
	return one[0]


func test_center_depth_follows_exposed_area_at_a_tall_wall_end() -> void:
	# 점검이 든 반례: 길이 24 m·높이 5.2 m 북쪽 벽, 표 없음, 칸 2~22 m, 깊이 40 m.
	var wall: Dictionary = {"id": "end", "a": Vector2(4, 0), "b": Vector2(28, 0), "out": Vector2(0, -1), "kind": "wall_stack", "height": 5.2}
	var geometry: Dictionary = Horde.wall_geometry(wall)
	var full: float = geometry["full"]
	assert_gt(full, 2.0, "가려지는 띠가 있는 높은 벽")
	var bins: PackedFloat64Array = Horde.placement_bins(geometry, 2.0, 22.0, 40.0)
	var hidden_band: float = 0.0
	var total: float = 0.0
	for index: int in range(2, bins.size(), 3):
		total += bins[index]
		if bins[index - 1] <= full + 0.0001:
			hidden_band += bins[index]
	assert_almost_eq(total, Horde.placement_area(geometry, 2.0, 22.0, 40.0), 0.0001, "후보 수와 표본이 같은 적분")
	var draws: int = 4000
	var shallow_centers: int = 0
	for draw: int in range(draws):
		if Horde.sample_placed_depth(bins, (float(draw) + 0.5) / float(draws)) < full:
			shallow_centers += 1
	assert_almost_eq(float(shallow_centers) / float(draws), hidden_band / total, 0.005, "가려지는 띠의 중심 비율 = 그 띠의 노출 면적 비율")
	var density_only: float = (Horde.density_area(full) - Horde.density_area(0.4)) / (Horde.density_area(40.0) - Horde.density_area(0.4))
	assert_gt(density_only, 2.0 * hidden_band / total, "밀도만으로 뽑으면 좁은 끝 띠에 몰린다(고치기 전)")


func test_same_input_same_placement() -> void:
	var first: Array[Dictionary] = await _layout(_walls())
	var second: Array[Dictionary] = await _layout(_walls())
	assert_false(first.is_empty())
	assert_eq(first, second)


func test_wall_array_order_does_not_change_wall_id_layout() -> void:
	var walls: Array = _walls()
	var first: Array[Dictionary] = await _layout(walls)
	walls.reverse()
	assert_eq(first, await _layout(walls))


func test_map_chunk_and_visible_instance_caps() -> void:
	var node: Horde = Horde.new()
	add_child_autofree(node)
	var walls: Array = [{"id": "long", "a": Vector2(0, 0), "b": Vector2(2000, 0), "out": Vector2(0, -1), "kind": "wall_plank", "height": 1.0}]
	var layout: Array[Dictionary] = await node.build_layout(walls, {"map_size": Vector2(2000, 80)})
	var count: int = 0
	for chunk: Dictionary in layout:
		var people: Array = chunk["people"]
		assert_lte(people.size(), Horde.CHUNK_CAP)
		count += people.size()
	assert_gt(count, Horde.CHUNK_CAP)
	assert_lte(count, Horde.MAP_CAP)
	assert_lte(Horde.VISIBLE_CAP * Horde.CHUNK_CAP, 1300)
	assert_eq(int(node.stats["instances"]), count)
	assert_gt(int(node.stats["pieces"]), 0)
	assert_lte(int(node.stats["attempts"]), layout.size() * Horde.CHUNK_CAP * Horde.MAX_TRIES)


func test_fully_hidden_heads_are_removed_but_segment_ends_are_finite() -> void:
	var walls: Array = _walls(5.2)
	var layout: Array[Dictionary] = await _layout(walls)
	for chunk: Dictionary in layout:
		var wall: Dictionary = chunk["wall"]
		for person: Dictionary in chunk["people"]:
			var at: Vector3 = person["position"]
			assert_false(Horde.fully_hidden(wall, Vector2(at.x, at.z)))
	var north: Dictionary = walls[0]
	assert_true(Horde.fully_hidden(north, Vector2(20, -1)))
	assert_false(Horde.fully_hidden(north, Vector2(90, -1)), "벽 끝 밖의 연장선은 벽이 아니다")
	var expected: float = (5.2 - Horde.HEAD_MAX_M * Horde.MAX_SCALE) / tan(deg_to_rad(35.0)) / sqrt(2.0) - Horde.ORBIT_M
	assert_almost_eq(Horde.full_depth(north), expected, 0.0001)


func test_contact_row_uses_thump_and_claw() -> void:
	# 낮은 시험 벽은 접촉 줄의 머리를 가리지 않는다.
	var layout: Array[Dictionary] = await _layout(_walls(1.0))
	var contact: int = 0
	var reacting: int = 0
	var walk: int = 0
	var stagger: int = 0
	for chunk: Dictionary in layout:
		for person: Dictionary in chunk["people"]:
			var motion: int = person["motion"]
			if float(person["depth"]) <= 1.2:
				contact += 1
				if motion in [2, 3]:
					reacting += 1
			elif motion == 0:
				walk += 1
			elif motion == 1:
				stagger += 1
	assert_gt(contact, 0)
	assert_eq(reacting, contact)
	assert_gt(walk, 0)
	assert_gt(stagger, walk)


func test_minimum_spacing_end_gaps_and_sparse_tail() -> void:
	var layout: Array[Dictionary] = await _layout(_walls(1.0))
	var points: Array[Vector2] = []
	var tail: int = 0
	var near_count: int = 0
	var least_gap: float = INF
	for chunk: Dictionary in layout:
		var wall: Dictionary = chunk["wall"]
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		for person: Dictionary in chunk["people"]:
			var at: Vector3 = person["position"]
			var point := Vector2(at.x, at.z)
			var along: float = (point - a).dot((b - a).normalized())
			assert_gte(along, 2.0 - 0.0001)
			assert_lte(along, a.distance_to(b) - 2.0 + 0.0001)
			for previous: Vector2 in points:
				least_gap = minf(least_gap, point.distance_to(previous))
			points.append(point)
			if float(person["depth"]) > 22.0:
				tail += 1
			else:
				near_count += 1
	assert_gt(tail, 0)
	assert_gt(near_count, tail)
	assert_gte(least_gap, Horde.MIN_GAP - 0.0001)


func test_invalid_walls_are_dropped() -> void:
	var original: Dictionary = _walls()[0]
	var bad: Array = [17, {}, original.merged({"id": "zero", "b": original["a"]}, true),
		original.merged({"id": "negative", "height": -1.0}, true),
		original.merged({"id": "nan", "height": NAN}, true),
		original.merged({"id": "infinite", "height": INF}, true),
		original.merged({"id": "not_unit", "out": Vector2(0, -2)}, true),
		original.merged({"id": "parallel", "out": Vector2(1, 0)}, true),
		original.merged({"id": "inward", "out": Vector2(0, 1)}, true),
		original.merged({"id": "fraction", "a": Vector2(4.5, 0)}, true)]
	var node: Horde = Horde.new()
	add_child_autofree(node)
	assert_eq((await node.build_layout(bad, {"map_size": Vector2(120, 80)})).size(), 0)
	assert_eq(int(node.stats["invalid_walls"]), bad.size())


func test_depth_zero_places_no_one_and_warns_nothing() -> void:
	# The map marks a piece with no horde behind it as depth 0: valid, quiet, empty.
	var walls: Array = _walls()
	walls[0] = (walls[0] as Dictionary).merged({"depth": 0.0}, true)
	var node: Horde = Horde.new()
	add_child_autofree(node)
	var chunks: Array[Dictionary] = await node.build_layout(walls, {"map_size": Vector2(120, 80)})
	assert_eq(int(node.stats["invalid_walls"]), 0)
	assert_false(chunks.is_empty(), "the other wall still has its horde")
	for chunk: Dictionary in chunks:
		assert_ne(String((chunk["wall"] as Dictionary)["id"]), "north", "no one behind a depth 0 piece")


func test_duplicate_ids_are_rejected_without_order_tiebreak() -> void:
	var wall: Dictionary = _walls()[0]
	assert_true((await _layout([wall, wall.duplicate()])).is_empty())


func test_inset_boundary_uses_grid_to_validate_outward_side() -> void:
	var grid: Grid = Grid.new(120, 80)
	for y: int in range(10):
		for x: int in range(120):
			grid.solid[grid.index(Vector2i(x, y))] = Grid.Solid.WALL
	var wall: Dictionary = {"id": "inset", "a": Vector2(4, 10), "b": Vector2(28, 10),
		"out": Vector2(0, -1), "kind": "wall_sheet", "height": 3.0}
	assert_eq(Horde.wall_error(wall, Vector2(120, 80), grid), "")
	assert_ne(Horde.wall_error(wall.merged({"out": Vector2(0, 1)}, true), Vector2(120, 80), grid), "")
	var node: Horde = Horde.new()
	add_child_autofree(node)
	assert_false((await node.build_layout([wall], {"map_size": Vector2(120, 80), "grid": grid})).is_empty())


func test_camera_contract_matches_field_and_foot_is_shared() -> void:
	assert_eq(Horde.CAM_PITCH, Field.CAM_PITCH)
	assert_eq(Horde.CAM_YAW, Field.CAM_YAW)
	assert_eq(Horde.camera_back(), Field.cam_back())
	assert_eq(Horde.PX_PER_M, 720.0 / 24.0)
	assert_eq(float(Horde.REFERENCE_HEIGHT) / Horde.CAM_SIZE, Horde.PX_PER_M)
	assert_eq(Horde.table_contract()["foot_px"], [21.0, 64.0])
	# 회색 기준 칸은 576칸(48열 x 42 px = 2016) 뒤 오른쪽 띠, 발 x는 (방향, 동작)마다 칸 표에.
	assert_eq(Horde.table_contract()["gray_rect"], [2016, 0, 32, 80])
	assert_eq(Horde.table_contract()["foot_px_x_order"], "direction * 4 + motion")
	assert_lte(Horde.COLUMNS * Horde.CELL.x, Horde.GRAY_RECT.position.x)
	assert_lte(Horde.GRAY_RECT.end.x, Horde.ATLAS_SIZE.x)
	assert_eq(Horde.COLUMNS * 12, Horde.CELL_COUNT)
	assert_eq(Horde.table_contract()["padding_px"], 2)


func _baked_table() -> Dictionary:
	# The same keys horde_bake.gd writes, with integer lists like the bake's.
	var table: Dictionary = Horde.table_contract()
	var bounds: Array = []
	var feet: Array = []
	for i: int in 32:
		bounds.append([4, 18, 33, 50])
		feet.append(5 + i)
	table["bounds_px"] = bounds
	table["foot_px_x"] = feet
	table["clip_lengths"] = [1.0, 0.8, 0.6, 0.7, 1.0, 0.8, 0.6, 0.7, 1.0, 0.8, 0.6, 0.7]
	return table


func test_baked_table_reads_back_through_json() -> void:
	# JSON turns every number into a float; integer contract lists must still match.
	var table: Dictionary = Horde.parse_table(JSON.stringify(_baked_table(), "\t"))
	assert_false(table.is_empty())
	assert_eq(table.get("cell_px"), [42.0, 80.0])
	var wrong: Dictionary = _baked_table()
	wrong["cell_px"] = [40, 80]
	assert_true(Horde.parse_table(JSON.stringify(wrong)).is_empty())
	var outside: Dictionary = _baked_table()
	outside["foot_px_x"][3] = 41
	assert_true(Horde.parse_table(JSON.stringify(outside)).is_empty())


func test_direction_boundaries_plus_minus_pi_over_eight() -> void:
	var zero: float = Horde.camera_theta() + Horde.THETA_ZERO
	var epsilon: float = 0.00001
	assert_eq(Horde.direction_cell(zero + PI / 8.0 - epsilon), 0)
	assert_eq(Horde.direction_cell(zero + PI / 8.0 + epsilon), 1)
	assert_eq(Horde.direction_cell(zero - PI / 8.0 - epsilon), 7)
	assert_eq(Horde.direction_cell(zero - PI / 8.0 + epsilon), 0)
	assert_eq(Horde.direction_cell(zero + PI / 8.0), 1)
	assert_eq(Horde.direction_cell(zero - PI / 8.0), 0)
	for direction: int in range(8):
		assert_eq(Horde.direction_cell(zero + float(direction) * PI / 4.0 + TAU), direction)


func test_atlas_index_covers_576_cells_without_overlap() -> void:
	var occupied: Dictionary = {}
	for body: int in range(3):
		for direction: int in range(8):
			for motion: int in range(4):
				for frame: int in range(6):
					var index: int = Horde.atlas_index(body, direction, motion, frame)
					assert_false(occupied.has(index))
					occupied[index] = true
	assert_eq(occupied.size(), 576)
	for index: int in range(576):
		assert_true(occupied.has(index))
	assert_lte(Horde.COLUMNS * Horde.CELL.x, Horde.ATLAS_SIZE.x)
	assert_lte(12 * Horde.CELL.y, Horde.ATLAS_SIZE.y)


func test_clip_lookup_uses_names_when_clips_are_appended_or_reordered() -> void:
	for body: String in Horde.BODIES:
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/people/%s/clips.json" % body))
		var clips: Array = info["clips"]
		var before: Array[int] = Horde.clip_indices(clips)
		assert_eq(before.size(), 4)
		clips.append({"name": "future_reaction", "length": 0.7})
		assert_eq(Horde.clip_indices(clips), before)
		clips.reverse()
		var after: Array[int] = Horde.clip_indices(clips)
		for motion: int in range(4):
			assert_eq(String(clips[after[motion]]["name"]), Horde.MOTIONS[motion])
	assert_true(Horde.clip_indices([{"name": "walk_a", "length": 1.4}]).is_empty())


func test_vat_upper_clip_motion_packing() -> void:
	for index: int in [17, 18]:
		var packed: int = int(VatBaker.pack_motion(index))
		var upper: int = int(floor(float(packed) / 2097152.0))
		var low: int = packed - upper * 2097152
		assert_eq((low % 16) + upper * 16, index)
		assert_ne(packed, index)


func test_chunk_aabb_contains_max_cards_orbit_and_lean() -> void:
	for chunk: Dictionary in await _layout(_walls(1.0)):
		var box: AABB = chunk["aabb"]
		for person: Dictionary in chunk["people"]:
			var foot: Vector3 = person["position"]
			# 발 x는 칸 안 2..40이라 모서리는 발에서 가로 ±40 px 안.
			for dx: float in [-40.0, 40.0]:
				for py: float in [0.0, 80.0]:
					var corner: Vector3 = Horde.upright_corner(foot, Vector2(dx, 64.0 - py) * (1.08 / 30.0))
					for shift: Vector3 in [Vector3(0.3, 0, 0.3), Vector3(-0.3, 0, -0.3)]:
						assert_true(box.has_point(corner + shift))


func test_instances_are_sorted_by_camera_forward_projection() -> void:
	var forward: Vector3 = -Horde.camera_back()
	for chunk: Dictionary in await _layout(_walls()):
		var previous: float = -INF
		for person: Dictionary in chunk["people"]:
			var depth: float = (person["position"] as Vector3).dot(forward)
			assert_gte(depth, previous)
			previous = depth


func test_separate_seed_lanes_and_custom_ranges() -> void:
	var cell := Vector2i(3, -6)
	assert_ne(Horde.stream("north".hash(), cell, 25), Horde.stream("north".hash(), cell, 26))
	assert_ne(Horde.stream("north".hash(), cell, 25), Horde.stream("west".hash(), cell, 25))
	for chunk: Dictionary in await _layout(_walls()):
		for person: Dictionary in chunk["people"]:
			var custom: Color = person["custom"]
			assert_true(custom.r >= 0.0 and custom.r < 1.0)
			assert_true(custom.b >= 0.0 and custom.b < 1.0)
			assert_true(custom.a >= 0.0 and custom.a < 1.0)
			assert_eq(int(custom.g), int(person["motion"]))


func test_dilation_keeps_transparent_padding_and_nearest_rgb() -> void:
	var picture: Image = Image.create(40, 80, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0, 0, 0, 0))
	picture.set_pixel(20, 40, Color(0.7, 0.2, 0.1, 1.0))
	Bake._dilate(picture)
	assert_eq(picture.get_used_rect(), Rect2i(20, 40, 1, 1))
	assert_eq(picture.get_pixel(0, 0).a, 0.0)
	assert_almost_eq(picture.get_pixel(0, 0).r, 0.7, 0.005)


func test_perf_horde_false_creates_no_node_and_does_not_load_atlas() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var reads_before: int = Horde.resource_reads
	var node: Node3D = await Horde.attach(parent, _walls(), {}, null, Switch._valid({"horde": false}))
	assert_null(node)
	assert_null(parent.get_node_or_null("HordeView"))
	assert_eq(parent.get_child_count(), 0)
	assert_eq(Horde.resource_reads, reads_before)
	assert_eq(Switch._valid({"horde": true}), {"horde": true})
	assert_false(Switch._valid({"horde": "false"}).has("horde"))


func _ids(walls: Array) -> Array:
	return walls.map(func(wall: Dictionary) -> String: return String(wall["id"]))


func test_phone_switch_horde_test_walls_adds_the_shot_walls_only_when_on() -> void:
	# 폰 재기 길: perf_switch.json "horde_test_walls": true → 정차가 넘기는 벽에 촬영 도구와 같은 시험 벽.
	assert_eq(Switch._valid({"horde_test_walls": true}), {"horde_test_walls": true})
	assert_false(Switch._valid({"horde_test_walls": 1}).has("horde_test_walls"), "참/거짓만 받는다")
	# 정본 두 벽은 함수 밖 값으로 확인(촬영 도구도 같은 벽).
	var expected: Array = [
		{"id": "h1_north_sheet", "a": Vector2(4, 0), "b": Vector2(28, 0), "out": Vector2(0, -1), "kind": "wall_sheet", "height": 3.0},
		{"id": "h1_west_stack", "a": Vector2(0, 4), "b": Vector2(0, 28), "out": Vector2(-1, 0), "kind": "wall_stack", "height": 5.2},
	]
	assert_eq(Horde.test_walls(), expected)
	assert_eq(Shots.test_walls(), expected)
	var map_wall: Dictionary = {"id": "map_east", "a": Vector2(40, 4), "b": Vector2(40, 28), "out": Vector2(1, 0), "kind": "wall_plank", "height": 2.0}
	var data: Dictionary = {"edge_walls": [map_wall]}
	var opts: Dictionary = {"test_edge_walls": _walls(1.0)}
	assert_eq(Horde.stop_walls(data, opts, {}), [map_wall] + _walls(1.0), "기본은 지도 + opts 그대로")
	assert_eq(Horde.stop_walls(data, opts, Switch._valid({"horde_test_walls": false})), [map_wall] + _walls(1.0))
	assert_eq(Horde.stop_walls({}, {}, {"horde_test_walls": "yes"}), [], "검사 안 거친 잘못된 값도 켬이 아니다")
	var on: Array = Horde.stop_walls(data, opts, Switch._valid({"horde_test_walls": true}))
	assert_eq(_ids(on), ["map_east", "north", "west", "h1_north_sheet", "h1_west_stack"])
	for index: int in range(3, 5):
		assert_eq(on[index]["test_mode"], "corner")
		for key: String in ["a", "b", "out", "kind", "height"]:
			assert_eq(on[index][key], expected[index - 3][key])
	# 무리 꺼짐이면 시험 벽을 넣지 않는다(켬 줄도 없음 — "ok": false 줄만).
	assert_eq(Horde.stop_walls(data, {}, {"horde": false, "horde_test_walls": true}), [map_wall])
	# 같은 시험 벽이 opts로 이미 오면 하나만(같은 id 둘은 둘 다 거부되므로), 다른 벽이 id를 쓰면 이름을 바꿔 둘 다.
	var doubled: Array = Horde.stop_walls({}, {"test_edge_walls": Horde.test_walls()}, {"horde_test_walls": true})
	assert_eq(_ids(doubled), ["h1_north_sheet", "h1_west_stack"])
	assert_eq(doubled[0]["test_mode"], "corner")
	var clash: Dictionary = map_wall.duplicate()
	clash["id"] = "h1_north_sheet"
	var renamed: Array = Horde.stop_walls({"edge_walls": [clash]}, {}, {"horde_test_walls": true})
	assert_eq(_ids(renamed), ["h1_north_sheet", "h1_north_sheet_test", "h1_west_stack"])


func test_phone_switch_reports_ok_only_after_the_test_walls_are_really_built() -> void:
	# 켬 판정 줄은 짓기가 끝난 뒤: 받아들인 시험 벽·그 무리 수. 실제 자원·나눠 짓기 끔.
	var parent := Node3D.new()
	add_child_autofree(parent)
	var settings: Dictionary = {"horde_test_walls": true}
	var walls: Array = Horde.stop_walls({}, {}, settings)
	var node: Horde = await Horde.attach(parent, walls, {"map_size": Vector2(120, 80)}, Pace.new(), settings)
	assert_true(bool(node.stats["ready"]))
	assert_eq(int(node.stats["test_walls_used"]), 2)
	assert_true(bool(node.stats["test_walls_ok"]))
	assert_eq(int(node.stats["instances"]), 432)
	# 24 m 벽이 안 들어가는 작은 지도: 시험 벽이 거부돼 켬이 아니다.
	var small_parent := Node3D.new()
	add_child_autofree(small_parent)
	var small: Horde = await Horde.attach(small_parent, Horde.stop_walls({}, {}, settings), {"map_size": Vector2(20, 20)}, Pace.new(), settings)
	assert_eq(int(small.stats["test_walls_used"]), 0)
	assert_false(bool(small.stats["test_walls_ok"]))


func test_phone_switch_near_puts_the_two_test_walls_on_the_edge_nearest_the_arrival() -> void:
	assert_eq(Switch._valid({"horde_test_walls": "near"}), {"horde_test_walls": "near"})
	assert_false(Switch._valid({"horde_test_walls": "far"}).has("horde_test_walls"))
	var map_size := Vector2(120, 80)
	# 남쪽 가장자리(y = 80)에서 6 m, 동서로는 가운데쯤.
	var near: Dictionary = Horde.near_test_walls(Vector2(60.5, 74.5), map_size)
	assert_almost_eq(float(near["edge_m"]), 5.5, 0.0001)
	var walls: Array = near["walls"]
	assert_eq(walls.size(), 2)
	for wall: Dictionary in walls:
		assert_eq(Horde.wall_error(wall, map_size), "", String(wall["id"]))
		assert_eq(wall["out"], Vector2(0, 1), "바깥이 무리 쪽(지도 밖)")
		assert_eq((wall["a"] as Vector2).y, 80.0)
	assert_eq([float(walls[0]["height"]), float(walls[1]["height"])], [3.0, 5.2], "구석 시험 벽과 같은 두 높이")
	assert_true((walls[0]["a"] as Vector2).x <= 60.5 and (walls[1]["b"] as Vector2).x >= 60.5, "도착 자리 맞은편 가운데")
	# 서쪽 구석에 가까운 도착 자리는 서쪽 가장자리, 지도 안으로 잘림.
	var west: Dictionary = Horde.near_test_walls(Vector2(3.5, 10.5), map_size)
	for wall: Dictionary in west["walls"]:
		assert_eq(Horde.wall_error(wall, map_size), "", String(wall["id"]))
		assert_eq(wall["out"], Vector2(-1, 0))
		assert_gte((wall["a"] as Vector2).y, 0.0)
		assert_lte((wall["b"] as Vector2).y, 80.0)
	# 정차 자료의 첫 도착 칸을 쓰고, 넣은 벽에 "near"와 가장자리 거리를 단다.
	var data: Dictionary = {"spawns": {"squad": [Vector2i(60, 74), Vector2i(61, 74)]}}
	var placed: Array = Horde.stop_walls(data, {}, {"horde_test_walls": "near"}, map_size)
	assert_eq(_ids(placed), _ids(walls))
	for index: int in range(2):
		assert_eq(placed[index]["test_mode"], "near")
		assert_almost_eq(float(placed[index]["test_edge_m"]), 5.5, 0.0001)
		for key: String in ["a", "b", "out", "kind", "height"]:
			assert_eq(placed[index][key], walls[index][key])
	assert_eq(Horde.stop_walls({}, {}, {"horde_test_walls": "near"}, map_size), [], "도착 자리 없으면 더하지 않음")


func test_hiding_and_exit_clear_owned_focus() -> void:
	var node := FixtureHorde.new()
	add_child_autofree(node)
	await node.setup([], {}, null)
	node._history.fill(Vector4.ONE)
	node._focus = Vector4.ONE
	node.hide()
	assert_eq(node._focus, Vector4.ZERO)
	for sample: Vector4 in node._history:
		assert_eq(sample, Vector4.ZERO)
	node._focus = Vector4.ONE
	remove_child(node)
	assert_eq(node._focus, Vector4.ZERO)
	add_child(node)


func test_upright_head_depth_and_screen_size() -> void:
	var back: Vector3 = Horde.camera_back()
	var right: Vector3 = Vector3.UP.cross(back).normalized()
	var up: Vector3 = back.cross(right).normalized()
	var foot := Vector3(15.0, 0.0, -5.0)
	for px: float in [0.0, 40.0]:
		for py: float in [0.0, 64.0, 80.0]:
			var corner := Vector2(px - 20.0, 64.0 - py) * (Horde.MAX_SCALE / Horde.PX_PER_M)
			var old: Vector3 = foot + right * corner.x + up * corner.y
			var upright: Vector3 = Horde.upright_corner(foot, corner)
			assert_almost_eq(upright.dot(right), old.dot(right), 0.0001)
			assert_almost_eq(upright.dot(up), old.dot(up) + maxf(0.0, upright.y - foot.y) * up.y if py > 64.0 else old.dot(up), 0.0001)
			if py < 64.0:
				assert_lt(upright.dot(-back), foot.dot(-back))
			elif py > 64.0:
				# 발 아래 그림은 땅 밑이 아니라 땅 위, 카메라 쪽으로.
				assert_gt(upright.y, foot.y)
				assert_lte(upright.y - foot.y, Horde.SOLE_LIFT + 0.0001)
				assert_lt(upright.dot(-back), foot.dot(-back))
	var people: Array[Dictionary] = [{"position": foot}]
	var box: AABB = Horde.card_aabb(people)
	assert_almost_eq(box.end.y - foot.y, 64.0 / Horde.PX_PER_M / cos(deg_to_rad(Horde.CAM_PITCH)) * Horde.MAX_SCALE + 0.6, 0.0001)


func test_contact_row_tracks_first_visible_depth_on_both_sides() -> void:
	for height: float in [3.0, 5.2]:
		var walls: Array = _walls(height)
		walls.append({"id": "south", "a": Vector2(4, 80), "b": Vector2(116, 80), "out": Vector2(0, 1), "kind": "wall_sheet", "height": height})
		var counts: Dictionary = {"north": 0, "west": 0, "south": 0}
		for chunk: Dictionary in await _layout(walls):
			var wall: Dictionary = chunk["wall"]
			var first: float = maxf(0.4, Horde.full_depth(wall))
			for person: Dictionary in chunk["people"]:
				if int(person["motion"]) in [2, 3]:
					counts[wall["id"]] += 1
					assert_gte(float(person["depth"]), first)
					assert_lte(float(person["depth"]), first + 0.8)
		for id: String in counts:
			assert_gt(int(counts[id]), 0, "%s 높이 %.1f의 접촉 줄" % [id, height])
		assert_eq(Horde.full_depth(walls[2]), 0.0)


func test_conservative_height_uses_atlas_and_keeps_overpass() -> void:
	var wall: Dictionary = _walls(5.2)[0]
	var old_depth: float = (5.2 - 1.7) / tan(deg_to_rad(Horde.CAM_PITCH)) / sqrt(2.0)
	assert_lt(Horde.full_depth(wall), old_depth)
	assert_eq(Horde.head_height({}), Horde.HEAD_MAX_M)
	var table: Dictionary = {"bounds_px": [[2, 8, 36, 68], [3, 4, 34, 72]]}
	var height: float = 60.0 / Horde.PX_PER_M / cos(deg_to_rad(Horde.CAM_PITCH))
	assert_almost_eq(Horde.head_height(table), height, 0.0001)
	assert_lt(Horde.full_depth(wall, height), Horde.full_depth(wall))
	var bridge: Dictionary = wall.merged({"kind": "overpass"}, true)
	var hidden: int = 0
	for step: int in range(1, 80):
		if Horde.fully_hidden(bridge, Vector2(20.0, -float(step) * 0.1)):
			hidden += 1
	assert_eq(hidden, 0)
	var near_bridge: int = 0
	for chunk: Dictionary in await _layout([bridge]):
		for person: Dictionary in chunk["people"]:
			if float(person["depth"]) < Horde.full_depth(wall):
				near_bridge += 1
	assert_gt(near_bridge, 0)
	var node: Horde = Horde.new()
	add_child_autofree(node)
	var table_contacts: int = 0
	for chunk: Dictionary in await node.build_layout([wall], {"map_size": Vector2(120, 80)}, null, table):
		for person: Dictionary in chunk["people"]:
			if int(person["motion"]) in [2, 3]:
				table_contacts += 1
				assert_gte(float(person["depth"]), Horde.full_depth(wall, height))
				assert_lte(float(person["depth"]), Horde.full_depth(wall, height) + 0.8)
	assert_gt(table_contacts, 0)


func test_joined_segments_keep_people_at_shared_endpoint() -> void:
	var first: Dictionary = {"id": "a", "a": Vector2(4, 0), "b": Vector2(28, 0), "out": Vector2(0, -1), "kind": "wall_plank", "height": 1.0}
	var second: Dictionary = first.merged({"id": "b", "a": Vector2(28, 0), "b": Vector2(52, 0)}, true)
	var walls: Array = [first, second]
	var layout: Array[Dictionary] = await _layout(walls)
	var before: int = 0
	var after: int = 0
	for chunk: Dictionary in layout:
		for person: Dictionary in chunk["people"]:
			var x: float = (person["position"] as Vector3).x
			if x > 26.0 and x < 28.0:
				before += 1
			if x >= 28.0 and x < 30.0:
				after += 1
	assert_gt(before, 0)
	assert_gt(after, 0)
	walls.reverse()
	assert_eq(layout, await _layout(walls))
	for chunk: Dictionary in await _layout([first]):
		for person: Dictionary in chunk["people"]:
			var x: float = (person["position"] as Vector3).x
			assert_gte(x, 6.0)
			assert_lte(x, 26.0)


func _large_walls(prefix: String) -> Array:
	var walls: Array = []
	for index: int in range(20):
		walls.append({"id": "%s_%02d" % [prefix, index], "a": Vector2(index * 40, 0), "b": Vector2((index + 1) * 40, 0), "out": Vector2(0, -1), "kind": "wall_sheet", "height": 1.0})
	return walls


func _wall_counts(layout: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for chunk: Dictionary in layout:
		var id: String = chunk["wall"]["id"]
		counts[id] = int(counts.get(id, 0)) + (chunk["people"] as Array).size()
	return counts


func test_density_has_no_half_step_from_17_to_27_metres() -> void:
	var bins: Array[int] = []
	bins.resize(10)
	bins.fill(0)
	var node: Horde = Horde.new()
	add_child_autofree(node)
	# 12개의 고정 씨앗, 각 800m. 1m 구간의 면적은 같으며 지도 상한도 동일.
	for sample: int in range(12):
		var layout: Array[Dictionary] = await node.build_layout(_large_walls("density_%d" % sample), {"map_size": Vector2(800, 80)})
		for chunk: Dictionary in layout:
			for person: Dictionary in chunk["people"]:
				var index: int = floori(float(person["depth"])) - 17
				if index >= 0 and index < bins.size():
					bins[index] += 1
	for index: int in range(bins.size()):
		assert_gt(bins[index], 100, "표본 부족: %dm" % (index + 17))
		if index > 0:
			assert_lte(absf(float(bins[index] - bins[index - 1])) / float(mini(bins[index], bins[index - 1])), 0.5, "%d~%dm 밀도 계단" % [index + 16, index + 18])
	assert_eq(Horde.density(18.0), 0.5)
	assert_almost_eq(Horde.density(26.0), 0.12, 0.00001)
	# 적분/역함수가 연속 밀도를 함께 사용한다.
	for index: int in range(17, 28):
		var depth: float = float(index)
		assert_almost_eq((Horde.density_area(depth + 0.001) - Horde.density_area(depth - 0.001)) / 0.002, Horde.density(depth), 0.0001)
		assert_almost_eq(Horde.sample_depth(Horde.density_area(depth) / Horde.density_area(40.0), 40.0), depth, 0.001)


func test_map_cap_scales_all_800m_walls_independent_of_order() -> void:
	var node: Horde = Horde.new()
	add_child_autofree(node)
	var walls: Array = _large_walls("cap")
	var first: Array[Dictionary] = await node.build_layout(walls, {"map_size": Vector2(800, 80)})
	var counts: Dictionary = _wall_counts(first)
	assert_lte(int(node.stats["instances"]), 3000)
	assert_lt(float(node.stats["density_scale"]), 1.0)
	assert_almost_eq(float(node.stats["candidate_sum"]) * float(node.stats["density_scale"]), 3000.0, 0.0001)
	assert_eq(counts.size(), walls.size())
	assert_gt(int(counts.get("cap_19", 0)), 0)
	for chunk: Dictionary in first:
		assert_lte((chunk["people"] as Array).size(), 216)
	walls.reverse()
	assert_eq(counts, _wall_counts(await node.build_layout(walls, {"map_size": Vector2(800, 80)})))
	assert_lte(int(node.stats["instances"]), 3000)


func test_time_budget_requests_rest_before_piece_cap() -> void:
	var node: Horde = Horde.new()
	add_child_autofree(node)
	node._begin_stats(null)
	node._pieces = 1
	node._work_start = Time.get_ticks_usec() - Horde.WORK_USEC
	node._rest_from = node._work_start
	assert_true(node._rest_due())
	node._account()
	assert_gte(float(node.stats["max_continuous_ms"]), 6.0)
	assert_true(node._rest_due(), "단계를 바꾸며 시간을 셈해도 마지막 쉼 뒤 6 ms면 쉼 자리")
	# 경계와 조각 수는 시각을 고정해 본다(CI 스케줄링에 흔들리지 않게).
	var start: int = 1_000_000
	node._continuous_usec = 0
	node._pieces = Horde.PIECE_CAP * 10
	node._work_start = start
	node._rest_from = start
	assert_false(node._rest_due(start + Horde.WORK_USEC - 1), "조각 수만으로 프레임을 양보하지 않는다")
	assert_true(node._rest_due(start + Horde.WORK_USEC))
	node._staged = true
	node._continuous_usec = Horde.WORK_USEC - 1
	assert_false(node._rest_due(start))
	assert_true(node._rest_due(start + 1), "준비 단계는 계산한 작업 시간까지 더해 본다")


func test_late_field_player_reaches_focus_after_setup() -> void:
	var field := LateField.new()
	add_child_autofree(field)
	var node := FixtureHorde.new()
	node.fixture = _baked_table()
	field.add_child(node)
	await node.setup(_walls(1.0), {"map_size": Vector2(120, 80), "field": field}, null)
	node.set_process(false)
	assert_true(bool(node.stats["ready"]))
	node._process(0.1)
	assert_eq(node._focus.z, 0.0)
	field.player = Node3D.new()
	field.add_child(field.player)
	field.player.position = Vector3(12, 0, 2)
	node._process(0.5)
	assert_gt(node._focus.z, 0.0)
	assert_eq(Vector2(node._focus.x, node._focus.y), Vector2(12, 2))
	field.player.position.x = 18.0
	node._process(0.5)
	assert_gt(node._focus.x, 12.0)
	field.player = null
	node._process(0.5)
	assert_lt(node._focus.z, 1.0)


func test_card_mesh_foot_edge_and_triangle_interiors() -> void:
	var mesh: ArrayMesh = Horde.card_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_eq(vertices.size(), 6)
	assert_eq(indices.size(), 12)
	assert_almost_eq(uv[2].y, 0.8, 0.00001)
	assert_almost_eq(uv[3].y, 0.8, 0.00001)
	var rect := Rect2(2, 13, 37, 61)
	var foot := Vector3(15, 2, -5)
	var back: Vector3 = Horde.camera_back()
	var right: Vector3 = Vector3.UP.cross(back).normalized()
	var up: Vector3 = back.cross(right).normalized()
	for foot_x: float in [5.0, 21.0, 36.0]:
		var world := PackedVector3Array()
		var pixels := PackedVector2Array()
		for index: int in range(vertices.size()):
			var pixel: Vector2 = Horde.card_pixel(uv[index], rect)
			pixels.append(pixel)
			world.append(Horde.upright_corner(foot, Vector2(pixel.x - foot_x, 64.0 - pixel.y) * (Horde.MAX_SCALE / Horde.PX_PER_M)))
		# 실제 두 가운데 정점을 잇는 삼각형 변 내부의 발 원점 화소.
		var along: float = (foot_x - rect.position.x) / rect.size.x
		var foot_sample: Vector3 = world[2].lerp(world[3], along)
		assert_almost_eq(foot_sample.distance_to(foot), 0.0, 0.0001)
		assert_almost_eq(foot_sample.dot(-back), foot.dot(-back), 0.0001)
		var people: Array[Dictionary] = [{"position": foot}]
		var box: AABB = Horde.card_aabb(people)
		# 보조식을 내부 화소에 직접 적용하지 않고 실제 삼각형 정점을 보간한다.
		for triangle: int in range(4):
			for weight: Vector3 in [Vector3(0.2, 0.3, 0.5), Vector3(0.6, 0.2, 0.2)]:
				var a: int = indices[triangle * 3]
				var b: int = indices[triangle * 3 + 1]
				var c: int = indices[triangle * 3 + 2]
				var point: Vector3 = world[a] * weight.x + world[b] * weight.y + world[c] * weight.z
				var pixel: Vector2 = pixels[a] * weight.x + pixels[b] * weight.y + pixels[c] * weight.z
				var corner := Vector2(pixel.x - foot_x, 64.0 - pixel.y) * (Horde.MAX_SCALE / Horde.PX_PER_M)
				assert_true(box.has_point(point))
				assert_almost_eq((point - foot).dot(right), corner.x, 0.0001)
				assert_almost_eq((point - foot).dot(up), corner.y + ((point.y - foot.y) * up.y if triangle >= 2 else 0.0), 0.0001)
				if triangle < 2:
					var height: float = corner.y / cos(deg_to_rad(Horde.CAM_PITCH))
					assert_almost_eq(point.y - foot.y, height, 0.0001)
					assert_almost_eq((point - foot).dot(-back), -height * back.y, 0.0001)
				else:
					assert_gt(point.y, foot.y)
					assert_lte(point.y - foot.y, Horde.SOLE_LIFT)
					assert_almost_eq((point - foot).dot(-back), corner.y / tan(deg_to_rad(Horde.CAM_PITCH)) - (point.y - foot.y) * back.y, 0.0001)


func test_comparison_and_uploaded_cards_share_all_foot_x_values() -> void:
	var node := FixtureHorde.new()
	add_child_autofree(node)
	node.fixture = _baked_table()
	await node.setup(_walls(1.0), {"map_size": Vector2(120, 80)}, null)
	node.set_process(false)
	var expected := PackedFloat32Array(node.fixture["foot_px_x"])
	var comparison: ShaderMaterial = Shots.comparison_card_material(node.fixture)
	assert_eq(comparison.get_shader_parameter("foot_px_x"), expected)
	assert_eq(expected.size(), 32)
	var submitted: int = 0
	assert_gt(node._draws.size(), 0)
	for draw: MultiMeshInstance3D in node._draws:
		var mat: ShaderMaterial = draw.material_override
		assert_eq(mat.get_shader_parameter("foot_px_x"), expected)
		assert_true(draw.multimesh.mesh is ArrayMesh)
		submitted += draw.multimesh.instance_count
	assert_eq(submitted, int(node.stats["instances"]))
	assert_eq(submitted, int(node.stats["uploaded_instances"]))


func test_camera_selection_and_frame_writes_scale_with_visible_chunks() -> void:
	var node := FixtureHorde.new()
	add_child_autofree(node)
	node.fixture = _baked_table()
	var sight := ShaderMaterial.new()
	sight.shader = load("res://fx/shaders/horde_far.gdshader")
	await node.setup(_large_walls("frame"), {"map_size": Vector2(800, 80), "material": sight}, null)
	node.set_process(false)
	assert_eq(node._draws.size(), 40)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2000.0
	camera.far = 3000.0
	var target := Vector3(400, 0, -20)
	camera.position = target + Horde.camera_back() * 1200.0
	camera.look_at(target)
	camera.make_current()
	var selected: Array[int] = node._select_visible(camera)
	assert_eq(selected.size(), 6)
	node._process(0.1)
	assert_eq(node.visible_chunks, selected)
	node._process(0.1) # 새로 들어온 덩어리의 최초 전송 뒤 정상 프레임.
	assert_eq(node.frame_material_writes, selected.size() * 3)
	assert_eq(node.frame_sight_reads, 5)
	var drawn: int = 0
	for index: int in range(node._draws.size()):
		assert_eq(node._draws[index].visible, selected.has(index))
		if node._draws[index].visible:
			drawn += node._draws[index].multimesh.instance_count
	assert_lte(drawn, 1296)
	sight.set_shader_parameter("eye_r", 12.0)
	node._process(0.1)
	assert_eq(node.frame_material_writes, selected.size() * 4)
	for index: int in selected:
		assert_eq(node._materials[index].get_shader_parameter("eye_r"), 12.0)
	var previous: Array[int] = selected.duplicate()
	sight.set_shader_parameter("eye_xz", Vector2(15, 2))
	node._process(0.1)
	assert_eq(node.frame_material_writes, selected.size() * 4)
	for index: int in range(node._materials.size()):
		if not previous.has(index):
			assert_false(node._sent_sight.has(index), "화면 밖에는 시야를 전송하지 않는다")
	node._process(0.1)
	assert_eq(node.frame_material_writes, selected.size() * 3)
	camera.position += Vector3(10000, 0, 10000)
	assert_true(node._select_visible(camera).is_empty())
	node._process(0.1)
	assert_eq(node.frame_material_writes, 0)
	camera.position -= Vector3(10000, 0, 10000)
	camera.position.x += 300.0
	node._process(0.1)
	for index: int in node.visible_chunks:
		assert_eq(node._materials[index].get_shader_parameter("eye_xz"), Vector2(15, 2))
		assert_eq(node._materials[index].get_shader_parameter("eye_r"), 12.0)


func test_staged_zero_depth_planning_and_sort_use_time_budget() -> void:
	var node: Horde = Horde.new()
	add_child_autofree(node)
	var pace := Pace.new(get_tree(), true)
	var walls: Array = []
	for index: int in range(600):
		walls.append({"id": "skip_%04d" % (599 - index), "a": Vector2(index, 0), "b": Vector2(index + 1, 0),
			"out": Vector2(0, -1), "kind": "wall_sheet", "height": 1.0, "depth": 0.0 if index % 2 == 0 else 0.4})
	var layout: Array[Dictionary] = await node.build_layout(walls, {"map_size": Vector2(600, 80)}, pace)
	assert_true(layout.is_empty())
	node._continuous_usec = Horde.WORK_USEC
	var before: int = Engine.get_process_frames()
	var sorted: Array[Dictionary] = []
	for wall: Dictionary in walls:
		sorted.append(wall)
	sorted = await node._sort_rows(sorted, true)
	assert_gt(Engine.get_process_frames(), before)
	assert_gt(pace.waits, 0)
	assert_eq(String(sorted[0]["id"]), "skip_0000")
	assert_false(bool(node.stats["cancelled"]))


func test_people_sort_and_aabb_yield_at_remaining_budget() -> void:
	var node: Horde = Horde.new()
	add_child_autofree(node)
	var pace := Pace.new(get_tree(), true)
	var people: Array[Dictionary] = [{"position": Vector3(1, 0, -2)}, {"position": Vector3(3, 0, -4)}]
	for index: int in range(people.size()):
		people[index]["sort_depth"] = (people[index]["position"] as Vector3).dot(-Horde.camera_back())
		people[index]["order"] = index
	node._begin_stats(pace)
	node._continuous_usec = Horde.WORK_USEC
	var before: int = Engine.get_process_frames()
	var sorted: Array[Dictionary] = await node._sort_rows(people, false)
	assert_gt(Engine.get_process_frames(), before)
	assert_eq(sorted.size(), people.size())
	node._continuous_usec = Horde.WORK_USEC
	before = Engine.get_process_frames()
	var box: AABB = await node._card_aabb(sorted)
	assert_gt(Engine.get_process_frames(), before)
	assert_eq(box, Horde.card_aabb(sorted))


func test_hidden_staged_setup_accounts_resources_without_forced_frames() -> void:
	var node := FixtureHorde.new()
	add_child_autofree(node)
	node.hide()
	node.fixture = _baked_table()
	var pace := Pace.new(get_tree(), true)
	await node.setup(_walls(1.0), {"map_size": Vector2(120, 80), "staged": true}, pace)
	node.set_process(false)
	assert_true(bool(node.stats["ready"]))
	assert_false(bool(node.stats["cancelled"]))
	assert_eq(node.read_frames.size(), 3)
	assert_gte(node.read_frames[1], node.read_frames[0])
	assert_gte(node.read_frames[2], node.read_frames[1])
	assert_gte(float(node.stats["cpu_ms"]), float(node.stats["resource_ms"]))
	assert_gte(float(node.stats["max_continuous_ms"]), float(node.stats["resource_max_ms"]))
	assert_eq(int(node.stats["resource_loads"]), 2)
	assert_eq(int(node.stats["resource_first"]) + int(node.stats["resource_cached"]), 1)


func test_abandon_after_table_skips_layout_and_resource_connection() -> void:
	var field := LateField.new()
	add_child_autofree(field)
	field.pace = Pace.new(get_tree(), true)
	var loader := Loader.new()
	add_child_autofree(loader)
	loader.field = field
	var node := FixtureHorde.new()
	add_child_autofree(node)
	node.fixture = _baked_table()
	node.after_table = loader.abandon
	await node.setup(_large_walls("cancel"), {"map_size": Vector2(800, 80), "staged": true}, field.pace)
	assert_true(bool(node.stats["cancelled"]))
	assert_false(bool(node.stats["ready"]))
	assert_eq(node.read_frames.size(), 1)
	assert_eq(int(node.stats["resource_loads"]), 2, "처음 요청은 허용하되 연결과 배치는 취소한다")
	assert_eq(int(node.stats["attempts"]), 0)
	assert_true(node._draws.is_empty())
	field.built.emit()


func test_abandon_during_layout_exits_next_piece() -> void:
	var field := LateField.new()
	add_child_autofree(field)
	field.pace = Pace.new(get_tree(), true)
	var loader := Loader.new()
	add_child_autofree(loader)
	loader.field = field
	var node: Horde = Horde.new()
	add_child_autofree(node)
	get_tree().process_frame.connect(loader.abandon, CONNECT_ONE_SHOT)
	var layout: Array[Dictionary] = await node.build_layout(_large_walls("cancel_layout"), {"map_size": Vector2(800, 80)}, field.pace)
	assert_true(layout.is_empty())
	assert_true(bool(node.stats["cancelled"]))
	assert_eq(field.pace.waits, 1)
	assert_lte(int(node.stats["attempts"]), Horde.MAP_CAP * Horde.MAX_TRIES)
	field.built.emit()


func test_cancel_before_setup_skips_table_but_sync_setup_is_valid() -> void:
	var node := FixtureHorde.new()
	add_child_autofree(node)
	node.fixture = _baked_table()
	var pace := Pace.new(get_tree(), true)
	pace.on = false
	await node.setup(_walls(), {"map_size": Vector2(120, 80), "staged": true}, pace)
	assert_true(bool(node.stats["cancelled"]))
	assert_true(node.read_frames.is_empty())
	assert_eq(int(node.stats["resource_loads"]), 0)
	var sync_node := FixtureHorde.new()
	add_child_autofree(sync_node)
	sync_node.fixture = _baked_table()
	await sync_node.setup(_walls(1.0), {"map_size": Vector2(120, 80)}, Pace.new())
	sync_node.set_process(false)
	assert_true(bool(sync_node.stats["ready"]))


func test_table_failure_reasons_warn_before_empty_layout_except_zero_depth() -> void:
	var absent: Dictionary = Horde.read_table_result("res://models/horde/__missing_h1_table__.json")
	assert_true(String(absent["error"]).begins_with("없음:"))
	var broken: Dictionary = Horde.parse_table_result("{broken")
	assert_true(String(broken["error"]).begins_with("파싱:"))
	var wrong: Dictionary = Horde.parse_table_result("{}")
	assert_eq(wrong["error"], "계약 다름")
	var high_wall: Dictionary = _walls(100.0)[0].merged({"depth": 1.0}, true)
	for chunk: Dictionary in await _layout([high_wall]):
		for person: Dictionary in chunk["people"]:
			var position3: Vector3 = person["position"]
			assert_false(Horde.fully_hidden(high_wall, Vector2(position3.x, position3.z)), "높은 벽도 끝의 부분 노출은 보존")
	for issue: Dictionary in [absent, broken, wrong]:
		var node := FixtureHorde.new()
		add_child_autofree(node)
		node.table_failure = issue["error"]
		await node.setup([high_wall], {"map_size": Vector2(120, 80)}, null)
		assert_eq(node.stats["table_error"], issue["error"])
		assert_eq(node.stats["table_warning"], issue["error"])
		assert_true(node.chunks.is_empty())
		assert_eq(int(node.stats["resource_loads"]), 2)
	var empty := FixtureHorde.new()
	add_child_autofree(empty)
	empty.table_failure = absent["error"]
	await empty.setup([high_wall.merged({"depth": 0.0}, true)], {"map_size": Vector2(120, 80)}, null)
	assert_eq(empty.stats["table_warning"], "")
	assert_true(empty.chunks.is_empty())


func test_wall_end_keeps_partly_exposed_card_width_and_motion() -> void:
	var wall: Dictionary = Shots.test_walls()[0].merged({"height": 5.2}, true)
	assert_false(Horde.fully_hidden(wall, Vector2(25.6, -2.2)), "끝 교점 27.8에서도 카드 오른쪽은 노출된다")
	assert_true(Horde.fully_hidden(wall, Vector2(16, -1.0)))
	var geometry: Dictionary = Horde.wall_geometry(wall)
	var span: Vector2 = Horde.visible_span(geometry, 2.2, 2.0, 22.0, 0.99)
	assert_lt(span.x, 21.6)
	assert_gte(span.y, 21.6)
	var node: Horde = Horde.new()
	add_child_autofree(node)
	var exposed: int = 0
	for chunk: Dictionary in await node.build_layout([wall], {"map_size": Vector2(120, 80)}):
		for person: Dictionary in chunk["people"]:
			if float(person["depth"]) < float(geometry["full"]):
				exposed += 1
	assert_gt(exposed, 0, "배치도 벽 끝의 얕은 노출 구간을 남긴다")


func test_test_walls_keep_432_and_stage_timings() -> void:
	var node := FixtureHorde.new()
	add_child_autofree(node)
	node.fixture = Horde.read_table()
	assert_false(node.fixture.is_empty(), "실제 칸 표와 시험 벽으로 같은 432명을 확인")
	await node.setup(Shots.test_walls(), {"map_size": Vector2(120, 80)}, Pace.new())
	assert_true(bool(node.stats["ready"]))
	assert_eq(int(node.stats["instances"]), 432)
	assert_eq(int(node.stats["uploaded_instances"]), 432)
	for key: String in ["table_ms", "candidates_ms", "sort_ms", "aabb_ms", "upload_ms"]:
		assert_gte(float(node.stats[key]), 0.0)
		assert_lte(float(node.stats[key]), float(node.stats["cpu_ms"]))
	assert_lt(int(node.stats["attempts"]), 4169, "이전 432명 기준보다 거절 후보를 줄인다")
	# CPU 30ms는 실제 아틀라스 최초/캐시 적중 촬영에서 호출자가 판정한다.
	var paced: Horde = Horde.new()
	add_child_autofree(paced)
	var paced_layout: Array[Dictionary] = await paced.build_layout(Shots.test_walls(), {"map_size": Vector2(120, 80)}, Pace.new(get_tree(), true), node.fixture)
	assert_eq(paced_layout, node.chunks, "쉼 시점과 무관하게 자리·동작·방향·씨앗이 같다")


func test_visible_six_keep_tie_until_distance_margin_is_crossed() -> void:
	var node: Horde = Horde.new()
	add_child_autofree(node)
	for index: int in range(7):
		var x: float = 0.0 if index < 5 else (-10.0 if index == 5 else 10.0)
		node.chunks.append({"aabb": AABB(Vector3(x - 0.1, -0.1, -0.1), Vector3.ONE * 0.2)})
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 60.0
	camera.position = Vector3(-0.01, 10, 30)
	camera.look_at(Vector3.ZERO)
	node.visible_chunks = node._select_visible(camera)
	assert_eq(node.visible_chunks.size(), 6)
	assert_true(node.visible_chunks.has(5))
	for x: float in [0.01, -0.01, 0.1, -0.1]:
		camera.position.x = x
		var chosen: Array[int] = node._select_visible(camera)
		assert_eq(chosen.size(), 6)
		assert_true(chosen.has(5))
		assert_false(chosen.has(6))
	camera.position.x = 10.0
	var changed: Array[int] = node._select_visible(camera)
	assert_eq(changed.size(), 6)
	assert_true(changed.has(6))
	assert_false(changed.has(5))


func test_real_assets_sync_cpu_budget_and_cache_classification() -> void:
	var expected_cached: int = int(ResourceLoader.has_cached(Horde.ATLAS_PATH)) + int(ResourceLoader.has_cached(Horde.SHADER_PATH))
	var first: Horde = Horde.new()
	add_child_autofree(first)
	# 나눠 짓기 끔은 한 번에 끝난다: 자원 읽기를 기다리며 프레임을 넘기면 짓는 중인
	# 필드의 _process가 먼저 돈다(촬영에서 feel 없는 필드가 돎).
	var frame_before: int = Engine.get_process_frames()
	await first.setup(Shots.test_walls(), {"map_size": Vector2(120, 80)}, Pace.new())
	assert_eq(Engine.get_process_frames(), frame_before, "끔 짓기는 프레임을 넘기지 않는다")
	assert_true(bool(first.stats["ready"]))
	assert_eq(int(first.stats["resource_cached"]), expected_cached)
	assert_eq(int(first.stats["resource_first"]), 2 - expected_cached)
	assert_eq(int(first.stats["instances"]), 432)
	# 30 ms 문턱은 실제 렌더러 촬영에서 잰다(CI 기계 속도에 기대지 않는다). 여기선 단계 합만.
	assert_gt(float(first.stats["cpu_ms"]), 0.0)
	assert_lte(float(first.stats["material_ms"]), float(first.stats["upload_ms"]))
	var cached: Horde = Horde.new()
	add_child_autofree(cached)
	await cached.setup(Shots.test_walls(), {"map_size": Vector2(120, 80)}, Pace.new())
	assert_true(bool(cached.stats["ready"]))
	assert_eq(int(cached.stats["resource_cached"]), 2)
	assert_eq(int(cached.stats["resource_first"]), 0)
	assert_eq(cached.chunks, first.chunks)
	assert_eq(int(cached.stats["uploaded_instances"]), 432)
	assert_true(ResourceLoader.has_cached(Horde.SHADER_PATH), "컴파일한 셰이더는 정차 사이에 남는다")
	assert_eq(int(first.stats["requests_released"]), 0, "다 받은 짓기는 넘길 요청이 없다")
	assert_true(first._open_requests.is_empty())


func test_unused_thread_reads_are_collected_after_an_early_return() -> void:
	# 벽이 없어 배치가 비면 아틀라스·셰이더를 받지 않고 끝난다: 요청 하나에 get 하나는 수거 목록이 한다.
	var node: Horde = Horde.new()
	add_child_autofree(node)
	await node.setup([], {"map_size": Vector2(120, 80)}, Pace.new())
	assert_false(bool(node.stats["ready"]))
	assert_eq(int(node.stats["resource_loads"]), 2)
	assert_eq(int(node.stats["requests_released"]), 2, "등록한 요청 둘 다 수거 목록으로")
	assert_true(node._open_requests.is_empty())
	for _frame: int in range(600):
		if Horde._orphan_paths.is_empty():
			break
		await get_tree().process_frame
	assert_true(Horde._orphan_paths.is_empty(), "읽기가 끝나면 get으로 회수")


func test_disabled_field_show_selects_chunks_without_advancing_clock() -> void:
	var field := LateField.new()
	add_child_autofree(field)
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.hide()
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 100.0
	camera.position = Vector3(10, 0, 10) + Horde.camera_back() * 80.0
	camera.look_at(Vector3(10, 0, 10))
	camera.make_current()
	var node := FixtureHorde.new()
	field.add_child(node)
	node.fixture = _baked_table()
	await node.setup(Shots.test_walls(), {"map_size": Vector2(120, 80), "field": field}, null)
	field.show()
	assert_false(node.visible_chunks.is_empty())
	assert_true(node.can_process())
	var clock_before: float = node._focus_clock
	await get_tree().process_frame
	assert_eq(node._focus_clock, clock_before)
	camera.position += Vector3(10000, 0, 10000)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(node.visible_chunks.is_empty())
	assert_eq(node._focus_clock, clock_before)
	# 처리 모드는 켜고 set_process(false)로만 멈춘 필드(물러나는 필드·촬영 도구 꼴)도 시계를 멈춘다.
	camera.position -= Vector3(10000, 0, 10000)
	field.process_mode = Node.PROCESS_MODE_INHERIT
	field.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(node._focus_clock, clock_before, "set_process(false) 필드")
	field.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(node._focus_clock, clock_before, "필드 처리가 돌면 시계도 간다")


func test_shared_frame_clock_keeps_motion_until_visible_frame_boundary() -> void:
	var source: String = FileAccess.get_file_as_string(Horde.SHADER_PATH)
	assert_true(source.contains("float frame = mod(floor(frame_clock), 6.0)"))
	assert_true(source.contains("float boundary_clock = max(0.0, (floor(frame_clock) - 6.0 * phase) / base_rate)"))
	assert_false(source.contains("fract(frame_clock)"), "경계를 시각에서 틀 나이를 빼서 구하지 않는다")
	# 셰이더와 같은 단정도 계산으로, 한 그림 틀 동안 이력 칸이 그대로인지(점검이 찾은 사례 포함).
	for case: Vector2 in [Vector2(0.4475752711, 4.0638699532), Vector2(0.13, 4.6), Vector2(0.91, 5.2)]:
		var phase: float = case.x
		var rate: float = case.y
		var slot_of_frame: Dictionary = {}
		for step: int in range(0, 6000):
			var time_s: float = _f32(62.0 + float(step) * 0.0001)
			var frame_clock: float = _f32(_f32(time_s * rate) + _f32(6.0 * phase))
			var frame_n: float = floorf(frame_clock)
			var boundary: float = maxf(0.0, _f32(_f32(frame_n - _f32(6.0 * phase)) / rate))
			var slot: int = posmod(floori(_f32(boundary * 30.0)), 32)
			if slot_of_frame.has(frame_n):
				assert_eq(slot, int(slot_of_frame[frame_n]), "틀 %d 안에서 이력 칸이 바뀜 (phase %.4f)" % [int(frame_n), phase])
			slot_of_frame[frame_n] = slot
	assert_true(source.contains("if (base_motion == 0)"))
	assert_true(source.contains("0.3 * (1.0 - reaction)"))
	var fragment: String = source.get_slice("void fragment()", 1)
	assert_false(fragment.contains("clip_lengths"))
	assert_false(fragment.contains("floor("))
	# 기본 길이 1.4/1.3 어느 쪽도 진입·이탈 판정은 현재 표시 틀의 경계에 고정.
	for length_s: float in [1.4, 1.3]:
		for speed: float in [0.85, 1.0, 1.15]:
			var duration: float = length_s / (6.0 * speed)
			var previous_motion: int = 0
			var previous_frame: int = -1
			var transitions: int = 0
			for step: int in range(1, 1500):
				var time_s: float = float(step) * 0.001
				var frame: int = floori(time_s / duration + 0.37)
				var boundary: float = maxf(0.0, (float(frame) - 0.37) * duration)
				var motion: int = 2 if boundary >= 0.31 and boundary < 0.91 else 0
				if motion != previous_motion:
					assert_ne(frame, previous_frame)
					transitions += 1
				previous_frame = frame
				previous_motion = motion
			assert_eq(transitions, 2)
	# 반응 문턱 양쪽에서 반경/발 좌표가 연속이고, 완전 반응에서 고리는 0이다.
	var before: Vector2 = Vector2.RIGHT * 0.3 * (1.0 - 0.19999)
	var after: Vector2 = Vector2.RIGHT * 0.3 * (1.0 - 0.20001)
	assert_lt(before.distance_to(after), 0.00001)


func test_night_mask_capture_is_explicit_and_unexplored() -> void:
	var count: int = 0
	for scene: Dictionary in Shots.SCENES:
		if bool(scene.get("mask", false)):
			assert_eq(String(scene["name"]), "night_mask")
			assert_eq(float(scene["hour"]), 19.0)
			count += 1
	assert_eq(count, 1)
	var source: String = FileAccess.get_file_as_string("res://tools/horde_shots.gd")
	assert_true(source.contains("vis_image.fill(Color(0, 0, 0, 1))"))
	assert_true(source.contains('"mask": masked'))
