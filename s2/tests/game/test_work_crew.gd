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


func _parts(seconds: Array, wagon_index: int = -1) -> Array:
	var index: int = game.work._dig_wagon_index("work_site") if wagon_index < 0 else wagon_index
	var out: Array = []
	for value: float in seconds:
		out.append({"wagon": index, "seconds": value})
	return out


func _pick(parts: Array = []) -> Variant:
	game.work._site("work_site")["dig_parts"] = parts
	var worker: Variant = _role("worker")[0]
	worker.position = game.work._work_spot(worker, "work_site", game.work.dig_wagon())
	worker.brain["work_wait"] = 0.0
	game.ai._crew(worker, 0.1, true)
	return worker


## The whole site somewhere else: its cell, and its wagons' work cells with it (a coal site
## works from a wagon far off its cell, field_work.gd moved_to).
func _move_site(cell: Vector2i) -> void:
	var shift: Vector2i = cell - (game.data["spots"]["work_site"]["cell"] as Vector2i)
	game.data["spots"]["work_site"]["cell"] = cell
	for wagon: Dictionary in game.data["wagons"]:
		if wagon.has("work"):
			wagon["work"] = (wagon["work"] as Vector2i) + shift


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
	_move_site(door + Vector2i(0, 51))
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
	_move_site(FieldGrid.cell_of(door) + Vector2i(0, 70))
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
	assert_eq(workers[1].brain.get("dest"), own, "walking to its own place")
	assert_false(workers[1].path.is_empty(), "walking needs a path")
	if not workers[1].path.is_empty():
		assert_eq(workers[1].path[-1], own, "the path ends at its own place")


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
	assert_eq(_radio(), "기관사: 열차에서 일터 가는 길에 망자가 하나 있습니다.")
	assert_eq(game.crew.size(), 0)
	assert_eq(game.receipt.to_dict()["people"]["sent"].size(), 0)
	assert_eq(game.work.blocked_reason({"path_awake": 0, "near_awake": 2}), "기관사: 일터 바로 곁에 깨어 있는 망자가 둘 있습니다.")
	assert_eq(game.work.blocked_reason({"path_awake": 0, "near_awake": 0, "total": 10, "cleared": 6}), "기관사: 둘레에 아직 하나 남았습니다.")
	assert_eq(game.work.blocked_reason({"path_awake": 11}), "기관사: 열차에서 일터 가는 길에 망자가 열 남짓 있습니다.")


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
	var train: Rect2i = Rect2i(10, game.grid.height - 3, 40, 3)
	game.data["train"] = train
	# The new train occupies real solid cells; the two rows above remain reachable.
	for y in range(train.position.y - 3, train.end.y):
		for x in range(train.position.x - 3, train.end.x + 3):
			var at: Vector2i = Vector2i(x, y)
			game.grid.set_solid(at, FieldGrid.Solid.BLOCK if train.has_point(at) else FieldGrid.Solid.NONE)
	game.grid.refresh_paths()
	worker.position = FieldGrid.center(Vector2i(20, train.position.y - 3))
	var original: Vector2i = Vector2i(20, game.grid.height - 1)
	assert_true(train.has_point(original))
	assert_false(game.grid.people_can_walk(original), "the clamped candidate is inside the train")
	var drop: Vector3 = game.work.coal_drop(worker)
	var cell: Vector2i = FieldGrid.cell_of(drop)
	assert_true(game.grid.inside(cell), "on the map")
	assert_true(game.grid.people_can_walk(cell), "where a carrier can stand")
	assert_false(train.has_point(cell), "outside the train's solid cells")
	var path: PackedVector3Array = game.find_path(worker.position, drop, false)
	assert_false(path.is_empty(), "reachable from the carrier")
	if not path.is_empty():
		assert_eq(path[-1], drop, "the path reaches the drop")


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


func test_a_short_wagon_limits_diggers_to_distinct_places() -> void:
	_send()
	var wagon: Dictionary = game.work.dig_wagon()
	var cell: Vector2i = wagon["work"]
	var rect: Rect2i = wagon["rect"]
	wagon["rect"] = Rect2i(cell.x, rect.position.y, 1, rect.size.y)
	assert_eq(game.work._wagon_places(wagon).size(), 1)
	var diggers: int = 0
	var waiting: Array[Vector3] = []
	for worker in _role("worker"):
		var at: Vector3 = game.work._work_spot(worker, "work_site", wagon)
		worker.position = at if at.is_finite() else _at()
		worker.brain["work_wait"] = 0.0
		game.work.crew_step(worker, true)
		if worker.action == "dig":
			diggers += 1
		else:
			assert_false(at.is_finite(), "no reused digging slot")
			assert_true(worker.brain.get("dest") is Vector3, "waiting beside the site")
			waiting.append(worker.brain["dest"])
	assert_eq(_role("worker").size(), 4, "the crew size is unchanged")
	assert_eq(diggers, 1)
	assert_eq(waiting.size(), 3)
	for i in waiting.size():
		for j in range(i + 1, waiting.size()):
			assert_gte(waiting[i].distance_to(waiting[j]), FieldWork.WORK_GAP - FieldWork.EMPTY)


