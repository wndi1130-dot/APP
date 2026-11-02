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
			if String(step[0]) in ["stand_support", "axe_support"]:
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


func _legacy_keyed(keys: Array, u: float) -> float:
	if u <= float(keys[0][0]):
		return float(keys[0][1])
	for n: int in range(1, keys.size()):
		if u <= float(keys[n][0]):
			var a: Array = keys[n - 1]
			var b: Array = keys[n]
			var t: float = (u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, t))
	return float(keys[keys.size() - 1][1])


func _collect_key_tracks(spec: Variant, tracks: Array) -> void:
	if spec is Dictionary:
		var fields: Dictionary = spec
		for value: Variant in fields.values():
			_collect_key_tracks(value, tracks)
	elif spec is Array:
		var parts: Array = spec
		if parts.size() == 2 and typeof(parts[0]) == TYPE_STRING and String(parts[0]) == "keys":
			tracks.append(parts[1])
		else:
			for value: Variant in parts:
				_collect_key_tracks(value, tracks)


func test_keyed_default_has_zero_difference_from_the_legacy_formula() -> void:
	var tracks: Array = [
		[[0.2, 1.0], [0.6, 3.0]],
		[[0.0, -3.25], [0.13, 8.5], [0.51, -0.75], [1.0, 2.25]],
		[[0.5, 7.0]],
		[[0.0, 0.0], [0.00001, 1.0], [0.5, -1.0]],
	]
	_collect_key_tracks(BodyBake.LAYERS, tracks)
	for keys: Array in tracks:
		var plain: Array = []
		for key: Array in keys:
			plain.append([key[0], key[1]])
		keys = plain
		var phases: Array[float] = [-0.25, 0.0, 0.000005, 0.17, 0.5, 0.83, 1.0, 1.25]
		for key: Array in keys:
			phases.append(float(key[0]))
		for n: int in range(1, keys.size()):
			for fraction: float in [0.125, 0.5, 0.875]:
				phases.append(lerpf(float(keys[n - 1][0]), float(keys[n][0]), fraction))
		for u: float in phases:
			var difference: float = BodyBake._keyed(keys, u) - _legacy_keyed(keys, u)
			assert_almost_eq(difference, 0.0, 0.0, "legacy difference at %.9f" % u)


func test_keyed_in_and_out_have_exact_endpoints_and_one_moving_end() -> void:
	var h: float = 0.125
	for ease: String in ["in", "out"]:
		var keys: Array = [[0.0, 2.0, ease], [1.0, 6.0]]
		var start: float = BodyBake._keyed(keys, 0.0)
		var end: float = BodyBake._keyed(keys, 1.0)
		assert_almost_eq(start - 2.0, 0.0, 0.0, ease + " start")
		assert_almost_eq(end - 6.0, 0.0, 0.0, ease + " end")
		for u: float in [0.125, 0.25, 0.5, 0.75, 0.875]:
			var t: float = u * u if ease == "in" else 1.0 - (1.0 - u) * (1.0 - u)
			assert_almost_eq(BodyBake._keyed(keys, u) - lerpf(2.0, 6.0, t), 0.0, 0.0, ease + " quadratic")
		# Second-order one-sided differences are exact for a quadratic.
		var start_speed: float = (-3.0 * start + 4.0 * BodyBake._keyed(keys, h) - BodyBake._keyed(keys, 2.0 * h)) / (2.0 * h)
		var end_speed: float = (3.0 * end - 4.0 * BodyBake._keyed(keys, 1.0 - h) + BodyBake._keyed(keys, 1.0 - 2.0 * h)) / (2.0 * h)
		if ease == "in":
			assert_almost_eq(start_speed, 0.0, 0.0, "in starts at rest")
			assert_gt(end_speed, 0.0, "in arrives moving")
		else:
			assert_gt(start_speed, 0.0, "out departs moving")
			assert_almost_eq(end_speed, 0.0, 0.0, "out ends at rest")


func test_short_tagged_segments_use_the_actual_positive_span() -> void:
	for ease: String in ["in", "out"]:
		var keys: Array = [[0.0, 0.0, ease], [0.00001, 1.0]]
		assert_almost_eq(BodyBake._keyed(keys, 0.000005), 0.25 if ease == "in" else 0.75, 0.00000001)
		assert_almost_eq(BodyBake._keyed(keys, 0.00001 - 0.000000000001), 1.0, 0.000001, "continuous before endpoint")
		assert_eq(BodyBake._keyed(keys, 0.00001), 1.0)


