extends "res://addons/gut/test.gd"
## PNG 없이 배치/칸 표/연결 계약을 확인한다. 굽기·그림 확인은 별도 문지기 실행.

const Horde = preload("res://game/world/horde_view.gd")
const Field = preload("res://game/field_game.gd")
const Switch = preload("res://game/perf_switch.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const Bake = preload("res://tools/horde_bake.gd")
const Grid = preload("res://game/world/field_grid.gd")


func _walls(height: float = 3.0) -> Array:
	return [
		{"id": "north", "a": Vector2(4, 0), "b": Vector2(76, 0), "out": Vector2(0, -1), "kind": "wall_sheet", "height": height},
		{"id": "west", "a": Vector2(0, 4), "b": Vector2(0, 52), "out": Vector2(-1, 0), "kind": "wall_stack", "height": height},
	]


func _layout(walls: Array) -> Array[Dictionary]:
	var node: Horde = Horde.new()
	add_child_autofree(node)
	return await node.build_layout(walls, {"map_size": Vector2(120, 80)})


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
	assert_eq(Horde.table_contract()["foot_px"], [20.0, 64.0])
	assert_eq(Horde.table_contract()["padding_px"], 2)


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
			for px: float in [0.0, 40.0]:
				for py: float in [0.0, 80.0]:
					var corner: Vector3 = Horde.upright_corner(foot, Vector2(px - 20.0, 64.0 - py) * (1.08 / 30.0))
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
	assert_ne(Horde.stream("north", cell, 25), Horde.stream("north", cell, 26))
	assert_ne(Horde.stream("north", cell, 25), Horde.stream("west", cell, 25))
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
	var cached_before: bool = ResourceLoader.has_cached(Horde.ATLAS_PATH)
	var node: Node3D = await Horde.attach(parent, _walls(), {}, null, Switch._valid({"horde": false}))
	assert_null(node)
	assert_null(parent.get_node_or_null("HordeView"))
	assert_eq(parent.get_child_count(), 0)
	assert_eq(ResourceLoader.has_cached(Horde.ATLAS_PATH), cached_before)
	assert_eq(Switch._valid({"horde": true}), {"horde": true})
	assert_false(Switch._valid({"horde": "false"}).has("horde"))


func test_hiding_and_exit_clear_owned_focus() -> void:
	var node: Horde = Horde.new()
	add_child_autofree(node)
	node._history.resize(Horde.HISTORY_SIZE)
	node._history.fill(Vector4.ONE)
	node._focus = Vector4.ONE
	node.hide()
	node._visibility_reset()
	assert_eq(node._focus, Vector4.ZERO)
	for sample: Vector4 in node._history:
		assert_eq(sample, Vector4.ZERO)
	node._focus = Vector4.ONE
	node._exit_tree()
	assert_eq(node._focus, Vector4.ZERO)


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
			assert_almost_eq(upright.dot(up), old.dot(up), 0.0001)
			if py < 64.0:
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
	assert_true(node._rest_due())
	node._account()
	assert_gte(float(node.stats["max_continuous_ms"]), 6.0)
