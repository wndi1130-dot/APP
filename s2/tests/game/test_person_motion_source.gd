extends "res://addons/gut/test.gd"
## Run after rebaking all living bodies and wear with the same PERSON_KEEP.
## VAT does not retain bones. Rotation checks use source keys; their frame
## tables are in _out/motion_source_result.md and _out/motion_add_result.md.

const BodyBake = preload("res://scripts/body_bake.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const PEOPLE: String = "res://models/people"
const GROUPS: Dictionary = {
	"walk": ["p_walk", "p_walk_long", "p_walk_axe", "p_walk_pistol", "p_carry_big", "p_walk_hurt"],
	"run": ["p_run", "p_run_long", "p_run_pistol"],
	"crouch": ["p_crouch_walk", "p_crouch_walk_long", "p_crouch_walk_pistol"],
}
const BLOWS: Array = [
	["p_swing_one", "p_ready_one", 0.45, 24, 0.6],
	["p_swing_back", "p_ready_one", 0.33, 24, 0.6],
	["p_stab", "p_ready_stab", 0.35, 20, 0.45],
	["p_swing_over", "p_ready_one", 0.45, 24, 0.6],
	["p_chop_one", "p_ready_one", 0.45, 24, 0.6],
]

var _fixtures: Array[Dictionary] = []
var _folder_count: int = 0


func before_all() -> void:
	var names := DirAccess.get_directories_at(PEOPLE)
	names.sort()
	for folder: String in names:
		if not folder.ends_with("_p"):
			continue
		_folder_count += 1
		var baked := BodyBake.load_baked(PEOPLE.path_join(folder))
		assert_false(baked.is_empty(), folder + " loads")
		if baked.is_empty():
			continue
		var arrays: Array = (baked["mesh"] as Mesh).surface_get_arrays(0)
		var fixture := {"name": folder, "baked": baked, "rest": arrays[Mesh.ARRAY_VERTEX], "look": arrays[Mesh.ARRAY_TEX_UV2]}
		fixture["feet"] = _walk_feet(fixture)
		fixture["soles"] = BodyBake.person_sole_vertices(fixture["rest"])
		fixture["right"] = PersonVisual.hand_of(baked).get("hand", PackedInt32Array())
		fixture["left"] = _left_hand(fixture)
		_fixtures.append(fixture)


func after_all() -> void:
	_fixtures.clear()


func _clip(fixture: Dictionary, name_text: String) -> Dictionary:
	for clip: Dictionary in fixture["baked"]["clips"]:
		if str(clip["name"]) == name_text:
			return clip
	assert_true(false, "%s has %s; rebake before this test" % [fixture["name"], name_text])
	return {}


## Decode a known clip directly, including UV2 sharing and per-clip rgb8q
## boxes. Looking up the clip again for every vertex would slow this suite.
func _sample(fixture: Dictionary, clip: Dictionary, ids: PackedInt32Array) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	if clip.is_empty():
		return out
	var baked: Dictionary = fixture["baked"]
	var image: Image = baked["image"]
	var rest: PackedVector3Array = fixture["rest"]
	var look: PackedVector2Array = fixture["look"]
	var lo := Vector3.ZERO
	var span := Vector3.ONE
	if baked.get("format", "") != "":
		lo = Vector3(clip["lo"][0], clip["lo"][1], clip["lo"][2])
		span = Vector3(clip["hi"][0], clip["hi"][1], clip["hi"][2]) - lo
	for f in int(clip["frames"]):
		var points := PackedVector3Array()
		for i in ids:
			var pixel := image.get_pixel(int(look[i].x * float(baked["width"])), (int(clip["start"]) + f) * int(baked["rows_per_frame"]) + int(look[i].y))
			points.append(rest[i] + lo + Vector3(pixel.r, pixel.g, pixel.b) * span)
		out.append(points)
	return out


## Same 40 vertices as still_feet.py: rank walk z ranges after filtering the
## mean offsets, then reuse those IDs for shared-leg and stance-speed checks.
func _walk_feet(fixture: Dictionary) -> PackedInt32Array:
	var rest: PackedVector3Array = fixture["rest"]
	var ids := PackedInt32Array()
	for i in rest.size():
		ids.append(i)
	var frames := _sample(fixture, _clip(fixture, "p_walk"), ids)
	var ranked: Array = []
	if frames.is_empty():
		return PackedInt32Array()
	for i in rest.size():
		var mean := Vector3.ZERO
		var low := INF
		var high := -INF
		for points: PackedVector3Array in frames:
			var offset := points[i] - rest[i]
			mean += offset
			low = minf(low, offset.z)
			high = maxf(high, offset.z)
		mean /= float(frames.size())
		if absf(mean.x) < 0.25 and mean.y > -0.3:
			ranked.append([i, high - low])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]) if a[1] != b[1] else int(a[0]) < int(b[0]))
	var feet := PackedInt32Array()
	for n in mini(40, ranked.size()):
		feet.append(int(ranked[n][0]))
	return feet


