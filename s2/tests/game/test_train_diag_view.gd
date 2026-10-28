extends "res://addons/gut/test.gd"
## The diagonal camera keeps its target in the clear part of the viewport;
## dragging follows the projected train axis, while section keeps its old view.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")


func _scene(extra: Dictionary = {}) -> Scene:
	# A fixed viewport makes pixel assertions independent of the test window.
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1688, 780)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var train_scene: Scene = Scene.new()
	train_scene.rules = Rules.load_default()
	var scene_opts: Dictionary = {"seed": 7, "panel": false, "baked_people": false}
	scene_opts.merge(extra, true)
	train_scene.opts = scene_opts
	viewport.add_child(train_scene)
	return train_scene


func test_diag_pose_and_zoom_sizes() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	var cam: Camera3D = train_scene.camera
	assert_eq(train_scene.view_mode, "diag")
	assert_eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_eq(cam.keep_aspect, Camera3D.KEEP_HEIGHT)
	assert_almost_eq(cam.rotation_degrees.x, -35.0, 0.5)
	assert_almost_eq(cam.rotation_degrees.y, 45.0, 0.5)
	assert_almost_eq(cam.rotation_degrees.z, 0.0, 0.5)
	assert_almost_eq(cam.size, 22.8192, 0.0001)
	var wide_size: float = cam.size
	train_scene.focus_car("dining", true)
	assert_eq(train_scene.zoom, "near")
	assert_almost_eq(cam.size, 11.9801, 0.0001)
	assert_almost_eq(cam.size / wide_size, 0.525, 0.001)


func test_diag_pane_centers_the_anchor() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	var view_size: Vector2 = train_scene.get_viewport().get_visible_rect().size
	var pane_width: float = 420.0
	for close_up: bool in [false, true]:
		train_scene.focus_car("dining", close_up)
		train_scene.set_pane(pane_width)
		var anchor: Vector3 = Vector3(train_scene.cam_x, Scene.DIAG_LOOK_Y, 0.0)
		var projected: Vector2 = train_scene.camera.unproject_position(anchor)
		assert_almost_eq(projected.x, (view_size.x - pane_width) / 2.0, 1.0)
		assert_almost_eq(projected.y, view_size.y / 2.0, 1.0)


func test_diag_drag_follows_only_the_projected_train_axis() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	train_scene.focus_car("dining")
	train_scene.set_pane(420.0)
	var cam: Camera3D = train_scene.camera
	var anchor: Vector3 = Vector3(train_scene.cam_x, Scene.DIAG_LOOK_Y, 0.0)
	var q: Vector2 = cam.unproject_position(anchor + Vector3.RIGHT) - cam.unproject_position(anchor)
	assert_gt(q.length_squared(), 0.000001)
	if q.length_squared() <= 0.000001:
		return
	var before: float = train_scene.cam_x
	train_scene.drag(q.normalized() * 100.0)
	assert_almost_eq(train_scene.cam_x, before - 100.0 / q.length(), 0.001)
	var after_axis: float = train_scene.cam_x
	train_scene.drag(Vector2(-q.y, q.x).normalized() * 100.0)
	assert_almost_eq(train_scene.cam_x, after_axis, 0.001)
	var vertical: InputEventScreenDrag = InputEventScreenDrag.new()
	vertical.relative = Vector2(0.0, 100.0)
	train_scene._unhandled_input(vertical)
	assert_almost_eq(train_scene.cam_x, after_axis - vertical.relative.dot(q) / q.length_squared(), 0.001)


func test_diag_zoom_round_trip_does_not_accumulate_pane_offset() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	train_scene.set_pane(420.0)
	var initial_offset: float = train_scene.camera.h_offset
	for _i: int in range(4):
		train_scene.toggle_zoom()
	assert_eq(train_scene.zoom, "wide")
	assert_almost_eq(train_scene.camera.h_offset, initial_offset, 0.000001)


func test_diag_unfocus_restores_wide_and_clears_the_pane() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	train_scene.focus_car("dining", true)
	train_scene.set_pane(420.0)
	assert_eq(train_scene.zoom, "near")
	assert_gt(train_scene.camera.h_offset, 0.0)
	train_scene.focus_car("dining", false)
	assert_eq(train_scene.zoom, "wide")
	assert_almost_eq(train_scene.camera.size, 22.8192, 0.0001)
	assert_almost_eq(train_scene.cam_x, float(train_scene.car("dining")["x0"]) + Scene.CAR_LENGTH * 0.5, 0.001)
	train_scene.set_pane(0.0)
	assert_eq(train_scene.pane_px, 0.0)
	assert_eq(train_scene.camera.h_offset, 0.0)


