extends "res://addons/gut/test.gd"
## Sight changes the dead's drawing, never where the rules put them. The draw
## ledger is used here: a headless MultiMesh does not return its instance data.

const Zombies = preload("res://game/actors/zombies.gd")
const DeadCast = preload("res://game/actors/dead_cast.gd")
const FieldGame = preload("res://game/field_game.gd")
const Wear = preload("res://game/sim/wear.gd")

var game
var dead: Zombies
var camera: Camera3D
var origin: Vector3


class WaitingGarment extends Zombies:
	var waiting: bool = true
	var requests: int = 0

	func _garment_of(b: int, kind: String) -> MultiMeshInstance3D:
		requests += 1
		return null if waiting else super._garment_of(b, kind)


func _camera_at(at: Vector3) -> Camera3D:
	# A sized viewport gives Camera3D its projection even with no display.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 240)
	add_child_autofree(viewport)
	var cam := Camera3D.new()
	viewport.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 16.0
	cam.far = 100.0
	cam.look_at_from_position(at + Vector3(0, 40, 0.01), at)
	return cam


func _field(wait_for_garment: bool = false) -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	origin = game.lift(Vector2i(60, 7), 0)
	game.player.position = origin
	# A fresh renderer makes its first render explicit, without relying on the
	# field's arrival drawing. Loading tests add their own pending appearance.
	dead = WaitingGarment.new() if wait_for_garment else Zombies.new()
	game.add_child(dead)
	dead.setup(game, game.zombies.vat)
	dead.bodies_to_read.clear()
	dead.bodies_planned = 1
	camera = _camera_at(origin)


func _spawn(at: Vector3) -> Dictionary:
	var z: Dictionary = dead.spawn("dead", at)
	z["worn"] = {}
	return z


func _seen(at: Vector3) -> Dictionary:
	return {game.seen_key(at): true}


func test_shown_uses_each_direction_time_and_clamps() -> void:
	assert_almost_eq(Zombies.next_shown(0.0, true, 0.09), 0.5, 0.0001)
	assert_almost_eq(Zombies.next_shown(0.0, true, 0.18), 1.0, 0.0001)
	assert_almost_eq(Zombies.next_shown(1.0, false, 0.2), 0.0, 0.0001)
	assert_eq(Zombies.next_shown(0.9, true, 1.0), 1.0)
	assert_eq(Zombies.next_shown(0.1, false, 1.0), 0.0)
	assert_eq(Zombies.next_shown(0.4, true, 0.0), 0.4)


func test_shade_and_shown_round_trip() -> void:
	for shade: float in [1.0, 0.8]:
		for shown: float in [0.0, 0.5, 1.0]:
			var decoded: Vector2 = Zombies.unpack_shade(Zombies.pack_shade(shade, shown))
			assert_almost_eq(decoded.x, shade, 0.0001)
			assert_almost_eq(decoded.y, shown, 1.0 / 16.0)
		assert_almost_eq(Zombies.unpack_shade(shade).x, shade, 0.0001)
		assert_eq(Zombies.unpack_shade(shade).y, 1.0, "plain shade hides no pixels")


func test_leaving_sight_keeps_the_last_draw_until_reentry() -> void:
	_field()
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	dead.render(camera, _seen(origin), true, 0.0)
	assert_eq(float(dead._shown[id]), 1.0, "arrival is already shown")
	assert_eq(dead.drawn_at.get(id, Vector3.INF), origin)
	assert_eq(dead.drawn_count, 1)
	if not dead._last_seen_draw.has(id):
		fail_test("the sized camera must submit the body before testing its last draw")
		return
	var kept: Dictionary = dead._last_seen_draw[id].duplicate()
	dead.render(camera, {}, true, 0.1)
	assert_almost_eq(float(dead._shown[id]), 0.5, 0.0001)
	z["pos"] = origin + Vector3(2, 0, 0)
	z["angle"] = float(z["angle"]) + 1.0
	z["state"] = "downed"
	z["kind"] = "clothed"
	z["stun"] = 1.0
	z["worn"] = {"coat": Wear.make("coat_long")}
	dead.render(camera, {}, true, 0.05)
	assert_almost_eq(float(dead._shown[id]), 0.25, 0.0001)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), origin, "no unseen movement is exposed")
	assert_eq(dead._last_seen_draw[id], kept, "place, turn, motion, body and garment stay as seen")
	dead.render(camera, {}, true, 0.1)
	assert_eq(float(dead._shown[id]), 0.0)
	assert_false(dead.drawn_at.has(id))
	assert_eq(dead.drawn_count, 0)
	z["state"] = "wander"
	z["worn"] = {}
	dead.render(camera, _seen(z["pos"]), true, 0.09)
	assert_almost_eq(float(dead._shown[id]), 0.5, 0.0001)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), z["pos"], "reentry uses its present place")
	assert_eq(dead.drawn_count, 1)
	assert_false(z.has("shown"), "drawing state is not saved on the body")
	assert_false(z.has("last_seen_draw"))


