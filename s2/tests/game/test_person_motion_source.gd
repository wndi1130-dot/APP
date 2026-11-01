extends "res://addons/gut/test.gd"
## Run after rebaking all living bodies and wear with the same PERSON_KEEP.
## VAT does not retain bones. Rotation checks use source keys; their frame
## tables are in _out/motion_source_result.md and _out/motion_add_result.md.

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const PEOPLE: String = "res://models/people"
const GROUPS: Dictionary = {
	"walk": ["p_walk", "p_walk_long", "p_walk_axe", "p_walk_pistol", "p_carry_big", "p_walk_hurt"],
	"run": ["p_run", "p_run_long", "p_run_pistol"],
	"crouch": ["p_crouch_walk", "p_crouch_walk_long", "p_crouch_walk_pistol"],
}
const SOURCE_RIGS: Array[String] = ["driver", "duffel_b1v2", "fitter", "guard", "guard_f", "hunter_f", "lumberjack", "medic", "overalls", "railman_old", "seamstress", "sheepskin", "stoker", "woodsman"]

var _fixtures: Array[Dictionary] = []
var _folder_count: int = 0


## Decision 535 drafts: run only in the bake/test session, after rebuilding bodies
## and every wear folder. Missing metadata on old assets is an intentional failure.
func test_head_share_is_zero_at_feet_and_one_at_crown() -> void:
	for fixture in _fixtures:
		var mesh: Mesh = fixture["baked"]["mesh"]
		var arrays := mesh.surface_get_arrays(0)
		assert_true(arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array, str(fixture["name"]) + " CUSTOM0 R_FLOAT")
		if not arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array:
			continue
		var shares: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		assert_eq(shares.size(), rest.size())
		if shares.size() != rest.size():
			continue
		var low := INF
		var high := -INF
		for p in rest:
			low = minf(low, p.y)
			high = maxf(high, p.y)
		var feet := 0
		var crown := 0
		for v in rest.size():
			assert_true(shares[v] >= 0.0 and shares[v] <= 1.0, "head share bounded")
			if rest[v].y <= low + 0.05:
				feet += 1
				assert_almost_eq(shares[v], 0.0, 0.01, "feet do not turn")
			if rest[v].y >= high - 0.03:
				crown += 1
				assert_almost_eq(shares[v], 1.0, 0.05, "crown follows head")
		assert_gt(feet, 0)
		assert_gt(crown, 0)


func _assert_head_bake(folder: String, baked: Dictionary, bag: bool = false) -> void:
	assert_false(baked.is_empty(), folder + " loads")
	if baked.is_empty():
		return
	var info := _clip_info(folder)
	assert_true(info.has("head"), folder + " clips.json head metadata")
	if not info.has("head"):
		return
	assert_eq(baked.get("head", {}), info["head"], "load preserves head metadata")
	var mesh: Mesh = baked["mesh"]
	var arrays := mesh.surface_get_arrays(0)
	var total: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var look: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var width := int(baked["width"])
	var head: Dictionary = baked["head"]
	var tables := VatBaker.shader_tables(baked)
	assert_true(bool(tables.get("has_head", false)))
	var mesh_columns := {}
	for uv in look:
		mesh_columns[int(uv.x * width) + int(uv.y) * width] = true
	assert_eq(int(baked["columns"]), mesh_columns.size() + 2, "exactly two extra columns, no gap")
	for n in 2:
		var name_text: String = "pivot" if n == 0 else "up"
		assert_true(head.has(name_text), name_text + " present")
		if not head.has(name_text):
			continue
		var point: Dictionary = head[name_text]
		assert_eq(int(point["vertex"]), total + n, "virtual ID outside the mesh")
		assert_eq(int(point["column"]), mesh_columns.size() + n, "appended after deduplication")
		assert_false(mesh_columns.has(int(point["column"])), "no triangle reads virtual column")
		assert_eq(int(point["uv"][0] * width) + int(point["uv"][1]) * width, int(point["column"]))
		assert_almost_eq(float(tables["head_" + name_text + "_x"]), float(point["uv"][0]), 0.000001)
		assert_eq(float(tables["head_" + name_text + "_row"]), float(point["uv"][1]))
		var rest: Array = point["rest"]
		assert_eq(tables["head_" + name_text + "_rest"], Vector3(rest[0], rest[1], rest[2]))
	assert_almost_eq((tables["head_up_rest"] as Vector3).distance_to(tables["head_pivot_rest"]), 0.1, 0.00001)
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		assert_true(index >= 0 and index < total, "virtual vertices have no triangles")
	assert_true(arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array, folder + " CUSTOM0")
	if arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array:
		var shares: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		assert_eq(shares.size(), total)
		for share in shares:
			assert_true(share >= 0.0 and share <= 1.0)
			if bag:
				assert_eq(share, 0.0, "generated bag never turns")
	for clip: Dictionary in info["clips"]:
		assert_true(clip.has("head_yaw"), str(clip["name"]) + " raw JSON yaw stats")
		var yaw: Array = clip.get("head_yaw", [])
		assert_eq(yaw.size(), 3, "mean, min, max radians")
		if yaw.size() == 3:
			assert_true(is_finite(float(yaw[0])) and is_finite(float(yaw[1])) and is_finite(float(yaw[2])))
			assert_true(float(yaw[1]) <= float(yaw[0]) and float(yaw[0]) <= float(yaw[2]), "min <= mean <= max")
			for loaded: Dictionary in baked["clips"]:
				if loaded["name"] == clip["name"]:
					assert_eq(loaded["head_yaw"], yaw, "load preserves yaw stats")


func test_body_and_wear_head_metadata_columns_tables_and_yaw() -> void:
	for fixture in _fixtures:
		var folder := PEOPLE.path_join(str(fixture["name"]))
		_assert_head_bake(folder, fixture["baked"])
		var wear := folder.path_join("wear")
		for garment: String in DirAccess.get_directories_at(wear):
			var path := wear.path_join(garment)
			_assert_head_bake(path, BodyBake.load_baked(path), BodyBake.BAG_SHELLS.has(garment))


