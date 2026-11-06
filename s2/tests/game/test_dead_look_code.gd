extends "res://addons/gut/test.gd"
## P0 transport contract. Numeric expectations do not use the production decoder.

const DeadCast = preload("res://game/actors/dead_cast.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const INCLUDE: String = "res://game/actors/dead_vat.gdshaderinc"
const SHADERS: Array[String] = ["actors/dead_vat", "actors/dead_weathered", "actors/dead_garment",
	"actors/person_vat", "train/people_faded"]


func _has(methods: Array[String]) -> bool:
	var present := true
	for method: String in methods:
		var found: bool = DeadCast.has_method(method)
		assert_true(found, "DeadCast implements " + method)
		present = present and found
	return present


func _half(value: float) -> float:
	var bytes := PackedByteArray()
	bytes.resize(2)
	bytes.encode_half(0, value)
	return bytes.decode_half(0)


func _shader_half(b: float) -> Vector2:
	var stored := _half(b)
	var code := floorf(_half(_half(stored * 0.5) + 0.25)) if stored >= 0.0 else 0.0
	return Vector2(_half(stored - _half(2.0 * code)), code)


func test_t1_every_code_and_still_round_trip_through_half_storage() -> void:
	if not _has(["pack_still", "unpack_still"]):
		return
	for code: int in 512:
		for still: float in [0.0, 1.0]:
			var packed: float = DeadCast.call("pack_still", still, code)
			assert_eq(packed, still + 2.0 * code, "wire value %d / %s" % [code, still])
			var restored: Vector2 = DeadCast.call("unpack_still", _half(packed))
			assert_eq(restored, Vector2(still, code))
			assert_eq(_shader_half(packed), Vector2(still, code), "each arithmetic step rounded to half")


func test_t1_negative_shiver_and_living_fraction_keep_their_value() -> void:
	if not _has(["pack_still", "unpack_still"]):
		return
	for b: float in [-0.5, -0.25, 0.0, 0.5, 1.0, 1.4]:
		var restored: Vector2 = DeadCast.call("unpack_still", b)
		assert_eq(restored, Vector2(b, 0.0))
		assert_eq(_shader_half(b), Vector2(_half(b), 0.0))
	for b: float in [-0.5, -0.25]:
		assert_eq(float(DeadCast.call("pack_still", b, 511)), b, "a shiver never carries a code")


func test_t1_invalid_pack_inputs_assert_at_the_boundary() -> void:
	if not _has(["pack_still", "unpack_still"]):
		return
	for code: int in [-1, 512, 1024]:
		DeadCast.call("pack_still", 0.0, code)
		assert_engine_error("look code must be within 0..511")
	for still: float in [0.5, 1.4, 1.5, 2.0, NAN, INF, -INF, -0.75]:
		DeadCast.call("pack_still", still, 8)
		assert_engine_error("still must be 0 or 1, or a shiver in -0.5..0")
	for b: float in [-0.75, 1024.0, NAN, INF, -INF]:
		DeadCast.call("unpack_still", b)
		assert_engine_error("packed still must be finite and within -0.5..1023")


func test_t2_half_boundaries_and_shader_use_the_same_safe_formula() -> void:
	if not _has(["unpack_still"]):
		return
	var expected: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 255),
		Vector2(1, 255), Vector2(0, 511), Vector2(1, 511), Vector2(-0.5, 0), Vector2(1, 0), Vector2(_half(1.4), 0)]
	var values: Array[float] = [0.0, 1.0, 510.0, 511.0, 1022.0, 1023.0, -0.5, 1.0, 1.4]
	for i: int in values.size():
		var decoded: Vector2 = DeadCast.call("unpack_still", _half(values[i]))
		assert_eq(decoded, expected[i])
		assert_eq(_shader_half(values[i]), expected[i])
	var source := FileAccess.get_file_as_string(INCLUDE)
	assert_true(source.contains("floor(INSTANCE_CUSTOM.b * 0.5 + 0.25)"))
	assert_true(source.contains("varying flat float look_code;"))
	assert_true(source.contains("float still_b = INSTANCE_CUSTOM.b - 2.0 * look_code;"))
	assert_true(source.contains("float hold = max(still_b, 0.0);"))
	assert_true(source.contains("float shiver = max(-still_b, 0.0);"))
	assert_false(source.get_slice("void fragment()", 1).contains("look_code"), "P0 never changes fragment colour")


	if not _has(["look_code_for", "look_code_migrated"]):
		return
	var outfits := {}
	var variants := {}
	for seed_value: int in [1, 11, -19, 9007199254740993]:
		for id: int in range(1, 257):
			var code: int = DeadCast.call("look_code_for", seed_value, id)
			assert_eq(code, int(DeadCast.call("look_code_for", seed_value, id)))
			outfits[code >> 3] = true
			variants[code % 8] = true
			assert_eq(int(DeadCast.call("look_code_migrated", seed_value, id, "")), code)
			assert_eq(int(DeadCast.call("look_code_migrated", seed_value, id, "이름 있는 사람")), 0)
	assert_eq(variants.size(), 8)
	var changed := 0
	for id: int in range(1, 65):
		if int(DeadCast.call("look_code_for", 1, id)) != int(DeadCast.call("look_code_for", 11, id)):
			changed += 1
	assert_gt(changed, 0, "the run seed participates in the private stream")


