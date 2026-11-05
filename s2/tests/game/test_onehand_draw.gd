extends GutTest
## One-hand drawing contracts, without rebuilding motions.

const Pose = preload("res://game/actors/person_pose.gd")
const Visual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const Baseline = preload("res://tests/game/test_onehand_tip_baseline.gd")


class WristField:
	var people: Array = []
	var paused: bool = false
	var ended: bool = false
	var hitstop: bool = false
	var slow: float = 1.0
	var combat: Variant = null
	var data: Dictionary = {}
	var levels: Dictionary = {}
	var ground_items: Array = []
	# The save codec reads these three to skip their own fields; this stub has none.
	var mission_play: Variant = null
	var holdout: Variant = null
	var train_guard: Variant = null

	func level_of(_point: Vector3) -> int:
		return 0


func _person() -> Person:
	var p: Person = Person.new()
	add_child_autofree(p)
	p.setup("onehand_draw", "Onehand", "companion", Vector3.ZERO)
	p.hands = [{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.strike_kind = "swing"
	p.strike_at = {}
	return p


func _clips() -> Array:
	return [{"name": "p_stand", "length": 2.5}, {"name": "p_walk", "round": 1.64},
		{"name": "p_swing_one", "length": 1.0}, {"name": "p_swing_back", "length": 1.0}]


func _table() -> Array:
	return [[0, 2, true], [2, 8, true], [10, 24, false], [34, 24, false]]


func _same_basis(a: Basis, b: Basis) -> void:
	assert_lt(a.x.distance_to(b.x), 0.000001)
	assert_lt(a.y.distance_to(b.y), 0.000001)
	assert_lt(a.z.distance_to(b.z), 0.000001)


func test_phase_contract_uses_the_exact_guard_sample() -> void:
	assert_almost_eq(Pose.SWING_GUARD_PHASE * 23.0, 18.0, 0.000000001)
	assert_almost_eq(Pose.RECOVER_ONE_END, (18.0 / 23.0 - 0.45) / 0.55, 0.000000001)
	assert_almost_eq(Pose.RECOVER_BACK_END, (18.0 / 23.0 - 0.33) / 0.67, 0.000000001)
	assert_eq(Visual.OWN_BLOWS["one"], [["p_swing_one", 0.45], ["p_swing_back", 0.33]])
	for row: Array in [[0.45, Pose.RECOVER_ONE_END], [0.33, Pose.RECOVER_BACK_END]]:
		assert_almost_eq(lerpf(row[0], 1.0, row[1]), Pose.SWING_GUARD_PHASE, 0.000000001)
	assert_almost_eq(lerpf(0.45, 1.0, Pose.RECOVER_FOLLOW), 0.62, 0.000000001)
	assert_almost_eq(lerpf(0.45, 1.0, Pose.RECOVER_SAG), 0.70, 0.000000001)


func test_recovery_schedule_knots_speed_and_monotonicity() -> void:
	for base: float in [0.25, 0.35]:
		for duration: float in [base + 0.000001, 0.5, 0.9, 2.0, 6.0]:
			for end: float in [Pose.RECOVER_ONE_END, Pose.RECOVER_BACK_END]:
				var follow: float = (0.62 - 0.45) / (18.0 / 23.0 - 0.45) * end
				var sag: float = (0.70 - 0.45) / (18.0 / 23.0 - 0.45) * end
				var knots: Array = [[0.0, 0.0], [0.17, follow], [0.50, sag], [1.0, end]]
				for knot: Array in knots:
					assert_almost_eq(Pose.recovery_phase(knot[0] * duration, duration, base, end), knot[1], 0.000000001)
				var h: float = duration * 0.0000001
				var speed: float = minf(1.0 / base, 3.0 * follow / (0.17 * duration))
				assert_almost_eq(Pose.recovery_phase(h, duration, base, end) / h, speed, 0.0001)
				assert_lt((end - Pose.recovery_phase(duration - h, duration, base, end)) / h, 0.0001)
				for ratio: float in [0.17, 0.50]:
					var at: float = ratio * duration
					var mid: float = Pose.recovery_phase(at, duration, base, end)
					var left: float = (mid - Pose.recovery_phase(at - h, duration, base, end)) / h
					var right: float = (Pose.recovery_phase(at + h, duration, base, end) - mid) / h
					assert_almost_eq(left, right, 0.0001)
				var previous: float = 0.0
				for tick: int in range(1201):
					var value: float = Pose.recovery_phase(duration * float(tick) / 1200.0, duration, base, end)
					assert_gte(value + 0.000000001, previous)
					assert_lte(value, end + 0.000000001)
					previous = value
				assert_eq(Pose.recovery_phase(-1.0, duration, base, end), 0.0)
				assert_almost_eq(Pose.recovery_phase(duration + 1.0, duration, base, end), end, 0.000000001)


func test_short_recovery_keeps_the_linear_branch() -> void:
	for base: float in [0.25, 0.35]:
		for duration: float in [0.1, base - 0.000001, base]:
			for end: float in [Pose.RECOVER_ONE_END, Pose.RECOVER_BACK_END]:
				for ratio: float in [-0.1, 0.0, 0.17, 0.5, 1.0, 1.1]:
					assert_almost_eq(Pose.recovery_phase(duration * ratio, duration, base, end), clampf(ratio, 0.0, 1.0), 0.000000001)


func test_wrist_weight_boundaries_and_shared_return_knots() -> void:
	for way: String in ["p_swing_one", "p_swing_back"]:
		var hit: float = 0.45 if way == "p_swing_one" else 0.33
		var follow: float = lerpf(hit, Pose.SWING_GUARD_PHASE, (0.62 - 0.45) / (18.0 / 23.0 - 0.45))
		var rise_end: float = lerpf(hit, follow, 0.2)
		var sag: float = lerpf(hit, Pose.SWING_GUARD_PHASE, (0.70 - 0.45) / (18.0 / 23.0 - 0.45))
		for phase: float in [0.0, hit, Pose.SWING_GUARD_PHASE, 1.0]:
			assert_eq(Visual.wrist_weight(way, phase), 0.0)
		assert_almost_eq(Visual.wrist_weight(way, follow), 1.0, 0.000001)
		assert_almost_eq(Visual.wrist_weight(way, sag), 1.0, 0.000001)
		assert_almost_eq(Visual.wrist_weight(way, (hit + rise_end) * 0.5), 0.5, 0.000001)
		assert_almost_eq(Visual.wrist_weight(way, (sag + Pose.SWING_GUARD_PHASE) * 0.5), 0.5, 0.000001)
		for edge: float in [hit, rise_end, follow, sag, Pose.SWING_GUARD_PHASE]:
			assert_lt(absf(Visual.wrist_weight(way, edge + 0.000001) - Visual.wrist_weight(way, edge - 0.000001)) / 0.000002, 0.001)
	for way: String in ["p_stab", "p_floor_strike", "p_stomp", "p_walk", "p_stand", "p_swing_axe"]:
		assert_eq(Visual.wrist_weight(way, 0.65), 0.0)


func test_wrist_rotates_local_positive_x_toward_down_without_moving_the_hand() -> void:
	for angle: float in [-65.0, -50.0, 0.0, 20.0, 38.0, 60.0]:
		var want: Basis = Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, deg_to_rad(angle))
		var correction: float = Visual.wrist_correction(want, 1.0)
		assert_almost_eq(rad_to_deg(correction), maxf(0.0, 38.0 - angle), 0.0001)
		var bent: Basis = Visual.wrist_target(want, 1.0)
		assert_almost_eq(rad_to_deg(Visual.grip_down_angle(bent)), maxf(angle, 38.0), 0.0001)
		assert_eq(Visual.wrist_correction(want, 0.0), 0.0)
		var hand: Vector3 = Vector3(-0.2, 1.0, 0.3)
		var elbow: Vector3 = hand + Vector3.UP
		var before: Vector3 = hand
		var actual: Basis = Visual.grip_of(hand, elbow, Basis(), 0.0, false, 1.0)
		assert_eq(hand, before)
		assert_almost_eq(rad_to_deg(Visual.grip_down_angle(actual)), 38.0, 0.0001)


func test_corrected_grip_is_filtered_once_and_freezes_at_zero_delta() -> void:
	var hand: Vector3 = Vector3(0.0, -0.4, 0.3)
	var elbow: Vector3 = Vector3.ZERO
	var start: Basis = Basis(Vector3.UP, 0.2)
	var target: Basis = Visual.grip_of(hand, elbow, start, 0.0, false, 1.0)
	_same_basis(Visual.grip_of(hand, elbow, start, 1.0 / 30.0, true, 1.0), start.slerp(target, 0.5))
	_same_basis(Visual.grip_of(hand, elbow, start, 0.0, true, 1.0), start)
	_same_basis(Visual.grip_of(hand, hand, start, 1.0, true, 1.0), start)
	_same_basis(Visual.grip_of(hand, elbow, start, 0.0, false), Visual.grip_target(hand, elbow, start))


func test_wrist_mix_decodes_the_kept_absolute_row_and_actual_share() -> void:
	var clips: Array = _clips()
	var tab: Array = _table()
	for kept_clip: int in [2, 3]:
		var kept_row: int = int(tab[kept_clip][0]) + 15
		var source: float = Visual.wrist_weight(String(clips[kept_clip]["name"]), 15.0 / 23.0)
		for share: int in [0, 1, 15, 31]:
			var drawn: Color = DeadBody.packed(Color(0.6, 1.0, 1.0, 1.0), 1, kept_row, share)
			assert_almost_eq(Visual.drawn_wrist_weight(clips, tab, drawn), source * float(share) / 31.0, 0.000001)
	var current: Color = DeadBody.packed(Color(0.62, 2.0, 1.0, 1.0), 2, 0, 16)
	assert_almost_eq(Visual.drawn_wrist_weight(clips, tab, current), 15.0 / 31.0, 0.000001)
	assert_eq(Visual.drawn_wrist_weight([], [], current), 0.0)


func test_guard_lowering_cut_uses_only_the_final_drawn_rows() -> void:
	var clips: Array = _clips()
	var tab: Array = _table()
	for target: int in [1, 2]:
		for age: float in [0.02, 0.20, 0.38]:
			var mix: Dictionary = {}
			Visual.mix_recovery({}, mix, Color(Pose.SWING_GUARD_PHASE, 2, 1, 1), 0.0, tab, {})
			Visual.mix_recovery({"guard_lower_mix": 2}, mix, Color(0, 0, 1, 1), 0.0, tab, {})
			var note: Dictionary = {"blow_from_guard": target == 2, "gait_pick": target == 1}
			var drawn: Color = Visual.mix_recovery(note, mix, Color(0, target, 1, 1), age, tab, {})
			assert_eq(Visual.drawn_wrist_weight(clips, tab, drawn), 0.0)


func test_two_active_clips_blend_corrections_with_upper_motion_bits() -> void:
	var clips: Array = []
	var tab: Array = []
	for i: int in 16:
		clips.append({"name": "p_stand"})
		tab.append([i * 2, 2, true])
	clips.append({"name": "p_swing_one"})
	clips.append({"name": "p_swing_back"})
	tab.append([32, 24, false])
	tab.append([56, 24, false])
	var drawn: Color = DeadBody.packed(Color(0.5, 16, 1, 1), 16, 56 + 15, 12)
	var expected: float = lerpf(Visual.wrist_weight("p_swing_one", 0.5), Visual.wrist_weight("p_swing_back", 15.0 / 23.0), 12.0 / 31.0)
	assert_almost_eq(Visual.drawn_wrist_weight(clips, tab, drawn), expected, 0.000001)


func test_hitstop_freezes_the_walking_blend_and_corrected_grip() -> void:
	var clips: Array = _clips()
	var tab: Array = _table()
	var mix: Dictionary = {}
	Visual.mix_recovery({}, mix, Color(0.65, 2, 1, 1), 0.0, tab, {})
	var note: Dictionary = {"recover_walk_mix": true, "recover_walk_from": 2, "recover_walk_to": 1}
	var look: Color = Color(0.1, 1, 1, 1)
	Visual.mix_recovery(note, mix, look, 0.0, tab, {})
	var now: float = 0.04
	var before: Color = Visual.mix_recovery(note, mix, look, now, tab, {})
	var weight: float = Visual.drawn_wrist_weight(clips, tab, before)
	assert_gt(weight, 0.0)
	var grip: Basis = Visual.grip_of(Vector3.DOWN, Vector3.ZERO, Basis(), 1.0 / 30.0, true, weight)
	var frozen: Basis = grip
	var state: Dictionary = {"paused": false, "hitstop": true, "ended": false, "slow": 1.0}
	for fps: int in [30, 60]:
		for _frame: int in fps:
			var delta: float = Visual.frame_delta(state, 1.0 / float(fps))
			now += delta
			var drawn: Color = Visual.mix_recovery(note, mix, look, now, tab, {})
			assert_eq(drawn, before)
			assert_eq(Visual.drawn_wrist_weight(clips, tab, drawn), weight)
			grip = Visual.grip_of(Vector3.DOWN, Vector3.ZERO, grip, delta, true, weight)
			_same_basis(grip, frozen)
	var resumed: Color = Visual.mix_recovery(note, mix, look, now + 1.0 / 30.0, tab, {})
	assert_lt(Visual.drawn_wrist_weight(clips, tab, resumed), weight)
	var ended: Color = Visual.mix_recovery(note, mix, look, Visual.RECOVER_WALK_MIX, tab, {})
	assert_eq(Visual.drawn_wrist_weight(clips, tab, ended), 0.0)


func test_restored_clip_precedes_recovery_and_epoch_preserves_elapsed_time() -> void:
	for way: String in ["p_swing_one", "p_swing_back"]:
		for epoch_change: bool in [false, true]:
			var p: Person = _person()
			p.set_meta(Pose.MODE, "swing")
			p.set_meta(Pose.BLOW_WAY, way)
			p.set_meta(Pose.SWING, 0.9)
			p.set_meta(Pose.RECOVER_WAIT, 0.9)
			p.swing_t = 0.45
			var note: Dictionary = {"epoch": -1, "blow_n": 0, "blow_on": true} if epoch_change else {}
			var picked: Vector2 = Visual.motion_of(p, note, 0.0, [], _clips())
			assert_eq(String(_clips()[int(picked.y)]["name"]), way)
			var hit: float = 0.45 if way == "p_swing_one" else 0.33
			assert_almost_eq(picked.x, lerpf(hit, Pose.SWING_GUARD_PHASE, (0.70 - 0.45) / (18.0 / 23.0 - 0.45)), 0.000001)
			assert_eq(float(p.get_meta(Pose.SWING)), 0.9)
			assert_almost_eq(float(note["blow_guard_phase"]), Pose.SWING_GUARD_PHASE, 0.000000001)
			p.swing_t = 0.44
			assert_gt(Visual.motion_of(p, note, 0.01, [], _clips()).x, picked.x)


func test_wrist_target_never_lifts_reversed_or_rolled_axes() -> void:
	for yaw: float in [0.0, 0.7, PI, -1.3]:
		for pitch: float in [-PI / 2.0, -1.1, 0.0, 0.4, PI / 2.0]:
			for roll: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
				var want: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
				var before: float = Visual.grip_down_angle(want)
				for weight: float in [0.0, 0.2, 0.7, 1.0]:
					var bent: Basis = Visual.wrist_target(want, weight)
					var after: float = Visual.grip_down_angle(bent)
					assert_gte(after + 0.000001, before)
					assert_almost_eq(after, before + weight * maxf(0.0, Visual.WRIST_DOWN - before), 0.000001)
	var reversed: Basis = Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD)
	assert_almost_eq(rad_to_deg(Visual.grip_down_angle(Visual.wrist_target(reversed, 1.0))), 38.0, 0.0001)