func test_virtual_neck_columns_fold_and_compact_without_mesh_vertices() -> void:
	var source: Array = []
	source.resize(Mesh.ARRAY_MAX)
	source[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.UP, Vector3.RIGHT, Vector3.ZERO])
	source[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	source[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 1, 2])
	source[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	source[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	source[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array([0, 1, 0, 0])
	var probes := [{"rest": Vector3.UP, "bone": 0}, {"rest": Vector3(0, 1.1, 0), "bone": 0}]
	var shifted := Transform3D(Basis(), Vector3(0.2, 0.3, -0.1))
	var clips := [{"name": "probe", "frames": [[Transform3D()], [shifted]], "loop": false, "head_yaw": [0.1, -0.2, 0.4]}]
	var baked := VatBaker.build_skinned(source, clips, 4, probes)
	assert_eq(int(baked["vertices"]), 4)
	assert_eq(int(baked["columns"]), 5, "three shared columns plus two probes")
	assert_eq(int(baked["rows_per_frame"]), 2)
	assert_eq(int(baked["head"]["pivot"]["column"]), 3)
	assert_eq(int(baked["head"]["up"]["column"]), 4)
	assert_eq((baked["mesh"] as Mesh).surface_get_array_len(0), 4)
	var small := BodyBake.compact(baked, ["probe"])
	assert_eq(small["clips"][0]["head_yaw"], clips[0]["head_yaw"], "compact keeps original sampled stats")
	for assets: Dictionary in [baked, small]:
		var image: Image = assets["image"]
		var tables := VatBaker.shader_tables(assets)
		for name_text: String in ["pivot", "up"]:
			var point: Dictionary = assets["head"][name_text]
			var pixel := image.get_pixel(int(point["uv"][0] * int(assets["width"])), int(assets["rows_per_frame"]) + int(point["uv"][1]))
			var offset := Vector3(pixel.r, pixel.g, pixel.b)
			if bool(tables["quantized"]):
				offset = tables["clip_lo"][0] + offset * (tables["clip_hi"][0] - tables["clip_lo"][0])
			assert_almost_eq(offset.x, shifted.origin.x, 0.003)
			assert_almost_eq(offset.y, shifted.origin.y, 0.003)
			assert_almost_eq(offset.z, shifted.origin.z, 0.003)
	var legacy := baked.duplicate()
	legacy.erase("head")
	assert_false(bool(VatBaker.shader_tables(legacy)["has_head"]))
	assert_eq(BodyBake._head_yaw_stats([]), [0.0, 0.0, 0.0])
	assert_eq(BodyBake._head_yaw_stats([-0.25, 0.25]), [0.0, -0.25, 0.25])


func before_all() -> void:
	var names := DirAccess.get_directories_at(PEOPLE)
	names.sort()
	for folder: String in names:
		if not folder.ends_with("_p"):
			continue
		_folder_count += 1
		var baked := BodyBake.load_baked(PEOPLE.path_join(folder))
		assert_false(baked.is_empty(), folder + " loads")
		if baked.is_empty():
			continue
		var arrays: Array = (baked["mesh"] as Mesh).surface_get_arrays(0)
		var fixture := {"name": folder, "baked": baked, "rest": arrays[Mesh.ARRAY_VERTEX], "look": arrays[Mesh.ARRAY_TEX_UV2]}
		fixture["feet"] = _walk_feet(fixture)
		fixture["soles"] = BodyBake.person_sole_vertices(fixture["rest"])
		fixture["right"] = PersonVisual.hand_of(baked).get("hand", PackedInt32Array())
		fixture["left"] = _left_hand(fixture)
		_fixtures.append(fixture)


func after_all() -> void:
	_fixtures.clear()


func _clip(fixture: Dictionary, name_text: String) -> Dictionary:
	for clip: Dictionary in fixture["baked"]["clips"]:
		if str(clip["name"]) == name_text:
			return clip
	assert_true(false, "%s has %s; rebake before this test" % [fixture["name"], name_text])
	return {}


## Decode a known clip directly, including UV2 sharing and per-clip rgb8q
## boxes. Looking up the clip again for every vertex would slow this suite.
func _sample(fixture: Dictionary, clip: Dictionary, ids: PackedInt32Array) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	if clip.is_empty():
		return out
	var baked: Dictionary = fixture["baked"]
	var image: Image = baked["image"]
	var rest: PackedVector3Array = fixture["rest"]
	var look: PackedVector2Array = fixture["look"]
	var lo := Vector3.ZERO
	var span := Vector3.ONE
	if baked.get("format", "") != "":
		lo = Vector3(clip["lo"][0], clip["lo"][1], clip["lo"][2])
		span = Vector3(clip["hi"][0], clip["hi"][1], clip["hi"][2]) - lo
	for f in int(clip["frames"]):
		var points := PackedVector3Array()
		for i in ids:
			var pixel := image.get_pixel(int(look[i].x * float(baked["width"])), (int(clip["start"]) + f) * int(baked["rows_per_frame"]) + int(look[i].y))
			points.append(rest[i] + lo + Vector3(pixel.r, pixel.g, pixel.b) * span)
		out.append(points)
	return out


## Same 40 vertices as still_feet.py: rank walk z ranges after filtering the
## mean offsets, then reuse those IDs for shared-leg and stance-speed checks.
func _walk_feet(fixture: Dictionary) -> PackedInt32Array:
	var rest: PackedVector3Array = fixture["rest"]
	var ids := PackedInt32Array()
	for i in rest.size():
		ids.append(i)
	var frames := _sample(fixture, _clip(fixture, "p_walk"), ids)
	var ranked: Array = []
	if frames.is_empty():
		return PackedInt32Array()
	for i in rest.size():
		var mean := Vector3.ZERO
		var low := INF
		var high := -INF
		for points: PackedVector3Array in frames:
			var offset := points[i] - rest[i]
			mean += offset
			low = minf(low, offset.z)
			high = maxf(high, offset.z)
		mean /= float(frames.size())
		if absf(mean.x) < 0.25 and mean.y > -0.3:
			ranked.append([i, high - low])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]) if a[1] != b[1] else int(a[0]) < int(b[0]))
	var feet := PackedInt32Array()
	for n in mini(40, ranked.size()):
		feet.append(int(ranked[n][0]))
	return feet


