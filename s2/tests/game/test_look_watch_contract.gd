extends "res://addons/gut/test.gd"
## 저장 경계, 현재 후보 범위, 표시 시선의 계약.

const FieldAi = preload("res://game/field_ai.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldWork = preload("res://game/field_work.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const Person = preload("res://game/actors/person.gd")
const SAMPLE_SECONDS: int = 600
const SAMPLE_PICKS: int = 4096
const MAX_SHARE: float = 0.15
const SITE_HEADING: float = 1.9545153379440308
const PEOPLE: Array = [
	["p_guard_marek", "마레크", "side"],
	["p_med_joanna", "요안나", "rear"],
	["p_tail_tomasz", "토마시", "point"],
]


class WatchClock:
	extends RefCounted
	var elapsed: float = 0.0


class WatchField:
	extends RefCounted
	var clock: WatchClock = WatchClock.new()
	var camera: Node3D
	var squad: Array = []
	var crew: Array = []
	var screen: Vector3 = FieldGame.cam_back()

	func cam_back() -> Vector3:
		return screen


func _person(id: String = "watch_contract", title: String = "Watch") -> Person:
	var person: Person = Person.new()
	add_child_autofree(person)
	person.setup(id, title, "companion", Vector3.ZERO)
	return person


func _way(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


func _camera_count(ai: FieldAi, state: Dictionary, camera: Vector3) -> int:
	var count: int = 0
	for point: int in range(4):
		if ai._watch_faces_camera(float(state["yaw_" + str(point)]), camera):
			count += 1
	return count


func _assert_bounds(ai: FieldAi, state: Dictionary, base: Vector3, camera: Vector3, label: String) -> void:
	var count: int = _camera_count(ai, state, camera)
	assert_lte(count, 2, "%s camera_points=%d" % [label, count])
	for point: int in range(4):
		var angle: float = absf(angle_difference(atan2(base.x, base.z), float(state["yaw_" + str(point)])))
		assert_lte(angle, PI * 0.5 + FieldAi.LOOK_ANGLE_EPS, "%s point=%d role_angle=%.9f" % [label, point, rad_to_deg(angle)])


func test_watch_bounds_after_camera_or_role_change() -> void:
	var field: WatchField = WatchField.new()
	var ai: FieldAi = FieldAi.new(field)
	var person: Person = _person()
	var base: Vector3 = Vector3.LEFT
	var camera: Vector3 = Vector3.RIGHT
	ai._watch_look(person, base, 0, camera, "watch_point")
	var state: Dictionary = person.brain["watch_point"]
	state["point"] = 0
	state["target"] = state["yaw_0"]
	state["until"] = 2.0
	state["waiting"] = 0.0
	person.facing = float(state["target"])
	for change: Array in [[Vector3.LEFT, Vector3.LEFT], [Vector3.BACK, Vector3.LEFT], [Vector3.RIGHT, Vector3.RIGHT]]:
		var target: float = float(state["target"])
		var step: int = int(state["step"])
		base = change[0]
		camera = change[1]
		field.clock.elapsed = float(state["until"]) - 0.1
		var look: Vector3 = ai._watch_look(person, base, 0, camera, "watch_point")
		person.face_point(person.position + look)
		assert_eq(float(state["target"]), target, "머묾 중 세계 목표각 actual=%.9f expected=%.9f" % [float(state["target"]), target])
		assert_eq(int(state["step"]), step, "머묾 중 선택 actual=%d expected=%d" % [int(state["step"]), step])
		field.clock.elapsed = float(state["until"]) + 0.001
		look = ai._watch_look(person, base, 0, camera, "watch_point")
		person.face_point(person.position + look)
		state = person.brain["watch_point"]
		assert_eq(int(state["step"]), step + 1, "상태 유지 후 다음 선택 actual=%d expected=%d" % [int(state["step"]), step + 1])
		_assert_bounds(ai, state, base, camera, "base=%s camera=%s" % [base, camera])
		# 다음 변화는 회전을 마친 머묾에서 시작한다.
		person.look = person.facing
		state["waiting"] = 0.0
		state["until"] = field.clock.elapsed + 2.0


func _field(options: Dictionary = {}) -> FieldGame:
	var field: FieldGame = FieldGame.new()
	field.opts = options if not options.is_empty() else {"seed": 17, "raiders": false, "auto_pause": false, "field_save": false}
	add_child_autofree(field)
	field.set_process(false)
	field.zombies.list.clear()
	field.pending_spawn.clear()
	return field


func _saved_deadline(think_phase: float, deadline: float) -> Dictionary:
	var field: FieldGame = _field()
	var site: Vector3 = field.work.position_of("work_site")
	field.player.position = site
	field.clock.elapsed += 1.0
	field.work.update(1.0)
	field.actions.start_work(field.player)
	field.clock.elapsed += FieldWork.ESCORT_LEAD
	field.work.update(FieldWork.ESCORT_LEAD)
	field.clock.elapsed = 10.0
	var ids: Array[String] = []
	for guard in field.crew:
		if guard.role != "escort":
			continue
		guard.position = site + Vector3(-4.0 if int(guard.brain.get("side", 0)) == 0 else 4.0, 0.0, 1.5)
		guard.stop()
		guard.face_point(guard.position + guard.position - site)
		field.ai._escort_watch(guard, site)
		var state: Dictionary = guard.brain["watch_escort"]
		state["point"] = 0
		state["step"] = 3
		state["target"] = guard.facing
		state["picked"] = 9.0
		state["until"] = 10.0 + deadline
		state["waiting"] = 0.0
		state["turning"] = 0.0
		state["body_turned"] = 0.0
		guard.brain["watch_pick_count"] = 7
		guard.brain["watch_target_yaw"] = guard.facing
		guard.brain["watch_slot"] = FieldAi.LOOK_KEYS.find("watch_escort")
		ids.append(String(guard.pid))
	field._turn_people(0.0)
	field.ai.think_t = think_phase
	assert_eq(ids.size(), 2, "양쪽 호위 actual=%s" % [ids])
	var saved: Dictionary = FieldSave.from_json(FieldSave.to_json(FieldSave.capture(field)))
	assert_false(saved.is_empty(), "저장본 size=%d" % saved.size())
	return {"saved": saved, "ids": ids}


func _deadline_run(fixture: Dictionary, fps: int) -> Dictionary:
	var field: FieldGame = _field(FieldSave.resume_opts(fixture["saved"]))
	var guards: Dictionary = {}
	var events: Dictionary = {}
	var counts: Dictionary = {}
	for person in field.crew:
		var id: String = String(person.pid)
		if id in fixture["ids"]:
			guards[id] = person
			events[id] = []
			counts[id] = int(person.brain["watch_pick_count"])
	assert_eq(guards.size(), 2, "복원 호위 fps=%d ids=%s" % [fps, guards.keys()])
	var at_tenth: Dictionary = {}
	var start: float = field.clock.elapsed
	var delta: float = 1.0 / float(fps)
	for tick: int in range(1, 20 * fps + 1):
		field.clock.elapsed = start + float(tick) / float(fps)
		field._turn_people(delta)
		field.ai.update(delta)
		for id: String in guards:
			var guard: Person = guards[id]
			var state: Dictionary = guard.brain.get("watch_escort", {})
			if state.is_empty():
				fail_test("상태 없음 fps=%d tick=%d id=%s" % [fps, tick, id])
				return {}
			var count: int = int(guard.brain.get("watch_pick_count", 0))
			var sample: Array = [int(state["step"]), int(state["point"]), count]
			if tick * 10 == fps:
				at_tenth[id] = sample
			if count != int(counts[id]):
				events[id].append({"at": field.clock.elapsed - start, "sample": sample})
				counts[id] = count
	return {"tenth": at_tenth, "events": events}


func test_saved_watch_near_deadline_is_fps_invariant() -> void:
	for phase: Vector2 in [Vector2(0.010, 0.020), Vector2(0.047, 0.055)]:
		var fixture: Dictionary = _saved_deadline(phase.x, phase.y)
		var slow: Dictionary = _deadline_run(fixture, 30)
		var fast: Dictionary = _deadline_run(fixture, 60)
		if slow.is_empty() or fast.is_empty():
			return
		for id: String in fixture["ids"]:
			var label: String = "phase=%s id=%s" % [phase, id]
			assert_eq(slow["tenth"].get(id), fast["tenth"].get(id), "%s +0.100 actual30=%s actual60=%s" % [label, slow["tenth"].get(id), fast["tenth"].get(id)])
			var a: Array = slow["events"][id]
			var b: Array = fast["events"][id]
			assert_gt(a.size(), 2, "%s event_count=%d" % [label, a.size()])
			assert_eq(a.size(), b.size(), "%s event_count30=%d event_count60=%d" % [label, a.size(), b.size()])
			for index: int in range(mini(a.size(), b.size())):
				assert_eq(a[index]["sample"], b[index]["sample"], "%s event=%d 30=%s 60=%s" % [label, index, a[index], b[index]])
				var gap: float = absf(float(a[index]["at"]) - float(b[index]["at"]))
				assert_lte(gap, 1.0 / 30.0 + 0.000001, "%s event=%d time_gap=%.9f" % [label, index, gap])


## Person.refresh_view가 몸 표시각을 적용한다. 현재 머리 노드는 별도 yaw를 적용하지 않는다.
func _drawn_yaw(person: Person) -> float:
	return wrapf(person.rotation.y + person.head_mesh.rotation.y, -PI, PI)


func _site_sample(site: String, row: Array, side: int, fps: int) -> int:
	var field: WatchField = WatchField.new()
	field.camera = Node3D.new()
	add_child_autofree(field.camera)
	var ai: FieldAi = FieldAi.new(field)
	var person: Person = _person(String(row[0]), String(row[1]))
	field.squad = [null, person]
	field.crew = [person]
	var heading: float = SITE_HEADING if site == "standing_site" else 0.0
	var forward: Vector3 = _way(heading)
	var right: Vector3 = Vector3(forward.z, 0.0, -forward.x)
	var role: String = String(row[2])
	var centre: Vector3 = Vector3(20.0, 0.0, 20.0)
	var offset: Vector2 = {"point": Vector2(1.2, 1.6), "side": Vector2(1.8, -0.8), "rear": Vector2(0.0, -2.0)}[role]
	person.position = centre + right * offset.x + forward * offset.y
	person.facing = heading
	var key: String = "watch_" + role
	if site == "work_escort":
		person.position = centre + Vector3(-4.0 if side == 0 else 4.0, 0.0, 1.5)
		person.brain["side"] = side
		person.face_point(centre)
		key = "watch_escort"
	person.look = person.facing
	person.turn_rate = deg_to_rad(FieldGame.TURN_DEG_PER_S) * (0.85 + 0.3 * person.name_unit())
	field.camera.global_position = centre + field.screen * 60.0
	var camera: Vector3 = field.screen if site == "work_escort" else field.camera.global_position - person.global_position
	var seconds: float = 0.0
	var delta: float = 1.0 / float(fps)
	for tick: int in range(SAMPLE_SECONDS * fps):
		field.clock.elapsed = float(tick + 1) / float(fps)
		person.turn_tick(delta)
		if site == "work_escort":
			ai._escort_watch(person, centre)
		else:
			var look: Vector3 = ai._look_out(person, role, forward, right)
			person.face_point(person.position + look)
		ai._tick_watch_head(person)
		person.refresh_view(false)
		if ai._watch_faces_camera(_drawn_yaw(person), camera):
			seconds += delta
	var share: float = seconds / float(SAMPLE_SECONDS)
	var label: String = "%s %s side=%d fps=%d" % [site, row[0], side, fps]
	assert_lte(share, MAX_SHARE, "%s drawn_camera_s=%.6f total_s=%d share=%.9f" % [label, seconds, SAMPLE_SECONDS, share])
	var state: Dictionary = person.brain[key]
	var camera_points: int = _camera_count(ai, state, camera)
	var camera_picks: int = 0
	if camera_points > 0:
		for pick: int in range(SAMPLE_PICKS):
			var point: int = ai._watch_pick(person, state, pick, field.clock.elapsed, camera)
			if ai._watch_faces_camera(float(state["yaw_" + str(point)]), camera):
				camera_picks += 1
		assert_gt(camera_picks, 0, "%s camera_points=%d camera_picks=%d/%d" % [label, camera_points, camera_picks, SAMPLE_PICKS])
	print("표시 시선 %s share=%.9f camera_points=%d" % [label, share, camera_points])
	person.queue_free()
	field.camera.queue_free()
	return camera_picks


func test_camera_share_uses_drawn_gaze_in_real_sites() -> void:
	var field: WatchField = WatchField.new()
	var ai: FieldAi = FieldAi.new(field)
	var person: Person = _person()
	person.turn_rate = 1.0
	person.look = deg_to_rad(40.01)
	person.brain["watch_target_yaw"] = deg_to_rad(60.01)
	person.brain["watch_head_yaw"] = deg_to_rad(20.0)
	person.refresh_view(false)
	assert_almost_eq(_drawn_yaw(person), deg_to_rad(40.01), 0.000001, "표시 actual=%.9f" % rad_to_deg(_drawn_yaw(person)))
	assert_true(ai._watch_faces_camera(_drawn_yaw(person), Vector3.BACK), "몸 40.01도 actual=%.9f" % rad_to_deg(_drawn_yaw(person)))
	assert_false(ai._watch_faces_camera(float(person.brain["watch_target_yaw"]), Vector3.BACK), "목표 60.01도 actual=%.9f" % rad_to_deg(float(person.brain["watch_target_yaw"])))
	var total_camera_picks: int = 0
	for fps: int in [30, 60]:
		for row: Array in PEOPLE:
			total_camera_picks += _site_sample("standing_site", row, 0, fps)
			total_camera_picks += _site_sample("north_wall_room", row, 0, fps)
			for side: int in [0, 1]:
				total_camera_picks += _site_sample("work_escort", row, side, fps)
	assert_gt(total_camera_picks, 0, "전체 장기 표본 camera_picks=%d" % total_camera_picks)


func test_camera_rotation_cap_is_not_point_displacement() -> void:
	var field: WatchField = WatchField.new()
	var ai: FieldAi = FieldAi.new(field)
	var person: Person = _person()
	var original: Array[float] = [-30.5, -0.03, 0.01, 33.5]
	for centre: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var state: Dictionary = {}
		for point: int in range(4):
			state["yaw_" + str(point)] = wrapf(centre + deg_to_rad(original[point]), -PI, PI)
		var before: Dictionary = state.duplicate()
		var base: Vector3 = _way(centre)
		var camera: Vector3 = _way(centre + deg_to_rad(0.9))
		var turn: float = ai._watch_camera_turn(person, state, base, camera)
		assert_lte(absf(rad_to_deg(turn)), 60.0001, "공통 회전 actual=%.9f" % rad_to_deg(turn))
		for point: int in range(4):
			var key: String = "yaw_" + str(point)
			state[key] = wrapf(float(state[key]) + turn, -PI, PI)
		ai._watch_camera_adjust(state, base, camera)
		_assert_bounds(ai, state, base, camera, "fallback centre=%.9f" % centre)
		var displacement: float = 0.0
		for point: int in range(4):
			var key: String = "yaw_" + str(point)
			displacement = maxf(displacement, absf(rad_to_deg(angle_difference(float(before[key]), float(state[key])))))
		assert_gt(displacement, 60.5, "공통 회전과 점 이동을 구별 actual_turn=%.9f displacement=%.9f" % [rad_to_deg(turn), displacement])