func test_shipped_post_contact_wrist_targets_never_lift() -> void:
	var folders: int = 0
	for folder: String in DirAccess.get_directories_at("res://models/people"):
		if not folder.ends_with("_p"):
			continue
		folders += 1
		var baked: Dictionary = BodyBake.load_baked("res://models/people".path_join(folder))
		var ids: Dictionary = Visual.hand_of(baked)
		assert_false(ids.is_empty(), folder)
		if ids.is_empty():
			continue
		var arm: PackedVector3Array = Visual.arm_table(baked, ids["hand"], ids["elbow"])
		var tab: Array = DeadBody.table_of(baked)
		for way: String in ["p_swing_one", "p_swing_back"]:
			var hit: float = Pose.SWING_ONE_HIT if way == "p_swing_one" else Pose.SWING_BACK_HIT
			var clip: int = Visual.clip_named(baked["clips"], way, -1)
			assert_gte(clip, 0, folder + way)
			if clip < 0:
				continue
			var packed_clip: Color = DeadBody.packed(Color(0.0, 0.0, 1.0, 1.0), clip, 0, 0.0)
			assert_eq(DeadBody.motion_in(packed_clip.g), clip, folder + way + " 상위 클립 번호")
			var steps: int = (int(tab[clip][1]) - 1) * 10
			for tick: int in range(int(ceil(hit * float(steps))), steps + 1):
				var phase: float = float(tick) / float(steps)
				var drawn: Color = Color(phase, packed_clip.g, 1, 1)
				var hand: Array = Visual.arm_at(arm, tab, drawn)
				var want: Basis = Visual.grip_target(hand[0], hand[1])
				var weight: float = Visual.drawn_wrist_weight(baked["clips"], tab, drawn)
				var bent: Basis = Visual.wrist_target(want, weight)
				var before: float = Visual.grip_down_angle(want)
				var after: float = Visual.grip_down_angle(bent)
				assert_gte(after + 0.000001, before, "%s %s %.6f" % [folder, way, phase])
				if is_equal_approx(weight, 1.0) and before <= Visual.WRIST_DOWN:
					assert_almost_eq(after, Visual.WRIST_DOWN, 0.000001)
	assert_eq(folders, 14)