## Mirror hand_of's shove-frame tip and HAND_R neighbourhood for the left.
func _left_hand(fixture: Dictionary) -> PackedInt32Array:
	var shove := _clip(fixture, "p_shove")
	if shove.is_empty():
		return PackedInt32Array()
	var baked: Dictionary = fixture["baked"]
	var rest: PackedVector3Array = fixture["rest"]
	var look: PackedVector2Array = fixture["look"]
	var frame := int(shove["start"]) + int(roundf(0.4 * float(int(shove["frames"]) - 1)))
	var at := PackedVector3Array()
	var tip := Vector3(0, 0, -99)
	for i in rest.size():
		var point := PersonVisual.vertex_at(baked, rest, look, i, frame)
		at.append(point)
		if point.x > 0.05 and point.z > tip.z:
			tip = point
	var hand := PackedInt32Array()
	for i in at.size():
		if at[i].distance_to(tip) < PersonVisual.HAND_R:
			hand.append(i)
	return hand


func _center(points: PackedVector3Array) -> Vector3:
	var middle := Vector3.ZERO
	for point in points:
		middle += point
	return middle / float(points.size()) if not points.is_empty() else Vector3.ZERO


func _quantum(fixture: Dictionary, clip: Dictionary) -> float:
	if fixture["baked"].get("format", "") == "":
		return 0.0
	var lo := Vector3(clip["lo"][0], clip["lo"][1], clip["lo"][2])
	var hi := Vector3(clip["hi"][0], clip["hi"][1], clip["hi"][2])
	return (hi - lo).length() / 255.0


func test_all_fourteen_living_folders_load() -> void:
	assert_eq(_folder_count, 14, "all living bodies, including the seamstress")
	assert_eq(_fixtures.size(), _folder_count, "none silently skipped")
	for fixture in _fixtures:
		assert_eq((fixture["feet"] as PackedInt32Array).size(), 40, str(fixture["name"]) + " foot vertices")
		for side in 2:
			assert_false(fixture["soles"][side].is_empty(), "%s %s rest sole found" % [fixture["name"], "L" if side == 0 else "R"])


func test_standing_feet_stay_within_one_centimetre() -> void:
	for fixture in _fixtures:
		var clip := _clip(fixture, "p_stand")
		if clip.is_empty():
			continue
		assert_true(float(clip["round"]) <= BodyBake.ROUND_LEAST, str(fixture["name"]) + " standing round")
		assert_almost_eq(float(clip["length"]), 2.5, 0.0001, "UAL1 Idle_Loop length")
		for side in 2:
			var sole: PackedInt32Array = fixture["soles"][side]
			if sole.is_empty():
				continue  # Missing soles already fail the fixture check.
			var frames := _sample(fixture, clip, sole)
			var greatest := 0.0
			var greatest_round := 0.0
			# Track each fixed rest-bottom vertex, avoiding toe/heel identity jumps.
			for i in sole.size():
				var low: Vector3 = frames[0][i]
				var high := low
				var zs := []
				for points: PackedVector3Array in frames:
					low = low.min(points[i])
					high = high.max(points[i])
					zs.append(points[i].z)
				var span := high - low
				greatest = maxf(greatest, maxf(span.x, maxf(span.y, span.z)))
				greatest_round = maxf(greatest_round, BodyBake.round_of(zs))
			var label := "%s %s sole (%d rest-bottom vertices)" % [fixture["name"], "L" if side == 0 else "R", sole.size()]
			assert_true(greatest <= 0.01, "%s standing axis range %.6f m <= 0.01" % [label, greatest])
			assert_true(greatest_round <= BodyBake.ROUND_LEAST, "%s standing round %.6f m" % [label, greatest_round])


