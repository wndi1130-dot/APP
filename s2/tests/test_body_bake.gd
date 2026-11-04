extends "res://addons/gut/test.gd"
## The body baker's tables and its save / read-back. The bake itself needs a
## body and a motion set, which are not in the repository.

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")


func _two_bone_assets() -> Dictionary:
	var source: Array = []
	source.resize(Mesh.ARRAY_MAX)
	source[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 0.5, 0)])
	source[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	source[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	source[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0])
	source[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 0.5, 0.5, 0, 0])
	var still := [Transform3D(), Transform3D()]
	var lifted := [Transform3D(), Transform3D(Basis(), Vector3(0, 2.25, 0))]
	return VatBaker.build_skinned(source, [{"name": "walk", "length": 1.5, "frames": [still, lifted, still]}, {"name": "fall", "loop": false, "length": 2.5, "frames": [still, lifted]}])


func test_every_motion_names_a_layer_that_exists_and_layers_only_name_body_bones() -> void:
	for clip in BodyBake.CLIPS:
		assert_true(clip[4] == "" or BodyBake.LAYERS.has(clip[4]), "layer of %s" % clip[0])
	for pose in BodyBake.POSES:
		assert_true(pose[2] == "" or BodyBake.OVERLAYS.has(pose[2]), "addition %s" % pose[2])
	for layer_name in BodyBake.LAYERS:
		var layer: Dictionary = BodyBake.LAYERS[layer_name]
		for bone in layer.get("damp", {}):
			assert_true(BodyBake.MAP.has(bone), "%s damp %s" % [layer_name, bone])
		for step in layer["steps"]:
			if step[0] == "stand_support":
				continue  # written in code: it names no bones here
			assert_true(step[0] in ["turn", "aim", "swing"], "%s step kind %s" % [layer_name, step[0]])
			assert_true(BodyBake.MAP.has(step[1]), "%s step %s" % [layer_name, step[1]])
			if step[0] == "turn":
				assert_true(BodyBake.AXES.has(step[2]))
			else:
				assert_true(BodyBake.MAP.has(step[2]), "%s aims at %s" % [layer_name, step[2]])


func test_the_three_walks_differ_and_the_motion_numbers_fit_the_shader_table() -> void:
	var names: Array = []
	for clip in BodyBake.CLIPS:
		names.append(clip[0])
	assert_eq(names, ["walk_a", "walk_b", "walk_c", "stand", "lunge", "hit", "fall", "run", "tell", "fall_front", "crawl", "rise", "climb", "rise_front", "stagger", "fall_thrown", "fall_slump",
		"thump", "claw", "hit_left", "hit_right", "hit_top", "hit_upper", "turn_left", "turn_right", "walk_d", "walk_e",
		"eat_start", "eat", "eat_rise", "bite", "bite_miss"], "the numbers the drawing side uses")
	assert_true(BodyBake.CLIPS.size() + 1 <= VatBaker.TABLE_SIZE, "with the still poses")
	assert_ne(BodyBake.LAYERS["walk"]["damp"], BodyBake.LAYERS["walk_c"]["damp"], "a different leg drags")


func test_a_layer_value_is_a_number_or_a_swing_about_it() -> void:
	assert_eq(BodyBake._value(0.3, 1.0), 0.3)
	assert_almost_eq(BodyBake._value([0.2, 0.1, 0.0], PI * 0.5), 0.3, 0.0001)
	assert_almost_eq(BodyBake._value([0.2, 0.1, PI * 0.5], PI * 0.5), 0.2, 0.0001, "lagging a quarter turn")
	assert_almost_eq(BodyBake._value([0.2, 0.1, 0.0, 2.0], PI * 0.25), 0.3, 0.0001, "two beats to a turn")
	assert_almost_eq(BodyBake._value([[0.2, 0.1, 0.0], [0.5, 0.0, 0.0]], PI * 0.5), 0.8, 0.0001, "a list of them adds up")


func test_turn_and_aim_move_a_bone_and_what_hangs_on_it() -> void:
	var body := Skeleton3D.new()
	add_child_autofree(body)
	body.add_bone("upper")
	body.add_bone("lower")
	body.add_bone("tip")
	body.set_bone_parent(1, 0)
	body.set_bone_parent(2, 1)
	body.set_bone_rest(1, Transform3D(Basis(), Vector3(0, 1, 0)))
	body.set_bone_rest(2, Transform3D(Basis(), Vector3(0, 1, 0)))
	body.reset_bone_poses()
	BodyBake.aim(body, "upper", "lower", Vector3(0, 0, 3))
	assert_true(body.get_bone_global_pose(1).origin.is_equal_approx(Vector3(0, 0, 1)), "points where it was told")
	assert_true(body.get_bone_global_pose(2).origin.is_equal_approx(Vector3(0, 0, 2)), "what hangs on it follows")
	BodyBake.turn(body, "lower", PI * 0.5)
	assert_true(body.get_bone_global_pose(2).origin.is_equal_approx(Vector3(0, -1, 1)), "bent forward about the left-right axis")


func test_a_swing_points_a_bone_ahead_of_straight_down_or_behind_past_level() -> void:
	var body := Skeleton3D.new()
	add_child_autofree(body)
	body.add_bone("upper")
	body.add_bone("lower")
	body.set_bone_parent(1, 0)
	body.set_bone_rest(1, Transform3D(Basis(), Vector3(0, 1, 0)))
	body.reset_bone_poses()
	BodyBake.apply_layer(body, {"steps": [["swing", "upper", "lower", 0.0, PI * 0.5]]}, 0.0)
	assert_true(body.get_bone_global_pose(1).origin.is_equal_approx(Vector3(0, 0, 1)), "a right angle: straight ahead")
	BodyBake.apply_layer(body, {"steps": [["swing", "upper", "lower", 0.0, -2.0]]}, 0.0)
	var behind := body.get_bone_global_pose(1).origin
	assert_lt(behind.z, -0.9, "behind")
	assert_gt(behind.y, 0.4, "and up, past level (a heel kicked up)")


func test_a_bake_is_written_and_read_back_the_same() -> void:
	var assets := _two_bone_assets()
	var dir := "user://test_body_bake"
	BodyBake.save(assets, dir)
	var back: Dictionary = BodyBake.load_baked(dir)
	assert_false(back.is_empty())
	assert_eq(int(back["vertices"]), 3)
	assert_eq(int(back["height"]), 5)
	assert_eq((back["clips"] as Array).size(), 2)
	assert_eq(String(back["clips"][1]["name"]), "fall")
	assert_false(bool(back["clips"][1]["loop"]))
	assert_eq(float(back["clips"][0]["round"]), 0.0, "a folder baked before rounds were measured reads as none")
	assert_almost_eq((back["image"] as Image).get_pixel(1, 1).g, 2.25, 0.001, "metres past the 8 bit range survive the file")
	assert_eq(VatBaker.shader_tables(back)["clip_start"][1], 3.0)
	for file in ["vat.bin", "mesh.res", "clips.json"]:
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func test_a_compacted_bake_reads_back_within_a_centimetre() -> void:
	var source: Array = []
	source.resize(Mesh.ARRAY_MAX)
	source[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 0.5, 0)])
	source[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	source[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	source[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0])
	source[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 0.5, 0.5, 0, 0])
	var moves := func(count: int, reach: float) -> Array:
		var frames := []
		for f in count:
			frames.append([Transform3D(), Transform3D(Basis(), Vector3(0.1 * f, reach * f / float(count - 1), -0.3 * f))])
		return frames
	var clips := [{"name": "walk", "length": 1.0, "frames": moves.call(8, 0.4)}, {"name": "hit", "loop": false, "length": 0.4, "frames": moves.call(4, 0.2)},
		{"name": "fall", "loop": false, "length": 1.0, "frames": moves.call(5, 2.25)}, {"name": BodyBake.POSES_CLIP, "loop": false, "length": 1.0, "frames": moves.call(2, 1.0)}]
	var full := VatBaker.build_skinned(source, clips)
	var small := BodyBake.compact(full)
	var names := []
	for clip in small["clips"]:
		names.append(clip["name"])
	assert_eq(names, ["walk", "hit", "fall"], "the still poses are left out")
	assert_eq(int(small["clips"][0]["frames"]), 4, "a loop keeps every other frame")
	assert_eq(int(small["clips"][1]["frames"]), 1, "a motion the field never picks keeps one frame")
	assert_eq(int(small["clips"][2]["frames"]), 3, "a one-shot keeps its first and last")
	var mixed := BodyBake.compact(full, ["walk"])
	assert_eq(int(mixed["clips"][0]["frames"]), 8, "a clip named to keep every frame keeps them")
	assert_eq(int(mixed["clips"][2]["frames"]), 3, "the others are still halved")
	assert_eq(int(mixed["clips"][1]["start"]), 8)
	var dir := "user://test_body_bake_small"
	BodyBake.save(small, dir)
	var back: Dictionary = BodyBake.load_baked(dir)
	assert_eq(str(back.get("format", "")), BodyBake.SMALL_FORMAT)
	assert_true(bool(VatBaker.shader_tables(back)["quantized"]))
	var worst := 0.0
	# walk frames 0, 2, 4, 6 and fall frames 0 and 4 land on stored frames
	for pair in [[0, 0, 0], [0, 1, 2], [0, 2, 4], [0, 3, 6], [2, 0, 0], [2, 2, 4]]:
		var got: Dictionary = back["clips"][pair[0]]
		var was: Dictionary = full["clips"][pair[0]]
		var lo: Array = got["lo"]
		var hi: Array = got["hi"]
		for vertex in 3:
			var c := (back["image"] as Image).get_pixel(vertex, int(got["start"]) + pair[1])
			var decoded := Vector3(lo[0] + c.r * (hi[0] - lo[0]), lo[1] + c.g * (hi[1] - lo[1]), lo[2] + c.b * (hi[2] - lo[2]))
			var o := (full["image"] as Image).get_pixel(vertex, int(was["start"]) + pair[2])
			worst = maxf(worst, decoded.distance_to(Vector3(o.r, o.g, o.b)))
	assert_lt(worst, 0.01, "8 bits inside each clip's box stay within a centimetre")
	assert_eq(VatBaker.shader_tables(BodyBake.load_baked(dir))["clip_start"][2], 5.0)
	for file in ["vat.bin", "mesh.res", "clips.json"]:
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func test_reading_a_folder_with_no_bake_gives_nothing() -> void:
	assert_true(BodyBake.load_baked("user://no_such_bake_folder").is_empty())


func test_a_layer_value_can_swing_and_the_tell_runs_a_quarter_turn() -> void:
	assert_almost_eq(BodyBake._value(0.3, 2.0), 0.3, 0.0001, "a plain number stays")
	assert_almost_eq(BodyBake._value([0.2, 0.4, 0.0, 0.25], 0.0), 0.2, 0.0001, "the tell starts from the slump")
	assert_almost_eq(BodyBake._value([0.2, 0.4, 0.0, 0.25], TAU), 0.6, 0.0001, "and ends at its far end, without coming back")
	assert_false(bool(BodyBake.CLIPS[8][3]), "the tell plays once")
	assert_true(bool(BodyBake.CLIPS[7][3]), "the run loops")


## A stick body with the bones the baker asks for, standing with its arms out,
## and three skinned vertices (foot, head, hips). `size` scales it (hips 1 m up at 1).
func _stick_body(size: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var body := Skeleton3D.new()
	root.add_child(body)
	# bone, parent, where it starts from its parent
	var bones := [
		["hips", "", Vector3(0, 1, 0)], ["spine", "hips", Vector3(0, 0.2, 0)], ["chest", "spine", Vector3(0, 0.2, 0)],
		["neck", "chest", Vector3(0, 0.2, 0)], ["head", "neck", Vector3(0, 0.1, 0)],
		["upper_arm.L", "chest", Vector3(0.2, 0.1, 0)], ["forearm.L", "upper_arm.L", Vector3(0.3, 0, 0)], ["hand.L", "forearm.L", Vector3(0.3, 0, 0)],
		["upper_arm.R", "chest", Vector3(-0.2, 0.1, 0)], ["forearm.R", "upper_arm.R", Vector3(-0.3, 0, 0)], ["hand.R", "forearm.R", Vector3(-0.3, 0, 0)],
		["thigh.L", "hips", Vector3(0.1, 0, 0)], ["shin.L", "thigh.L", Vector3(0, -0.5, 0)], ["foot.L", "shin.L", Vector3(0, -0.5, 0)],
		["thigh.R", "hips", Vector3(-0.1, 0, 0)], ["shin.R", "thigh.R", Vector3(0, -0.5, 0)], ["foot.R", "shin.R", Vector3(0, -0.5, 0)],
	]
	var skin := Skin.new()
	for bone: Array in bones:
		var id := body.add_bone(bone[0])
		if bone[1] != "":
			body.set_bone_parent(id, body.find_bone(bone[1]))
		body.set_bone_rest(id, Transform3D(Basis(), bone[2] * size))
	body.reset_bone_poses()
	for id in body.get_bone_count():
		skin.add_bind(id, body.get_bone_global_rest(id).affine_inverse())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var foot := body.find_bone("foot.L")
	var head := body.find_bone("head")
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0.1, 0, 0) * size, Vector3(0, 1.7, 0) * size, Vector3(0, 1, 0) * size])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([foot, 0, 0, 0, head, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = mesh
	mesh_node.skin = skin
	root.add_child(mesh_node)
	return root


## Keep the original three-vertex fixture unchanged for its VAT index tests.
## This walking-only fixture adds both heels/toes, 4 cm below the ankle.
func _walk_stick_context() -> Dictionary:
	var root: Node3D = _stick_body()
	add_child_autofree(root)
	var body: Skeleton3D = BodyBake.first_of(root, "Skeleton3D") as Skeleton3D
	var mesh_node: MeshInstance3D = BodyBake.first_of(root, "MeshInstance3D") as MeshInstance3D
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var legs: Array = []
	var ankles: Array = []
	var anchors: Array = []
	var rotations: Array = []
	for side in 2:
		var suffix: String = ".L" if side == 0 else ".R"
		var leg: Array = [body.find_bone("thigh" + suffix), body.find_bone("shin" + suffix), body.find_bone("foot" + suffix)]
		var ankle: Vector3 = body.get_bone_global_rest(int(leg[2])).origin
		var first: int = vertices.size()
		for x: float in [-0.04, 0.04]:
			for z: float in [-0.08, 0.16]:
				vertices.append(ankle + Vector3(x, -0.04, z))
				normals.append(Vector3.DOWN)
				bones.append_array(PackedInt32Array([int(leg[2]), 0, 0, 0]))
				weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first + 1, first + 3, first + 2]))
		legs.append(leg)
		ankles.append(ankle)
		anchors.append(body.get_bone_global_rest(int(leg[0])).origin - Vector3(0.0, 0.0, BodyBake.PERSON_WALK_FOOTPRINT_BACK))
		rotations.append(Basis())
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	# surface_get_arrays hands back tangents (4 per vertex) for the three stick vertices only.
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_node.mesh = mesh
	var walk: Array = BodyBake.PERSON_CLIPS[0]
	var ctx: Dictionary = BodyBake.prepare_own(root, [walk])
	var durations: Array = []
	for side in 2:
		var gap: float = fposmod(float(BodyBake.PERSON_STEP_AT[1 - side]) - float(BodyBake.PERSON_STEP_AT[side]), 1.0)
		durations.append(clampf(gap + BodyBake.PERSON_FOOTLOCK_OVERLAP, BodyBake.PERSON_FOOTLOCK_STANCE_MIN, BodyBake.PERSON_FOOTLOCK_STANCE_MAX))
	var fit: Dictionary = {"rest": vertices, "bones": bones, "weights": weights, "per": 4,
		"soles": BodyBake.person_sole_vertices(vertices), "legs": legs, "rest_ankles": ankles, "anchors": anchors, "rotations": rotations,
		"starts": BodyBake.PERSON_STEP_AT.duplicate(), "durations": durations, "round": float(BodyBake.PERSON_STRIDE_ROUNDS["p_walk"]),
		"floor": -0.04, "rest_hips_y": 1.0, "stand_ref_m": 1.04}
	fit["pelvis"] = BodyBake._fit_person_walk_height(ctx, fit, walk, 0.0)
	ctx["footlock_walk"] = fit
	return ctx