func test_back_recovery_release_uses_the_settled_row() -> void:
	var returned: float = Pose.recovery_phase(0.6, 0.9, 0.35, Pose.RECOVER_BACK_END)
	var phase: float = lerpf(Pose.SWING_BACK_HIT, 1.0, returned)
	assert_eq(DeadBody.frame_in(_table(), 3, phase) - int(_table()[3][0]), 17)
	assert_almost_eq(Pose.RECOVER_FOLLOW_SHARE, (0.62 - 0.45) / (18.0 / 23.0 - 0.45), 0.000000001)
	assert_almost_eq(Pose.RECOVER_SAG_SHARE, (0.70 - 0.45) / (18.0 / 23.0 - 0.45), 0.000000001)


func test_actual_filtered_onehand_wrist_reaches_downward_range() -> void:
	for way: String in ["p_swing_one", "p_swing_back"]:
		for fps: int in [30, 60]:
			_measure_filtered_wrist(way, fps)


func _measure_filtered_wrist(way: String, fps: int) -> void:
	var p: Person = _person()
	p.set_process(false)
	p.set_physics_process(false)
	p.rotation.y = 0.4
	p._refresh_weapon_mesh()
	var field := WristField.new()
	field.people = [p]
	var visual: Visual = Visual.new()
	add_child_autofree(visual)
	visual.set_process(false)
	visual.setup(field)
	visual.body_by[p] = ""
	visual.notes[p] = {"blow_n": 0, "blow_end": 0.0} if way == "p_swing_back" else {}
	var mult: float = float(p.mults()["swing"])
	var wind: float = Pose.W.melee_windup("axe") / mult
	var wait: float = Pose.W.melee_recover(float(Pose.W.get_data("axe")["swing"]) / mult, wind, Pose.W.melee_gap("axe"))
	var dt: float = 1.0 / float(fps)
	var landed: bool = false
	var good: int = 0
	var first_good: float = -1.0
	var peak_active_down: float = -90.0
	var previous_down: float = 0.0
	var previous_axis: Vector3 = Vector3.ZERO
	var max_down_step: float = 0.0
	var max_axis_step: float = 0.0
	var probe: Baseline = Baseline.new()
	var geometry: Dictionary = probe._tip_geometry(p)
	var event_rows: Array[Dictionary] = []
	p.strike_total = wind
	for frame: int in range(int(ceil((wind + wait) * float(fps))) + 1):
		var t: float = float(frame) * dt
		if t < wind - 0.000001:
			p.strike_t = wind - t
			p.swing_t = p.strike_t
		else:
			p.strike_t = 0.0
			p.swing_t = maxf(0.0, wait - (t - wind))
			if not landed:
				p.set_meta(Pose.SWING, wait)
				landed = true
		visual._process(dt if frame > 0 else 0.0)
		var snapshot: Dictionary = Visual.drawn_snapshot(visual, p)
		assert_false(snapshot.is_empty(), way)
		if snapshot.is_empty():
			probe.free()
			return
		var drawn: Color = snapshot["drawn"]
		var row: Dictionary = probe._sample(p, visual, geometry, way)
		assert_false(row.is_empty(), "%s %d %.6f초 끝 사건 표본" % [way, fps, t])
		if not row.is_empty():
			row.merge({"rule_s": t, "hit_s": wind, "attack": 0, "attack_clip": way}, true)
			event_rows.append(row)
		var baked: Dictionary = snapshot["baked"]
		var clip: int = DeadBody.motion_in(drawn.g)
		assert_eq(String(baked["clips"][clip]["name"]), way)
		var weight: float = Visual.drawn_wrist_weight(baked["clips"], snapshot["frames"], drawn)
		var axis_node: Node3D = p.weapon_model if p.weapon_model != null else p.weapon_mesh
		var actual: Basis = p.global_basis.inverse() * axis_node.global_basis
		var down: float = rad_to_deg(Visual.grip_down_angle(actual))
		var axis: Vector3 = actual.z.normalized()
		# Report the 0.4-to-0.5-second turn, without adding a speed threshold.
		if frame > 0 and t > 0.4 + 0.000001 and t <= 0.5 + 0.000001:
			max_down_step = maxf(max_down_step, absf(down - previous_down) * float(fps) / 30.0)
			max_axis_step = maxf(max_axis_step, rad_to_deg(acos(clampf(axis.dot(previous_axis), -1.0, 1.0))) * float(fps) / 30.0)
		previous_down = down
		previous_axis = axis
		if weight > 0.0:
			peak_active_down = maxf(peak_active_down, down)
			assert_lte(down, 45.0 + 3.0, "%s %d at %.6f phase %.6f" % [way, fps, t, drawn.r])
		if weight < 1.0 - 0.000001:
			continue
		if down >= 30.0 and down <= 45.0:
			good += 1
			if first_good < 0.0:
				first_good = t
	assert_gt(good, 0, "%s %d filtered plateau" % [way, fps])
	var event: Variant = probe._attack_events(event_rows, 0)["follow_end"]["tip"]
	assert_not_null(event, "%s %d 끝점 높이의 첫 국소 최솟값" % [way, fps])
	if event != null:
		assert_between(float(event["weapon_down_deg"]), 30.0, 45.0,
			"%s %d 끝 사건 %.6f도 @%.6f초 위상 %.6f" % [way, fps, event["weapon_down_deg"], event["rule_s"], event["phase"]])
	probe.free()
	var delay: float = first_good - (wind + Pose.RECOVER_FOLLOW_TIME * wait)
	if first_good >= 0.0:
		assert_lte(delay, 4.0 * Visual.GRIP_TAU + dt)
	print("ONEHAND_WRIST_SETTLE " + JSON.stringify({"clip": way, "fps": fps, "good_frames": good, "delay_s": delay, "allowed_delay_s": 4.0 * Visual.GRIP_TAU + dt, "max_active_down_deg": peak_active_down, "max_down_step_per_30th_deg": max_down_step, "max_axis_step_per_30th_deg": max_axis_step}))


