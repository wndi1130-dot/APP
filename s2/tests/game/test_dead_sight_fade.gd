extends "res://addons/gut/test.gd"
## Sight changes the dead's drawing, never where the rules put them. The draw
## ledger is used here: a headless MultiMesh does not return its instance data.

const Zombies = preload("res://game/actors/zombies.gd")
const DeadCast = preload("res://game/actors/dead_cast.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const FieldGame = preload("res://game/field_game.gd")
const Wear = preload("res://game/sim/wear.gd")
const Props = preload("res://game/world/prop_models.gd")

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


class QueuedAppearance extends Zombies:
	# Model successful reads using the fixture's assets, without optional files.
	var body_reads: int = 0
	var garment_reads: Array[String] = []

	func _read_a_body() -> void:
		if bodies_to_read.is_empty():
			return
		bodies_to_read.pop_front()
		body_reads += 1
		draws.append(_draws_of(vat))
		wear_draws.append({})
		body_rounds.append(body_rounds[0])

	func _garment_of(b: int, kind: String) -> MultiMeshInstance3D:
		var wear: Dictionary = wear_draws[b]
		if not wear.has(kind):
			if _garment_reads <= 0:
				return null
			_garment_reads -= 1
			garment_reads.append(kind)
			wear[kind] = _garment_draw(vat)
		return wear[kind]


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


func _field(wait_for_garment: bool = false, queued_appearance: bool = false) -> void:
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
	if queued_appearance:
		dead = QueuedAppearance.new()
	else:
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


func test_resume_render_resolves_unread_appearances_but_a_new_field_reads_one_a_frame() -> void:
	for resuming: bool in [false, true]:
		_field(false, true)
		var loading: QueuedAppearance = dead as QueuedAppearance
		if resuming:
			dead.render(camera, {}, true, 0.0)
		game.resume_pending = resuming
		dead.bodies_planned = 3
		dead.bodies_to_read.assign(["pending-one", "pending-two"])
		var ids: Array[int] = []
		for candidate: int in range(1, 65):
			if DeadCast.body_of(candidate, 3) != 2:
				continue
			dead.next_id = candidate
			var z: Dictionary = _spawn(origin)
			z["worn"] = {"coat": Wear.make("coat_long" if ids.is_empty() else "vest_armor")}
			ids.append(int(z["id"]))
			if ids.size() == 2:
				break
		assert_eq(ids.size(), 2, "two seen bodies need the second queued body and different garments")
		assert_eq(dead.draws.size(), 1)
		assert_true(loading.garment_reads.is_empty())
		dead.render(camera, _seen(origin), true, 0.0)
		if not resuming:
			assert_lte(loading.body_reads + loading.garment_reads.size(), 1, "a new field keeps one read a frame")
			for id: int in ids:
				assert_false(dead._submitted_last.has(id), "an unread appearance waits at zero on a new field")
			continue
		assert_eq(loading.body_reads, 2, "the still resolves more than one pending body")
		assert_eq(loading.garment_reads, ["coat_long", "vest"], "both garments resolve in the same render")
		for id: int in ids:
			assert_eq(float(dead._shown.get(id, 0.0)), 1.0)
			assert_eq(dead.drawn_at.get(id, Vector3.INF), origin)
			assert_true(dead._submitted_last.has(id))
			if not dead._last_seen_draw.has(id):
				fail_test("the single restored render must submit the complete appearance")
				continue
			var record: Dictionary = dead._last_seen_draw[id]
			assert_eq(int(record["b"]), 2)
			assert_not_null(record["garment"])
			assert_true((dead.garments_drawn.get(record["garment"], []) as Array).has(id))


func test_onscreen_garment_reads_before_an_earlier_offscreen_seen_body() -> void:
	_field(false, true)
	var loading: QueuedAppearance = dead as QueuedAppearance
	dead.render(camera, {}, true, 0.0)   # exercise the ordinary one-read budget
	var offscreen: Dictionary = _spawn(origin + Vector3(30, 0, 0))
	offscreen["worn"] = {"coat": Wear.make("coat_long")}
	var onscreen: Dictionary = _spawn(origin)
	onscreen["worn"] = {"coat": Wear.make("vest_armor")}
	var onscreen_id: int = int(onscreen["id"])
	dead.render(camera, {}, false, 0.09)
	assert_eq(loading.garment_reads, ["vest"], "the earlier offscreen coat cannot spend the one read")
	assert_false((dead.wear_draws[0] as Dictionary).has("coat_long"))
	assert_eq(dead.drawn_at.get(onscreen_id, Vector3.INF), origin)
	assert_true(dead._submitted_last.has(onscreen_id))
	assert_almost_eq(float(dead._shown[onscreen_id]), 0.5, 0.0001)
	assert_false(dead.drawn_at.has(int(offscreen["id"])))
	offscreen["pos"] = origin
	dead.render(camera, {}, false, 0.09)
	assert_eq(loading.garment_reads, ["vest", "coat_long"], "the deferred coat loads when its picture enters")
	assert_true(dead._submitted_last.has(int(offscreen["id"])))


func test_unseen_floor_change_hides_the_last_seen_upper_floor_draw() -> void:
	_field()
	var upper: Vector3 = game.lift(Vector2i(60, 7), 1)
	game.player.position = upper
	var z: Dictionary = _spawn(upper)
	var id: int = int(z["id"])
	dead.render(camera, _seen(upper), true, 0.0)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), upper)
	z["pos"] = origin
	dead.render(camera, {}, true, 0.05)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), upper, "unseen descent leaves the picture upstairs")
	assert_almost_eq(float(dead._shown[id]), 0.75, 0.0001)
	game.player.position = origin
	dead.render(camera, {}, true, 0.05)
	assert_eq(float(dead._shown[id]), 0.0, "hide the upstairs picture even though the body is now downstairs")
	assert_false(dead.drawn_at.has(id))
	assert_false(dead._submitted_last.has(id))


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