func test_corrected_work_and_hold_places_never_overlap() -> void:
	_send()
	var wagon: Dictionary = game.work.dig_wagon()
	var cell: Vector2i = wagon["work"]
	var rect: Rect2i = wagon["rect"]
	wagon["rect"] = Rect2i(cell.x, rect.position.y, 3, rect.size.y)
	var only: Vector2i = cell + Vector2i(1, 0)
	for y in range(cell.y - 2, cell.y + 3):
		for x in range(cell.x - 2, cell.x + 5):
			var at: Vector2i = Vector2i(x, y)
			game.grid.set_solid(at, FieldGrid.Solid.NONE if at == only else FieldGrid.Solid.BLOCK)
	var hold: Vector2i = FieldGrid.cell_of(game.work.hold_position("work_site"))
	for y in range(hold.y - 2, hold.y + 3):
		for x in range(hold.x - 2, hold.x + 3):
			var at: Vector2i = Vector2i(x, y)
			game.grid.set_solid(at, FieldGrid.Solid.NONE if at == hold else FieldGrid.Solid.BLOCK)
	game.grid.refresh_paths()
	assert_eq(game.walkable_near(FieldGrid.center(cell)), FieldGrid.center(only))
	assert_eq(game.walkable_near(FieldGrid.center(cell + Vector2i(2, 0))), FieldGrid.center(only))
	var places: Array[Vector3] = game.work._wagon_places(wagon)
	assert_eq(places.size(), 1, "two corrected candidates become one slot")
	if not places.is_empty():
		assert_eq(places[0], FieldGrid.center(only))
	var waiting: Array[Vector3] = []
	for worker in _role("worker"):
		var at: Vector3 = game.work._hold_spot(worker, "work_site")
		assert_true(at.is_finite())
		assert_true(game.grid.people_can_walk(FieldGrid.cell_of(at)))
		for other: Vector3 in waiting:
			assert_gte(at.distance_to(other), FieldWork.WORK_GAP - FieldWork.EMPTY)
		waiting.append(at)


func test_a_retreat_keeps_the_pick_and_the_next_dispatch_resumes_it_by_default() -> void:
	_job("coal_wagon")
	_send()
	assert_true(game.work.keeps_dig(), "the rule is on without a measuring override")
	var worker: Variant = _role("worker")[0]
	worker.position = game.work._work_spot(worker, "work_site", game.ai._wagon_with_coal())
	worker.brain["work_wait"] = 0.0
	game.ai._crew(worker, 0.1, true)
	assert_eq(worker.action, "dig")
	assert_eq(worker.action_total, FieldWork.DIG_TIME)
	worker.action_t = FieldWork.DIG_TIME - 30.0
	game.work.retreat("work_site")
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([30.0]), "returned before any update")
	game.work.update(0.0)
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([30.0]))
	assert_false(worker.brain.has("dig_done"))
	assert_false(worker.brain.has("dig_from"))
	_board_all()
	_advance(2.0)
	game.actions.start_work(game.player)
	_advance(FieldWork.ESCORT_LEAD)
	worker.position = game.work._work_spot(worker, "work_site", game.ai._wagon_with_coal())
	worker.brain["work_wait"] = 0.0
	game.ai._crew(worker, 0.1, true)
	assert_eq(worker.action, "dig")
	assert_eq(worker.action_total, FieldWork.DIG_TIME - 30.0)
	assert_eq(float(worker.brain["dig_from"]), 30.0)
	assert_true(game.work._site("work_site")["dig_parts"].is_empty())
	assert_almost_eq(game.work.dig_progress(), 1.0 / 3.0, 0.0001)
	worker.action_t -= 15.0
	game.work.retreat("work_site")
	game.work.update(0.0)
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([45.0]), "the resumed pick keeps both parts once")


func test_dig_progress_uses_the_furthest_saved_or_live_pick() -> void:
	assert_eq(game.work.dig_progress(), 0.0)
	var state: Dictionary = game.work._site("work_site")
	state["dig_wagon"] = 0
	state["dig_parts"] = [45.0]
	assert_eq(game.work.dig_progress(), 0.5)
	state["dig_parts"] = [15.0, 67.5, 30.0]
	assert_eq(game.work.dig_progress(), 0.75, "the largest part, not their sum")
	_send()
	var worker: Variant = _pick([30.0])
	var active: Dictionary = game.work._active_digs("work_site")[worker.pid]
	active["done"] = 54.0
	worker.action_t = 9.0
	assert_almost_eq(game.work.dig_progress(), 0.9, 0.0001, "the live timer includes what this pick resumed")
	active["done"] = 85.5
	assert_almost_eq(game.work.dig_progress(), 0.95, 0.0001, "the worker's larger recorded progress counts too")
	state["dig_parts"] = [135.0]
	assert_eq(game.work.dig_progress(), 1.0)
	assert_eq(state["dig_parts"], [135.0], "reading progress does not rewrite saved parts")
	game.work._cancel_dig(worker, "work_site")
	state["dig_parts"] = [-15.0]
	assert_eq(game.work.dig_progress(), 0.0)
	assert_eq(state["dig_parts"], [-15.0], "normalization belongs to the work state")


