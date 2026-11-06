extends "res://addons/gut/test.gd"
## CPU records and submission receipts only; headless MultiMesh readback is zero.

const Zombies = preload("res://game/actors/zombies.gd")
const DeadCast = preload("res://game/actors/dead_cast.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const FieldGame = preload("res://game/field_game.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const Wear = preload("res://game/sim/wear.gd")
var game
var dead: ObservedLooks
var camera: Camera3D
var origin: Vector3


class ObservedLooks extends Zombies:
	var submitted_ids: Array[int] = []

	func _garment_of(b: int, kind: String) -> MultiMeshInstance3D:
		var wear: Dictionary = wear_draws[b]
		if not wear.has(kind):
			wear[kind] = make_draw(MAX_DRAW * 5)
		return wear[kind]


	func make_draw(capacity: int) -> MultiMeshInstance3D:
		var node := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = BoxMesh.new()
		mm.instance_count = capacity
		node.multimesh = mm
		add_child(node)
		return node


	func _submit_sight_draw(id: int, record: Dictionary, shown: float, counts: Array, attachments: Vector2i) -> Vector2i:
		submitted_ids.append(id)
		return super._submit_sight_draw(id, record, shown, counts, attachments)


func _field() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false, "arrive": false}
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	origin = game.player.position
	dead = ObservedLooks.new()
	game.add_child(dead)
	dead.setup(game, game.zombies.vat)
	dead.bodies_to_read.clear()
	dead.bodies_planned = 1
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 240)
	add_child_autofree(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.0
	camera.far = 100.0
	camera.look_at_from_position(origin + Vector3(0, 40, 0.01), origin)


func _spawn(at: Vector3, code: int = 13) -> Dictionary:
	var z: Dictionary = dead.spawn("dead", at)
	z["look_code"] = code
	z["worn"] = {"coat": Wear.make("coat_long")}
	return z


func _ledger() -> Dictionary:
	var ledger: Variant = dead.get("_submitted_looks")
	assert_true(ledger is Dictionary, "submission boundary exposes actual body and garment values")
	return ledger if ledger is Dictionary else {}


func _decode(b: float) -> Vector2:
	var code := floorf(b * 0.5 + 0.25) if b >= 0.0 else 0.0
	return Vector2(b - 2.0 * code, code)


func _shell_code(code: int, tear: Color) -> int:
	if code == 0:
		return 0
	return roundi(clampf(tear.g, 0.0, 1.0) * 7.0) + 8 * roundi(clampf(tear.r, 0.0, 1.0) * 7.0) + 64 * (code % 8)


func _counts() -> Array:
	return [{"dead": 0, "clothed": 0, "fresh": 0, "frozen": 0, "corpse": 0}]


func test_t5_spawn_keeps_three_game_rng_draws_and_uses_a_private_look_seed() -> void:
	_field()
	var expected := RandomNumberGenerator.new()
	expected.seed = game.rng.seed
	expected.state = game.rng.state
	var angle := expected.randf() * TAU
	var phase := expected.randf()
	var stander := expected.randf() < 0.55
	var z: Dictionary = dead.spawn("dead", origin)
	assert_eq(z["angle"], angle)
	assert_eq(z["phase"], phase)
	assert_eq(z["stander"], stander)
	assert_eq(game.rng.state, expected.state)
	assert_true(z.has("look_code"), "spawn persists the code before drawing")
	if DeadCast.has_method("look_code_for"):
		assert_eq(int(z.get("look_code", -1)), int(DeadCast.call("look_code_for", 11, int(z["id"]))))


func test_lazy_migration_preserves_saved_codes_and_reserved_rows_draw_as_zero() -> void:
	_field()
	assert_true(dead.has_method("look_code_of"))
	if not dead.has_method("look_code_of"):
		return
	var state: int = game.rng.state
	for named: String in ["", "옛 동료"]:
		var old := {"id": 73, "name": named}
		var expected: int = 0 if named != "" else int(DeadCast.call("look_code_for", 11, 73))
		assert_eq(int(dead.call("look_code_of", old)), expected)
		assert_eq(int(old["look_code"]), expected)
		assert_eq(int(dead.call("look_code_of", old)), expected)
	for code: int in [0, 1, 7, 511]:
		var saved := {"id": 73, "name": "", "look_code": code}
		assert_eq(int(dead.call("look_code_of", saved)), 0, "outfit 0 and unassigned rows draw as code 0 (assigned rows: P0 redo)")
		assert_eq(int(saved["look_code"]), code, "reserved save data is not rewritten")
	assert_eq(game.rng.state, state)


func test_spawn_and_migration_use_the_run_seed_when_options_omit_it() -> void:
	_field()
	game.opts.erase("seed")
	assert_true(DeadCast.has_method("look_code_for"))
	assert_true(dead.has_method("look_code_of"))
	if not DeadCast.has_method("look_code_for") or not dead.has_method("look_code_of"):
		return
	for _i: int in 16:
		var z: Dictionary = dead.spawn("dead", origin)
		var expected: int = int(DeadCast.call("look_code_for", int(game.rng.seed), int(z["id"])))
		assert_eq(int(z.get("look_code", -1)), expected)
		z.erase("look_code")
		assert_eq(int(dead.call("look_code_of", z)), expected)


func test_t7_fresh_aging_and_thaw_keep_the_same_persistent_code() -> void:
	_field()
	var fresh: Dictionary = dead.spawn("fresh", origin)
	var frozen: Dictionary = dead.spawn("frozen", origin + Vector3(3, 0, 0))
	var fresh_code: int = int(fresh.get("look_code", -1))
	var frozen_code: int = int(frozen.get("look_code", -1))
	assert_gt(fresh_code, 0)
	assert_gt(frozen_code, 0)
	fresh["age"] = Zombies.FRESH_STIFFEN + 1.0
	fresh["stun"] = 10.0
	dead.wake(frozen)
	frozen["t"] = 0.0
	dead.update(0.01)
	assert_eq(fresh["kind"], "dead")
	assert_eq(frozen["kind"], "dead")
	assert_eq(int(fresh.get("look_code", -1)), fresh_code)
	assert_eq(int(frozen.get("look_code", -1)), frozen_code)


func test_t7_rising_people_including_unnamed_keep_zero_and_their_own_clothes() -> void:
	_field()
	for who_name: String in ["동료", "약탈자", ""]:
		var risen: Dictionary = dead.add_rising(origin, who_name)
		assert_eq(int(risen.get("look_code", -1)), 0)
	assert_gt(game.squad.size(), 0)
	if game.squad.is_empty():
		return
	var person = game.squad[-1]
	var worn: Dictionary = person.worn.duplicate(true)
	game.on_person_died(person)
	var z: Dictionary = game.zombies.find(int(person.brain["rising_id"]))
	assert_eq(int(z.get("look_code", -1)), 0, "the actual field death path")
	assert_eq(z["worn"], worn)
	assert_false(is_same(z["worn"], person.worn), "clothes are copied, not aliased")


func test_t8_body_shell_and_axe_use_the_same_record_without_changing_shade() -> void:
	_field()
	dead.embedded_draw = dead.make_draw(Zombies.EMBED_MAX)
	var z := _spawn(origin)
	var id: int = int(z["id"])
	var garment: MultiMeshInstance3D = dead._garment_of(0, "coat_long")
	for frozen: bool in [false, true]:
		z["state"] = "frozen" if frozen else "wander"
		var record: Dictionary = dead._sight_draw(z, 0, "dead", {"shell": "coat_long", "colour": Color(0, 1, 0, 1)}, garment, {})
		var raw: Color = record["custom"]
		var code: int = 13 if DeadBody.can_mix() else 0
		# Baked walks already hold a CPU-sampled frame; the box bake walks by TIME.
		var still := 1.0 if frozen or dead.baked else 0.0
		assert_eq(raw.b, still + 2.0 * code)
		record["color"] = Color(0.75, 0.25, 0.9, 1.0)   # different from live z and garment colour
		record["axe"] = Transform3D.IDENTITY
		for shade: float in [1.0, 0.8, 0.6]:
			for shown: float in [0.0, 0.25, 0.5, 1.0]:
				raw.a = shade
				record["custom"] = raw
				dead._submit_sight_draw(id, record, shown, _counts(), Vector2i.ZERO)
				var ledger := _ledger()
				assert_true(ledger.has(id))
				if not ledger.has(id):
					continue
				var body: Color = ledger[id]["body"]
				var shell: Color = ledger[id]["garment"]
				assert_eq(body, Color(raw.r, raw.g, raw.b, Zombies.pack_shade(shade, shown)))
				assert_eq(shell, Color(body.r, body.g, still + 2.0 * _shell_code(code, record["color"]), body.a))
				var shade_back := Zombies.unpack_shade(shell.a)
				assert_almost_eq(shade_back.x, shade, 0.00001)
				assert_eq(shade_back.y, shown)
				assert_eq(record["custom"], raw, "submitting does not overwrite the cached record")
				if shown > 0.0:
					assert_eq(dead._submitted_axes[id], Color(0, 0, 0, shown))


func test_t8_climbing_body_preserves_the_picked_hold_bit() -> void:
	_field()
	var z := _spawn(origin)
	dead.start_climb(z)
	var plain := DeadBody.picked(z, 0.0, 0.0, 1.0, true)
	assert_eq(plain.b, 1.0, "baked lid climb holds its sampled progress")
	if DeadCast.has_method("pack_still") and DeadCast.has_method("unpack_still"):
		var packed: float = DeadCast.call("pack_still", plain.b, 13)
		assert_eq(_decode(packed), Vector2(1, 13))
	var record: Dictionary = dead._sight_draw(z, 0, "dead", {}, null, {})
	var code: int = 13 if DeadBody.can_mix() else 0
	assert_eq(_decode((record["custom"] as Color).b), Vector2(1.0 if dead.baked else 0.0, code))


func test_t8_unbaked_walk_keeps_zero_hold_when_carrying_a_code() -> void:
	_field()
	dead.baked = false
	var z := _spawn(origin)
	var record: Dictionary = dead._sight_draw(z, 0, "dead", {}, null, {})
	var custom: Color = record["custom"]
	var code: int = 13 if DeadBody.can_mix() else 0
	assert_eq(_decode(custom.b), Vector2(0, code))
	assert_almost_eq(custom.r, float(z["phase"]), 0.000001)
	assert_eq(custom.g, 0.0)


func test_submission_receipt_omits_a_missing_or_full_garment() -> void:
	_field()
	var z := _spawn(origin)
	var id: int = int(z["id"])
	var garment: MultiMeshInstance3D = dead.make_draw(1)
	var record: Dictionary = dead._sight_draw(z, 0, "dead", {"shell": "coat_long"}, garment, {})
	dead._submit_sight_draw(id, record, 1.0, _counts(), Vector2i.ZERO)
	var ledger := _ledger()
	assert_true(ledger.get(id, {}).has("garment"))
	dead._submit_sight_draw(id + 1, record, 1.0, _counts(), Vector2i.ZERO)
	ledger = _ledger()
	assert_true(ledger.has(id + 1))
	assert_false(ledger.get(id + 1, {}).has("garment"), "full garment has no submission receipt")
	record["garment"] = null
	dead._submit_sight_draw(id, record, 1.0, _counts(), Vector2i.ZERO)
	ledger = _ledger()
	assert_true(ledger.has(id))
	assert_false(ledger.get(id, {}).has("garment"), "the old receipt is replaced, not merged")


func test_t7_code_zero_keeps_body_and_garment_b_unchanged() -> void:
	_field()
	var z := _spawn(origin, 0)
	z["state"] = "frozen"
	dead.render(camera, {}, false, 0.0)
	var ledger := _ledger()
	assert_true(ledger.has(int(z["id"])))
	if ledger.has(int(z["id"])):
		assert_eq((ledger[z["id"]]["body"] as Color).b, 1.0)
		assert_eq(ledger[z["id"]]["body"], ledger[z["id"]]["garment"])


func test_t8_hidden_state_changes_keep_last_seen_shell_strength_and_seed() -> void:
	_field()
	var z := _spawn(origin)
	var id: int = int(z["id"])
	dead.render(camera, {game.seen_key(origin): true}, true, 0.0)
	var ledger := _ledger()
	assert_true(ledger.has(id))
	if not ledger.has(id):
		return
	var before: Dictionary = ledger[id].duplicate()
	var record: Dictionary = dead._last_seen_draw[id].duplicate()
	z["kind"] = "fresh"
	z["state"] = "eat"
	z["stun"] = 1.0
	z["pos"] += Vector3(2, 0, 0)
	dead.render(camera, {}, true, 0.1)
	var hidden := _ledger()
	assert_eq((hidden[id]["body"] as Color).b, (before["body"] as Color).b)
	assert_eq((hidden[id]["garment"] as Color).b, (before["garment"] as Color).b)
	assert_eq(dead._last_seen_draw[id], record)
	dead.render(camera, {game.seen_key(z["pos"]): true}, true, 0.09)
	var seen := _ledger()
	var code: int = 13 if DeadBody.can_mix() else 0
	var tear: Color = dead._last_seen_draw[id]["color"]
	assert_eq(int(_decode((seen[id]["garment"] as Color).b).y), _shell_code(code, tear))
	assert_eq(int(_decode((seen[id]["garment"] as Color).b).y) >> 6, code % 8)
	if DeadBody.can_mix():
		assert_ne((seen[id]["garment"] as Color).b, (before["garment"] as Color).b, "seen eating refreshes strength")
	dead.render(camera, {}, true, 0.1)
	dead.render(camera, {}, true, 0.1)
	assert_false(_ledger().has(id), "a new frame drops expired receipts")


func test_t8_cap_reselection_clears_provisional_looks_and_records_only_survivors() -> void:
	_field()
	for _i: int in Zombies.MAX_DRAW:
		_spawn(origin + Vector3(2, 0, 0))
	var newcomer := _spawn(origin + Vector3(30, 0, 0), 15)
	var newcomer_id: int = int(newcomer["id"])
	dead.render(camera, {}, false, 0.0)
	var kept: Array = dead.drawn_at.keys()
	kept.sort()
	assert_eq(kept.size(), Zombies.MAX_DRAW)
	newcomer["pos"] = origin
	dead.list.reverse()
	dead.submitted_ids.clear()
	dead.render(camera, {}, false, 0.09)
	assert_eq(dead.submitted_ids[0], newcomer_id, "161st candidate was provisionally submitted first")
	assert_gt(dead.submitted_ids.size(), Zombies.MAX_DRAW, "the cap really caused a second submission pass")
	var ledger := _ledger()
	var actual: Array = ledger.keys()
	actual.sort()
	assert_eq(actual, kept)
	assert_false(ledger.has(newcomer_id))
	assert_eq(ledger.size(), dead.drawn_at.size())
	for id: int in ledger:
		assert_true(ledger[id].has("garment"))
	dead.list.clear()
	dead.render(camera, {}, false, 0.0)
	assert_eq(_ledger().size(), 0, "removed identities leave no receipts")
