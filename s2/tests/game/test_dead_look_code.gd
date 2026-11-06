extends "res://addons/gut/test.gd"
## P0 transport contract. Numeric expectations do not use the production decoder.

const DeadCast = preload("res://game/actors/dead_cast.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const INCLUDE: String = "res://game/actors/dead_vat.gdshaderinc"
const SHADERS: Array[String] = ["actors/dead_vat", "actors/dead_weathered", "actors/dead_garment",
	"actors/person_vat", "train/people_faded"]
## Frozen issuance snapshot from the clean design, 2026-11-07 sections 2 and 8-3.
## Later issuances may be appended to production; these pairs must never change.
const ISSUED_20261107: Dictionary[int, String] = {
	1: "flight_wool_long",
	2: "flight_quilted",
	3: "flight_short_coat",
	4: "flight_wrapped",
	5: "flight_layered",
	6: "flight_lined",
	7: "home_cardigan_coat",
	8: "home_robe_coat",
	9: "town_counter_winter",
	10: "town_outdoor_knit",
	21: "rail_two_tone_jacket",
	22: "rail_bib_overalls",
	23: "workshop_coat",
	24: "workshop_apron_vest",
	25: "farm_bib_overalls",
	26: "farm_work_coat",
	27: "shed_heavy_vest",
	41: "police_winter_coat",
	42: "police_duty",
	43: "fire_turnout",
	44: "fire_duty",
}
const COMMON_20261107: Dictionary[int, int] = {
	1: 89, 2: 89, 3: 88, 4: 88, 5: 88, 6: 88, 7: 90, 8: 90, 9: 80, 10: 80,
	21: 20, 22: 20, 23: 20, 25: 20, 26: 20, 41: 10, 42: 5, 43: 10, 44: 5,
}
const LOOK_METHODS: Array[String] = ["pack_still", "unpack_still", "active_look_code",
	"outfit_for_roll", "look_code_for", "look_code_migrated", "shell_look_code"]
var api: GDScript = DeadCast


func before_each() -> void:
	for method: String in LOOK_METHODS:
		assert_true(api.has_method(method), "required DeadCast method: " + method)


func _constant_dictionary(key: String) -> Dictionary:
	var constants: Dictionary = api.get_script_constant_map()
	assert_true(constants.has(key), "required DeadCast constant: " + key)
	var value: Variant = constants.get(key)
	assert_true(value is Dictionary, key + " must be a Dictionary")
	return value if value is Dictionary else {}


func test_required_look_methods_are_static() -> void:
	var flags := {}
	for method: Dictionary in api.get_script_method_list():
		flags[String(method["name"])] = int(method["flags"])
	for method: String in LOOK_METHODS:
		assert_true(flags.has(method), "declared look method: " + method)
		assert_ne(int(flags.get(method, 0)) & METHOD_FLAG_STATIC, 0, "static look method: " + method)


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
	for code: int in 512:
		for still: float in [0.0, 1.0]:
			var packed: float = api.call("pack_still", still, code)
			assert_eq(packed, still + 2.0 * code, "wire value %d / %s" % [code, still])
			var restored: Vector2 = api.call("unpack_still", _half(packed))
			assert_eq(restored, Vector2(still, code))
			assert_eq(_shader_half(packed), Vector2(still, code), "each arithmetic step rounded to half")


func test_t1_negative_shiver_and_living_fraction_keep_their_value() -> void:
	for b: float in [-0.5, -0.25, 0.0, 0.5, 1.0, 1.4]:
		var restored: Vector2 = api.call("unpack_still", b)
		assert_eq(restored, Vector2(b, 0.0))
		assert_eq(_shader_half(b), Vector2(_half(b), 0.0))
	for b: float in [-0.5, -0.25]:
		assert_eq(float(api.call("pack_still", b, 511)), b, "a shiver never carries a code")


func test_t1_invalid_pack_inputs_assert_at_the_boundary() -> void:
	for code: int in [-1, 512, 1024]:
		api.call("pack_still", 0.0, code)
		assert_engine_error("look code must be within 0..511")
	for still: float in [0.5, 1.4, 1.5, 2.0, NAN, INF, -INF, -0.75]:
		api.call("pack_still", still, 8)
		assert_engine_error("still must be 0 or 1, or a shiver in -0.5..0")
	for b: float in [-0.75, 1024.0, NAN, INF, -INF]:
		api.call("unpack_still", b)
		assert_engine_error("packed still must be finite and within -0.5..1023")


func test_t2_half_boundaries_and_shader_use_the_same_safe_formula() -> void:
	var expected: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 255),
		Vector2(1, 255), Vector2(0, 511), Vector2(1, 511), Vector2(-0.5, 0), Vector2(1, 0), Vector2(_half(1.4), 0)]
	var values: Array[float] = [0.0, 1.0, 510.0, 511.0, 1022.0, 1023.0, -0.5, 1.0, 1.4]
	for i: int in values.size():
		var decoded: Vector2 = api.call("unpack_still", _half(values[i]))
		assert_eq(decoded, expected[i])
		assert_eq(_shader_half(values[i]), expected[i])
	var source := FileAccess.get_file_as_string(INCLUDE)
	assert_true(source.contains("floor(INSTANCE_CUSTOM.b * 0.5 + 0.25)"))
	assert_true(source.contains("varying flat float look_code;"))
	assert_true(source.contains("float still_b = INSTANCE_CUSTOM.b - 2.0 * look_code;"))
	assert_true(source.contains("float hold = max(still_b, 0.0);"))
	assert_true(source.contains("float shiver = max(-still_b, 0.0);"))
	assert_false(source.get_slice("void fragment()", 1).contains("look_code"), "P0 never changes fragment colour")