func test_walk_height_table_is_deterministic_periodic_and_reach_safe() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var first: Dictionary = fit["pelvis"]
	var second: Dictionary = BodyBake._fit_person_walk_height(ctx, fit, BodyBake.PERSON_CLIPS[0], 0.0)
	for key: String in ["values", "slopes", "uppers", "lowers"]:
		var a: PackedFloat64Array = first[key]
		var b: PackedFloat64Array = second[key]
		assert_eq(a.to_byte_array(), b.to_byte_array(), key + " identical bytes from repeated fits")
	var values: PackedFloat64Array = first["values"]
	var uppers: PackedFloat64Array = first["uppers"]
	var lowers: PackedFloat64Array = first["lowers"]
	assert_eq(values.size(), 256, "one canonical cycle")
	assert_true((first["failed_samples"] as PackedInt32Array).is_empty(), "stick height interval feasible")
	for sample in values.size():
		assert_lte(values[sample], uppers[sample] + 0.00000001, "smoothed height obeys reach ceiling")
		assert_gte(values[sample], lowers[sample] - 0.00000001, "smoothed height keeps mid-stance knee bound")
	assert_eq(BodyBake._person_walk_height_at(first, 0.0), BodyBake._person_walk_height_at(first, 1.0), "same seam height")
	var epsilon: float = 0.000001
	var seam: float = BodyBake._person_walk_height_at(first, 0.0)
	var left: float = (seam - BodyBake._person_walk_height_at(first, 1.0 - epsilon)) / epsilon
	var right: float = (BodyBake._person_walk_height_at(first, epsilon) - seam) / epsilon
	assert_almost_eq(left, right, 0.002, "same one-sided seam slope, m/cycle")
	for u: float in [0.75, 0.0, 0.37, 0.999, 0.2]:
		assert_almost_eq(BodyBake._person_walk_height_at(first, u), BodyBake._person_walk_height_at(first, u + 1.0), 0.00000001, "arbitrary query order is periodic")
	var body: Skeleton3D = ctx["body"]
	var applied: Array[float] = []
	var pose_epsilon: float = 0.00001
	for u: float in [0.0, 1.0, 1.0 - pose_epsilon, pose_epsilon]:
		BodyBake.pose(ctx, "", "p_walk", fposmod(u, 1.0))
		BodyBake._apply_person_walk_body(ctx, fit, u, fposmod(u, 1.0), "p_walk")
		applied.append(body.get_bone_global_pose(body.find_bone("hips")).origin.y)
	assert_almost_eq(applied[0], applied[1], 0.000001, "exact-phase projection preserves seam height")
	assert_almost_eq((applied[0] - applied[2]) / pose_epsilon, (applied[3] - applied[0]) / pose_epsilon, 0.02, "applied seam slope (float32 skeleton positions)")


func test_six_walks_keep_mid_knees_upright_hips_and_locked_rolling_feet() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	for entry: Array in BodyBake.PERSON_CLIPS:
		if not BodyBake.PERSON_FOOT_LOCK.has(entry[0]):
			continue
		var cached: Dictionary = BodyBake._fit_person_footlock(ctx, entry, {"shift": 0.0})
		assert_eq(cached["pelvis"]["values"], fit["pelvis"]["values"], "six clips share canonical p_walk height table")
		var stats: Array = BodyBake._person_footlock_stats()
		for frame in int(entry[2]):
			var u: float = float(frame) / float(entry[2])
			BodyBake.pose(ctx, entry[1], entry[4], u)
			var before: Array = BodyBake._person_footlock_points(fit, BodyBake._skin_frame(ctx))
			var drop: float = BodyBake._apply_person_walk_body(ctx, fit, u, u, entry[4])
			var misses: Array = BodyBake._apply_person_footlock(ctx, fit, u)
			var after: Array = BodyBake._person_footlock_probes(fit, BodyBake._skin_frame(ctx))
			BodyBake._note_person_footlock(ctx, fit, u, before, after, misses, stats, drop)
		for side in 2:
			var note: Dictionary = stats[side]
			var label: String = "%s side %d" % [entry[0], side]
			assert_gt(int(note["mid_samples"]), 0, label + " scheduled mid-stance sampled")
			assert_lte(float(note["mid_knee_max_deg"]), 15.001, label + " mid knee <= 15 degrees (0.001 degree numeric tolerance)")
			var ratio: float = float(note["hips_sum_m"]) / float(note["frames"]) / float(fit["stand_ref_m"])
			assert_gte(ratio, 0.95, label + " mean hip / main rest hips above same floor >= 95%")
			assert_lte(BodyBake._person_footlock_slide(note["after"]), 2.0, label + " full scheduled stance slide <= 2 cm")
			assert_gte(float(note["contacts"]) / float(note["frames"]), 0.50, label + " actual contact share >= 50%")
			assert_eq(int(note["reach_clamp_frames"]), 0, label + " no IK distance cuts")
			assert_lte(float(note["miss"]), 0.001, label + " ankle target reached within 1 mm")
			assert_eq(int(note["height_fail_frames"]), 0, label + " exact bake phases feasible")
			assert_gte(float(note["knee_forward_min_m"]), -0.00001, label + " knee bends toward fixed forward pole")
			assert_eq(int(note["knee_backward_frames"]), 0, label + " no backward branch")


func test_walk_height_cancels_entire_main_sink_and_counts_noncontact_mid_stance() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var body: Skeleton3D = ctx["body"]
	var u: float = fposmod(float(fit["starts"][0]) + 0.5 * float(fit["durations"][0]), 1.0)
	var heights: Array[float] = []
	for scale: float in [1.0, 0.25, 2.0, 1.0]:
		ctx["sink_scale"] = scale
		BodyBake.pose(ctx, "", "p_walk", u)
		BodyBake._apply_person_walk_body(ctx, fit, u, u, "p_walk")
		heights.append(body.get_bone_global_pose(body.find_bone("hips")).origin.y)
	for height: float in heights:
		assert_almost_eq(height, heights[0], 0.000001, "neither WALK_SINK mean nor oscillation survives")
	var before: Array = BodyBake._person_footlock_points(fit, BodyBake._skin_frame(ctx))
	var misses: Array = BodyBake._apply_person_footlock(ctx, fit, u)
	var after: Array = BodyBake._person_footlock_probes(fit, BodyBake._skin_frame(ctx))
	var point: Vector3 = after[0]["point"]
	point.y += 0.1  # force noncontact without removing a scheduled knee sample
	after[0]["point"] = point
	var stats: Array = BodyBake._person_footlock_stats()
	BodyBake._note_person_footlock(ctx, fit, u, before, after, misses, stats, 0.0)
	assert_eq(int(stats[0]["contacts"]), 0, "probe deliberately airborne")
	assert_eq(int(stats[0]["mid_samples"]), 1, "knee sample still counted")


func test_walk_height_infeasibility_rejects_the_fit_and_ik_reports_distance_cuts() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = (ctx["footlock_walk"] as Dictionary).duplicate(true)
	fit["rest_hips_y"] = 0.5  # ceiling below the mid-stance lower bound
	ctx["fit_failures"] = []
	var table: Dictionary = BodyBake._fit_person_walk_height(ctx, fit, BodyBake.PERSON_CLIPS[0], 0.0)
	var failed: PackedInt32Array = table["failed_samples"]
	assert_gt(failed.size(), 0, "infeasible sample slots recorded")
	assert_eq((ctx["fit_failures"] as Array).size(), failed.size(), "each failing slot reaches the existing save refusal list")
	var body: Skeleton3D = ctx["body"]
	var leg: Array = fit["legs"][0]
	body.reset_bone_poses()
	var hip: Vector3 = body.get_bone_global_pose(int(leg[0])).origin
	assert_true(BodyBake._solve_person_footlock_leg(body, leg, hip + Vector3(0.0, -3.0, 0.1), Vector3.BACK), "unreachable ankle reports a cut")


## Keep the stick rig, but give both feet a sole vertex for final-phase checks.
func _stick_body_with_two_soles(size: float = 1.0) -> Node3D:
	var root: Node3D = _stick_body(size)
	var body: Skeleton3D = BodyBake.first_of(root, "Skeleton3D") as Skeleton3D
	var mesh_node: MeshInstance3D = BodyBake.first_of(root, "MeshInstance3D") as MeshInstance3D
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	vertices[1] = Vector3(-0.1, 0.0, 0.0) * size
	bones[4] = body.find_bone("foot.R")
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_BONES] = bones
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_node.mesh = mesh
	return root


## Actual skin matrices with independently timed soles. A negative phase
## leaves that foot on the ground throughout, so it has no first contact.
func _sole_frames(ctx: Dictionary, left: float, right: float, count: int = 24) -> Array:
	var body: Skeleton3D = ctx["body"]
	var bind_bone: Array = ctx["bind_bone"]
	var feet: Array = [bind_bone.find(body.find_bone("foot.L")), bind_bone.find(body.find_bone("foot.R"))]
	var phases: Array[float] = [left, right]
	var frames: Array = []
	for f in count:
		var skin: Array = []
		for _bone_index in bind_bone.size():
			skin.append(Transform3D.IDENTITY)
		for side in 2:
			var height: float = 0.02 * (1.0 - cos(TAU * (float(f) / float(count) - phases[side] - 1.0 / 6.0))) if phases[side] >= 0.0 else 0.0
			skin[int(feet[side])] = Transform3D(Basis.IDENTITY, Vector3(0.0, height, 0.0))
		frames.append(skin)
	return frames


func test_stand_support_uses_thigh_x_and_accepts_symmetric_splayed_rest() -> void:
	var root: Node3D = _stick_body()
	add_child_autofree(root)
	var body: Skeleton3D = BodyBake.first_of(root, "Skeleton3D") as Skeleton3D
	for side: String in ["L", "R"]:
		var foot: int = body.find_bone("foot." + side)
		var rest: Transform3D = body.get_bone_rest(foot)
		rest.origin.x = 0.08 if side == "L" else -0.08
		body.set_bone_rest(foot, rest)
	var ctx: Dictionary = BodyBake.prepare_own(root)
	for f in 32:
		BodyBake.pose(ctx, "", "p_stand", float(f) / 32.0)
		for side: String in ["L", "R"]:
			var thigh: Vector3 = body.get_bone_global_rest(body.find_bone("thigh." + side)).origin
			var rest: Vector3 = body.get_bone_global_rest(body.find_bone("foot." + side)).origin
			var foot: Vector3 = body.get_bone_global_pose(body.find_bone("foot." + side)).origin
			var target: Vector3 = Vector3(thigh.x + (0.05 if side == "L" else -0.05), rest.y, rest.z)
			assert_lt(foot.distance_to(target), 0.001, side + " ankle is relative to its thigh, not its splayed rest ankle")
	assert_eq(ctx.get("fit_failures", []), [], "symmetric support meets all four final checks")
	ctx["player"] = null
	var assets: Dictionary = BodyBake._bake_list(ctx, [["p_stand", "", 32, true, "p_stand", 2.5]], [])
	assert_false(assets.is_empty())
	assert_eq(assets.get("fit_failures", []), [], "normal support has no bake failures")


func test_asymmetric_stand_fails_once_per_leg_and_retains_worst_measurements() -> void:
	var root: Node3D = _stick_body()
	add_child_autofree(root)
	var ctx: Dictionary = BodyBake.prepare_own(root)
	var body: Skeleton3D = ctx["body"]
	var foot: int = body.find_bone("foot.L")
	var rest: Transform3D = body.get_bone_rest(foot)
	for offset: float in [0.1, 0.2]:
		rest.origin.x = offset
		body.set_bone_rest(foot, rest)
		for f in 64:
			BodyBake.pose(ctx, "", "p_stand", float(f) / 64.0)
	var failures: Array = ctx.get("fit_failures", [])
	assert_eq(failures.size(), 2, "128 bad frames give one STAND_UNFIT per leg")
	for failure: String in failures:
		assert_true(failure.begins_with("STAND_UNFIT p_stand "), failure)
	var records: Dictionary = ctx.get("stand_failures", {})
	assert_true(records.has("p_stand:R"), "averaging the pelvis drop leaves the other ankle unreachable")
	if records.has("p_stand:R"):
		var worst: float = records["p_stand:R"]["ankle_error"]
		assert_gt(worst, 0.001, "unreachable ankle is measured, not inferred from the target")
		rest.origin.x = 0.1
		body.set_bone_rest(foot, rest)
		BodyBake.pose(ctx, "", "p_stand", 0.0)
		assert_eq(float(records["p_stand:R"]["ankle_error"]), worst, "a less bad frame retains the worst error")
		rest.origin.x = 0.0
		body.set_bone_rest(foot, rest)
		BodyBake.pose(ctx, "", "p_stand", 0.0)
		assert_eq((ctx["fit_failures"] as Array).size(), 2, "a good frame cannot erase earlier failures")
	rest.origin.x = 0.2
	body.set_bone_rest(foot, rest)
	ctx["player"] = null
	var entry: Array = ["p_stand", "", 32, true, "p_stand", 2.5]
	var assets: Dictionary = BodyBake._bake_list(ctx, [entry], [])
	assert_eq((assets.get("fit_failures", []) as Array).size(), 2, "both failures reach the result consumed by the CLI")
	var own: Dictionary = BodyBake.bake_own(root, [entry], [])
	assert_eq((own.get("fit_failures", []) as Array).size(), 2, "the body-only path also forwards support failures")


func test_final_phase_checks_saved_sole_frames_for_both_orders_missing_and_late_steps() -> void:
	var root: Node3D = _stick_body_with_two_soles()
	add_child_autofree(root)
	var ctx: Dictionary = BodyBake.prepare_own(root)
	# Preserve the original soles as a garment bake does, then remove a foot
	# from the output mesh. The final checker must still use the body source.
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	mesh_node.set_meta(BodyBake.PERSON_PHASE_SOURCE, mesh_node.mesh.surface_get_arrays(0))
	var shell_root: Node3D = _stick_body()
	add_child_autofree(shell_root)
	mesh_node.mesh = (BodyBake.first_of(shell_root, "MeshInstance3D") as MeshInstance3D).mesh
	for pair: Array in [[0.2, 0.65], [0.65, 0.2], [0.45, 0.9], [-1.0, 0.65], [0.2, -1.0]]:
		var heights: Array = BodyBake._person_sole_heights_from_frames(ctx, _sole_frames(ctx, float(pair[0]), float(pair[1])))
		for clip: String in ["p_walk", "p_run"]:
			ctx["fit_failures"] = []
			BodyBake._check_person_phase_final(ctx, clip, heights)
			var failed: bool = float(pair[0]) < 0.0 or float(pair[1]) < 0.0 or (clip == "p_run" and float(pair[0]) == 0.45)
			var failures: Array = ctx["fit_failures"]
			assert_eq(failures.size(), 1 if failed else 0, "%s %s missing contacts fail, late walks only report" % [clip, str(pair)])
			for failure: String in failures:
				assert_true(failure.begins_with("PHASE_FINAL " + clip + " "), failure)
	assert_eq(BodyBake.person_contact_phase([0.0, INF, 0.02]), -1.0, "non-finite samples cannot establish a contact")


func test_a_saved_frame_contact_is_the_first_sole_vertex_s_own_crossing() -> void:
	# Heel just above the band then lifting, toe coming down: the lowest point switches vertex.
	var rows: Array = [PackedFloat32Array([0.05, 0.05]), PackedFloat32Array([0.0101, 0.04]), PackedFloat32Array([0.04, 0.0]), PackedFloat32Array([0.05, 0.05])]
	assert_almost_eq(BodyBake.person_contact_phase(rows), (1.0 + 0.75) / 4.0, 0.0001, "the toe enters three quarters of the way between frames 1 and 2")
	assert_almost_eq(BodyBake.person_contact_phase([0.05, 0.0101, 0.0, 0.05]), (1.0 + 0.0001 / 0.0101) / 4.0, 0.0001, "joining the lowest points would put it at frame 1")
	assert_eq(BodyBake.person_contact_phase([PackedFloat32Array([0.0, NAN]), PackedFloat32Array([0.02, 0.02])]), -1.0, "a non-finite vertex cannot establish a contact")