func test_active_wrist_filter_stays_between_endpoint_elevations() -> void:
	var start: Basis = Basis(Vector3.RIGHT, deg_to_rad(38.0))
	var reversed: Basis = Basis(Vector3.RIGHT, deg_to_rad(142.0))
	# Both endpoints look down 38 degrees; their shortest rotation passes through down.
	assert_gt(rad_to_deg(Visual.grip_down_angle(start.slerp(reversed, 0.5))), 48.0)
	assert_almost_eq(Visual.grip_down_angle(Visual.wrist_follow(start, reversed, 0.5)), deg_to_rad(38.0), 0.000001)
	_same_basis(Visual.wrist_follow(start, reversed, 0.0), start)
	_same_basis(Visual.wrist_follow(start, reversed, 1.0), reversed)
	for from_deg: float in [-70.0, 0.0, 38.0]:
		for to_deg: float in [-20.0, 20.0, 38.0]:
			for yaw: float in [0.0, PI / 2.0, PI]:
				for roll: float in [0.0, PI / 2.0, PI]:
					var was: Basis = Basis(Vector3.RIGHT, deg_to_rad(from_deg))
					var want: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(to_deg)) * Basis(Vector3.BACK, roll)
					for share: float in [0.0, 0.1, 0.5, 0.9, 1.0]:
						var filtered: Basis = Visual.wrist_follow(was, want, share)
						assert_between(Visual.grip_down_angle(filtered), deg_to_rad(minf(from_deg, to_deg)) - 0.000001, deg_to_rad(maxf(from_deg, to_deg)) + 0.000001)