func test_a_resumed_pick_returns_immediately_without_an_update() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	assert_eq(worker.action_total, 30.0)
	assert_eq(float(worker.brain["dig_done"]), 60.0, "owned from the start")
	game.work.retreat("work_site")
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([60.0]))
	game.work._keep_digs()
	game.work._cancel_dig(worker, "work_site")
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([60.0]), "one return")
	assert_false(worker.brain.has("dig_from"))
	assert_false(worker.brain.has("dig_done"))
	assert_true(game.work._active_digs("work_site").is_empty())


func test_a_refused_pick_restores_its_resumed_seconds_once() -> void:
	_send()
	var worker: Variant = _role("worker")[0]
	game.work._site("work_site")["dig_parts"] = [60.0]
	worker.swing_t = 1.0
	game.work._begin_dig(worker, "work_site")
	assert_eq(worker.action, "")
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([60.0]))
	game.work._keep_digs()
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([60.0]))
	assert_false(worker.brain.has("dig_from"))
	assert_true(game.work._active_digs("work_site").is_empty())


func test_a_removed_worker_returns_the_current_timer_once() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	worker.action_t = 24.0
	game.crew.erase(worker)
	assert_false(game.work.members("work_site").has(worker))
	game.work._keep_digs()
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([66.0]))
	game.work._keep_digs()
	game.work.retreat("work_site")
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([66.0]), "not returned twice")
	assert_eq(worker.action, "")


func test_a_removed_worker_is_recovered_on_retreat_without_an_update() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	worker.action_t = 24.0
	game.crew.erase(worker)
	game.work.retreat("work_site")
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([66.0]))
	game.work._keep_digs()
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([66.0]))


func test_a_freed_worker_returns_on_tree_exit_without_polling() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	worker.action_t = 20.0
	game.crew.erase(worker)
	game.people.erase(worker)
	worker.free()
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([70.0]))
	game.work._keep_digs()
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([70.0]))


func test_a_dead_worker_keeps_the_timer_before_cancellation() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	worker.action_t = 21.0
	worker.body.dead = true
	game.work._keep_digs()
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([69.0]))
	assert_eq(worker.action, "")
	game.work._keep_digs()
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([69.0]))


func test_a_hold_and_board_return_a_resumed_pick_before_polling() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	worker.action_t = 25.0
	game.work._site("work_site")["phase"] = "hold"
	game.work.crew_step(worker, true)
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([65.0]))
	game.work._site("work_site")["phase"] = "working"
	worker.position = game.work._work_spot(worker, "work_site", game.work.dig_wagon())
	game.work._begin_dig(worker, "work_site")
	worker.position = game.work.door_of("work_site")
	game.work._go_home(worker, "work_site", true)
	assert_true(bool(worker.brain["boarded"]))
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([65.0]))


func test_a_threat_returns_the_pick_before_walking_away() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	worker.action_t = 20.0
	_spawn(worker.position + Vector3(2, 0, 0))
	game.work.crew_step(worker, true)
	assert_eq(worker.action, "")
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([70.0]))
	game.work._keep_digs()
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([70.0]))


func test_an_empty_wagon_never_lends_its_pick_to_the_next() -> void:
	_send()
	var first: int = game.work._dig_wagon_index("work_site")
	var state: Dictionary = game.work._site("work_site")
	state["dig_parts"] = _parts([60.0], first)
	game.work.paint_digs()
	game.data["wagons"][first]["coal"] = 0.0
	var second: int = game.work._dig_wagon_index("work_site")
	assert_ne(second, first)
	assert_gte(second, 0)
	game.work.paint_digs()
	assert_false(game.view.dig_nodes["work_site"].visible, "the next wagon has no progress")
	var worker: Variant = _pick(state["dig_parts"])
	assert_eq(worker.action_total, FieldWork.DIG_TIME, "the next wagon starts at zero")
	assert_eq(state["dig_parts"], _parts([60.0], first))
	worker.action_t = 60.0
	game.work.paint_digs()
	var bar: MeshInstance3D = game.view.dig_nodes["work_site"]
	assert_eq(bar.position, game.view.dig_bar_at(game.data["wagons"][second]))
	assert_eq(int(bar.get_meta("cells", -1)), 2, "only this wagon's 30 seconds")
	game.work._cancel_dig(worker, "work_site")
	game.data["wagons"][first]["coal"] = 1.0
	game.data["wagons"][second]["coal"] = 0.0
	assert_eq(game.work._take_dig("work_site"), 60.0, "the original coal still owns its pick")
	assert_eq(state["dig_parts"], _parts([30.0], second))