func test_spawn_after_the_first_render_starts_at_zero() -> void:
	_field()
	dead.render(camera, {}, true, 0.0)
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	dead.render(camera, _seen(origin), true, 0.0)
	assert_eq(float(dead._shown[id]), 0.0)
	assert_false(dead.drawn_at.has(id))
	dead.render(camera, _seen(origin), true, 0.09)
	assert_almost_eq(float(dead._shown[id]), 0.5, 0.0001)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), origin)
	dead.render(camera, _seen(origin), true, 0.09)
	assert_eq(float(dead._shown[id]), 1.0)


func test_reentry_reverses_the_current_fade_and_mask_off_counts_as_seen() -> void:
	_field()
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	dead.render(camera, _seen(origin), true, 0.0)
	dead.render(camera, {}, true, 0.1)
	z["pos"] = origin + Vector3(2, 0, 0)
	dead.render(camera, {}, false, 0.045)
	assert_almost_eq(float(dead._shown[id]), 0.75, 0.0001)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), z["pos"])
	dead.render(camera, {}, true, 10.0)
	assert_almost_eq(float(dead._shown[id]), 0.25, 0.0001, "render caps a long frame at 0.1 seconds")


func test_a_hundred_sight_crossings_never_show_the_unseen_place() -> void:
	_field()
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	dead.render(camera, _seen(origin), true, 0.0)
	for crossing: int in 100:
		var before: Vector3 = z["pos"]
		z["pos"] = origin + Vector3(2.0 if crossing % 2 == 0 else 0.0, 0, 0)
		dead.render(camera, {}, true, 0.1)
		assert_almost_eq(float(dead._shown[id]), 0.5, 0.0001, "out %d" % crossing)
		assert_eq(dead.drawn_at.get(id, Vector3.INF), before, "kept %d" % crossing)
		dead.render(camera, {}, true, 0.1)
		assert_eq(float(dead._shown[id]), 0.0)
		assert_false(dead.drawn_at.has(id))
		dead.render(camera, _seen(z["pos"]), true, 0.09)
		assert_almost_eq(float(dead._shown[id]), 0.5, 0.0001, "in %d" % crossing)
		assert_eq(dead.drawn_at.get(id, Vector3.INF), z["pos"])
		dead.render(camera, _seen(z["pos"]), true, 0.09)
		assert_eq(float(dead._shown[id]), 1.0)
	assert_eq(dead.appearance_swaps, 0)
	assert_eq(dead.held_frames_max, 0)


func test_frustum_plane_sign_and_a_sphere_at_every_edge() -> void:
	var at := Vector3(60.5, 0, 7.5)
	var cam: Camera3D = _camera_at(at)
	var centre: Vector3 = at + Vector3(0, 0.9, 0)
	var planes: Array[Plane] = cam.get_frustum()
	assert_eq(planes.size(), 6)
	assert_true(Zombies.in_sight_frustum(planes, at))
	for plane: Plane in planes:
		assert_lt(plane.distance_to(centre), 0.0, "the camera's inside is the negative half-space")
		var on_plane: Vector3 = centre - plane.normal * plane.distance_to(centre)
		var one: Array[Plane] = [plane]
		var close: Vector3 = on_plane + plane.normal * (Zombies.FRUSTUM_PAD - 0.01) - Vector3(0, 0.9, 0)
		var away: Vector3 = on_plane + plane.normal * (Zombies.FRUSTUM_PAD + 0.01) - Vector3(0, 0.9, 0)
		assert_true(Zombies.in_sight_frustum(one, close), "its centre is out but its body still reaches in")
		assert_false(Zombies.in_sight_frustum(one, away), "the whole sphere is outside")


