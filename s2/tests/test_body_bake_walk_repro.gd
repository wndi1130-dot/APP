extends "res://addons/gut/test.gd"

const BodyBake = preload("res://scripts/body_bake.gd")
const SOURCE_RIG: String = "duffel_b1v2"
const RIG_SHA256: String = "873e5abbe390f42cfbab6e69d0a88e20bc8e6ed86e3b2b88e0d878f523f9b946"
const MOTION_SHA256: String = "69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997"
const PROBE_PHASE: float = 0.359375
const SKIN_LIMIT_M: float = 0.001
const FRAME_EVALUATION_LIMIT: int = 12
const WORK_SCALE: float = 4.0
const SHARED_IK_LIMIT: int = 65536
const POLICY_BACKTRACK_FLOOR: float = 0.25
const POLICY_REJECTION_LIMIT: int = 3

var _previous_scale: Variant = null


func before_all() -> void:
	_previous_scale = ProjectSettings.get_setting("body_bake/walk_budget_scale_for_tests", null)
	ProjectSettings.set_setting("body_bake/walk_budget_scale_for_tests", WORK_SCALE)


func after_all() -> void:
	ProjectSettings.set_setting("body_bake/walk_budget_scale_for_tests", _previous_scale)


func _source_scene(path: String, digest: String) -> Node3D:
	assert_true(FileAccess.file_exists(path), "required fixed source: " + path)
	if not FileAccess.file_exists(path):
		return null
	var actual_digest: String = FileAccess.get_sha256(path)
	assert_eq(actual_digest, digest, "fixed source bytes")
	if actual_digest != digest:
		return null
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: Error = document.append_from_file(path, state)
	assert_eq(error, OK, "source import")
	return document.generate_scene(state) as Node3D if error == OK else null


func _print_trial_observations(batches: Array) -> void:
	var minimum_omega: float = INF
	var quarter_trials: int = 0
	var total_trials: int = 0
	var longest_rejected_run: int = 0
	for trials: Array in batches:
		var rejected_run: int = 0
		for trial: Dictionary in trials:
			var omega: float = float(trial.get("omega", 1.0))
			minimum_omega = minf(minimum_omega, omega)
			if is_equal_approx(omega, POLICY_BACKTRACK_FLOOR):
				quarter_trials += 1
			rejected_run = 0 if bool(trial.get("accepted", false)) else rejected_run + 1
			longest_rejected_run = maxi(longest_rejected_run, rejected_run)
			total_trials += 1
	print("WALK_REPRO_BACKTRACK recorded_frames=%d trials=%d min_omega=%s quarter_trials=%d max_rejected_run=%d aitken_floor=%.2f aitken_rejections=%d" % [
		batches.size(), total_trials, str(minimum_omega) if total_trials > 0 else "not_observed", quarter_trials,
		longest_rejected_run, POLICY_BACKTRACK_FLOOR, POLICY_REJECTION_LIMIT])


