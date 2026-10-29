extends "res://addons/gut/test.gd"
## The diagonal camera keeps its target in the clear part of the viewport;
## dragging follows the projected train axis, while section keeps its old view.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Interior = preload("res://game/train/train_interior.gd")


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


## A folded paper's edge at the left (결정 508): the anchor sits in the middle of what
## the edge and the pane leave.
func test_diag_folded_paper_edge_shifts_the_anchor_right() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	var view_size: Vector2 = train_scene.get_viewport().get_visible_rect().size
	train_scene.focus_car("dining", true)
	train_scene.set_pane(420.0, 110.0)
	assert_eq(train_scene.pane_left_px, 110.0)
	var anchor: Vector3 = Vector3(train_scene.cam_x, Scene.DIAG_LOOK_Y, 0.0)
	var projected: Vector2 = train_scene.camera.unproject_position(anchor)
	assert_almost_eq(projected.x, (110.0 + view_size.x - 420.0) / 2.0, 1.0)
	train_scene.set_pane(420.0)
	assert_eq(train_scene.pane_left_px, 0.0, "the right pane alone clears the edge")


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
	var train_scene: Scene = _scene({"view_mode": "section"})
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
	assert_eq(train_scene.view_mode, "diag", "an unknown name falls back to the default")
	train_scene.set_view_mode("section")
	train_scene.set_view_mode("unknown")
	assert_eq(train_scene.view_mode, "section")
	assert_eq(train_scene.camera.size, Scene.CAM_NEAR)
	train_scene.set_view_mode("diag")
	assert_eq(train_scene.view_mode, "diag")
	assert_almost_eq(train_scene.camera.size, Scene.DIAG_WIDE, 0.0001)


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


func test_a_resize_keeps_a_section_frame_set_by_hand() -> void:
	# The council frames the dining car close by hand (slice_flow _frame_dining_car).
	var train_scene: Scene = _scene({"view_mode": "section"})
	var cam: Camera3D = train_scene.camera
	cam.size = 4.2
	cam.position.y += 1.5
	var framed: Vector3 = cam.position
	var viewport: SubViewport = train_scene.get_viewport() as SubViewport
	viewport.size = Vector2i(1280, 720)
	assert_almost_eq(cam.size, 4.2, 0.0001, "a window resize does not undo the council's frame")
	assert_eq(cam.position, framed)


func test_the_diag_pane_offset_is_none_outside_the_tree() -> void:
	var train_scene: Scene = Scene.new()
	autofree(train_scene)
	var cam: Camera3D = Camera3D.new()
	train_scene.add_child(cam)
	train_scene.camera = cam
	train_scene.set_view_mode("diag")
	train_scene.set_pane(420.0)
	assert_eq(cam.h_offset, 0.0, "no view to measure the pane against")


func _assert_shell_view(train_scene: Scene, diagonal: bool) -> void:
	var pipe_count: int = 0
	for c: Dictionary in train_scene.cars:
		var top_parts: Array = c["shell_top"]
		assert_false(top_parts.is_empty(), c["id"])
		for top_node: Node3D in top_parts:
			assert_eq(top_node.visible, not diagonal, String(c["id"]) + "/" + String(top_node.name))
		for shell_material: StandardMaterial3D in c["shell_mats"]:
			assert_eq(shell_material.cull_mode, BaseMaterial3D.CULL_DISABLED if diagonal else BaseMaterial3D.CULL_BACK, c["id"])
		if c.has("stove_light"):
			pipe_count += 1
			var car_node: Node3D = c["node"]
			var pipe_top: MeshInstance3D = car_node.get_node("StovePipeTop") as MeshInstance3D
			var pipe_low: MeshInstance3D = car_node.get_node("StovePipeLow") as MeshInstance3D
			assert_true(top_parts.has(pipe_top), c["id"])
			assert_true(pipe_low.visible)
			assert_almost_eq(pipe_top.position.y - (pipe_top.mesh as BoxMesh).size.y * 0.5, Scene.SHELL_CUT_Y, 0.0001)
			assert_almost_eq(pipe_low.position.y + (pipe_low.mesh as BoxMesh).size.y * 0.5, Scene.SHELL_CUT_Y, 0.0001)
	assert_gt(pipe_count, 0)


func test_diag_hides_shell_tops_and_stove_pipes_and_section_restores_them() -> void:
	var train_scene: Scene = _scene({"view_mode": "section"})
	_assert_shell_view(train_scene, false)
	train_scene.set_view_mode("diag")
	_assert_shell_view(train_scene, true)
	train_scene.set_view_mode("section")
	_assert_shell_view(train_scene, false)


