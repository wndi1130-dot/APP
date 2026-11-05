extends GutTest
## These contracts also run with the actor scripts at 8119468b.

const Visual = preload("res://game/actors/person_visual.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const Person = preload("res://game/actors/person.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const Baseline = preload("res://tests/game/test_onehand_tip_baseline.gd")
const EPS: float = 0.000001
const GUARD: float = 18.0 / 23.0
const CONTINUITY_DEG: float = 0.1
const ROTATION_PER_30TH_DEG: float = 45.0

var _traces: Dictionary = {}


class WristField:
	var people: Array = []
	var paused: bool = false
	var ended: bool = false
	var hitstop: bool = false
	var slow: float = 1.0
	var combat: Variant = null


func _angle(a: Basis, b: Basis) -> float:
	return rad_to_deg(a.orthonormalized().get_rotation_quaternion().angle_to(b.orthonormalized().get_rotation_quaternion()))


func _continuous(a: Basis, b: Basis, label: String) -> void:
	var full: float = _angle(a, b)
	var axis: float = rad_to_deg(a.z.normalized().angle_to(b.z.normalized()))
	assert_lte(full, CONTINUITY_DEG, "%s 전체 %.9f도" % [label, full])
	assert_lte(axis, CONTINUITY_DEG, "%s z축 %.9f도" % [label, axis])


func test_wrist_follow_is_continuous_across_elevation_gate() -> void:
	var a: Basis = Basis(Vector3.UP, deg_to_rad(60.960127 - 0.0000573)) * Basis(Vector3.RIGHT, deg_to_rad(38.0)) * Basis(Vector3.BACK, deg_to_rad(150.0))
	var b: Basis = Basis(Vector3.UP, deg_to_rad(60.960127 + 0.0000573)) * Basis(Vector3.RIGHT, deg_to_rad(38.0)) * Basis(Vector3.BACK, deg_to_rad(150.0))
	_continuous(Visual.wrist_follow(Basis(), a, 0.5), Visual.wrist_follow(Basis(), b, 0.5), "아래 각 경계")


func test_wrist_filter_is_continuous_at_zero_weight() -> void:
	var was: Basis = Basis(Vector3.RIGHT, deg_to_rad(38.0))
	var hand: Vector3 = Vector3(0.0, cos(deg_to_rad(38.0)), -sin(deg_to_rad(38.0)))
	_continuous(Visual.grip_of(hand, Vector3.ZERO, was, 1.0 / 30.0, true, 0.0),
		Visual.grip_of(hand, Vector3.ZERO, was, 1.0 / 30.0, true, 1e-9), "가중치 0과 1e-9")


func test_wrist_follow_is_continuous_across_opposite_heading() -> void:
	var was: Basis = Basis(Vector3.RIGHT, deg_to_rad(38.0))
	var a: Basis = Basis(Vector3.UP, PI - 1e-6) * was * Basis(Vector3.BACK, deg_to_rad(150.0))
	var b: Basis = Basis(Vector3.UP, PI + 1e-6) * was * Basis(Vector3.BACK, deg_to_rad(150.0))
	_continuous(Visual.wrist_follow(was, a, 0.5), Visual.wrist_follow(was, b, 0.5), "정반대 방위")


func test_wrist_target_is_continuous_across_up_pole() -> void:
	var a: Basis = Basis(Vector3.RIGHT, -PI / 2.0 - 2e-6)
	var b: Basis = Basis(Vector3.RIGHT, -PI / 2.0 + 2e-6)
	for weight: float in [0.0, 1e-9, 0.2, 0.7, 1.0]:
		_continuous(Visual.wrist_target(a, weight), Visual.wrist_target(b, weight), "위쪽 수직 극점 가중치 %.9f" % weight)
	_continuous(Visual.wrist_target(Basis(Vector3.BACK, PI / 2.0 - 2e-6), 1.0),
		Visual.wrist_target(Basis(Vector3.BACK, PI / 2.0 + 2e-6), 1.0), "쥠 가로축의 수직 통과")


func test_wrist_follow_is_continuous_across_vertical_midpoint() -> void:
	var was: Basis = Basis(Vector3.RIGHT, deg_to_rad(38.0))
	var a: Basis = Basis(Vector3.RIGHT, deg_to_rad(142.0) - 2e-6)
	var b: Basis = Basis(Vector3.RIGHT, deg_to_rad(142.0) + 2e-6)
	_continuous(Visual.wrist_follow(was, a, 0.5), Visual.wrist_follow(was, b, 0.5), "필터 중간의 수직 극점")


func test_grip_target_is_continuous_across_sideways_forearm() -> void:
	for dy: float in [1e-9, 1e-6]:
		var a: Vector3 = Vector3(0.8, -dy, 0.6).normalized()
		var b: Vector3 = Vector3(0.8, dy, 0.6).normalized()
		_continuous(Visual.grip_target(a, Vector3.ZERO), Visual.grip_target(b, Vector3.ZERO), "팔 높이 +/-%.9f" % dy)


func _vector(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _basis(b: Basis) -> Array:
	return [_vector(b.x), _vector(b.y), _vector(b.z)]


func _recovery_row(row: Dictionary) -> bool:
	for pair: Array in [[row["clip"], row["phase"]], [row["kept_clip"], row["kept_phase"]]]:
		if pair[0] == null or pair[1] == null:
			continue
		if String(pair[0]) == "p_swing_one" and float(pair[1]) + EPS >= 0.45:
			return true
		if String(pair[0]) == "p_swing_back" and float(pair[1]) + EPS >= 0.33:
			return true
	return false


func _trace(body: String, way: String, fps: int, walking: bool = false, chaining: bool = false) -> Dictionary:
	var key: String = "%s/%s/%d/%s/%s" % [body, way, fps, walking, chaining]
	if _traces.has(key):
		return _traces[key]
	var p: Person = Person.new()
	add_child(p)
	p.setup("wrist_contract", "손목", "companion", Vector3.ZERO)
	p.set_process(false)
	p.set_physics_process(false)
	p.hands = [{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.strike_kind = "swing"
	p.strike_at = {}
	p._refresh_weapon_mesh()
	var field := WristField.new()
	field.people = [p]
	var visual: Visual = Visual.new()
	add_child(visual)
	visual.set_process(false)
	visual.setup(field)
	visual.body_by[p] = body
	visual.notes[p] = {"blow_n": 0, "blow_end": 0.0} if way == "p_swing_back" else {}
	var probe: Baseline = Baseline.new()
	var geometry: Dictionary = probe._tip_geometry(p)
	assert_false(geometry.is_empty(), key + " 실제 무기 끝점")
	var mult: float = float(p.mults()["swing"])
	var wind: float = Pose.W.melee_windup("axe") / mult
	var wait: float = Pose.W.melee_recover(float(Pose.W.get_data("axe")["swing"]) / mult, wind, Pose.W.melee_gap("axe"))
	var release: float = (float(Pose.W.get_data("axe")["swing"]) - Pose.W.melee_windup("axe")) / mult
	var dt: float = 1.0 / float(fps)
	var rows: Array[Dictionary] = []
	var landed: bool = false
	var previous: Basis = Basis()
	var peak: float = 0.0
	var peak_at: float = -1.0
	var peak_axis: float = 0.0
	var active_peak: float = -90.0
	var sampled: int = 0
	var recovery_samples: int = 0
	var walk_blends: int = 0
	var chain_blends: int = 0
	var previous_recovery: bool = false
	var recovery_exits: int = 0
	var diagnostic_target: Variant = null
	var begun: int = 0
	var attacks: int = 3 if chaining else 1
	var observed_attacks: Dictionary = {}
	var gap: float = maxf(38.0 / 30.0, wind + wait + 2.0 / 30.0)
	p.strike_total = wind
	var duration: float = float(attacks - 1) * gap + wind + wait + Visual.RECOVER_GUARD_HOLD + Visual.RECOVER_GUARD_LOWER + 0.2
	for frame: int in range(int(ceil(duration * fps)) + 1):
		var t: float = float(frame) * dt
		if begun < attacks and t + EPS >= float(begun) * gap:
			begun += 1
			landed = false
		var start: float = float(begun - 1) * gap
		var age: float = t - start
		var attack_way: String = ("p_swing_one" if (begun - 1) % 2 == 0 else "p_swing_back") if chaining else way
		if age < wind - EPS:
			p.strike_t = wind - age
			p.swing_t = p.strike_t
		else:
			p.strike_t = 0.0
			p.swing_t = maxf(0.0, wait - (age - wind))
			if not landed:
				p.set_meta(Pose.SWING, wait)
				landed = true
		p.moving = walking and age >= wind + release
		if p.moving:
			p.position.z += 0.8 * dt
		var was: Basis = visual.notes[p].get("grip", Basis())
		var was_displayed: Basis = p.weapon_mesh.basis.orthonormalized()
		visual._process(dt if frame > 0 else 0.0)
		var snapshot: Dictionary = Visual.drawn_snapshot(visual, p)
		assert_false(snapshot.is_empty(), "%s %.6f초 표시 표본" % [key, t])
		if snapshot.is_empty() or geometry.is_empty():
			continue
		var row: Dictionary = probe._sample(p, visual, geometry, attack_way)
		assert_false(row.is_empty(), "%s %.6f초 측정 표본" % [key, t])
		if row.is_empty():
			continue
		row.merge({"rule_s": t, "hit_s": start + wind, "attack": begun - 1, "attack_clip": attack_way}, true)
		if not observed_attacks.has(begun - 1) and String(row["clip"]) in ["p_swing_one", "p_swing_back"]:
			assert_eq(String(row["clip"]), attack_way, "%s 공격 %d 실제 클립" % [key, begun - 1])
			observed_attacks[begun - 1] = row["clip"]
		rows.append(row)
		var actual: Basis = (p.global_basis.inverse() * (geometry["axis_node"] as Node3D).global_basis).orthonormalized()
		var down: float = rad_to_deg(Visual.grip_down_angle(actual))
		var drawn: Color = snapshot["drawn"]
		var baked: Dictionary = snapshot["baked"]
		if frame == 0 and body != "":
			assert_ne(visual.worn[body], visual.worn[""], body + " 기본 몸으로 대체되지 않은 실제 몸")
		var weight: float = Visual.drawn_wrist_weight(baked["clips"], snapshot["frames"], drawn)
		if weight > 0.0:
			active_peak = maxf(active_peak, down)
		var recovery: bool = _recovery_row(row)
		if recovery:
			recovery_samples += 1
			if float(row["kept_share"]) > 0.0:
				var target: int = int(visual.notes[p].get("recover_walk_to", -1))
				var source: int = int(visual.notes[p].get("recover_walk_from", -1))
				if walking and target >= 0 and source >= 0 and target < baked["clips"].size() and source < baked["clips"].size() \
						and String(row["clip"]) == String(baked["clips"][target]["name"]) \
						and String(row["kept_clip"]) == String(baked["clips"][source]["name"]):
					assert_eq(String(row["clip"]), "p_walk_axe", key + " 무기에 맞는 실제 걷기 클립")
					if walk_blends == 0:
						print("ONEHAND_WALK_BLEND " + JSON.stringify({"body": body, "fps": fps, "rule_s": t,
							"current_clip": row["clip"], "kept_clip": row["kept_clip"], "kept_phase": row["kept_phase"],
							"kept_share": row["kept_share"], "phase": row["phase"]}))
					walk_blends += 1
				if chaining and begun > 1 and age < wind and String(row["clip"]) == attack_way:
					chain_blends += 1
		if sampled > 0 and (recovery or previous_recovery):
			var full: float = _angle(previous, actual) / (30.0 * dt)
			var axis: float = rad_to_deg(previous.z.angle_to(actual.z)) / (30.0 * dt)
			if previous_recovery and not recovery:
				recovery_exits += 1
				assert_lte(full, ROTATION_PER_30TH_DEG,
					"%s 회복을 떠나는 장 %.9f도/30분의1초 @%.9f초" % [key, full, t])
			if full > peak:
				peak = full
				peak_at = t
			peak_axis = maxf(peak_axis, axis)
		if walking and not chaining and way == "p_swing_one" and body in ["", "n10-body_duffel-m"] and t >= 1.0 - EPS and t <= 1.1 + EPS:
			var arm: Array = Visual.arm_at(baked["arm"], snapshot["frames"], drawn)
			var lean: Basis = Visual.lean_of(p, visual.notes[p])
			var before_local: Basis = (lean.transposed() * was_displayed).orthonormalized()
			var raw: Basis = Visual.grip_target(arm[0], arm[1], before_local)
			print("ONEHAND_WALK_BUDGET " + JSON.stringify({"body": body, "fps": fps, "rule_s": t,
				"phase": row["phase"], "kept_phase": row["kept_phase"], "kept_share": row["kept_share"],
				"weight": weight, "current_recovery": recovery, "previous_recovery": previous_recovery,
				"legacy_budget_deg": ROTATION_PER_30TH_DEG * 30.0 * dt if recovery else null,
				"pair_budget_deg": ROTATION_PER_30TH_DEG * 30.0 * dt if recovery or previous_recovery else null,
				"raw_target_step_deg": _angle(diagnostic_target, raw) if diagnostic_target is Basis else null,
				"target_gap_deg": _angle(before_local, raw), "full_step_deg": _angle(previous, actual),
				"full_per_30th_deg": _angle(previous, actual) / (30.0 * dt)}))
			diagnostic_target = raw
		previous = actual
		previous_recovery = recovery
		sampled += 1
		if body == "" and not walking and not chaining and t >= 0.4 - EPS and t <= 0.5 + EPS:
			var arm: Array = Visual.arm_at(baked["arm"], snapshot["frames"], drawn)
			var raw: Basis = Visual.grip_target(arm[0], arm[1], was)
			var current_lean: Basis = Visual.lean_of(p, visual.notes[p])
			var want: Basis = Visual.wrist_target(raw, weight)
			var share: float = 1.0 - exp(-dt / Visual.GRIP_TAU)
			var simple: Basis = was.slerp(want, share)
			var lo: float = minf(Visual.grip_down_angle(was), Visual.grip_down_angle(want))
			var hi: float = maxf(Visual.grip_down_angle(was), Visual.grip_down_angle(want))
			var gate: bool = Visual.grip_down_angle(simple) >= lo and Visual.grip_down_angle(simple) <= hi
			print("ONEHAND_WRIST_STEP " + JSON.stringify({"body": body, "clip": way, "fps": fps,
				"rule_s": t, "phase": drawn.r, "vat_hand": _vector(arm[0]), "vat_elbow": _vector(arm[1]),
				"raw_target": _basis(raw), "corrected_target": _basis(want), "previous_grip": _basis(was),
				"weight": weight, "legacy_branch": "slerp" if weight <= 0.0 or gate else "separate",
				"legacy_slerp_error_deg": _angle(simple, visual.notes[p]["grip"]),
				"previous_displayed_basis": _basis(was_displayed), "current_lean": _basis(current_lean),
				"compensated_previous_grip": _basis((current_lean.transposed() * was_displayed).orthonormalized()),
				"final_grip": _basis(visual.notes[p]["grip"]), "displayed_basis": _basis(actual)}))
	var events: Dictionary = probe._attack_events(rows, 0)
	assert_eq(observed_attacks.size(), attacks, key + " 실제 관측한 공격 수")
	if walking:
		assert_gt(walk_blends, 0, key + " 실제 걷기 전환의 잡아 둔 회복 장")
		assert_gt(recovery_exits, 0, key + " 잡아 둔 회복 장이 사라지는 실제 전환")
	if chaining:
		assert_gt(chain_blends, 0, key + " 실제 연타 전환의 잡아 둔 회복 장")
	var out: Dictionary = {"key": key, "events": events, "active_peak": active_peak,
		"rotation_peak": peak, "rotation_at": peak_at, "axis_peak": peak_axis, "sampled": sampled,
		"recovery_samples": recovery_samples, "walk_blends": walk_blends, "chain_blends": chain_blends, "recovery_exits": recovery_exits,
		"rotation_space": "person_body_including_lean"}
	_traces[key] = out
	visual.free()
	p.free()
	probe.free()
	return out


func _assert_rotation(trace: Dictionary) -> void:
	assert_gt(int(trace["sampled"]), 0, String(trace["key"]) + " 실제 필터 표본")
	assert_gt(int(trace["recovery_samples"]), 0, String(trace["key"]) + " 실제 회복 장")
	assert_lte(float(trace["rotation_peak"]), ROTATION_PER_30TH_DEG,
		"%s 전체 %.6f도/30분의1초 @%.6f초" % [trace["key"], trace["rotation_peak"], trace["rotation_at"]])
	assert_lte(float(trace["axis_peak"]), ROTATION_PER_30TH_DEG,
		"%s z축 %.6f도/30분의1초" % [trace["key"], trace["axis_peak"]])


func _assert_follow_event(trace: Dictionary) -> void:
	var event: Variant = trace["events"]["follow_end"]["tip"]
	assert_not_null(event, String(trace["key"]) + " 맞은 뒤 첫 끝점 높이 국소 최솟값")
	if event == null:
		return
	var down: float = float(event["weapon_down_deg"])
	assert_between(down, 30.0, 45.0, "%s 끝 사건 %.6f도 @%.6f초 위상 %.6f" % [trace["key"], down, event["rule_s"], event["phase"]])


func test_onehand_post_contact_rotation_budget() -> void:
	for way: String in ["p_swing_one", "p_swing_back"]:
		for fps: int in [30, 60]:
			for walking: bool in [false, true]:
				_assert_rotation(_trace("", way, fps, walking))
	for fps: int in [30, 60]:
		_assert_rotation(_trace("", "p_swing_one", fps, false, true))


func test_onehand_follow_end_event_points_down_30_to_45_degrees() -> void:
	for way: String in ["p_swing_one", "p_swing_back"]:
		for fps: int in [30, 60]:
			_assert_follow_event(_trace("", way, fps))


func test_all_shipped_bodies_filtered_wrist_contract() -> void:
	var folders: PackedStringArray = DirAccess.get_directories_at("res://models/people")
	folders.sort()
	var count: int = 0
	for folder: String in folders:
		if not folder.ends_with("_p"):
			continue
		count += 1
		var body: String = "" if folder == "n5-crew_seamstress_p" else folder.trim_suffix("_p")
		for way: String in ["p_swing_one", "p_swing_back"]:
			for fps: int in [30, 60]:
				var trace: Dictionary = _trace(body, way, fps)
				_assert_rotation(trace)
				_assert_rotation(_trace(body, way, fps, true))
				_assert_follow_event(trace)
				assert_lte(float(trace["active_peak"]), 48.0, "%s 보정 중 최대 %.6f도" % [trace["key"], trace["active_peak"]])
	assert_eq(count, 14, "배포된 몸 전체")