func test_final_round_returns_measured_reach_and_rejects_wrong_strides_for_all_twelve_clips() -> void:
	for clip: String in BodyBake.PERSON_STRIDE_ROUNDS:
		var target: float = BodyBake.PERSON_STRIDE_ROUNDS[clip]
		for scale: float in [1.0, 1.02]:
			var zs: Array = []
			for f in 8:
				zs.append(target * scale * (1.0 - float(f) / 8.0))
			var ctx: Dictionary = {"fit_failures": []}
			var measured: float = BodyBake._check_person_stride_final(ctx, clip, [zs, zs])
			assert_almost_eq(measured, target * scale, 0.000001, "return the actual round, even when refusing to save")
			var failures: Array = ctx["fit_failures"]
			assert_eq(failures.size(), 0 if scale == 1.0 else 1, clip + " 0.5 percent gate")
			for failure: String in failures:
				assert_true(failure.begins_with("STRIDE_FINAL " + clip + " "), failure)
		# One foot going back the whole round and the other standing still averages to the
		# rule's round; the gate still refuses it.
		var going: Array = []
		var still: Array = []
		for f in 8:
			going.append(target * (1.0 - float(f) / 8.0))
			still.append(0.0)
		var one: Dictionary = {"fit_failures": []}
		BodyBake._check_person_stride_final(one, clip, [going, still])
		var refused: Array = one["fit_failures"]
		assert_eq(refused.size(), 1, clip + " one foot still")
		if refused.size() == 1:
			assert_true(String(refused[0]).begins_with("STRIDE_FINAL " + clip + " one_foot "), refused[0])


func test_the_saved_round_is_the_motion_s_own_wherever_the_loop_starts() -> void:
	var entry: Array = BodyBake.PERSON_CLIPS[1]
	var probe: Node3D = _stick_body_with_two_soles()
	add_child_autofree(probe)
	var probe_ctx: Dictionary = BodyBake.prepare_own(probe)
	var raw_round: float = BodyBake._person_stride_round(probe_ctx, entry)
	assert_gt(raw_round, 0.0)
	if raw_round <= 0.0:
		return
	# A step-phase shift moves where the samples fall, not how far a foot goes back: on the
	# fine grid it stays inside the save gate (this stick: 0.36 % at most; on 24 frames up to 5 %).
	for shift: float in [0.13, 0.31, 0.5, 0.77]:
		var shifted: float = BodyBake._person_stride_round(probe_ctx, entry, shift)
		assert_almost_eq(shifted, raw_round, raw_round * BodyBake.STRIDE_TOLERANCE, "round at shift %.2f stays inside the 0.5 percent gate" % shift)
	# Calibrate body size, not the fit bounds, so this stick is a valid input.
	var root: Node3D = _stick_body_with_two_soles(float(BodyBake.PERSON_STRIDE_ROUNDS["p_run"]) / raw_round)
	add_child_autofree(root)
	var ctx: Dictionary = BodyBake.prepare_own(root)
	ctx["player"] = null
	var assets: Dictionary = BodyBake._bake_list(ctx, [entry], [])
	assert_false(assets.is_empty())
	if assets.is_empty():
		return
	assert_eq(assets.get("fit_failures", []), [], "normal shifted stick gait passes the final gates")
	assert_almost_eq(float(assets["clips"][0]["round"]), BodyBake._person_stride_round(ctx, entry), 0.000001, "clips round is the final legs' round on the fine grid")
	# A body 4 % too long in the legs: the fit turns the leg swing down to the rule's round.
	var long_root: Node3D = _stick_body_with_two_soles(float(BodyBake.PERSON_STRIDE_ROUNDS["p_run"]) / raw_round * 1.04)
	add_child_autofree(long_root)
	var long_ctx: Dictionary = BodyBake.prepare_own(long_root)
	long_ctx["player"] = null
	var before: float = BodyBake._person_stride_round(long_ctx, entry)
	assert_gt(absf(before / float(BodyBake.PERSON_STRIDE_ROUNDS["p_run"]) - 1.0), 0.03, "off the rule before the fit")
	var fitted: Dictionary = BodyBake._bake_list(long_ctx, [entry], [])
	assert_false(fitted.is_empty())
	if fitted.is_empty():
		return
	assert_eq(fitted.get("fit_failures", []), [], "a 4 percent long stride is fitted, not refused")
	assert_almost_eq(float(fitted["clips"][0]["round"]), float(BodyBake.PERSON_STRIDE_ROUNDS["p_run"]), float(BodyBake.PERSON_STRIDE_ROUNDS["p_run"]) * BodyBake.STRIDE_TOLERANCE, "fitted onto the rule's round")
	var fits: Dictionary = long_ctx["stride_fits"]
	var fit: Dictionary = fits.get(String(entry[4]), {})
	assert_lt(float(fit.get("scale", 1.0)), 0.99, "by turning the swing down")


func test_the_motions_written_here_alone_have_the_same_numbers_and_bake_with_no_motion_set() -> void:
	var names: Array = []
	for clip in BodyBake.CLIPS:
		names.append(clip[0])
	var own_names: Array = []
	for clip in BodyBake.OWN_CLIPS:
		own_names.append(clip[0])
		assert_eq(clip[1], "", "%s takes nothing from a motion set" % clip[0])
		assert_gt(float(clip[5]), 0.0, "and says how long it is")
		assert_true(BodyBake.LAYERS.has(clip[4]), "layer of %s" % clip[0])
	assert_eq(own_names, names, "the drawing side's numbers hold either way")
	assert_eq(BodyBake.OWN_POSES.size(), BodyBake.POSES.size())
	var root := _stick_body()
	add_child_autofree(root)
	var assets: Dictionary = BodyBake.bake_own(root)
	assert_false(assets.is_empty())
	assert_eq((assets["clips"] as Array).size(), BodyBake.OWN_CLIPS.size() + 1)
	assert_eq(String(assets["clips"][6]["name"]), "fall")
	assert_false(bool(assets["clips"][6]["loop"]))
	# The head's vertex: up at the start of the fall, near the ground at its end.
	var image: Image = assets["image"]
	var first: int = int(assets["clips"][6]["start"])
	var last: int = first + int(assets["clips"][6]["frames"]) - 1
	assert_gt(1.7 + image.get_pixel(1, first).g, 1.3, "standing as it starts to go over")
	assert_lt(1.7 + image.get_pixel(1, last).g, 0.6, "its head is down on the ground at the end")
	# The bake says how far a round of each walk carries the body, off this body's own feet.
	assert_gt(float(assets["clips"][0]["round"]), 0.5, "a walk covers ground")
	assert_gt(float(assets["clips"][7]["round"]), float(assets["clips"][0]["round"]), "the run more")
	assert_eq(float(assets["clips"][3]["round"]), 0.0, "standing covers none")
	assert_eq(float(assets["clips"][6]["round"]), 0.0, "nor does a motion played once")


func test_the_living_have_their_own_set_baked_with_no_still_poses() -> void:
	assert_lte(BodyBake.PERSON_CLIPS.size(), VatBaker.TABLE_SIZE, "the shader's clip tables")
	var written: Array = []
	for clip in BodyBake.PERSON_CLIPS:
		assert_true(String(clip[0]).begins_with("p_"), clip[0])
		assert_gt(float(clip[5]), 0.0, "%s says how long it is" % clip[0])
		if clip[1] == "":
			assert_true(BodyBake.LAYERS.has(clip[4]), "layer of %s" % clip[0])
			written.append(clip)
		else:
			assert_true(clip[4] == "" or BodyBake.LAYERS.has(clip[4]), "layer of %s" % clip[0])
	# Slots stay where they are when a clip's source changes (the field finds clips by name).
	assert_eq(String(BodyBake.PERSON_CLIPS[0][0]), "p_walk", "first slot")
	assert_eq(String(BodyBake.PERSON_CLIPS[1][0]), "p_run", "second slot")
	assert_eq(String(BodyBake.PERSON_CLIPS[2][0]), "p_stand", "third slot")
	var root := _stick_body()
	add_child_autofree(root)
	var assets: Dictionary = BodyBake.bake_own(root, written, [])
	assert_false(assets.is_empty())
	assert_eq((assets["clips"] as Array).size(), written.size(), "no still poses after them")
	assert_eq(String(assets["clips"][0]["name"]), "p_walk")
	assert_gt(float(assets["clips"][0]["round"]), 0.5, "a walk covers ground")
	assert_gt(float(assets["clips"][1]["round"]), float(assets["clips"][0]["round"]), "the run more")


func test_a_keyed_value_eases_from_key_to_key_and_holds_past_the_ends() -> void:
	var keys := ["keys", [[0.2, 1.0], [0.6, 3.0]]]
	assert_eq(BodyBake._value(keys, 0.0), 1.0)
	assert_almost_eq(BodyBake._value(keys, TAU * 0.4), 2.0, 0.001, "half way")
	assert_eq(BodyBake._value(keys, TAU * 0.9), 3.0)


func test_a_shorter_body_lies_on_the_ground_not_in_it() -> void:
	# Hips 0.85 m up, like a person 1.7 m tall: lowered as far in proportion
	# as the 1 m body, its hips end the fall above the ground.
	var root := _stick_body(0.85)
	add_child_autofree(root)
	var assets: Dictionary = BodyBake.bake_own(root)
	var image: Image = assets["image"]
	var fall: Dictionary = assets["clips"][6]
	var last: int = int(fall["start"]) + int(fall["frames"]) - 1
	var hips_y := 0.85 + image.get_pixel(2, last).g
	assert_almost_eq(hips_y, 0.85 * (1.0 - 0.84), 0.02, "the hips sink 0.84 of their height, as on the 1 m body")
	assert_gt(hips_y, 0.1, "not into the ground")


func test_a_round_is_what_a_foot_goes_back_in_a_frame_times_the_frames() -> void:
	# Forward for 16 frames and back for 16 at one pace, 0.6 m each way.
	var zs: Array = []
	for f in 32:
		zs.append(-0.3 + 0.6 * float(f) / 16.0 if f < 16 else 0.3 - 0.6 * float(f - 16) / 16.0)
	assert_almost_eq(BodyBake.round_of(zs), 1.2, 0.001)
	# The same foot, slowing where it turns round: the ends are left out.
	zs[16] = 0.29
	zs[0] = -0.29
	assert_almost_eq(BodyBake.round_of(zs), 1.2, 0.001)
	assert_eq(BodyBake.round_of([0.1, 0.1, 0.1, 0.1]), 0.0, "a foot that stays covers none")


## The stick body wearing a skin of three pieces: a square on the chest cut in
## two along a seam, so its corners there are split as an exported body's are;
## a triangle on the head; one on the left hand. Each in its own corner of the
## colour picture.
func _dressed_body() -> Node3D:
	var root := _stick_body()
	var body := BodyBake.first_of(root, "Skeleton3D") as Skeleton3D
	var chest := body.find_bone("chest")
	var head := body.find_bone("head")
	var hand := body.find_bone("hand.L")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.1, 1.3, 0.1), Vector3(0.1, 1.3, 0.1), Vector3(0.1, 1.5, 0.1),
		Vector3(-0.1, 1.3, 0.1), Vector3(0.1, 1.5, 0.1), Vector3(-0.1, 1.5, 0.1),
		Vector3(0.0, 1.75, 0.1), Vector3(0.05, 1.85, 0.1), Vector3(-0.05, 1.85, 0.1),
		Vector3(0.8, 1.45, 0.0), Vector3(0.9, 1.45, 0.0), Vector3(0.85, 1.55, 0.0)])
	var normals := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for v in 12:
		normals.append(Vector3.BACK)
		bones.append_array([chest if v < 6 else (head if v < 9 else hand), 0, 0, 0])
		weights.append_array([1, 0, 0, 0])
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.05, 0.05), Vector2(0.45, 0.05), Vector2(0.45, 0.45),
		Vector2(0.05, 0.05), Vector2(0.45, 0.45), Vector2(0.05, 0.45),
		Vector2(0.55, 0.05), Vector2(0.95, 0.05), Vector2(0.75, 0.45),
		Vector2(0.55, 0.55), Vector2(0.95, 0.55), Vector2(0.75, 0.95)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	(BodyBake.first_of(root, "MeshInstance3D") as MeshInstance3D).mesh = mesh
	return root