func test_sight_fade_follows_slow_holds_for_hitstop_and_finishes_paused() -> void:
	_field()
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	dead.render(camera, _seen(origin), true, 0.0)
	game.slow = 0.5
	dead.render(camera, {}, true, 0.1)
	assert_almost_eq(float(dead._shown[id]), 0.75, 0.0001, "half-speed game time advances half a fade step")
	game.hitstop = true
	dead.render(camera, {}, true, 0.1)
	assert_almost_eq(float(dead._shown[id]), 0.75, 0.0001, "hitstop holds the pending transition")
	assert_true(dead._submitted_last.has(id))
	game.hitstop = false
	game.slow = 1.0
	game.paused = true
	dead.render(camera, {}, true, 0.1)
	assert_almost_eq(float(dead._shown[id]), 0.25, 0.0001, "pause alone lets the pending transition finish")
	dead.render(camera, {}, true, 0.05)
	assert_eq(float(dead._shown[id]), 0.0)
	assert_false(dead.drawn_at.has(id))
	assert_false(dead._submitted_last.has(id))


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


func test_frustum_keeps_the_shoved_picture_until_its_drawn_origin_leaves() -> void:
	_field()
	var edge_at: Vector3 = origin
	for plane: Plane in camera.get_frustum():
		if plane.normal.x > 0.9:
			edge_at -= plane.normal * plane.distance_to(origin + Vector3(0, 0.9, 0))
			break
	var z: Dictionary = _spawn(edge_at)
	var id: int = int(z["id"])
	z["shoved_from"] = edge_at
	z["pos"] = edge_at + Vector3(1.3, 0, 0)
	z["shoved_t"] = Zombies.SHOVED_TIME
	dead.render(camera, _seen(z["pos"]), true, 0.0)
	var record: Dictionary = dead._last_seen_draw[id]
	var transform: Transform3D = record["transform"]
	assert_eq(record["at"], z["pos"], "the draw record still knows the logical place")
	assert_eq(transform.origin, edge_at)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), edge_at, "the body still on the screen survives a 1.3 m logical shove")
	assert_true(dead._submitted_last.has(id))
	assert_eq(float(dead._shown[id]), 1.0)
	z["shoved_t"] = 0.0
	dead.render(camera, _seen(z["pos"]), true, 0.0)
	assert_false(dead.drawn_at.has(id), "cull only once the picture has reached the offscreen place")
	assert_false(dead._submitted_last.has(id))
	assert_eq(float(dead._shown[id]), 1.0, "frustum culling does not change sight visibility")


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
		dead.embedded_draw.multimesh.use_custom_data = true
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


