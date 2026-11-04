extends GutTest
## One-hand drawing contracts, without rebuilding motions.

const Pose = preload("res://game/actors/person_pose.gd")
const Visual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")


class WristField:
	var people: Array = []
	var paused: bool = false
	var ended: bool = false
	var hitstop: bool = false
	var slow: float = 1.0
	var combat: Variant = null


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
		var sag: float = lerpf(hit, Pose.SWING_GUARD_PHASE, (0.70 - 0.45) / (18.0 / 23.0 - 0.45))
		for phase: float in [0.0, hit, Pose.SWING_GUARD_PHASE, 1.0]:
			assert_eq(Visual.wrist_weight(way, phase), 0.0)
		assert_almost_eq(Visual.wrist_weight(way, follow), 1.0, 0.000001)
		assert_almost_eq(Visual.wrist_weight(way, sag), 1.0, 0.000001)
		assert_almost_eq(Visual.wrist_weight(way, (hit + follow) * 0.5), 0.5, 0.000001)
		assert_almost_eq(Visual.wrist_weight(way, (sag + Pose.SWING_GUARD_PHASE) * 0.5), 0.5, 0.000001)
		for edge: float in [hit, follow, sag, Pose.SWING_GUARD_PHASE]:
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
			var steps: int = (int(tab[clip][1]) - 1) * 10
			for tick: int in range(int(ceil(hit * float(steps))), steps + 1):
				var phase: float = float(tick) / float(steps)
				var drawn: Color = Color(phase, clip, 1, 1)
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
			return
		var drawn: Color = snapshot["drawn"]
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