func test_a_garment_is_the_body_s_skin_where_it_covers_welded_and_pushed_out() -> void:
	var root := _dressed_body()
	add_child_autofree(root)
	assert_false(BodyBake.shell(root, "no_such_garment"))
	assert_true(BodyBake.shell(root, "jacket_short"))
	var arrays: Array = (BodyBake.first_of(root, "MeshInstance3D") as MeshInstance3D).mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(pos.size(), 4, "the chest square alone, its split corners made one")
	assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 6, "both its halves")
	var push: float = BodyBake.SHELLS["jacket_short"]["push"]
	for v in pos:
		assert_almost_eq(v.z, 0.1 + push, 0.0001, "pushed out the way the chest faces")
	var chest := (BodyBake.first_of(root, "Skeleton3D") as Skeleton3D).find_bone("chest")
	assert_eq((arrays[Mesh.ARRAY_BONES] as PackedInt32Array)[0], chest, "moving with the chest")
	var hat := _dressed_body()
	add_child_autofree(hat)
	assert_true(BodyBake.shell(hat, "hat_knit"))
	var hat_pos: PackedVector3Array = (BodyBake.first_of(hat, "MeshInstance3D") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(hat_pos.size(), 3, "the head alone")


func test_gloves_paint_the_hands_in_the_colour_picture_and_leave_the_rest() -> void:
	var root := _dressed_body()
	add_child_autofree(root)
	var albedo := Image.create(64, 64, false, Image.FORMAT_RGB8)
	albedo.fill(Color(0.8, 0.7, 0.6))
	var out := BodyBake.gloved(root, albedo, Color(0.2, 0.2, 0.2))
	assert_not_null(out)
	assert_almost_eq(out.get_pixel(48, 52).r, 0.2, 0.01, "on the hand")
	assert_almost_eq(out.get_pixel(16, 16).r, 0.8, 0.01, "not the chest")
	assert_almost_eq(out.get_pixel(48, 16).r, 0.8, 0.01, "nor the head")
	assert_almost_eq(albedo.get_pixel(48, 52).r, 0.8, 0.01, "the picture it was given is left as it was")


# For the shader's gloves (decision 434): the hands marked in the vertex colour
# where gloved() paints, the picture's light there kept with the mesh, and
# nothing else of it changed, so the motion picture reads it as before; a body
# marked before it is baked carries the marks.
func test_the_hands_are_marked_for_the_shader_and_the_rest_left_as_it_was() -> void:
	var root := _dressed_body()
	add_child_autofree(root)
	var marks := BodyBake.hand_marks(root)
	assert_eq(marks.size(), 12)
	for v in 12:
		assert_eq(marks[v].a, 1.0 if v >= 9 else 0.0, "vertex %d on the hand or not" % v)
		assert_eq(marks[v].r, 1.0, "white, so the colour each body is drawn in shows as it is")
	var mesh := (BodyBake.first_of(root, "MeshInstance3D") as MeshInstance3D).mesh
	var albedo := Image.create(64, 64, false, Image.FORMAT_RGB8)
	albedo.fill(Color(0.8, 0.7, 0.6))
	var light := BodyBake.hand_light(mesh, marks, albedo)
	assert_almost_eq(light, Color(0.8, 0.7, 0.6).get_luminance(), 0.01, "the picture's light at the hands")
	var marked := BodyBake.with_hand_marks(mesh, marks, light)
	var before: Array = mesh.surface_get_arrays(0)
	var after: Array = marked.surface_get_arrays(0)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX, Mesh.ARRAY_BONES]:
		assert_eq(after[slot], before[slot], "slot %d the same, in the same order" % slot)
	assert_eq((after[Mesh.ARRAY_COLOR] as PackedColorArray)[10].a, 1.0)
	assert_almost_eq(float(marked.get_meta(BodyBake.HAND_LIGHT)), light, 0.0001)
	assert_null(BodyBake.with_hand_marks(mesh, PackedColorArray([Color.WHITE]), 0.0), "marks of another mesh")
	assert_eq(BodyBake.mark_hands(root), marks)
	var colours = (BodyBake.first_of(root, "MeshInstance3D") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_eq(colours, marks, "the body to bake has them")


func test_walk_saved_stride_uses_rolling_skin_support_and_rejects_wrong_slope() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var bind_bone: Array = ctx["bind_bone"]
	var frames: Array = []
	var too_long: Array = []
	for frame in 32:
		var u: float = float(frame) / 32.0
		var skin: Array = BodyBake._skin_frame(ctx)
		for side in 2:
			var bone: int = int(fit["legs"][side][2])
			var bind: int = bind_bone.find(bone)
			var ankle: Vector3 = fit["rest_ankles"][side]
			var angle: float = 0.25 * sin(TAU * u + float(side))
			var basis: Basis = Basis(Vector3.RIGHT, angle)
			skin[bind] = Transform3D(basis, ankle - basis * ankle)
		for side in 2:
			var bind: int = bind_bone.find(int(fit["legs"][side][2]))
			var probe: Dictionary = BodyBake._person_footlock_probes(fit, skin)[side]
			var point: Vector3 = probe["point"]
			var rest: Vector3 = probe["rest"]
			var age: float = fposmod(u - float(fit["starts"][side]), 1.0)
			var transform: Transform3D = skin[bind]
			transform.origin.z += -1.64 * age - (point.z - rest.z)
			skin[bind] = transform
		frames.append(skin)
		var longer: Array = skin.duplicate()
		for side in 2:
			var bind: int = bind_bone.find(int(fit["legs"][side][2]))
			var transform: Transform3D = longer[bind]
			var age: float = fposmod(u - float(fit["starts"][side]), 1.0)
			transform.origin.z -= 0.02 * 1.64 * age
			longer[bind] = transform
		too_long.append(longer)
	ctx["fit_failures"] = []
	var measured: float = BodyBake._check_person_stride_final(ctx, "p_walk", frames, fit)
	assert_almost_eq(measured, 1.64, 1.64 * 0.005, "rolling support stride is measured from saved frames")
	assert_eq((ctx["fit_failures"] as Array).size(), 0, "correct support travel passes")
	BodyBake._check_person_stride_final(ctx, "p_walk", too_long, fit)
	assert_eq((ctx["fit_failures"] as Array).size(), 1, "two percent wrong support travel is refused")


func test_walk_final_reach_failure_is_counted_separately_from_intermediate_clamps() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var body: Skeleton3D = ctx["body"]
	var leg: Array = fit["legs"][0]
	var hip: Vector3 = body.get_bone_global_pose(int(leg[0])).origin
	var far: Dictionary = BodyBake._person_walk_reach_info(body, leg, hip + Vector3(0.0, -3.0, 0.0))
	assert_gt(float(far["excess"]), 0.0, "unreachable final target has positive excess")
	var u: float = 0.3
	BodyBake.pose(ctx, "", "p_walk", u)
	var before: Array = BodyBake._person_footlock_points(fit, BodyBake._skin_frame(ctx))
	var drop: float = BodyBake._apply_person_walk_body(ctx, fit, u, u, "p_walk")
	var misses: Array = BodyBake._apply_person_footlock(ctx, fit, u)
	var after: Array = BodyBake._person_footlock_probes(fit, BodyBake._skin_frame(ctx))
	fit["reach_clamped"] = [true, true]
	fit["reach_final_failed"] = [false, true]
	var stats: Array = BodyBake._person_footlock_stats()
	BodyBake._note_person_footlock(ctx, fit, u, before, after, misses, stats, drop)
	assert_eq(int(stats[0]["reach_clamp_frames"]), 1, "intermediate clamp retained")
	assert_eq(int(stats[0]["reach_final_fail_frames"]), 0, "recovered final target")
	assert_eq(int(stats[1]["reach_final_fail_frames"]), 1, "failed final target counted")


func test_walk_stride_refit_samples_the_shifted_phase() -> void:
	var entry: Array = BodyBake.PERSON_CLIPS[0]
	var shift: float = 0.0137
	var probe: Node3D = _stick_body_with_two_soles()
	add_child_autofree(probe)
	var probe_ctx: Dictionary = BodyBake.prepare_own(probe, [entry])
	var raw: float = BodyBake._person_stride_round(probe_ctx, entry, shift)
	assert_gt(raw, 0.0, "stick walk has measurable stride")
	if raw <= 0.0:
		return
	var root: Node3D = _stick_body_with_two_soles(float(BodyBake.PERSON_STRIDE_ROUNDS["p_walk"]) / raw)
	add_child_autofree(root)
	var ctx: Dictionary = BodyBake.prepare_own(root, [entry])
	ctx["fit_failures"] = []
	BodyBake._fit_person_stride(ctx, entry, shift)
	var measured: float = BodyBake._person_stride_round(ctx, entry, shift)
	assert_almost_eq(measured, float(BodyBake.PERSON_STRIDE_ROUNDS["p_walk"]), float(BodyBake.PERSON_STRIDE_ROUNDS["p_walk"]) * BodyBake.STRIDE_TOLERANCE, "fit and sample use the same shifted phase")
	assert_eq((ctx["fit_failures"] as Array).size(), 0, "shifted stride fit stays within its bounds")


func test_walk_height_bounds_accept_corrected_targets_for_both_legs() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var u: float = 0.0
	BodyBake.pose(ctx, "", "p_walk", u)
	BodyBake._apply_person_walk_turn(ctx, fit, u, u, "p_walk")
	var original: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, u)
	var targets: Array = []
	for side in 2:
		var goal: Dictionary = BodyBake._person_walk_ankle_goal(fit, side, u)
		var target: Vector3 = goal["target"]
		target.y -= 0.3
		targets.append(target)
	var corrected: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, u, targets)
	assert_lt(float(corrected["upper"]), float(original["upper"]) - 0.1, "both corrected ankle targets lower the reachable ceiling")


## Short legs and mixed sole weights belong only to these regression fixtures.
func _walk_feedback_context(bent: bool = false) -> Dictionary:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var body: Skeleton3D = ctx["body"]
	var a: float = 0.391
	var b: float = 0.374
	var r15: float = sqrt(a * a + b * b + 2.0 * a * b * cos(deg_to_rad(15.0)))
	var height: float = r15 - 0.000679 if bent else a + b
	var knee_y: float = (a * a + height * height - b * b) / (2.0 * height)
	var knee_z: float = sqrt(maxf(0.0, a * a - knee_y * knee_y))
	body.set_bone_rest(body.find_bone("hips"), Transform3D(Basis(), Vector3(0.0, height, 0.0)))
	var rest: PackedVector3Array = fit["rest"]
	var bones: PackedInt32Array = fit["bones"]
	var weights: PackedFloat32Array = fit["weights"]
	for side in 2:
		var leg: Array = fit["legs"][side]
		body.set_bone_rest(int(leg[1]), Transform3D(Basis(), Vector3(0.0, -knee_y, knee_z)))
		body.set_bone_rest(int(leg[2]), Transform3D(Basis(), Vector3(0.0, knee_y - height, -knee_z)))
		var ankle: Vector3 = body.get_bone_global_rest(int(leg[2])).origin
		fit["rest_ankles"][side] = ankle
		fit["anchors"][side] = body.get_bone_global_rest(int(leg[0])).origin - Vector3(0.0, 0.0, BodyBake.PERSON_WALK_FOOTPRINT_BACK)
		for vertex: int in fit["soles"][side]:
			var offset: Vector3 = rest[vertex] - Vector3(0.1 if side == 0 else -0.1, 0.0, 0.0)
			# Unequal heel/toe distances on each side, with an exactly flat sole.
			offset.z *= 1.0 if side == 0 else 0.8
			rest[vertex] = ankle + offset
			for slot in 4:
				bones[vertex * 4 + slot] = int(leg[2 - slot]) if slot < 3 else 0
				weights[vertex * 4 + slot] = [0.65, 0.30, 0.05, 0.0][slot]
		assert_almost_eq(body.get_bone_global_rest(int(leg[0])).origin.distance_to(body.get_bone_global_rest(int(leg[1])).origin), a, 0.000001, "fixture thigh length")
		assert_almost_eq(body.get_bone_global_rest(int(leg[1])).origin.distance_to(ankle), b, 0.000001, "fixture shin length")
	fit["rest"] = rest
	fit["bones"] = bones
	fit["weights"] = weights
	fit["rest_hips_y"] = height
	fit["stand_ref_m"] = height - float(fit["floor"])
	body.reset_bone_poses()
	var skin: Skin = ctx["skin"]
	for bind in skin.get_bind_count():
		skin.set_bind_pose(bind, body.get_bone_global_rest(skin.get_bind_bone(bind)).affine_inverse())
	ctx["fit_failures"] = []
	ctx["walk_clip"] = "p_walk"
	return ctx


func _walk_feedback_frame(ctx: Dictionary, u: float, seed_offset: Vector3 = Vector3.ZERO, iteration_limit: int = BodyBake.PERSON_WALK_SKIN_EVALUATIONS, accelerate: bool = true) -> Dictionary:
	var fit: Dictionary = ctx["footlock_walk"]
	var body: Skeleton3D = ctx["body"]
	body.reset_bone_poses()
	var targets: Array = []
	for side in 2:
		targets.append((BodyBake._person_walk_ankle_goal(fit, side, u)["target"] as Vector3) + seed_offset)
	var bounds: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, u, targets)
	if bool(bounds["empty"]):
		return {}
	fit["pelvis"] = {"values": PackedFloat64Array([bounds["upper"]]), "slopes": PackedFloat64Array([0.0])}
	ctx["fit_failures"] = []
	return BodyBake._solve_person_walk_frame(ctx, fit, u, targets, iteration_limit, accelerate)


func test_walk_skin_feedback_refits_both_targets_before_ik() -> void:
	var ctx: Dictionary = _walk_feedback_context()
	var fit: Dictionary = ctx["footlock_walk"]
	# Fixed fixture, bounded phase witnesses; never skip a missing premise.
	for sample in 32:
		var result: Dictionary = _walk_feedback_frame(ctx, float(sample) / 32.0)
		if result.is_empty() or not bool(result["ok"]):
			continue
		var passes: Array = result["passes"]
		var first: Dictionary = passes[0]
		var excess: float = 0.0
		for info: Dictionary in first["proposal_reach"]:
			excess = maxf(excess, float(info["excess"]))
		if excess <= 0.0:
			continue
		assert_false(bool(first["bounds"]["empty"]), "premise: rigid pair is feasible")
		assert_gt(excess, 0.0, "premise: skin proposal exhausts reach at the old height")
		assert_gt(passes.size(), 1, "skin correction needs another paired solve")
		assert_lte(int(result["ik_passes"]), BodyBake.PERSON_WALK_SKIN_EVALUATIONS, "rejected evaluations also consume the cap")
		for side in 2:
			assert_gt((first["targets_used"][side] as Vector3).distance_to(first["proposed_targets"][side]), 0.000001, "both feet have real skin feedback")
		var previous: Dictionary = first
		for pass_id in range(1, passes.size()):
			var alpha: float = passes[pass_id]["omega"]
			assert_gte(alpha, BodyBake.PERSON_WALK_AITKEN_MIN)
			assert_lte(alpha, BodyBake.PERSON_WALK_AITKEN_MAX)
			for side in 2:
				var expected_target: Vector3 = (previous["targets_used"][side] as Vector3).lerp(previous["proposed_targets"][side], alpha)
				assert_lt(expected_target.distance_to(passes[pass_id]["targets_used"][side]), 0.000001, "both targets advance with the same damping step")
			if bool(passes[pass_id]["accepted"]):
				assert_lt(float(passes[pass_id]["normalized_residual"]), float(previous["normalized_residual"]), "actual measured residual decreases")
				previous = passes[pass_id]
		for pass_note: Dictionary in passes:
			if not bool(pass_note["evaluated"]):
				continue
			assert_false(bool(pass_note["bounds"]["empty"]), "paired interval before every IK")
			assert_gte(float(pass_note["height"]), float(pass_note["bounds"]["lower"]), "height meets both lower bounds")
			assert_lte(float(pass_note["height"]), float(pass_note["bounds"]["upper"]), "height meets both upper bounds")
			for side in 2:
				assert_false(bool(pass_note["pre_reach"][side]["invalid"]))
				assert_eq(float(pass_note["pre_reach"][side]["excess"]), 0.0, "both targets reachable before either IK")
				var goal: Dictionary = BodyBake._person_walk_ankle_goal(fit, side, float(sample) / 32.0)
				var probe: Dictionary = pass_note["probes"][side]
				var offset: Vector3 = (probe["point"] as Vector3) - (pass_note["actual_ankles"][side] as Vector3)
				var expected: Vector3 = goal["base"] + (probe["rest"] as Vector3) - (fit["rest_ankles"][side] as Vector3) - offset
				expected.y = float(fit["floor"]) + (goal["path"] as Vector3).y - offset.y
				assert_lt(expected.distance_to(pass_note["proposed_targets"][side]), 0.000001, "both proposals use the same post-IK skin")
		assert_eq(fit["reach_clamped"], [false, false], "no intermediate cuts")
		assert_eq(fit["reach_final_failed"], [false, false], "no final target failures")
		assert_lte(float(result["skin_residual"]), BodyBake.PERSON_WALK_SKIN_TOL_M, "undamped target residual")
		assert_lte(float(result["height_residual"]), BodyBake.PERSON_WALK_SKIN_HEIGHT_TOL_M, "next height residual")
		assert_true((ctx["fit_failures"] as Array).is_empty(), "converged frame is accepted")
		return
	assert_true(false, "mixed skin must provide a convergent corrected-reach witness")


func test_walk_last_skin_proposal_is_not_reported_as_solved() -> void:
	var ctx: Dictionary = _walk_feedback_context()
	var fit: Dictionary = ctx["footlock_walk"]
	# One pass leaves the deliberate lateral seed error unresolved.
	var result: Dictionary = _walk_feedback_frame(ctx, 0.0, Vector3(0.12, 0.0, 0.0), 1)
	assert_false(result.is_empty(), "premise: fixed phase has a feasible seeded interval")
	if result.is_empty():
		return
	assert_eq(BodyBake.PERSON_WALK_SOLVE_PASSES, 6, "legacy fixed-point count stays six")
	assert_eq(BodyBake.PERSON_WALK_SKIN_EVALUATIONS, 12, "paired evaluation cap includes rejected trials")
	assert_false(bool(result["ok"]), "nonconvergence is not solved")
	assert_eq(result["reason"], "SKIN_ITER_LIMIT", "last unsolved proposal exhausts the test budget")
	assert_eq(int(result["ik_passes"]), 1, "exactly the requested paired IK budget")
	assert_eq((result["passes"] as Array).size(), 1, "no hidden solve after the limit")
	assert_eq(fit["reach_clamped"], [false, false], "premise: no distance cut needed")
	assert_gt(float(result["skin_residual"]), BodyBake.PERSON_WALK_SKIN_TOL_M, "premise: last proposal still changes")
	for side: int in 2:
		assert_lt((result["actual_ankles"][side] as Vector3).distance_to(result["targets_used"][side]), 0.0001, "ankle solves the used target")
		assert_almost_eq(float(result["misses"][side]), (result["actual_ankles"][side] as Vector3).distance_to(result["targets_used"][side]), 0.000001, "miss is measured against used target")
	assert_ne(result["targets_used"], result["proposed_targets"], "last proposal is recorded separately")
	assert_eq((ctx["fit_failures"] as Array).size(), 1, "nonconvergence reaches save refusal")
	assert_true(str(ctx["fit_failures"][0]).begins_with("WALK_SOLVE_FAIL "))
	assert_true(str(ctx["fit_failures"][0]).contains("reason=SKIN_ITER_LIMIT"))


func test_walk_rest_cap_fix_covers_entire_mid_window() -> void:
	var ctx: Dictionary = _walk_feedback_context(true)
	var fit: Dictionary = ctx["footlock_walk"]
	fit["hip_over_stand_allowed"] = false
	var body: Skeleton3D = ctx["body"]
	var hip: Vector3 = body.get_bone_global_pose(int(fit["legs"][0][0])).origin
	var duration: float = fit["durations"][0]
	var start: float = fit["starts"][0]
	# One constant centre fixes entry, but the same -1.64 slope crosses the hip later.
	var centre: float = 0.04 - 1.64 * duration * 0.1
	var rejected: int = 0
	for t: float in [0.4, 0.45, 0.5, 0.55, 0.6]:
		var target: Vector3 = Vector3(hip.x, 0.0, hip.z + centre + 1.64 * duration * (0.5 - t))
		var other: Vector3 = body.get_bone_global_pose(int(fit["legs"][1][0])).origin + Vector3(0.0, -0.5, 0.0)
		var bounds: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, start + duration * t, [target, other])
		if t == 0.4:
			assert_false(bool(bounds["empty"]), "premise: the single-phase repair works at entry")
		if bool(bounds["empty"]):
			rejected += 1
			assert_gt(float(bounds["lower"]), float(bounds["upper"]), "keep the conflicting interval")
			assert_eq(int(bounds["lower_side"]), 0, "mid-stance leg owns the lower bound")
			assert_eq(int(bounds["upper_side"]), -1, "rest cap owns the upper bound")
	assert_gt(rejected, 0, "a later middle phase rejects the one-phase fix")