func test_section_keeps_its_camera_and_drag() -> void:
	var train_scene: Scene = _scene()
	var cam: Camera3D = train_scene.camera
	assert_eq(train_scene.view_mode, "section")
	assert_eq(cam.size, Scene.CAM_NEAR)
	assert_almost_eq(cam.rotation_degrees.x, -8.0, 0.001)
	assert_almost_eq(cam.rotation_degrees.y, 0.0, 0.001)
	assert_almost_eq(cam.rotation_degrees.z, 0.0, 0.001)
	assert_eq(cam.h_offset, 0.0)
	train_scene.set_pane(420.0)
	train_scene.focus_car("dining", true)
	assert_eq(cam.size, Scene.CAM_NEAR, "section ignores the near argument")
	assert_eq(cam.h_offset, 0.0)
	train_scene.toggle_zoom()
	train_scene.focus_car("dining", true)
	assert_eq(cam.size, Scene.CAM_FAR)
	var before: float = train_scene.cam_x
	var view_h: float = train_scene.get_viewport().get_visible_rect().size.y
	train_scene.drag(Vector2(100.0, 80.0))
	assert_almost_eq(train_scene.cam_x, before - 100.0 * Scene.CAM_FAR / view_h, 0.001)
	var after_horizontal: float = train_scene.cam_x
	train_scene.drag(Vector2(0.0, 100.0))
	assert_almost_eq(train_scene.cam_x, after_horizontal, 0.001)
	train_scene.toggle_zoom()
	assert_eq(cam.size, Scene.CAM_NEAR)
	train_scene.set_view_mode("diag")
	train_scene.set_view_mode("section")
	assert_eq(cam.h_offset, 0.0)
	assert_eq(cam.size, Scene.CAM_NEAR)
	assert_almost_eq(cam.rotation_degrees.x, -8.0, 0.001)


func test_missing_camera_accepts_drag_pane_and_view_mode() -> void:
	var train_scene: Scene = Scene.new()
	autofree(train_scene)
	train_scene.drag(Vector2(30.0, 10.0))
	train_scene.set_pane(420.0)
	train_scene.set_view_mode("diag")
	train_scene.drag(Vector2(30.0, 10.0))
	assert_null(train_scene.camera)
	assert_eq(train_scene.view_mode, "diag")
	assert_eq(train_scene.pane_px, 420.0)
	train_scene.set_pane(-20.0)
	train_scene.set_view_mode("section")
	assert_eq(train_scene.pane_px, 0.0)
	assert_eq(train_scene.view_mode, "section")


func test_view_mode_accepts_only_diag_and_section() -> void:
	var train_scene: Scene = _scene({"view_mode": "unknown"})
	assert_eq(train_scene.view_mode, "section")
	train_scene.set_view_mode("diag")
	train_scene.set_view_mode("unknown")
	assert_eq(train_scene.view_mode, "diag")
	assert_almost_eq(train_scene.camera.size, Scene.DIAG_WIDE, 0.0001)
	train_scene.set_view_mode("section")
	assert_eq(train_scene.view_mode, "section")
	assert_eq(train_scene.camera.size, Scene.CAM_NEAR)


func test_diag_pose_can_be_set_outside_the_tree() -> void:
	var train_scene: Scene = Scene.new()
	autofree(train_scene)
	var cam: Camera3D = Camera3D.new()
	train_scene.add_child(cam)
	train_scene.camera = cam
	train_scene.set_view_mode("diag")
	assert_false(train_scene.is_inside_tree())
	assert_almost_eq(cam.rotation_degrees.x, -35.0, 0.5)
	assert_almost_eq(cam.rotation_degrees.y, 45.0, 0.5)
	assert_almost_eq(cam.rotation_degrees.z, 0.0, 0.5)


func test_diag_pane_recomputes_after_resize_scroll_and_layout() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	train_scene.set_pane(420.0)
	var viewport: SubViewport = train_scene.get_viewport() as SubViewport
	viewport.size = Vector2i(1280, 720)
	var expected_offset: float = 210.0 * Scene.DIAG_WIDE / 720.0
	assert_almost_eq(train_scene.camera.h_offset, expected_offset, 0.000001)
	train_scene.scroll(2.0)
	assert_almost_eq(train_scene.camera.h_offset, expected_offset, 0.000001)
	train_scene._rebuild_layout()
	assert_almost_eq(train_scene.camera.h_offset, expected_offset, 0.000001)
	var anchor: Vector3 = Vector3(train_scene.cam_x, Scene.DIAG_LOOK_Y, 0.0)
	var projected: Vector2 = train_scene.camera.unproject_position(anchor)
	assert_almost_eq(projected.x, (1280.0 - 420.0) / 2.0, 1.0)
	assert_almost_eq(projected.y, 360.0, 1.0)