func test_a_completed_pick_never_takes_coal_from_the_next_wagon() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	var first: int = int(worker.brain["dig_wagon"])
	game.data["wagons"][first]["coal"] = 0.0
	var second: int = game.work._dig_wagon_index("work_site")
	var before: float = float(game.data["wagons"][second]["coal"])
	var done: Callable = worker.action_done
	worker.cancel_action()
	done.call()
	assert_eq(float(game.data["wagons"][second]["coal"]), before)
	assert_eq(float(worker.brain["load"]), 0.0)
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([90.0], first))
	done.call()
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([90.0], first), "completion also consumes ownership once")


func test_coal_sites_paint_their_own_wagons() -> void:
	var other: Dictionary = game.data["spots"]["work_site"].duplicate(true)
	game.data["spots"]["other_coal"] = other
	game.work._site("work_site")["phase"] = "working"
	game.work._site("other_coal")["phase"] = "working"
	var first: Dictionary = game.work.dig_wagon("work_site")
	var second: Dictionary = game.work.dig_wagon("other_coal")
	assert_false(is_same(first, second))
	game.work._site("work_site")["dig_parts"] = [30.0]
	game.work._site("other_coal")["dig_parts"] = [60.0]
	game.work.paint_digs()
	var first_bar: MeshInstance3D = game.view.dig_nodes["work_site"]
	var second_bar: MeshInstance3D = game.view.dig_nodes["other_coal"]
	assert_eq(first_bar.position, game.view.dig_bar_at(first))
	assert_eq(second_bar.position, game.view.dig_bar_at(second))
	assert_ne(first_bar.position, second_bar.position)
	assert_eq(int(first_bar.get_meta("cells", -1)), 2)
	assert_eq(int(second_bar.get_meta("cells", -1)), 4)


func test_only_finite_clamped_seconds_can_be_resumed() -> void:
	_send()
	var state: Dictionary = game.work._site("work_site")
	state["dig_parts"] = [NAN, INF, -INF, -15.0, 135.0, 45.0]
	assert_eq(game.work._take_dig("work_site"), 90.0)
	assert_eq(state["dig_parts"], _parts([0.0, 45.0]))
	assert_eq(game.work._take_dig("work_site"), 45.0)
	assert_eq(game.work._take_dig("work_site"), 0.0)
	assert_true(state["dig_parts"].is_empty())
	var worker: Variant = _pick([-15.0])
	assert_eq(worker.action_total, 90.0)
	assert_eq(float(worker.brain["dig_from"]), 0.0)
	game.work._cancel_dig(worker, "work_site")
	worker = _pick([135.0])
	assert_eq(worker.action_total, FieldWork.EMPTY)
	assert_eq(float(worker.brain["dig_from"]), 90.0)


func test_dig_bar_reuses_its_mesh_until_the_filled_count_changes() -> void:
	var state: Dictionary = game.work._site("work_site")
	state["dig_wagon"] = 0
	state["dig_parts"] = [30.0]
	game.work.paint_digs()
	var bar: MeshInstance3D = game.view.dig_nodes["work_site"]
	var first_mesh: Mesh = bar.mesh
	var wagon: Dictionary = game.ai._wagon_with_coal()
	assert_true(bar.visible)
	assert_eq(bar.position, game.view.dig_bar_at(wagon))
	assert_gt(bar.position.y, 3.0, "over the 3 m wagon's roof, not hidden by its side")
	assert_eq(int(bar.get_meta("cells", -1)), 2)
	state["dig_parts"] = [31.0]
	game.work.paint_digs()
	assert_eq(bar.mesh, first_mesh, "the same two filled cells reuse the mesh")
	var work_cell: Vector2i = wagon["work"]
	wagon["work"] = work_cell + Vector2i(1, 0)
	game.work.paint_digs()
	assert_eq(bar.position, game.view.dig_bar_at(wagon))
	assert_almost_eq(bar.position.x, FieldGrid.center(work_cell + Vector2i(1, 0)).x, 0.0001, "the bar follows the work cell")
	assert_eq(bar.mesh, first_mesh, "moving the bar does not rebuild it")
	state["dig_parts"] = [60.0]
	game.work.paint_digs()
	assert_ne(bar.mesh, first_mesh)
	assert_eq(int(bar.get_meta("cells", -1)), 4)
	state["dig_parts"] = []
	game.work.paint_digs()
	assert_false(bar.visible)
	state["dig_parts"] = [1.0]
	game.work.paint_digs()
	assert_true(bar.visible, "even a part below the first filled cell is visible")
	assert_eq(int(bar.get_meta("cells", -1)), 0)