func test_walk_rest_cap_tolerance_covers_entire_mid_window() -> void:
	var ctx: Dictionary = _walk_feedback_context(true)
	var fit: Dictionary = ctx["footlock_walk"]
	fit["hip_over_stand_allowed"] = true
	var body: Skeleton3D = ctx["body"]
	var hip: Vector3 = body.get_bone_global_pose(int(fit["legs"][0][0])).origin
	var duration: float = fit["durations"][0]
	var start: float = fit["starts"][0]
	var centre: float = 0.04 - 1.64 * duration * 0.1
	var strict_conflicts: int = 0
	var reach_limited: int = 0
	var stand_cap: float = float(fit["rest_hips_y"]) + 0.0012
	assert_almost_eq(stand_cap, 0.75897956482943, 0.000000001)
	for t: float in [0.4, 0.45, 0.5, 0.55, 0.6]:
		var target: Vector3 = Vector3(hip.x, 0.0, hip.z + centre + 1.64 * duration * (0.5 - t))
		var other: Vector3 = body.get_bone_global_pose(int(fit["legs"][1][0])).origin + Vector3(0.0, -0.5, 0.0)
		var bounds: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, start + duration * t, [target, other])
		assert_false(bool(bounds["empty"]), "the explicit tolerance opens every middle sample")
		# The rest cap competes with each leg's four-degree reach sphere.
		var expected_upper: float = stand_cap
		var targets: Array[Vector3] = [target, other]
		var hips: Vector3 = body.get_bone_global_pose(body.find_bone("hips")).origin
		for side: int in 2:
			var leg: Array = fit["legs"][side]
			var thigh: Vector3 = body.get_bone_global_pose(int(leg[0])).origin
			var shin: Vector3 = body.get_bone_global_pose(int(leg[1])).origin
			var ankle: Vector3 = body.get_bone_global_pose(int(leg[2])).origin
			var a: float = thigh.distance_to(shin)
			var b: float = shin.distance_to(ankle)
			var horizontal: float = Vector2(thigh.x - targets[side].x, thigh.z - targets[side].z).length_squared()
			var reach_cap: float = targets[side].y - (thigh - hips).y + sqrt(a * a + b * b + 2.0 * a * b * cos(BodyBake.PERSON_WALK_KNEE_MIN) - horizontal) - 0.001
			expected_upper = minf(expected_upper, reach_cap)
		assert_almost_eq(float(bounds["upper"]), expected_upper, 0.000000001)
		if expected_upper < stand_cap:
			reach_limited += 1
		if float(bounds["lower"]) > float(fit["rest_hips_y"]):
			strict_conflicts += 1
	assert_gt(strict_conflicts, 0, "the tolerance is necessary for this fixture")
	assert_eq(reach_limited, 2, "the last two samples are limited by leg reach")


func test_walk_exhausted_search_refuses_unfit_bake() -> void:
	# Only the empty-interval part is in scope; path search comes later.
	var ctx: Dictionary = _walk_feedback_context(true)
	var fit: Dictionary = ctx["footlock_walk"]
	var body: Skeleton3D = ctx["body"]
	var u: float = float(fit["starts"][0]) + 0.5 * float(fit["durations"][0])
	fit["rest_hips_y"] = 0.5
	var targets: Array = []
	for side in 2:
		targets.append(BodyBake._person_walk_ankle_goal(fit, side, u)["target"])
	var bounds: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, u, targets)
	assert_gt(float(bounds["lower"]), float(bounds["upper"]), "premise: genuinely empty interval")
	assert_true(bool(bounds["empty"]))
	fit["pelvis"] = {"values": PackedFloat64Array([0.5]), "slopes": PackedFloat64Array([0.0])}
	var before: Transform3D = body.get_bone_global_pose(body.find_bone("hips"))
	var result: Dictionary = BodyBake._solve_person_walk_frame(ctx, fit, u, targets)
	assert_false(bool(result["ok"]))
	assert_eq(result["reason"], "POINT_EMPTY")
	assert_eq(int(result["ik_passes"]), 0, "empty interval never reaches IK")
	assert_gt(float(result["bounds"]["lower"]), float(result["bounds"]["upper"]), "failure retains L > U")
	assert_eq(body.get_bone_global_pose(body.find_bone("hips")), before, "no fabricated clamped height")
	assert_eq((ctx["fit_failures"] as Array).size(), 1, "failure reaches the existing save refusal")
	assert_true(str(ctx["fit_failures"][0]).contains("reason=POINT_EMPTY"))
	var table: Dictionary = BodyBake._fit_person_walk_height(ctx, fit, BodyBake.PERSON_CLIPS[0], 0.0)
	assert_gt((table["failed_samples"] as PackedInt32Array).size(), 0, "infeasible cycle is retained as failure")
	assert_true((table["values"] as PackedFloat64Array).is_empty(), "no folded single-value solution is published")
	body.reset_bone_poses()
	var hip: Vector3 = body.get_bone_global_pose(int(fit["legs"][0][0])).origin
	var far: Array = [hip + Vector3(2.0, 0.0, 0.0), targets[1]]
	var far_bounds: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, 0.0, far)
	assert_true(bool(far_bounds["empty"]), "horizontal unreachability is not sqrt-clamped away")
	assert_eq(far_bounds["per_side"][0]["reason"], "HORIZONTAL_REACH")
	var near_bounds: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, 0.0, [hip, targets[1]])
	assert_gt(float(near_bounds["per_side"][0]["lower"]), hip.y + 0.0169, "internal radius enforces the positive-branch lower bound")


func test_walk_height_mean_is_raised_within_ceilings_or_reported_unfit() -> void:
	var values: PackedFloat64Array = PackedFloat64Array([0.8, 0.9])
	var ceilings: PackedFloat64Array = PackedFloat64Array([1.0, 0.95])
	var fitted: Dictionary = BodyBake._person_walk_raise_mean(values, ceilings, 0.95)
	var raised: PackedFloat64Array = fitted["values"]
	assert_true(bool(fitted["feasible"]), "a feasible mean is reached")
	assert_almost_eq(float(fitted["mean"]), 0.95, 0.00000001, "mean is the requested height")
	assert_lte(raised[0], ceilings[0], "first height stays below its ceiling")
	assert_lte(raised[1], ceilings[1], "second height stays below its ceiling")
	var impossible: Dictionary = BodyBake._person_walk_raise_mean(values, ceilings, 1.1)
	assert_false(bool(impossible["feasible"]), "an impossible mean is reported")
	assert_almost_eq(float(impossible["mean"]), 0.975, 0.00000001, "best ceiling-limited mean is retained")


func test_walk_stick_height_table_meets_mean_constraint_when_feasible() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var table: Dictionary = fit["pelvis"]
	var heights: PackedFloat64Array = table["values"]
	var total: float = 0.0
	for height: float in heights:
		total += height
	var mean: float = total / float(heights.size())
	var minimum: float = float(fit["floor"]) + 0.95 * float(fit["stand_ref_m"])
	assert_true(bool(table["mean_feasible"]), "stick height table has a feasible 95 percent mean")
	assert_gte(mean + 0.000000001, minimum, "fitted sample mean reaches the 95 percent constraint")
	assert_almost_eq(float(table["mean"]), mean, 0.000000001, "recorded mean matches the fitted table")


func test_walk_empty_height_table_records_direct_and_solver_failures() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	ctx["rig_label"] = "empty_table_stick"
	ctx["walk_clip"] = "p_walk"
	ctx["fit_failures"] = []
	fit["rest_hips_y"] = 0.5
	var table: Dictionary = BodyBake._fit_person_walk_height(ctx, fit, BodyBake.PERSON_CLIPS[0], 0.0)
	fit["pelvis"] = table
	assert_true((table["values"] as PackedFloat64Array).is_empty(), "premise: failed cycle publishes no heights")
	assert_gt((table["failed_samples"] as PackedInt32Array).size(), 0, "empty table comes from infeasible intervals")
	assert_true(is_nan(BodyBake._person_walk_height_at(table, 0.0)), "direct query returns an invalid sentinel without modulo")
	assert_true(is_nan(BodyBake._person_walk_height_at(table, 1.0)), "seam query is guarded too")
	assert_true((ctx["fit_failures"] as Array).has("PELVIS_TABLE_EMPTY rig=empty_table_stick clip=p_walk phase=0.000000000 cause=POINT_EMPTY"), "direct query retains the originating refusal sink")
	ctx["walk_clip"] = "p_walk_pistol"
	BodyBake.pose(ctx, "", "p_walk_pistol", 0.0)
	var body: Skeleton3D = ctx["body"]
	var before_y: float = body.get_bone_global_pose(body.find_bone("hips")).origin.y
	BodyBake._apply_person_walk_body(ctx, fit, 0.0, 0.0, "p_walk_pistol")
	assert_almost_eq(body.get_bone_global_pose(body.find_bone("hips")).origin.y, before_y, 0.000001, "invalid height never reaches the skeleton")
	var result: Dictionary = BodyBake._solve_person_walk_frame(ctx, fit, 0.0)
	assert_false(bool(result["ok"]), "empty table cannot produce a saved frame")
	assert_eq(result["reason"], "PELVIS_TABLE_EMPTY")
	assert_eq(int(result["ik_passes"]), 0, "no IK without a height table")
	assert_true((ctx["fit_failures"] as Array).has("PELVIS_TABLE_EMPTY rig=empty_table_stick clip=p_walk_pistol phase=0.000000000 cause=POINT_EMPTY"), "shared table reports the current clip")
	assert_true(is_nan(BodyBake._person_walk_height_at({}, 0.25, ctx)), "unbuilt tables are guarded too")
	assert_true((ctx["fit_failures"] as Array).has("PELVIS_TABLE_EMPTY rig=empty_table_stick clip=p_walk_pistol phase=0.250000000 cause=NOT_BUILT"))


func test_walk_paired_solver_preserves_saved_stride_final() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	ctx["fit_failures"] = []
	for entry: Array in BodyBake.PERSON_CLIPS:
		if not BodyBake.PERSON_FOOT_LOCK.has(entry[0]):
			continue
		ctx["walk_clip"] = entry[0]
		var frames: Array = []
		for frame: int in int(entry[2]):
			var u: float = float(frame) / float(entry[2])
			BodyBake.pose(ctx, entry[1], entry[4], u)
			BodyBake._apply_person_walk_body(ctx, fit, u, u, entry[4])
			BodyBake._apply_person_footlock(ctx, fit, u)
			assert_true(bool(fit["walk_solve"]["ok"]), "%s frame %d solves before saving" % [entry[0], frame])
			frames.append(BodyBake._skin_frame(ctx))
		var measured: float = BodyBake._check_person_stride_final(ctx, entry[0], frames, fit)
		assert_almost_eq(measured, 1.64, 1.64 * 0.005, "%s paired solve keeps the saved support stride" % entry[0])
	assert_true((ctx["fit_failures"] as Array).is_empty(), "all six actual saved walks pass the unchanged stride gate")


func test_walk_mean_gate_checks_saved_frames_as_well_as_256_knots() -> void:
	var phases: PackedFloat64Array = PackedFloat64Array()
	var lowers: PackedFloat64Array = PackedFloat64Array()
	var uppers: PackedFloat64Array = PackedFloat64Array()
	var cap_sum: float = 0.0
	for sample in 256:
		phases.append(float(sample) / 256.0)
		lowers.append(0.8)
		uppers.append(0.94 if sample % 8 == 0 else 1.0)
		cap_sum += uppers[sample]
	assert_almost_eq(cap_sum / 256.0, 0.9925, 0.000000001, "premise: grid mean alone is feasible")
	var rejected: Dictionary = BodyBake._person_walk_project_table(phases, lowers, uppers, 0.95)
	assert_false(bool(rejected["ok"]), "saved samples cannot reach 95 percent")
	assert_eq(rejected["reason"], "MEAN_SAVED_CAP")
	assert_true((rejected["values"] as PackedFloat64Array).is_empty(), "no low-mean table published")
	uppers.fill(0.95)
	var boundary: Dictionary = BodyBake._person_walk_project_table(phases, lowers, uppers, 0.95)
	assert_true(bool(boundary["ok"]), "exactly 95 percent remains feasible")
	assert_gte(float(boundary["mean"]) + 0.000000001, 0.95)
	assert_gte(float(boundary["saved_mean"]) + 0.000000001, 0.95)
	for u: float in phases:
		assert_lte(BodyBake._person_walk_height_at(boundary, u), 0.95000001, "boundary never exceeds its cap")


func test_walk_projected_spline_obeys_off_grid_bounds_and_periodic_weights() -> void:
	var phases: PackedFloat64Array = PackedFloat64Array()
	var lowers: PackedFloat64Array = PackedFloat64Array()
	var uppers: PackedFloat64Array = PackedFloat64Array()
	for sample in 256:
		phases.append(float(sample) / 256.0)
		lowers.append(0.93)
		uppers.append(1.0)
	phases.append(0.412)
	lowers.append(0.955)
	uppers.append(0.96)
	var table: Dictionary = BodyBake._person_walk_project_table(phases, lowers, uppers, 0.95)
	assert_true(bool(table["ok"]), "off-grid constraint has a feasible constant witness")
	if not bool(table["ok"]):
		return
	for index in phases.size():
		var height: float = BodyBake._person_walk_height_at(table, phases[index])
		assert_gte(height + 0.0000001, lowers[index])
		assert_lte(height, uppers[index] + 0.0000001)
	for u: float in [0.0, 0.412, 0.999999, 1.0]:
		var row: Dictionary = BodyBake._person_walk_height_weights(u, 256)
		var value: float = 0.0
		var weight_sum: float = 0.0
		for slot in 4:
			var weight: float = row["weights"][slot]
			weight_sum += weight
			value += weight * float(table["coefficients"][int(row["indices"][slot])])
		assert_almost_eq(weight_sum, 1.0, 0.000000001)
		assert_almost_eq(value, BodyBake._person_walk_height_at(table, u), 0.000000001, "Hermite evaluates the same cyclic spline")


func test_walk_adjusted_paths_join_at_touchdown_toeoff_and_seam() -> void:
	var epsilon: float = 0.00001
	for duration: float in [0.50, 0.53, 0.55, 0.57]:
		for lift: float in [0.02, 0.18]:
			for roll: Vector2 in [Vector2(0.16, 0.45), Vector2(0.40, 0.80)]:
				var params: Dictionary = {"swing_lift": lift, "heel_end": roll.x, "toe_start": roll.y}
				for boundary: float in [0.0, duration, 1.0]:
					var left: Vector3 = BodyBake._person_walk_path(fposmod(boundary - epsilon, 1.0), duration, 1.64, params)
					var at: Vector3 = BodyBake._person_walk_path(fposmod(boundary, 1.0), duration, 1.64, params)
					var right: Vector3 = BodyBake._person_walk_path(fposmod(boundary + epsilon, 1.0), duration, 1.64, params)
					assert_lt(left.distance_to(right), 0.00004, "position joins at both contacts and seam")
					assert_lt(((at - left) / epsilon).distance_to((right - at) / epsilon), 0.004, "velocity joins at float32 precision")
				for sample in 65:
					var age: float = duration * float(sample) / 64.0
					var path: Vector3 = BodyBake._person_walk_path(age, duration, 1.64, params)
					assert_almost_eq(path.x, 1.64 * (duration * 0.5 - age), 0.0000001, "unchanged stance slope")
					assert_eq(path.y, 0.0, "stance sole stays on the floor")
				assert_almost_eq(BodyBake._person_walk_path((1.0 + duration) * 0.5, duration, 1.64, params).y, lift, 0.0000001)