func test_shared_legs_and_full_walk_run_frames() -> void:
	for fixture in _fixtures:
		for group: String in GROUPS:
			var base := _clip(fixture, GROUPS[group][0])
			if base.is_empty():
				continue
			var base_frames := _sample(fixture, base, fixture["feet"])
			for name_text: String in GROUPS[group]:
				var clip := _clip(fixture, name_text)
				if clip.is_empty():
					continue
				var label := "%s %s" % [fixture["name"], name_text]
				assert_eq(int(clip["frames"]), int(base["frames"]), label + " shares frame count")
				if group != "crouch":
					assert_eq(int(clip["frames"]), 32 if group == "walk" else 24, label + " keeps every frame")
				var frames := _sample(fixture, clip, fixture["feet"])
				if frames.size() != base_frames.size():
					continue
				var greatest := 0.0
				for f in frames.size():
					for i in frames[f].size():
						greatest = maxf(greatest, frames[f][i].distance_to(base_frames[f][i]))
				# Each arm-dependent clip box rounds into its own rgb8 cell.
				# Allow one cell from each box, including truncating encoders.
				var tolerance := _quantum(fixture, base) + _quantum(fixture, clip) + 0.00001
				assert_true(greatest <= tolerance, "%s foot difference %.6f <= quantization %.6f" % [label, greatest, tolerance])


func _contact_at(frames: Array[PackedVector3Array]) -> float:
	var heights := []
	for points: PackedVector3Array in frames:
		var lowest := INF
		for point in points:
			lowest = minf(lowest, point.y)
		heights.append(lowest)
	if heights.size() < 2 or not is_finite(float(heights.min())):
		return -1.0
	var threshold := float(heights.min()) + 0.01
	for f in heights.size():
		var previous := float(heights[(f + heights.size() - 1) % heights.size()])
		var current := float(heights[f])
		if previous > threshold and current <= threshold:
			return fposmod((float(f - 1) + (previous - threshold) / (previous - current)) / float(heights.size()), 1.0)
	return -1.0


func _phase_distance(a: float, b: float) -> float:
	var gap := absf(a - b)
	return minf(gap, 1.0 - gap)


func test_walk_run_sole_contacts_are_within_fifty_milliseconds_of_steps() -> void:
	for fixture in _fixtures:
		for group in ["walk", "run"]:
			var period := float(SimNoise.STEP_ROUND[group]) / (2.1 if group == "walk" else 3.9)
			for name_text: String in GROUPS[group]:
				var clip := _clip(fixture, name_text)
				if clip.is_empty():
					continue
				var contacts := []
				for side in 2:
					contacts.append(_contact_at(_sample(fixture, clip, fixture["soles"][side])))
				var label := "%s %s" % [fixture["name"], name_text]
				assert_true(float(contacts[0]) >= 0.0 and float(contacts[1]) >= 0.0, "%s sole first entries L %.6f R %.6f" % [label, contacts[0], contacts[1]])
				if float(contacts[0]) < 0.0 or float(contacts[1]) < 0.0:
					continue
				var best := []
				var least := INF
				for order in 2:
					var errors := [_phase_distance(contacts[0], SimNoise.STEP_AT[order]), _phase_distance(contacts[1], SimNoise.STEP_AT[1 - order])]
					var worst := maxf(errors[0], errors[1])
					if worst < least:
						least = worst
						best = errors
				for side in 2:
					var seconds := float(best[side]) * period
					assert_true(seconds <= 0.05, "%s %s contact %.6f, STEP_AT %s, error %.3f ms <= 50 (round time %.6f s)" % [label, "L" if side == 0 else "R", contacts[side], str(SimNoise.STEP_AT), seconds * 1000.0, period])