func test_compact_preserves_failure_only_results_with_and_without_keep() -> void:
	var failed: Dictionary = {"fit_failures": ["KEY_EASE_UNKNOWN clip=bad_clip value=sideways"]}
	for keep: Array in [[], ["p_swing_axe"]]:
		assert_eq(BodyBake.compact(failed, keep), failed)


func test_invalid_layer_stops_real_bakers_before_sampling_even_for_own_stills() -> void:
	# Compile a private table; never mutate the production constant.
	var source: String = FileAccess.get_file_as_string("res://scripts/body_bake.gd").replace("\r\n", "\n")
	var marker: String = "[\"axe_support\", [\"keys\", [[0.0, 4]"
	assert_true(source.contains(marker))
	var baker: GDScript = GDScript.new()
	baker.source_code = source.replace(marker, "[\"axe_support\", [\"keys\", [[0.0, 4, \"sideways\"]")
	assert_eq(baker.reload(), OK)
	var entry: Array = ["bad_clip", "", 32, false, "p_swing_axe", 0.9]
	var ctx: Dictionary = {"sampling_sentinel": 17}
	var listed: Dictionary = baker.call("_bake_list", ctx, [entry], [])
	assert_eq(listed, {"fit_failures": ["KEY_EASE_UNKNOWN clip=bad_clip value=sideways"]})
	assert_eq(ctx, {"sampling_sentinel": 17}, "no sampling or fit state touched")
	# Missing rigs would error if either entry point got past its preflight.
	var own: Dictionary = baker.call("bake_own", null, [entry], [])
	assert_eq(own, listed)
	var still: Dictionary = baker.call("bake_own", null, [], [["p_swing_axe", 0.0, ""]])
	assert_eq(still, {"fit_failures": ["KEY_EASE_UNKNOWN clip=p_swing_axe value=sideways"]})


func test_key_ease_belongs_only_to_the_departure_key() -> void:
	var plain: Array = [[0.0, 0.0], [0.5, 4.0], [1.0, 8.0]]
	for ease: String in ["in", "out"]:
		var keys: Array = [[0.0, 0.0], [0.5, 4.0, ease], [1.0, 8.0]]
		for u: float in [0.125, 0.25, 0.375, 0.5]:
			assert_almost_eq(BodyBake._keyed(keys, u) - _legacy_keyed(plain, u), 0.0, 0.0, "arrival tag leaves prior segment unchanged")
		var expected: float = 5.0 if ease == "in" else 7.0
		assert_almost_eq(BodyBake._keyed(keys, 0.75) - expected, 0.0, 0.0, "next segment uses the tag")
		var mixed: Array = [[0.0, 0.0, "in"], [0.5, 4.0, ease], [1.0, 8.0, "out"]]
		assert_almost_eq(BodyBake._keyed(mixed, 0.25) - 1.0, 0.0, 0.0, "arrival cannot override departure")


func test_key_ease_reaches_aim_axes_swing_turn_sink_and_summed_values() -> void:
	var root: Node3D = _stick_body()
	add_child_autofree(root)
	var body: Skeleton3D = BodyBake.first_of(root, "Skeleton3D") as Skeleton3D
	var keyed_in: Array = ["keys", [[0.0, 0.0, "in"], [1.0, 1.0]]]
	var keyed_out: Array = ["keys", [[0.0, 0.0, "out"], [1.0, 1.0]]]
	var summed: Array = [keyed_in, keyed_out]
	var layer: Dictionary = {"steps": [
		["turn", "chest", "x", summed],
		["aim", "upper_arm.L", "forearm.L", [keyed_in, keyed_out, summed]],
		["swing", "upper_arm.R", "forearm.R", keyed_in, keyed_out],
	], "sink": keyed_in}
	for u: float in [0.25, 0.5]:
		var in_value: float = u * u
		var out_value: float = 1.0 - (1.0 - u) * (1.0 - u)
		var total: float = in_value + out_value
		assert_eq(total, 0.5 if u == 0.25 else 1.0)
		var expected: Dictionary = {"steps": [
			["turn", "chest", "x", total],
			["aim", "upper_arm.L", "forearm.L", [in_value, out_value, total]],
			["swing", "upper_arm.R", "forearm.R", in_value, out_value],
		], "sink": in_value}
		body.reset_bone_poses()
		BodyBake.apply_layer(body, layer, u)
		var actual: Array[Transform3D] = []
		for bone: int in body.get_bone_count():
			actual.append(body.get_bone_pose(bone))
		body.reset_bone_poses()
		BodyBake.apply_layer(body, expected, u)
		for bone: int in body.get_bone_count():
			var wanted: Transform3D = body.get_bone_pose(bone)
			assert_almost_eq(actual[bone].origin.distance_to(wanted.origin), 0.0, 0.0, "position")
			for axis: int in 3:
				assert_almost_eq(actual[bone].basis[axis].distance_to(wanted.basis[axis]), 0.0, 0.0, "rotation")