func test_walk_path_parameters_and_phase_boundaries_stay_in_design_box() -> void:
	var params: Dictionary = {"centers": [-0.16, 0.16], "lifts": [0.02, 0.18],
		"heel_end": 0.40, "toe_start": 0.45, "durations": [0.50, 0.55]}
	assert_true(BodyBake._person_walk_params_valid(params, [0.2, 0.65]))
	for key: String in ["centers", "lifts", "durations"]:
		var outside: Dictionary = params.duplicate(true)
		outside[key][0] = 0.17 if key == "centers" else (0.19 if key == "lifts" else 0.49)
		assert_false(BodyBake._person_walk_params_valid(outside, [0.2, 0.65]), key + " bounds cannot expand")
	var crossed: Dictionary = params.duplicate(true)
	crossed["toe_start"] = 0.44
	assert_false(BodyBake._person_walk_params_valid(crossed, [0.2, 0.65]))
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = BodyBake._person_walk_with_params(ctx["footlock_walk"], params)
	var phases: PackedFloat64Array = BodyBake._person_walk_validation_phases(fit)
	for side in 2:
		for fraction: float in [0.0, 0.40, 0.60, 1.0]:
			var boundary: float = fposmod(float(fit["starts"][side]) + float(fit["durations"][side]) * fraction, 1.0)
			assert_true(phases.has(boundary), "new durations recompute all exact stance boundaries")
	assert_eq(fit["starts"], BodyBake.PERSON_STEP_AT, "touchdown phases remain fixed")
	assert_eq(float(fit["round"]), 1.64, "stride remains fixed")


func test_walk_swing_lift_opens_cross_leg_mid_entry_gap() -> void:
	var ctx: Dictionary = _walk_feedback_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var body: Skeleton3D = ctx["body"]
	body.reset_bone_poses()
	var u: float = 225.0 / 256.0
	var targets: Array = []
	for side in 2:
		targets.append(BodyBake._person_walk_ankle_goal(fit, side, u)["target"])
	var initial: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, u, targets)
	var support_lower: float = initial["per_side"][1]["lower"]
	var swing_upper: float = initial["per_side"][0]["upper"]
	var swing: Vector3 = targets[0]
	swing.y += support_lower - swing_upper - 0.0348
	targets[0] = swing
	var closed: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, u, targets)
	assert_true(bool(closed["empty"]), "premise: cross-leg interval is empty")
	assert_almost_eq(float(closed["lower"]) - float(closed["upper"]), 0.0348, 0.000001)
	var age: float = fposmod(u - float(fit["starts"][0]), 1.0)
	var old_path: Vector3 = BodyBake._person_walk_path(age, float(fit["durations"][0]), 1.64)
	var raised_path: Vector3 = BodyBake._person_walk_path(age, float(fit["durations"][0]), 1.64, {"swing_lift": 0.12})
	swing.y += raised_path.y - old_path.y
	targets[0] = swing
	var opened: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, u, targets)
	assert_false(bool(opened["empty"]), "bounded swing lift opens the measured gap")
	assert_eq(old_path.x, raised_path.x, "lift leaves horizontal travel unchanged")


func test_walk_bounded_search_reports_limit_without_poisoning_caller() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = (ctx["footlock_walk"] as Dictionary).duplicate(true)
	fit["rest_hips_y"] = 0.5
	ctx["fit_failures"] = ["existing_failure"]
	var result: Dictionary = BodyBake._search_person_walk_path(ctx, fit, [{"entry": BodyBake.PERSON_CLIPS[0], "shift": 0.0}], 2, 1)
	assert_false(bool(result["ok"]), "empty geometry is not accepted")
	assert_eq(result["reason"], "SEARCH_LIMIT", "a budget is not an impossibility proof")
	assert_eq(int(result["geometry_count"]), 2)
	assert_lte(int(result["skin_count"]), 1)
	assert_gt((result["trials"] as Array).size(), 0, "failed paths retain diagnostics")
	assert_eq(ctx["fit_failures"], ["existing_failure"], "trial failures cannot enter the caller's save refusal list")


func test_walk_path_search_preserves_material_stance_slope_and_shared_table() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var specs: Array = []
	for entry: Array in BodyBake.PERSON_CLIPS:
		if BodyBake.PERSON_FOOT_LOCK.has(entry[0]):
			specs.append({"entry": entry, "shift": 0.0})
	ctx["fit_failures"] = ["existing_failure"]
	var searched: Dictionary = BodyBake._search_person_walk_path(ctx, ctx["footlock_walk"], specs)
	print("WALK_SEARCH_WORK fixture=stick ok=%s geometry=%d skin=%d budget=%s" % [str(searched["ok"]), int(searched["geometry_count"]), int(searched["skin_count"]), JSON.stringify(searched["budget"])])
	assert_true(bool(searched["ok"]), "stick rig must provide an accepted bounded path")
	assert_false(bool(searched["budget"]["exhausted"]), "the unchanged work budget must suffice")
	for kind: String in ["bounds", "ik", "project", "paths"]:
		assert_lte(int(searched["budget"]["used"].get(kind, 0)), int(searched["budget"]["limits"][kind]))
	assert_eq(ctx["fit_failures"], ["existing_failure"], "successful search preserves the caller's refusal list")
	if not bool(searched["ok"]):
		print("WALK_STICK_DIAGNOSTIC " + JSON.stringify(searched["witness"]))
		return
	assert_lte(int(searched["geometry_count"]), 4096)
	assert_lte(int(searched["skin_count"]), 64)
	var fit: Dictionary = searched["fit"]
	assert_true(BodyBake._person_walk_params_valid(fit["path_params"], fit["starts"]))
	assert_eq((fit["target_field"] as Dictionary).size(), 6, "skin target fields are clip specific")
	assert_eq((fit["height_extra_phases"] as PackedFloat64Array).size(), 1024, "accepted path includes the dense check")
	var repeated: Dictionary = BodyBake._fit_person_walk_height(ctx, fit, BodyBake.PERSON_CLIPS[0], 0.0)
	for key: String in ["values", "slopes", "uppers", "lowers"]:
		assert_eq((repeated[key] as PackedFloat64Array).to_byte_array(), (fit["pelvis"][key] as PackedFloat64Array).to_byte_array(), "accepted field reproduces " + key)
	for spec: Dictionary in specs:
		var entry: Array = spec["entry"]
		var note: Dictionary = searched["saved"]["measurements"][entry[0]]
		for side in 2:
			var stats: Dictionary = note["stats"][side]
			assert_almost_eq(float(note["rounds"][side]), 1.64, 1.64 * 0.005, "actual saved material support has the fixed stance slope")
			assert_lte(BodyBake._person_footlock_slide(stats["after"]), 2.0)
			assert_gte(float(stats["contacts"]) / float(stats["frames"]), 0.5)
			assert_gte(float(stats["hips_sum_m"]) / float(stats["frames"]) / float(fit["stand_ref_m"]), 0.95)


func test_walk_total_budget_stops_search_and_is_shared_across_retries() -> void:
	var ctx: Dictionary = _walk_stick_context()
	ctx["rig_label"] = "budget_stick"
	ctx["fit_failures"] = ["existing_failure"]
	var specs: Array = [{"entry": BodyBake.PERSON_CLIPS[0], "shift": 0.0}]
	var result: Dictionary = BodyBake._search_person_walk_path(ctx, ctx["footlock_walk"], specs, 4096, 64, {"bounds": 1, "clip_bounds": 1})
	assert_false(bool(result["ok"]))
	assert_eq(str(result["reason"]), "FOOT_PATH_BUDGET")
	assert_true(str(result["failure"]).begins_with("FOOT_PATH_BUDGET rig=budget_stick clip=p_walk"))
	assert_eq(int(result["budget"]["used"]["bounds"]), 1)
	assert_eq(int(result["skin_count"]), 0)
	var used: Dictionary = (result["budget"]["used"] as Dictionary).duplicate()
	var retried: Dictionary = BodyBake._search_person_walk_path(ctx, ctx["footlock_walk"], specs)
	assert_eq(str(retried["reason"]), "FOOT_PATH_BUDGET")
	assert_eq(retried["budget"]["used"], used, "the rig cannot reset its ledger by retrying")
	assert_eq(ctx["fit_failures"], ["existing_failure"])


func test_walk_projection_budget_reserves_a_whole_sweep() -> void:
	# Two rows leave one credit, insufficient to reserve the next whole sweep.
	var budget: Dictionary = BodyBake._person_walk_budget({"project": 3})
	var rows: Array = [BodyBake._person_walk_height_row(PackedInt32Array([0, 1]), PackedFloat64Array([1.0, 1.0]), 0.0),
		BodyBake._person_walk_height_row(PackedInt32Array([1]), PackedFloat64Array([-1.0]), -1.0)]
	var result: Dictionary = BodyBake._project_person_walk_height(rows, PackedFloat64Array([2.0, 2.0]), 512, budget)
	assert_false(bool(result["converged"]))
	assert_eq(str(result["reason"]), "FOOT_PATH_BUDGET")
	assert_eq(int(result["sweeps"]), 1)
	assert_eq(int(budget["used"]["project"]), 2)
	assert_eq(float(result["coefficients"][0]), 0.0, "only the reserved sweep ran")


func test_walk_clip_ik_budget_stops_before_the_next_pair() -> void:
	var budget: Dictionary = BodyBake._person_walk_budget({"ik": 3, "clip_ik": 1})
	assert_true(BodyBake._person_walk_spend(budget, "ik", "p_walk"))
	assert_true(BodyBake._person_walk_spend(budget, "ik", "p_walk_long"))
	assert_false(BodyBake._person_walk_spend(budget, "ik", "p_walk"))
	assert_eq(int(budget["used"]["ik"]), 2)
	assert_eq(int(budget["clips"]["p_walk"]["ik"]), 1)
	assert_false(BodyBake._person_walk_spend(budget, "ik", "p_walk_long"))
	assert_eq(int(budget["used"]["ik"]), 2, "exhaustion is sticky across clips")


func test_walk_projection_accepts_feasibility_before_small_coefficient_change() -> void:
	var rows: Array = [BodyBake._person_walk_height_row(PackedInt32Array([0]), PackedFloat64Array([1.0]), 0.0)]
	var budget: Dictionary = BodyBake._person_walk_budget({"project": 1})
	var result: Dictionary = BodyBake._project_person_walk_height(rows, PackedFloat64Array([2.0]), 512, budget)
	assert_true(bool(result["converged"]), "a two-metre correction already reaches the feasible set")
	assert_eq(int(result["sweeps"]), 1)
	assert_eq(float(result["max_violation"]), 0.0)
	assert_eq(float(result["coefficients"][0]), 0.0)
	assert_false(bool(budget["exhausted"]))
	assert_eq(int(budget["used"]["project"]), 1)


func test_walk_projection_uses_one_micrometre_feasibility() -> void:
	var rows: Array = [BodyBake._person_walk_height_row(PackedInt32Array([0]), PackedFloat64Array([1.0]), 0.0),
		BodyBake._person_walk_height_row(PackedInt32Array([0]), PackedFloat64Array([-1.0]), -0.0000005)]
	var result: Dictionary = BodyBake._project_person_walk_height(rows, PackedFloat64Array([0.0]))
	assert_eq(BodyBake.PERSON_WALK_PROJECT_FEASIBILITY_M, 0.000001)
	assert_true(bool(result["converged"]))
	assert_eq(int(result["sweeps"]), 1)
	assert_almost_eq(float(result["max_violation"]), 0.0000005, 0.000000000001)


func test_walk_projection_stall_records_residual_and_spent_sweeps() -> void:
	var rows: Array = [BodyBake._person_walk_height_row(PackedInt32Array([0]), PackedFloat64Array([1.0]), 0.0),
		BodyBake._person_walk_height_row(PackedInt32Array([0]), PackedFloat64Array([-1.0]), -0.01)]
	var budget: Dictionary = BodyBake._person_walk_budget()
	var result: Dictionary = BodyBake._project_person_walk_height(rows, PackedFloat64Array([0.0]), 512, budget)
	assert_false(bool(result["converged"]))
	assert_eq(str(result["reason"]), "HEIGHT_PROJECT_STALLED")
	assert_eq(int(result["stale_sweeps"]), BodyBake.PERSON_WALK_PROJECT_STALL_SWEEPS)
	assert_eq(int(result["sweeps"]), BodyBake.PERSON_WALK_PROJECT_STALL_SWEEPS + 1)
	assert_lt(int(result["sweeps"]), BodyBake.PERSON_WALK_PROJECT_SWEEPS)
	assert_almost_eq(float(result["max_violation"]), 0.01, 0.000000001)
	assert_eq(int(budget["used"]["project"]), int(result["sweeps"]) * rows.size())
	assert_false(bool(budget["exhausted"]))
	var witness: Dictionary = BodyBake._person_walk_skin_witness({"reason": result["reason"], "table": {"projection": result}})
	assert_eq(int(witness["projection_sweeps"]), int(result["sweeps"]))
	assert_eq(float(witness["projection_max_violation"]), float(result["max_violation"]))


func test_walk_projection_keeps_mean_rows_at_one_nanometre() -> void:
	var mean_row: Dictionary = BodyBake._person_walk_height_row(PackedInt32Array([0]), PackedFloat64Array([-1.0]), -0.95)
	mean_row["epsilon_m"] = BodyBake.PERSON_WALK_MEAN_EPSILON
	var rows: Array = [mean_row, BodyBake._person_walk_height_row(PackedInt32Array([0]), PackedFloat64Array([1.0]), 0.9499995)]
	var result: Dictionary = BodyBake._project_person_walk_height(rows, PackedFloat64Array([0.95]))
	assert_eq(BodyBake.PERSON_WALK_MEAN_EPSILON, 0.000000001)
	assert_false(bool(result["converged"]), "half a micrometre cannot pass a mean row")
	assert_eq(str(result["reason"]), "HEIGHT_PROJECT_STALLED")
	assert_lt(float(result["max_violation"]), BodyBake.PERSON_WALK_PROJECT_FEASIBILITY_M)
	assert_gt(float(result["max_violation"]), BodyBake.PERSON_WALK_MEAN_EPSILON)


func test_walk_failed_bake_cannot_be_compacted_as_empty_bytes() -> void:
	var failed: Dictionary = BodyBake._person_bake_failure({"rig_label": "budget_stick"}, "FOOT_PATH_BUDGET", "p_walk")
	var compacted: Dictionary = BodyBake.compact(failed)
	assert_false(bool(compacted["ok"]))
	assert_eq(str(compacted["bake_error"]), "FOOT_PATH_BUDGET")
	assert_false(compacted.has("image"))
	assert_gt((compacted["fit_failures"] as Array).size(), 0)
	assert_eq(BodyBake._person_bake_output_error({}), "BAKE_EMPTY_IMAGE")


## Frozen targets isolate the original proportions from skin iteration.
func _walk_original_ratio_case(kind: String) -> Dictionary:
	var fit: Dictionary = {"rest_hips_y": 0.850, "stand_ref_m": 0.850, "floor": 0.0,
		"starts": [0.2, 0.65], "durations": [0.53, 0.57], "hip_over_stand_allowed": false}
	var geometry: Dictionary = {"hips": Vector3(0.0, 0.85, 0.0), "legs": [
		{"thigh": Vector3(0.1, 0.85, 0.0), "a": 0.391, "b": 0.374},
		{"thigh": Vector3(-0.1, 0.85, 0.0), "a": 0.391, "b": 0.374}]}
	var targets: Array = [Vector3(0.1, 0.11224412552, 0.30), Vector3(-0.1, 0.09230130925, 0.05)]
	var phase: float = 225.0 / 256.0
	if kind == "guard_f":
		phase = 106.0 / 256.0
		targets = [Vector3(0.1, 0.09382130925, 0.05), Vector3(-0.1, 0.12, 0.05)]
	elif kind == "sheepskin":
		targets = [Vector3(0.1, 0.06936412552, 0.30), Vector3(-0.1, 0.09197130925, 0.05)]
	return {"fit": fit, "geometry": geometry, "targets": targets, "phase": phase}


func test_walk_original_ratio_fitter_225_swing_owner_and_gap() -> void:
	var frozen: Dictionary = _walk_original_ratio_case("fitter")
	var bounds: Dictionary = BodyBake._person_walk_bounds_from_geometry(frozen["fit"], frozen["phase"], frozen["targets"], frozen["geometry"])
	assert_eq(int(bounds["lower_side"]), 1)
	assert_eq(int(bounds["upper_side"]), 0)
	assert_almost_eq(float(bounds["lower"]) - float(bounds["upper"]), 0.03465, 0.000001)
	assert_true(bool(bounds["empty"]))
	var gain: float = pow(sin(PI * ((225.0 / 256.0 - 0.2) - 0.53) / 0.47), 2.0)
	var targets: Array = (frozen["targets"] as Array).duplicate()
	var swing: Vector3 = targets[0]
	var lift_delta: float = (float(bounds["lower"]) - float(bounds["upper"])) / gain
	swing.y += (lift_delta + 0.001) * gain
	targets[0] = swing
	assert_lt(0.07 + lift_delta, 0.18)
	assert_false(bool(BodyBake._person_walk_bounds_from_geometry(frozen["fit"], frozen["phase"], targets, frozen["geometry"])["empty"]))