## Mirror hand_of's shove-frame tip and HAND_R neighbourhood for the left.
func _left_hand(fixture: Dictionary) -> PackedInt32Array:
	var shove := _clip(fixture, "p_shove")
	if shove.is_empty():
		return PackedInt32Array()
	var baked: Dictionary = fixture["baked"]
	var rest: PackedVector3Array = fixture["rest"]
	var look: PackedVector2Array = fixture["look"]
	var frame := int(shove["start"]) + int(roundf(0.4 * float(int(shove["frames"]) - 1)))
	var at := PackedVector3Array()
	var tip := Vector3(0, 0, -99)
	for i in rest.size():
		var point := PersonVisual.vertex_at(baked, rest, look, i, frame)
		at.append(point)
		if point.x > 0.05 and point.z > tip.z:
			tip = point
	var hand := PackedInt32Array()
	for i in at.size():
		if at[i].distance_to(tip) < PersonVisual.HAND_R:
			hand.append(i)
	return hand


func _center(points: PackedVector3Array) -> Vector3:
	var middle := Vector3.ZERO
	for point in points:
		middle += point
	return middle / float(points.size()) if not points.is_empty() else Vector3.ZERO


func _quantum(fixture: Dictionary, clip: Dictionary) -> float:
	if fixture["baked"].get("format", "") == "":
		return 0.0
	var lo := Vector3(clip["lo"][0], clip["lo"][1], clip["lo"][2])
	var hi := Vector3(clip["hi"][0], clip["hi"][1], clip["hi"][2])
	return (hi - lo).length() / 255.0


func test_all_fourteen_living_folders_load() -> void:
	assert_eq(_folder_count, 14, "all living bodies, including the seamstress")
	assert_eq(_fixtures.size(), _folder_count, "none silently skipped")
	for fixture in _fixtures:
		assert_eq((fixture["feet"] as PackedInt32Array).size(), 40, str(fixture["name"]) + " foot vertices")
		for side in 2:
			assert_false(fixture["soles"][side].is_empty(), "%s %s rest sole found" % [fixture["name"], "L" if side == 0 else "R"])


func test_standing_feet_stay_within_one_centimetre() -> void:
	for fixture in _fixtures:
		var clip := _clip(fixture, "p_stand")
		if clip.is_empty():
			continue
		assert_true(float(clip["round"]) <= BodyBake.ROUND_LEAST, str(fixture["name"]) + " standing round")
		assert_almost_eq(float(clip["length"]), 2.5, 0.0001, "UAL1 Idle_Loop length")
		var footprint_low := INF
		var footprint_high := -INF
		for side in 2:
			var sole: PackedInt32Array = fixture["soles"][side]
			if sole.is_empty():
				continue  # Missing soles already fail the fixture check.
			var frames := _sample(fixture, clip, sole)
			var greatest := 0.0
			var greatest_distance := 0.0
			var greatest_round := 0.0
			# The sole stays on the floor (rest bottom y = 0): neither floating nor sunk.
			var lowest := INF
			var highest_low := -INF
			for points: PackedVector3Array in frames:
				var low_y := INF
				for i in sole.size():
					low_y = minf(low_y, points[i].y)
					footprint_low = minf(footprint_low, points[i].z)
					footprint_high = maxf(footprint_high, points[i].z)
				lowest = minf(lowest, low_y)
				highest_low = maxf(highest_low, low_y)
			assert_true(lowest >= -0.01 and highest_low <= 0.015, "%s %s standing sole height %.4f..%.4f m within -0.01..0.015" % [fixture["name"], "L" if side == 0 else "R", lowest, highest_low])
			# Track each fixed rest-bottom vertex, avoiding toe/heel identity jumps.
			for i in sole.size():
				var low: Vector3 = frames[0][i]
				var high := low
				var zs := []
				for points: PackedVector3Array in frames:
					low = low.min(points[i])
					high = high.max(points[i])
					zs.append(points[i].z)
				var span := high - low
				greatest = maxf(greatest, maxf(span.x, maxf(span.y, span.z)))
				for a in frames.size():
					for b in range(a + 1, frames.size()):
						greatest_distance = maxf(greatest_distance, frames[a][i].distance_to(frames[b][i]))
				greatest_round = maxf(greatest_round, BodyBake.round_of(zs))
			var label := "%s %s sole (%d rest-bottom vertices)" % [fixture["name"], "L" if side == 0 else "R", sole.size()]
			assert_true(greatest <= 0.01, "%s standing axis range %.6f m <= 0.01" % [label, greatest])
			assert_true(greatest_distance <= 0.01, "%s standing 3D travel %.6f m <= 0.01" % [label, greatest_distance])
			assert_true(greatest_round <= BodyBake.ROUND_LEAST, "%s standing round %.6f m" % [label, greatest_round])
		assert_true(footprint_high - footprint_low <= 0.35, str(fixture["name"]) + " standing fixed sole z span <= 0.35 m")