func test_unknown_key_ease_records_failure_even_on_unreached_and_last_keys() -> void:
	for bad: Variant in ["sideways", "", 7, null]:
		for index: int in 3:
			var keys: Array = [[0.2, 0.0], [0.6, 1.0], [1.0, 2.0]]
			(keys[index] as Array).append(bad)
			var spec: Dictionary = {"steps": [["aim", "upper_arm.L", "forearm.L", [0.0, ["keys", keys], 1.0]]]}
			var failures: Array[String] = BodyBake._key_ease_failures(spec, "bad_clip")
			assert_eq(failures.size(), 1, "one invalid key track")
			assert_eq(failures[0], "KEY_EASE_UNKNOWN clip=bad_clip value=%s" % str(bad))
			assert_true(is_nan(BodyBake._keyed(keys, 0.0)), "no endpoint shortcut hides an invalid tag")
			assert_push_error("KEY_EASE_UNKNOWN clip=<direct> value=%s" % str(bad))
	var valid: Dictionary = {"sink": ["keys", [[0.0, 0.0, "in"], [0.5, 1.0, "out"], [1.0, 2.0]]]}
	assert_true(BodyBake._key_ease_failures(valid, "valid_clip").is_empty())


func test_unknown_key_ease_refuses_save_before_creating_a_directory() -> void:
	var spec: Array = ["keys", [[0.0, 0.0], [1.0, 1.0, "sideways"]]]
	var failures: Array[String] = BodyBake._key_ease_failures(spec, "bad_clip")
	var dir: String = "user://key_ease_refused_%d" % Time.get_ticks_usec()
	assert_false(DirAccess.dir_exists_absolute(dir), "fresh destination")
	BodyBake.save({"fit_failures": failures}, dir)
	assert_push_error("KEY_EASE_UNKNOWN clip=bad_clip value=sideways")
	assert_false(DirAccess.dir_exists_absolute(dir), "refusal precedes all file writes")


func test_only_axe_authors_ease_tags_and_all_clip_tables_validate() -> void:
	for clips: Array in [BodyBake.PERSON_CLIPS, BodyBake.CLIPS, BodyBake.OWN_CLIPS]:
		var tracks: Array = []
		for entry: Array in clips:
			if String(entry[4]) != "p_swing_axe":
				_collect_key_tracks(BodyBake.LAYERS.get(entry[4], {}), tracks)
		assert_gt(tracks.size(), 0, "each clip set exercises keyed tracks")
		for keys: Array in tracks:
			for key: Array in keys:
				assert_eq(key.size(), 2, "other clips retain two-field keys")
		assert_true(BodyBake._clip_key_ease_failures(clips).is_empty())
	var all_tracks: Array = []
	for layer_name: String in BodyBake.LAYERS:
		if layer_name != "p_swing_axe":
			_collect_key_tracks(BodyBake.LAYERS[layer_name], all_tracks)
	for keys: Array in all_tracks:
		for key: Array in keys:
			assert_eq(key.size(), 2, "all layers, including still poses")
	assert_true(BodyBake._clip_key_ease_failures(BodyBake.OWN_CLIPS, BodyBake.OWN_POSES).is_empty())


## Three vertices per sole, hand, head and forearm, with the original binds.
func _axe_stick(size: float = 1.0) -> Node3D:
	var root: Node3D = _stick_body(size)
	var body: Skeleton3D = BodyBake.first_of(root, "Skeleton3D") as Skeleton3D
	var mesh_node: MeshInstance3D = BodyBake.first_of(root, "MeshInstance3D") as MeshInstance3D
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for name_text: String in ["foot.L", "foot.R", "hand.R", "head", "forearm.R"]:
		var bone: int = body.find_bone(name_text)
		var origin: Vector3 = body.get_bone_global_rest(bone).origin
		for offset: Vector3 in [Vector3(-0.02, 0.0, -0.03), Vector3(0.02, 0.0, -0.03), Vector3(0.0, 0.0, 0.06)]:
			vertices.append(origin + offset * size)
			normals.append(Vector3.UP)
			bones.append_array([bone, 0, 0, 0])
			weights.append_array([1.0, 0.0, 0.0, 0.0])
			indices.append(indices.size())
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_node.mesh = mesh
	return root