func test_walk_original_ratio_guard_106_stand_tolerance_keeps_bent_knee() -> void:
	var frozen: Dictionary = _walk_original_ratio_case("guard_f")
	var fit: Dictionary = frozen["fit"]
	var bounds: Dictionary = BodyBake._person_walk_bounds_from_geometry(fit, frozen["phase"], frozen["targets"], frozen["geometry"])
	assert_eq(int(bounds["lower_side"]), 0)
	assert_eq(int(bounds["upper_side"]), -1)
	assert_almost_eq(float(bounds["lower"]) - float(bounds["upper"]), 0.00063, 0.000001)
	assert_true(bool(bounds["empty"]))
	fit["hip_over_stand_allowed"] = true
	var opened: Dictionary = BodyBake._person_walk_bounds_from_geometry(fit, frozen["phase"], frozen["targets"], frozen["geometry"])
	assert_false(bool(opened["empty"]))
	assert_almost_eq(float(opened["upper"]), 0.8512, 0.0000001)
	var height: float = (float(opened["lower"]) + float(opened["upper"])) * 0.5
	var ankle: Vector3 = frozen["targets"][0]
	var distance_squared: float = Vector3(0.1, height, 0.0).distance_squared_to(ankle)
	var knee_deg: float = rad_to_deg(acos(clampf((distance_squared - 0.391 * 0.391 - 0.374 * 0.374) / (2.0 * 0.391 * 0.374), -1.0, 1.0)))
	assert_gte(knee_deg, rad_to_deg(BodyBake.PERSON_WALK_KNEE_MIN))
	assert_lte(knee_deg, 15.0)
	assert_false(BodyBake._person_walk_tolerance_knee_ok(fit, height, 0.0))
	assert_true(BodyBake._person_walk_tolerance_knee_ok(fit, height, knee_deg))
	assert_eq(float(fit["rest_hips_y"]), 0.850)
	assert_eq(float(fit["stand_ref_m"]), 0.850)
	print("WALK_STANCE_KNEE_MIN rig=guard_f_frozen deg=%.6f" % knee_deg)


func test_walk_original_ratio_sheepskin_owners_and_both_mean_caps() -> void:
	var frozen: Dictionary = _walk_original_ratio_case("sheepskin")
	var bounds: Dictionary = BodyBake._person_walk_bounds_from_geometry(frozen["fit"], frozen["phase"], frozen["targets"], frozen["geometry"])
	assert_eq(int(bounds["lower_side"]), 1)
	assert_eq(int(bounds["upper_side"]), 0)
	assert_almost_eq(float(bounds["lower"]) - float(bounds["upper"]), 0.0772, 0.000001)
	var grid_cap: float = 0.0
	var saved_cap: float = 0.0
	for index in 256:
		var point: Dictionary = BodyBake._person_walk_bounds_from_geometry(frozen["fit"], float(index) / 256.0, frozen["targets"], frozen["geometry"])
		grid_cap += float(point["upper"]) / 256.0
		if index % 8 == 0:
			saved_cap += float(point["upper"]) / 32.0
	assert_lt(grid_cap, 0.95 * 0.85)
	assert_lt(saved_cap, 0.95 * 0.85)
	assert_almost_eq(grid_cap, 0.77158, 0.000001)
	assert_almost_eq(saved_cap, grid_cap, 0.0000001)


func test_walk_center_intersection_rejects_later_mid_collision() -> void:
	var entry: Array = BodyBake._person_walk_center_intersection([Vector2(-0.16, 0.16)], Vector2(-0.1, 0.04))
	var whole: Array = BodyBake._person_walk_center_intersection(entry, Vector2(0.02, 0.12))
	assert_eq(whole.size(), 2)
	assert_almost_eq((whole[1] as Vector2).x, 0.12, 0.00000001)
	assert_gt((whole[1] as Vector2).x, (entry[1] as Vector2).x)


func test_walk_budget_witness_keeps_completed_candidate_and_partial_means_flag() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = (ctx["footlock_walk"] as Dictionary).duplicate(true)
	fit["rest_hips_y"] = 0.5
	var specs: Array = [{"entry": BodyBake.PERSON_CLIPS[0], "shift": 0.0}]
	var result: Dictionary = BodyBake._search_person_walk_path(ctx, fit, specs, 4096, 64, {"paths": 1})
	var witness: Dictionary = result["witness"]
	assert_eq(str(witness["budget_kind"]), "paths")
	assert_eq(str(witness["geometry_reason"]), "POINT_EMPTY")
	assert_true(bool(witness["candidate_complete"]))
	assert_true(bool(witness["means_complete"]))
	assert_true((witness["params"] as Dictionary).has("centers"))
	assert_true((witness["detail"] as Dictionary).has("lower_clip"))
	assert_true((witness["detail"] as Dictionary).has("upper_clip"))
	assert_false(bool(result["global_infeasible"]))
	ctx.erase("walk_work_budget")
	var partial: Dictionary = BodyBake._search_person_walk_path(ctx, fit, specs, 4096, 64, {"bounds": 1})
	assert_false(bool(partial["witness"]["means_complete"]))
	assert_false(bool(partial["witness"]["candidate_complete"]))


func test_walk_original_ratio_full_search_keeps_all_saved_gates() -> void:
	var ctx: Dictionary = _walk_feedback_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var body: Skeleton3D = ctx["body"]
	body.set_bone_rest(body.find_bone("hips"), Transform3D(Basis(), Vector3(0.0, 0.85, 0.0)))
	var rest: PackedVector3Array = fit["rest"]
	for side in 2:
		var leg: Array = fit["legs"][side]
		fit["rest_ankles"][side] = body.get_bone_global_rest(int(leg[2])).origin
		fit["anchors"][side] = body.get_bone_global_rest(int(leg[0])).origin - Vector3(0.0, 0.0, 0.08)
		for vertex: int in fit["soles"][side]:
			var position: Vector3 = rest[vertex]
			position.y = 0.0
			rest[vertex] = position
	fit["rest"] = rest
	fit["floor"] = 0.0
	fit["rest_hips_y"] = 0.85
	fit["stand_ref_m"] = 0.85
	body.reset_bone_poses()
	var skin: Skin = ctx["skin"]
	for bind in skin.get_bind_count():
		skin.set_bind_pose(bind, body.get_bone_global_rest(skin.get_bind_bone(bind)).affine_inverse())
	var specs: Array = []
	for entry: Array in BodyBake.PERSON_CLIPS:
		if BodyBake.PERSON_FOOT_LOCK.has(entry[0]):
			specs.append({"entry": entry, "shift": 0.0})
	var result: Dictionary = BodyBake._search_person_walk_path(ctx, fit, specs)
	print("WALK_SEARCH_WORK fixture=original_ratio_short ok=%s geometry=%d skin=%d budget=%s" % [str(result["ok"]), int(result["geometry_count"]), int(result["skin_count"]), JSON.stringify(result["budget"])])
	assert_true(bool(result["ok"]), "short original proportions must pass the full search")
	assert_false(bool(result["budget"]["exhausted"]), "the short rig uses the unchanged work budget")
	for kind: String in ["bounds", "ik", "project", "paths"]:
		assert_lte(int(result["budget"]["used"].get(kind, 0)), int(result["budget"]["limits"][kind]))
	if not bool(result["ok"]):
		print("WALK_RIG_DIAGNOSTIC " + JSON.stringify(result["witness"]))
		print("WALK_STANCE_KNEE_MIN rig=original_ratio_short deg=UNMEASURED accepted=false")
		return
	var accepted: Dictionary = result["fit"]
	var minimum: float = accepted["stance_knee_min_deg"]
	print("WALK_STANCE_KNEE_MIN rig=original_ratio_short deg=%.6f accepted=true" % minimum)
	assert_gt(minimum, 0.0)
	for spec: Dictionary in specs:
		var measurement: Dictionary = result["saved"]["measurements"][spec["entry"][0]]
		for side in 2:
			var stats: Dictionary = measurement["stats"][side]
			assert_almost_eq(float(measurement["rounds"][side]), 1.64, 1.64 * 0.005)
			assert_lte(BodyBake._person_footlock_slide(stats["after"]), 2.0)
			assert_lte(BodyBake._person_footlock_slide(stats["contact_after"]), 2.0)
			assert_gte(float(stats["contacts"]) / float(stats["frames"]), 0.5)
			assert_lte(float(stats["mid_knee_max_deg"]), 15.0)
			assert_gte(float(stats["hips_sum_m"]) / float(stats["frames"]), 0.95 * 0.85)
			assert_eq(int(stats["reach_clamp_frames"]), 0)
			assert_eq(int(stats["reach_final_fail_frames"]), 0)


func test_walk_allocation_covers_ends_positive_centers_lift_and_short_stance() -> void:
	var params: Dictionary = {"centers": [-0.08, -0.08], "lifts": [0.07, 0.07], "durations": [0.53, 0.57], "heel_end": 0.22, "toe_start": 0.55}
	var item: Dictionary = {"params": params, "fit": {"starts": [0.2, 0.65]}, "center_intervals": [[Vector2(0.04, 0.16)], [Vector2(0.04, 0.16)]], "lift_estimates": [0.12, 0.13]}
	var proposals: Array = BodyBake._person_walk_path_block([item], 0)
	proposals.append_array(proposals.duplicate(true))
	var allocation: Dictionary = BodyBake._person_walk_allocate_paths(proposals, {}, [0.2, 0.65], 24)
	assert_eq((allocation["selected"] as Array).size(), 24)
	assert_gt(int(allocation["omitted"]), 0)
	assert_lte(int(allocation["unique"]), 297)
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	var high_lift_short: bool = false
	var positive: bool = false
	for selected: Dictionary in allocation["selected"]:
		var center: Vector2 = Vector2(selected["centers"][0], selected["centers"][1])
		low = low.min(center)
		high = high.max(center)
		positive = positive or (center.x > 0.0 and center.y > 0.0)
		high_lift_short = high_lift_short or (float(selected["lifts"][0]) >= 0.18 and float(selected["lifts"][1]) >= 0.18 and float(selected["durations"][0]) <= 0.50 and float(selected["durations"][1]) <= 0.55)
	assert_eq(low, Vector2(-0.16, -0.16))
	assert_eq(high, Vector2(0.16, 0.16))
	assert_true(positive)
	assert_true(high_lift_short)


func test_walk_first_block_visits_near_centers_before_joint_extremes() -> void:
	var params: Dictionary = {"centers": [-0.08, -0.08], "lifts": [0.07, 0.07], "durations": [0.53, 0.57], "heel_end": 0.22, "toe_start": 0.55}
	var item: Dictionary = {"params": params, "fit": {"starts": [0.2, 0.65]}, "center_intervals": [[Vector2(-0.16, 0.16)], [Vector2(-0.16, 0.16)]], "lift_estimates": [0.07, 0.07]}
	var allocation: Dictionary = BodyBake._person_walk_allocate_paths(BodyBake._person_walk_path_block([item], 0), {var_to_str(params): true}, [0.2, 0.65], 24, params)
	var selected: Array = allocation["selected"]
	assert_eq(selected.size(), 24)
	var previous: float = 0.0
	for index: int in 16:
		var distance: float = BodyBake._person_walk_path_distance(selected[index], params)
		assert_gte(distance, previous)
		assert_lte(distance, 0.04)
		previous = distance
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for choice: Dictionary in selected:
		var center: Vector2 = Vector2(choice["centers"][0], choice["centers"][1])
		low = low.min(center)
		high = high.max(center)
	assert_eq(low, Vector2(-0.16, -0.16))
	assert_eq(high, Vector2(0.16, 0.16))


func test_walk_necessary_conditions_reject_before_projection() -> void:
	var candidate: Dictionary = {"complete": true, "gap": 0.0, "detail": {"horizontal_miss": false},
		"fit": {"floor": 0.0, "stand_ref_m": 1.0}, "grid_cap": 0.96, "saved_cap": 0.96,
		"center_intervals": [[Vector2(-0.16, 0.16)], [Vector2(-0.16, 0.16)]]}
	assert_true(BodyBake._person_walk_candidate_possible(candidate))
	for key: String in ["grid_cap", "saved_cap"]:
		var low_mean: Dictionary = candidate.duplicate(true)
		low_mean[key] = 0.94
		assert_false(BodyBake._person_walk_candidate_possible(low_mean), key)
	var horizontal: Dictionary = candidate.duplicate(true)
	horizontal["detail"]["horizontal_miss"] = true
	assert_false(BodyBake._person_walk_candidate_possible(horizontal))
	var empty: Dictionary = candidate.duplicate(true)
	empty["center_intervals"][1] = []
	assert_false(BodyBake._person_walk_candidate_possible(empty))
	var crossed: Dictionary = candidate.duplicate(true)
	crossed["gap"] = 0.001
	assert_false(BodyBake._person_walk_candidate_possible(crossed))


func test_walk_deferred_projection_rows_are_checked_and_reinserted() -> void:
	var phases: PackedFloat64Array = PackedFloat64Array()
	var lowers: PackedFloat64Array = PackedFloat64Array()
	var uppers: PackedFloat64Array = PackedFloat64Array()
	for index: int in BodyBake.PERSON_WALK_HEIGHT_SAMPLES:
		phases.append(float(index) / float(BodyBake.PERSON_WALK_HEIGHT_SAMPLES))
		lowers.append(0.5)
		uppers.append(1.0)
	var initial: PackedFloat64Array = phases.duplicate()
	phases.append(0.5 / float(BodyBake.PERSON_WALK_HEIGHT_SAMPLES))
	lowers.append(0.5)
	uppers.append(0.9)
	var table: Dictionary = BodyBake._person_walk_project_table(phases, lowers, uppers, 0.5, false, 0.0, {}, initial)
	assert_true(bool(table["ok"]))
	if not bool(table["ok"]):
		return
	for index: int in phases.size():
		var value: float = BodyBake._person_walk_height_at(table, phases[index])
		assert_gte(value + BodyBake.PERSON_WALK_PROJECT_EPSILON, lowers[index])
		assert_lte(value - BodyBake.PERSON_WALK_PROJECT_EPSILON, uppers[index])


func _walk_skin_gate(residual: float = 0.0, height_residual: float = 0.0, height: float = 0.75, bounds: Dictionary = {"empty": false, "lower": 0.7, "upper": 0.8}, misses: Array = [0.0, 0.0], knees: Array = [0.15, 0.15]) -> Dictionary:
	return BodyBake._person_walk_skin_conditions(residual, height_residual, height, bounds, misses, knees, [true, true], [true, true])


func test_walk_skin_named_tolerances_have_inclusive_boundaries() -> void:
	var epsilon: float = 0.000000001
	for direction: float in [-1.0, 0.0, 1.0]:
		var expected: bool = direction <= 0.0
		assert_eq(bool(_walk_skin_gate(BodyBake.PERSON_WALK_SKIN_TOL_M + direction * epsilon)["ok"]), expected)
		assert_eq(bool(_walk_skin_gate(0.0, BodyBake.PERSON_WALK_SKIN_HEIGHT_TOL_M + direction * epsilon)["ok"]), expected)
		for side in 2:
			var misses: Array = [0.0, 0.0]
			misses[side] = BodyBake.PERSON_WALK_ANKLE_TOL_M + direction * epsilon
			assert_eq(bool(_walk_skin_gate(0.0, 0.0, 0.75, {"empty": false, "lower": 0.7, "upper": 0.8}, misses)["ok"]), expected)
	assert_false(bool(_walk_skin_gate(0.0, 0.0, 0.75, {"empty": false, "lower": 0.7, "upper": 0.8}, [0.0, 0.0], [BodyBake.PERSON_WALK_KNEE_MIN - epsilon, 0.15])["actual_ok"]), "every stance keeps the four degree floor")
	assert_false(bool(_walk_skin_gate(0.0, 0.0, 0.75, {"empty": false, "lower": 0.7, "upper": 0.8}, [0.0, 0.0], [0.15, BodyBake.PERSON_WALK_MID_KNEE_MAX + epsilon])["actual_ok"]))
	assert_almost_eq(BodyBake.PERSON_WALK_PROJECT_FEASIBILITY_M, 0.000001, 0.000000000001)
	assert_almost_eq(BodyBake.PERSON_WALK_MEAN_EPSILON, 0.000000001, 0.000000000000001)
	assert_almost_eq(BodyBake.PERSON_WALK_JOINT_TARGET_TOL_M, 0.0001, 0.000000000001)
	assert_almost_eq(BodyBake.PERSON_WALK_JOINT_HEIGHT_TOL_M, 0.00005, 0.000000000001)