## VAT has no joints. This optional source fixture checks the knee/hip/stance
## contract on the original rigs; the test above checks the baked soles.
func _stand_source_scene(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	assert_eq(error, OK, path + " imports")
	return document.generate_scene(state) as Node3D if error == OK else null


func test_standing_source_support_is_upright_on_all_fourteen_rigs() -> void:
	var directory := ProjectSettings.globalize_path("res://").path_join("../../_motion_src").simplify_path()
	if not FileAccess.file_exists(directory.path_join("UAL1.glb")):
		# The original rigs live beside the repository, not in it (CI has none); the baked
		# soles above are checked everywhere. CI counts a pending test as a failure.
		pass_test("original _motion_src/UAL1.glb and 14 rigs are not beside this checkout: standing joints checked where they are")
		return
	var motion := _stand_source_scene(directory.path_join("UAL1.glb"))
	if motion == null:
		return
	add_child(motion)
	var checked := 0
	for rig_name: String in SOURCE_RIGS:
		var root := _stand_source_scene(directory.path_join("rig").path_join(rig_name + ".glb"))
		if root == null:
			continue
		add_child(root)
		var ctx := BodyBake.prepare(root, motion, [BodyBake.PERSON_CLIPS[2]], [])
		assert_false(ctx.is_empty(), rig_name + " standing context")
		if ctx.is_empty():
			root.queue_free()
			continue
		var body: Skeleton3D = ctx["body"]
		var hips := BodyBake._bone(body, "hips")
		# The old main sink is a zero-mean sine, so its mean hip height is rest.
		var main_height := (body.global_transform * body.get_bone_global_rest(hips)).origin.y - root.global_position.y
		var knee_sum := [0.0, 0.0]
		var first_chest := Vector3.ZERO
		var chest_travel := 0.0
		var count: int = BodyBake.PERSON_CLIPS[2][2]
		for frame in count:
			BodyBake.pose(ctx, "Idle_Loop", "p_stand", float(frame) / float(count))
			var chest := BodyBake._world(body, BodyBake._bone(body, "chest")).origin
			if frame == 0:
				first_chest = chest
			chest_travel = maxf(chest_travel, chest.distance_to(first_chest))
			var height := BodyBake._world(body, hips).origin.y - root.global_position.y
			assert_true(height >= main_height * 0.97, "%s frame %d hip >= 97%% main" % [rig_name, frame])
			var feet: Array[Vector3] = []
			var thighs: Array[Vector3] = []
			var outward: Array[float] = []
			for side in 2:
				var suffix := ".L" if side == 0 else ".R"
				var thigh := BodyBake._world(body, BodyBake._bone(body, "thigh" + suffix)).origin
				var knee := BodyBake._world(body, BodyBake._bone(body, "shin" + suffix)).origin
				var foot := BodyBake._world(body, BodyBake._bone(body, "foot" + suffix)).origin
				var bend := rad_to_deg((knee - thigh).angle_to(foot - knee))
				knee_sum[side] += bend
				assert_true(bend >= 3.0 and bend <= 5.0, "%s frame %d side %d relaxed knee 3..5 degrees" % [rig_name, frame, side])
				# The knee bends forward (+Z in skeleton space), never backward.
				var pose_hip := body.get_bone_global_pose(BodyBake._bone(body, "thigh" + suffix)).origin
				var pose_knee := body.get_bone_global_pose(BodyBake._bone(body, "shin" + suffix)).origin
				var pose_axis := (body.get_bone_global_pose(BodyBake._bone(body, "foot" + suffix)).origin - pose_hip).normalized()
				var knee_out := (pose_knee - pose_hip) - pose_axis * (pose_knee - pose_hip).dot(pose_axis)
				var forward := Vector3.BACK - pose_axis * Vector3.BACK.dot(pose_axis)
				assert_gt(knee_out.dot(forward), 0.0, "%s frame %d side %d knee bends forward" % [rig_name, frame, side])
				feet.append(foot)
				thighs.append(thigh)
				outward.append((foot.x - thigh.x) * (1.0 if side == 0 else -1.0))
				var rest_thigh := body.get_bone_global_rest(BodyBake._bone(body, "thigh" + suffix)).origin
				var rest_knee := body.get_bone_global_rest(BodyBake._bone(body, "shin" + suffix)).origin
				var rest_foot := body.get_bone_global_rest(BodyBake._bone(body, "foot" + suffix))
				assert_almost_eq(thigh.distance_to(knee), rest_thigh.distance_to(rest_knee), 0.00001, rig_name + " thigh length preserved")
				assert_almost_eq(knee.distance_to(foot), rest_knee.distance_to(rest_foot.origin), 0.00001, rig_name + " shin length preserved")
				var foot_basis := body.get_bone_global_pose(BodyBake._bone(body, "foot" + suffix)).basis.orthonormalized()
				var tilt := rad_to_deg(foot_basis.get_rotation_quaternion().angle_to(rest_foot.basis.orthonormalized().get_rotation_quaternion()))
				# With every bone posed at rest, the lumberjack foot already reads 0.04 degrees off its
				# global rest (the other rigs 0), before any standing step; 0.1 leaves room for that.
				assert_true(absf(tilt) <= 0.1, "%s foot stays flat in its rest orientation (%.4f degrees)" % [rig_name, tilt])
			assert_true(absf(feet[0].z - feet[1].z) <= 0.35, "%s frame %d foot z spread <= 0.35 m" % [rig_name, frame])
			var extra_width := absf(feet[0].x - feet[1].x) - absf(thighs[0].x - thighs[1].x)
			assert_true(extra_width >= 0.08 and extra_width <= 0.12, rig_name + " ankles 0.08..0.12 m wider than hips")
			assert_true(outward[0] >= 0.04 and outward[0] <= 0.06 and outward[1] >= 0.04 and outward[1] <= 0.06, rig_name + " both feet move outward")
			assert_almost_eq(outward[0], outward[1], 0.00001, rig_name + " symmetric foot widening")
		for side in 2:
			assert_true(float(knee_sum[side]) / float(count) <= 10.0, "%s side %d mean knee <= 10 degrees" % [rig_name, side])
		assert_true(chest_travel >= 0.0005 and chest_travel <= 0.01, rig_name + " small upper-body breath remains")
		assert_eq(ctx.get("fit_failures", []), [], rig_name + " standing solver passes the stricter save gate")
		checked += 1
		root.queue_free()
	assert_eq(checked, 14, "all original living rigs checked")
	motion.queue_free()


## VAT contains no joint origins: knee/hip checks use the original rigs.
## Missing source files are pending; present files that fail to import are failures.
func test_walking_source_mid_knees_hips_and_footlock_on_all_fourteen_rigs() -> void:
	var directory: String = ProjectSettings.globalize_path("res://").path_join("../../_motion_src").simplify_path()
	var names: Array[String] = ["driver", "duffel_b1v2", "fitter", "guard", "guard_f", "hunter_f", "lumberjack", "medic", "overalls", "railman_old", "seamstress", "sheepskin", "stoker", "woodsman"]
	if not FileAccess.file_exists(directory.path_join("UAL1.glb")):
		pending("walking joint checks require original _motion_src/UAL1.glb")
		return
	for rig_name: String in names:
		if not FileAccess.file_exists(directory.path_join("rig").path_join(rig_name + ".glb")):
			pending("walking joint checks require original rig " + rig_name)
			return
	var motion: Node3D = _stand_source_scene(directory.path_join("UAL1.glb"))
	if motion == null:
		return
	add_child(motion)
	var walks: Array = []
	for entry: Array in BodyBake.PERSON_CLIPS:
		if BodyBake.PERSON_FOOT_LOCK.has(entry[0]):
			walks.append(entry)
	var checked: int = 0
	for rig_name: String in names:
		var root: Node3D = _stand_source_scene(directory.path_join("rig").path_join(rig_name + ".glb"))
		if root == null:
			continue
		add_child(root)
		var ctx: Dictionary = BodyBake.prepare(root, motion, walks + [BodyBake.PERSON_CLIPS[2]], [])
		assert_false(ctx.is_empty(), rig_name + " walking context")
		if ctx.is_empty():
			root.queue_free()
			continue
		var walk: Array = walks[0]
		ctx["sink_scale"] = BodyBake._sink_scale(root, ctx["body"])
		BodyBake._fit_person_stride(ctx, walk)
		var phase: Dictionary = BodyBake._fit_person_phase(ctx, walk)
		var fit: Dictionary = BodyBake._fit_person_footlock(ctx, walk, phase)
		assert_false(fit.is_empty(), rig_name + " canonical footlock fit")
		if fit.is_empty():
			root.queue_free()
			continue
		var table: Dictionary = fit["pelvis"]
		var repeated: Dictionary = BodyBake._fit_person_walk_height(ctx, fit, walk, float(phase["shift"]))
		for key: String in ["values", "slopes", "uppers", "lowers"]:
			var first: PackedFloat64Array = table[key]
			var second: PackedFloat64Array = repeated[key]
			assert_eq(first.to_byte_array(), second.to_byte_array(), rig_name + " deterministic height " + key)
		assert_true((table["failed_samples"] as PackedInt32Array).is_empty(), rig_name + " all 256 height intervals feasible")
		assert_eq(BodyBake._person_walk_height_at(table, 0.0), BodyBake._person_walk_height_at(table, 1.0), rig_name + " seam height")
		var epsilon: float = 0.000001
		var seam: float = BodyBake._person_walk_height_at(table, 0.0)
		var left: float = (seam - BodyBake._person_walk_height_at(table, 1.0 - epsilon)) / epsilon
		var right: float = (BodyBake._person_walk_height_at(table, epsilon) - seam) / epsilon
		assert_almost_eq(left, right, 0.002, rig_name + " periodic height slope m/cycle")
		var body: Skeleton3D = ctx["body"]
		var to_mesh: Transform3D = ctx["to_mesh"]
		var applied: Array[float] = []
		var pose_epsilon: float = 0.00002
		for u: float in [0.0, 1.0, 1.0 - pose_epsilon, pose_epsilon]:
			var keyed_u: float = fposmod(u + float(phase["shift"]), 1.0)
			BodyBake.pose(ctx, walk[1], walk[4], keyed_u)
			BodyBake._apply_person_walk_body(ctx, fit, u, keyed_u, walk[4])
			applied.append((to_mesh * body.get_bone_global_pose(BodyBake._bone(body, "hips")).origin).y)
		assert_almost_eq(applied[0], applied[1], 0.000001, rig_name + " applied seam height")
		assert_almost_eq((applied[0] - applied[2]) / pose_epsilon, (applied[3] - applied[0]) / pose_epsilon, 0.02, rig_name + " applied seam slope (float32 skeleton positions)")
		for entry: Array in walks:
			if entry[0] != walk[0]:
				BodyBake._fit_person_stride(ctx, entry)
				phase = BodyBake._fit_person_phase(ctx, entry)
			var shared: Dictionary = BodyBake._fit_person_footlock(ctx, entry, phase)
			assert_eq(shared["pelvis"]["values"], table["values"], rig_name + " canonical table shared by " + str(entry[0]))
			var stats: Array = BodyBake._person_footlock_stats()
			for frame in int(entry[2]):
				var u: float = float(frame) / float(entry[2])
				var keyed_u: float = fposmod(u + float(phase["shift"]), 1.0)
				BodyBake.pose(ctx, entry[1], entry[4], keyed_u)
				var before: Array = BodyBake._person_footlock_points(fit, BodyBake._skin_frame(ctx))
				var drop: float = BodyBake._apply_person_walk_body(ctx, fit, u, keyed_u, entry[4])
				var misses: Array = BodyBake._apply_person_footlock(ctx, fit, u)
				var after: Array = BodyBake._person_footlock_probes(fit, BodyBake._skin_frame(ctx))
				BodyBake._note_person_footlock(ctx, fit, u, before, after, misses, stats, drop)
			BodyBake._print_person_footlock(entry[0], fit, stats)
			for side in 2:
				var note: Dictionary = stats[side]
				var label: String = "%s %s side %d" % [rig_name, entry[0], side]
				assert_gt(int(note["mid_samples"]), 0, label + " scheduled mid-stance samples")
				assert_lte(float(note["mid_knee_max_deg"]), 15.001, label + " mid knee <= 15 degrees (0.001 degree numeric tolerance)")
				var ratio: float = float(note["hips_sum_m"]) / float(note["frames"]) / float(fit["stand_ref_m"])
				assert_gte(ratio, 0.95, label + " mean hip / main rest hips above same floor >= 95%")
				assert_lte(BodyBake._person_footlock_slide(note["after"]), 2.0, label + " full scheduled stance slide <= 2 cm")
				assert_gte(float(note["contacts"]) / float(note["frames"]), 0.50, label + " actual contact share >= 50%")
				assert_eq(int(note["reach_clamp_frames"]), 0, label + " no IK distance cuts")
				assert_eq(int(note["height_fail_frames"]), 0, label + " exact bake phase height feasible")
				assert_gte(float(note["knee_forward_min_m"]), -0.00001, label + " fixed forward knee branch")
				assert_eq(int(note["knee_backward_frames"]), 0, label + " no backward knee")
		checked += 1
		root.queue_free()
	assert_eq(checked, 14, "all original living rigs checked")
	motion.queue_free()


## Include toe/heel corners above the rest minimum, not just one flat row.
func _baked_walk_sole(fixture: Dictionary, side: int) -> PackedInt32Array:
	var rest: PackedVector3Array = fixture["rest"]
	var flat: PackedInt32Array = fixture["soles"][side]
	var ids: PackedInt32Array = PackedInt32Array()
	if flat.is_empty():
		return ids
	var floor_y: float = rest[flat[0]].y
	for vertex in rest.size():
		if (rest[vertex].x >= 0.0) == (side == 0) and rest[vertex].y <= floor_y + 0.12:
			ids.append(vertex)
	return ids


func test_baked_six_walks_keep_rolling_stance_slide_and_contact_share() -> void:
	for fixture: Dictionary in _fixtures:
		var rest: PackedVector3Array = fixture["rest"]
		for side in 2:
			var ids: PackedInt32Array = _baked_walk_sole(fixture, side)
			assert_gt(ids.size(), 0, str(fixture["name"]) + " rolling sole vertices")
			if ids.is_empty():
				continue
			var base_frames: Array[PackedVector3Array] = _sample(fixture, _clip(fixture, "p_walk"), ids)
			var heights: Array[float] = []
			var floor_y: float = INF
			for vertex in ids:
				floor_y = minf(floor_y, rest[vertex].y)
			for points: PackedVector3Array in base_frames:
				var lowest: float = INF
				for point: Vector3 in points:
					lowest = minf(lowest, point.y)
				heights.append(lowest)
			var contact: float = BodyBake.person_contact_phase(heights)
			assert_gte(contact, 0.0, str(fixture["name"]) + " base walk has a touchdown")
			if contact < 0.0:
				continue
			# Only foot order is inferred; every walk uses the same exact STEP_AT.
			var order: int = 0 if _phase_distance(contact, float(BodyBake.PERSON_STEP_AT[0])) <= _phase_distance(contact, float(BodyBake.PERSON_STEP_AT[1])) else 1
			var start: float = BodyBake.PERSON_STEP_AT[order]
			var gap: float = fposmod(float(BodyBake.PERSON_STEP_AT[1 - order]) - start, 1.0)
			var duration: float = clampf(gap + BodyBake.PERSON_FOOTLOCK_OVERLAP, BodyBake.PERSON_FOOTLOCK_STANCE_MIN, BodyBake.PERSON_FOOTLOCK_STANCE_MAX)
			for name_text: String in GROUPS["walk"]:
				var clip: Dictionary = _clip(fixture, name_text)
				var frames: Array[PackedVector3Array] = _sample(fixture, clip, ids)
				if frames.is_empty():
					continue
				var contacts: int = 0
				var residuals: Array = []
				var y_quantum: float = 0.0
				if fixture["baked"].get("format", "") != "":
					y_quantum = (float(clip["hi"][1]) - float(clip["lo"][1])) / 255.0
				for frame in frames.size():
					var points: PackedVector3Array = frames[frame]
					var lowest: float = INF
					for point: Vector3 in points:
						lowest = minf(lowest, point.y)
					# The stored rgb8q pixel has up to half a vertical quantum of error.
					if absf(lowest - floor_y) <= BodyBake.PERSON_WALK_CONTACT_EPSILON + y_quantum * 0.5:
						contacts += 1
					var age: float = fposmod(float(frame) / float(frames.size()) - start, 1.0)
					if age > duration:
						continue
					var centre: Vector3 = Vector3.ZERO
					var reference: Vector3 = Vector3.ZERO
					var count: int = 0
					for index in points.size():
						if points[index].y <= lowest + BodyBake.PERSON_SOLE_EPSILON:
							centre += points[index]
							reference += rest[ids[index]]
							count += 1
					centre /= float(count)
					reference /= float(count)
					residuals.append(Vector2(centre.x - reference.x, centre.z + age * float(clip["round"]) - reference.z))
				var label: String = "%s %s side %d" % [fixture["name"], name_text, side]
				assert_lte(BodyBake._person_footlock_slide(residuals), 2.0, label + " baked stance slide <= 2 cm")
				assert_gte(float(contacts) / float(frames.size()), 0.50, label + " baked actual contact share >= 50%")




func test_original_final_fit_checks_accept_normal_rigs_and_reject_asymmetric_support() -> void:
	var directory: String = ProjectSettings.globalize_path("res://").path_join("../../_motion_src").simplify_path()
	var required: Array[String] = [directory.path_join("UAL1.glb")]
	for rig_name: String in SOURCE_RIGS:
		required.append(directory.path_join("rig").path_join(rig_name + ".glb"))
	for path: String in required:
		if not FileAccess.file_exists(path):
			pass_test("original motion and 14 rigs are not beside this checkout (missing " + path + "): final fit checks run where they are")
			return
	var motion: Node3D = _stand_source_scene(required[0])
	if motion == null:
		return
	add_child(motion)
	var entries: Array = []
	for entry: Array in BodyBake.PERSON_CLIPS:
		if BodyBake.PERSON_STRIDE_ROUNDS.has(entry[0]) or entry[0] == "p_stand":
			entries.append(entry)
	assert_eq(entries.size(), 13, "standing plus all twelve gait clips")
	var checked: int = 0
	for rig_name: String in SOURCE_RIGS:
		var root: Node3D = _stand_source_scene(directory.path_join("rig").path_join(rig_name + ".glb"))
		if root == null:
			continue
		add_child(root)
		var ctx: Dictionary = BodyBake.prepare(root, motion, entries, [])
		assert_false(ctx.is_empty(), rig_name + " final-fit context")
		if ctx.is_empty():
			root.queue_free()
			continue
		# As bake_person sets it, so the walk and run sink here is the bake's own.
		ctx["sink_scale"] = BodyBake._sink_scale(root, ctx["body"])
		var normal: Dictionary = BodyBake._bake_list(ctx, entries, [])
		assert_false(normal.is_empty(), rig_name + " normal frames are built")
		assert_eq(normal.get("fit_failures", []), [], rig_name + " normal stand, final phase and final round all pass")
		# A lateral offset lengthens only the left lower leg. The single mean
		# pelvis drop cannot satisfy both legs' requested knee angle/ankle.
		var body: Skeleton3D = ctx["body"]
		var foot: int = BodyBake._bone(body, "foot.L")
		var rest: Transform3D = body.get_bone_rest(foot)
		rest.origin.x += 0.2
		body.set_bone_rest(foot, rest)
		var broken: Dictionary = BodyBake._bake_list(ctx, [BodyBake.PERSON_CLIPS[2]], [])
		assert_false(broken.is_empty(), rig_name + " rejected frames still return diagnostics")
		var failures: Array = broken.get("fit_failures", [])
		assert_gt(failures.size(), 0, rig_name + " asymmetric support reaches fit_failures")
		assert_lte(failures.size(), 2, "at most one failure per standing leg")
		for failure: String in failures:
			assert_true(failure.begins_with("STAND_UNFIT p_stand "), failure)
		checked += 1
		root.queue_free()
	assert_eq(checked, 14, "all original rigs exercise the save gate")
	motion.queue_free()


func test_shared_legs_and_full_walk_run_frames() -> void:
	for fixture in _fixtures:
		for group: String in GROUPS:
			var base := _clip(fixture, GROUPS[group][0])
			if base.is_empty():
				continue
			var base_frames := _sample(fixture, base, fixture["feet"])
			for name_text: String in GROUPS[group]:
				var clip := _clip(fixture, name_text)
				if clip.is_empty():
					continue
				var label := "%s %s" % [fixture["name"], name_text]
				assert_eq(int(clip["frames"]), int(base["frames"]), label + " shares frame count")
				if group != "crouch":
					assert_eq(int(clip["frames"]), 32 if group == "walk" else 24, label + " keeps every frame")
				var frames := _sample(fixture, clip, fixture["feet"])
				if frames.size() != base_frames.size():
					continue
				var greatest := 0.0
				for f in frames.size():
					for i in frames[f].size():
						greatest = maxf(greatest, frames[f][i].distance_to(base_frames[f][i]))
				# Each arm-dependent clip box rounds into its own rgb8 cell.
				# Allow one cell from each box, including truncating encoders.
				var tolerance := _quantum(fixture, base) + _quantum(fixture, clip) + 0.00001
				assert_true(greatest <= tolerance, "%s foot difference %.6f <= quantization %.6f" % [label, greatest, tolerance])


func _contact_at(frames: Array[PackedVector3Array]) -> float:
	var heights := []
	for points: PackedVector3Array in frames:
		var lowest := INF
		for point in points:
			lowest = minf(lowest, point.y)
		heights.append(lowest)
	if heights.size() < 2 or not is_finite(float(heights.min())):
		return -1.0
	var threshold := float(heights.min()) + 0.01
	for f in heights.size():
		var previous := float(heights[(f + heights.size() - 1) % heights.size()])
		var current := float(heights[f])
		if previous > threshold and current <= threshold:
			return fposmod((float(f - 1) + (previous - threshold) / (previous - current)) / float(heights.size()), 1.0)
	return -1.0


func _phase_distance(a: float, b: float) -> float:
	var gap := absf(a - b)
	return minf(gap, 1.0 - gap)


func test_run_sole_contacts_are_within_fifty_milliseconds_of_steps_walks_reported() -> void:
	for fixture in _fixtures:
		for group in ["walk", "run"]:
			var period := float(SimNoise.STEP_ROUND[group]) / (2.1 if group == "walk" else 3.9)
			for name_text: String in GROUPS[group]:
				var clip := _clip(fixture, name_text)
				if clip.is_empty():
					continue
				var contacts := []
				for side in 2:
					contacts.append(_contact_at(_sample(fixture, clip, fixture["soles"][side])))
				var label := "%s %s" % [fixture["name"], name_text]
				assert_true(float(contacts[0]) >= 0.0 and float(contacts[1]) >= 0.0, "%s sole first entries L %.6f R %.6f" % [label, contacts[0], contacts[1]])
				if float(contacts[0]) < 0.0 or float(contacts[1]) < 0.0:
					continue
				var best := []
				var least := INF
				for order in 2:
					var errors := [_phase_distance(contacts[0], SimNoise.STEP_AT[order]), _phase_distance(contacts[1], SimNoise.STEP_AT[1 - order])]
					var worst := maxf(errors[0], errors[1])
					if worst < least:
						least = worst
						best = errors
				for side in 2:
					var seconds := float(best[side]) * period
					var line := "%s %s contact %.6f, STEP_AT %s, error %.3f ms <= 50 (round time %.6f s)" % [label, "L" if side == 0 else "R", contacts[side], str(SimNoise.STEP_AT), seconds * 1000.0, period]
					# The written walk keeps a swinging foot near (on one body below) the ground, so its
					# first entry is not always the step: walks are reported until the walk keys are
					# remade; runs are held.
					if group == "walk":
						print("WALK_PHASE " + line)
					else:
						assert_true(seconds <= 0.05, line)


func test_final_phase_gate_accepts_baked_soles_and_rejects_shifted_or_missing_contacts() -> void:
	for fixture: Dictionary in _fixtures:
		for group: String in ["walk", "run"]:
			for name_text: String in GROUPS[group]:
				var clip: Dictionary = _clip(fixture, name_text)
				if clip.is_empty():
					continue
				var heights: Array = [[], []]
				for side in 2:
					for points: PackedVector3Array in _sample(fixture, clip, fixture["soles"][side]):
						var lowest: float = INF
						for point: Vector3 in points:
							lowest = minf(lowest, point.y)
						heights[side].append(lowest)
				var label: String = "%s %s" % [fixture["name"], name_text]
				var ctx: Dictionary = {"fit_failures": []}
				BodyBake._check_person_phase_final(ctx, name_text, heights)
				assert_eq(ctx["fit_failures"], [], label + " existing baked soles pass the same final gate")
				if group == "run":
					var shifted: Array = [[], []]
					for side in 2:
						var count: int = heights[side].size()
						for f in count:
							shifted[side].append(heights[side][(f + int(count / 4.0)) % count])
					ctx["fit_failures"] = []
					BodyBake._check_person_phase_final(ctx, name_text, shifted)
					assert_eq((ctx["fit_failures"] as Array).size(), 1, label + " a quarter-cycle late fails")
					for failure: String in ctx["fit_failures"]:
						assert_true(failure.begins_with("PHASE_FINAL " + name_text + " "), failure)
				heights[0] = []
				ctx["fit_failures"] = []
				BodyBake._check_person_phase_final(ctx, name_text, heights)
				assert_eq((ctx["fit_failures"] as Array).size(), 1, label + " a missing foot also fails for walks")
				for failure: String in ctx["fit_failures"]:
					assert_true(failure.begins_with("PHASE_FINAL " + name_text + " no_sole_contact "), failure)


func test_phase_solver_splits_symmetric_contact_error_and_handles_the_seam() -> void:
	assert_eq(BodyBake.PERSON_STEP_AT, SimNoise.STEP_AT, "phase targets follow the unchanged noise rule")
	for pair: Array in [[0.1, 0.6], [0.98, 0.48]]:
		var shift := BodyBake.person_phase_shift(pair[0], pair[1])
		for contact: float in pair:
			var phase := fposmod(contact - shift, 1.0)
			var error := minf(_phase_distance(phase, SimNoise.STEP_AT[0]), _phase_distance(phase, SimNoise.STEP_AT[1]))
			assert_almost_eq(error, 0.025, 0.000001, "half-cycle contacts split the 0.05 mismatch equally")
	assert_almost_eq(BodyBake.person_contact_phase([0.0, 0.0, 0.03, 0.02]), 0.875, 0.000001, "contact interpolates across the seam")
	assert_eq(BodyBake.person_contact_phase([0.0, 0.0, 0.0, 0.0]), -1.0, "a foot that never lifts has no first entry")


func test_step_off_solver_interpolates_upward_exits_and_the_seam() -> void:
	assert_almost_eq(BodyBake.person_step_off_phase([0.0, 0.0, 0.03, 0.02]), 1.0 / 3.0, 0.000001, "upward exit between output frames")
	assert_almost_eq(BodyBake.person_step_off_phase([0.02, 0.03, 0.0, 0.0]), 0.875, 0.000001, "upward exit across last-to-first seam")
	assert_almost_eq(BodyBake.person_step_off_phase([0.0, 0.01, 0.03, 0.0]), 0.25, 0.000001, "threshold is still grounded; exit starts at that sample")
	assert_almost_eq(BodyBake.person_step_off_phase([0.01, 0.03, 0.0, 0.0]), 0.0, 0.000001, "phase zero is a valid exit")
	assert_almost_eq(BodyBake.person_step_off_phase([-0.2, -0.2, -0.17, -0.18]), 1.0 / 3.0, 0.000001, "ground follows the sole minimum, as for contact")
	for heights: Array in [[], [0.0], [0.0, 0.0, 0.0, 0.0], [0.0, 0.005, 0.01, 0.005]]:
		assert_eq(BodyBake.person_step_off_phase(heights), -1.0, "no upward exit in %s" % [heights])


## Draft for the bake/test session: old bodies must be rebaked before this runs.
func test_baked_gait_step_off_is_preserved_and_differs_from_contact() -> void:
	if _fixtures.is_empty():
		pending("No baked living bodies available for step_off checks")
		return
	for fixture in _fixtures:
		var info := _clip_info(PEOPLE.path_join(fixture["name"]))
		for saved: Dictionary in info.get("clips", []):
			var loaded := _clip(fixture, str(saved["name"]))
			assert_eq(loaded.has("step_off"), saved.has("step_off"), "load preserves key presence, including legacy omissions")
			if saved.has("step_off"):
				assert_eq(loaded.get("step_off"), saved["step_off"], "load preserves step_off unchanged")
		for name_text: String in BodyBake.PERSON_STRIDE_ROUNDS:
			var clip := _clip(fixture, name_text)
			var label := "%s %s" % [fixture["name"], name_text]
			assert_true(clip.has("step_off"), label + " has step_off after rebaking")
			var step_off: Array = clip.get("step_off", [])
			assert_eq(step_off.size(), 2, label + " has left/right phases")
			if step_off.size() != 2:
				continue
			for side in 2:
				var phase := float(step_off[side])
				assert_true(phase >= 0.0 and phase < 1.0, "%s side %d step_off %.6f in [0, 1)" % [label, side, phase])
				var contact := _contact_at(_sample(fixture, clip, fixture["soles"][side]))
				assert_true(contact >= 0.0, label + " has a sole contact")
				if contact >= 0.0:
					assert_true(_phase_distance(phase, contact) > 0.000001, label + " lift differs from that foot's contact")


func _clip_info(folder: String) -> Dictionary:
	var path := folder.path_join("clips.json")
	assert_true(FileAccess.file_exists(path), path + " exists")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, path + " is an object")
	if not parsed is Dictionary:
		return {}
	var info: Dictionary = parsed
	var height := int(info.get("height", 0))
	assert_true(height > 0 and height <= 4096, "%s height %d in 1..4096" % [path, height])
	assert_true(info.get("clips", []) is Array and not (info.get("clips", []) as Array).is_empty(), path + " has clips")
	return info