func _axe_entry() -> Array:
	for entry: Array in BodyBake.PERSON_CLIPS:
		if String(entry[0]) == "p_swing_axe":
			return entry.duplicate(true)
	return []


## Decode the saved vertex layout, then interpolate exactly as VAT does.
func _axe_vertex(assets: Dictionary, vertex: int, u: float) -> Vector3:
	var arrays: Array = (assets["mesh"] as Mesh).surface_get_arrays(0)
	var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var look: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var clip: Dictionary = assets["clips"][0]
	var frame: float = clampf(u, 0.0, 1.0) * float(int(clip["frames"]) - 1)
	var first: int = int(floorf(frame))
	var last: int = mini(first + 1, int(clip["frames"]) - 1)
	var image: Image = assets["image"]
	var x: int = int(look[vertex].x * float(assets["width"]))
	var row: int = int(look[vertex].y)
	var a: Color = image.get_pixel(x, (int(clip["start"]) + first) * int(assets["rows_per_frame"]) + row)
	var b: Color = image.get_pixel(x, (int(clip["start"]) + last) * int(assets["rows_per_frame"]) + row)
	return rest[vertex] + Vector3(a.r, a.g, a.b).lerp(Vector3(b.r, b.g, b.b), frame - float(first))


func _axe_hand(assets: Dictionary, u: float) -> Vector3:
	return (_axe_vertex(assets, 6, u) + _axe_vertex(assets, 7, u) + _axe_vertex(assets, 8, u)) / 3.0


func _axe_time(u: float) -> float:
	return u * 0.30 / 0.45 if u <= 0.45 else 0.30 + (u - 0.45) * BodyBake.AXE_RECOVER_SECONDS / 0.55


func test_axe_keys_close_and_saved_hand_lands_at_speed() -> void:
	var pose_script: GDScript = preload("res://game/actors/person_pose.gd")
	assert_almost_eq(float(pose_script.call("recover_seconds", "axe")), BodyBake.AXE_RECOVER_SECONDS, 0.000001)
	var tracks: Array = []
	_collect_key_tracks(BodyBake.LAYERS["p_swing_axe"], tracks)
	for step: Array in BodyBake.LAYERS["p_swing_axe"]["steps"]:
		if String(step[0]) == "aim" and String(step[1]).ends_with(".R"):
			for axis: Array in step[3]:
				assert_gte((axis[1] as Array).size(), 8, "right arm key count")
	for keys: Array in tracks:
		assert_eq(float(keys[0][1]), float(keys[-1][1]), "K0 equals K9")
	var root: Node3D = _axe_stick()
	add_child_autofree(root)
	var assets: Dictionary = BodyBake.bake_own(root, [_axe_entry()], [])
	var ctx: Dictionary = BodyBake.prepare_own(root)
	var player: AnimationPlayer = AnimationPlayer.new()
	add_child_autofree(player)
	ctx["player"] = player
	var listed: Dictionary = BodyBake._bake_list(ctx, [_axe_entry()], [])
	assert_eq(listed["clips"], assets["clips"])
	assert_eq((listed["image"] as Image).get_data(), (assets["image"] as Image).get_data(), "both bake paths")
	assert_true((assets.get("fit_failures", []) as Array).is_empty())
	assert_eq(int(assets["clips"][0]["frames"]), 32)
	for vertex: int in 9:
		assert_lt(_axe_vertex(assets, vertex, 0.0).distance_to(_axe_vertex(assets, vertex, 1.0)), 0.000001)
	var maximum: float = 0.0
	for frame: int in 31:
		var a: float = float(frame) / 31.0
		var b: float = float(frame + 1) / 31.0
		var speed: float = _axe_hand(assets, a).distance_to(_axe_hand(assets, b)) / (_axe_time(b) - _axe_time(a))
		maximum = maxf(maximum, speed)
	# Incoming speed at impact, using saved hand vertices, not key derivatives.
	var before: float = 0.45 - 0.0001
	var at_hit: float = _axe_hand(assets, before).distance_to(_axe_hand(assets, 0.45)) / (_axe_time(0.45) - _axe_time(before))
	assert_gt(maximum, 0.0)
	assert_gte(at_hit, maximum * 0.6, "incoming hit speed / clip maximum")


