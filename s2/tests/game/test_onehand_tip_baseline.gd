extends GutTest
## 실제 표시 변환과 최종 VAT 장을 읽는 기준값 측정기.

const Person = preload("res://game/actors/person.gd")
const Visual = preload("res://game/actors/person_visual.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const W = preload("res://game/sim/weapons.gd")
const START_GAP: float = 38.0 / 30.0
const STILL_SPEED: float = 0.05
const GUARD_PHASE: float = 18.0 / 23.0
const ARRIVAL_RADIUS_M: float = 0.02
const HAND_MOTION_MIN_M: float = 0.05
const HAND_TIP_ALLOWANCE_M: float = 0.05
const HAND_ORIGIN_LIMIT_M: float = 1.0  # across the ground from the feet
const HAND_HEIGHT_MIN_M: float = -0.1
const HAND_HEIGHT_MAX_M: float = 2.4
const EPS: float = 0.000001
const ORIGIN: Vector3 = Vector3(2.0, 0.0, 3.0)


class BaselineField:

	var people: Array = []
	var paused: bool = false
	var ended: bool = false
	var hitstop: bool = false
	var slow: float = 1.0
	var combat: Variant = null


func test_actual_hatchet_tip_baseline_at_30_and_60_fps() -> void:
	for scene: String in ["single_air", "chain_three", "move_after_hit"]:
		for fps: int in [30, 60]:
			_measure(scene, fps)


func test_measurement_gate_rejects_static_walk_and_wrong_space() -> void:
	var rows: Array[Dictionary] = []
	for index: int in range(2):
		var hand := Vector3(float(index) * 0.1, 0.8, 0.2)
		rows.append({"attack": 0, "attack_start_s": 0.0, "rule_s": float(index) * 0.1,
			"rule_wind_s": 0.3, "rule_wait_s": 0.9, "clip": "p_swing_one",
			"hand_body": _vector(hand), "hand_world": _vector(ORIGIN + hand),
			"tip_world": _vector(ORIGIN + hand + Vector3(0.0, 0.0, 0.3)),
			"person_origin_world": _vector(ORIGIN)})
	assert_true(bool(_measurement_checks(rows, 0.4, "single_air")["valid"]), "유효한 작은 움직임 대조군")
	var broken: Array[Dictionary] = rows.duplicate(true)
	for row: Dictionary in broken:
		row["clip"] = "p_walk"
		row["hand_world"] = [-0.3744, 0.7776, 0.2922]
		row["hand_body"] = [-1.13, 0.78, -3.42]
	var checks: Dictionary = _measurement_checks(broken, 0.4, "single_air")
	assert_false(bool(checks["valid"]), "기본 장과 잘못된 손 공간은 출력 차단")
	assert_eq(int(checks["attacks"][0]["drawn_attack_frames"]), 0, "공격 장 없음 검출")
	assert_eq(float(checks["attacks"][0]["max_hand_motion_m"]), 0.0, "손 움직임 없음 검출")
	assert_eq(int(checks["hand_tip_outside_frames"]), 2, "모든 잘못된 손과 끝 거리 검출")
	assert_eq(int(checks["hand_origin_outside_frames"]), 2, "모든 잘못된 원점 거리 검출")
	var far: Array[Dictionary] = rows.duplicate(true)
	for row: Dictionary in far:
		var far_hand: Vector3 = _point(row, "hand_body") + Vector3(1.2, 0.0, 0.0)
		row["hand_body"] = _vector(far_hand)
		row["hand_world"] = _vector(ORIGIN + far_hand)
		row["tip_world"] = _vector(ORIGIN + far_hand + Vector3(0.0, 0.0, 0.3))
	checks = _measurement_checks(far, 0.4, "single_air")
	assert_false(bool(checks["valid"]), "원점에서 바닥 방향 거리만 초과해도 출력 차단")
	assert_eq(String(checks["failure_code"]), "F-MEASUREMENT-INVALID")
	var raised: Array[Dictionary] = rows.duplicate(true)
	for row: Dictionary in raised:
		var up_hand: Vector3 = _point(row, "hand_body") + Vector3(0.0, 1.1, 0.0)
		row["hand_body"] = _vector(up_hand)
		row["hand_world"] = _vector(ORIGIN + up_hand)
		row["tip_world"] = _vector(ORIGIN + up_hand + Vector3(0.0, 0.0, 0.3))
	assert_true(bool(_measurement_checks(raised, 0.4, "single_air")["valid"]), "머리 위로 든 손은 유효")
	var too_high: Array[Dictionary] = rows.duplicate(true)
	for row: Dictionary in too_high:
		var high_hand: Vector3 = _point(row, "hand_body") + Vector3(0.0, 3.0, 0.0)
		row["hand_body"] = _vector(high_hand)
		row["hand_world"] = _vector(ORIGIN + high_hand)
		row["tip_world"] = _vector(ORIGIN + high_hand + Vector3(0.0, 0.0, 0.3))
	checks = _measurement_checks(too_high, 0.4, "single_air")
	assert_false(bool(checks["valid"]), "높이만 범위를 벗어나도 출력 차단")
	assert_eq(int(checks["hand_origin_outside_frames"]), 2, "높이 초과 장 수")
	assert_eq(int(checks["hand_tip_outside_frames"]), 0, "손과 끝 거리는 정상인 음성 대조")
	assert_lte(float(checks["max_hand_origin_distance_m"]), HAND_ORIGIN_LIMIT_M, "바닥 방향 거리는 정상인 음성 대조")


func _measure(scene: String, fps: int) -> void:
	var p: Person = Person.new()
	add_child(p)
	p.setup("onehand_tip_baseline", "기준값", "companion", ORIGIN)
	p.set_process(false)
	p.set_physics_process(false)
	p.rotation.y = 0.4
	p.hands = [{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.strike_kind = "swing"
	p.strike_at = {}
	p._refresh_weapon_mesh()
	var field := BaselineField.new()
	field.people = [p]
	var visual: Visual = Visual.new()
	add_child(visual)
	visual.set_process(false)
	visual.setup(field)
	# 기본 몸 한 벌을 고정해 이름에 따른 배역 선택을 배제한다.
	visual.body_by[p] = ""
	var geometry: Dictionary = _tip_geometry(p)
	var valid: bool = visual.draw != null and visual.own_draw != null
	valid = valid and visual.own_vat.has("arm") and not geometry.is_empty()
	if valid:
		valid = is_finite(float(geometry["weapon_length_m"])) and float(geometry["weapon_length_m"]) > 0.0
	assert_true(valid, "%s %dfps 실제 몸과 무기 자료" % [scene, fps])
	if valid:
		var rows: Array[Dictionary] = _run_scene(p, visual, geometry, scene, fps)
		if not rows.is_empty():
			var checks: Dictionary = _measurement_checks(rows, float(geometry["weapon_length_m"]), scene)
			if _assert_measurement(checks, "%s %dfps" % [scene, fps]):
				for row: Dictionary in rows:
					print("ONEHAND_TIP_FRAME " + JSON.stringify(row))
				var summary: Dictionary = _summarize(rows, geometry, scene, fps)
				summary["measurement_checks"] = checks
				print("ONEHAND_TIP_BASELINE " + JSON.stringify(summary))
				_check_existing_limits(summary)
			else:
				print("ONEHAND_TIP_MEASUREMENT_ERROR " + JSON.stringify({
					"scene": scene, "fps": fps, "failure_code": checks["failure_code"],
					"blocked_reason": "측정기 자체 검사 실패", "checks": checks
				}))
	else:
		print("ONEHAND_TIP_MEASUREMENT_ERROR " + JSON.stringify({
			"scene": scene, "fps": fps, "status": "not_measured",
			"failure_code": "F-INPUT-MISSING", "blocked_reason": "몸 VAT 또는 표시 무기 끝점 없음"
		}))
	visual.free()
	p.free()


func _mesh_nodes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		out.append_array(_mesh_nodes(child))
	return out


func _tip_geometry(p: Person) -> Dictionary:
	if p.weapon_model == null:
		if not p.weapon_mesh.mesh is BoxMesh:
			return {}
		var box: BoxMesh = p.weapon_mesh.mesh as BoxMesh
		return {
			"node": p.weapon_mesh, "axis_node": p.weapon_mesh,
			"local": Vector3(0.0, 0.0, box.size.z * 0.5),
			"tip_source": "box_positive_z_half_length",
			"weapon_length_m": box.size.z * p.weapon_mesh.global_basis.z.length(),
			"mesh_path": str(p.weapon_mesh.get_path())
		}
	var root: Node3D = p.weapon_model
	var inverse: Transform3D = root.global_transform.affine_inverse()
	var best: Dictionary = {}
	var farthest_z: float = -INF
	var nearest_z: float = INF
	var high: Vector3 = Vector3(-INF, -INF, -INF)
	var low: Vector3 = Vector3(INF, INF, INF)
	var has_bounds: bool = false
	for node: MeshInstance3D in _mesh_nodes(root):
		if node.mesh == null or not node.is_visible_in_tree():
			continue
		var to_model: Transform3D = inverse * node.global_transform
		var bounds: AABB = node.mesh.get_aabb()
		for corner: int in range(8):
			var point: Vector3 = to_model * bounds.get_endpoint(corner)
			low = low.min(point)
			high = high.max(point)
			has_bounds = true
		for surface: int in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			if arrays.is_empty() or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: int in vertices.size():
				var model_point: Vector3 = to_model * vertices[vertex]
				nearest_z = minf(nearest_z, model_point.z)
				if model_point.z > farthest_z:
					farthest_z = model_point.z
					best = {
						"node": node, "axis_node": root, "local": vertices[vertex],
						"tip_source": "model_vertex_max_z", "surface": surface,
						"vertex": vertex, "mesh_path": str(node.get_path())
					}
	if not best.is_empty():
		best["weapon_length_m"] = (farthest_z - nearest_z) * root.global_basis.z.length()
		return best
	if not has_bounds:
		return {}
	return {
		"node": root, "axis_node": root,
		"local": Vector3((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, high.z),
		"tip_source": "model_aabb_positive_z_end",
		"weapon_length_m": (high.z - low.z) * root.global_basis.z.length(),
		"mesh_path": str(root.get_path())
	}


func _run_scene(p: Person, visual: Visual, geometry: Dictionary, scene: String, fps: int) -> Array[Dictionary]:
	var mult: float = float(p.mults()["swing"])
	var wind: float = W.melee_windup("axe") / mult
	var wait: float = maxf(float(W.get_data("axe")["swing"]) / mult - wind, 0.2) + W.melee_gap("axe")
	var gap: float = maxf(START_GAP, wind + wait + 2.0 / 30.0)
	var attacks: int = 3 if scene == "chain_three" else 1
	var duration: float = ceilf((2.0 * gap + wind + wait + Visual.RECOVER_GUARD_HOLD + Visual.RECOVER_GUARD_LOWER + 0.25) * 30.0) / 30.0
	var request_s: float = wind + 1.0 / 30.0
	var feet_release_s: float = wind + (float(W.get_data("axe")["swing"]) - W.melee_windup("axe")) / mult
	var move_s: float = maxf(request_s, feet_release_s)
	var direction: Vector3 = p.global_basis.z.normalized()
	var rows: Array[Dictionary] = []
	var begun: int = 0
	var landed: bool = false
	var dt: float = 1.0 / float(fps)
	for frame: int in range(int(roundf(duration * fps)) + 1):
		var t: float = float(frame) / float(fps)
		if begun < attacks and t + EPS >= float(begun) * gap:
			begun += 1
			landed = false
			p.strike_total = wind
		var start: float = float(begun - 1) * gap
		var age: float = t - start
		if age < wind - EPS:
			p.strike_t = maxf(0.000000001, wind - age)
			p.swing_t = p.strike_t
		else:
			p.strike_t = 0.0
			p.swing_t = maxf(0.0, wait - (age - wind))
			if not landed:
				# 규칙의 맞음 시각을 보존해 첫 회복 표본의 프레임 반올림을 없앤다.
				p.set_meta(Pose.SWING, wait)
				landed = true
		var requested: bool = scene == "move_after_hit" and t + EPS >= request_s
		p.moving = requested and t + EPS >= move_s
		if scene == "move_after_hit":
			p.position = ORIGIN + direction * maxf(0.0, t - move_s)
		visual._process(dt if frame > 0 else 0.0)
		var attack_clip: String = "p_swing_back" if begun == 2 else "p_swing_one"
		var row: Dictionary = _sample(p, visual, geometry, attack_clip)
		if row.is_empty():
			fail_test("%s %dfps 최종 표시 장 없음" % [scene, fps])
			print("ONEHAND_TIP_MEASUREMENT_ERROR " + JSON.stringify({
				"scene": scene, "fps": fps, "status": "not_measured", "failure_code": "F-INPUT-MISSING",
				"blocked_reason": "최종 표시 장 또는 가드·서기 기준 장 없음", "rule_s": t
			}))
			return []
		row.merge({
			"scene": scene, "fps": fps, "frame": frame, "rule_s": t,
			"attack": begun - 1, "attack_start_s": start, "hit_s": start + wind,
			"attack_clip": attack_clip, "rule_wind_s": wind, "rule_wait_s": wait,
			"rule_gap_s": gap, "duration_s": duration,
			"move_requested": requested, "moving": p.moving,
			"movement_input_s": request_s if scene == "move_after_hit" else null,
			"movement_release_s": move_s if scene == "move_after_hit" else null
		})
		rows.append(row)
	return rows


func _sample(p: Person, visual: Visual, geometry: Dictionary, attack_clip: String) -> Dictionary:
	var snapshot: Dictionary = Visual.drawn_snapshot(visual, p)
	if snapshot.is_empty() or not bool(snapshot["own"]):
		return {}
	var drawn: Color = snapshot["drawn"]
	var clip: int = DeadBody.motion_in(drawn.g)
	var baked: Dictionary = snapshot["baked"]
	var clips: Array = baked["clips"]
	var guard_clip: int = Visual.clip_named(clips, attack_clip, -1)
	var stand_clip: int = Visual.clip_named(clips, "p_stand", -1)
	if clip < 0 or clip >= clips.size() or guard_clip < 0 or stand_clip < 0:
		return {}
	var body_at: Transform3D = snapshot["world_transform"]
	var body_inverse: Transform3D = p.global_transform.affine_inverse()
	var arm: Array = Visual.arm_at(baked["arm"], snapshot["frames"], drawn)
	var hand_world: Vector3 = body_at * (arm[0] as Vector3)
	var tip_node: Node3D = geometry["node"]
	var axis_node: Node3D = geometry["axis_node"]
	var tip_world: Vector3 = tip_node.global_transform * (geometry["local"] as Vector3)
	var hand_body: Vector3 = body_inverse * hand_world
	var tip_body: Vector3 = body_inverse * tip_world
	var axis_world: Vector3 = axis_node.global_basis.z.normalized()
	var axis_body: Vector3 = (body_inverse.basis * axis_world).normalized()
	var packed: float = fposmod(floorf(drawn.g + 0.5), Visual.VatBaker.UPPER)
	var share: float = floorf(packed / 65536.0)
	var kept: int = int(floorf((packed - share * 65536.0) / 16.0))
	var guard_frame: int = int(clips[guard_clip]["start"]) + int(roundf(GUARD_PHASE * (int(clips[guard_clip]["frames"]) - 1)))
	var arm_table: PackedVector3Array = baked["arm"]
	var stand_frame: int = int(clips[stand_clip]["start"])
	var stand_ref: float = arm_table[stand_frame * 2].y
	var guard_hand: Vector3 = arm_table[guard_frame * 2]
	var guard_grip: Basis = Visual.grip_of(guard_hand, arm_table[guard_frame * 2 + 1], Basis(), 0.0, false)
	# 기준 자세만 필터가 수렴한 방향을 쓴다. 측정 끝점은 표시 노드에서만 읽는다.
	var tip_in_weapon: Vector3 = p.weapon_mesh.global_transform.affine_inverse() * tip_world
	var guard_hand_world: Vector3 = body_at * guard_hand
	var guard_tip_world: Vector3 = body_at * (guard_hand + guard_grip * tip_in_weapon)
	var down: float = rad_to_deg(atan2(-axis_body.y, Vector2(axis_body.x, axis_body.z).length()))
	return {
		"body": Visual.OWN_FOLDER, "clip": String(clips[clip]["name"]), "phase": drawn.r,
		"drawn": [drawn.r, drawn.g, drawn.b, drawn.a],
		"drawn_source": "completed_cpu_mix_snapshot",
		"visual_s": snapshot["visual_s"], "kept_frame": kept if share > 0.0 else null,
		"kept_clip": _clip_for_frame(clips, kept) if share > 0.0 else null,
		"kept_phase": _phase_for_frame(clips, kept) if share > 0.0 else null,
		"kept_share": share / DeadBody.MIX_STEPS, "current_share": 1.0 - share / DeadBody.MIX_STEPS,
		"hand_world": _vector(hand_world), "hand_body": _vector(hand_body),
		"person_origin_world": _vector(p.global_position),
		"hand_stand_ref_m": stand_ref, "hand_stand_delta_m": hand_body.y - stand_ref,
		"hand_stand_ref_frame": stand_frame,
		"tip_world": _vector(tip_world), "tip_body": _vector(tip_body),
		"weapon_axis_world": _vector(axis_world), "weapon_axis_body": _vector(axis_body),
		"weapon_down_deg": down, "hand_left_m": hand_body.x,
		"pelvis_world": null, "pelvis_body": null, "hand_pelvis_height_m": null,
		"pelvis_source": "unavailable_no_baked_pelvis_track",
		"tip_hand_distance_m": tip_world.distance_to(hand_world),
		"tip_source": geometry["tip_source"], "weapon_length_m": geometry["weapon_length_m"],
		"guard_phase": GUARD_PHASE, "guard_frame": guard_frame,
		"guard_hand_error_m": hand_world.distance_to(guard_hand_world),
		"guard_tip_error_m": tip_world.distance_to(guard_tip_world),
		"targets_report_only": {"down_30_to_45_deg": down >= 30.0 and down <= 45.0,
			"hand_left_of_center": hand_body.x > 0.0, "hand_below_pelvis_010_to_025_m": null,
			"hand_left_lower_quadrant": null}
	}


func _clip_for_frame(clips: Array, frame: int) -> String:
	for clip: Dictionary in clips:
		if frame >= int(clip["start"]) and frame < int(clip["start"]) + int(clip["frames"]):
			return String(clip["name"])
	return ""


func _phase_for_frame(clips: Array, frame: int) -> Variant:
	for clip: Dictionary in clips:
		var first: int = int(clip["start"])
		var count: int = int(clip["frames"])
		if frame >= first and frame < first + count:
			return float(frame - first) / float(count if bool(clip["loop"]) else maxi(count - 1, 1))
	return null


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _point(row: Dictionary, key: String) -> Vector3:
	var value: Array = row[key]
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _measurement_checks(rows: Array[Dictionary], length_m: float, scene: String) -> Dictionary:
	var finite: bool = not rows.is_empty() and is_finite(length_m) and length_m > 0.0
	var max_tip_distance: float = 0.0
	var max_origin_distance: float = 0.0
	var tip_outside: int = 0
	var origin_outside: int = 0
	var tip_at: float = 0.0
	var origin_at: float = 0.0
	for row: Dictionary in rows:
		var hand: Vector3 = _point(row, "hand_world")
		var tip: Vector3 = _point(row, "tip_world")
		var origin: Vector3 = _point(row, "person_origin_world")
		if not hand.is_finite() or not tip.is_finite() or not origin.is_finite() or not _point(row, "hand_body").is_finite():
			finite = false
			continue
		var tip_distance: float = hand.distance_to(tip)
		# The origin is at the feet, so a raised hand can be far above it: reach is
		# checked across the ground, height on its own band.
		var rel: Vector3 = hand - origin
		var origin_distance: float = Vector2(rel.x, rel.z).length()
		var height_outside: bool = rel.y < HAND_HEIGHT_MIN_M - EPS or rel.y > HAND_HEIGHT_MAX_M + EPS
		if tip_distance > max_tip_distance:
			max_tip_distance = tip_distance
			tip_at = float(row["rule_s"])
		if origin_distance > max_origin_distance:
			max_origin_distance = origin_distance
			origin_at = float(row["rule_s"])
		if tip_distance > length_m + HAND_TIP_ALLOWANCE_M + EPS:
			tip_outside += 1
		if origin_distance > HAND_ORIGIN_LIMIT_M + EPS or height_outside:
			origin_outside += 1
	var expected: Array[String] = ["p_swing_one"]
	if scene == "chain_three":
		expected = ["p_swing_one", "p_swing_back", "p_swing_one"]
	var attacks: Array[Dictionary] = []
	var attacks_valid: bool = true
	for attack: int in expected.size():
		var points: PackedVector3Array = PackedVector3Array()
		for row: Dictionary in rows:
			if int(row["attack"]) != attack or String(row["clip"]) != expected[attack]:
				continue
			var age: float = float(row["rule_s"]) - float(row["attack_start_s"])
			if age < -EPS or age > float(row["rule_wind_s"]) + float(row["rule_wait_s"]) + EPS:
				continue
			points.append(_point(row, "hand_body"))
		var motion: float = 0.0
		for first: int in points.size():
			for second: int in range(first + 1, points.size()):
				motion = maxf(motion, points[first].distance_to(points[second]))
		var attack_valid: bool = not points.is_empty() and motion > HAND_MOTION_MIN_M
		attacks_valid = attacks_valid and attack_valid
		attacks.append({"attack": attack, "expected_clip": expected[attack],
			"drawn_attack_frames": points.size(), "max_hand_motion_m": motion, "valid": attack_valid})
	var valid: bool = finite and attacks_valid and tip_outside == 0 and origin_outside == 0
	var code: Variant = null
	if not valid:
		code = "F-MEASUREMENT-INVALID"
	return {"valid": valid, "failure_code": code, "finite": finite, "attacks": attacks,
		"max_hand_tip_distance_m": max_tip_distance, "max_hand_tip_at_s": tip_at,
		"hand_tip_limit_m": length_m + HAND_TIP_ALLOWANCE_M,
		"max_hand_origin_distance_m": max_origin_distance, "max_hand_origin_at_s": origin_at,
		"hand_origin_limit_m": HAND_ORIGIN_LIMIT_M, "origin_distance_space": "world_ground_plane",
		"hand_height_band_m": [HAND_HEIGHT_MIN_M, HAND_HEIGHT_MAX_M],
		"hand_tip_outside_frames": tip_outside, "hand_origin_outside_frames": origin_outside}


func _assert_measurement(checks: Dictionary, label: String) -> bool:
	assert_true(checks["valid"] == true, label + " 측정 전체 유효")
	assert_eq(int(checks["hand_origin_outside_frames"]), 0, label + " 손 높이와 바닥 방향 거리 초과 장 없음")
	assert_true(bool(checks["finite"]), label + " 유한한 좌표")
	for attack: Dictionary in checks["attacks"]:
		var attack_label: String = label + " 공격 " + str(attack["attack"])
		assert_gt(int(attack["drawn_attack_frames"]), 0, attack_label + " 실제 공격 클립 장")
		assert_gt(float(attack["max_hand_motion_m"]), HAND_MOTION_MIN_M, attack_label + " 몸 공간 손 움직임")
	assert_lte(float(checks["max_hand_tip_distance_m"]), float(checks["hand_tip_limit_m"]) + EPS, label + " 모든 장 손과 끝 거리")
	assert_lte(float(checks["max_hand_origin_distance_m"]), HAND_ORIGIN_LIMIT_M + EPS, label + " 모든 장 손과 사람 원점 거리")
	return bool(checks["valid"])


func _stops(rows: Array[Dictionary], key: String, start_s: float, end_s: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var began: float = -1.0
	var last: float = 0.0
	for i: int in range(1, rows.size()):
		var a: float = float(rows[i - 1]["rule_s"])
		var b: float = float(rows[i]["rule_s"])
		var lo: float = maxf(a, start_s)
		var hi: float = minf(b, end_s)
		if hi <= lo:
			continue
		var speed: float = _point(rows[i], key).distance_to(_point(rows[i - 1], key)) / (b - a)
		if speed < STILL_SPEED:
			if began < 0.0:
				began = lo
			last = hi
		elif began >= 0.0:
			out.append({"start_s": began, "duration_s": last - began, "end_s": last})
			began = -1.0
	if began >= 0.0:
		out.append({"start_s": began, "duration_s": last - began, "end_s": last})
	return out


func _event(row: Dictionary) -> Dictionary:
	return {
		"rule_s": row["rule_s"], "since_hit_s": float(row["rule_s"]) - float(row["hit_s"]),
		"clip": row["clip"], "phase": row["phase"], "kept_share": row["kept_share"],
		"hand_body": row["hand_body"], "tip_body": row["tip_body"],
		"hand_world": row["hand_world"], "tip_world": row["tip_world"],
		"weapon_down_deg": row["weapon_down_deg"], "hand_left_m": row["hand_left_m"],
		"hand_pelvis_height_m": row["hand_pelvis_height_m"],
		"hand_stand_ref_m": row["hand_stand_ref_m"], "hand_stand_delta_m": row["hand_stand_delta_m"],
		"targets_report_only": row["targets_report_only"]
	}


func _attack_events(rows: Array[Dictionary], attack: int) -> Dictionary:
	var window: Array[Dictionary] = []
	var guard_started: bool = false
	var arrival: Dictionary = {"hand": null, "tip": null}
	var phase_event: Variant = null
	for row: Dictionary in rows:
		if int(row["attack"]) != attack or float(row["rule_s"]) + EPS < float(row["hit_s"]):
			continue
		if String(row["clip"]) == String(row["attack_clip"]):
			if float(row["phase"]) < GUARD_PHASE:
				window.append(row)
			if float(row["phase"]) >= GUARD_PHASE - 0.5 / 23.0:
				guard_started = true
			if float(row["phase"]) >= GUARD_PHASE and phase_event == null:
				phase_event = row["rule_s"]
		if guard_started:
			for part: String in ["hand", "tip"]:
				if arrival[part] == null and float(row["guard_" + part + "_error_m"]) <= ARRIVAL_RADIUS_M:
					arrival[part] = row["rule_s"]
	var follow: Dictionary = {"hand": null, "tip": null}
	var sag: Dictionary = {"hand": null, "tip": null}
	for part: String in ["hand", "tip"]:
		var key: String = part + "_body"
		var lowest: int = -1
		for i: int in window.size():
			var y: float = _point(window[i], key).y
			if lowest < 0 or y < _point(window[lowest], key).y - EPS:
				lowest = i
			if i == 0 or i == window.size() - 1 or follow[part] != null:
				continue
			var before: float = _point(window[i - 1], key).y
			var after: float = _point(window[i + 1], key).y
			if y < before - EPS and y <= after + EPS:
				follow[part] = _event(window[i])
		if lowest >= 0:
			sag[part] = _event(window[lowest])
			sag[part]["window_boundary"] = lowest == 0 or lowest == window.size() - 1
	return {
		"attack": attack, "follow_end": follow, "sag": sag,
		"guard_arrival_s": arrival, "guard_phase_event_s": phase_event,
		"arrival_radius_m": ARRIVAL_RADIUS_M,
		"event_status": "observed" if phase_event != null else "guard_not_observed_or_interrupted"
	}


func _summarize(rows: Array[Dictionary], geometry: Dictionary, scene: String, fps: int) -> Dictionary:
	var stride: int = int(fps / 30)
	var jump: float = 0.0
	var body_jump: float = 0.0
	var transition_jump: float = 0.0
	var max_distance: float = 0.0
	var jump_at: float = 0.0
	var observed_clips: Array[String] = []
	for i: int in rows.size():
		if i == 0 or int(rows[i]["attack"]) != int(rows[i - 1]["attack"]):
			observed_clips.append(String(rows[i]["clip"]))
		max_distance = maxf(max_distance, float(rows[i]["tip_hand_distance_m"]))
		if i < stride:
			continue
		var distance: float = _point(rows[i], "tip_world").distance_to(_point(rows[i - stride], "tip_world"))
		if distance > jump:
			jump = distance
			jump_at = float(rows[i]["rule_s"])
		body_jump = maxf(body_jump, _point(rows[i], "tip_body").distance_to(_point(rows[i - stride], "tip_body")))
		if int(rows[i]["attack"]) != int(rows[i - 1]["attack"]):
			transition_jump = maxf(transition_jump, distance)
	var duration: float = float(rows[-1]["rule_s"])
	var between: Array[Dictionary] = []
	if scene == "chain_three":
		between = _stops(rows, "tip_world", float(rows[0]["hit_s"]), float(rows[-1]["hit_s"]))
	var max_stop: float = 0.0
	for stop: Dictionary in between:
		max_stop = maxf(max_stop, float(stop["duration_s"]))
	var attacks: Array[Dictionary] = []
	for attack: int in range(int(rows[-1]["attack"]) + 1):
		attacks.append(_attack_events(rows, attack))
	return {
		"scene": scene, "fps": fps, "body": Visual.OWN_FOLDER, "weapon": "axe", "hands": 1,
		"expected_attack_clips": ["p_swing_one", "p_swing_back", "p_swing_one"] if scene == "chain_three" else ["p_swing_one"],
		"observed_attack_clips": observed_clips,
		"status": "measured", "failure_code": null,
		"pelvis_status": "not_measured", "drawn_source": "completed_cpu_mix_snapshot",
		"hand_stand_ref_m": rows[0]["hand_stand_ref_m"],
		"tip_source": geometry["tip_source"], "tip_mesh_path": geometry["mesh_path"],
		"tip_local": _vector(geometry["local"]), "weapon_length_m": geometry["weapon_length_m"],
		"duration_s": duration, "samples": rows.size(), "rule_wind_s": rows[0]["rule_wind_s"],
		"rule_wait_s": rows[0]["rule_wait_s"], "rule_gap_s": rows[0]["rule_gap_s"],
		"movement_input_s": rows[0]["movement_input_s"], "movement_release_s": rows[0]["movement_release_s"],
		"stops": _stops(rows, "tip_world", 0.0, duration),
		"body_stops": _stops(rows, "tip_body", 0.0, duration), "between_hit_stops": between,
		"max_stop_between_hits_s": max_stop, "still_speed_mps": STILL_SPEED,
		"max_jump_per_30th_m": jump, "max_jump_body_per_30th_m": body_jump,
		"max_transition_jump_per_30th_m": transition_jump, "max_jump_at_s": jump_at,
		"max_tip_hand_distance_m": max_distance,
		"follow_end": attacks[-1]["follow_end"], "sag": attacks[-1]["sag"],
		"guard_arrival_s": attacks[-1]["guard_arrival_s"], "attacks": attacks,
		"pelvis_source": "unavailable_no_baked_pelvis_track",
		"arrival_radius_m": ARRIVAL_RADIUS_M, "grip_tau_s": Visual.GRIP_TAU
	}


func _check_existing_limits(summary: Dictionary) -> void:
	var label: String = "%s %dfps" % [summary["scene"], summary["fps"]]
	if String(summary["scene"]) == "chain_three":
		assert_lte(float(summary["max_stop_between_hits_s"]), 0.15 + EPS, label + " 두 공격 사이 정지")
	# The 0.15 m rule is for the frame where one attack hands over to the next;
	# the strike itself is meant to be fast and is only reported (max_jump_*).
	assert_lte(float(summary["max_transition_jump_per_30th_m"]), 0.15 + EPS, label + " 공격 넘김 장 1/30초 끝점 이동")
	assert_lte(float(summary["max_tip_hand_distance_m"]), float(summary["weapon_length_m"]) + EPS, label + " 손에서 무기 길이 안쪽")