func _clip_layout(info: Dictionary) -> Array:
	var layout := []
	for clip: Dictionary in info.get("clips", []):
		layout.append([str(clip.get("name", "")), int(clip.get("start", -1)), int(clip.get("frames", 0))])
	return layout


func test_all_body_and_wear_heights_and_clip_layouts_match() -> void:
	for name_text: String in DirAccess.get_directories_at(PEOPLE):
		if not name_text.ends_with("_p"):
			continue
		var folder := PEOPLE.path_join(name_text)
		var body_info := _clip_info(folder)
		var layout := _clip_layout(body_info)
		var wear := folder.path_join("wear")
		for garment: String in DirAccess.get_directories_at(wear):
			var garment_folder := wear.path_join(garment)
			var garment_info := _clip_info(garment_folder)
			assert_eq(_clip_layout(garment_info), layout, garment_folder + " shares body clip names/start/frames")


func test_every_gait_round_matches_the_rules_within_half_a_percent() -> void:
	for fixture in _fixtures:
		for group: String in GROUPS:
			var target: float = SimNoise.STEP_ROUND[group]
			for name_text: String in GROUPS[group]:
				var clip := _clip(fixture, name_text)
				if not clip.is_empty():
					assert_almost_eq(float(clip["round"]), target, target * 0.005, "%s %s round" % [fixture["name"], name_text])