func test_axe_low_pose_holds_continuously_for_a_tenth_second() -> void:
	var root: Node3D = _axe_stick()
	add_child_autofree(root)
	var assets: Dictionary = BodyBake.bake_own(root, [_axe_entry()], [])
	# The blow's own low point: from where it lands until the body recovers.
	# The resting hand hangs lower at the side, so the clip ends do not count.
	var lowest: float = INF
	for sample: int in 1001:
		var u: float = lerpf(0.45, BodyBake.AXE_BODY_PHASE, float(sample) / 1000.0)
		lowest = minf(lowest, _axe_hand(assets, u).y)
	var run_start: float = -1.0
	var longest: float = 0.0
	for sample: int in 1001:
		var u: float = lerpf(0.45, BodyBake.AXE_BODY_PHASE, float(sample) / 1000.0)
		var time: float = _axe_time(u)
		if _axe_hand(assets, u).y <= lowest + 0.025:
			if run_start < 0.0:
				run_start = time
			longest = maxf(longest, time - run_start)
		else:
			run_start = -1.0
	assert_gte(longest, 0.10, "within 2.5 cm of the lowest saved hand position")
	var anchor: Vector3 = _axe_hand(assets, BodyBake.AXE_LOW_PHASE)
	for sample: int in 101:
		var u: float = lerpf(BodyBake.AXE_LOW_PHASE, BodyBake.AXE_HOLD_PHASE, float(sample) / 100.0)
		assert_lte(_axe_hand(assets, u).distance_to(anchor), 0.025, "continuous low hold")
	assert_gte(_axe_time(BodyBake.AXE_HOLD_PHASE) - _axe_time(BodyBake.AXE_LOW_PHASE), 0.10)


func test_axe_planted_sole_vertices_and_orientation_survive_body_sizes() -> void:
	for size: float in [0.85, 1.0, 1.15]:
		var root: Node3D = _axe_stick(size)
		add_child_autofree(root)
		var stand: Dictionary = BodyBake.bake_own(root, [["reference", "", 2, false, "p_stand", 1.0]], [])
		var assets: Dictionary = BodyBake.bake_own(root, [_axe_entry()], [])
		assert_true((assets.get("fit_failures", []) as Array).is_empty())
		for sample: int in 311:
			var u: float = float(sample) / 310.0
			for vertex: int in 6:
				var point: Vector3 = _axe_vertex(assets, vertex, u)
				assert_lte(point.distance_to(_axe_vertex(stand, vertex, 0.0)), 0.01, "standing sole stays planted")
				assert_gte(point.y, -0.01)
				assert_lte(point.y, 0.015)
			for first: int in [0, 3]:
				var edge: Vector3 = _axe_vertex(assets, first + 1, u) - _axe_vertex(assets, first, u)
				var reference: Vector3 = _axe_vertex(stand, first + 1, 0.0) - _axe_vertex(stand, first, 0.0)
				assert_lt(edge.distance_to(reference), 0.00001, "sole direction")


func test_axe_support_rejects_impossible_knees_and_keeps_failure() -> void:
	var root: Node3D = _axe_stick()
	add_child_autofree(root)
	var ctx: Dictionary = BodyBake.prepare_own(root)
	var body: Skeleton3D = ctx["body"]
	var bad: Array[Dictionary] = BodyBake._plant_axe_support(body, 60.0)
	assert_false(bad.is_empty())
	BodyBake._record_axe_failures(ctx, "p_swing_axe", bad)
	BodyBake.pose(ctx, "", "p_swing_axe", 0.0)
	assert_true(String(ctx["fit_failures"][0]).begins_with("AXE_SUPPORT_UNFIT"))
	# Planted feet keep their own rest height, so moving a whole leg changes
	# nothing; a right leg twice as long needs a lower pelvis than the left allows.
	for name_text: String in ["shin.R", "foot.R"]:
		var rest: Transform3D = body.get_bone_rest(body.find_bone(name_text))
		rest.origin *= 2.0
		body.set_bone_rest(body.find_bone(name_text), rest)
	body.reset_bone_poses()
	var lopsided: Array[Dictionary] = BodyBake._plant_axe_support(body, 36.0)
	assert_false(lopsided.is_empty(), "asymmetric legs have no shared allowed height")
	if not lopsided.is_empty():
		assert_eq(String(lopsided[0]["reason"]), "no_shared_height")