func test_dig_progress_and_restore_painting_allow_a_missing_view() -> void:
	var original_view: Variant = game.view
	game.view = null
	game.work._site("work_site")["dig_parts"] = [45.0]
	game.work._site("work_site")["dig_wagon"] = 0
	game.work.update(1.0)
	FieldSave._refresh_restored_view(game)
	game.view = original_view
	assert_eq(game.work.dig_progress(), 0.5)


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
	var state: Dictionary = game.work._site("work_site")
	state["dig_parts"] = [15.0, 30.0, 45.0]
	var worker: Variant = _role("worker")[0]
	worker.position = game.work._work_spot(worker, "work_site", game.ai._wagon_with_coal())
	worker.brain["work_wait"] = 0.0
	game.ai._crew(worker, 0.1, true)
	worker.action_t = 30.0
	game.work.update(0.0)
	assert_eq(state["dig_parts"], _parts([15.0, 30.0]), "the next pick took the largest saved part")
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
	assert_eq(resumed.work._site("work_site")["dig_parts"], state["dig_parts"])
	var resumed_worker: Variant = resumed.work._person(worker.pid)
	assert_not_null(resumed_worker)
	if resumed_worker != null:
		assert_eq(float(resumed_worker.brain["dig_from"]), 45.0)
		assert_eq(float(resumed_worker.brain["dig_done"]), 60.0)
		assert_eq(resumed_worker.action, "dig")
		assert_eq(resumed_worker.action_t, worker.action_t)
		assert_eq(resumed_worker.action_total, worker.action_total)
	assert_almost_eq(resumed.work.dig_progress(), 2.0 / 3.0, 0.0001)
	assert_true(resumed.view.dig_nodes.has("work_site"), "the bar is rebuilt before another tick")
	if resumed.view.dig_nodes.has("work_site"):
		var bar: MeshInstance3D = resumed.view.dig_nodes["work_site"]
		assert_true(bar.visible)
		assert_eq(int(bar.get_meta("cells", -1)), 4)


func test_wagon_bound_parts_round_trip_to_their_original_wagons() -> void:
	_send()
	var first: int = game.work._dig_wagon_index("work_site")
	game.data["wagons"][first]["coal"] = 0.0
	var second: int = game.work._dig_wagon_index("work_site")
	var parts: Array = _parts([60.0], first) + _parts([30.0], second)
	game.work._site("work_site")["dig_parts"] = parts
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var resumed: FieldGame = FieldGame.new()
	resumed.opts = FieldSave.resume_opts(saved)
	add_child_autofree(resumed)
	resumed.set_process(false)
	assert_eq(resumed.work._site("work_site")["dig_parts"], parts)
	assert_eq(resumed.work._dig_wagon_index("work_site"), second)
	assert_almost_eq(resumed.work.dig_progress(), 1.0 / 3.0, 0.0001)
	var bar: MeshInstance3D = resumed.view.dig_nodes["work_site"]
	assert_eq(bar.position, resumed.view.dig_bar_at(resumed.data["wagons"][second]))
	assert_eq(int(bar.get_meta("cells", -1)), 2)
	resumed.data["wagons"][first]["coal"] = 1.0
	resumed.data["wagons"][second]["coal"] = 0.0
	assert_eq(resumed.work._take_dig("work_site"), 60.0)
	assert_eq(resumed.work._site("work_site")["dig_parts"], _parts([30.0], second))


func test_a_live_pick_keeps_its_wagon_when_resumed_from_a_save() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	var first: int = int(worker.brain["dig_wagon"])
	game.data["wagons"][first]["coal"] = 0.0
	var second: int = game.work._dig_wagon_index("work_site")
	game.data["wagons"][first]["coal"] = 1.0
	var before: float = float(game.data["wagons"][second]["coal"])
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var resumed: FieldGame = FieldGame.new()
	resumed.opts = FieldSave.resume_opts(saved)
	add_child_autofree(resumed)
	resumed.set_process(false)
	var back: Variant = resumed.work._person(worker.pid)
	assert_eq(int(back.brain["dig_wagon"]), first)
	assert_eq(resumed.work._dig_wagon_index("work_site"), second)
	var done: Callable = back.action_done
	back.cancel_action()
	done.call()
	assert_eq(float(resumed.data["wagons"][second]["coal"]), before)
	assert_eq(float(resumed.data["wagons"][first]["coal"]), 1.0 - FieldWork.TRIP_COAL)
	assert_eq(float(back.brain["load"]), FieldWork.TRIP_COAL)
	assert_true(resumed.work._site("work_site")["dig_parts"].is_empty())