func test_t3_four_seed_sequences_repeat_and_differ_as_whole_sequences() -> void:
	var variants := {}
	var sequences: Array = []
	for seed_value: int in [1, 11, -19, 9007199254740993]:
		var sequence: Array[int] = []
		for id: int in range(1, 257):
			var code: int = api.call("look_code_for", seed_value, id)
			assert_eq(code, int(api.call("look_code_for", seed_value, id)))
			assert_true(COMMON_20261107.has(code >> 3), "generated outfit has a positive common weight")
			assert_between(code, 8, 511)
			sequence.append(code)
			variants[code % 8] = true
			assert_eq(int(api.call("look_code_migrated", seed_value, id, "")), code)
			assert_eq(int(api.call("look_code_migrated", seed_value, id, "이름 있는 사람")), 0)
		sequences.append(sequence)
	assert_eq(variants.size(), 8)
	for a: int in sequences.size():
		for b: int in range(a + 1, sequences.size()):
			assert_ne(sequences[a], sequences[b], "different seeds change the whole output sequence")


func test_clean_outfit_rows_have_exact_numbers_ids_and_shape() -> void:
	var outfits := _constant_dictionary("LOOK_OUTFITS")
	var numbers: Array = outfits.keys()
	numbers.sort()
	assert_eq(numbers, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 21, 22, 23, 24, 25, 26, 27, 41, 42, 43, 44])
	var ids := {}
	for number: Variant in outfits:
		assert_true(number is int)
		assert_between(int(number), 1, 63)
		var row: Dictionary = outfits[number]
		var keys: Array = row.keys()
		keys.sort()
		assert_eq(keys, ["id", "kind", "set"], "each row has only the three clean fields")
		for key: String in ["id", "kind", "set"]:
			assert_true(row.get(key) is String, "text field: " + key)
		var id := String(row.get("id", ""))
		assert_ne(id, "")
		assert_false(ids.has(id), "outfit ids are unique")
		ids[id] = true
		assert_eq(id, String(ISSUED_20261107.get(number, "")))
		assert_true(row.get("kind") in ["plain", "work", "uniform"])
		assert_true(row.get("set") in ["flight", "home", "work"])
		var expected_kind := "plain" if int(number) <= 10 else ("work" if int(number) <= 27 else "uniform")
		var expected_set := "flight" if int(number) <= 6 else ("home" if int(number) <= 8 else "work")
		assert_eq(row.get("kind"), expected_kind)
		assert_eq(row.get("set"), expected_set)
	assert_false(outfits.has(0))


