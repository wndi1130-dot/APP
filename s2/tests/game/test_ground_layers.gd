extends "res://addons/gut/test.gd"
## Decision 496: the imported array and its local build ledger agree.

const TEXTURE_PATH := "res://fx/textures/ground/ground_layers.png"
const LEDGER_PATH := "res://fx/textures/ground/ground_layers.json"
const SHADER_PATH := "res://game/world/world_vis.gdshader"
const EXPECTED := [
	["asphalt", "Road013A", 12.0],
	["asphalt_patched", "Road012B", 18.0],
	["concrete_road", "Concrete031", 3.0],
	["pavement", "PavingStones136", 2.5],
	["gravel", "Gravel041", 1.5],
	["ballast", "Gravel043", 1.5],
	["soil", "Ground106", 3.0],
	["dry_grass", "Ground037", 3.0],
]


func test_import_is_an_eight_layer_512_square_array() -> void:
	var resource = load(TEXTURE_PATH)
	# CompressedTexture2DArray and Texture2DArray share TextureLayered, not a
	# concrete parent class. Check the array kind as well as the imported class.
	assert_true(resource is CompressedTexture2DArray, "the 2d_array_texture importer")
	assert_true(resource is TextureLayered)
	if not resource is TextureLayered:
		return
	var layers := resource as TextureLayered
	assert_eq(layers.get_layered_type(), TextureLayered.LAYERED_TYPE_2D_ARRAY)
	assert_eq(layers.get_layers(), 8)
	assert_eq(layers.get_width(), 512)
	assert_eq(layers.get_height(), 512)
	assert_true(layers.has_mipmaps(), "distance filtering has mip levels")


func test_ledger_matches_the_build_tools_layer_order() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LEDGER_PATH))
	assert_true(parsed is Array)
	if not parsed is Array:
		return
	var rows: Array = parsed
	assert_eq(rows.size(), EXPECTED.size())
	if rows.size() != EXPECTED.size():
		return
	for i in EXPECTED.size():
		assert_true(rows[i] is Dictionary)
		if not rows[i] is Dictionary:
			continue
		var row: Dictionary = rows[i]
		assert_eq(int(row.get("index", -1)), i)
		assert_eq(row.get("name"), EXPECTED[i][0])
		assert_eq(row.get("source_id"), EXPECTED[i][1])
		assert_eq(float(row.get("tile_m", 0.0)), EXPECTED[i][2])
		assert_eq(row.get("license"), "CC0 1.0, ambientCG")


func test_shader_exposes_the_three_ground_uniforms() -> void:
	var shader := load(SHADER_PATH) as Shader
	assert_not_null(shader)
	if shader == null:
		return
	var names: Array[String] = []
	for uniform: Dictionary in shader.get_shader_uniform_list():
		names.append(str(uniform["name"]))
	for name: String in ["ground_layers", "ground_layers_on", "region_band"]:
		assert_has(names, name)


func test_room_floor_and_sight_lines_stay_in_place() -> void:
	var source := FileAccess.get_file_as_string(SHADER_PATH)
	assert_true(source.contains("vec3 room_floor(int code, vec2 p, vec2 px, out vec3 tone) {"))
	assert_true(source.contains("\t\t\tvec3 finish = room_floor(rc, world_pos.xz, room_px, tone);"))
	assert_true(source.contains("\tfloat lit = mix(1.0, max(reveal, floor_k), mask_on);"))


func test_png_rgb_means_are_half_strength_in_each_layer() -> void:
	# Read the source PNG, before GPU compression; alpha is height, not detail.
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(TEXTURE_PATH))
	assert_eq(error, OK)
	if error != OK:
		return
	assert_eq(image.get_size(), Vector2i(512, 4096))
	if image.get_size() != Vector2i(512, 4096):
		return
	image.convert(Image.FORMAT_RGBA8)
	var bytes := image.get_data()
	var pixels := 512 * 512
	for layer in EXPECTED.size():
		var sum := Vector3i.ZERO
		var first := layer * pixels * 4
		for offset in range(first, first + pixels * 4, 4):
			sum.x += bytes[offset]
			sum.y += bytes[offset + 1]
			sum.z += bytes[offset + 2]
		for channel in 3:
			var mean := float(sum[channel]) / float(pixels * 255)
			assert_almost_eq(mean, 0.5, 0.03, "%s channel %d" % [EXPECTED[layer][0], channel])
