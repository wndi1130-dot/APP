extends "res://addons/gut/test.gd"

const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")

func test_default_box_zombie_keeps_one_row_per_frame() -> void:
	var assets := VatBaker.build()
	assert_eq(int(assets["vertices"]), 144)
	assert_eq(int(assets["rows_per_frame"]), 1)
	assert_eq(int(assets["height"]), VatBaker.FRAMES * 2)

func test_dense_zombie_folds_rows_and_writes_last_vertex() -> void:
	var assets := VatBaker.build(1500, 1024)
	var vertices := int(assets["vertices"])
	var rows := int(assets["rows_per_frame"])
	assert_true(vertices >= 1500, "vertices %d" % vertices)
	assert_eq(int(assets["width"]), 1024)
	assert_eq(rows, ceili(vertices / 1024.0))
	assert_true(rows > 1)
	assert_eq(int(assets["height"]), VatBaker.FRAMES * 2 * rows)
	# Chase clip, quarter phase: the last vertex is on a swinging leg.
	var image: Image = assets["image"]
	var last := vertices - 1
	var texel := image.get_pixel(last % 1024, (VatBaker.FRAMES + VatBaker.FRAMES / 4) * rows + last / 1024)
	assert_eq(texel.a, 1.0)
	assert_true(absf(texel.g - 0.5) + absf(texel.b - 0.5) > 0.01)
	gut.p("VAT 1500 target: %d vertices, %dx%d" % [vertices, int(assets["width"]), int(assets["height"])])

## Three vertices on two bones: 0 rides bone 0, 1 rides bone 1, 2 is half each.
func _two_bone_source() -> Array:
	var source: Array = []
	source.resize(Mesh.ARRAY_MAX)
	source[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 0.5, 0)])
	source[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	source[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	source[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0])
	source[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 0.5, 0.5, 0, 0])
	return source

func test_skinned_bake_stacks_clips_with_their_own_frame_counts() -> void:
	var still := [Transform3D(), Transform3D()]
	var lifted := [Transform3D(), Transform3D(Basis(), Vector3(0, 2, 0))]
	var clips := [{"name": "walk", "frames": [still, lifted, still]}, {"name": "fall", "loop": false, "length": 2.4, "frames": [still, lifted, lifted, lifted, lifted]}]
	var assets := VatBaker.build_skinned(_two_bone_source(), clips)
	assert_eq(int(assets["vertices"]), 3)
	assert_eq(int(assets["width"]), 3)
	assert_eq(int(assets["height"]), 8)
	var table: Array = assets["clips"]
	assert_eq(int(table[0]["start"]), 0)
	assert_eq(int(table[1]["start"]), 3)
	assert_eq(int(table[1]["frames"]), 5)
	assert_false(bool(table[1]["loop"]))
	assert_true(bool(table[0]["loop"]))
	assert_eq((assets["mesh"] as ArrayMesh).surface_get_array_len(0), 3)

func test_skinned_bake_writes_weighted_offsets_in_metres() -> void:
	var still := [Transform3D(), Transform3D()]
	var lifted := [Transform3D(), Transform3D(Basis(), Vector3(0, 2, 0))]
	var assets := VatBaker.build_skinned(_two_bone_source(), [{"name": "lift", "frames": [still, lifted]}])
	var image: Image = assets["image"]
	assert_almost_eq(image.get_pixel(0, 1).g, 0.0, 0.001, "bone 0 does not move")
	assert_almost_eq(image.get_pixel(1, 1).g, 2.0, 0.001, "past the 0.5 an 8 bit bake could hold")
	assert_almost_eq(image.get_pixel(2, 1).g, 1.0, 0.001, "half of each bone")
	assert_almost_eq(image.get_pixel(1, 0).g, 0.0, 0.001, "rest frame")

func test_skinned_bake_folds_rows_past_the_width() -> void:
	var still := [Transform3D(), Transform3D()]
	var lifted := [Transform3D(), Transform3D(Basis(), Vector3(0, 2, 0))]
	var assets := VatBaker.build_skinned(_two_bone_source(), [{"name": "lift", "frames": [still, lifted]}], 2)
	assert_eq(int(assets["rows_per_frame"]), 2)
	assert_eq(int(assets["height"]), 4)
	# Vertex 2 folds to the second row of each frame.
	assert_almost_eq((assets["image"] as Image).get_pixel(0, 3).g, 1.0, 0.001)

