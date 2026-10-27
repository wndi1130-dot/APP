extends "res://addons/gut/test.gd"

const EdgeBand = preload("res://game/world/edge_band.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const MapEdge = preload("res://fx/map_edge.gd")
const F = FieldGrid.Floor


func after_each() -> void:
	EdgeBand.view_band = EdgeBand.BAND


## 60 x 40 snow; a rail line along row 20 out of both side edges, a road down
## column 30 out of the north edge.
func _grid() -> FieldGrid:
	var g := FieldGrid.new(60, 40)
	for x in g.width:
		g.floor[g.index(Vector2i(x, 20))] = F.RAIL
	for y in range(0, 20):
		g.floor[g.index(Vector2i(30, y))] = F.ROAD
		g.floor[g.index(Vector2i(31, y))] = F.ROAD
	return g


func test_values_are_fixed() -> void:
	assert_eq(EdgeBand.BAND, 12.0)
	assert_eq(EdgeBand.INNER_ROW, 2.6)
	assert_eq(EdgeBand.INNER_SPACING, 2.0)
	assert_eq(EdgeBand.DEEP_SPACING, 4.0)
	assert_eq(EdgeBand.TRUNK_GAP, 0.3)
	assert_eq(EdgeBand.EDGE_WAVE, 1.2)
	assert_eq(EdgeBand.RAIL_CLEAR, 2.5)
	assert_eq(EdgeBand.ROAD_RUN, EdgeBand.BAND - 3.0)
	assert_eq(EdgeBand.ROAD_WIDEST, 8)
	assert_eq(EdgeBand.SHADE_DEPTH, 1.2)
	assert_eq(EdgeBand.GLADE_EVERY, 48.0)
	assert_eq(EdgeBand.GLADE_CHANCE, 0.5)
	assert_eq(EdgeBand.GLADE_SIZE, Vector2(4.0, 6.0))
	assert_eq(EdgeBand.GLADE_NEAR, 3.0)


func test_now_and_then_a_glade_with_a_trace_of_people_behind_the_first_rows() -> void:
	# A town-sized map: about a dozen chances round it.
	var g := FieldGrid.new(170, 120)
	for x in g.width:
		g.floor[g.index(Vector2i(x, 60))] = F.RAIL
	var total := 0
	for seed in range(1, 21):
		var plan := EdgeBand.plan(g, seed)
		total += plan["glades"].size()
		for gl: Dictionary in plan["glades"]:
			var r: Rect2 = gl["rect"]
			assert_between(r.size.x, EdgeBand.GLADE_SIZE.x, EdgeBand.GLADE_SIZE.y)
			assert_eq(r.size.x, r.size.y, "square")
			var near := minf(EdgeBand.outside(g, r.position.x, r.position.y), EdgeBand.outside(g, r.end.x, r.end.y))
			assert_almost_eq(near, EdgeBand.GLADE_NEAR, 0.001, "behind the first rows")
			assert_true(EdgeBand.outside(g, r.get_center().x, r.get_center().y) < EdgeBand.BAND - 2.0, "where the camera shows it")
			assert_true(absf(r.get_center().y - 60.5) > EdgeBand.RAIL_CLEAR + r.size.y * 0.5 or (r.position.x >= 0.0 and r.end.x <= g.width), "not on the rail line running out")
			assert_true(["felled", "rest"].has(gl["kind"]))
			for p: Dictionary in gl["props"]:
				var at: Vector3 = p["at"]
				assert_true(r.has_point(Vector2(at.x, at.z)), "the trace stands in its glade")
			for t: Dictionary in plan["trees"]:
				var at: Vector3 = t["at"]
				assert_false(r.has_point(Vector2(at.x, at.z)), "no tree in a glade")
	# 20 maps of about 12 chances at one in two: well over none, well under all.
	assert_between(total, 60, 180)


func test_the_camera_never_looks_past_the_band() -> void:
	var half := EdgeBand.view_half(24.0, 2.0, 52.0)
	assert_almost_eq(half.x, 24.0, 0.0001)
	assert_almost_eq(half.y, 12.0 / sin(deg_to_rad(52.0)), 0.0001)
	var mid := Vector3(80, 0, 60)
	assert_eq(EdgeBand.clamp_focus(mid, half, 170, 120), mid, "inside the map nothing moves")
	var west := EdgeBand.clamp_focus(Vector3(1, 0, 60), half, 170, 120)
	assert_almost_eq(west.x - half.x, -EdgeBand.BAND, 0.0001, "the left of the view stops at the band's far side")
	var far := EdgeBand.view_half(36.0, 2.0, 52.0)
	var south := EdgeBand.clamp_focus(Vector3(80, 0, 119), far, 170, 120)
	assert_almost_eq(south.z + far.y, 120.0 + EdgeBand.BAND, 0.0001, "zoomed out, the bottom of the view stops there too")
	var narrow := EdgeBand.clamp_focus(Vector3(3, 0, 3), Vector2(100, 100), 40, 30)
	assert_eq(narrow, Vector3(20, 0, 15), "a map smaller than the view is centred")
	# A camera turned 45° (결정 476) shows its rectangle turned: the box round it.
	var turned := EdgeBand.view_half(24.0, 2.0, 35.0, 45.0)
	var box := (24.0 + 12.0 / sin(deg_to_rad(35.0))) * cos(deg_to_rad(45.0))
	assert_almost_eq(turned.x, box, 0.0001)
	assert_almost_eq(turned.y, box, 0.0001)
	var corner := EdgeBand.clamp_focus(Vector3(1, 0, 1), turned, 170, 120)
	assert_almost_eq(corner.x - turned.x, -EdgeBand.BAND, 0.0001, "the turned view stops at the band too")
	assert_almost_eq(corner.z - turned.y, -EdgeBand.BAND, 0.0001)
	# Held that far in, a player in the map's corner would be off the screen: the
	# view follows past the band till the player is back inside the middle of it.
	var player := Vector3(1, 0, 1)
	var kept := EdgeBand.keep_on_screen(corner, player, 24.0, 2.0, 35.0, 45.0)
	var off := Vector2(player.x - kept.x, player.z - kept.z).rotated(deg_to_rad(45.0))
	assert_almost_eq(absf(off.x), 0.0, 0.01, "the corner lies straight up the screen")
	assert_almost_eq(off.y, -12.0 / sin(deg_to_rad(35.0)) * EdgeBand.KEEP, 0.01, "at the edge of the middle, not past it")
	assert_eq(EdgeBand.keep_on_screen(mid, mid, 24.0, 2.0, 35.0, 45.0), mid, "in the middle of the map nothing moves")


func test_rails_run_out_through_a_clear_corridor_and_roads_end_at_a_block() -> void:
	var g := _grid()
	var runs := EdgeBand.openings(g)
	var rails := runs.filter(func(r): return int(r["floor"]) == F.RAIL)
	var roads := runs.filter(func(r): return int(r["floor"]) == F.ROAD)
	assert_eq(rails.size(), 2, "west and east")
	assert_eq(roads.size(), 1, "north")
	assert_eq(int(roads[0]["side"]), 2)
	assert_eq([int(roads[0]["from"]), int(roads[0]["to"])], [30, 31])
	var plan := EdgeBand.plan(g, 7)
	for t: Dictionary in plan["trees"]:
		var at: Vector3 = t["at"]
		var out := EdgeBand.outside(g, at.x, at.z)
		assert_true(out >= EdgeBand.TRUNK_GAP and out < EdgeBand.BAND, "every tree stands in the band")
		if at.x < 0.0 or at.x > g.width:
			assert_true(absf(at.z - 20.5) > EdgeBand.RAIL_CLEAR, "no tree on the rail line running out")
		if at.z < 0.0 and at.x > 29.4 and at.x < 32.6:
			assert_true(at.z < -EdgeBand.ROAD_RUN - 1.0, "the road runs clear before the woods")
	assert_eq(plan["blocks"].size(), 1, "one block across the two-cell road")
	var block: Vector3 = plan["blocks"][0]["at"]
	assert_almost_eq(block.z, -EdgeBand.ROAD_RUN - 0.6, 0.0001)
	assert_true(block.x >= 30.0 and block.x <= 32.0)


func test_a_road_along_an_edge_is_not_walled_off() -> void:
	var g := _grid()
	for x in range(5, 55):
		g.floor[g.index(Vector2i(x, g.height - 1))] = F.ROAD
	var runs := EdgeBand.openings(g)
	assert_eq(runs.filter(func(r): return int(r["side"]) == 3).size(), 0, "a road beside the south edge leaves nothing open")
	var plan := EdgeBand.plan(g, 7)
	assert_eq(plan["blocks"].size(), 1, "only the road out of the north edge is blocked")
	var south := 0
	for t: Dictionary in plan["trees"]:
		var at: Vector3 = t["at"]
		if at.z > g.height and at.x > 6.0 and at.x < 54.0:
			south += 1
	assert_gt(south, 20, "woods stand past the road along the edge")


func test_the_same_map_draws_the_same_woods() -> void:
	var a := EdgeBand.plan(_grid(), 11)
	var b := EdgeBand.plan(_grid(), 11)
	var c := EdgeBand.plan(_grid(), 12)
	assert_eq(a["trees"].size(), b["trees"].size())
	assert_eq(a["trees"][0]["at"], b["trees"][0]["at"])
	assert_ne(a["trees"][0]["at"], c["trees"][0]["at"], "another place, other woods")
	# 60 x 40 map: the ring is about (84 x 64 - 60 x 40) square metres.
	var n: int = a["trees"].size()
	assert_between(n, 150, 700)


func test_the_band_is_built_under_the_ground_level() -> void:
	var g := _grid()
	var root := Node3D.new()
	add_child_autofree(root)
	var counts := EdgeBand.build(root, g, {"place_id": "test"}, StandardMaterial3D.new(), [Color.WHITE, Color.GRAY, Color.GRAY, Color.GRAY, Color.DIM_GRAY, Color.WHITE, Color.WHITE, Color.GRAY])
	var band := root.get_node("EdgeBand")
	assert_not_null(band)
	assert_not_null(band.get_node("Runs"), "the road and rail runs out of the map")
	assert_eq(int(counts["blocks"]), 1)
	var plan := EdgeBand.plan(g, EdgeBand.seed_of({"place_id": "test"}))
	assert_eq(int(counts["glades"]), plan["glades"].size())
	assert_eq(band.get_child_count(), 1 + int(counts["chunks"]) + 1 + int(counts["traces"]) + 1, "runs, tree pieces, the road's block, glade traces and one far root")
	assert_gt(int(counts["trees"]), 0)
	assert_gt(int(counts["chunks"]), 4, "the woods are cut in pieces so those off screen are not drawn")
	var far_root := band.get_node("Far")
	var props := 0
	for child in far_root.get_children():
		var geometry := child as GeometryInstance3D
		assert_not_null(geometry, "far scenery has only batched geometry, no audio or physics")
		if geometry != null:
			assert_eq(geometry.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		if child is MultiMeshInstance3D:
			props += (child as MultiMeshInstance3D).multimesh.instance_count
	assert_eq(int(counts["far"]), props, "only successfully loaded model instances count")
	var houses := 0
	for item: Dictionary in plan["far"]:
		if String(item["model"]) == EdgeBand.FAR_HOUSE:
			houses += 1
	assert_eq(int(counts["houses"]), houses)
	assert_eq(int(counts["fields"]), (plan["fields"] as Array).size())
	assert_eq(int(counts["tracks"]), (plan["tracks"] as Array).size())
	assert_eq(int(counts["sounds"]), (plan["sounds"] as Array).size())


func test_far_scenery_keeps_the_ring_and_the_continuing_corridors_clear() -> void:
	var g := _grid()
	for seed in range(1, 21):
		var planned := EdgeBand.plan(g, seed)
		assert_gt((planned["far"] as Array).size(), 0)
		var houses: Array[Vector3] = []
		var houses_by_side: Array[int] = [0, 0, 0, 0]
		var standing_by_side: Array[int] = [0, 0, 0, 0]
		var fallen_by_side: Array[int] = [0, 0, 0, 0]
		var wrecks := 0
		for item: Dictionary in planned["far"]:
			var at := item["at"] as Vector3
			var depth := EdgeBand.outside(g, at.x, at.z)
			assert_gte(depth, EdgeBand.FAR_NEAR)
			assert_lt(depth, EdgeBand.FAR_REACH)
			for corridor: Rect2 in planned["clear"]:
				assert_false(corridor.has_point(Vector2(at.x, at.z)))
			for run: Dictionary in planned["runs"]:
				var pad := EdgeBand.RAIL_CLEAR if int(run["floor"]) == F.RAIL else 0.6
				assert_false(EdgeBand.run_rect(g, run, EdgeBand.FAR_REACH, pad).has_point(Vector2(at.x, at.z)), "roads and rails stay clear beyond the band too")
			var side := int(item["side"])
			var model := String(item["model"])
			if model == EdgeBand.FAR_HOUSE:
				assert_between(depth, 35.0, 55.0)
				for other in houses:
					assert_gte(at.distance_to(other), 25.0, "isolated houses, including across corners")
				houses.append(at)
				houses_by_side[side] += 1
			elif model == "res://models/props_field/power_pole.glb":
				standing_by_side[side] += 1
			elif model == EdgeBand.FAR_POLE:
				fallen_by_side[side] += 1
			elif model == EdgeBand.FAR_CAR:
				wrecks += 1
		for side in 4:
			assert_lte(houses_by_side[side], 2)
			assert_lte(standing_by_side[side], 2)
			assert_lte(fallen_by_side[side], 2)
		assert_eq(wrecks, 1, "one wreck beside a road, never on its continuation")


func test_far_fields_stay_inside_the_ring_and_tracks_follow_only_roads() -> void:
	var g := _grid()
	for seed in range(1, 21):
		var planned := EdgeBand.plan(g, seed)
		var fields_by_side: Array[int] = [0, 0, 0, 0]
		for plot: Dictionary in planned["fields"]:
			var rect := plot["rect"] as Rect2
			var corners: Array[Vector2] = [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]
			for corner in corners:
				assert_gte(EdgeBand.outside(g, corner.x, corner.y), EdgeBand.FAR_NEAR)
				assert_lt(EdgeBand.outside(g, corner.x, corner.y), EdgeBand.FAR_REACH)
			for run: Dictionary in planned["runs"]:
				var pad := EdgeBand.RAIL_CLEAR if int(run["floor"]) == F.RAIL else 0.6
				assert_false(EdgeBand.run_rect(g, run, EdgeBand.FAR_REACH, pad).intersects(rect))
			if String(plot["kind"]) == "field":
				assert_between(rect.size.x, 12.0, 30.0)
				assert_between(rect.size.y, 12.0, 30.0)
				fields_by_side[int(plot["side"])] += 1
		for count in fields_by_side:
			assert_between(count, 1, 3)
		var tracks := planned["tracks"] as Array
		assert_eq(tracks.size(), 1, "north road only; neither rail exit becomes a dirt track")
		var track := tracks[0] as Dictionary
		assert_eq(int(track["side"]), 2)
		assert_almost_eq(float(track["along"]), 31.0, 0.0001)
		assert_almost_eq(float(track["near"]), EdgeBand.ROAD_RUN + 1.2, 0.0001)
		assert_eq(float(track["far"]), EdgeBand.FAR_REACH)
	var empty := EdgeBand.plan(FieldGrid.new(60, 40), 11)
	assert_eq((empty["tracks"] as Array).size(), 0)
	for item: Dictionary in empty["far"]:
		assert_ne(String(item["model"]), EdgeBand.FAR_CAR, "no abandoned road car at a stop without road exits")


func test_horde_sites_are_metadata_outside_the_band_and_away_from_rails() -> void:
	var g := _grid()
	for seed in range(1, 21):
		var planned := EdgeBand.plan(g, seed)
		var sites := planned["sounds"] as Array
		assert_between(sites.size(), 3, 4)
		var sides: Array[int] = []
		for site: Dictionary in sites:
			var at := site["at"] as Vector3
			var depth := EdgeBand.outside(g, at.x, at.z)
			assert_between(depth, 30.0, 40.0)
			assert_gt(depth, EdgeBand.BAND)
			assert_eq(String(site["kind"]), "horde")
			var side := 0 if at.x < 0.0 else (1 if at.x > float(g.width) else (2 if at.z < 0.0 else 3))
			assert_false(sides.has(side), "spread around separate sides")
			sides.append(side)
			for run: Dictionary in planned["runs"]:
				if int(run["floor"]) == F.RAIL:
					assert_false(EdgeBand.run_rect(g, run, EdgeBand.FAR_REACH, EdgeBand.RAIL_CLEAR + 6.0).has_point(Vector2(at.x, at.z)))
	# Even all-rail edges leave safe sound positions round the corners.
	var rail_grid := FieldGrid.new(20, 20)
	for index in rail_grid.floor.size():
		rail_grid.floor[index] = F.RAIL
	var all_rails := EdgeBand.plan(rail_grid, 7)
	assert_between((all_rails["sounds"] as Array).size(), 3, 4)
	for site: Dictionary in all_rails["sounds"]:
		var at := site["at"] as Vector3
		assert_between(EdgeBand.outside(rail_grid, at.x, at.z), 30.0, 40.0)
		for run: Dictionary in all_rails["runs"]:
			assert_false(EdgeBand.run_rect(rail_grid, run, EdgeBand.FAR_REACH, EdgeBand.RAIL_CLEAR + 6.0).has_point(Vector2(at.x, at.z)))


func test_far_plan_is_repeatable_without_moving_the_original_band() -> void:
	var grids: Array[FieldGrid] = [_grid(), FieldGrid.new(170, 120)]
	for g in grids:
		for seed: int in [7, 11, 12, 93]:
			var planned := EdgeBand.plan(g, seed)
			var repeated := EdgeBand.plan(g, seed)
			assert_eq(planned, repeated, "the complete plan repeats, including fields, tracks and sound sites")
			var original := _original_band_plan(g, seed)
			var trees := planned["trees"] as Array
			var old_trees := original["trees"] as Array
			assert_eq(trees.size(), old_trees.size(), "tree count before distant scenery")
			assert_eq((trees[0] as Dictionary)["at"], (old_trees[0] as Dictionary)["at"], "first tree before distant scenery")
			for key: String in ["trees", "blocks", "glades", "clear", "runs"]:
				assert_eq(planned[key], original[key], "unchanged original placement: " + key)
			EdgeBand.view_band = 36.0
			assert_eq(EdgeBand.plan(g, seed), planned, "camera trials do not reseed the scenery")
			EdgeBand.view_band = EdgeBand.BAND
	var a := EdgeBand.plan(_grid(), 11)
	var b := EdgeBand.plan(_grid(), 12)
	assert_ne(a["far"], b["far"], "other stops have other distant scenery")
	assert_ne(a["sounds"], b["sounds"])


## The pre-far plan's draw order, retained as a regression oracle. The original
## scatter and glade helpers are unchanged; new RNG draws must never enter here.
func _original_band_plan(g: FieldGrid, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var runs := EdgeBand.openings(g)
	var clear: Array[Rect2] = []
	var blocks: Array = []
	for run: Dictionary in runs:
		if int(run["floor"]) == F.RAIL:
			clear.append(EdgeBand.run_rect(g, run, EdgeBand.BAND + 1.0, EdgeBand.RAIL_CLEAR))
			continue
		clear.append(EdgeBand.run_rect(g, run, EdgeBand.ROAD_RUN + 1.2, 0.6))
		var across := EdgeBand.run_rect(g, run, EdgeBand.ROAD_RUN + 0.6, 0.0)
		var along_x := int(run["side"]) >= 2
		var width := across.size.x if along_x else across.size.y
		var at_end := EdgeBand._run_end(across, int(run["side"]))
		var pieces := maxi(1, int(ceil(width / 2.2)))
		for k in pieces:
			var t := (float(k) + 0.5) / float(pieces)
			var at := Vector3(across.position.x + across.size.x * t, 0, at_end.y) if along_x \
				else Vector3(at_end.x, 0, across.position.y + across.size.y * t)
			blocks.append({"at": at, "yaw": 0.0 if along_x else PI * 0.5, "model": EdgeBand.BLOCK_MODELS[k % 2 if rng.randf() < 0.7 else 1]})
	var glades := EdgeBand._glades(g, seed, clear)
	var no_trees: Array[Rect2] = clear.duplicate()
	for glade: Dictionary in glades:
		no_trees.append((glade["rect"] as Rect2).grow(0.5))
	var trees: Array = []
	EdgeBand._scatter(g, rng, no_trees, trees, EdgeBand.INNER_SPACING, EdgeBand.TRUNK_GAP, EdgeBand.INNER_ROW)
	EdgeBand._scatter(g, rng, no_trees, trees, EdgeBand.DEEP_SPACING, EdgeBand.INNER_ROW, EdgeBand.BAND)
	return {"trees": trees, "blocks": blocks, "glades": glades, "clear": clear, "runs": runs}


func test_view_band_is_live_without_changing_woods_or_default_fog() -> void:
	assert_eq(EdgeBand.view_band, 12.0)
	assert_eq(EdgeBand.BAND, 12.0)
	assert_eq(MapEdge.MARGIN, EdgeBand.FAR_REACH + 12.0)
	assert_eq(MapEdge.fog_reach(), 12.0)
	EdgeBand.view_band = 24.0
	var half := EdgeBand.view_half(24.0, 2.0, 35.0, 45.0)
	var corner := EdgeBand.clamp_focus(Vector3(-200, 0, -200), half, 170, 120)
	assert_almost_eq(corner.x - half.x, -24.0, 0.0001)
	assert_almost_eq(corner.z - half.y, -24.0, 0.0001)
	var far_corner := EdgeBand.clamp_focus(Vector3(300, 0, 300), half, 170, 120)
	assert_almost_eq(far_corner.x + half.x, 170.0 + 24.0, 0.0001)
	assert_almost_eq(far_corner.z + half.y, 120.0 + 24.0, 0.0001)
	var explicit := EdgeBand.clamp_focus(Vector3(-200, 0, -200), half, 170, 120, 12.0)
	assert_almost_eq(explicit.x - half.x, -12.0, 0.0001, "an explicit argument still wins")
	assert_eq(MapEdge.fog_reach(), 36.0)
	EdgeBand.view_band = 36.0
	assert_eq(MapEdge.fog_reach(), 48.0)
	EdgeBand.view_band = 12.0
	assert_eq(MapEdge.fog_reach(), 12.0)


func test_missing_far_models_are_skipped_without_a_placeholder() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var planned := {"far": [{"at": Vector3(-30, 0, 10), "yaw": 0.0, "scale": Vector3.ONE, "model": "res://models/props_field/missing_far_test.glb"}],
		"fields": [], "tracks": [], "sounds": []}
	var counts := EdgeBand._build_far(root, FieldGrid.new(2, 2), planned, StandardMaterial3D.new(), [Color.WHITE])
	assert_eq(int(counts["far"]), 0)
	assert_eq(root.get_node("Far").get_child_count(), 0, "a missing model adds no grey geometry")