func test_visibility_advances_offscreen_and_hidden_floors_stop_it() -> void:
	_field()
	var z: Dictionary = _spawn(origin + Vector3(30, 0, 0))
	var id: int = int(z["id"])
	dead.render(camera, _seen(z["pos"]), true, 0.0)
	assert_eq(float(dead._shown[id]), 1.0)
	assert_false(dead.drawn_at.has(id), "beyond the sized camera")
	dead.render(camera, {}, true, 0.1)
	assert_almost_eq(float(dead._shown[id]), 0.5, 0.0001)
	z["pos"] = game.lift(Vector2i(60, 7), 1)
	dead.render(camera, _seen(z["pos"]), true, 0.09)
	assert_eq(float(dead._shown[id]), 0.0, "a floor above the player is hidden at once")
	assert_false(dead.drawn_at.has(id))


func test_hidden_culling_uses_the_last_seen_place() -> void:
	_field()
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	dead.render(camera, _seen(origin), true, 0.0)
	z["pos"] = origin + Vector3(30, 0, 0)
	dead.render(camera, {}, true, 0.1)
	assert_almost_eq(float(dead._shown[id]), 0.5, 0.0001)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), origin, "culling does not follow unseen movement either")


func test_offscreen_seen_movement_refreshes_the_fading_draw() -> void:
	_field()
	var z: Dictionary = _spawn(origin)
	z["worn"] = {"coat": Wear.make("coat_long")}
	var id: int = int(z["id"])
	dead.render(camera, _seen(origin), true, 0.0)
	var record: Dictionary = dead._last_seen_draw[id]
	var last_seen_at: Vector3 = origin + Vector3(30, 0, 0)
	z["pos"] = last_seen_at
	z["kind"] = "clothed"
	dead.render(camera, _seen(last_seen_at), true, 0.09)
	assert_false(dead.drawn_at.has(id), "the seen body is outside the camera")
	assert_true(is_same(dead._last_seen_draw[id], record), "a seen update reuses its record")
	assert_eq(record["at"], last_seen_at, "offscreen sight refreshes the cached position")
	assert_eq(dead.appearance_swaps, 1, "compare the old coat colour before overwriting, even offscreen")
	# Copy values, not the reused Dictionary reference, to detect an unseen overwrite.
	var kept_transform: Transform3D = record["transform"]
	var kept_body: int = int(record["b"])
	var kept_shell: String = String(record["shell"])
	var kept_color: Color = record["garment_color"]
	z["pos"] = last_seen_at + Vector3(3, 0, 0)
	z["kind"] = "fresh"
	z["worn"] = {}
	camera.look_at_from_position(last_seen_at + Vector3(0, 40, 0.01), last_seen_at)
	dead.render(camera, {}, true, 0.1)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), last_seen_at, "fade uses the latest seen place, not the old onscreen place")
	assert_eq(record["transform"], kept_transform)
	assert_eq(int(record["b"]), kept_body)
	assert_eq(String(record["shell"]), kept_shell)
	assert_eq(record["garment_color"], kept_color)
	assert_eq(dead.appearance_swaps, 1, "unseen changes do not refresh appearance")


func test_seen_record_reuses_values_and_erases_finished_attachments() -> void:
	_field()
	if dead.embedded_draw == null:
		dead.embedded_draw = MultiMeshInstance3D.new()
		dead.embedded_draw.multimesh = MultiMesh.new()
		dead.embedded_draw.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		dead.embedded_draw.multimesh.mesh = BoxMesh.new()
		dead.embedded_draw.multimesh.instance_count = Zombies.EMBED_MAX
		dead.add_child(dead.embedded_draw)
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	z["state"] = "rising"
	z["embedded"] = {"id": "axe"}
	dead.render(camera, _seen(origin), true, 0.0)
	var record: Dictionary = dead._last_seen_draw[id]
	assert_true(record.has("marker"))
	assert_true(record.has("axe"))
	z["state"] = "wander"
	z.erase("embedded")
	z["pos"] = origin + Vector3(1, 0, 0)
	dead.render(camera, _seen(z["pos"]), true, 0.09)
	assert_true(is_same(dead._last_seen_draw[id], record), "refresh does not allocate another record")
	assert_eq(record["at"], z["pos"])
	assert_false(record.has("marker"), "rising finished on the reused record")
	assert_false(record.has("axe"), "the removed axe cannot linger on the reused record")
	assert_eq(dead.markers.multimesh.visible_instance_count, 0)
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 0)