func test_wrist_correction_requires_a_held_onehand_melee_weapon() -> void:
	var p: Person = _person()
	for wid: String in ["", "pistol", "pipe_shotgun", "shotgun", "unknown_weapon"]:
		p.hands = [] if wid == "" else [{"id": wid, "quality": "factory", "condition": 1.0, "loaded": 0}]
		assert_eq(Visual.wrist_for_weapon(p, 1.0), 0.0, wid + " 보정 없음")
	for wid: String in ["axe", "knife", "frying_pan", "broken_bottle", "wood_stake"]:
		p.hands = [{"id": wid, "quality": "factory", "condition": 1.0, "loaded": 0}]
		assert_eq(Visual.wrist_for_weapon(p, 0.7), 0.7, wid + " 한 손 휘두르기")
	assert_eq(String(Visual.OWN_WORK["window"][0]), "p_swing_one")
	assert_eq(String(Visual.OWN_BLOWS["stab"][1][0]), "p_swing_one")


func test_wrist_rotation_budget_uses_current_and_held_recovery_rows() -> void:
	var clips: Array = _clips()
	var tab: Array = _table()
	assert_false(Visual.drawn_wrist_recovery(clips, tab, Color(0.4, 2, 1, 1)))
	assert_true(Visual.drawn_wrist_recovery(clips, tab, Color(0.45, 2, 1, 1)))
	assert_true(Visual.drawn_wrist_recovery(clips, tab, Color(0.33, 3, 1, 1)))
	for target: int in [0, 1, 2, 3]:
		var held_guard: int = int(tab[2][0]) + 18
		var drawn: Color = DeadBody.packed(Color(0.1, target, 1, 1), target, held_guard, 1)
		assert_true(Visual.drawn_wrist_recovery(clips, tab, drawn), "잡아 둔 가드 장이 남은 섞기")
		assert_false(Visual.drawn_wrist_recovery(clips, tab, Color(0.1, target, 1, 1)), "잡아 둔 장이 사라진 뒤")
	assert_false(Visual.drawn_wrist_recovery([], [], Color()))