## Recover the saved head basis from three non-collinear skin vertices.
func _axe_head_basis(assets: Dictionary, u: float) -> Basis:
	var left: Vector3 = _axe_vertex(assets, 9, u)
	var right: Vector3 = _axe_vertex(assets, 10, u)
	var front: Vector3 = _axe_vertex(assets, 11, u)
	var x_axis: Vector3 = (right - left).normalized()
	var z_axis: Vector3 = (front - (left + right) * 0.5).normalized()
	return Basis(x_axis, z_axis.cross(x_axis).normalized(), z_axis).orthonormalized()


func test_axe_saved_head_rotation_changes_by_at_most_twelve_degrees() -> void:
	var root: Node3D = _axe_stick()
	add_child_autofree(root)
	var assets: Dictionary = BodyBake.bake_own(root, [_axe_entry()], [])
	assert_true((assets.get("fit_failures", []) as Array).is_empty())
	assert_eq(int(assets["clips"][0]["frames"]), 32)
	# 0.67 rad over K5..K7 and 0.62 over K7..K8 need at most 10.1 deg
	# per saved interval under smoothstep; 12 deg adds a 20 percent margin.
	for frame: int in 31:
		var before: Basis = _axe_head_basis(assets, float(frame) / 31.0)
		var after: Basis = _axe_head_basis(assets, float(frame + 1) / 31.0)
		assert_lte(absf(rad_to_deg(after.get_euler().x - before.get_euler().x)), 12.0, "saved head pitch")
		assert_lte(rad_to_deg(before.get_rotation_quaternion().angle_to(after.get_rotation_quaternion())), 12.0, "saved head rotation")
	var ctx: Dictionary = BodyBake.prepare_own(root)
	var body: Skeleton3D = ctx["body"]
	for sample: int in 101:
		BodyBake.pose(ctx, "", "p_swing_axe", lerpf(0.3255, 0.45, float(sample) / 100.0))
		var head: Basis = body.get_bone_global_pose(body.find_bone("head")).basis
		assert_almost_eq(head.get_euler().x, 0.0, 0.00001, "K3..K5 cancellation")
	assert_true(_axe_head_basis(assets, 0.0).is_equal_approx(_axe_head_basis(assets, 1.0)))


func test_axe_forearm_lateral_limit_at_1001_phases_and_saved_blends() -> void:
	var root: Node3D = _axe_stick()
	add_child_autofree(root)
	var assets: Dictionary = BodyBake.bake_own(root, [_axe_entry()], [])
	assert_true((assets.get("fit_failures", []) as Array).is_empty())
	var ctx: Dictionary = BodyBake.prepare_own(root)
	var body: Skeleton3D = ctx["body"]
	for sample: int in 1001:
		var u: float = float(sample) / 1000.0
		BodyBake.pose(ctx, "", "p_swing_axe", u)
		var elbow: Vector3 = body.get_bone_global_pose(body.find_bone("forearm.R")).origin
		var hand: Vector3 = body.get_bone_global_pose(body.find_bone("hand.R")).origin
		assert_lte(absf((hand - elbow).normalized().x), 0.6, "posed forearm at %.3f" % u)
		var saved_elbow: Vector3 = (_axe_vertex(assets, 12, u) + _axe_vertex(assets, 13, u) + _axe_vertex(assets, 14, u)) / 3.0
		assert_lte(absf((_axe_hand(assets, u) - saved_elbow).normalized().x), 0.6, "saved forearm at %.3f" % u)
	# Original authored directions remain exact at all ten keys.
	var phases: Array[float] = [0.0, 0.1005, 0.2505, 0.3255, 0.4005, 0.45, BodyBake.AXE_LOW_PHASE, BodyBake.AXE_HOLD_PHASE, BodyBake.AXE_BODY_PHASE, 1.0]
	var directions: Array[Vector3] = [Vector3(0.15, -1, 0.1), Vector3(0.56, -0.02, 0.83), Vector3(0.44, 0.68, -0.59),
		Vector3(0.47, 0.64, -0.6), Vector3(0.39, 0.89, 0.25), Vector3(0.53, -0.81, 0.24),
		Vector3(0.53, -0.85, 0.07), Vector3(0.54, -0.84, 0.05), Vector3(0.53, -0.84, 0.06), Vector3(0.15, -1, 0.1)]
	for index: int in phases.size():
		BodyBake.pose(ctx, "", "p_swing_axe", phases[index])
		var elbow: Vector3 = body.get_bone_global_pose(body.find_bone("forearm.R")).origin
		var hand: Vector3 = body.get_bone_global_pose(body.find_bone("hand.R")).origin
		assert_lt((hand - elbow).normalized().distance_to(directions[index].normalized()), 0.00001, "authored direction")