func test_draw_cap_keeps_previous_ids_and_waits_at_zero_until_a_slot_opens() -> void:
	_field()
	for _index: int in Zombies.MAX_DRAW:
		_spawn(origin + Vector3(2, 0, 0))
	var newcomer: Dictionary = _spawn(origin + Vector3(4, 0, 0))
	var newcomer_id: int = int(newcomer["id"])
	dead.render(camera, {}, false, 0.0)
	var kept_ids: Array = dead.drawn_at.keys()
	kept_ids.sort()
	assert_eq(kept_ids.size(), Zombies.MAX_DRAW)
	assert_eq(dead.drawn_count, Zombies.MAX_DRAW)
	assert_false(dead.drawn_at.has(newcomer_id))
	assert_eq(float(dead._shown[newcomer_id]), 0.0, "the 161st waits instead of finishing its fade unseen")
	var waiting_record: Dictionary = dead._last_seen_draw[newcomer_id]
	newcomer["pos"] = origin
	# Put the newcomer first as well as closest, so list order cannot preserve incumbents by accident.
	dead.list.reverse()
	dead.render(camera, {}, false, 0.09)
	var next_ids: Array = dead.drawn_at.keys()
	next_ids.sort()
	assert_eq(next_ids, kept_ids, "all 160 previously shown ids retain their slots")
	assert_eq(float(dead._shown[newcomer_id]), 0.0)
	assert_true(is_same(dead._last_seen_draw[newcomer_id], waiting_record))
	assert_eq(waiting_record["at"], origin, "cap waiting still refreshes the last seen position")
	assert_eq(dead.cap_drops, 0, "newcomer rejection does not count as a previously shown drop")
	var removed_id: int = int(kept_ids[0])
	for z: Dictionary in dead.list:
		if int(z["id"]) == removed_id:
			dead.list.erase(z)
			break
	dead.render(camera, {}, false, 0.09)
	assert_eq(dead.drawn_at.size(), Zombies.MAX_DRAW)
	assert_true(dead.drawn_at.has(newcomer_id))
	assert_false(dead.drawn_at.has(removed_id))
	assert_almost_eq(float(dead._shown[newcomer_id]), 0.5, 0.0001, "the freed slot starts the usual fade from zero")


func test_draw_cap_uses_distance_and_counts_excess_previous_visibility() -> void:
	_field()
	var crowd_at: Vector3 = origin + Vector3(30, 0, 0)
	for _index: int in Zombies.MAX_DRAW:
		_spawn(crowd_at)
	var nearest: Dictionary = _spawn(crowd_at - Vector3(1, 0, 0))
	var nearest_id: int = int(nearest["id"])
	dead.render(camera, {}, false, 0.0)
	assert_eq(dead.drawn_at.size(), 0, "all 161 are offscreen but have positive sight visibility")
	camera.look_at_from_position(crowd_at + Vector3(0, 40, 0.01), crowd_at)
	dead.render(camera, {}, false, 0.09)
	assert_eq(dead.drawn_at.size(), Zombies.MAX_DRAW)
	assert_true(dead.drawn_at.has(nearest_id), "distance to the player wins inside the previously shown group")
	assert_eq(dead.cap_drops, 1, "only the excess previously positive id is counted")
	dead.render(camera, {}, false, 0.09)
	assert_eq(dead.cap_drops, 1, "a zero-visibility waiting id is not counted again")


func test_markers_and_embedded_axes_stop_below_half_shown() -> void:
	_field()
	# Supply an axe draw even when the optional model is not carried in a build.
	if dead.embedded_draw == null:
		dead.embedded_draw = MultiMeshInstance3D.new()
		dead.embedded_draw.multimesh = MultiMesh.new()
		dead.embedded_draw.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		dead.embedded_draw.multimesh.mesh = BoxMesh.new()
		dead.embedded_draw.multimesh.instance_count = Zombies.EMBED_MAX
		dead.add_child(dead.embedded_draw)
	var z: Dictionary = _spawn(origin)
	z["state"] = "rising"
	z["embedded"] = {"id": "axe"}
	dead.render(camera, _seen(origin), true, 0.0)
	assert_eq(dead.markers.multimesh.visible_instance_count, 1)
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 1)
	dead.render(camera, {}, true, 0.1)
	assert_eq(dead.markers.multimesh.visible_instance_count, 1, "half shown still has its marker")
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 1)
	dead.render(camera, {}, true, 0.05)
	assert_eq(dead.markers.multimesh.visible_instance_count, 0)
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 0)
	assert_eq(dead.drawn_count, 1, "the body still fades after its solid attachments stop")


