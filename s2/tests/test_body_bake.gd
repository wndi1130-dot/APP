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
			assert_true(BodyBake.MAP.has(step[1]), "%s step %s" % [layer_name, step[1]])
			if step[0] == "turn":
				assert_true(BodyBake.AXES.has(step[2]))
			else:
				assert_true(BodyBake.MAP.has(step[2]), "%s aims at %s" % [layer_name, step[2]])


func test_the_three_walks_differ_and_the_motion_numbers_fit_the_shader_table() -> void:
	var names: Array = []
	for clip in BodyBake.CLIPS:
		names.append(clip[0])
	assert_eq(names, ["walk_a", "walk_b", "walk_c", "stand", "lunge", "hit", "fall", "run", "tell", "fall_front", "crawl", "rise", "climb", "rise_front", "stagger"], "the numbers the drawing side uses")
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


func test_reading_a_folder_with_no_bake_gives_nothing() -> void:
	assert_true(BodyBake.load_baked("user://no_such_bake_folder").is_empty())


func test_a_layer_value_can_swing_and_the_tell_runs_a_quarter_turn() -> void:
	assert_almost_eq(BodyBake._value(0.3, 2.0), 0.3, 0.0001, "a plain number stays")
	assert_almost_eq(BodyBake._value([0.2, 0.4, 0.0, 0.25], 0.0), 0.2, 0.0001, "the tell starts from the slump")
	assert_almost_eq(BodyBake._value([0.2, 0.4, 0.0, 0.25], TAU), 0.6, 0.0001, "and ends at its far end, without coming back")
	assert_false(bool(BodyBake.CLIPS[8][3]), "the tell plays once")
	assert_true(bool(BodyBake.CLIPS[7][3]), "the run loops")


## A stick body with the bones the baker asks for, standing with its arms out, and three skinned vertices.
func _stick_body() -> Node3D:
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
		body.set_bone_rest(id, Transform3D(Basis(), bone[2]))
	body.reset_bone_poses()
	for id in body.get_bone_count():
		skin.add_bind(id, body.get_bone_global_rest(id).affine_inverse())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var foot := body.find_bone("foot.L")
	var head := body.find_bone("head")
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0.1, 0, 0), Vector3(0, 1.7, 0), Vector3(0, 1, 0)])
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