func test_draw_cap_uses_distance_without_counting_unsubmitted_visibility() -> void:
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
	assert_true(dead.drawn_at.has(nearest_id), "distance to the player wins among never-submitted candidates")
	assert_eq(dead.cap_drops, 0, "positive visibility offscreen was never an actual submission")
	dead.render(camera, {}, false, 0.09)
	assert_eq(dead.cap_drops, 0, "a waiting id is not a displaced submission either")


func test_draw_cap_keeps_submitted_ids_over_a_charged_offscreen_candidate() -> void:
	_field()
	for _index: int in Zombies.MAX_DRAW:
		_spawn(origin + Vector3(2, 0, 0))
	var newcomer: Dictionary = _spawn(origin + Vector3(30, 0, 0))
	var newcomer_id: int = int(newcomer["id"])
	dead.render(camera, {}, false, 0.0)
	var kept_ids: Array = dead._submitted_last.keys()
	kept_ids.sort()
	assert_eq(kept_ids.size(), Zombies.MAX_DRAW)
	assert_eq(float(dead._shown[newcomer_id]), 1.0, "offscreen sight has already filled its visibility")
	assert_false(dead._submitted_last.has(newcomer_id))
	newcomer["pos"] = origin
	dead.list.reverse()   # nearest and first, but never submitted in the preceding frame
	dead.render(camera, {}, false, 0.09)
	var drawn_ids: Array = dead.drawn_at.keys()
	drawn_ids.sort()
	var submitted_ids: Array = dead._submitted_last.keys()
	submitted_ids.sort()
	assert_eq(drawn_ids, kept_ids, "all previous submissions retain their slots")
	assert_eq(submitted_ids, kept_ids, "the snapshot contains only the final cap selection")
	assert_false(dead.drawn_at.has(newcomer_id))
	assert_eq(float(dead._shown[newcomer_id]), 0.0, "the rejected candidate waits for a fresh fade-in")
	assert_eq(dead._last_seen_draw[newcomer_id]["at"], origin, "waiting still tracks the seen place")