func _assert_axe_leg_fit(lengths: Array) -> void:
	var root: Node3D = _axe_stick()
	add_child_autofree(root)
	var body: Skeleton3D = BodyBake.first_of(root, "Skeleton3D") as Skeleton3D
	for index: int in 2:
		var side: String = "L" if index == 0 else "R"
		var pair: Vector2 = lengths[index]
		var shin: int = body.find_bone("shin." + side)
		var foot: int = body.find_bone("foot." + side)
		body.set_bone_rest(shin, Transform3D(Basis(), Vector3(0, -pair.x, 0)))
		body.set_bone_rest(foot, Transform3D(Basis(), Vector3(0, -pair.y, 0)))
	for target_angle: float in [4.0, 10.0, 26.0, 36.0, 41.0]:
		body.reset_bone_poses()
		var failures: Array[Dictionary] = BodyBake._plant_axe_support(body, target_angle)
		assert_true(failures.is_empty(), str(failures))
		for side: String in ["L", "R"]:
			var thigh_id: int = body.find_bone("thigh." + side)
			var foot_id: int = body.find_bone("foot." + side)
			var thigh_rest: Vector3 = body.get_bone_global_rest(thigh_id).origin
			var target: Vector3 = body.get_bone_global_rest(foot_id).origin
			target.x = thigh_rest.x + (0.05 if side == "L" else -0.05)
			var thigh: Vector3 = body.get_bone_global_pose(thigh_id).origin
			var shin: Vector3 = body.get_bone_global_pose(body.find_bone("shin." + side)).origin
			var foot: Vector3 = body.get_bone_global_pose(foot_id).origin
			var knee: float = rad_to_deg((shin - thigh).angle_to(foot - shin))
			assert_gte(knee, maxf(0.0, target_angle - 5.0) - 0.001)
			assert_lte(knee, minf(50.0, target_angle + 5.0) + 0.001)
			assert_lte(foot.distance_to(target), 0.001, "actual ankle target error")
			var axis: Vector3 = (foot - thigh).normalized()
			assert_gt(((shin - thigh) - axis * (shin - thigh).dot(axis)).z, 0.0, "knee bends forward")


func test_axe_support_fits_unequal_upper_and_lower_lengths() -> void:
	_assert_axe_leg_fit([Vector2(0.62, 0.38), Vector2(0.62, 0.38)])


func test_axe_support_fits_asymmetric_legs_with_shared_height() -> void:
	_assert_axe_leg_fit([Vector2(0.62, 0.38), Vector2(0.55, 0.45)])


func test_axe_support_rejects_actual_post_solve_ankle_error() -> void:
	var root: Node3D = _axe_stick()
	add_child_autofree(root)
	var ctx: Dictionary = BodyBake.prepare_own(root)
	var body: Skeleton3D = ctx["body"]
	var foot: int = body.find_bone("foot.L")
	# Rest geometry is feasible; a shorter posed shin defeats the actual solve.
	body.set_bone_pose_position(foot, body.get_bone_rest(foot).origin * 0.8)
	var failures: Array[Dictionary] = BodyBake._plant_axe_support(body, 36.0)
	assert_eq(failures.size(), 1)
	if failures.size() != 1:
		return
	assert_eq(String(failures[0]["reason"]), "post_solve")
	assert_eq(String(failures[0]["side"]), "L")
	assert_almost_eq(float(failures[0]["ankle_error"]), 0.1, 0.00001)
	BodyBake._record_axe_failures(ctx, "p_swing_axe", failures)
	assert_true(String(ctx["fit_failures"][0]).begins_with("AXE_SUPPORT_UNFIT"))
	BodyBake.pose(ctx, "", "p_swing_axe", 0.0)
	assert_true(String(ctx["fit_failures"][0]).begins_with("AXE_SUPPORT_UNFIT"))


