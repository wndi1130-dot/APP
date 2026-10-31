extends "res://addons/gut/test.gd"
## Decision 486: clearing, the train's calls, and the people it sends back out.

const FieldGame = preload("res://game/field_game.gd")
const FieldWork = preload("res://game/field_work.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const ArrivalHorde = preload("res://game/sim/arrival_horde.gd")

class CountReceipt extends "res://game/sim/receipt.gd":
	var sent_calls: Dictionary = {}

	func _init() -> void:
		super("work_crew_test")

	func person(list_name: String, id: String) -> bool:
		if list_name == "sent":
			sent_calls[id] = int(sent_calls.get(id, 0)) + 1
		return super.person(list_name, id)

var game: FieldGame


func _game() -> FieldGame:
	var field: FieldGame = FieldGame.new()
	field.opts = {"seed": 17, "raiders": false, "auto_pause": false, "field_save": false}
	add_child_autofree(field)
	field.set_process(false)
	field.zombies.list.clear()
	field.pending_spawn.clear()
	field.player.position = field.work.position_of("work_site")
	field.receipt = CountReceipt.new()
	return field


func before_each() -> void:
	game = _game()


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		var dt: float = minf(left, 1.0)
		game.clock.elapsed += dt
		game.work.update(dt)
		left -= dt


func _radio() -> String:
	return String(game.radio_wait.get("text", ""))


func _at() -> Vector3:
	return game.work.position_of("work_site")


func _spawn(at: Vector3, state: String = "wander", kind: String = "dead") -> Dictionary:
	var z: Dictionary = game.zombies.spawn(kind, at)
	z["state"] = state
	return z


func _outer(reach: float = 35.0) -> Vector3:
	var path: PackedVector3Array = game.work.route("work_site")
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var at: Vector3 = _at() + direction * reach
		var clear: bool = true
		for cell: Vector3 in path:
			if at.distance_to(cell) <= FieldWork.PATH_R + 1.0:
				clear = false
		if clear:
			return at
	return _at() + Vector3(reach, 0, 0)


func _ring(cleared: int) -> void:
	for i in 10:
		_spawn(_outer(), ("dead" if i % 2 == 0 else "downed") if i < cleared else "wander")


func _job(id: String) -> void:
	var spot: Dictionary = game.data["spots"]["work_site"].duplicate(true)
	spot["job"] = id
	spot["amount"] = 10.0
	spot["state"] = "closed"
	game.data["spots"]["work_site"] = spot


func _send() -> void:
	_advance(1.0)
	game.actions.start_work(game.player)
	_advance(FieldWork.ESCORT_LEAD)


func _role(role: String) -> Array:
	var out: Array = []
	for p in game.crew:
		if p.role == role:
			out.append(p)
	return out


func _events() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in game.telemetry.work_events:
		out.append(String(row["ev"]))
	return out


func _board_all() -> void:
	for p in game.crew:
		p.position = game.work.door_of("work_site")
		game.ai._crew(p, 0.1, true)
		assert_true(bool(p.brain.get("boarded", false)))
		assert_true(p.brain.has("board_at"))


func test_six_job_crews_and_house_buildings() -> void:
	var expected: Dictionary = {"coal_heap": [4, 1], "coal_wagon": [4, 2], "wood_stack": [4, 1],
		"furniture": [2, 1], "house": [4, 2], "tree": [4, 2]}
	assert_eq(FieldWork.JOBS.size(), 6)
	for id: String in expected:
		assert_eq([FieldWork.JOBS[id]["carriers"], FieldWork.JOBS[id]["escorts"]], expected[id], id)
	assert_eq(FieldWork.JOBS["house"]["buildings"], ["log_cabin", "wood_shed", "barn"])
	assert_eq(float(FieldWork.JOBS["coal_wagon"]["work_s"]), 90.0)
	assert_eq(float(FieldWork.JOBS["coal_wagon"]["trip"]), 0.25)


func test_seven_of_ten_dead_or_downed_opens_but_six_does_not() -> void:
	_ring(7)
	var safe: Dictionary = game.work.safety()
	assert_eq(int(safe["total"]), 10)
	assert_eq(int(safe["cleared"]), 7)
	assert_almost_eq(float(safe["share"]), 0.7, 0.0001)
	assert_true(bool(safe["open"]))
	game.zombies.list[6]["state"] = "wander"
	assert_false(bool(game.work.safety()["open"]))


func test_frozen_and_decorative_corpses_are_out_of_both_counts() -> void:
	_ring(7)
	_spawn(_at(), "frozen", "frozen")
	_spawn(_at(), "dead", "corpse")
	_spawn(_at(), "wander", "corpse")
	var safe: Dictionary = game.work.safety()
	assert_eq(int(safe["total"]), 10)
	assert_eq(int(safe["cleared"]), 7)
	assert_true(bool(safe["open"]))


func test_one_awake_near_the_site_closes_a_cleared_ring() -> void:
	for i in 4:
		_spawn(_at(), "dead")
	_spawn(_at() + Vector3(0, 0, 24))
	var safe: Dictionary = game.work.safety()
	assert_almost_eq(float(safe["share"]), 0.8, 0.0001)
	assert_eq(int(safe["near_awake"]), 1)
	assert_false(bool(safe["open"]))


func test_waking_on_the_door_path_blocks_and_path_is_cached_for_ten_seconds() -> void:
	var door: Vector2i = game.data["spawns"]["train_door"][0]
	game.data["spots"]["work_site"]["cell"] = door + Vector2i(0, 51)
	var z: Dictionary = _spawn(game.work.door_of("work_site"), "waking")
	var safe: Dictionary = game.work.safety()
	assert_eq(int(safe["near_awake"]), 0)
	assert_eq(int(safe["path_awake"]), 1)
	assert_false(bool(safe["open"]))
	var cached_at: float = float(game.work.sites["work_site"]["path_at"])
	_advance(9.0)
	assert_eq(float(game.work.sites["work_site"]["path_at"]), cached_at)
	_advance(1.0)
	assert_gt(float(game.work.sites["work_site"]["path_at"]), cached_at)
	z["state"] = "downed"
	assert_true(bool(game.work.safety()["open"]))


func test_radio_seen_then_half_then_open_uses_the_exact_lines() -> void:
	_ring(0)
	_advance(1.0)
	assert_eq(_radio(), "기관사: 저기 석탄 화차 일터가 보입니다. 둘레에 망자가 열 남짓 있어 아직 못 내보냅니다.")
	for i in 4:
		game.zombies.list[i]["state"] = "dead"
	_advance(1.0)
	assert_eq(_radio(), "기관사: 좀 줄었습니다. 조금만 더 치우면 내보내겠습니다.")
	for i in 7:
		game.zombies.list[i]["state"] = "downed"
	_advance(1.0)
	assert_eq(_radio(), "기관사: 이 정도면 이제 거의 안전한 것 같습니다. 작업조 내보낼까요?")
	assert_eq(game.data["spots"]["work_site"]["state"], "ready")
	assert_eq(_events(), ["seen", "half", "open"] as Array[String])


func test_smoothed_path_segments_are_checked_between_their_endpoints() -> void:
	var door: Vector3 = game.work.door_of("work_site")
	game.data["spots"]["work_site"]["cell"] = FieldGrid.cell_of(door) + Vector2i(0, 70)
	game.work.sites["work_site"]["path"] = PackedVector3Array([door, _at()])
	game.work.sites["work_site"]["path_at"] = game.work.elapsed
	for i in 10:
		_spawn(_at(), "dead")
	_spawn(door.lerp(_at(), 0.5), "waking")
	var safe: Dictionary = game.work.safety()
	assert_eq(int(safe["near_awake"]), 0)
	assert_eq(int(safe["path_awake"]), 1)
	assert_gt(float(safe["share"]), FieldWork.CLEAR_SHARE)
	assert_false(bool(safe["open"]))


## Decision 486: while the brakes' dead are still coming the button waits, said once, and it
## opens when they are dealt with.
func test_the_button_waits_while_the_brakes_dead_are_coming() -> void:
	var z: Dictionary = _spawn(_outer(FieldWork.RING_R + 20.0), "investigate")
	z["arrival"] = true
	assert_true(game.work.safety()["open"], "off the ring and the walk: only the arrival holds it")
	_advance(1.0)
	assert_true(game.work.arriving())
	assert_eq(_radio(), FieldWork.ARRIVAL_LINE)
	assert_ne(game.data["spots"]["work_site"]["state"], "ready")
	game.radio_wait.clear()
	game.actions.start_work(game.player)
	assert_eq(_radio(), FieldWork.ARRIVAL_LINE, "a press says why, every time")
	assert_eq(game.crew.size(), 0)
	game.radio_wait.clear()
	_advance(3.0)
	assert_eq(_radio(), "", "the train says it once")
	assert_eq(_events(), ["seen"] as Array[String], "still shut")
	z["state"] = "dead"
	_advance(1.0)
	assert_eq(_radio(), "기관사: 이 정도면 이제 거의 안전한 것 같습니다. 작업조 내보낼까요?")
	assert_eq(game.data["spots"]["work_site"]["state"], "ready")


## One still to walk in (the guards' fill, a few seconds apart) holds the button too.
func test_one_still_to_walk_in_holds_the_button() -> void:
	game.train_guard.fill_due = [{"t": game.clock.elapsed + 2.5, "i": 0}]
	assert_true(game.work.arriving())
	game.train_guard.fill_due = []
	assert_false(game.work.arriving())


## A worker two metres from its own place along the wagon (at the next one's) walks on to it
## rather than digging there.
func test_a_worker_at_the_next_place_walks_on_to_its_own() -> void:
	_job("coal_wagon")
	_send()
	var wagon: Dictionary = game.ai._wagon_with_coal()
	var workers: Array = _role("worker")
	var own: Vector3 = game.work._work_spot(workers[1], "work_site", wagon)
	var other: Vector3 = game.work._work_spot(workers[0], "work_site", wagon)
	assert_gt(own.distance_to(other), FieldWork.WAGON_WORK_R, "the next place is outside its own reach")
	workers[1].position = other
	workers[1].brain["work_wait"] = 0.0
	game.ai._crew(workers[1], 0.1, true)
	assert_ne(workers[1].action_label, String(FieldWork.JOBS["coal_wagon"]["verb"]), "not digging at the next place")


func test_past_the_arrival_window_a_late_one_no_longer_holds_the_button() -> void:
	var z: Dictionary = _spawn(_outer(FieldWork.RING_R + 20.0), "investigate")
	z["arrival"] = true
	game.clock.elapsed = ArrivalHorde.WINDOW_S + 1.0
	assert_false(game.work.arriving(), "a straggler is one of the stop's dead now")
	_advance(1.0)
	assert_eq(game.data["spots"]["work_site"]["state"], "ready")


func test_initially_empty_site_starts_with_the_open_call() -> void:
	_advance(1.0)
	assert_eq(_radio(), "기관사: 이 정도면 이제 거의 안전한 것 같습니다. 작업조 내보낼까요?")
	assert_eq(_events(), ["seen", "open"] as Array[String])


func test_a_press_before_the_first_call_only_opens_the_button() -> void:
	game.actions.start_work(game.player)
	assert_eq(game.crew.size(), 0)
	assert_eq(_radio(), "기관사: 이 정도면 이제 거의 안전한 것 같습니다. 작업조 내보낼까요?")
	assert_eq(game.data["spots"]["work_site"]["state"], "ready")
	game.actions.start_work(game.player)
	assert_eq(_role("escort").size(), 2)


func test_closed_button_says_one_reason_and_sends_nobody() -> void:
	_spawn(game.work.door_of("work_site"))
	game.actions.start_work(game.player)
	assert_eq(_radio(), "기관사: 열차에서 거기까지 길에 망자가 하나 있습니다.")
	assert_eq(game.crew.size(), 0)
	assert_eq(game.receipt.to_dict()["people"]["sent"].size(), 0)
	assert_eq(game.work.blocked_reason({"path_awake": 0, "near_awake": 2}), "기관사: 일터 바로 곁에 깨어 있는 놈이 둘 있습니다.")
	assert_eq(game.work.blocked_reason({"path_awake": 0, "near_awake": 0, "total": 10, "cleared": 6}), "기관사: 둘레에 아직 하나 남았습니다.")
	assert_eq(game.work.blocked_reason({"path_awake": 11}), "기관사: 열차에서 거기까지 길에 망자가 열 남짓 있습니다.")


func test_open_call_is_not_repeated_until_sixty_seconds_have_passed() -> void:
	_advance(1.0)
	var z: Dictionary = _spawn(_at())
	game.radio_wait.clear()
	_advance(1.0)
	assert_eq(game.work.phase(), "closed")
	assert_eq(_radio(), "")
	z["state"] = "dead"
	_advance(1.0)
	assert_eq(game.work.phase(), "open")
	assert_eq(_radio(), "")
	z["state"] = "wander"
	_advance(60.0)
	game.radio_wait.clear()
	z["state"] = "dead"
	_advance(1.0)
	assert_eq(_radio(), "기관사: 이 정도면 이제 거의 안전한 것 같습니다. 작업조 내보낼까요?")


func test_coal_wagon_escorts_land_three_seconds_before_four_workers() -> void:
	_advance(1.0)
	game.actions.start_work(game.player)
	assert_eq(_role("escort").size(), 2)
	assert_eq(_role("worker").size(), 0)
	assert_eq(_radio(), "기관사: 작업조 내려간다. 호위는 석탄 화차 일터를 지켜라.")
	_advance(2.0)
	assert_eq(_role("worker").size(), 0)
	_advance(1.0)
	assert_eq(_role("worker").size(), 4)
	for p in game.crew:
		assert_lt(p.position.distance_to(game.work.door_of("work_site")), 1.0)


func test_dispatch_between_ticks_still_gives_the_escort_at_least_three_seconds() -> void:
	_advance(1.75)
	game.actions.start_work(game.player)
	_advance(2.25)
	assert_eq(_role("worker").size(), 0)
	_advance(1.0)
	assert_eq(_role("worker").size(), 4)


func test_first_work_starts_are_spread_between_zero_and_six_seconds() -> void:
	_job("furniture")
	_send()
	var starts: Array[float] = []
	for p in _role("worker"):
		p.position = _at()
		game.ai._crew(p, 0.1, true)
		var wait: float = float(p.brain["work_wait"]) - game.work.elapsed
		assert_between(wait, 0.0, 6.0)
		starts.append(wait)
	assert_ne(starts[0], starts[1])


func test_furniture_uses_two_workers_one_escort_and_its_actual_cap() -> void:
	_job("furniture")
	while game.allies_alive().size() < game.ALLY_CAP - 3:
		game.make_person({"id": "cap_%d" % game.people.size(), "name": "동료", "role": "worker"}, game.player.position)
	_send()
	assert_eq(_role("worker").size(), 2)
	assert_eq(_role("escort").size(), 1)
	assert_eq(game.allies_alive().size(), game.ALLY_CAP)


func test_cap_overflow_sends_no_escort_or_worker() -> void:
	while game.allies_alive().size() < game.ALLY_CAP - 5:
		game.make_person({"id": "cap_%d" % game.people.size(), "name": "동료", "role": "worker"}, game.player.position)
	_send()
	assert_eq(game.crew.size(), 0)
	assert_false(game.actions.work_started)
	assert_false(_events().has("sent"))


func test_hold_retreat_dropped_load_and_same_people_on_the_next_dispatch() -> void:
	_send()
	var original: Array = game.crew.duplicate()
	var worker: Variant = _role("worker")[0]
	worker.position = _at()
	worker.brain["load"] = 0.25
	worker.brain["job"] = "carry"
	for i in 4:
		_spawn(_at() + Vector3(0, 0, 15))
	_advance(1.0)
	assert_eq(game.work.phase(), "hold")
	assert_eq(_radio(), "기관사: 작업조 잠깐 멈춰. 호위가 막는다.")
	game.ai._crew(worker, 0.1, true)
	assert_eq(worker.brain["dest"], game.work._hold_spot(worker, "work_site"))
	# Each waits by the hold position at its own place (decision 486 N1: four sent to one point
	# pushed one another off it and walked back to it again).
	var holds: Array[Vector3] = []
	for p in _role("worker"):
		holds.append(game.work._hold_spot(p, "work_site"))
	for i in holds.size():
		assert_lt(holds[i].distance_to(game.work.hold_position("work_site")), FieldWork.SITE_SPREAD + 1.0)
		for j in range(i + 1, holds.size()):
			assert_gt(holds[i].distance_to(holds[j]), 0.5, "no two wait on one point")
	_advance(19.0)
	assert_eq(game.work.phase(), "hold")
	_advance(1.0)
	assert_eq(game.work.phase(), "retreat")
	assert_eq(_radio(), "기관사: 작업조 물러나!")
	assert_eq(game.work.dropped.size(), 1)
	assert_eq(float(game.work.dropped[0]["n"]), 0.25)
	game.ai._crew(worker, 0.1, true)
	assert_eq(worker.brain["dest"], game.work.door_of("work_site"))
	_board_all()
	game.zombies.list.clear()
	_advance(1.0)
	assert_eq(game.work.phase(), "closed")
	_advance(1.0)
	assert_eq(_radio(), "기관사: 다시 내보낼까요?")
	game.actions.start_work(game.player)
	_advance(3.0)
	assert_eq(game.crew, original)
	for p in game.crew:
		assert_false(bool(p.brain["boarded"]))
		assert_lt(p.position.distance_to(game.work.door_of("work_site")), 1.0)
		assert_eq(int((game.receipt as CountReceipt).sent_calls[p.pid]), 1)
	worker.position = game.work.dropped[0]["pos"]
	game.ai._crew(worker, 0.1, true)
	assert_true(game.work.dropped.is_empty())
	assert_eq(float(worker.brain["load"]), 0.25)


func test_hold_needs_five_continuous_clear_seconds() -> void:
	_send()
	for i in 4:
		_spawn(_at() + Vector3(0, 0, 15))
	_advance(1.0)
	game.zombies.list[0]["state"] = "dead"
	_advance(4.0)
	assert_eq(game.work.phase(), "hold")
	game.zombies.list[0]["state"] = "wander"
	_advance(1.0)
	game.zombies.list[0]["state"] = "dead"
	_advance(4.0)
	assert_eq(game.work.phase(), "hold")
	_advance(1.0)
	assert_eq(game.work.phase(), "working")


func test_eight_awake_retreat_without_waiting_twenty_seconds() -> void:
	_send()
	for i in 8:
		_spawn(_at())
	_advance(1.0)
	assert_eq(game.work.phase(), "retreat")


func test_a_grabbed_worker_calls_retreat() -> void:
	_send()
	var z: Dictionary = _spawn(_at())
	_role("worker")[0].grabbers.append(z)
	_advance(1.0)
	assert_eq(game.work.phase(), "retreat")


func test_a_fallen_escort_calls_retreat() -> void:
	_send()
	_role("escort")[0].body.downed = true
	_advance(1.0)
	assert_eq(game.work.phase(), "retreat")


func test_only_the_seconds_held_at_four_count_toward_the_overflow() -> void:
	_send()
	for i in 4:
		_spawn(_at() + Vector3(0, 0, 15))
	_advance(1.0)
	_advance(16.0)
	game.zombies.list[0]["state"] = "dead"
	_advance(4.0)
	assert_eq(game.work.phase(), "hold", "four clear seconds do not add to the twenty")
	game.zombies.list[0]["state"] = "wander"
	_advance(3.0)
	assert_eq(game.work.phase(), "hold")
	_advance(1.0)
	assert_eq(game.work.phase(), "retreat")


func test_a_slipping_escort_does_not_call_retreat() -> void:
	_send()
	_role("escort")[0].fallen_t = 1.0
	_advance(1.0)
	assert_eq(game.work.phase(), "working")


func test_half_is_said_only_after_more_is_cleared_than_at_first_sight() -> void:
	_ring(4)
	_advance(1.0)
	assert_true(_radio().contains("아직 못 내보냅니다"))
	_advance(1.0)
	assert_eq(_events(), ["seen"] as Array[String])
	game.zombies.list[4]["state"] = "dead"
	_advance(1.0)
	assert_eq(_radio(), "기관사: 좀 줄었습니다. 조금만 더 치우면 내보내겠습니다.")


func test_worker_backs_behind_escort_at_eight_and_drops_at_three_metres() -> void:
	_send()
	var worker: Variant = _role("worker")[0]
	var guard: Variant = _role("escort")[0]
	worker.position = _at()
	guard.position = _at() + Vector3(-2, 0, 0)
	_role("escort")[1].position = _at() + Vector3(-20, 0, 0)
	worker.brain["load"] = 0.25
	var z: Dictionary = _spawn(_at() + Vector3(8, 0, 0))
	worker.start_action("dig", "곡괭이질", 45.0, Callable())
	game.ai._crew(worker, 0.1, true)
	assert_eq(worker.action, "")
	assert_eq(worker.brain["dest"], guard.position + Vector3(-2, 0, 0))
	assert_eq(float(worker.brain["load"]), 0.25)
	z["pos"] = _at() + Vector3(3, 0, 0)
	game.ai._crew(worker, 0.1, true)
	assert_eq(float(worker.brain["load"]), 0.0)
	assert_eq(game.work.dropped.size(), 1)
	assert_eq(worker.brain["dest"], game.work.door_of("work_site"))


func test_a_posted_escort_keeps_its_back_to_the_work() -> void:
	_send()
	for guard in _role("escort"):
		guard.position = _at() + Vector3(-4.0 if guard.brain.get("side", 0) == 0 else 4.0, 0, 1.5)
		guard.stop()
		guard.face_point(_at())
		var before := INF
		# A whole sweep (about 12.6 s): no step may jump, as a flip across the screen would.
		for i in 26:
			game.clock.elapsed += 0.5
			game.ai._crew(guard, 0.1, true)
			var look := Vector3(sin(guard.facing), 0.0, cos(guard.facing))
			assert_gt(rad_to_deg(look.angle_to(_at() - guard.position)), 119.5, "watching outward, the work behind")
			var screen: Vector3 = game.cam_back()
			screen.y = 0.0
			assert_gt(rad_to_deg(look.angle_to(screen)), game.ai.LOOK_CAMERA_DEG - 0.5, "never into the screen")
			if before != INF:
				assert_lt(rad_to_deg(absf(angle_difference(before, guard.facing))), 30.0, "the sweep turns slowly, never flips")
			before = guard.facing


func _cycle(id: String) -> void:
	_job(id)
	_send()
	var worker: Variant = _role("worker")[0]
	var template: Dictionary = FieldWork.JOBS[id]
	worker.position = _at()
	worker.brain["work_wait"] = 0.0
	if id == "coal_wagon":
		worker.position = FieldGrid.center(game.ai._wagon_with_coal()["work"])
	var before: float = game.work.remaining()
	game.ai._crew(worker, 0.1, true)
	assert_eq(worker.action_label, String(template["verb"]))
	assert_eq(worker.action_total, float(template["work_s"]))
	worker.action_done.call()
	worker.cancel_action()
	assert_almost_eq(game.work.remaining(), before - float(template["trip"]), 0.0001)
	worker.position = game.work.door_of("work_site")
	if id == "coal_wagon":
		worker.position = game.work.coal_drop(worker)
	game.ai._crew(worker, 0.1, true)
	var delivered: float = game.actions.coal_delivered if template["yield"] == "coal" else game.actions.wood_delivered
	assert_almost_eq(delivered, float(template["trip"]), 0.0001)


## Decision 486 N1: coal goes down beside the train wherever the map's ring has moved it, at the
## carrier's own x (the old fixed row 6 was 70 rows off on a grown map).
func test_coal_goes_down_beside_the_train_where_the_map_puts_it() -> void:
	_job("coal_wagon")
	_send()
	var worker: Variant = _role("worker")[0]
	game.data["train"] = Rect2i(46, 76, 80, 3)
	worker.position = Vector3(121.4, 0.0, 93.5)
	assert_eq(FieldGrid.cell_of(game.work.coal_drop(worker)), Vector2i(121, 81))
	worker.position = Vector3(140.0, 0.0, 93.5)
	assert_eq(FieldGrid.cell_of(game.work.coal_drop(worker)), Vector2i(124, 81), "a cell in from the train's end")


## A train at the foot of the map still gets its coal put down on the map, where a carrier can stand.
func test_coal_drop_stays_on_the_map_where_a_carrier_can_stand() -> void:
	_job("coal_wagon")
	_send()
	var worker: Variant = _role("worker")[0]
	game.data["train"] = Rect2i(10, game.grid.height - 3, 40, 3)
	worker.position = Vector3(20.5, 0.0, float(game.grid.height) - 5.0)
	var cell: Vector2i = FieldGrid.cell_of(game.work.coal_drop(worker))
	assert_true(game.grid.inside(cell), "on the map")
	assert_true(game.grid.people_can_walk(cell), "where a carrier can stand")


## Each worker digs at its own place along the wagon, two metres apart to either hand of the work
## cell and within the wagon's length (on this map the work cell is mid-wagon).
func test_workers_dig_at_their_own_places_along_the_wagon() -> void:
	_job("coal_wagon")
	_send()
	var wagon: Dictionary = game.ai._wagon_with_coal()
	var spots: Array[Vector3] = []
	for p in _role("worker"):
		spots.append(game.work._work_spot(p, "work_site", wagon))
	assert_eq(spots.size(), 4)
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			assert_gt(spots[i].distance_to(spots[j]), 1.5, "no two at one place")
		assert_lt(spots[i].distance_to(FieldGrid.center(wagon["work"])), (wagon["rect"] as Rect2i).size.x + 0.5)


func test_coal_wagon_cycle() -> void:
	_cycle("coal_wagon")


func test_coal_heap_trial_site_cycle() -> void:
	_cycle("coal_heap")


func test_wood_stack_trial_site_cycle() -> void:
	_cycle("wood_stack")


func test_furniture_trial_site_cycle() -> void:
	_cycle("furniture")


func test_house_trial_site_cycle() -> void:
	_cycle("house")


func test_tree_trial_site_cycle() -> void:
	_cycle("tree")


func test_player_pickup_of_dropped_wood_does_not_leave_a_second_crew_load() -> void:
	_job("furniture")
	_send()
	var worker: Variant = _role("worker")[0]
	worker.position = _at()
	worker.brain["load"] = 1.0
	game.work.drop_load(worker)
	assert_true(game.work.dropped.is_empty(), "wood lies on the ground, not with the coal piles")
	assert_eq(game.ground_items[-1]["id"], "wood")
	assert_eq(game.work._dropped_near("work_site").size(), 1)
	game.player.position = _at()
	game.actions.pick_up(game.player, game.ground_items.size() - 1)
	assert_true(game.work._dropped_near("work_site").is_empty())
	game.ai._crew(worker, 0.1, true)
	assert_eq(float(worker.brain["load"]), 0.0)


func test_identical_wood_piles_keep_their_own_ground_items() -> void:
	_job("furniture")
	_send()
	for p in _role("worker"):
		p.position = _at()
		p.brain["load"] = 1.0
		game.work.drop_load(p)
	var piles: Array[Dictionary] = game.work._dropped_near("work_site")
	assert_eq(piles.size(), 2)
	var first: Dictionary = piles[0]
	game.player.position = _at()
	game.actions.pick_up(game.player, game.ground_items.size() - 1)
	piles = game.work._dropped_near("work_site")
	assert_eq(piles.size(), 1)
	assert_true(is_same(piles[0], first))
	game.ai._crew(_role("worker")[0], 0.1, true)
	assert_true(game.work._dropped_near("work_site").is_empty())
	assert_eq(float(_role("worker")[0].brain["load"]), 1.0)


func test_empty_site_is_done_after_the_last_load_is_unloaded() -> void:
	_job("furniture")
	_send()
	var worker: Variant = _role("worker")[0]
	game.data["spots"]["work_site"]["amount"] = 0.0
	worker.brain["load"] = 1.0
	_advance(1.0)
	assert_eq(game.work.phase(), "working")
	worker.position = game.work.door_of("work_site")
	game.ai._crew(worker, 0.1, true)
	_advance(1.0)
	assert_eq(game.actions.wood_delivered, 1.0)
	assert_eq(game.work.phase(), "done")
	assert_true(_events().has("done"))
	assert_false(game.actions.work_started)


func test_budget_counts_wagons_once_salvage_wood_and_five_other_job_amounts() -> void:
	var data: Dictionary = {"wagons": [{"coal": 2.0, "work": Vector2i(1, 1)}, {"coal": 3.5, "work": Vector2i(2, 1)}, {"coal": 9.0}], "spots": {
		"wagon": {"kind": "work_site", "amount": 999.0},
		"heap": {"kind": "work_site", "job": "coal_heap", "amount": 1.0},
		"salvage": {"kind": "salvage", "material": "wood", "amount": 2},
		"scrap": {"kind": "salvage", "material": "scrap", "amount": 99}}}
	for id: String in ["wood_stack", "furniture", "house", "tree"]:
		data["spots"][id] = {"kind": "work_site", "job": id, "amount": 1.0}
	assert_eq(FieldWork.budget(data), {"coal": 6.5, "wood": 6.0})
	assert_eq(FieldWork.WOOD_TABLE, {"freight": 2, "houses": 5, "hospital": 1, "factory": 1, "church": 3, "office": 3})
	assert_eq(FieldWork.BUDGET_SLACK, 0.1)


func test_a_save_while_the_crew_is_out_makes_the_same_crew_again_on_resume() -> void:
	_send()
	_advance(1.0)
	var pids: Array = []
	for p in game.crew:
		pids.append(p.pid)
	pids.sort()
	assert_eq(pids.size(), 6)
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var resumed: FieldGame = FieldGame.new()
	resumed.opts = FieldSave.resume_opts(saved)
	add_child_autofree(resumed)
	resumed.set_process(false)
	var back: Array = []
	for p in resumed.crew:
		assert_not_null(p)
		if p != null:
			assert_true(resumed.people.has(p))
			back.append(p.pid)
	back.sort()
	assert_eq(back, pids)
	assert_eq(resumed.work.phase(), game.work.phase())
	assert_eq(resumed.work.members("work_site").size(), 6)


func test_a_part_load_of_wood_dropped_by_the_crew_keeps_its_part_through_a_save() -> void:
	game.ground_items.append({"pos": Vector3(1, 0, 1), "id": "wood", "n": 0.5, "crew_drop": true})
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var drops: Array = (saved["ground_items"] as Array).filter(func(g: Dictionary) -> bool: return g.get("crew_drop", false))
	assert_eq(drops.size(), 1)
	assert_almost_eq(float(drops[0]["n"]), 0.5, 0.001)


## A restart builds the map again: coal dug from a wagon must not be back in it after one.
func _wagons_kept_through_a_save() -> void:
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var resumed: FieldGame = FieldGame.new()
	resumed.opts = FieldSave.resume_opts(saved)
	add_child_autofree(resumed)
	resumed.set_process(false)
	assert_eq(resumed.data["wagons"].size(), game.data["wagons"].size())
	for i in mini(resumed.data["wagons"].size(), game.data["wagons"].size()):
		assert_almost_eq(float(resumed.data["wagons"][i]["coal"]), float(game.data["wagons"][i]["coal"]), 0.0001)


func test_coal_the_crew_dug_stays_out_of_the_wagon_through_a_save() -> void:
	_send()
	assert_eq(game.work.phase(), "working")
	var before: float = FieldWork.wagon_coal(game.data)
	game.work._worked(_role("worker")[0], "work_site")
	assert_lt(FieldWork.wagon_coal(game.data), before, "the dig took coal from a wagon")
	_wagons_kept_through_a_save()


func test_coal_a_squad_mate_dug_stays_out_of_the_wagon_through_a_save() -> void:
	var mate: Variant = null
	for p in game.squad:
		if p != game.player:
			mate = p
			break
	assert_not_null(mate)
	var before: float = FieldWork.wagon_coal(game.data)
	game.ai._dug(mate)
	assert_lt(FieldWork.wagon_coal(game.data), before, "the dig took coal from a wagon")
	_wagons_kept_through_a_save()


func test_a_contract_with_no_work_crew_sends_nobody() -> void:
	_advance(1.0)
	game.opts["departure"] = {"version": 2, "roster": [], "workCrew": []}
	assert_false(game.work.start())
	assert_eq(_radio(), FieldWork.SPEAKER + ": 지금 내보낼 일꾼이 없습니다.")
	assert_eq(game.crew.size(), 0)


func test_no_escort_to_stand_guard_sends_nobody() -> void:
	_advance(1.0)
	for row: Dictionary in FieldWork.DEFAULT_ROWS:
		if row["role"] == "escort":
			var p = game.make_person(row, game.work.door_of("work_site"))
			p.body.downed = true
			game.crew.append(p)
	assert_false(game.work.start())
	assert_eq(_radio(), FieldWork.SPEAKER + ": 지켜 줄 호위가 없습니다. 지금은 못 내보냅니다.")
	assert_eq(game.work.phase(), "open")


func test_every_carrier_down_for_ten_seconds_calls_the_crew_back() -> void:
	_send()
	for p in _role("worker"):
		p.body.downed = true
	_advance(FieldWork.NO_HANDS_S - 1.0)
	assert_ne(game.work.phase(), "retreat")
	_advance(1.0)
	assert_eq(game.work.phase(), "retreat")
	assert_eq(game.work.sites["work_site"]["why"], "no_hands")