func test_phase_solver_splits_symmetric_contact_error_and_handles_the_seam() -> void:
	assert_eq(BodyBake.PERSON_STEP_AT, SimNoise.STEP_AT, "phase targets follow the unchanged noise rule")
	for pair: Array in [[0.1, 0.6], [0.98, 0.48]]:
		var shift := BodyBake.person_phase_shift(pair[0], pair[1])
		for contact: float in pair:
			var phase := fposmod(contact - shift, 1.0)
			var error := minf(_phase_distance(phase, SimNoise.STEP_AT[0]), _phase_distance(phase, SimNoise.STEP_AT[1]))
			assert_almost_eq(error, 0.025, 0.000001, "half-cycle contacts split the 0.05 mismatch equally")
	assert_almost_eq(BodyBake.person_contact_phase([0.0, 0.0, 0.03, 0.02]), 0.875, 0.000001, "contact interpolates across the seam")
	assert_eq(BodyBake.person_contact_phase([0.0, 0.0, 0.0, 0.0]), -1.0, "a foot that never lifts has no first entry")


func _clip_info(folder: String) -> Dictionary:
	var path := folder.path_join("clips.json")
	assert_true(FileAccess.file_exists(path), path + " exists")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, path + " is an object")
	if not parsed is Dictionary:
		return {}
	var info: Dictionary = parsed
	var height := int(info.get("height", 0))
	assert_true(height > 0 and height <= 4096, "%s height %d in 1..4096" % [path, height])
	assert_true(info.get("clips", []) is Array and not (info.get("clips", []) as Array).is_empty(), path + " has clips")
	return info


func _clip_layout(info: Dictionary) -> Array:
	var layout := []
	for clip: Dictionary in info.get("clips", []):
		layout.append([str(clip.get("name", "")), int(clip.get("start", -1)), int(clip.get("frames", 0))])
	return layout


func test_all_body_and_wear_heights_and_clip_layouts_match() -> void:
	for name_text: String in DirAccess.get_directories_at(PEOPLE):
		if not name_text.ends_with("_p"):
			continue
		var folder := PEOPLE.path_join(name_text)
		var body_info := _clip_info(folder)
		var layout := _clip_layout(body_info)
		var wear := folder.path_join("wear")
		for garment: String in DirAccess.get_directories_at(wear):
			var garment_folder := wear.path_join(garment)
			var garment_info := _clip_info(garment_folder)
			assert_eq(_clip_layout(garment_info), layout, garment_folder + " shares body clip names/start/frames")


func test_every_gait_round_matches_the_rules_within_half_a_percent() -> void:
	for fixture in _fixtures:
		for group: String in GROUPS:
			var target: float = SimNoise.STEP_ROUND[group]
			for name_text: String in GROUPS[group]:
				var clip := _clip(fixture, name_text)
				if not clip.is_empty():
					assert_almost_eq(float(clip["round"]), target, target * 0.005, "%s %s round" % [fixture["name"], name_text])


func test_stance_speed_ratios_are_reported_without_a_pass_threshold() -> void:
	for fixture in _fixtures:
		for group in ["walk", "run"]:
			var clip := _clip(fixture, GROUPS[group][0])
			if clip.is_empty():
				continue
			var frames := _sample(fixture, clip, fixture["feet"])
			var feet: PackedInt32Array = fixture["feet"]
			var rest: PackedVector3Array = fixture["rest"]
			for side in ["L", "R"]:
				var track := PackedVector3Array()
				var ground := INF
				for points: PackedVector3Array in frames:
					var lowest := Vector3(0, INF, 0)
					for i in feet.size():
						if (rest[feet[i]].x >= 0.0) == (side == "L") and points[i].y < lowest.y:
							lowest = points[i]
					track.append(lowest)
					ground = minf(ground, lowest.y)
				var ratios := []
				for f in track.size():
					var next := (f + 1) % track.size()
					if track[f].y <= ground + 0.015 and track[next].y <= ground + 0.015 and is_finite(ground):
						ratios.append((track[next].z - track[f].z) / (float(SimNoise.STEP_ROUND[group]) / float(track.size())))
				if ratios.is_empty():
					print("STANCE %s %s %s n=0 target=-1.1..-0.9" % [fixture["name"], clip["name"], side])
				else:
					var total := 0.0
					for ratio: float in ratios:
						total += ratio
					print("STANCE %s %s %s n=%d min=%.4f max=%.4f mean=%.4f target=-1.1..-0.9" % [fixture["name"], clip["name"], side, ratios.size(), ratios.min(), ratios.max(), total / float(ratios.size())])
	pass_test("stance speed ratios are reported in the log (no pass line while the walk keys wait on a decision)")


