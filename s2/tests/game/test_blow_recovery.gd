extends GutTest
## Rule clocks and the shipped VAT, without rebuilding any motion.

const Person = preload("res://game/actors/person.gd")
const Visual = preload("res://game/actors/person_visual.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const W = preload("res://game/sim/weapons.gd")
const Motion = preload("res://game/sim/motion.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const Source = preload("res://tests/game/test_person_motion_source.gd")
const FieldGame = preload("res://game/field_game.gd")
const PEOPLE: String = "res://models/people"
const WEAPONS: Array[String] = ["knife", "crowbar", "axe", "frying_pan", "broken_bottle", "wood_stake"]


func _person(wid: String) -> Person:
	var p: Person = Person.new()
	add_child_autofree(p)
	p.setup("recovery", "Recovery", "companion", Vector3.ZERO)
	p.hands = [{"id": wid, "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.strike_kind = "swing"
	p.strike_at = {}
	return p


func _own() -> Array:
	return [{"name": "p_stand", "length": 2.5}, {"name": "p_walk", "round": 1.64},
		{"name": "p_swing_one", "length": 1.0}, {"name": "p_swing_back", "length": 1.0},
		{"name": "p_stab", "length": 1.0}]


func _begin(p: Person, own: Array, note: Dictionary, rest: float) -> void:
	p.strike_total = W.melee_windup(p.weapon_id()) / float(p.mults()["swing"])
	p.strike_t = p.strike_total
	Visual.blow_of(p, own, note)
	p.strike_t = 0.0
	p.swing_t = rest
	Visual.blow_of(p, own, note)


func _wait(p: Person) -> float:
	var wid: String = p.weapon_id()
	var m: float = float(p.mults()["swing"])
	return W.melee_recover(float(W.get_data(wid)["swing"]) / m, W.melee_windup(wid) / m, W.melee_gap(wid))


func test_rule_times_and_contact_phases_are_unchanged() -> void:
	var expected: Array = [[0.10, 0.50, 0.60], [0.18, 0.67, 0.85], [0.30, 0.90, 1.20],
		[0.18, 0.62, 0.80], [0.08, 0.42, 0.50], [0.12, 0.53, 0.65]]
	for i: int in WEAPONS.size():
		var wid: String = WEAPONS[i]
		var d: Dictionary = W.get_data(wid)
		var row: Dictionary = Motion.swing_row(wid)
		assert_almost_eq(W.melee_windup(wid), float(expected[i][0]), 0.000001, wid)
		for m: float in [1.0, 0.5, 0.15]:
			var wind: float = W.melee_windup(wid) / m
			var wait: float = W.melee_recover(float(d["swing"]) / m, wind, W.melee_gap(wid))
			assert_almost_eq(wait, maxf(float(d["swing"]) / m - wind, 0.2) + W.melee_gap(wid), 0.000001)
			if is_equal_approx(m, 1.0):
				assert_almost_eq(wait, float(expected[i][1]), 0.000001)
				assert_almost_eq(wind + wait, float(expected[i][2]), 0.000001)
		assert_almost_eq(float(row["hit"]), W.melee_windup(wid), 0.000001)
		assert_eq(row["feet"], Vector2(float(d["feet_from"]) * float(d["swing"]), float(d["swing"])))
	assert_eq(Visual.OWN_BLOWS["one"], [["p_swing_one", 0.45], ["p_swing_back", 0.33]])
	assert_eq(Visual.OWN_BLOWS["stab"], [["p_stab", 0.35], ["p_swing_one", 0.45]])


func test_recovery_deadline_and_ally_cap_at_both_rates() -> void:
	for fps: int in [30, 60]:
		for wid: String in WEAPONS:
			for extra: float in [0.0, 2.0]:
				var p: Person = _person(wid)
				var wait: float = _wait(p)
				for way: String in ["p_swing_one", "p_swing_back"]:
					p.set_meta(Pose.BLOW_WAY, way)
					p.set_meta(Pose.MODE, "swing")
					p.set_meta(Pose.SWING, wait + extra)
					p.swing_t = wait + extra
					var elapsed: float = 0.0
					# Frame steps summed to the wait land a rounding hair either side of it;
					# the picture must hold up to just before the wait, and be gone at it.
					while elapsed < wait - 0.000001:
						p.swing_t = wait + extra - elapsed
						assert_false(Pose.swing_state(p).is_empty(), "%s %s %d" % [wid, way, fps])
						elapsed = minf(wait, elapsed + 1.0 / float(fps))
					p.swing_t = extra
					assert_true(Pose.swing_state(p).is_empty(), "ends at the player wait")
					assert_almost_eq(p.swing_t, extra, 0.000001, "picture cannot consume ally rest")


func test_follow_through_speed_join_and_slow_stop() -> void:
	for wid: String in WEAPONS:
		var base: float = Pose.recover_seconds(wid)
		var join: float = base * Pose.RECOVER_FOLLOW
		for duration: float in [base, 0.9, 6.0]:
			for fps: int in [30, 60]:
				var t: float = 0.0
				while t <= join:
					assert_almost_eq(Pose.recovery_phase(t, duration, base), t / base, 0.000001)
					t += 1.0 / float(fps)
			var h: float = 0.000001
			var left: float = (Pose.recovery_phase(join, duration, base) - Pose.recovery_phase(join - h, duration, base)) / h
			var right: float = (Pose.recovery_phase(join + h, duration, base) - Pose.recovery_phase(join, duration, base)) / h
			assert_almost_eq(left, right, 0.001, "continuous speed at the join")
			assert_almost_eq(Pose.recovery_phase(duration, duration, base), 1.0, 0.000001)
			if duration > base:
				assert_lt((1.0 - Pose.recovery_phase(duration - h, duration, base)) / h, 0.001)


func test_short_miss_stab_floor_and_stomp_keep_old_recovery() -> void:
	var p: Person = _person("axe")
	for mode: String in ["swing", "floor", "stomp"]:
		for way: String in ["p_stab", "p_swing_axe", "p_chop_side", "p_swing_one"]:
			p.set_meta(Pose.MODE, mode)
			p.set_meta(Pose.BLOW_WAY, way)
			assert_almost_eq(Pose.recovery_duration(p, W.WHIFF_RECOVER), W.WHIFF_RECOVER, 0.000001)
			if mode != "swing" or way != "p_swing_one":
				assert_almost_eq(Pose.recovery_duration(p, 3.0), Pose.recover_seconds("axe"), 0.000001)


func test_movement_releases_only_after_feet_and_does_not_restart_recovery() -> void:
	for fps: int in [30, 60]:
		var p: Person = _person("axe")
		var note: Dictionary = {}
		var own: Array = _own()
		var wait: float = _wait(p)
		_begin(p, own, note, wait)
		p.set_meta(Pose.RECOVER_RELEASE, 0.6)
		p.moving = true
		p.swing_t = wait - 0.59
		var picked: Vector2 = Visual.motion_of(p, note, 1.0 / float(fps), [], own)
		assert_eq(String(own[int(picked.y)]["name"]), "p_swing_one")
		p.swing_t = wait - 0.61
		p.brain["step_r"] = 0.37
		picked = Visual.motion_of(p, note, 1.0 / float(fps), [], own)
		assert_eq(String(own[int(picked.y)]["name"]), "p_walk")
		assert_true(bool(note.get("recover_walk_mix", false)))
		# The footsteps stay where the rules have them (field_game.gd steps_in): the
		# walk drawn after the ease is at that round, and the picture leaves it alone.
		assert_almost_eq(picked.x, 0.37, 0.000001, "the walk drawn after the ease is at the footstep round")
		assert_almost_eq(float(p.brain["step_r"]), 0.37, 0.000001, "the picture does not move the footsteps")
		p.moving = false
		assert_lt(Visual.blow_of(p, own, note).y, 0.0, "stopping cannot restore the cancelled picture")
	assert_between(Visual.RECOVER_WALK_MIX, 0.10, 0.15)


func test_hitstop_keeps_recovery_and_mix_clocks_still() -> void:
	for fps: int in [30, 60]:
		var p: Person = _person("axe")
		var own: Array = _own()
		var note: Dictionary = {}
		var wait: float = _wait(p)
		_begin(p, own, note, wait)
		p.swing_t = wait * 0.4
		var before: Vector2 = Visual.motion_of(p, note, 0.0, [], own)
		var state: Dictionary = {"paused": false, "hitstop": true, "ended": false, "slow": 1.0}
		var t: float = float(note["t"])
		for frame: int in fps:
			var delta: float = Visual.frame_delta(state, 1.0 / float(fps))
			assert_eq(delta, 0.0, str(frame))
			assert_eq(Visual.motion_of(p, note, delta, [], own), before)
		assert_eq(float(note["t"]), t)


## Decode the actual packed shader mix, including its frozen source frame.
func _drawn_points(baked: Dictionary, ids: PackedInt32Array, drawn: Color) -> PackedVector3Array:
	var arrays: Array = (baked["mesh"] as Mesh).surface_get_arrays(0)
	var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var look: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var tab: Array = DeadBody.table_of(baked)
	var clip: int = DeadBody.motion_in(drawn.g)
	var count: int = int(tab[clip][1])
	var first: int = int(tab[clip][0])
	var loops: bool = bool(tab[clip][2])
	var at: float = fposmod(drawn.r, 1.0) * float(count) if loops else clampf(drawn.r, 0.0, 1.0) * float(count - 1)
	var a: int = int(at)
	var b: int = (a + 1) % count if loops else mini(a + 1, count - 1)
	var packed: float = fposmod(roundf(drawn.g), Visual.VatBaker.UPPER)
	var share: float = floorf(packed / 65536.0)
	var kept: int = int(floorf((packed - share * 65536.0) / 16.0))
	var out: PackedVector3Array = PackedVector3Array()
	for id: int in ids:
		var point: Vector3 = Visual.vertex_at(baked, rest, look, id, first + a).lerp(Visual.vertex_at(baked, rest, look, id, first + b), at - float(a))
		if share > 0.0:
			point = point.lerp(Visual.vertex_at(baked, rest, look, id, kept), share / DeadBody.MIX_STEPS)
		out.append(point)
	return out


## How far the planted soles slide while an ease into the walk runs: the eased-from
## frame is held while the body moves off with the real start (field_game.gd
## _drive: from MOVE_MIN, up by WALK over INERTIA["now"][0] a second, unloaded).
## Returns [the worst slide in metres, how many planted samples were measured].
func _start_slip(baked: Dictionary, feet: PackedInt32Array, tab: Array, from: Color, walk: int, round_m: float, phase: float, fps: int, from_blow: bool) -> Array:
	var mix: Dictionary = {}
	DeadBody.mix_from(mix, from, 0.0, tab)
	var note: Dictionary = {"recover_walk_mix": from_blow}
	var walk_mix: float = Visual.RECOVER_WALK_MIX if from_blow else float(Visual.OWN_MIX.get("p_walk", Visual.OWN_MIX_TIME))
	var times: Dictionary = {walk: float(Visual.OWN_MIX.get("p_walk", Visual.OWN_MIX_TIME))}
	var start_s: float = float(FieldGame.INERTIA["now"][0])
	var dt: float = 1.0 / float(fps)
	var start: PackedVector3Array = PackedVector3Array()
	var touched: int = 0
	var worst: float = 0.0
	var t: float = 0.0
	var speed: float = 0.0
	var distance: float = 0.0
	while true:
		var look: Color = Color(phase + distance / round_m, walk, 1.0, 1.0)
		var drawn: Color = Visual.mix_recovery(note, mix, look, t, tab, times)
		assert_almost_eq(float(mix["body_mix"]), walk_mix, 0.000001)
		var points: PackedVector3Array = _drawn_points(baked, feet, drawn)
		if start.is_empty():
			start = points.duplicate()
		for i: int in points.size():
			if start[i].y <= 0.02 and points[i].y <= 0.02:
				touched += 1
				var drift: Vector3 = points[i] + Vector3(0.0, 0.0, distance) - start[i]
				drift.y = 0.0
				worst = maxf(worst, drift.length())
		if t >= walk_mix:
			break
		speed = minf(Person.WALK, maxf(Person.MOVE_MIN, speed + Person.WALK / start_s * dt))
		distance += speed * dt
		t = minf(walk_mix, t + dt)
	return [worst, touched]


## The ease out of the blow into the walk holds the frame it left, as every change
## of motion does now, so the soles slide while the body moves off. It must slide
## no more than starting to walk from standing does on the same body: compared
## at the best and at the worst start in the walk round, at both frame rates.
func test_shipped_vat_blow_to_walk_slides_no_more_than_a_standing_start() -> void:
	var source: Source = Source.new()
	add_child_autofree(source)
	var folders: int = 0
	var released: float = Pose.recovery_phase(0.6, 0.9, 0.35)
	for folder: String in DirAccess.get_directories_at(PEOPLE):
		if not folder.ends_with("_p"):
			continue
		folders += 1
		var baked: Dictionary = BodyBake.load_baked(PEOPLE.path_join(folder))
		assert_false(baked.is_empty(), folder)
		if baked.is_empty():
			continue
		var arrays: Array = (baked["mesh"] as Mesh).surface_get_arrays(0)
		var fixture: Dictionary = {"name": folder, "baked": baked, "rest": arrays[Mesh.ARRAY_VERTEX], "look": arrays[Mesh.ARRAY_TEX_UV2]}
		var feet: PackedInt32Array = source._walk_feet(fixture)
		assert_eq(feet.size(), 40, folder)
		var own: Array = baked["clips"]
		var tab: Array = DeadBody.table_of(baked)
		var stand: int = Visual.clip_named(own, "p_stand", -1)
		assert_gte(stand, 0, folder + " p_stand")
		for gait: String in ["p_walk", "p_walk_axe"]:
			var walk: int = Visual.clip_named(own, gait, -1)
			assert_gte(walk, 0, folder + gait)
			if walk < 0 or stand < 0:
				continue
			var round_m: float = float(own[walk]["round"])
			for way: String in ["p_swing_one", "p_swing_back"]:
				var swing: int = Visual.clip_named(own, way, -1)
				assert_gte(swing, 0, folder + way)
				if swing < 0:
					continue
				var lands: float = 0.45 if way == "p_swing_one" else 0.33
				var from_blow: Color = Color(lerpf(lands, 1.0, released), swing, 1.0, 1.0)
				for fps: int in [30, 60]:
					var blow_best: float = INF
					var blow_worst: float = 0.0
					var stand_best: float = INF
					var stand_worst: float = 0.0
					# Sixteen starts round the walk: the best start of some bodies falls between eighths.
					for k: int in 16:
						var phase: float = float(k) / 16.0
						var b: Array = _start_slip(baked, feet, tab, from_blow, walk, round_m, phase, fps, true)
						var s: Array = _start_slip(baked, feet, tab, Color(0.0, stand, 1.0, 1.0), walk, round_m, phase, fps, false)
						assert_gt(int(b[1]), 0, "must measure planted vertices")
						assert_gt(int(s[1]), 0, "must measure planted vertices")
						blow_best = minf(blow_best, float(b[0]))
						blow_worst = maxf(blow_worst, float(b[0]))
						stand_best = minf(stand_best, float(s[0]))
						stand_worst = maxf(stand_worst, float(s[0]))
					var label: String = "%s %s %s %d" % [folder, way, gait, fps]
					assert_lte(blow_best, stand_best + 0.001, label + " best start")
					assert_lte(blow_worst, stand_worst + 0.001, label + " worst start")
					if fps == 30:
						print("RECOVER_SLIP %s blow %.1f/%.1f cm stand %.1f/%.1f cm" % [label, blow_best * 100.0, blow_worst * 100.0, stand_best * 100.0, stand_worst * 100.0])
	assert_eq(folders, 14, "every shipped living body")


func test_shipped_vat_next_blow_starts_from_the_last_pose() -> void:
	var folders: int = 0
	for folder: String in DirAccess.get_directories_at(PEOPLE):
		if not folder.ends_with("_p"):
			continue
		folders += 1
		var baked: Dictionary = BodyBake.load_baked(PEOPLE.path_join(folder))
		assert_false(baked.is_empty(), folder)
		if baked.is_empty():
			continue
		var ids: PackedInt32Array = PackedInt32Array()
		for id: int in int(baked["vertices"]):
			ids.append(id)
		var own: Array = baked["clips"]
		var tab: Array = DeadBody.table_of(baked)
		for pair: Array in [["p_swing_one", "p_swing_back"], ["p_swing_back", "p_swing_one"], ["p_swing_one", "p_stab"]]:
			var first: int = Visual.clip_named(own, String(pair[0]), -1)
			var next: int = Visual.clip_named(own, String(pair[1]), -1)
			assert_gte(first, 0)
			assert_gte(next, 0)
			if first < 0 or next < 0:
				continue
			for fps: int in [30, 60]:
				var r: float = lerpf(0.45 if String(pair[0]) == "p_swing_one" else 0.33, 1.0, Pose.recovery_phase(0.9 - 1.0 / float(fps), 0.9, 0.35))
				var mix: Dictionary = {}
				var before: Color = DeadBody.mix_from(mix, Color(r, first, 1.0, 1.0), 0.0, tab)
				var after: Color = Visual.mix_recovery({}, mix, Color(0.0, next, 1.0, 1.0), 1.0 / float(fps), tab, {next: float(Visual.OWN_MIX[String(pair[1])])})
				var a: PackedVector3Array = _drawn_points(baked, ids, before)
				var b: PackedVector3Array = _drawn_points(baked, ids, after)
				var jump: float = 0.0
				for id: int in ids.size():
					jump = maxf(jump, a[id].distance_to(b[id]))
				assert_lte(jump, 0.02, "%s %s %d jump %.6f m" % [folder, str(pair), fps, jump])
	assert_eq(folders, 14)
