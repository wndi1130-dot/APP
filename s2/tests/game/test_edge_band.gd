extends "res://addons/gut/test.gd"

const EdgeBand = preload("res://game/world/edge_band.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const MapEdge = preload("res://fx/map_edge.gd")
const BuildPace = preload("res://game/world/build_pace.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const F = FieldGrid.Floor


func after_each() -> void:
	EdgeBand.view_band = EdgeBand.VIEW_BAND


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
	assert_eq(EdgeBand.FOREST_ROWS, StopGround.REMOTE_FOREST_EDGE)
	assert_eq(EdgeBand.FOREST_ROWS, 6)
	assert_eq(EdgeBand.INNER_ROW, 2.6)
	assert_eq(EdgeBand.YOUNG_TALL, Vector2(1.8, 3.4))
	assert_eq(EdgeBand.CANOPY_TALL, Vector2(4.6, 8.5))
	assert_eq(EdgeBand.CANOPY_RAMP, 5.0)
	assert_eq(EdgeBand.FAR_WOODS, 34.0)
	assert_eq(float(EdgeBand.PROFILES["dense"]["canopy"]), 2.2)
	assert_eq(float(EdgeBand.PROFILES["mixed"]["canopy"]), 2.8)
	assert_eq(float(EdgeBand.PROFILES["town"]["canopy"]), 3.6)
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
	# The clamp's own sums at a 12 m reach (the default reach, 24 m, is checked in
	# test_view_band_is_live_without_changing_woods_or_default_fog).
	EdgeBand.view_band = EdgeBand.BAND
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
	var counts: Dictionary = await EdgeBand.build(root, g, {"place_id": "test"}, StandardMaterial3D.new(), [Color.WHITE, Color.GRAY, Color.GRAY, Color.GRAY, Color.DIM_GRAY, Color.WHITE, Color.WHITE, Color.GRAY])
	var band := root.get_node("EdgeBand")
	assert_not_null(band)
	assert_not_null(band.get_node("Runs"), "the road and rail runs out of the map")
	var runs_box: AABB = (band.get_node("Runs") as MeshInstance3D).mesh.get_aabb()
	assert_lt(runs_box.position.x, -EdgeBand.FAR_REACH + 1.0, "the rail goes on past the camera's reach into the fog, west")
	assert_gt(runs_box.end.x, float(g.width) + EdgeBand.FAR_REACH - 1.0, "and east")
	assert_eq(int(counts["blocks"]), 1)
	var plan := EdgeBand.plan(g, EdgeBand.seed_of({"place_id": "test"}))
	assert_eq(int(counts["glades"]), plan["glades"].size())
	assert_eq(band.get_child_count(), 1 + int(counts["chunks"]) + 1 + int(counts["traces"]) + 1, "runs, tree pieces, the road's block, glade traces and one far root")
	assert_gt(int(counts["trees"]), 0)
	assert_gt(int(counts["chunks"]), 4, "the woods are cut in pieces so those off screen are not drawn")
	var far_root := band.get_node("Far")
	assert_eq(int(counts["far_pieces"]), far_root.get_child_count(), "every far piece counted, batches and ground")
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


func test_the_near_ring_gets_low_cover_in_loose_clumps() -> void:
	assert_eq(EdgeBand.FAR_NEAR, EdgeBand.BAND, "the far ground starts where the woods end")
	var g := FieldGrid.new(170, 120)
	var ring_banks := 0
	for seed in range(1, 11):
		var planned := EdgeBand.plan(g, seed)
		var by_side: Array = [[], [], [], []]
		for item: Dictionary in planned["far"]:
			if not EdgeBand.COVER_MODELS.has(String(item["model"])):
				continue
			var at := item["at"] as Vector3
			var depth := EdgeBand.outside(g, at.x, at.z)
			if depth < EdgeBand.VIEW_BAND:
				(by_side[int(item["side"])] as Array).append(depth)
		for side in 4:
			var depths := by_side[side] as Array
			assert_gt(depths.size(), 4, "every side's near ring has cover (seed %d side %d)" % [seed, side])
			if depths.size() > 1:
				assert_gt(float(depths.max()) - float(depths.min()), 4.0, "spread over the ring's depth, not a row")
		for plot: Dictionary in planned["fields"]:
			var r := plot["rect"] as Rect2
			if String(plot["kind"]) == "bank" and EdgeBand.outside(g, r.get_center().x, r.get_center().y) < EdgeBand.VIEW_BAND:
				ring_banks += 1
	assert_gt(ring_banks, 0, "now and then a short snow bank in the ring")


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
			EdgeBand.view_band = EdgeBand.VIEW_BAND
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
	var look := EdgeBand.look_of({})
	var profile: Dictionary = EdgeBand.PROFILES[look["profile"]]
	EdgeBand._scatter(g, rng, no_trees, trees, float(profile["edge"]), EdgeBand.TRUNK_GAP, EdgeBand.INNER_ROW, "edge", look)
	EdgeBand._scatter(g, rng, no_trees, trees, float(profile["canopy"]), EdgeBand.INNER_ROW, EdgeBand.BAND, "canopy", look)
	EdgeBand._scatter(g, rng, no_trees, trees, float(profile["under"]), EdgeBand.INNER_ROW, EdgeBand.BAND, "under", look)
	return {"trees": trees, "blocks": blocks, "glades": glades, "clear": clear, "runs": runs}


func test_view_band_is_live_without_changing_woods_or_default_fog() -> void:
	assert_eq(EdgeBand.VIEW_BAND, 24.0, "the camera looks 24 m past the edge (user 10-27)")
	assert_eq(EdgeBand.view_band, EdgeBand.VIEW_BAND)
	assert_eq(EdgeBand.BAND, 12.0)
	assert_eq(MapEdge.MARGIN, EdgeBand.FAR_REACH + 12.0)
	assert_eq(MapEdge.fog_reach(), 36.0, "the fog is whole 12 m past the camera's reach")
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
	assert_eq(MapEdge.fog_reach(), 24.0)


func test_missing_far_models_are_skipped_without_a_placeholder() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var planned := {"far": [{"at": Vector3(-30, 0, 10), "yaw": 0.0, "scale": Vector3.ONE, "model": "res://models/props_field/missing_far_test.glb"}],
		"fields": [], "tracks": [], "sounds": []}
	var counts: Dictionary = await EdgeBand._build_far(root, FieldGrid.new(2, 2), planned, StandardMaterial3D.new(), [Color.WHITE])
	assert_eq(int(counts["far"]), 0)
	assert_eq(root.get_node("Far").get_child_count(), 0, "a missing model adds no grey geometry")


## A town-sized map with the rails across it, the woods round it as `place_id`'s.
func _woods(place_id: String, seed: int, band: String = "") -> Dictionary:
	var g := FieldGrid.new(170, 120)
	for x in g.width:
		g.floor[g.index(Vector2i(x, 60))] = F.RAIL
	return {"g": g, "plan": EdgeBand.plan(g, seed, EdgeBand.look_of({"place_id": place_id, "region_band": band}))}


func test_forest_stops_grow_dense_spruce_woods_and_towns_thin_fruit_and_street_trees() -> void:
	assert_eq(EdgeBand.look_of({"place_id": "sawmill_03"})["profile"], "dense")
	assert_eq(EdgeBand.look_of({"place_id": "bare_line_01"})["profile"], "dense")
	assert_eq(EdgeBand.look_of({"place_id": "lodge_02"})["profile"], "dense")
	assert_eq(EdgeBand.look_of({"place_id": "houses_01"})["profile"], "town")
	assert_eq(EdgeBand.look_of({"place_id": "freight_02"})["profile"], "mixed")
	assert_eq(EdgeBand.look_of({"place_id": "test"})["profile"], "mixed", "a place with no group")
	var counts := {}
	for place: String in ["sawmill_01", "freight_01", "houses_01"]:
		var w := _woods(place, 5)
		var g: FieldGrid = w["g"]
		var tall := 0
		var spruce := 0
		var by_model := {}
		for t: Dictionary in w["plan"]["trees"]:
			var at: Vector3 = t["at"]
			var model := String(t["model"])
			by_model[model] = int(by_model.get(model, 0)) + 1
			if t.has("height"):
				tall += 1
				spruce += 1 if model == EdgeBand.SPRUCE else 0
				if EdgeBand.outside(g, at.x, at.z) < EdgeBand.INNER_ROW:
					assert_lte(float(t["height"]), EdgeBand.YOUNG_TALL.y, "the first rows stay low (%s)" % place)
					assert_eq(model, EdgeBand.SPRUCE, "only young spruce among the first rows' trees")
			else:
				assert_true(t.has("scale"), "what grows low has a scale")
		counts[place] = (w["plan"]["trees"] as Array).size()
		if place == "houses_01":
			assert_gt(int(by_model.get(EdgeBand.ORCHARD, 0)), 0, "fruit trees round a town")
			assert_gt(int(by_model.get(EdgeBand.STREET, 0)), 0, "street trees round a town")
			assert_lt(float(spruce) / float(tall), 0.5)
		else:
			assert_gt(float(spruce) / float(tall), 0.6, "spruce is the woods' body (%s)" % place)
			assert_gt(int(by_model.get(EdgeBand.BROADLEAF, 0)), 0, "with leafless broadleaf mixed in")
			assert_gt(int(by_model.get(EdgeBand.THICKET, 0)), 0, "and thicket under them")
	assert_gt(int(counts["sawmill_01"]), int(counts["freight_01"]) * 1.3, "forest stops thicker than the rail works")
	assert_gt(int(counts["freight_01"]), int(counts["houses_01"]) * 1.5, "the rail works thicker than a town")


func test_deep_spruce_crowns_meet_and_the_woods_go_on_past_the_band() -> void:
	var w := _woods("lodge_01", 9)
	var g: FieldGrid = w["g"]
	# The crowns need the model's own width; the rest is the plan's and runs without it.
	var mesh := EdgeBand._model_mesh(EdgeBand.SPRUCE)
	if mesh != null:
		var across := mesh.get_aabb().size.x / mesh.get_aabb().size.y
		var deep := 0
		var narrow := 0
		for t: Dictionary in w["plan"]["trees"]:
			var at: Vector3 = t["at"]
			if String(t["model"]) == EdgeBand.SPRUCE and EdgeBand.outside(g, at.x, at.z) > EdgeBand.INNER_ROW + EdgeBand.CANOPY_RAMP:
				deep += 1
				if float(t["height"]) * float(t["spread"]) * across <= float(EdgeBand.PROFILES["dense"]["canopy"]):
					narrow += 1
		assert_gt(deep, 200)
		assert_eq(narrow, 0, "deep crowns are wider than the gap between trunks")
	# Out to FAR_WOODS the woods go on; the few groves further out are as before.
	var woods := 0
	for item: Dictionary in w["plan"]["far"]:
		var at := item["at"] as Vector3
		if item.has("height") and EdgeBand.outside(g, at.x, at.z) < EdgeBand.FAR_WOODS:
			woods += 1
	assert_gt(woods, 300, "a forest stop's woods go on into the far ground")
	var town := _woods("houses_01", 9)
	for item: Dictionary in town["plan"]["far"]:
		assert_false(item.has("height"), "a town's far ground keeps its groves, fields and houses")


func test_the_region_band_sets_the_share_of_spruce_never_below_the_body() -> void:
	var sandy := EdgeBand.look_of({"place_id": "sawmill_01", "region_band": "K4"})
	assert_almost_eq(float(sandy["conifer"]), 0.95 / (0.95 + 0.12), 0.0001, "the pine sand plain is near all conifer")
	var flood := EdgeBand.look_of({"place_id": "sawmill_01", "region_band": "K6"})
	assert_eq(float(flood["conifer"]), float(EdgeBand.PROFILES["dense"]["conifer"]), "a broadleaf band still gets spruce first")
	assert_eq(float(EdgeBand.look_of({"place_id": "houses_01", "region_band": "K4"})["conifer"]), float(EdgeBand.PROFILES["town"]["conifer"]))
	var thin := _woods("sawmill_01", 4, "K7")
	var thick := _woods("sawmill_01", 4, "K10")
	assert_gt((thick["plan"]["far"] as Array).size(), (thin["plan"]["far"] as Array).size(), "a forested band has more woods out far")
	var pine := _woods("sawmill_01", 4, "K4")["plan"]["trees"] as Array
	var mixed := _woods("sawmill_01", 4, "K6")["plan"]["trees"] as Array
	assert_eq(pine.size(), mixed.size(), "the band stands where it did; only what grows there follows the band")
	assert_eq((pine[0] as Dictionary)["at"], (mixed[0] as Dictionary)["at"])


func test_the_plan_made_ahead_is_used_while_it_fits() -> void:
	var g := _grid()
	var data := {"place_id": "sawmill_01", "grid": g}
	var ahead := EdgeBand.plan_ahead(data)
	assert_eq(ahead["plan"], EdgeBand.plan(g, EdgeBand.seed_of(data), EdgeBand.look_of(data)), "the same plan the main thread would make")
	var colors := [Color.WHITE, Color.GRAY, Color.GRAY, Color.GRAY, Color.DIM_GRAY, Color.WHITE, Color.WHITE, Color.GRAY]
	var built := {}
	for way: String in ["fresh", "ahead", "other_band", "other_forest"]:
		var d := data.duplicate()
		if way != "fresh":
			d["_edge_plan"] = ahead
		if way == "other_band":
			d["region_band"] = "K4"
		if way == "other_forest":
			d["deep_forest"] = [Rect2i(0, 0, g.width, 16)]
		var root := Node3D.new()
		add_child_autofree(root)
		var counts: Dictionary = await EdgeBand.build(root, g, d, StandardMaterial3D.new(), colors)
		assert_false(d.has("_edge_plan"), "read once, not kept with the map (%s)" % way)
		assert_eq(bool(counts["planned_ahead"]), way == "ahead", way)
		counts.erase("planned_ahead")
		counts["children"] = root.get_node("EdgeBand").get_child_count()
		built[way] = counts
	assert_eq(built["ahead"], built["fresh"], "the band built from the plan made ahead is the band built here")
	assert_ne(built["other_band"]["far"], 0)


func test_rails_run_out_where_the_map_draws_them_even_under_a_car() -> void:
	var g := _grid()
	g.set_solid(Vector2i(0, 20), FieldGrid.Solid.BLOCK)
	g.set_solid(Vector2i(g.width - 1, 20), FieldGrid.Solid.BLOCK)
	var rails := EdgeBand.openings(g).filter(func(r): return int(r["floor"]) == F.RAIL)
	assert_eq(rails.size(), 2, "west and east, though their last cells cannot be walked")
	for run: Dictionary in rails:
		assert_eq([int(run["from"]), int(run["to"])], [20, 20], "the whole rail, as track_view.gd draws it in the map")


## A staged build rests between pieces; when the map it builds for is torn down while it
## rests (the stop left), it stops there: nothing is made after, nothing left without a parent.
func test_a_band_whose_map_is_torn_down_while_it_rests_makes_nothing_more() -> void:
	var g := _grid()
	var parent := Node3D.new()
	add_child(parent)
	var pace := BuildPace.new(get_tree(), true)
	pace.budget_usec = 0
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var done := [false]
	var run := func() -> void:
		await EdgeBand.build(parent, g, {"place_id": "test"}, StandardMaterial3D.new(), [Color.WHITE, Color.GRAY, Color.GRAY, Color.GRAY, Color.DIM_GRAY, Color.WHITE, Color.WHITE, Color.GRAY], pace)
		done[0] = true
	run.call()
	assert_false(done[0], "the build rests before its woods")
	parent.free()
	for i in 30:
		await get_tree().process_frame
	assert_true(done[0], "the build ended instead of building on a freed root")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "no piece left without a parent")


func test_empty_forest_keeps_the_original_plan_bytes() -> void:
	for g: FieldGrid in [_grid(), FieldGrid.new(170, 120)]:
		for seed: int in [7, 11, 93]:
			for place: String in ["sawmill_01", "freight_01", "houses_01"]:
				var look := EdgeBand.look_of({"place_id": place})
				var original := EdgeBand.plan(g, seed, look)
				var explicit_empty := EdgeBand.plan(g, seed, look, [])
				assert_eq(explicit_empty, original)
				assert_eq(var_to_bytes(explicit_empty), var_to_bytes(original), "empty forest adds no entries, flags or draws")


func test_deep_forest_depth_counts_only_open_sides() -> void:
	var g := FieldGrid.new(60, 64)
	var forest: Array = [Rect2i(0, 0, 60, 50)]
	assert_almost_eq(EdgeBand.woods_depth(g, forest, 30.0, 44.0), 0.0, 0.001, "six metres from the open south side")
	assert_almost_eq(EdgeBand.woods_depth(g, forest, 30.0, 43.0), 1.0, 0.001)
	assert_almost_eq(EdgeBand.woods_depth(g, forest, 0.0, 20.0), 24.0, 0.001, "the west map edge is closed")
	assert_lte(EdgeBand.woods_depth(g, forest, 30.0, 55.0), 0.0, "walkable ground has no woods depth")
	var joined: Array = [Rect2i(0, 0, 30, 50), Rect2i(30, 0, 30, 50)]
	assert_almost_eq(EdgeBand.woods_depth(g, joined, 29.0, 20.0), 24.0, 0.001, "another forest closes the shared side")
	var partial: Array = [Rect2i(0, 0, 30, 50), Rect2i(30, 0, 30, 25)]
	assert_gt(EdgeBand.woods_depth(g, partial, 29.0, 10.0), 8.0, "a partially shared side opens only beyond the neighbour")
	assert_gt(EdgeBand.woods_depth(g, [Rect2i(0, 0, 60, 64)], 30.0, 30.0), EdgeBand.FAR_WOODS, "a sealed forest has no near edge")


func test_deep_forest_leaves_the_map_rows_and_walkable_cells_clear() -> void:
	var g := FieldGrid.new(60, 64)
	var rect := Rect2i(0, 0, 60, 50)
	var forest: Array = [rect]
	var p := EdgeBand.plan(g, 17, EdgeBand.look_of({}), forest)
	var inside: int = 0
	for tree: Dictionary in p["trees"]:
		if bool(tree.get("skip", false)):
			continue
		var at: Vector3 = tree["at"]
		var c := Vector2i(floori(at.x), floori(at.z))
		if g.inside(c):
			inside += 1
			assert_true(rect.has_point(c), "no band tree on the map's walkable ground")
			assert_gt(float(rect.end.y) - at.z, float(EdgeBand.FOREST_ROWS), "the map's first six metres keep their own rows")
			assert_gt(EdgeBand.woods_depth(g, forest, at.x, at.z), 0.0)
	assert_gt(inside, 100, "the blocked forest beyond the map rows is planted")


func test_deep_forest_canopy_reaches_the_fog_without_far_woods_glades() -> void:
	var g := FieldGrid.new(60, 64)
	var forest: Array = [Rect2i(0, 0, 60, 50)]
	var p := EdgeBand.plan(g, 17, EdgeBand.look_of({}), forest)
	var deep: int = 0
	var furthest: float = 0.0
	for tree: Dictionary in p["trees"]:
		if bool(tree.get("skip", false)):
			continue
		var at: Vector3 = tree["at"]
		if not _starts_in_forest(g, forest, at):
			continue
		var d := EdgeBand.woods_depth(g, forest, at.x, at.z)
		assert_lt(d, EdgeBand.FAR_WOODS)
		if d >= EdgeBand.BAND:
			assert_true(tree.has("height"), "past BAND this layer is continuous canopy, without low clumps")
			if tree.has("height"):
				assert_between(float(tree["height"]), lerpf(EdgeBand.CANOPY_TALL.x, EdgeBand.CANOPY_TALL.y, 0.75), EdgeBand.CANOPY_TALL.y)
			if g.inside(Vector2i(floori(at.x), floori(at.z))):
				deep += 1
				furthest = maxf(furthest, d)
	assert_gt(deep, 30)
	assert_gt(furthest, EdgeBand.FAR_WOODS - 4.0, "canopy inside the map goes almost to the fog limit")
	for item: Dictionary in p["far"]:
		if _starts_in_forest(g, forest, item["at"]):
			assert_true(bool(item.get("skip", false)), "the old distant groves and houses cannot open a glade here")


func _starts_in_forest(g: FieldGrid, forest: Array, at: Vector3) -> bool:
	var c := Vector2i(clampi(floori(at.x), 0, g.width - 1), clampi(floori(at.z), 0, g.height - 1))
	return forest.any(func(rect: Rect2i) -> bool: return rect.has_point(c))


func test_forest_only_flags_legacy_items_and_appends_its_own_trees() -> void:
	var g := FieldGrid.new(170, 120)
	var forest: Array = [Rect2i(0, 0, 170, 46), Rect2i(0, 61, 21, 59)]
	var look := EdgeBand.look_of({})
	var legacy := EdgeBand.plan(g, 93, look)
	var p := EdgeBand.plan(g, 93, look, forest)
	assert_eq(p, EdgeBand.plan(g, 93, look, forest), "the separate forest draw repeats too")
	for key: String in ["trees", "glades", "far", "fields"]:
		var before: Array = legacy[key]
		var after: Array = p[key]
		if key != "trees":
			assert_eq(after.size(), before.size(), "legacy indices remain in " + key)
		else:
			assert_gt(after.size(), before.size(), "new forest is appended last")
		for i: int in before.size():
			var item: Dictionary = (after[i] as Dictionary).duplicate(true)
			var at: Vector3
			if item.has("at"):
				at = item["at"]
			else:
				var center: Vector2 = (item["rect"] as Rect2).get_center()
				at = Vector3(center.x, 0, center.y)
			assert_eq(bool(item.get("skip", false)), _starts_in_forest(g, forest, at), "only a forest starting cell hides an entry (%s %d)" % [key, i])
			item.erase("skip")
			assert_eq(var_to_bytes(item), var_to_bytes(before[i]), "all original entry bytes and indices stay put (%s %d)" % [key, i])
	for key: String in ["blocks", "clear", "runs", "tracks", "sounds"]:
		assert_eq(p[key], legacy[key], "unchanged " + key)
	var old_count: int = (legacy["trees"] as Array).size()
	for i: int in range(old_count, (p["trees"] as Array).size()):
		assert_true(_starts_in_forest(g, forest, p["trees"][i]["at"]), "appended trees belong only to deep forest")


func test_woods_depth_continues_outside_without_a_young_tree_seam() -> void:
	var g := FieldGrid.new(191, 151)
	var forest: Array = [Rect2i(0, 0, 191, 46), Rect2i(0, 61, 21, 90)]
	assert_almost_eq(EdgeBand.woods_depth(g, forest, 0.0, 100.0), 15.0, 0.001)
	assert_almost_eq(EdgeBand.woods_depth(g, forest, -0.01, 100.0), 15.01, 0.001)
	assert_almost_eq(EdgeBand.woods_depth(g, forest, -5.0, 100.0), 20.0, 0.001)
	assert_almost_eq(EdgeBand.woods_depth(g, forest, 100.0, -2.0), 42.0, 0.001)
	assert_almost_eq(EdgeBand.woods_depth(g, forest, -2.0, 55.0), EdgeBand.outside(g, -2.0, 55.0), 0.001, "outside a walking cell keeps its old depth")
	var p := EdgeBand.plan(g, 71, EdgeBand.look_of({}), forest)
	var west: int = 0
	for tree: Dictionary in p["trees"]:
		if bool(tree.get("skip", false)):
			continue
		var at: Vector3 = tree["at"]
		if _starts_in_forest(g, forest, at):
			assert_lt(EdgeBand.woods_depth(g, forest, at.x, at.z), EdgeBand.FAR_WOODS)
			assert_gte(at.z, 0.0, "north of the map even the starting depth is past FAR_WOODS")
		if at.x < 0.0 and at.z > 85.0 and at.z < 130.0:
			west += 1
			assert_true(tree.has("height"), "tall canopy rather than a new young edge at x=0")
			assert_gt(float(tree.get("height", 0.0)), EdgeBand.YOUNG_TALL.y)
	assert_gt(west, 20, "the west forest continues outside the map")


func test_deep_forest_shadow_uses_woods_depth_inside_the_map() -> void:
	var g := FieldGrid.new(60, 64)
	var forest: Array = [Rect2i(0, 0, 60, 50)]
	var data := {"grid": g, "place_id": "test", "deep_forest": forest}
	var seed := EdgeBand.seed_of(data)
	var look := EdgeBand.look_of(data)
	var p := EdgeBand.plan(g, seed, look, forest)
	var trees: Array = []
	for at: Vector3 in [Vector3(30, 0, 43.4), Vector3(30, 0, 40)]:
		var tree := EdgeBand._tree(EdgeBand.SPRUCE, 2.5)
		tree["at"] = at
		tree["yaw"] = 0.0
		trees.append(tree)
	var hidden: Dictionary = (trees[0] as Dictionary).duplicate()
	hidden["skip"] = true
	trees.append(hidden)
	p["trees"] = trees
	p["glades"] = [{"rect": Rect2(20, -8, 5, 5), "kind": "felled", "skip": true,
		"props": [{"at": Vector3(22, 0, -5), "yaw": 0.0, "model": EdgeBand.STUMPS_MODEL}]}]
	p["far"] = [{"at": Vector3(20, 0, -40), "yaw": 0.0, "scale": Vector3(6, 3, 5),
		"model": EdgeBand.FAR_HOUSE, "side": 2, "skip": true}]
	p["fields"] = [{"rect": Rect2(20, -30, 5, 1), "kind": "bank", "side": 2, "skip": true}]
	data["_edge_plan"] = {"key": EdgeBand.plan_key(g, seed, look, forest), "plan": p}
	var root := Node3D.new()
	add_child_autofree(root)
	var colors := [Color.WHITE, Color.GRAY, Color.GRAY, Color.GRAY, Color.DIM_GRAY, Color.WHITE, Color.WHITE, Color.GRAY]
	var counts: Dictionary = await EdgeBand.build(root, g, data, StandardMaterial3D.new(), colors)
	assert_true(bool(counts["planned_ahead"]))
	assert_eq(int(counts["trees"]), 2, "a skipped legacy tree is not drawn or counted")
	for key: String in ["glades", "traces", "houses", "fields"]:
		assert_eq(int(counts[key]), 0, "skipped " + key)
	var band := root.get_node("EdgeBand")
	var shaded: int = 0
	var unshaded: int = 0
	for node in band.get_children() + band.get_node("Far").get_children():
		if not node is GeometryInstance3D:
			continue
		var n: int = (node as MultiMeshInstance3D).multimesh.instance_count if node is MultiMeshInstance3D else 1
		if (node as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			unshaded += n
		else:
			shaded += n
	assert_eq(shaded, 1, "only depth 0.6 casts a shadow, even though both trees are inside")
	assert_eq(unshaded, 1, "depth 4 is batched without a shadow")


func test_forest_plan_key_copies_the_rectangles_and_plan_ahead_passes_them() -> void:
	var g := FieldGrid.new(60, 64)
	var forest: Array = [Rect2i(0, 0, 60, 50)]
	var data := {"grid": g, "place_id": "test", "deep_forest": forest}
	var seed := EdgeBand.seed_of(data)
	var look := EdgeBand.look_of(data)
	var ahead := EdgeBand.plan_ahead(data)
	assert_eq(ahead["plan"], EdgeBand.plan(g, seed, look, forest))
	assert_eq(ahead["key"], EdgeBand.plan_key(g, seed, look, forest))
	assert_ne(ahead["key"], EdgeBand.plan_key(g, seed, look, []))
	forest[0] = Rect2i(0, 0, 60, 45)
	assert_ne(ahead["key"], EdgeBand.plan_key(g, seed, look, forest), "editing the source list cannot mutate the saved key")


func test_fell_groves_ignore_skipped_and_inside_forest_trees() -> void:
	var g := FieldGrid.new(60, 64)
	var trees: Array = []
	for i: int in 8:
		for hidden: bool in [false, true]:
			var tree := EdgeBand._tree(EdgeBand.SPRUCE, 2.5)
			tree["at"] = Vector3(-0.5 if hidden else 0.5, 0, 12.0 + float(i) * 0.1)
			if hidden:
				tree["skip"] = true
			trees.append(tree)
	assert_eq(EdgeBand.fell_groves(g, {"trees": trees}, {"grid": g}), [], "neither hidden exterior entries nor new interior trees become work spots")