func test_wrist_recovery_exit_budget_survives_pause_and_expires_after_one_step() -> void:
	for fps: int in [30, 60]:
		var p: Person = _person()
		p.set_process(false)
		p.set_physics_process(false)
		p._refresh_weapon_mesh()
		var field := WristField.new()
		field.people = [p]
		var visual: Visual = Visual.new()
		add_child(visual)
		visual.set_process(false)
		visual.setup(field)
		visual.body_by[p] = ""
		visual._process(0.0)
		var snapshot: Dictionary = Visual.drawn_snapshot(visual, p)
		assert_false(snapshot.is_empty(), "전환 뒤 표시 준비")
		if snapshot.is_empty():
			visual.free()
			continue
		var baked: Dictionary = snapshot["baked"]
		assert_false(Visual.drawn_wrist_recovery(baked["clips"], snapshot["frames"], snapshot["drawn"]), "현재 장에는 회복이 없음")
		var hand: Array = Visual.arm_at(baked["arm"], snapshot["frames"], snapshot["drawn"])
		var lean: Basis = Visual.lean_of(p, visual.notes[p])
		var target: Basis = Visual.grip_of(hand[0], hand[1], Basis(), 0.0, false)
		var before: Basis = (Basis(Vector3.UP, deg_to_rad(170.0)) * lean * target).orthonormalized()
		p.weapon_mesh.basis = before
		visual.notes[p]["grip"] = (lean.transposed() * before).orthonormalized()
		visual.notes[p]["wrist_recovery"] = true
		var dt: float = 1.0 / float(fps)
		field.paused = true
		visual._process(dt)
		_same_basis(p.weapon_mesh.basis.orthonormalized(), before)
		assert_true(bool(visual.notes[p].get("wrist_recovery", false)), "정지 중에는 전환 예산을 소비하지 않음")
		field.paused = false
		field.hitstop = true
		visual._process(dt)
		_same_basis(p.weapon_mesh.basis.orthonormalized(), before)
		assert_true(bool(visual.notes[p].get("wrist_recovery", false)), "맞힘 정지도 전환 예산 보존")
		field.hitstop = false
		visual._process(0.0)
		assert_true(bool(visual.notes[p].get("wrist_recovery", false)), "0초 그리기도 전환 예산 보존")
		visual._process(dt)
		var after: Basis = p.weapon_mesh.basis.orthonormalized()
		var turn: float = rad_to_deg(before.get_rotation_quaternion().angle_to(after.get_rotation_quaternion())) / (30.0 * dt)
		assert_lte(turn, 45.0, "%d 회복을 떠나는 장 %.9f도/30분의1초" % [fps, turn])
		assert_false(bool(visual.notes[p].get("wrist_recovery", true)), "시간이 진행된 전환 한 장 뒤 해제")
		# Reset only the orientation: a later ordinary frame must use its normal filter.
		lean = Visual.lean_of(p, visual.notes[p])
		p.weapon_mesh.basis = before
		visual.notes[p]["grip"] = (lean.transposed() * before).orthonormalized()
		visual._process(dt)
		after = p.weapon_mesh.basis.orthonormalized()
		turn = rad_to_deg(before.get_rotation_quaternion().angle_to(after.get_rotation_quaternion())) / (30.0 * dt)
		assert_gt(turn, 45.0, "%d 일반 장까지 회전 제한이 남지 않음" % fps)
		visual.notes[p]["wrist_recovery"] = true
		p.motion_epoch += 1
		visual._process(0.0)
		assert_false(bool(visual.notes[p].get("wrist_recovery", true)), "복원 epoch에서 옛 전환 상태 제거")
		visual.free()


func test_saved_recovery_first_draw_keeps_weapon_orientation() -> void:
	for way: String in ["p_swing_one", "p_swing_back"]:
		for fps: int in [30, 60]:
			_measure_restored_wrist(way, fps)


func _measure_restored_wrist(way: String, fps: int) -> void:
	var p: Person = _person()
	p.set_process(false)
	p.set_physics_process(false)
	p._refresh_weapon_mesh()
	var field := WristField.new()
	field.people = [p]
	var visual: Visual = Visual.new()
	add_child(visual)
	visual.set_process(false)
	visual.setup(field)
	visual.body_by[p] = ""
	visual.notes[p] = {"blow_n": 0, "blow_end": 0.0} if way == "p_swing_back" else {}
	var wind: float = Pose.W.melee_windup("axe") / float(p.mults()["swing"])
	var dt: float = 1.0 / float(fps)
	var wait: float = 0.9
	p.strike_total = wind
	p.set_meta(Pose.RECOVER_WAIT, wait)
	var landed: bool = false
	var saved_count: int = 0
	for frame: int in range(int(ceil((wind + 0.6) * fps)) + 1):
		var t: float = float(frame) * dt
		p.strike_t = maxf(0.0, wind - t)
		p.swing_t = p.strike_t if t < wind else wait - (t - wind)
		if t >= wind and not landed:
			p.set_meta(Pose.SWING, wait)
			landed = true
		visual._process(dt if frame > 0 else 0.0)
		var elapsed: float = t - wind
		var checkpoints: Array[float] = [0.05, 0.2, 0.45]
		if saved_count >= checkpoints.size() or elapsed + 0.000001 < checkpoints[saved_count]:
			continue
		saved_count += 1
		# A person row uses the save codec, without pretending it is a whole field envelope.
		var packed: String = JSON.stringify(FieldSave._encode(FieldSave._person(field, p)), "", false, true)
		var decoded: Variant = FieldSave.decode_checked(JSON.parse_string(packed))
		assert_true(decoded is Dictionary, "사람 저장 행의 형식 왕복")
		if not decoded is Dictionary:
			continue
		var saved: Dictionary = decoded
		var q: Person = _person()
		q.set_process(false)
		q.set_physics_process(false)
		var restored_field := WristField.new()
		restored_field.people = [q]
		FieldSave._put_person(q, saved)
		FieldSave._restore_properties(restored_field, q, saved["state"])
		FieldSave._restore_properties(restored_field, q.aim, saved["aim"])
		for key: String in FieldSave.PERSON_META:
			if saved["meta"].has(key):
				q.set_meta(key, FieldSave._thaw(restored_field, saved["meta"][key]))
		q._refresh_weapon_mesh()
		q.motion_epoch += 1
		var restored: Visual = Visual.new()
		add_child(restored)
		restored.set_process(false)
		restored.setup(restored_field)
		restored.body_by[q] = ""
		restored.notes[q] = {"epoch": q.motion_epoch - 1, "grip": Basis(Vector3.UP, 1.0)}
		restored._process(0.0)
		assert_true(bool(restored.notes[q].get("wrist_replay_used", false)), "첫 표시 전에 회복 이력 재생")
		assert_eq(String(restored.notes[q].get("wrist_replay_error", "")), "", "회복 이력 재생 오류 없음")
		var a: Basis = p.weapon_mesh.basis.orthonormalized()
		var b: Basis = q.weapon_mesh.basis.orthonormalized()
		var full: float = rad_to_deg(a.get_rotation_quaternion().angle_to(b.get_rotation_quaternion()))
		var axis: float = rad_to_deg(a.z.angle_to(b.z))
		var label: String = "%s %d 복원 첫 장 @%.6f초 경과 %.6f초" % [way, fps, t, elapsed]
		assert_lte(full, 1.0, label + " 전체 %.6f도" % full)
		assert_lte(axis, 1.0, label + " z축 %.6f도" % axis)
		print("ONEHAND_WRIST_RESTORE " + JSON.stringify({"clip": way, "fps": fps, "rule_s": t,
			"elapsed_s": elapsed, "full_error_deg": full, "axis_error_deg": axis,
			"history_replayed": restored.notes[q].get("wrist_replay_used", false),
			"replay_tick": restored.notes[q].get("wrist_replay", {}).get("tick", -1)}))
		restored.free()
		q.free()
	assert_eq(saved_count, 3, "%s %d 복원 표본 수" % [way, fps])
	visual.free()