func test_walk_original_contact_field_converges_with_bounded_evaluations() -> void:
	var directory: String = ProjectSettings.globalize_path("res://").path_join("../../_motion_src").simplify_path()
	var motion: Node3D = _source_scene(directory.path_join("UAL1.glb"), MOTION_SHA256)
	var root: Node3D = _source_scene(directory.path_join("rig").path_join(SOURCE_RIG + ".glb"), RIG_SHA256)
	if motion != null:
		add_child_autofree(motion)
	if root != null:
		add_child_autofree(root)
	if motion == null or root == null:
		return
	var walks: Array = []
	for entry: Array in BodyBake.PERSON_CLIPS:
		if BodyBake.PERSON_FOOT_LOCK.has(entry[0]):
			walks.append(entry)
	var ctx: Dictionary = BodyBake.prepare(root, motion, walks + [BodyBake.PERSON_CLIPS[2]], [])
	assert_false(ctx.is_empty(), "source context")
	if ctx.is_empty():
		return
	var walk: Array = walks[0]
	ctx["rig_label"] = SOURCE_RIG
	ctx["sink_scale"] = BodyBake._sink_scale(root, ctx["body"])
	BodyBake._fit_person_stride(ctx, walk)
	var phase: Dictionary = BodyBake._fit_person_phase(ctx, walk)
	assert_false(phase.is_empty(), "source phase")
	if phase.is_empty():
		return
	BodyBake._fit_person_stride(ctx, walk, float(phase["shift"]))
	# The whole field entry point and its three arguments exist in both revisions.
	var fit: Dictionary = BodyBake._fit_person_footlock(ctx, walk, phase)
	var solved: Dictionary = {}
	var residual: float = INF
	var evaluations: int = 0
	var batches: Array = []
	if not fit.is_empty():
		var failure: Dictionary = fit.get("search", {}).get("witness", {}).get("last_skin_failure", {})
		if not failure.is_empty():
			batches.append((failure.get("passes", []) as Array).duplicate())
		for note: Dictionary in fit.get("search", {}).get("joint", {}).get("passes", []):
			batches.append((note.get("worst", {}).get("passes", []) as Array).duplicate())
		if not (fit.get("pelvis", {}).get("values", PackedFloat64Array()) as PackedFloat64Array).is_empty():
			ctx["walk_clip"] = walk[0]
			var keyed_u: float = fposmod(PROBE_PHASE + float(phase["shift"]), 1.0)
			BodyBake.pose(ctx, walk[1], walk[4], keyed_u)
			BodyBake._apply_person_walk_body(ctx, fit, PROBE_PHASE, keyed_u, walk[4])
			solved = BodyBake._solve_person_walk_frame(ctx, fit, PROBE_PHASE)
			residual = float(solved["skin_residual"])
			evaluations = int(solved["ik_passes"])
			batches.append((solved["passes"] as Array).duplicate())
	var budget: Dictionary = ctx.get("walk_work_budget", fit.get("work_budget", {}))
	var used: int = int(budget.get("used", {}).get("ik", 0))
	assert_true(bool(fit.get("pelvis", {}).get("ok", false)), "FIELD_FAILED_BEFORE_PROBE: complete six-clip fit")
	assert_true(ctx.has("footlock_walk"), "FIELD_FAILED_BEFORE_PROBE: only a successful fit is published")
	assert_false(solved.is_empty(), "FIELD_FAILED_BEFORE_PROBE: requested phase was not called")
	if not solved.is_empty():
		_assert_phase_contract(ctx, fit, solved)
	var observed: Dictionary = ctx.get("walk_observation", {})
	var outside: int = int(observed.get("outside_pairs", 0))
	assert_eq(used + outside, int(observed.get("actual_pairs", -1)), "ledger plus extra phase equals actual paired IK")
	assert_eq(outside, evaluations, "only the requested extra phase lies outside the fit budget")
	print("WALK_REPRO_ACCOUNTING ledger=%d outside=%d actual=%d" % [used, outside, int(observed.get("actual_pairs", -1))])
	_print_trial_observations(batches)
	print("WALK_REPRO_FIELD rig=%s phase=%.9f scale=%.1f residual_mm=%s evaluations=%d shared_ik=%d reason=%s" % [
		SOURCE_RIG, PROBE_PHASE, WORK_SCALE, residual * 1000.0, evaluations, used,
		solved.get("reason", fit.get("pelvis", {}).get("reason", "FIELD_UNSOLVED"))])
	assert_lte(residual, SKIN_LIMIT_M, "the complete field must supply a measured skin solution")
	assert_lte(evaluations, FRAME_EVALUATION_LIMIT, "paired evaluations stay within the existing cap")
	assert_lte(used, SHARED_IK_LIMIT, "the complete field stays within the fixed work budget")


func _assert_phase_contract(ctx: Dictionary, fit: Dictionary, solved: Dictionary) -> void:
	assert_true(bool(solved.get("ok", false)), "PROBE_FAILED: " + str(solved.get("reason", "missing result")))
	assert_true(bool(solved.get("evaluated", false)), "PROBE_NOT_EVALUATED: phase entered but no paired IK")
	assert_true(bool(solved.get("dynamic_verified", false)), "PROBE_FAILED: dynamic contact verification")
	var conditions: Dictionary = solved.get("conditions", {})
	assert_lte(float(solved.get("height_residual", INF)), 0.0005, "height residual, metres")
	assert_gte(float(conditions.get("height_minus_next_lower_m", -INF)), 0.0, "actual height above lower bound")
	assert_gte(float(conditions.get("next_upper_minus_height_m", -INF)), 0.0, "actual height below upper bound")
	for side in 2:
		assert_lte(float(conditions.get("ankle_miss_m", [INF, INF])[side]), 0.001, "ankle distance, metres")
		var knee: float = float(conditions.get("knee_rad", [INF, INF])[side])
		if bool(conditions.get("middle", [true, true])[side]):
			assert_lte(knee, BodyBake.PERSON_WALK_MID_KNEE_MAX, "middle stance knee, radians")
		if bool(conditions.get("stance", [true, true])[side]):
			assert_gte(knee, BodyBake.PERSON_WALK_KNEE_MIN, "stance knee, radians")
	var goals: Array = []
	for side in 2:
		goals.append(BodyBake._person_walk_ankle_goal(fit, side, PROBE_PHASE))
	var body: Skeleton3D = ctx["body"]
	var actual_h: float = ((ctx["to_mesh"] as Transform3D) * body.get_bone_global_pose(body.find_bone("hips"))).origin.y
	var physical: Dictionary = BodyBake._person_walk_physical_error(fit, BodyBake._skin_frame(ctx), goals, actual_h,
		BodyBake._person_walk_height_at(fit["pelvis"], PROBE_PHASE))
	assert_true(bool(physical["valid"]), "physical measurement is independent of solver flags")
	assert_lte(float(physical["max_abs_m"]), 0.001, "actual sole minimum minus floor and path lift")
	assert_lte(float(physical["height_abs_m"]), 0.0005, "actual hips minus fixed table height")
	print("WALK_REPRO_PHYSICAL " + JSON.stringify(physical))


