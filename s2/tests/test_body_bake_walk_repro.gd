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
	_print_trial_observations(batches)
	print("WALK_REPRO_FIELD rig=%s phase=%.9f scale=%.1f residual_mm=%s evaluations=%d shared_ik=%d reason=%s" % [
		SOURCE_RIG, PROBE_PHASE, WORK_SCALE, residual * 1000.0, evaluations, used,
		solved.get("reason", fit.get("pelvis", {}).get("reason", "FIELD_UNSOLVED"))])
	assert_lte(residual, SKIN_LIMIT_M, "the complete field must supply a measured skin solution")
	assert_lte(evaluations, FRAME_EVALUATION_LIMIT, "paired evaluations stay within the existing cap")
	assert_lte(used, SHARED_IK_LIMIT, "the complete field stays within the fixed work budget")