func test_capture_keeps_the_unpolled_timer_for_an_immediate_resume_retreat() -> void:
	_send()
	var worker: Variant = _pick([60.0])
	worker.action_t = 24.0
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var resumed: FieldGame = FieldGame.new()
	resumed.opts = FieldSave.resume_opts(saved)
	add_child_autofree(resumed)
	resumed.set_process(false)
	var back: Variant = resumed.work._person(worker.pid)
	assert_eq(float(back.brain["dig_done"]), 66.0)
	assert_eq(back.action_total, 30.0)
	assert_eq(back.action_t, 24.0)
	resumed.work.retreat("work_site")
	assert_eq(resumed.work._site("work_site")["dig_parts"], _parts([66.0]))
	resumed.work._keep_digs()
	assert_eq(resumed.work._site("work_site")["dig_parts"], _parts([66.0]))


func test_an_older_save_migrates_numeric_parts_and_live_ownership() -> void:
	_send()
	var worker: Variant = _pick([45.0])
	worker.action_t = 30.0
	var saved: Dictionary = FieldSave.capture(game)
	var old_site: Dictionary = saved["runtime"]["components"]["work"]["sites"]["work_site"]
	old_site["dig_parts"] = [15.0, 30.0]
	old_site.erase("dig_active")
	old_site.erase("dig_wagon")
	for row: Dictionary in saved["people"]:
		if row["pid"] == worker.pid:
			row["state"]["brain"].erase("dig_wagon")
			var call: Array = row["state"]["action_done"]["$call"]
			call[2].pop_back()
	saved = FieldSave.from_json(FieldSave.to_json(saved))
	var resumed: FieldGame = FieldGame.new()
	resumed.opts = FieldSave.resume_opts(saved)
	add_child_autofree(resumed)
	resumed.set_process(false)
	var back: Variant = resumed.work._person(worker.pid)
	assert_eq(float(back.brain["dig_from"]), 45.0)
	assert_eq(float(back.brain["dig_done"]), 60.0)
	assert_eq(resumed.work._site("work_site")["dig_parts"], _parts([15.0, 30.0]))
	resumed.work.retreat("work_site")
	assert_eq(resumed.work._site("work_site")["dig_parts"], _parts([15.0, 30.0, 60.0]))
	resumed.work._keep_digs()
	assert_eq(resumed.work._site("work_site")["dig_parts"], _parts([15.0, 30.0, 60.0]))


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
	var worker: Variant = _pick()
	var done: Callable = worker.action_done
	worker.cancel_action()
	done.call()
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


func test_idle_coal_sites_never_claim_wagons_while_painting() -> void:
	var original_view: Variant = game.view
	var choices: Array[int] = []
	for with_view: bool in [true, false]:
		game.view = original_view if with_view else null
		game.work.sites.clear()
		game.data["spots"]["other_coal"] = game.data["spots"]["work_site"].duplicate(true)
		game.data["wagons"][0]["coal"] = 0.25
		game.data["wagons"][1]["coal"] = 1.0
		game.work.paint_digs()
		assert_true(game.work.sites.is_empty(), "painting does not even create a site state")
		_send()
		assert_eq(int(game.work._site("work_site")["dig_wagon"]), 0)
		game.work.paint_digs()
		assert_eq(int(game.work._site("other_coal").get("dig_wagon", -1)), -1)
		var worker: Variant = _pick()
		var done: Callable = worker.action_done
		worker.cancel_action()
		done.call()
		assert_eq(float(game.data["wagons"][0]["coal"]), 0.0)
		worker.position = game.work.coal_drop(worker)
		game.work.crew_step(worker, true)
		game.work.crew_step(worker, true)
		choices.append(int(game.work._site("work_site")["dig_wagon"]))
		assert_eq(choices[-1], 1, "the active site reaches the second wagon")
		game.work.retreat("work_site")
		assert_eq(int(game.work._site("work_site")["dig_wagon"]), -1)
		_board_all()
		game.work.paint_digs()
		assert_eq(int(game.work._site("work_site")["dig_wagon"]), -1)
	game.view = original_view
	assert_eq(choices, [1, 1])


func test_a_short_wagon_passes_its_place_and_pick_to_the_next_live_worker() -> void:
	_send()
	var wagon: Dictionary = game.work.dig_wagon()
	var cell: Vector2i = wagon["work"]
	var rect: Rect2i = wagon["rect"]
	wagon["rect"] = Rect2i(cell.x, rect.position.y, 1, rect.size.y)
	var first: Variant = _pick([60.0])
	var next: Variant = _role("worker")[1]
	assert_false(game.work._work_spot(next, "work_site", wagon).is_finite())
	first.body.downed = true
	game.work.update(0.0)
	var place: Vector3 = game.work._work_spot(next, "work_site", wagon)
	assert_eq(place, FieldGrid.center(cell))
	next.position = place
	next.brain["work_wait"] = 0.0
	game.ai._crew(next, 0.1, true)
	assert_eq(next.action, "dig")
	assert_eq(next.action_total, 30.0)
	assert_eq(float(next.brain["dig_from"]), 60.0)
	game.work._cancel_dig(next, "work_site")
	next.body.dead = true
	var last: Variant = _role("worker")[2]
	_role("worker")[3].brain["boarded"] = true
	assert_eq(game.work._turn(last, "work_site"), Vector2i(0, 1))
	assert_eq(game.work._work_spot(last, "work_site", wagon), place)


