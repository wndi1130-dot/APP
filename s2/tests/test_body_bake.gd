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