func test_issued_snapshot_is_append_only_and_active_ids_match() -> void:
	var issued := _constant_dictionary("LOOK_OUTFIT_ISSUED")
	var outfits := _constant_dictionary("LOOK_OUTFITS")
	var ids := {}
	for number: Variant in issued:
		assert_true(number is int)
		assert_between(int(number), 1, 63)
		assert_true(issued[number] is String)
		var id := String(issued[number])
		assert_ne(id, "")
		assert_false(ids.has(id), "issued ids are never reused")
		ids[id] = true
	for number: int in ISSUED_20261107:
		assert_true(issued.has(number), "keep the 2026-11-07 issuance")
		assert_eq(String(issued.get(number, "")), ISSUED_20261107[number])
	for number: int in outfits:
		assert_true(issued.has(number), "every active outfit has an issuance")
		assert_eq((outfits[number] as Dictionary).get("id"), issued.get(number))


func test_common_weights_match_the_clean_per_mille_table() -> void:
	var weights := _constant_dictionary("COMMON_LOOK_WEIGHTS")
	var outfits := _constant_dictionary("LOOK_OUTFITS")
	assert_eq(weights.size(), 19)
	assert_eq(weights, COMMON_20261107)
	var total := 0
	for number: Variant in weights:
		assert_true(number is int)
		assert_between(int(number), 1, 63)
		assert_true(outfits.has(number), "a common outfit is active")
		assert_true(weights[number] is int)
		assert_gt(int(weights[number]), 0)
		total += int(weights[number])
	assert_eq(total, 1000)
	assert_false(weights.has(24), "place-only outfit")
	assert_false(weights.has(27), "place-only outfit")


func test_weight_totals_by_kind_set_and_integer_concentration() -> void:
	var weights := _constant_dictionary("COMMON_LOOK_WEIGHTS")
	var outfits := _constant_dictionary("LOOK_OUTFITS")
	var kinds := {"plain": 0, "work": 0, "uniform": 0}
	var sets := {"flight": 0, "work": 0, "home": 0}
	var sum_squares := 0
	for number: int in weights:
		var row: Dictionary = outfits.get(number, {})
		var kind := String(row.get("kind", ""))
		var scene_set := String(row.get("set", ""))
		var weight := int(weights[number])
		kinds[kind] = int(kinds.get(kind, 0)) + weight
		sets[scene_set] = int(sets.get(scene_set, 0)) + weight
		if kind == "plain":
			assert_between(weight, 80, 130)
		assert_lte(weight, 400)
		sum_squares += weight * weight
	assert_eq(kinds, {"plain": 870, "work": 100, "uniform": 30})
	assert_eq(sets, {"flight": 530, "work": 290, "home": 180})
	assert_eq(sum_squares, 78068, "integer sum avoids integer-division truncation")
	assert_lte(sum_squares, 100000)


func test_all_thousand_tickets_match_weights_and_each_interval_edge() -> void:
	var counts := {}
	for ticket: int in 1000:
		var outfit: int = api.call("outfit_for_roll", ticket)
		assert_true(COMMON_20261107.has(outfit), "ticket %d selects an actual key" % ticket)
		counts[outfit] = int(counts.get(outfit, 0)) + 1
	assert_eq(counts, COMMON_20261107, "all 1000 tickets give the exact per-outfit counts")
	var start := 0
	var numbers: Array = COMMON_20261107.keys()
	numbers.sort()
	for number: int in numbers:
		var end := start + COMMON_20261107[number] - 1
		assert_eq(int(api.call("outfit_for_roll", start)), number, "first ticket %d" % start)
		assert_eq(int(api.call("outfit_for_roll", end)), number, "last ticket %d" % end)
		start = end + 1
	assert_eq(start, 1000)