func test_markers_and_embedded_axes_fade_together_with_custom_visibility() -> void:
	_field()
	# Supply an axe draw even when the optional model is not carried in a build.
	if dead.embedded_draw == null:
		dead.embedded_draw = MultiMeshInstance3D.new()
		dead.embedded_draw.multimesh = MultiMesh.new()
		dead.embedded_draw.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		dead.embedded_draw.multimesh.use_custom_data = true
		dead.embedded_draw.multimesh.mesh = BoxMesh.new()
		dead.embedded_draw.multimesh.instance_count = Zombies.EMBED_MAX
		dead.add_child(dead.embedded_draw)
	assert_true(dead.embedded_draw.multimesh.use_custom_data)
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	z["state"] = "rising"
	z["embedded"] = {"id": "axe"}
	dead.render(camera, _seen(origin), true, 0.0)
	assert_eq(dead.markers.multimesh.visible_instance_count, 1)
	assert_eq(float(dead._submitted_markers[id]), 1.0)
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 1)
	assert_eq(dead._submitted_axes[id], Color(0.0, 0.0, 0.0, 1.0))
	dead.render(camera, {}, true, 0.1)
	assert_eq(dead.markers.multimesh.visible_instance_count, 1, "half shown still has its marker")
	assert_almost_eq(float(dead._submitted_markers[id]), 0.5, 0.0001)
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 1)
	assert_eq(dead._submitted_axes[id], Color(0.0, 0.0, 0.0, 0.5))
	dead.render(camera, {}, true, 0.05)
	assert_eq(dead.markers.multimesh.visible_instance_count, 1, "the marker keeps fading below half shown")
	assert_almost_eq(float(dead._submitted_markers[id]), 0.25, 0.0001)
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 1, "the axe keeps fading below half shown")
	assert_eq(dead._submitted_axes[id], Color(0.0, 0.0, 0.0, 0.25))
	assert_eq(dead.drawn_count, 1, "body, marker and axe still fade together")
	dead.render(camera, {}, true, 0.05)
	assert_eq(dead.markers.multimesh.visible_instance_count, 0)
	assert_false(dead._submitted_markers.has(id))
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 0)
	assert_false(dead._submitted_axes.has(id))
	dead.render(camera, _seen(origin), true, 0.045)
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 1)
	assert_eq(dead._submitted_axes[id], Color(0.0, 0.0, 0.0, 0.25))
	dead.render(camera, _seen(origin), true, 0.045)
	assert_eq(dead.embedded_draw.multimesh.visible_instance_count, 1)
	assert_eq(dead._submitted_axes[id], Color(0.0, 0.0, 0.0, 0.5))
	# A non-step visibility must use the body's quantization, not the raw timer.
	dead.render(camera, _seen(origin), true, 0.01)
	var shown: float = float(dead._shown[id])
	var axe_custom: Color = dead._submitted_axes[id]
	assert_almost_eq(axe_custom.a, Zombies.unpack_shade(Zombies.pack_shade(1.0, shown)).y, 0.0001)
	assert_ne(axe_custom.a, shown)


func test_embedded_axes_opt_in_without_changing_cached_prop_materials() -> void:
	var cached: Dictionary = Props.batch_meshes(Zombies.EMBED_MODEL)
	if not cached.has(0):
		pending("the optional embedded axe model is not carried in this build")
		return
	var shared: Mesh = cached[0]
	_field()
	assert_not_null(dead.embedded_draw)
	if dead.embedded_draw == null:
		return
	var faded: Mesh = dead.embedded_draw.multimesh.mesh
	assert_false(is_same(faded, shared), "the cached mesh keeps its original surfaces")
	assert_eq(faded.get_surface_count(), shared.get_surface_count())
	for surface: int in shared.get_surface_count():
		var original := shared.surface_get_material(surface) as ShaderMaterial
		var opted_in := faded.surface_get_material(surface) as ShaderMaterial
		assert_false(is_same(opted_in, original), "only the axe's private material opts in")
		assert_true(bool(opted_in.get_shader_parameter("sight_fade")))
		assert_ne(original.get_shader_parameter("sight_fade"), true, "shared cache stays solid")
	var furniture: Dictionary = Props.batch_meshes(Props.DIR + "bookcase.glb")
	assert_true(furniture.has(0))
	if furniture.has(0):
		var mesh: Mesh = furniture[0]
		for surface: int in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as ShaderMaterial
			assert_ne(material.get_shader_parameter("sight_fade"), true, "other props keep sight fade off")


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