func test_other_clips_keep_legacy_bake_tables_layout_and_values() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/body_bake_08530f0a.json"))
	var tables: Dictionary = {"CLIPS": BodyBake.CLIPS, "OWN_CLIPS": BodyBake.OWN_CLIPS,
		"PERSON_CLIPS": BodyBake.PERSON_CLIPS, "POSES": BodyBake.POSES, "OWN_POSES": BodyBake.OWN_POSES,
		"PERSON_KEEP": BodyBake.PERSON_KEEP, "DEAD_KEEP": BodyBake.DEAD_KEEP}
	for name_text: String in tables:
		var actual: Array = []
		for entry: Variant in tables[name_text]:
			var clip_name: String = String(entry[0]) if entry is Array else String(entry)
			if clip_name != "p_swing_axe":
				actual.append(entry)
		# JSON normalizes numeric types without accepting a changed value.
		var normalized: Array = JSON.parse_string(JSON.stringify(actual))
		assert_eq(normalized, baseline[name_text] as Array, name_text + " at 08530f0a")
	var source: String = FileAccess.get_file_as_string("res://scripts/body_bake.gd").replace("\r\n", "\n")
	var first: int = source.find("const WALK_LEGS:")
	var last: int = source.find("const AXES:", first)
	var axe_start: int = source.find("\t\"p_swing_axe\": {", first)
	var axe_end: int = source.find("\n\t# Knife:", axe_start)
	assert_gte(first, 0)
	assert_gt(last, first)
	assert_gt(axe_start, first)
	assert_gt(axe_end, axe_start)
	if first < 0 or last < 0 or axe_start < 0 or axe_end < 0:
		return
	var fixed_layers: String = source.substr(first, axe_start - first) + source.substr(axe_end, last - axe_end)
	assert_eq(fixed_layers.sha256_text(), String(baseline["layer_source_sha256"]), "other layers and shared tracks at 08530f0a")


func test_other_clips_keep_untagged_bake_layout_and_values() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/body_bake.gd").replace("\r\n", "\n")
	var tests: String = FileAccess.get_file_as_string("res://tests/test_body_bake.gd").replace("\r\n", "\n")
	var formula_start: int = tests.find("func _legacy_keyed(")
	var formula_end: int = tests.find("\n\nfunc _collect_key_tracks", formula_start)
	var formula: String = tests.substr(formula_start, formula_end - formula_start).replace("func _legacy_keyed(", "static func _keyed(")
	var start: int = source.find("static func _keyed(")
	var stop: int = source.find("## Interpolate lateral share", start)
	assert_gte(start, 0)
	assert_gt(stop, start)
	source = source.substr(0, start) + formula + "\n\n" + source.substr(stop)
	var legacy: GDScript = GDScript.new()
	legacy.source_code = source
	assert_eq(legacy.reload(), OK)
	# Same neutral source for every authored layer, in table order.
	var entries: Array = []
	for table: Array in [BodyBake.CLIPS, BodyBake.OWN_CLIPS, BodyBake.PERSON_CLIPS]:
		for entry: Array in table:
			if String(entry[4]).is_empty() or String(entry[4]) == "p_swing_axe":
				continue
			entries.append([entry[0], "", entry[2], entry[3], entry[4], float(entry[5]) if entry.size() > 5 else 1.0])
	var root: Node3D = _axe_stick()
	add_child_autofree(root)
	var expected: Dictionary = legacy.call("bake_own", root, entries, BodyBake.OWN_POSES)
	var actual: Dictionary = BodyBake.bake_own(root, entries, BodyBake.OWN_POSES)
	assert_eq(actual.get("fit_failures", []), expected.get("fit_failures", []))
	assert_eq(actual["clips"], expected["clips"], "names, counts, starts, lengths and rounds")
	for field: String in ["width", "height", "rows_per_frame", "vertices"]:
		assert_eq(actual[field], expected[field], field)
	assert_eq((actual["image"] as Image).get_data(), (expected["image"] as Image).get_data(), "saved offsets")
	assert_eq((actual["mesh"] as Mesh).surface_get_arrays(0), (expected["mesh"] as Mesh).surface_get_arrays(0), "mesh and UV2")
	var small_actual: Dictionary = BodyBake.compact(actual, BodyBake.PERSON_KEEP)
	var small_expected: Dictionary = legacy.call("compact", expected, BodyBake.PERSON_KEEP)
	assert_eq(small_actual["clips"], small_expected["clips"], "quantization bounds and placement")
	assert_eq((small_actual["image"] as Image).get_data(), (small_expected["image"] as Image).get_data(), "packed values")


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