func _replay_fixture() -> Dictionary:
	return {"arm": PackedVector3Array([Vector3(0.1, 0.4, 0.2), Vector3(0.0, 0.8, 0.0),
		Vector3(-0.1, 0.7, 0.4), Vector3(0.0, 0.8, 0.0)]), "tab": [[0, 2, false]],
		"clock": {"wind": 0.3, "duration": 0.9, "base": 0.35, "hit": Pose.SWING_ONE_HIT,
			"end": Pose.RECOVER_ONE_END, "aim": 0.1}}


func test_onehand_replay_is_independent_of_display_rate_and_cache() -> void:
	var f: Dictionary = _replay_fixture()
	for fps: int in [30, 60]:
		var cache: Dictionary = {}
		for frame: int in range(int(roundf(0.8 * fps)) + 1):
			var age: float = float(frame) / float(fps)
			var live: Dictionary = Visual.onehand_replay_at(f["arm"], f["tab"], 0, f["clock"], age, cache)
			assert_true(bool(live["valid"]), "재생 중 유효한 이력")
			if not bool(live["valid"]):
				return
			assert_lte(int(live["steps"]), int(ceil(Visual.WRIST_REPLAY_HZ / float(fps))) + 1, "지난 구간을 다시 돌리지 않는 증분 계산")
			if frame > 0:
				assert_false(bool(live["rebuilt"]), "같은 재생에서는 캐시 재사용")
			var cold: Dictionary = Visual.onehand_replay_at(f["arm"], f["tab"], 0, f["clock"], age, {})
			assert_true(bool(cold["valid"]))
			_same_basis(live["grip"], cold["grip"])
		var stopped: Dictionary = cache.duplicate(true)
		var again: Dictionary = Visual.onehand_replay_at(f["arm"], f["tab"], 0, f["clock"], 0.8, cache)
		assert_eq(int(again["steps"]), 0, "같은 시각에는 필터 시간을 다시 진행하지 않음")
		assert_eq(cache, stopped)
		var rewind: Dictionary = Visual.onehand_replay_at(f["arm"], f["tab"], 0, f["clock"], 0.35, cache)
		var fresh: Dictionary = Visual.onehand_replay_at(f["arm"], f["tab"], 0, f["clock"], 0.35, {})
		assert_true(bool(rewind["rebuilt"]), "되감기는 이력을 다시 세움")
		_same_basis(rewind["grip"], fresh["grip"])


func test_onehand_replay_rejects_invalid_data_and_bounds_its_work() -> void:
	var f: Dictionary = _replay_fixture()
	for age: float in [-1.0, NAN, INF, 1e30]:
		var cache: Dictionary = {}
		var result: Dictionary = Visual.onehand_replay_at(f["arm"], f["tab"], 0, f["clock"], age, cache)
		assert_false(bool(result["valid"]), "잘못된 시각 거부")
		assert_true(cache.is_empty(), "실패한 계산은 캐시에 기록하지 않음")
	for key: String in ["wind", "duration", "base", "hit", "end", "aim"]:
		var bad: Dictionary = f["clock"].duplicate()
		bad[key] = NAN
		assert_false(bool(Visual.onehand_replay_at(f["arm"], f["tab"], 0, bad, 0.4, {})["valid"]))
	assert_false(bool(Visual.onehand_replay_at(PackedVector3Array(), f["tab"], 0, f["clock"], 0.4, {})["valid"]))
	assert_false(bool(Visual.onehand_replay_at(f["arm"], [], 0, f["clock"], 0.4, {})["valid"]))
	assert_false(bool(Visual.onehand_replay_at(f["arm"], [[NAN, 2, false]], 0, f["clock"], 0.4, {})["valid"]))
	var bad_arm: PackedVector3Array = f["arm"].duplicate()
	bad_arm[0] = Vector3(NAN, 0.0, 0.0)
	assert_false(bool(Visual.onehand_replay_at(bad_arm, f["tab"], 0, f["clock"], 0.4, {})["valid"]))
	var long_clock: Dictionary = f["clock"].duplicate()
	long_clock["duration"] = 100.0
	var over: Dictionary = Visual.onehand_replay_at(f["arm"], f["tab"], 0, long_clock,
		float(Visual.WRIST_REPLAY_MAX_STEPS + 1) / Visual.WRIST_REPLAY_HZ, {})
	assert_false(bool(over["valid"]))
	assert_eq(String(over["reason"]), "replay_work_limit")
	var cache: Dictionary = {}
	Visual.onehand_replay_at(f["arm"], f["tab"], 0, f["clock"], 0.4, cache)
	cache["basis"] = "invalid"
	var rebuilt: Dictionary = Visual.onehand_replay_at(f["arm"], f["tab"], 0, f["clock"], 0.4, cache)
	assert_true(bool(rebuilt["valid"]))
	assert_true(bool(rebuilt["rebuilt"]), "오염된 캐시는 재생성")