func test_t4_motion_changes_and_both_recoil_strengths_keep_b() -> void:
	var saved_table: Array = DeadBody.table
	var table: Array = []
	for i: int in range(DeadBody.HIT_UPPER + 1):
		table.append([i * 32, 32, true, 1.0])
	DeadBody.table = table
	for b: float in [0.0, 1.0, 1022.0, 1023.0, -0.5]:
		for power: float in [-1.0, 0.3, 0.7, 1.0]:
			var plain := Color(0.5, float(DeadBody.HIT_LEFT), b, 0.8)
			var z := {"age": 2.0, "hit_power": power}
			assert_eq(DeadBody.mixed(z, plain).b, b)
			var note := {"body_motion": 0, "body_r": 0.4}
			assert_eq(DeadBody.mix_from(note, plain, 2.0, table).b, b)
			assert_eq(DeadBody.mix_from(note, plain, 2.05, table).b, b)
			assert_eq(DeadBody.mix_from(note, plain, 3.0, table).b, b)
	DeadBody.table = saved_table


func test_t8_shell_bits_keep_pattern_seed_when_dirt_and_blood_change() -> void:
	if not _has(["shell_look_code"]):
		return
	for seed_bits: int in 8:
		for dirt: int in 8:
			for blood: int in 8:
				var tear := Color(float(blood) / 7.0, float(dirt) / 7.0, 0.9, 1.0)
				assert_eq(int(DeadCast.call("shell_look_code", 8 + seed_bits, tear)), dirt + 8 * blood + 64 * seed_bits)
	assert_eq(int(DeadCast.call("shell_look_code", 0, Color.WHITE)), 0, "code 0 has no new shell effect")
	assert_eq(int(DeadCast.call("shell_look_code", 15, Color(2, -1, 0, 1))), 504, "clamp strengths only")
	assert_eq(int(DeadCast.call("shell_look_code", 8, Color(0.5, 0.5, 0, 1))), 36, "nearest of eight levels")


func test_t9_all_five_shaders_share_the_include_and_legacy_hold_shiver() -> void:
	for path: String in SHADERS:
		var source := FileAccess.get_file_as_string("res://game/%s.gdshader" % path)
		assert_true(source.contains('#include "res://game/actors/dead_vat.gdshaderinc"'), path)
	for b: float in [-0.5, -0.25, 0.0, 1.0, 1.4]:
		var decoded := _shader_half(b)
		assert_eq(maxf(decoded.x, 0.0), maxf(_half(b), 0.0))
		assert_eq(maxf(-decoded.x, 0.0), maxf(-_half(b), 0.0))


func test_t9_five_shader_materials_attach_to_visible_meshes() -> void:
	# A renderer-backed gate must also inspect its terminal log for SHADER ERROR.
	# Dummy/headless rendering alone cannot prove that a GPU compiled the variants.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 0, 5)
	camera.current = true
	for index: int in SHADERS.size():
		var path := "res://game/%s.gdshader" % SHADERS[index]
		var shader := load(path) as Shader
		assert_not_null(shader, path)
		if shader == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = shader
		var body := MeshInstance3D.new()
		body.mesh = BoxMesh.new()
		body.material_override = material
		viewport.add_child(body)
		body.position.x = (float(index) - 2.0) * 0.65
		assert_same(body.material_override, material)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_engine_error_count(0)