func test_body_step_matches_before_and_after_appearance_read() -> void:
	_field()
	assert_true(dead.baked, "the baked pose accumulates body_step")
	if not dead.baked:
		return
	dead.bodies_planned = 2
	var picked_id: int = -1
	for candidate: int in range(1, 65):
		if DeadCast.body_of(candidate, 2) == 1:
			picked_id = candidate
			break
	assert_gt(picked_id, 0, "the fixture wears the unread body")
	if picked_id < 0:
		return
	dead.next_id = picked_id
	var z: Dictionary = _spawn(origin)
	z["state"] = "chase"
	var motion: int = DeadBody.gait_of(z)
	var assigned_rounds: Dictionary = dead.body_rounds[0].duplicate()
	assigned_rounds[motion] = float(assigned_rounds.get(motion, DeadBody.STRIDE[motion])) * 2.0
	dead._pose_rounds.assign([dead.body_rounds[0], assigned_rounds])
	var initial: Dictionary = z.duplicate()
	var waiting_steps: Array[float] = []
	for frame: int in 4:
		z["pos"] = origin + Vector3(0.1 * frame, 0, 0)
		z["age"] = float(initial["age"]) + 0.05 * frame
		dead.render(camera, {}, false, 0.05)
		assert_eq(float(dead._shown[picked_id]), 0.0, "the appearance is still unread")
		assert_true(z.has("body_step"), "waiting still advances the saved pose")
		waiting_steps.append(float(z.get("body_step", -1.0)))
	assert_ne(waiting_steps[0], waiting_steps[3], "movement must exercise stride accumulation")
	# Replay the same movement with its appearance ready, using no MultiMesh readback.
	dead.draws.append(dead.draws[0])
	dead.wear_draws.append({})
	dead.body_rounds.append(assigned_rounds)
	z.clear()
	z.merge(initial)
	for frame: int in 4:
		z["pos"] = origin + Vector3(0.1 * frame, 0, 0)
		z["age"] = float(initial["age"]) + 0.05 * frame
		dead.render(camera, {}, false, 0.05)
		assert_eq(int(dead._last_seen_draw[picked_id]["b"]), 1, "the assigned appearance is ready")
		assert_true(z.has("body_step"))
		assert_eq(float(z.get("body_step", -1.0)), waiting_steps[frame], "appearance readiness cannot change body_step")


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


func test_visible_garment_wait_keeps_appearance_but_refreshes_the_draw() -> void:
	_field(true)
	var waiting: WaitingGarment = dead as WaitingGarment
	waiting.waiting = false
	var z: Dictionary = _spawn(origin)
	var id: int = int(z["id"])
	z["worn"] = {"coat": Wear.make("coat_long")}
	dead.render(camera, _seen(origin), true, 0.0)
	var record: Dictionary = dead._last_seen_draw[id]
	var kept_body: int = int(record["b"])
	var kept_shell: String = String(record["shell"])
	var kept_garment: MultiMeshInstance3D = record["garment"]
	var kept_color: Color = record["garment_color"]
	assert_eq(kept_shell, "coat_long")
	waiting.waiting = true
	z["worn"] = {"coat": Wear.make("vest_armor")}
	z["kind"] = "fresh"
	z["stun"] = 1.0
	for offset: float in [1.0, 2.0]:
		var current_at: Vector3 = origin + Vector3(offset, 0, 0)
		z["pos"] = current_at
		dead.render(camera, _seen(current_at), true, 0.09)
		var transform: Transform3D = record["transform"]
		var custom: Color = record["custom"]
		assert_true(is_same(dead._last_seen_draw[id], record))
		assert_eq(record["at"], current_at)
		assert_eq(transform.origin, current_at)
		assert_eq(dead.drawn_at.get(id, Vector3.INF), current_at, "waiting for clothes cannot freeze a visible body in place")
		assert_eq(record["look"], "fresh")
		assert_almost_eq(custom.a, 0.8, 0.0001, "current stun updates the unpacked custom shade")
		assert_eq(int(record["b"]), kept_body)
		assert_eq(String(record["shell"]), kept_shell)
		assert_eq(record["garment"], kept_garment)
		assert_eq(record["garment_color"], kept_color)
		assert_eq(float(dead._shown[id]), 1.0)
		assert_eq(dead.appearance_swaps, 0)
	waiting.waiting = false
	z["pos"] = origin + Vector3(3, 0, 0)
	dead.render(camera, _seen(z["pos"]), true, 0.09)
	assert_eq(dead.drawn_at.get(id, Vector3.INF), z["pos"])
	assert_eq(String(record["shell"]), "vest")
	assert_ne(record["garment_color"], kept_color)
	assert_eq(dead.appearance_swaps, 1, "the ready appearance is counted once")
	dead.render(camera, _seen(z["pos"]), true, 0.09)
	assert_eq(dead.appearance_swaps, 1)


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
	assert_false(dead._submitted_last.has(id))
	assert_false(dead._submitted_markers.has(id))
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
