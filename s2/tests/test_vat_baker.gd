extends "res://addons/gut/test.gd"

const VatBaker = preload("res://scripts/vat_baker.gd")

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

func test_device_levels_fit_without_folding() -> void:
	var assets := VatBaker.build(3000)
	assert_true(int(assets["vertices"]) >= 3000)
	assert_true(int(assets["width"]) <= VatBaker.MAX_WIDTH)
	gut.p("VAT 3000 target: %d vertices, rows %d" % [int(assets["vertices"]), int(assets["rows_per_frame"])])