func test_missing_carriers_retreat_after_ten_seconds_and_can_be_sent_again() -> void:
	_send()
	for worker in _role("worker"):
		game.crew.erase(worker)
		game.people.erase(worker)
		worker.free()
	_advance(FieldWork.NO_HANDS_S - 1.0)
	assert_eq(game.work.phase(), "working")
	_advance(1.0)
	assert_eq(game.work.phase(), "retreat")
	assert_eq(game.work._site("work_site")["why"], "no_hands")
	_board_all()
	_advance(2.0)
	assert_true(game.work.start())
	_advance(FieldWork.ESCORT_LEAD)
	assert_eq(game.work.phase(), "working")
	assert_eq(_role("worker").size(), 4)


func test_boarded_carriers_do_not_count_as_missing_hands() -> void:
	_send()
	for worker in _role("worker"):
		worker.position = game.work.door_of("work_site")
		game.work._go_home(worker, "work_site", true)
	assert_false(game.work._no_hands("work_site"))
	_advance(FieldWork.NO_HANDS_S + 1.0)
	assert_eq(game.work.phase(), "working")
	assert_eq(float(game.work._site("work_site")["no_hands_s"]), 0.0)


func test_a_blocked_cached_coal_drop_is_replaced_before_delivery() -> void:
	_send()
	var worker: Variant = _role("worker")[0]
	worker.position = game.work._work_spot(worker, "work_site", game.work.dig_wagon())
	worker.brain["load"] = 0.25
	var old_drop: Vector3 = game.work.coal_drop(worker)
	worker.brain["coal_drop"] = old_drop
	game.grid.set_solid(FieldGrid.cell_of(old_drop), FieldGrid.Solid.BLOCK)
	game.grid.refresh_paths()
	game.work._deliver(worker, "work_site")
	var next_drop: Vector3 = worker.brain["coal_drop"]
	assert_ne(next_drop, old_drop)
	assert_true(game.grid.people_can_walk(FieldGrid.cell_of(next_drop)))
	assert_eq(worker.brain["dest"], next_drop)
	assert_false(worker.path.is_empty())
	if not worker.path.is_empty():
		assert_lte(worker.path[-1].distance_to(next_drop), FieldWork.DROP_R)
	assert_eq(float(worker.brain["load"]), 0.25)
	assert_eq(game.actions.coal_delivered, 0.0)


func test_a_walkable_but_unreachable_coal_drop_is_replaced() -> void:
	_send()
	var worker: Variant = _role("worker")[0]
	worker.position = game.work._work_spot(worker, "work_site", game.work.dig_wagon())
	worker.brain["load"] = 0.25
	var old_drop: Vector3 = game.work.coal_drop(worker)
	var cell: Vector2i = FieldGrid.cell_of(old_drop)
	worker.brain["coal_drop"] = old_drop
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dy != 0:
				game.grid.set_solid(cell + Vector2i(dx, dy), FieldGrid.Solid.BLOCK)
	game.grid.refresh_paths()
	assert_true(game.grid.people_can_walk(cell))
	var failed: PackedVector3Array = game.find_path(worker.position, old_drop, false)
	assert_true(failed.is_empty() or failed[-1].distance_to(old_drop) > FieldWork.DROP_R)
	game.work._deliver(worker, "work_site")
	var next_drop: Vector3 = worker.brain["coal_drop"]
	assert_ne(next_drop, old_drop)
	assert_false(worker.path.is_empty())
	if not worker.path.is_empty():
		assert_lte(worker.path[-1].distance_to(next_drop), FieldWork.DROP_R)
	worker.position = next_drop
	game.work._deliver(worker, "work_site")
	assert_eq(game.actions.coal_delivered, 0.25)
	assert_eq(float(worker.brain["load"]), 0.0)


func _warm_pick_timer(field: FieldGame, worker) -> void:
	field.weather.kinds.clear()
	field.weather.ambient_c = 20.0
	worker.worn.erase("hands")
	worker.heat.heat = 100.0
	worker.heat.wet = 0.0
	assert_eq(float(worker.mults()["hands"]), 1.0)