## Same source bytes and pre-search construction as _fit_person_footlock.
## No complete-field call, fitted table or successful cached fit is required.
func _direct_phase_input() -> Dictionary:
	var directory: String = ProjectSettings.globalize_path("res://").path_join("../../_motion_src").simplify_path()
	var motion: Node3D = _source_scene(directory.path_join("UAL1.glb"), MOTION_SHA256)
	var root: Node3D = _source_scene(directory.path_join("rig").path_join(SOURCE_RIG + ".glb"), RIG_SHA256)
	if motion != null:
		add_child_autofree(motion)
	if root != null:
		add_child_autofree(root)
	if motion == null or root == null:
		return {}
	var walk: Array = BodyBake.PERSON_CLIPS[0]
	var stand: Array = BodyBake.PERSON_CLIPS[2]
	var ctx: Dictionary = BodyBake.prepare(root, motion, [walk, stand], [])
	assert_false(ctx.is_empty(), "direct phase context")
	if ctx.is_empty():
		return {}
	ctx["rig_label"] = SOURCE_RIG
	ctx["walk_clip"] = walk[0]
	ctx["sink_scale"] = BodyBake._sink_scale(root, ctx["body"])
	BodyBake._fit_person_stride(ctx, walk)
	var phase: Dictionary = BodyBake._fit_person_phase(ctx, walk)
	assert_false(phase.is_empty(), "direct phase contact input")
	if phase.is_empty():
		return {}
	BodyBake._fit_person_stride(ctx, walk, float(phase["shift"]))
	var contacts: Dictionary = ctx.get("phase_fits", {}).get("p_walk", {})
	assert_gte(float(contacts.get("left", -1.0)), 0.0)
	assert_gte(float(contacts.get("right", -1.0)), 0.0)
	if float(contacts.get("left", -1.0)) < 0.0 or float(contacts.get("right", -1.0)) < 0.0:
		return {}
	var body: Skeleton3D = ctx["body"]
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var arrays: Array = mesh_node.get_meta(BodyBake.PERSON_PHASE_SOURCE) if mesh_node.has_meta(BodyBake.PERSON_PHASE_SOURCE) else mesh_node.mesh.surface_get_arrays(0)
	var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	assert_false(rest.is_empty(), "direct source vertices")
	if rest.is_empty():
		return {}
	var per: int = bones.size() / rest.size()
	assert_gt(per, 0)
	assert_eq(weights.size(), bones.size())
	if per <= 0 or weights.size() != bones.size():
		return {}
	var soles: Array = BodyBake.person_sole_vertices(rest)
	var legs: Array = []
	for side in 2:
		var suffix: String = ".L" if side == 0 else ".R"
		var leg: Array = [body.find_bone("thigh" + suffix), body.find_bone("shin" + suffix), body.find_bone("foot" + suffix)]
		assert_false(leg.has(-1), "direct source leg chain")
		if leg.has(-1):
			return {}
		legs.append(leg)
		for vertex in rest.size():
			if BodyBake._main_bone(body, ctx["skin"], bones, weights, per, vertex) == int(leg[2]) and not soles[side].has(vertex):
				soles[side].append(vertex)
		assert_false(soles[side].is_empty(), "direct source sole")
		if soles[side].is_empty():
			return {}
	var fit: Dictionary = {"rest": rest, "bones": bones, "weights": weights, "per": per, "soles": soles, "legs": legs,
		"starts": [], "durations": [], "anchors": [], "rest_ankles": [], "rotations": [], "round": float(BodyBake.PERSON_STRIDE_ROUNDS["p_walk"])}
	BodyBake.pose(ctx, stand[1], stand[4], 0.0)
	var standing: Array = BodyBake._person_footlock_points(fit, BodyBake._skin_frame(ctx))
	fit["floor"] = minf((standing[0] as Vector3).y, (standing[1] as Vector3).y)
	var shift: float = float(phase["shift"])
	var left: float = fposmod(float(contacts["left"]) - shift, 1.0)
	var order: int = 0 if absf(wrapf(left - float(BodyBake.PERSON_STEP_AT[0]), -0.5, 0.5)) <= absf(wrapf(left - float(BodyBake.PERSON_STEP_AT[1]), -0.5, 0.5)) else 1
	fit["starts"] = [float(BodyBake.PERSON_STEP_AT[order]), float(BodyBake.PERSON_STEP_AT[1 - order])]
	var to_mesh: Transform3D = ctx["to_mesh"]
	for side in 2:
		var gap: float = fposmod(float(fit["starts"][1 - side]) - float(fit["starts"][side]), 1.0)
		fit["durations"].append(clampf(gap + BodyBake.PERSON_FOOTLOCK_OVERLAP, BodyBake.PERSON_FOOTLOCK_STANCE_MIN, BodyBake.PERSON_FOOTLOCK_STANCE_MAX))
		var rest_foot: Transform3D = to_mesh * body.get_bone_global_rest(int(legs[side][2]))
		var anchor: Vector3 = (to_mesh * body.get_bone_global_rest(int(legs[side][0]))).origin
		anchor.z -= BodyBake.PERSON_WALK_FOOTPRINT_BACK
		fit["anchors"].append(anchor)
		fit["rest_ankles"].append(rest_foot.origin)
		fit["rotations"].append(rest_foot.basis.orthonormalized())
	fit["rest_hips_y"] = (to_mesh * body.get_bone_global_rest(body.find_bone("hips"))).origin.y
	fit["stand_ref_m"] = float(fit["rest_hips_y"]) - float(fit["floor"])
	fit["path_params"] = BodyBake._person_walk_default_params(fit).duplicate(true)
	var keyed_u: float = fposmod(PROBE_PHASE + shift, 1.0)
	BodyBake.pose(ctx, walk[1], walk[4], keyed_u)
	BodyBake._apply_person_walk_turn(ctx, fit, PROBE_PHASE, keyed_u, walk[4])
	var seed: Array = []
	for side in 2:
		seed.append(BodyBake._person_walk_ankle_goal_uncached(fit, side, PROBE_PHASE)["target"])
	var bounds: Dictionary = BodyBake._person_walk_height_bounds(ctx, fit, PROBE_PHASE, seed)
	assert_false(bool(bounds["empty"]), "direct rigid seed must have a fixed height interval")
	if bool(bounds["empty"]):
		return {}
	var wanted: float = float(fit["floor"]) + BodyBake.PERSON_WALK_MEAN_MIN * float(fit["stand_ref_m"])
	var height: float = BodyBake._person_walk_inner_height(wanted, bounds)
	fit["pelvis"] = {"values": PackedFloat64Array([height]), "slopes": PackedFloat64Array([0.0])}
	BodyBake._set_person_walk_hips_y(ctx, height)
	var keyed_pose: Array = []
	for bone in body.get_bone_count():
		keyed_pose.append([body.get_bone_pose_position(bone), body.get_bone_pose_rotation(bone), body.get_bone_pose_scale(bone)])
	return {"ctx": ctx, "fit": fit, "seed": seed, "height": height, "keyed_pose": keyed_pose, "shift": shift}