func test_diag_shell_state_survives_layout_rebuild() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	_assert_shell_view(train_scene, true)
	train_scene._rebuild_layout()
	assert_eq(train_scene.view_mode, "diag")
	_assert_shell_view(train_scene, true)
	train_scene.set_view_mode("section")
	_assert_shell_view(train_scene, false)


func test_box_shell_fallback_hides_upper_walls_and_roof_in_diag() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	for variant: String in ["plain", "clean", "chief", "medic", "engine"]:
		train_scene._shells[Scene.SHELL_ROOT % variant] = null
	train_scene._rebuild_layout()
	for c: Dictionary in train_scene.cars:
		assert_null((c["node"] as Node3D).get_node_or_null("Shell"))
		assert_gte((c["shell_top"] as Array).size(), 8, c["id"])
		assert_false((c["shell_mats"] as Array).is_empty(), c["id"])
		for top_piece: MeshInstance3D in c["shell_top"]:
			assert_gte(top_piece.position.y - (top_piece.mesh as BoxMesh).size.y * 0.5, Scene.SHELL_CUT_Y - 0.0001)
			if top_piece.name != &"StovePipeTop":
				assert_true((c["shell_mats"] as Array).has(top_piece.get_active_material(0)), c["id"])
	_assert_shell_view(train_scene, true)
	train_scene.set_view_mode("section")
	_assert_shell_view(train_scene, false)


func _assert_front_view(train_scene: Scene, diagonal: bool) -> void:
	assert_eq(train_scene.backdrop.visible, not diagonal)
	assert_eq(train_scene.side_rail.visible, not diagonal)
	for c: Dictionary in train_scene.cars:
		var front: MeshInstance3D = c["front_wall"]
		assert_eq(front.visible, diagonal, c["id"])
		# Its own plain material among the car's, so the warmth and the shade reach it
		# without the shell's atlas stretched over a box.
		var front_material: StandardMaterial3D = front.material_override as StandardMaterial3D
		assert_true((c["shell_mats"] as Array).has(front_material))
		assert_ne(front_material, c.get("shell_mat"))
		assert_null(front_material.albedo_texture)
		var box: AABB = front.transform * front.get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.0001)
		assert_almost_eq(box.end.y, 0.9, 0.0001)
		assert_almost_eq(box.position.x, 0.1, 0.0001)
		assert_almost_eq(box.end.x, 15.9, 0.0001)
		assert_almost_eq(front.position.z, 1.40, 0.0001)
		assert_almost_eq(box.size.z, 0.06, 0.0001)


func test_diag_switches_front_walls_backdrop_and_side_rail() -> void:
	var train_scene: Scene = _scene({"view_mode": "section"})
	_assert_front_view(train_scene, false)
	train_scene.set_view_mode("diag")
	_assert_front_view(train_scene, true)
	train_scene._rebuild_layout()
	_assert_front_view(train_scene, true)
	train_scene.set_view_mode("section")
	_assert_front_view(train_scene, false)