func test_named_ticket_boundaries_cross_sparse_outfit_numbers() -> void:
	var boundaries := {0: 1, 88: 1, 89: 2, 869: 10, 870: 21, 969: 26,
		970: 41, 984: 42, 985: 43, 994: 43, 995: 44, 999: 44}
	for ticket: int in boundaries:
		assert_eq(int(api.call("outfit_for_roll", ticket)), int(boundaries[ticket]), "ticket %d" % ticket)


func test_out_of_range_tickets_assert_or_report_error_and_return_zero() -> void:
	for ticket: int in [-1, 1000]:
		if OS.is_debug_build():
			api.call("outfit_for_roll", ticket)
			assert_engine_error("look ticket must be within 0..999")
		else:
			assert_eq(int(api.call("outfit_for_roll", ticket)), 0)
			assert_push_error("look ticket must be within 0..999")


func test_all_transport_codes_activate_only_current_outfit_rows() -> void:
	for code: int in 512:
		var expected := code if ISSUED_20261107.has(code >> 3) else 0
		assert_eq(int(api.call("active_look_code", code)), expected, "transport code %d" % code)
	for code: int in [-1, 512]:
		assert_eq(int(api.call("active_look_code", code)), 0)


func test_twenty_thousand_generated_codes_reach_all_common_outfits_within_four_sigma() -> void:
	const SAMPLE_SIZE: int = 20000
	var counts := {}
	for id: int in range(1, SAMPLE_SIZE + 1):
		var code: int = api.call("look_code_for", 1, id)
		assert_true(COMMON_20261107.has(code >> 3), "private stream selects a positive-weight outfit")
		counts[code >> 3] = int(counts.get(code >> 3, 0)) + 1
	assert_eq(counts.size(), 19)
	assert_eq(int(counts.get(24, 0)), 0)
	assert_eq(int(counts.get(27, 0)), 0)
	for number: int in COMMON_20261107:
		var count := int(counts.get(number, 0))
		assert_gt(count, 0, "reachable common outfit %d" % number)
		var p := float(COMMON_20261107[number]) / 1000.0
		var expected := float(SAMPLE_SIZE) * p
		var four_sigma := 4.0 * sqrt(float(SAMPLE_SIZE) * p * (1.0 - p))
		assert_lte(absf(float(count) - expected), four_sigma,
			"outfit %d: count %d, expected %.3f, four sigma %.3f" % [number, count, expected, four_sigma])


func test_private_stream_is_independent_of_call_order_and_interleaved_ids() -> void:
	var expected := {}
	for id: int in range(1, 129):
		expected[id] = int(api.call("look_code_for", 11, id))
	for id: int in range(128, 0, -1):
		api.call("look_code_for", -19, id + 10000)
		api.call("look_code_migrated", 1, id, "이름 있는 사람")
		assert_eq(int(api.call("look_code_for", 11, id)), int(expected[id]))
		assert_eq(int(api.call("look_code_migrated", 11, id, "")), int(expected[id]))


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
	for seed_bits: int in 8:
		for dirt: int in 8:
			for blood: int in 8:
				var tear := Color(float(blood) / 7.0, float(dirt) / 7.0, 0.9, 1.0)
				assert_eq(int(api.call("shell_look_code", 8 + seed_bits, tear)), dirt + 8 * blood + 64 * seed_bits)
	assert_eq(int(api.call("shell_look_code", 0, Color.WHITE)), 0, "code 0 has no new shell effect")
	assert_eq(int(api.call("shell_look_code", 15, Color(2, -1, 0, 1))), 504, "clamp strengths only")
	assert_eq(int(api.call("shell_look_code", 8, Color(0.5, 0.5, 0, 1))), 36, "nearest of eight levels")


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