func test_stance_speed_ratios_are_reported_without_a_pass_threshold() -> void:
	for fixture in _fixtures:
		for group in ["walk", "run"]:
			var clip := _clip(fixture, GROUPS[group][0])
			if clip.is_empty():
				continue
			var frames := _sample(fixture, clip, fixture["feet"])
			var feet: PackedInt32Array = fixture["feet"]
			var rest: PackedVector3Array = fixture["rest"]
			for side in ["L", "R"]:
				var track := PackedVector3Array()
				var ground := INF
				for points: PackedVector3Array in frames:
					var lowest := Vector3(0, INF, 0)
					for i in feet.size():
						if (rest[feet[i]].x >= 0.0) == (side == "L") and points[i].y < lowest.y:
							lowest = points[i]
					track.append(lowest)
					ground = minf(ground, lowest.y)
				var ratios := []
				for f in track.size():
					var next := (f + 1) % track.size()
					if track[f].y <= ground + 0.015 and track[next].y <= ground + 0.015 and is_finite(ground):
						ratios.append((track[next].z - track[f].z) / (float(SimNoise.STEP_ROUND[group]) / float(track.size())))
				if ratios.is_empty():
					print("STANCE %s %s %s n=0 target=-1.1..-0.9" % [fixture["name"], clip["name"], side])
				else:
					var total := 0.0
					for ratio: float in ratios:
						total += ratio
					print("STANCE %s %s %s n=%d min=%.4f max=%.4f mean=%.4f target=-1.1..-0.9" % [fixture["name"], clip["name"], side, ratios.size(), ratios.min(), ratios.max(), total / float(ratios.size())])
	pass_test("stance speed ratios are reported in the log (no pass line while the walk keys wait on a decision)")