func test_diag_snow_covers_till_the_journey_shows() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	var ground: MeshInstance3D = train_scene.snow_ground
	assert_true(ground.visible)
	var bounds: AABB = ground.transform * ground.get_aabb()
	assert_almost_eq(bounds.position.x, -60.0, 0.0001)
	assert_almost_eq(bounds.end.x, train_scene.train_length() + 60.0, 0.0001)
	assert_almost_eq(bounds.position.y, -1.46, 0.0001)
	assert_almost_eq(bounds.position.z, -46.0, 0.0001)
	assert_almost_eq(bounds.end.z, 46.0, 0.0001)
	var snow: StandardMaterial3D = ground.material_override as StandardMaterial3D
	assert_eq(snow.albedo_color, Color(0.72, 0.76, 0.82))
	assert_eq(snow.roughness, 1.0)
	assert_eq(snow.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	var journey: Node3D = Node3D.new()
	journey.name = "Journey"
	journey.visible = false
	train_scene.add_child(journey)
	train_scene._process(0.0)
	assert_true(ground.visible, "the snow covers while the land is still being laid")
	journey.visible = true
	assert_false(ground.visible, "gives way the moment the land shows, no frame with both")
	train_scene.set_view_mode("section")
	train_scene.set_view_mode("diag")
	assert_false(ground.visible, "no overlap on the mode change")
	journey.visible = false
	assert_true(ground.visible, "covers again when the land hides (a window change)")
	journey.free()
	train_scene._process(0.0)
	assert_true(ground.visible)
	train_scene.set_view_mode("section")
	assert_false(ground.visible)


func test_the_train_opens_on_the_diagonal_view() -> void:
	var train_scene: Scene = _scene()
	assert_eq(train_scene.view_mode, "diag", "no view_mode given: the inside from above (결정 486)")
	assert_almost_eq(train_scene.camera.size, Scene.DIAG_WIDE, 0.0001)
	assert_true(train_scene.snow_ground.visible)
	assert_false(train_scene.backdrop.visible)


func _assert_shell_shade(selected: Dictionary, other: Dictionary, shade: float) -> void:
	var selected_mats: Array = selected["shell_mats"]
	var other_mats: Array = other["shell_mats"]
	assert_eq(other_mats.size(), selected_mats.size())
	for material_index: int in mini(selected_mats.size(), other_mats.size()):
		var lit: Color = (selected_mats[material_index] as StandardMaterial3D).albedo_color
		var expected: Color = Color(lit.r * shade, lit.g * shade, lit.b * shade, lit.a)
		assert_true((other_mats[material_index] as StandardMaterial3D).albedo_color.is_equal_approx(expected))


func test_highlight_moves_one_band_and_keeps_the_warmth_multiplier() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	var selected: Dictionary = train_scene.car("tail1")
	var other: Dictionary = train_scene.car("tail2")
	var band: MeshInstance3D = train_scene.highlight_band
	var ring: Mesh = band.mesh
	assert_false(band.visible)
	train_scene.highlight("tail1")
	assert_true(band.visible)
	assert_eq(band.transform, (selected["node"] as Node3D).transform)
	assert_eq((band.material_override as StandardMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	# The outline runs along the wall tops: the front wall's at 0.9 m, the cut ones at 2.2 m.
	var bounds: AABB = band.get_aabb()
	assert_almost_eq(bounds.position.x, 0.0, 0.0001)
	assert_almost_eq(bounds.end.x, Scene.CAR_LENGTH, 0.0001)
	assert_almost_eq(bounds.position.y, 0.905, 0.0001)
	assert_almost_eq(bounds.end.y, Scene.SHELL_CUT_Y + 0.005, 0.0001)
	assert_almost_eq(bounds.position.z, -1.44, 0.0001)
	assert_almost_eq(bounds.end.z, 1.50, 0.0001)
	_assert_shell_shade(selected, other, 0.6)
	train_scene.highlight("tail1")
	_assert_shell_shade(selected, other, 0.6)
	var before_warmth: Color = (selected["shell_mats"][0] as StandardMaterial3D).albedo_color
	assert_true(train_scene.set_sit("tail", 0, 90.0))
	assert_ne((selected["shell_mats"][0] as StandardMaterial3D).albedo_color, before_warmth)
	_assert_shell_shade(selected, other, 0.6)
	train_scene.highlight("tail2")
	assert_eq(train_scene.highlight_band, band)
	assert_eq(band.mesh, ring)
	assert_eq(band.transform, (other["node"] as Node3D).transform)
	_assert_shell_shade(other, selected, 0.6)
	train_scene.highlight("")
	assert_false(band.visible)
	_assert_shell_shade(selected, other, 1.0)
	train_scene.highlight("tail1")
	train_scene.set_view_mode("section")
	assert_false(band.visible)
	_assert_shell_shade(selected, other, 1.0)
	for c: Dictionary in train_scene.cars:
		assert_false(bool(c["dimmed"]), c["id"])


func test_highlight_and_ground_follow_a_rebuilt_layout() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	train_scene.highlight("tail1")
	train_scene.rules["cars"].append({"id": "tail_extra", "kind": "comm", "comm": "tail", "name": "꼬리칸"})
	train_scene.apply_rules()
	var chosen: Dictionary = train_scene.car("tail1")
	assert_true(train_scene.highlight_band.visible)
	assert_eq(train_scene.highlight_band.transform, (chosen["node"] as Node3D).transform)
	_assert_shell_shade(chosen, train_scene.car("tail_extra"), 0.6)
	assert_almost_eq((train_scene.snow_ground.mesh as PlaneMesh).size.x, train_scene.train_length() + 120.0, 0.001)
	_assert_front_view(train_scene, true)


func test_box_shell_highlight_restores_the_section_palette() -> void:
	var train_scene: Scene = _scene({"view_mode": "section"})
	for variant: String in ["plain", "clean", "chief", "medic", "engine"]:
		train_scene._shells[Scene.SHELL_ROOT % variant] = null
	train_scene._rebuild_layout()
	train_scene.apply_rules()
	var other: Dictionary = train_scene.car("tail2")
	var original_colors: Array[Color] = []
	for shell_material: StandardMaterial3D in other["shell_mats"]:
		original_colors.append(shell_material.albedo_color)
	train_scene.set_view_mode("diag")
	train_scene.highlight("tail1")
	for material_index: int in original_colors.size():
		var dimmed: StandardMaterial3D = other["shell_mats"][material_index]
		var lit: Color = original_colors[material_index]
		assert_true(dimmed.albedo_color.is_equal_approx(Color(lit.r * 0.6, lit.g * 0.6, lit.b * 0.6, lit.a)))
	train_scene.set_view_mode("section")
	for material_index: int in original_colors.size():
		var restored: StandardMaterial3D = other["shell_mats"][material_index]
		assert_eq(restored.albedo_color, original_colors[material_index])


func test_car_screen_polygon_is_convex_and_contains_the_car_center() -> void:
	var train_scene: Scene = _scene({"view_mode": "diag"})
	train_scene.focus_car("dining")
	train_scene.set_pane(420.0)
	var polygon: PackedVector2Array = train_scene.car_screen_polygon("dining")
	assert_gte(polygon.size(), 3)
	if polygon.size() < 3:
		return
	var orientation: float = 0.0
	for corner: int in polygon.size():
		var a: Vector2 = polygon[corner]
		var b: Vector2 = polygon[(corner + 1) % polygon.size()]
		var next: Vector2 = polygon[(corner + 2) % polygon.size()]
		var turn: float = (b - a).cross(next - b)
		assert_gt(absf(turn), 0.0001)
		if orientation == 0.0:
			orientation = signf(turn)
		assert_eq(signf(turn), orientation)
	var car_node: Node3D = train_scene.car("dining")["node"]
	var center: Vector2 = train_scene.camera.unproject_position(car_node.to_global(Vector3(8.0, 1.0, 0.02)))
	assert_true(Geometry2D.is_point_in_polygon(center, polygon))
	assert_true(train_scene.car_screen_polygon("missing").is_empty())
	var saved_camera: Camera3D = train_scene.camera
	train_scene.camera = null
	assert_true(train_scene.car_screen_polygon("dining").is_empty())
	train_scene.camera = saved_camera


func _prop_bounds(prop_node: Node3D) -> AABB:
	var local_box: AABB = (prop_node as MeshInstance3D).get_aabb() if prop_node is MeshInstance3D else Interior._bounds_of(prop_node)
	return prop_node.transform * local_box


func test_diag_lowers_laundry_and_shortens_curtain_then_restores_both() -> void:
	var train_scene: Scene = _scene({"view_mode": "section"})
	var laundry: Node3D = train_scene.life.rooms["tail1"].props["laundry"]
	var curtain: Node3D = train_scene.life.rooms["cold"].props["curtain"]
	var laundry_original: Transform3D = laundry.transform
	var curtain_original: Transform3D = curtain.transform
	var laundry_box: AABB = _prop_bounds(laundry)
	var curtain_box: AABB = _prop_bounds(curtain)
	assert_gt(laundry_box.end.y, 2.2)
	assert_gt(curtain_box.end.y, 2.2)
	for _round: int in range(2):
		train_scene.set_view_mode("diag")
		var lowered: AABB = _prop_bounds(laundry)
		var shortened: AABB = _prop_bounds(curtain)
		assert_almost_eq(lowered.end.y, 2.15, 0.01)
		assert_almost_eq(shortened.end.y, 2.15, 0.01)
		assert_eq(laundry.transform.basis, laundry_original.basis)
		assert_almost_eq(shortened.position.y, curtain_box.position.y, 0.0001)
		assert_almost_eq(shortened.size.x, curtain_box.size.x, 0.0001)
		assert_almost_eq(shortened.size.z, curtain_box.size.z, 0.0001)
		train_scene.set_view_mode("section")
		assert_eq(laundry.transform, laundry_original)
		assert_eq(curtain.transform, curtain_original)
		assert_eq(_prop_bounds(laundry), laundry_box)
		assert_eq(_prop_bounds(curtain), curtain_box)