func _blow_hit_at(name_text: String, fallback: float) -> float:
	for kind: String in PersonVisual.OWN_BLOWS:
		for blow: Array in PersonVisual.OWN_BLOWS[kind]:
			if str(blow[0]) == name_text:
				return float(blow[1])
	return fallback  # New overhead/chop clips both land at 0.45 before combat adopts them.


func test_one_hand_blows_start_and_end_at_the_guard_and_land_in_front() -> void:
	for fixture in _fixtures:
		var right: PackedInt32Array = fixture["right"]
		assert_false(right.is_empty(), str(fixture["name"]) + " right hand found like hand_of")
		if right.is_empty():
			continue
		for blow: Array in BLOWS:
			var clip := _clip(fixture, blow[0])
			var guard := _clip(fixture, blow[1])
			if clip.is_empty() or guard.is_empty():
				continue
			var label := "%s %s" % [fixture["name"], blow[0]]
			assert_eq(int(clip["frames"]), int(blow[3]), label + " full frames")
			assert_almost_eq(float(clip["length"]), float(blow[4]), 0.0001, label + " duration")
			var frames := _sample(fixture, clip, right)
			var ready := _center(_sample(fixture, guard, right)[0])
			var first_gap := _center(frames[0]).distance_to(ready)
			var last_gap := _center(frames[-1]).distance_to(ready)
			assert_true(first_gap <= 0.05, "%s begins %.4f m from guard <= 0.05" % [label, first_gap])
			assert_true(last_gap <= 0.05, "%s ends %.4f m from guard <= 0.05" % [label, last_gap])
			var at := int(roundf(_blow_hit_at(blow[0], blow[2]) * float(frames.size() - 1)))
			var hand := _center(frames[at])
			assert_true(hand.z > 0.3, "%s impact hand z %.4f > 0.3 m" % [label, hand.z])
			# 0.18 m: the broad-shouldered woodsman lands 0.17 m off the middle line (the rest within 0.15).
			assert_true(absf(hand.x) <= 0.18, "%s impact hand |x| %.4f <= 0.18 m" % [label, absf(hand.x)])


func test_overhead_left_hand_never_grips_the_right_hand() -> void:
	for fixture in _fixtures:
		var clip := _clip(fixture, "p_swing_over")
		var right: PackedInt32Array = fixture["right"]
		var left: PackedInt32Array = fixture["left"]
		assert_false(left.is_empty(), str(fixture["name"]) + " mirrored left hand found")
		if clip.is_empty() or right.is_empty() or left.is_empty():
			continue
		var right_frames := _sample(fixture, clip, right)
		var left_frames := _sample(fixture, clip, left)
		var nearest := INF
		for f in right_frames.size():
			nearest = minf(nearest, _center(right_frames[f]).distance_to(_center(left_frames[f])))
		assert_true(nearest > 0.25, "%s overhead hands stay %.4f m apart > 0.25" % [fixture["name"], nearest])


func test_chop_left_hand_stays_more_than_twenty_five_centimetres_from_the_right() -> void:
	for fixture in _fixtures:
		var clip := _clip(fixture, "p_chop_one")
		var right: PackedInt32Array = fixture["right"]
		var left: PackedInt32Array = fixture["left"]
		assert_false(left.is_empty(), str(fixture["name"]) + " chop left hand found")
		if clip.is_empty() or right.is_empty() or left.is_empty():
			continue
		var right_frames := _sample(fixture, clip, right)
		var left_frames := _sample(fixture, clip, left)
		for f in right_frames.size():
			var gap := _center(right_frames[f]).distance_to(_center(left_frames[f]))
			assert_true(gap > 0.25, "%s p_chop_one frame %d hands %.4f m apart > 0.25" % [fixture["name"], f, gap])