func test_an_unread_body_waits_at_zero_then_fades_in() -> void:
	_field()
	dead.bodies_planned = 2
	var picked_id: int = -1
	for candidate: int in range(1, 65):
		if DeadCast.body_of(candidate, 2) == 1:
			picked_id = candidate
			break
	assert_gt(picked_id, 0, "one of the fixture ids wears the pending body")
	if picked_id < 0:
		return
	dead.next_id = picked_id
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	for _frame: int in 3:
		dead.render(camera, _seen(origin), true, 0.09)
		assert_eq(float(dead._shown[id]), 0.0)
		assert_false(dead.drawn_at.has(id), "no body-zero placeholder")
	assert_eq(dead.held_frames_max, 3)
	# Supply a ready draw slot without reading another body from disk.
	dead.draws.append(dead.draws[0])
	dead.wear_draws.append({})
	dead.body_rounds.append(dead.body_rounds[0])
	dead.render(camera, _seen(origin), true, 0.09)
	assert_almost_eq(float(dead._shown[id]), 0.5, 0.0001)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), origin)
	assert_eq(int(dead._last_seen_draw[id]["b"]), 1)
	assert_eq(dead.appearance_swaps, 0)
	assert_false(dead._held_frames.has(id))


func test_a_garment_is_requested_while_its_body_waits_at_zero() -> void:
	_field(true)
	var waiting: WaitingGarment = dead as WaitingGarment
	var z: Dictionary = _spawn(origin)
	z["worn"] = {"coat": Wear.make("coat_long")}
	var id: int = int(z["id"])
	assert_true(dead.baked, "the field's baked garment path")
	for _frame: int in 3:
		dead.render(camera, _seen(origin), true, 0.09)
		assert_eq(float(dead._shown[id]), 0.0)
		assert_false(dead.drawn_at.has(id), "no coatless placeholder")
	assert_eq(waiting.requests, 3, "zero visibility still requests the garment")
	assert_eq(dead.held_frames_max, 3)
	waiting.waiting = false
	dead.render(camera, _seen(origin), true, 0.09)
	assert_almost_eq(float(dead._shown[id]), 0.5, 0.0001)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), origin)
	assert_true((dead.wear_draws[0] as Dictionary).has("coat_long"), "a read, including a missing shell, is resolved")
	assert_eq(dead.appearance_swaps, 0)


func test_removed_ids_leave_no_visibility_or_last_draw() -> void:
	_field()
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	dead.render(camera, _seen(origin), true, 0.0)
	assert_true(dead.drawn_at.has(id))
	dead.list.clear()
	dead.render(camera, {}, true, 0.1)
	assert_false(dead._shown.has(id))
	assert_false(dead._last_seen_draw.has(id))
	assert_false(dead._held_frames.has(id))
	assert_false(dead.drawn_at.has(id))
	assert_eq(dead.drawn_count, 0)


func test_sight_discard_is_enabled_only_by_the_field_dead_shaders() -> void:
	var living: String = FileAccess.get_file_as_string("res://game/actors/person_vat.gdshader")
	var train: String = FileAccess.get_file_as_string("res://game/actors/dead_vat.gdshader")
	var body: String = FileAccess.get_file_as_string("res://game/actors/dead_weathered.gdshader")
	var garment: String = FileAccess.get_file_as_string("res://game/actors/dead_garment.gdshader")
	assert_false(living.contains("#define SIGHT_FADE"))
	assert_false(train.contains("#define SIGHT_FADE"))
	assert_true(body.contains("#define SIGHT_FADE"))
	assert_true(garment.contains("#define SIGHT_FADE"))
	assert_eq(garment.replace("\r\n", "\n").replace("#define SIGHT_FADE\n", ""), living.replace("\r\n", "\n"))
