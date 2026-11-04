extends GutTest
## The measurement helpers also run against the baseline.

const Person = preload("res://game/actors/person.gd")
const Visual = preload("res://game/actors/person_visual.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const W = preload("res://game/sim/weapons.gd")
const PEOPLE: String = "res://models/people"
# person.gd _refresh_weapon_mesh: axe box length is 0.75 m.
const AXE_LENGTH: float = 0.75
const START_GAP: float = 38.0 / 30.0
const STILL_SPEED: float = 0.05


## blended false leaves out the kept frame: the clip alone at the same place.
func _drawn_points(baked: Dictionary, ids: PackedInt32Array, drawn: Color, blended: bool = true) -> PackedVector3Array:
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
		if blended and share > 0.0:
			point = point.lerp(Visual.vertex_at(baked, rest, look, id, kept), share / DeadBody.MIX_STEPS)
		out.append(point)
	return out


func _tip(points: PackedVector3Array, hands: int) -> Vector3:
	var hand: Vector3 = _center(points, 0, hands)
	var elbow: Vector3 = _center(points, hands, points.size() - hands)
	return hand + (hand - elbow).normalized() * AXE_LENGTH


func _center(points: PackedVector3Array, first: int, count: int) -> Vector3:
	var center: Vector3 = Vector3.ZERO
	for i: int in range(first, first + count):
		center += points[i]
	return center / float(count)


## Uses motion_of -> blow_of -> swing_state and the renderer's mix_recovery.
## The person is freed here, not by autofree: another test may hold this one without running it.
func measure_chain(baked: Dictionary, fps: int, wid: String = "axe", first_n: int = -1) -> Dictionary:
	var p: Person = Person.new()
	add_child(p)
	var measured: Dictionary = _measure_chain_on(p, baked, fps, wid, first_n)
	remove_child(p)
	p.free()
	return measured


func _measure_chain_on(p: Person, baked: Dictionary, fps: int, wid: String, first_n: int) -> Dictionary:
	p.setup("chain", "Chain", "companion", Vector3.ZERO)
	p.hands = [{"id": wid, "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.strike_kind = "swing"
	p.strike_at = {}
	var own: Array = baked["clips"]
	var tab: Array = DeadBody.table_of(baked)
	var arm: Dictionary = Visual.hand_of(baked)
	if arm.is_empty():
		return {}
	var ids: PackedInt32Array = arm["hand"].duplicate()
	var hands: int = ids.size()
	ids.append_array(arm["elbow"])
	var times: Dictionary = {}
	for i: int in own.size():
		times[i] = float(Visual.OWN_MIX.get(String(own[i]["name"]), Visual.OWN_MIX_TIME))
	var mult: float = float(p.mults()["swing"])
	var wind: float = W.melee_windup(wid) / mult
	var wait: float = maxf(float(W.get_data(wid)["swing"]) / mult - wind, 0.2) + W.melee_gap(wid)
	var gap: float = maxf(START_GAP, wind + wait + 2.0 / 30.0)
	var dt: float = 1.0 / float(fps)
	var stride: int = maxi(1, int(roundf(float(fps) / 30.0)))
	var note: Dictionary = {"blow_n": first_n, "blow_end": 0.0} if first_n >= 0 else {}
	var mix: Dictionary = {}
	var tips: PackedVector3Array = PackedVector3Array()
	# The tip of the clip alone at the same place, without the kept frame.
	var alone: PackedVector3Array = PackedVector3Array()
	var frames: Array[Color] = []
	var ways: Array[int] = []
	var starts: Array[int] = []
	var quiet: float = 0.0
	var max_quiet: float = 0.0
	var jump: float = 0.0
	var blend_jump: float = 0.0
	var next_attack: int = 0
	var began: float = 0.0
	var count: int = int(ceil((2.0 * gap + wind + 0.2) * float(fps)))
	for frame: int in range(count + 1):
		var t: float = float(frame) * dt
		if next_attack < 3 and t + 0.000000001 >= float(next_attack) * gap:
			began = t
			starts.append(frame)
			p.strike_total = wind
			next_attack += 1
		var age: float = t - began
		if age < wind - 0.000000001:
			p.strike_t = maxf(0.000000001, wind - age)
			p.swing_t = p.strike_t
		else:
			p.strike_t = 0.0
			p.swing_t = maxf(0.0, wait - (age - wind))
		var picked: Vector2 = Visual.motion_of(p, note, dt if frame > 0 else 0.0, [], own)
		if picked.y < 0.0 or int(picked.y) >= own.size():
			return {}
		var drawn: Color = Visual.mix_recovery(note, mix, Color(picked.x, picked.y, 1.0, 1.0), float(note["t"]), tab, times)
		frames.append(drawn)
		ways.append(int(picked.y))
		tips.append(_tip(_drawn_points(baked, ids, drawn), hands))
		alone.append(_tip(_drawn_points(baked, ids, drawn, false), hands))
		if frame > 0:
			var between_hits: bool = t > wind and t <= 2.0 * gap + wind
			var speed: float = tips[frame].distance_to(tips[frame - 1]) / dt
			quiet = quiet + dt if between_hits and speed < STILL_SPEED else 0.0
			max_quiet = maxf(max_quiet, quiet)
		if starts.size() > 1 and frame >= stride:
			var since: int = frame - starts[-1]
			if since == 0:
				jump = maxf(jump, tips[frame].distance_to(tips[frame - stride]))
			# From the first drawing of the new blow on: how much faster the ease makes the tip
			# move than the swing alone would, not the swing, which is fast by design.
			if since >= stride and float(since) * dt <= 0.15 + dt:
				var extra: float = tips[frame].distance_to(tips[frame - stride]) - alone[frame].distance_to(alone[frame - stride])
				blend_jump = maxf(blend_jump, extra)
	return {"quiet": max_quiet, "jump": jump, "blend_jump": blend_jump,
		"frames": frames, "ways": ways, "starts": starts, "tips": tips}


func _measure_all(check_limits: bool) -> void:
	var folders: int = 0
	for folder: String in DirAccess.get_directories_at(PEOPLE):
		if not folder.ends_with("_p"):
			continue
		folders += 1
		var baked: Dictionary = BodyBake.load_baked(PEOPLE.path_join(folder))
		assert_false(baked.is_empty(), folder)
		if baked.is_empty():
			continue
		var line: String = "CHAIN_METRICS " + folder
		for fps: int in [30, 60]:
			var measured: Dictionary = measure_chain(baked, fps)
			assert_false(measured.is_empty(), folder)
			if measured.is_empty():
				continue
			var label: String = "%s %dfps" % [folder, fps]
			if check_limits:
				assert_lte(float(measured["quiet"]), 0.15 + 0.000001, label + " still seconds")
				assert_lte(float(measured["jump"]), 0.15, label + " transition per 1/30 second")
				# blend_jump is reported only: an ease that holds the last frame must catch the
				# swing up, so it adds speed as every motion change does on main; inertial
				# easing (its own job) is what removes that.
				var own: Array = baked["clips"]
				var ways: Array[int] = measured["ways"]
				var starts: Array[int] = measured["starts"]
				assert_eq(starts.size(), 3, label)
				for i: int in starts.size():
					assert_eq(String(own[ways[starts[i]]]["name"]), "p_swing_back" if i == 1 else "p_swing_one", label)
			line += " %dfps quiet=%.4fs jump=%.4fm blend=%.4fm" % [fps, measured["quiet"], measured["jump"], measured["blend_jump"]]
		print(line)
	assert_eq(folders, 14)


func test_report_main_chain_metrics() -> void:
	_measure_all(false)


func test_shipped_hatchet_chain_has_no_freeze_or_transition_jump() -> void:
	_measure_all(true)