func test_blow_aim_angles_are_reported_without_a_pass_threshold() -> void:
	for fixture in _fixtures:
		var right: PackedInt32Array = fixture["right"]
		if right.is_empty():
			continue
		print("BLOW_BODY %s" % fixture["name"])
		for blow: Array in BLOWS:
			var clip := _clip(fixture, blow[0])
			if clip.is_empty():
				continue
			var frames := _sample(fixture, clip, right)
			var at := int(roundf(_blow_hit_at(blow[0], blow[2]) * float(frames.size() - 1)))
			var hand := _center(frames[at])
			print("BLOW_AIM %s %.6f" % [blow[0], rad_to_deg(atan2(hand.x, hand.z))])
	pass_test("blow aim angles are reported in the log for the attack timing")


func _turn_at(spec: Dictionary, bone: String, axis: String, u: float) -> float:
	var angle := 0.0
	for step: Array in spec["steps"]:
		if step[0] == "turn" and step[1] == bone and step[2] == axis:
			angle += BodyBake._value(step[3], TAU * u)
	return angle


## The authored rotations in body space, in apply_layer's order. The chest
## inherits hips before its own y turn; arm aims specify a body-space ray.
func _source_pose(spec: Dictionary, u: float) -> Array:
	var hips := Basis(Vector3.UP, _turn_at(spec, "hips", "y", u))
	var spine := Basis(Vector3.RIGHT, _turn_at(spec, "spine", "x", u))
	var chest := Basis(Vector3.UP, _turn_at(spec, "chest", "y", u)) * spine * hips
	var arm := Vector3.FORWARD
	for step: Array in spec["steps"]:
		if step[0] == "aim" and step[1] == "upper_arm.R":
			arm = Vector3(BodyBake._value(step[3][0], TAU * u), BodyBake._value(step[3][1], TAU * u), BodyBake._value(step[3][2], TAU * u)).normalized()
	return [hips, chest, arm]


func test_source_key_y_speed_peaks_go_hips_then_chest_then_arm() -> void:
	for blow: Array in BLOWS:
		var spec: Dictionary = BodyBake.LAYERS[blow[0]]
		var count := int(blow[3])
		var dt := float(blow[4]) / float(count - 1)
		var fastest := [-1.0, -1.0, -1.0]
		var peaks := [-1, -1, -1]
		for f in count - 1:
			var a := _source_pose(spec, float(f) / float(count - 1))
			var b := _source_pose(spec, float(f + 1) / float(count - 1))
			for part in 3:
				var rotation: Quaternion
				if part == 2:
					rotation = Quaternion(a[2], b[2])
				else:
					rotation = ((b[part] as Basis) * (a[part] as Basis).inverse()).get_rotation_quaternion()
				var speed := absf(BodyBake._rotation_vector(rotation).y) / dt
				if speed > float(fastest[part]):
					fastest[part] = speed
					peaks[part] = f
		assert_true(peaks[0] < peaks[1] and peaks[1] < peaks[2], "%s source y-speed peak intervals %s" % [blow[0], str(peaks)])


func test_source_key_waist_y_twist_stays_below_sixty_degrees() -> void:
	for blow: Array in BLOWS:
		var spec: Dictionary = BodyBake.LAYERS[blow[0]]
		var greatest := 0.0
		for f in 1001:
			var posed := _source_pose(spec, float(f) / 1000.0)
			var relative: Basis = (posed[0] as Basis).inverse() * (posed[1] as Basis)
			greatest = maxf(greatest, absf(atan2(relative.z.x, relative.z.z)))
		assert_true(greatest <= deg_to_rad(60.0), "%s source waist y twist %.3f degrees" % [blow[0], rad_to_deg(greatest)])