func test_wrist_lead_catches_the_recorded_follow_end_without_overshoot() -> void:
	# Recorded VAT samples and the previous displayed basis, before this change.
	var cases: Array = JSON.parse_string('[{"fps":30,"start":[[0.973831176757813,0.209967106580734,-0.0869867652654648],[-0.225660711526871,0.847792983055115,-0.479921251535416],[-0.0270209070295095,0.486991763114929,0.872988522052765]],"frames":[{"time":0.4,"hand":[0.159301355481148,1.05535709857941,0.657069563865662],"elbow":[-0.0173732582479715,1.09043109416962,0.452447980642319]},{"time":0.433333333333333,"hand":[0.141222149133682,1.07716071605682,0.650147914886475],"elbow":[-0.0328066870570183,1.08960723876953,0.438831120729446]}]},{"fps":60,"start":[[0.960184693336487,0.259260833263397,-0.104063779115677],[-0.279148072004318,0.905101776123047,-0.32072901725769],[0.0110358372330666,0.33700829744339,0.941437005996704]],"frames":[{"time":0.4,"hand":[0.159301355481148,1.05535709857941,0.657069563865662],"elbow":[-0.0173732582479715,1.09043109416962,0.452447980642319]},{"time":0.416666666666667,"hand":[0.149802714586258,1.06681251525879,0.65343302488327],"elbow":[-0.0254818312823772,1.08999824523926,0.445293813943863]},{"time":0.433333333333333,"hand":[0.141222149133682,1.07716071605682,0.650147914886475],"elbow":[-0.0328066870570183,1.08960723876953,0.438831120729446]}]}]')
	for sample: Dictionary in cases:
		var fps: int = int(sample["fps"])
		var start: Array = sample["start"]
		var grip: Basis = Basis(_fixture_vector(start[0]), _fixture_vector(start[1]), _fixture_vector(start[2])).orthonormalized()
		var ordinary: Basis = grip
		for frame: Dictionary in sample["frames"]:
			var before: Basis = grip
			ordinary = Visual.grip_of(_fixture_vector(frame["hand"]), _fixture_vector(frame["elbow"]),
				ordinary, 1.0 / float(fps), true, 1.0, deg_to_rad(45.0) * 30.0 / float(fps))
			grip = Visual.grip_of(_fixture_vector(frame["hand"]), _fixture_vector(frame["elbow"]),
				grip, 1.0 / float(fps), true, 1.0, deg_to_rad(45.0) * 30.0 / float(fps), 1.0)
			var turn: float = rad_to_deg(before.get_rotation_quaternion().angle_to(grip.get_rotation_quaternion())) * float(fps) / 30.0
			var down: float = rad_to_deg(Visual.grip_down_angle(grip))
			assert_lte(turn, 45.0, "%d %.6f초 전체 회전 %.6f도" % [fps, frame["time"], turn])
			assert_lte(down, 48.0, "%d %.6f초 아래 각 %.6f도" % [fps, frame["time"], down])
		var final_down: float = rad_to_deg(Visual.grip_down_angle(grip))
		var old_down: float = rad_to_deg(Visual.grip_down_angle(ordinary))
		assert_almost_eq(old_down, 21.12898 if fps == 30 else 17.29728, 0.01, "수정 전 로그의 방향과 같은 입력 재현")
		assert_lt(old_down, 30.0, "선행 보상이 없으면 끝 사건 목표에 못 미치는 대조군")
		assert_between(final_down, 30.0, 45.0, "%d 끝 사건 표본 %.6f도" % [fps, final_down])
		print("ONEHAND_WRIST_LEAD_CHECK " + JSON.stringify({"fps": fps, "end_s": 0.433333333333333,
			"without_lead_deg": old_down, "down_deg": final_down}))
	var was: Basis = Basis(Vector3.RIGHT, deg_to_rad(38.0))
	var hand: Vector3 = Vector3(0.0, cos(deg_to_rad(38.0)), -sin(deg_to_rad(38.0)))
	var zero: Basis = Visual.grip_of(hand, Vector3.ZERO, was, 1.0 / 30.0, true, 0.0, INF, 1.0)
	var tiny: Basis = Visual.grip_of(hand, Vector3.ZERO, was, 1.0 / 30.0, true, 1e-9, INF, 1.0)
	assert_lte(rad_to_deg(zero.get_rotation_quaternion().angle_to(tiny.get_rotation_quaternion())), 0.1, "선행 보상에서도 가중치 0 연속성")


func _fixture_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func test_onehand_replay_reads_upper_clip_bits() -> void:
	var f: Dictionary = _replay_fixture()
	var arm := PackedVector3Array([Vector3.DOWN, Vector3.ZERO, Vector3.DOWN, Vector3.ZERO])
	arm.append_array(f["arm"])
	var tab: Array = []
	for _clip: int in range(27):
		tab.append([0, 2, false])
	tab[26] = [2, 2, false]
	var high: Dictionary = Visual.onehand_replay_at(arm, tab, 26, f["clock"], 0.45, {})
	var direct: Dictionary = Visual.onehand_replay_at(f["arm"], f["tab"], 0, f["clock"], 0.45, {})
	assert_true(bool(high["valid"]))
	assert_true(bool(direct["valid"]))
	_same_basis(high["grip"], direct["grip"])