# Split at a seam, two vertices at one place with the same bones and weights
# move alike: one column, both pointing at it. One more at that place riding
# another bone moves its own way and keeps its own column.
func test_vertices_that_move_alike_share_one_column() -> void:
	var source := _two_bone_source()
	source[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 0.5, 0), Vector3(0, 1, 0), Vector3(0, 1, 0)])
	source[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.LEFT, Vector3.BACK])
	source[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 2, 3, 4])
	source[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0])
	source[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 0.5, 0.5, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var still := [Transform3D(), Transform3D()]
	var lifted := [Transform3D(), Transform3D(Basis(), Vector3(0, 2, 0))]
	var assets := VatBaker.build_skinned(source, [{"name": "lift", "frames": [still, lifted]}])
	assert_eq(int(assets["vertices"]), 5, "the mesh keeps every vertex")
	assert_eq(int(assets["columns"]), 4)
	assert_eq(int(assets["width"]), 4)
	var look: PackedVector2Array = (assets["mesh"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	assert_eq(look[3], look[1], "the seam's other side reads the same column")
	assert_ne(look[4], look[1], "another bone, another column")
	var image: Image = assets["image"]
	for v: int in [1, 3, 4]:
		var lift := image.get_pixel(int(look[v].x * 4.0), 1).g
		assert_almost_eq(lift, 2.0 if v != 4 else 0.0, 0.001, "vertex %d moves with its own bone" % v)


func test_shader_tables_follow_the_clips_and_fill_every_slot() -> void:
	var still := [Transform3D(), Transform3D()]
	var clips := [{"name": "walk", "length": 1.5, "frames": [still, still, still]}, {"name": "fall", "loop": false, "length": 2.5, "frames": [still, still, still, still, still]}]
	var tables := VatBaker.shader_tables(VatBaker.build_skinned(_two_bone_source(), clips, 2))
	assert_eq((tables["clip_start"] as PackedFloat32Array).size(), VatBaker.TABLE_SIZE)
	assert_eq(tables["clip_start"][1], 3.0)
	assert_eq(tables["clip_frames"][1], 5.0)
	assert_eq(tables["clip_rate"][0], 2.0, "frames per second")
	assert_eq(tables["clip_loop"][0], 1.0)
	assert_eq(tables["clip_loop"][1], 2.0, "a fall does not loop and is on the ground (2 more, dead_vat.gdshaderinc lying)")
	assert_eq(fmod(tables["clip_loop"][1], 2.0), 0.0, "the shader reads its loop as the rest after 2")
	assert_eq(tables["clip_frames"][2], 0.0, "an empty slot")
	assert_eq(tables["frame_rows"], 8.0, "frames, not texture rows")
	assert_eq(tables["rows_per_frame"], 2.0)
	assert_eq(tables["bias"], 0.0)

func test_device_levels_fit_without_folding() -> void:
	var assets := VatBaker.build(3000)
	assert_true(int(assets["vertices"]) >= 3000)
	assert_true(int(assets["width"]) <= VatBaker.MAX_WIDTH)
	gut.p("VAT 3000 target: %d vertices, rows %d" % [int(assets["vertices"]), int(assets["rows_per_frame"])])

func test_pack_motion_keeps_the_sixteen_place_numbers_and_reaches_thirty_two() -> void:
	assert_eq(VatBaker.pack_motion(3), 3.0, "a plain clip is its number")
	assert_eq(VatBaker.pack_motion(5, 120, 20), 5.0 + 16.0 * 120.0 + 65536.0 * 20.0, "as dead_body.gd mixed writes it")
	assert_eq(VatBaker.pack_motion(15, 4095, VatBaker.SHARE_MAX), VatBaker.UPPER - 1.0, "the largest sixteen-place number stays below the upper part")
	assert_eq(VatBaker.pack_motion(16), VatBaker.UPPER)
	assert_eq(VatBaker.pack_motion(31, 4095, 31), 15.0 + 16.0 * 4095.0 + 65536.0 * 31.0 + VatBaker.UPPER)
	assert_eq(DeadBody.MIX_STEPS, float(VatBaker.SHARE_MAX), "the mix is told in as many steps as a share holds")


# 128 places (decisions 422 and after): 16..127 carry one to seven steps of
# UPPER, and the last with every frame and share is 2^24 - 1, still whole in a
# float. The shader's tables are as long as TABLE_SIZE, it takes UPPER off as
# often as it is in g and a share back over SHARE_MAX, and it rounds g rather
# than adding a half (above 2^23 a float has no halves: clip 33 drew as 34).
func test_pack_motion_reaches_128_and_the_shader_reads_it_the_same_way() -> void:
	assert_eq(VatBaker.TABLE_SIZE, 128)
	assert_eq(VatBaker.pack_motion(32), 2.0 * VatBaker.UPPER)
	assert_eq(VatBaker.pack_motion(127, 4095, VatBaker.SHARE_MAX), 16777215.0, "2^24 - 1")
	for clip in [0, 15, 16, 26, 31, 32, 33, 47, 63, 64, 95, 112, 127]:
		var g := Color(0.0, VatBaker.pack_motion(clip, 7, 9), 0.0).g
		assert_eq(DeadBody.motion_in(g), clip, "back through a 32-bit colour: %d" % clip)
	var shader: String = FileAccess.get_file_as_string("res://game/actors/dead_vat.gdshaderinc")
	for table in ["clip_start", "clip_frames", "clip_rate", "clip_loop", "clip_lo", "clip_hi"]:
		assert_string_contains(shader, "%s[%d]" % [table, VatBaker.TABLE_SIZE], table)
	assert_string_contains(shader, "n < %d" % VatBaker.TABLE_SIZE, "clip_of looks through every place")
	assert_string_contains(shader, "floor(packed / %.1f)" % VatBaker.UPPER, "the same UPPER")
	assert_string_contains(shader, "share / %.1f" % float(VatBaker.SHARE_MAX), "the same share")
	assert_string_contains(shader, "round(INSTANCE_CUSTOM.g)")
