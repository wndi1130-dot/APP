extends "res://addons/gut/test.gd"
## Opt-in source diagnostic; no inherited source test suite.

const BodyBake = preload("res://scripts/body_bake.gd")
const OUTPUT_PATH: String = "C:/dev/zombie/ref_measure/motion_feel_20261101/walk2_phase1_driver.json"


func _load_source(path: String) -> Node3D:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: Error = document.append_from_file(path, state)
	assert_eq(int(error), int(OK), path)
	if int(error) != int(OK):
		return null
	return document.generate_scene(state) as Node3D


func test_driver_first_failed_projection_exports_phase_one_system() -> void:
	var directory: String = ProjectSettings.globalize_path("res://").path_join("../../_motion_src").simplify_path()
	var motion_path: String = directory.path_join("UAL1.glb")
	var rig_path: String = directory.path_join("rig/driver.glb")
	for path: String in [motion_path, rig_path]:
		if not FileAccess.file_exists(path):
			pending("projection diagnostic requires original " + path)
			return
	var requested: String = OS.get_environment("WALK_DUMP_PROJECTION")
	if requested.is_empty():
		pending("set WALK_DUMP_PROJECTION=1 or an output JSON path")
		return
	var motion: Node3D = _load_source(motion_path)
	var root: Node3D = _load_source(rig_path)
	if is_instance_valid(motion):
		add_child_autofree(motion)
	if is_instance_valid(root):
		add_child_autofree(root)
	assert_true(is_instance_valid(motion) and is_instance_valid(root))
	if not is_instance_valid(motion) or not is_instance_valid(root):
		return
	var walks: Array = []
	for entry: Array in BodyBake.PERSON_CLIPS:
		if BodyBake.PERSON_FOOT_LOCK.has(entry[0]):
			walks.append(entry)
	var ctx: Dictionary = BodyBake.prepare(root, motion, walks + [BodyBake.PERSON_CLIPS[2]], [])
	ctx["rig_label"] = "driver"
	ctx["dump_projection"] = OUTPUT_PATH if requested == "1" else requested
	ctx["sink_scale"] = BodyBake._sink_scale(root, ctx["body"])
	var walk: Array = walks[0]
	BodyBake._fit_person_stride(ctx, walk)
	var phase: Dictionary = BodyBake._fit_person_phase(ctx, walk)
	if not phase.is_empty():
		BodyBake._fit_person_stride(ctx, walk, float(phase["shift"]))
	var fit: Dictionary = BodyBake._fit_person_footlock(ctx, walk, phase)
	var capture: Dictionary = ctx.get("walk_projection_dump", {})
	assert_true(bool(capture.get("written", false)), "the first failed projection must produce a fresh JSON; fit_empty=%s capture=%s" % [str(fit.is_empty()), str(capture)])
	if not bool(capture.get("written", false)):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(ctx["dump_projection"])))
	assert_true(parsed is Dictionary)
	if not parsed is Dictionary:
		return
	var payload: Dictionary = parsed
	var rows: int = int(payload["rows"])
	var columns: int = int(payload["columns"])
	assert_eq(columns, BodyBake.PERSON_WALK_HEIGHT_SAMPLES)
	assert_eq((payload["A"] as Array).size(), rows)
	assert_eq((payload["b"] as Array).size(), rows)
	assert_eq((payload["x0"] as Array).size(), columns)
	assert_eq((payload["x_last"] as Array).size(), columns)
	assert_eq((payload["variables"] as Array).size(), columns)
	assert_eq((payload["A_eq"] as Array).size(), 0)
	for row: Array in payload["A"]:
		assert_eq(row.size(), columns)
		for coefficient: float in row:
			assert_true(is_finite(coefficient))
	for bound: float in payload["b"]:
		assert_true(is_finite(bound))
	assert_gte(int(payload["sweeps"]), 0)
	assert_lte(int(payload["sweeps"]), BodyBake.PERSON_WALK_PROJECT_SWEEPS)
	print("WALK_PROJECTION_CAPTURE path=%s rows=%d columns=%d sweeps=%d" % [ctx["dump_projection"], rows, columns, int(payload["sweeps"])])