func test_walk_skin_height_inclusion_is_independent_of_residual_tolerance() -> void:
	var gates: Dictionary = _walk_skin_gate(0.0, 0.0000002, 0.8000002)
	assert_true(bool(gates["target_ok"]))
	assert_true(bool(gates["height_ok"]))
	assert_true(bool(gates["next_bounds_ok"]))
	assert_true(bool(gates["actual_ok"]))
	assert_false(bool(gates["upper_ok"]))
	assert_false(bool(gates["ok"]), "a submicrometre overshoot still fails interval inclusion")
	assert_lt(float(gates["next_upper_minus_height_m"]), 0.0)
	var empty: Dictionary = _walk_skin_gate(0.0, 0.0, 0.75, {"empty": true, "lower": 0.7, "upper": 0.8})
	assert_false(bool(empty["next_bounds_ok"]))
	assert_false(bool(empty["ok"]))


func test_walk_skin_height_inset_matches_joint_projection() -> void:
	for width: float in [0.1, 0.00002, 0.0]:
		var bounds: Dictionary = {"empty": false, "lower": 0.7, "upper": 0.7 + width}
		var margin: float = minf(0.00001, width * 0.25)
		assert_almost_eq(BodyBake._person_walk_inner_height(0.0, bounds), 0.7 + margin, 0.000000000001)
		assert_almost_eq(BodyBake._person_walk_inner_height(1.0, bounds), 0.7 + width - margin, 0.000000000001)
		# The table rows use this same inset; feasibility does not require the
		# nearest point (or every table value) to sit on the upper boundary.
		var table_margin: float = BodyBake._person_walk_height_inset(float(bounds["lower"]), float(bounds["upper"]), BodyBake.PERSON_WALK_HEIGHT_INTERPOLATION_MARGIN)
		var inner_lower: float = float(bounds["lower"]) + table_margin
		var inner_upper: float = float(bounds["upper"]) - table_margin
		assert_almost_eq(inner_lower, BodyBake._person_walk_inner_height(0.0, bounds), 0.000000000001, "table and frame lower boundaries agree")
		assert_almost_eq(inner_upper, BodyBake._person_walk_inner_height(1.0, bounds), 0.000000000001, "table and frame upper boundaries agree")
		var phases: PackedFloat64Array = PackedFloat64Array()
		var lowers: PackedFloat64Array = PackedFloat64Array()
		var uppers: PackedFloat64Array = PackedFloat64Array()
		for index in BodyBake.PERSON_WALK_HEIGHT_SAMPLES:
			phases.append(float(index) / float(BodyBake.PERSON_WALK_HEIGHT_SAMPLES))
			lowers.append(float(bounds["lower"]))
			uppers.append(float(bounds["upper"]))
		var table: Dictionary = BodyBake._person_walk_project_table(phases, lowers, uppers, 0.0, false, BodyBake.PERSON_WALK_HEIGHT_INTERPOLATION_MARGIN)
		assert_true(bool(table["ok"]), "wide, narrow and zero-width intervals remain feasible")
		assert_eq((table["values"] as PackedFloat64Array).size(), BodyBake.PERSON_WALK_HEIGHT_SAMPLES, "an empty table cannot satisfy inclusion vacuously")
		for height: float in table["values"]:
			assert_gte(height, inner_lower - BodyBake.PERSON_WALK_PROJECT_FEASIBILITY_M)
			assert_lte(height, inner_upper + BodyBake.PERSON_WALK_PROJECT_FEASIBILITY_M)


func test_walk_last_evaluated_skin_state_can_succeed() -> void:
	var ctx: Dictionary = _walk_feedback_context()
	for sample in 32:
		var u: float = float(sample) / 32.0
		var full: Dictionary = _walk_feedback_frame(ctx, u)
		if full.is_empty() or not bool(full["ok"]) or int(full["ik_passes"]) < 2:
			continue
		var final_pass: int = int(full["ik_passes"])
		var replay: Dictionary = _walk_feedback_frame(ctx, u, Vector3.ZERO, final_pass)
		assert_true(bool(replay["ok"]), "success is checked before the last evaluation limit")
		assert_true(bool(replay["conditions"]["ok"]))
		assert_eq(int(replay["ik_passes"]), final_pass)
		var earlier: Dictionary = _walk_feedback_frame(ctx, u, Vector3.ZERO, final_pass - 1)
		assert_false(bool(earlier["ok"]), "an unevaluated proposal cannot succeed")
		return
	assert_true(false, "mixed skin must supply a multi-evaluation success")


func test_walk_vector_aitken_uses_both_feet_and_resets_history() -> void:
	var old: Dictionary = {"signature": "stable", "residual_vector": [Vector3(0.004, 0.0, 0.0), Vector3(0.0, 0.002, 0.0)]}
	var current: Dictionary = {"signature": "stable", "residual_vector": [Vector3(0.002, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)]}
	assert_almost_eq(BodyBake._person_walk_aitken(old, current, 1.0), 1.5, 0.000001, "six dimensional dot product, not separate component factors")
	assert_almost_eq(BodyBake._person_walk_aitken({}, current, 1.0), 1.0, 0.000001)
	assert_almost_eq(BodyBake._person_walk_aitken(old, old, 1.5), 1.0, 0.000001, "tiny denominator resets")
	current["signature"] = "changed_probe_or_bound"
	assert_almost_eq(BodyBake._person_walk_aitken(old, current, 1.5), 1.0, 0.000001)
	current["signature"] = "stable"
	current["residual_vector"] = [Vector3(0.0036, 0.0, 0.0), Vector3(0.0, 0.0018, 0.0)]
	assert_almost_eq(BodyBake._person_walk_aitken(old, current, 1.0), 2.0, 0.000001)
	current["residual_vector"] = [Vector3(0.008, 0.0, 0.0), Vector3(0.0, 0.004, 0.0)]
	assert_almost_eq(BodyBake._person_walk_aitken(old, current, 1.0), 0.25, 0.000001)
	var bounds: Dictionary = {"empty": false, "lower": 0.7, "upper": 0.8}
	assert_eq(BodyBake._person_walk_skin_height_branch(0.6, bounds), -1)
	assert_eq(BodyBake._person_walk_skin_height_branch(0.75, bounds), 0)
	assert_eq(BodyBake._person_walk_skin_height_branch(0.9, bounds), 1)


func test_walk_mixed_skin_aitken_needs_no_more_evaluations_than_plain() -> void:
	var ctx: Dictionary = _walk_feedback_context()
	var plain_count: int = 0
	var fast_count: int = 0
	var compared: int = 0
	for sample in 32:
		var u: float = float(sample) / 32.0
		var plain: Dictionary = _walk_feedback_frame(ctx, u, Vector3.ZERO, BodyBake.PERSON_WALK_SKIN_EVALUATIONS, false)
		if plain.is_empty() or not bool(plain["ok"]):
			continue
		var fast: Dictionary = _walk_feedback_frame(ctx, u)
		assert_false(fast.is_empty())
		if fast.is_empty():
			return
		assert_true(bool(fast["ok"]), "acceleration preserves every plain-convergent sampled phase")
		plain_count += int(plain["ik_passes"])
		fast_count += int(fast["ik_passes"])
		compared += 1
	assert_gt(compared, 0, "mixed skin comparison must actually converge")
	assert_lte(fast_count, plain_count, "same phases, including rejected evaluations")
	print("WALK_AITKEN_COMPARE phases=%d plain=%d accelerated=%d" % [compared, plain_count, fast_count])


func test_walk_rejected_aitken_trial_restores_pose_and_gate_state() -> void:
	var ctx: Dictionary = _walk_stick_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var body: Skeleton3D = ctx["body"]
	var rest: PackedVector3Array = fit["rest"]
	var bones: PackedInt32Array = fit["bones"]
	var weights: PackedFloat32Array = fit["weights"]
	var bind_bone: Array = ctx["bind_bone"]
	var goals: Array = []
	var targets: Array = []
	# A fixed noncontractive mixed skin, evaluated through the real paired IK.
	# Flat goals and fixed hips make r_x = -[[1/8, 3/8], [3/8, 1/8]] * d_x.
	# With d_x=(.04, 0), two accepted evaluations give omega=28/17; that
	# extrapolation increases the residual, as does its first half-step.
	fit["starts"] = [0.9, 0.9]
	fit["durations"] = [0.6, 0.6]
	fit["goal_cache"] = {}
	fit["floor"] = -0.05
	fit["pelvis"] = {"values": PackedFloat64Array([0.9]), "slopes": PackedFloat64Array([0.0])}
	for side in 2:
		# A unique lowest vertex prevents roundoff ties from resetting history.
		var lowest: int = int(fit["soles"][side][0])
		rest[lowest] = rest[lowest] - Vector3(0.0, 0.01, 0.0)
		var own_bind: int = bind_bone.find(int(fit["legs"][side][2]))
		var other_bind: int = bind_bone.find(int(fit["legs"][1 - side][2]))
		var hip_bind: int = bind_bone.find(body.find_bone("hips"))
		for vertex: int in fit["soles"][side]:
			for slot in 4:
				bones[vertex * 4 + slot] = [own_bind, other_bind, hip_bind, hip_bind][slot]
				weights[vertex * 4 + slot] = [0.125, 0.375, 0.5, 0.0][slot]
		var ankle: Vector3 = fit["rest_ankles"][side]
		var goal: Dictionary = {"target": ankle, "base": ankle, "rotation": Basis(), "path": Vector3.ZERO, "age": 0.1}
		goals.append(goal)
		fit["goal_cache"][side] = {0.0: goal}
		# +.1 y cancels the half-weighted hips' -.1 y. The right +.002
		# fixes the lower-bound owner, with the same mirrored residual map.
		targets.append(ankle + Vector3(0.04 if side == 0 else 0.0, 0.1 if side == 0 else 0.102, 0.0))
	fit["rest"] = rest
	fit["bones"] = bones
	fit["weights"] = weights
	ctx["walk_clip"] = "p_walk"
	ctx["fit_failures"] = []
	body.reset_bone_poses()
	var budget: Dictionary = BodyBake._person_walk_budget()
	fit["work_budget"] = budget
	var replay: Dictionary = BodyBake._solve_person_walk_frame(ctx, fit, 0.0, targets, 4, true)
	var passes: Array = replay["passes"]
	assert_eq(passes.size(), 4, "fixed input must reach the rejected extrapolation and its half-step")
	if passes.size() != 4:
		return
	assert_true(bool(passes[0]["accepted"]))
	assert_true(bool(passes[1]["accepted"]))
	assert_eq(passes[0]["signature"], passes[1]["signature"], "fixed probe and bound owners preserve accepted history")
	assert_gt(float(passes[2]["omega"]), 1.0, "accepted history must activate Aitken before rejection")
	assert_false(bool(passes[2]["accepted"]), "a missing measured rejection must fail")
	assert_false(bool(passes[3]["accepted"]), "the fixed half-step also fails to improve")
	assert_gt(float(passes[2]["normalized_residual"]), float(passes[1]["normalized_residual"]))
	assert_gt(float(passes[3]["normalized_residual"]), float(passes[1]["normalized_residual"]))
	assert_almost_eq(float(passes[3]["omega"]), float(passes[2]["omega"]) * 0.5, 0.000001, "rejection halves omega")
	assert_eq(int(replay["rejections"]), 2)
	assert_false(bool(replay["last_trial"]["accepted"]))
	assert_false(bool(replay["ok"]))
	assert_eq(replay["reason"], "SKIN_ITER_LIMIT")
	var evaluated: int = 0
	for note: Dictionary in passes:
		assert_true(bool(note["evaluated"]), "the witness must include actual paired IK, not a precheck refusal")
		assert_eq(note["reason"], "", "rejection must come from measured nonprogress")
		assert_true(is_finite(float(note["normalized_residual"])))
		assert_true(bool(note["conditions"]["actual_ok"]), "ankle and knee gates stay feasible during rejection")
		assert_true(bool(note["conditions"]["height_inside"]), "height inclusion is not the source of rejection")
		if bool(note["evaluated"]):
			evaluated += 1
	assert_eq(evaluated, 4)
	assert_eq(int(budget["used"]["ik"]), evaluated, "rejected paired IK remains charged after rollback")
	assert_eq(int(budget["clips"]["p_walk"]["ik"]), evaluated)
	assert_eq(int(replay["ik_passes"]), evaluated)
	assert_eq(replay["targets_used"], passes[1]["targets_used"], "rejected targets cannot replace the accepted state")
	assert_eq(replay["conditions"], passes[1]["conditions"])
	fit.erase("work_budget")
	var restored: Dictionary = BodyBake._person_walk_skin_snapshot(body, fit)
	body.reset_bone_poses()
	fit["reach_clamped"] = [false, false]
	fit["reach_final_failed"] = [false, false]
	fit["height_frame_failed"] = false
	var baseline: Dictionary = BodyBake._person_walk_skin_snapshot(body, fit)
	var expected: Dictionary = BodyBake._person_walk_skin_evaluate(ctx, fit, 0.0, goals, passes[1]["targets_used"], 0.9, baseline)
	assert_true(bool(expected["evaluated"]))
	assert_eq(replay["conditions"], expected["conditions"], "rejected conditions cannot overwrite the accepted witness")
	assert_eq(restored["reach_clamped"], fit["reach_clamped"])
	assert_eq(restored["reach_final_failed"], fit["reach_final_failed"])
	assert_true(bool(restored["height_frame_failed"]), "final refusal is separate from rolled-back trial gates")
	for bone in body.get_bone_count():
		assert_lt((restored["pose"][bone][0] as Vector3).distance_to(body.get_bone_pose_position(bone)), 0.000001)
		assert_lt((restored["pose"][bone][1] as Quaternion).angle_to(body.get_bone_pose_rotation(bone)), 0.00001)
		assert_lt((restored["pose"][bone][2] as Vector3).distance_to(body.get_bone_pose_scale(bone)), 0.000001)


func test_walk_skin_ledger_counts_exactly_the_evaluated_pairs() -> void:
	var ctx: Dictionary = _walk_feedback_context()
	var fit: Dictionary = ctx["footlock_walk"]
	var budget: Dictionary = BodyBake._person_walk_budget({"ik": 2, "clip_ik": 2})
	fit["work_budget"] = budget
	var result: Dictionary = _walk_feedback_frame(ctx, 0.0, Vector3(0.12, 0.0, 0.0))
	assert_false(result.is_empty())
	if result.is_empty():
		return
	var measured: int = 0
	for trial: Dictionary in result["passes"]:
		if bool(trial["evaluated"]):
			measured += 1
	assert_eq(int(budget["used"]["ik"]), measured)
	assert_eq(int(budget["clips"]["p_walk"]["ik"]), measured)
	assert_eq(int(result["ik_passes"]), measured)
	assert_lte(measured, 2)
	assert_lte(measured, BodyBake.PERSON_WALK_SKIN_EVALUATIONS)
	var witness: Dictionary = BodyBake._person_walk_skin_witness({"reason": result["reason"], "solve": result})
	assert_eq(witness["conditions"], result["conditions"])
	assert_eq(witness["passes"], result["passes"])
	assert_eq(int(witness["rejections"]), int(result["rejections"]))


func test_walk_skin_rejects_nonprogress_and_detects_two_state_cycle() -> void:
	var old: Dictionary = {"normalized_residual": 2.0}
	assert_false(BodyBake._person_walk_skin_improves(old, {"reason": "", "normalized_residual": 2.0}))
	assert_false(BodyBake._person_walk_skin_improves(old, {"reason": "", "normalized_residual": 3.0}))
	assert_true(BodyBake._person_walk_skin_improves(old, {"reason": "", "normalized_residual": 1.0}))
	assert_eq(BodyBake.PERSON_WALK_SKIN_STALL_TRIALS, 3)
	var state: Dictionary = {"height": 0.7, "targets_used": [Vector3(0.1, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0)]}
	assert_true(BodyBake._person_walk_skin_cycle(state, state.duplicate(true)))
	var moved: Dictionary = state.duplicate(true)
	moved["targets_used"][1] += Vector3(0.0, 0.0, 0.0001)
	assert_false(BodyBake._person_walk_skin_cycle(state, moved))