func test_walk_duffel_direct_phase_has_independent_physical_contract() -> void:
	var input: Dictionary = _direct_phase_input()
	assert_false(input.is_empty(), "DIRECT_INPUT_MISSING: no successful complete fit may be required")
	if input.is_empty():
		return
	var ctx: Dictionary = input["ctx"]
	var fit: Dictionary = input["fit"]
	var frozen: PackedByteArray = var_to_bytes([input["keyed_pose"], fit["path_params"], input["height"], input["seed"], input["shift"], PROBE_PHASE])
	var repeated: Dictionary = _direct_phase_input()
	assert_false(repeated.is_empty(), "independent direct input reconstruction")
	if repeated.is_empty():
		return
	assert_eq(frozen, var_to_bytes([repeated["keyed_pose"], repeated["fit"]["path_params"], repeated["height"], repeated["seed"], repeated["shift"], PROBE_PHASE]), "two fresh source contexts produce identical fixed input bytes")
	assert_false(ctx.has("footlock_walk"), "direct probe must bypass complete-field cache")
	assert_false(ctx.has("footlock_walk_refused"), "direct probe must bypass complete-field refusal cache")
	var solved: Dictionary = BodyBake._solve_person_walk_frame(ctx, fit, PROBE_PHASE, input["seed"])
	_assert_phase_contract(ctx, fit, solved)
	assert_eq(frozen, var_to_bytes([input["keyed_pose"], fit["path_params"], input["height"], input["seed"], input["shift"], PROBE_PHASE]), "fixed direct input bytes")
	assert_lte(int(solved["ik_passes"]), FRAME_EVALUATION_LIMIT)
	print("WALK_DIRECT_INPUT phase=%.9f height=%.12f bytes=%d reason=%s" % [PROBE_PHASE, input["height"], frozen.size(), solved["reason"]])