func _advance_pick_timer(field: FieldGame, worker, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		var dt: float = minf(left, 0.25)
		field.clock.elapsed += dt
		field._update_person(worker, dt)
		field.work.update(dt)
		left -= dt


func test_a_real_pick_timer_takes_coal_once_only_after_ninety_seconds() -> void:
	_send()
	var worker: Variant = _pick()
	_warm_pick_timer(game, worker)
	var before: float = FieldWork.wagon_coal(game.data)
	_advance_pick_timer(game, worker, 89.75)
	assert_eq(worker.action, "dig")
	assert_eq(worker.action_t, 0.25)
	assert_eq(FieldWork.wagon_coal(game.data), before)
	assert_eq(float(worker.brain["load"]), 0.0)
	_advance_pick_timer(game, worker, 0.5)
	assert_eq(worker.action, "")
	assert_eq(FieldWork.wagon_coal(game.data), before - FieldWork.TRIP_COAL)
	assert_eq(float(worker.brain["load"]), FieldWork.TRIP_COAL)
	assert_true(game.work._active_digs("work_site").is_empty())
	_advance_pick_timer(game, worker, 5.0)
	assert_eq(FieldWork.wagon_coal(game.data), before - FieldWork.TRIP_COAL)
	assert_eq(float(worker.brain["load"]), FieldWork.TRIP_COAL)


func test_an_interrupted_saved_pick_uses_only_its_remaining_real_timer() -> void:
	_send()
	var worker: Variant = _pick()
	_warm_pick_timer(game, worker)
	var before: float = FieldWork.wagon_coal(game.data)
	_advance_pick_timer(game, worker, 30.0)
	game.work._cancel_dig(worker, "work_site")
	assert_eq(game.work._site("work_site")["dig_parts"], _parts([30.0]))
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	var resumed: FieldGame = FieldGame.new()
	resumed.opts = FieldSave.resume_opts(saved)
	add_child_autofree(resumed)
	resumed.set_process(false)
	var back: Variant = resumed.work._person(worker.pid)
	_warm_pick_timer(resumed, back)
	back.brain["work_wait"] = 0.0
	resumed.ai._crew(back, 0.1, true)
	assert_eq(back.action, "dig")
	assert_eq(back.action_total, 60.0)
	assert_eq(float(back.brain["dig_from"]), 30.0)
	_advance_pick_timer(resumed, back, 59.75)
	assert_eq(back.action_t, 0.25)
	assert_eq(FieldWork.wagon_coal(resumed.data), before)
	assert_eq(float(back.brain["load"]), 0.0)
	_advance_pick_timer(resumed, back, 0.5)
	assert_eq(back.action, "")
	assert_eq(FieldWork.wagon_coal(resumed.data), before - FieldWork.TRIP_COAL)
	assert_eq(float(back.brain["load"]), FieldWork.TRIP_COAL)
	_advance_pick_timer(resumed, back, 5.0)
	assert_eq(FieldWork.wagon_coal(resumed.data), before - FieldWork.TRIP_COAL)
	assert_eq(float(back.brain["load"]), FieldWork.TRIP_COAL)


## The first wagon runs dry and the next stands far off (moved here 35 cells from the site's own place).
func _far_next_wagon() -> Vector2i:
	var wagons: Array = game.data["wagons"]
	var origin: Vector2i = game.data["spots"]["work_site"]["cell"]
	var far: Vector2i = origin + Vector2i(-35, 0)
	for i in wagons.size():
		if i == 0:
			wagons[i]["coal"] = 0.0
		elif wagons[i].has("work"):
			wagons[i]["work"] = far
	return far


# A wagon near the site is worked from the site's own place; a far one takes the site with it:
# the safety ring, the wait on the way and the ring on the ground (escort, sound: position_of).
func test_a_far_next_wagon_moves_the_site_and_a_near_one_does_not() -> void:
	var origin: Vector3 = game.work.origin_of("work_site")
	assert_eq(game.work.position_of("work_site"), origin, "the stop's own wagons stand near")
	game.data["wagons"][0]["coal"] = 0.0
	assert_eq(game.work.position_of("work_site"), origin, "the second one too")
	var far: Vector2i = _far_next_wagon()
	var at: Vector3 = FieldGrid.center(far)
	assert_gt(at.distance_to(origin), FieldWork.FOLLOW_R)
	assert_eq(game.work.position_of("work_site"), at)
	var path: PackedVector3Array = game.work.route("work_site")
	assert_lte(path[-1].distance_to(at), FieldWork.EMPTY, "the way leads to the wagon at once")
	_spawn(at + Vector3(3, 0, 0), "wander")
	assert_eq(int(game.work.safety()["near_awake"]), 1, "the ring stands round the wagon")
	game.work._paint("work_site", game.work.safety())
	assert_eq(game.data["spots"]["work_site"]["marker_cell"], far, "the ring on the ground moves")
	game.data["wagons"][1]["coal"] = 0.0
	assert_eq(game.work.position_of("work_site"), origin, "no wagon left: back to its own place")
	game.work._paint("work_site", game.work.safety())
	assert_false(game.data["spots"]["work_site"].has("marker_cell"))


# The site is found from its own place even when its next wagon stands far off.
func test_the_site_is_found_from_its_own_place() -> void:
	var far: Vector2i = _far_next_wagon()
	game.player.position = FieldGrid.center(far)
	_advance(2.0)
	assert_false(_events().has("seen"), "beside the far wagon is not beside the site")
	game.player.position = game.work.origin_of("work_site")
	_advance(1.0)
	assert_true(_events().has("seen"))
