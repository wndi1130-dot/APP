extends GutTest
## The decorating view (decor_view.gd through train_scene.gd enter_decor): the eight cars a player
## dresses open with their grid and wall places and close as they were, and a finger finds the place under it.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const DecorGrid = preload("res://game/train/decor_grid.gd")
const DecorView = preload("res://game/train/decor_view.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const DecorUiData = preload("res://game/ui/decor_ui_data.gd")
const DRESSED: Array[String] = ["tail1", "tail2", "tail3", "medtech", "guard", "front", "captain", "dining"]


func _scene() -> Scene:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1688, 780)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var s: Scene = Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": false, "baked_people": false, "view_mode": "diag"}
	viewport.add_child(s)
	return s


func _capsule(s: Scene) -> GeometryInstance3D:
	var found: Array = (s.people as Node).find_children("*", "GeometryInstance3D", true, false)
	return found[0] if not found.is_empty() else null


func test_every_car_to_decorate_opens_with_its_grid_and_closes_as_it_was() -> void:
	var s := _scene()
	var capsule := _capsule(s)
	assert_not_null(capsule, "the train has people to see through")
	for id: String in DRESSED:
		assert_true(s.enter_decor(id), id + " opens")
		assert_eq(s.decorating(), id)
		var c: Dictionary = s.car(id)
		var marks: Node3D = (c["node"] as Node3D).get_node_or_null("DecorMarks")
		assert_not_null(marks, id + ": its marks")
		if marks == null:
			continue
		var cells: MultiMeshInstance3D = marks.get_node("FloorCells")
		assert_eq(cells.multimesh.instance_count, DecorGrid.NX * DecorGrid.NZ, id + ": a mark for every floor cell")
		var walls := 0
		for child: Node in marks.get_children():
			if child.name.begins_with("Wall_"):
				walls += 1
		assert_eq(walls, int(DecorGrid.of(id)["wall_free"]), id + ": a square for every wall place")
		assert_false((c["front_wall"] as Node3D).visible, id + ": the front wall away")
		assert_true(s.life.rooms[id].dress == null or s.life.rooms[id].dress.visible, id + ": its small things shown")
		if capsule != null:
			assert_almost_eq(capsule.transparency, DecorView.PEOPLE_FADE, 0.001, "the people seen through")
		assert_ne(s.camera.v_offset, 0.0, id + ": the car raised into the band over the strip")
	var last: Dictionary = s.car(DRESSED[-1])
	s.exit_decor()
	await wait_physics_frames(1)
	assert_eq(s.decorating(), "")
	assert_null((last["node"] as Node3D).get_node_or_null("DecorMarks"), "the marks gone")
	for id: String in DRESSED:
		assert_true((s.car(id)["front_wall"] as Node3D).visible, id + ": the front wall back on the diagonal")
	if capsule != null:
		assert_almost_eq(capsule.transparency, 0.0, 0.001, "the people as they were")
	assert_eq(s.camera.v_offset, 0.0, "the train's own camera")


func test_only_the_cars_to_decorate() -> void:
	var s := _scene()
	for id: String in ["store", "cold", "loco", "nowhere"]:
		assert_false(s.enter_decor(id), id + " has no decor cells")
	assert_eq(s.decorating(), "")
	s.exit_decor()
	assert_eq(s.decorating(), "", "leaving with nothing open does nothing")


## Every translucent mark draws before the faded people, while still testing solid depth.
func test_marks_draw_before_the_faded_people() -> void:
	var s := _scene()
	assert_true(s.enter_decor("guard"))
	s.decor.set_surfaces([{"at": Vector3(8.0, 1.0, 0.0), "size": Vector2(0.5, 0.5)}])
	var marks: Node3D = s.decor.marks
	for geo: Node in marks.find_children("*", "GeometryInstance3D", true, false):
		var material := (geo as GeometryInstance3D).material_override as StandardMaterial3D
		assert_not_null(material, String(geo.name) + " has a mark material")
		if material != null:
			assert_lt(material.render_priority, 0, String(geo.name) + " before the people")
			assert_false(material.no_depth_test, String(geo.name) + " respects solid depth")
	s.exit_decor()


## Rebuilding must close the old view before freeing the car it holds.
func test_rebuilding_the_layout_closes_decorating() -> void:
	var s := _scene()
	assert_true(s.enter_decor("guard"))
	var old_car: Node3D = s.car("guard")["node"]
	s._rebuild_layout()
	assert_eq(s.decorating(), "", "the view closed before the old train was freed")
	assert_false(is_instance_valid(old_car), "the old car was freed")
	assert_null((s.car("guard")["node"] as Node3D).get_node_or_null("DecorMarks"))
	s._apply_highlight()
	s._place_camera()
	assert_eq(s.camera.v_offset, 0.0, "the train's camera no longer uses the old car")


## New bodies, their held props and reattached subtrees share the same original-value ledger.
func test_people_added_while_decorating_fade_and_restore() -> void:
	var s := _scene()
	assert_true(s.enter_decor("guard"))
	var body := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.transparency = 0.2
	body.add_child(mesh)
	s.people.add_child(body)
	assert_almost_eq(mesh.transparency, DecorView.PEOPLE_FADE, 0.001, "a new body's mesh fades")
	var prop := MeshInstance3D.new()
	prop.transparency = 0.35
	body.add_child(prop)
	assert_almost_eq(prop.transparency, DecorView.PEOPLE_FADE, 0.001, "a later held prop fades")
	var outside := MeshInstance3D.new()
	outside.transparency = 0.15
	s.add_child(outside)
	assert_almost_eq(outside.transparency, 0.15, 0.001, "geometry outside People is unchanged")
	s.people.remove_child(body)
	s.people.add_child(body)
	assert_almost_eq(mesh.transparency, DecorView.PEOPLE_FADE, 0.001, "reattaching keeps the body faded")
	var gone := MeshInstance3D.new()
	body.add_child(gone)
	gone.free()
	s.exit_decor()
	assert_almost_eq(mesh.transparency, 0.2, 0.001, "the first body value is restored")
	assert_almost_eq(prop.transparency, 0.35, 0.001, "the prop's original value is restored")
	var after := MeshInstance3D.new()
	after.transparency = 0.45
	body.add_child(after)
	assert_almost_eq(after.transparency, 0.45, 0.001, "no listener fades new things after exit")


## A rejected destination or a council lock leaves the already open view intact.
func test_a_rejected_car_keeps_the_current_decorating_view() -> void:
	var s := _scene()
	assert_true(s.enter_decor("guard"))
	var view = s.decor
	var camera_was: Transform3D = s.camera.transform
	assert_true(s.can_enter_decor("tail1"), "checking another car does not close this one")
	for id: String in ["store", "cold", "loco", "nowhere"]:
		assert_false(s.can_enter_decor(id))
		assert_false(s.enter_decor(id))
		assert_eq(s.decorating(), "guard", id + " leaves the car open")
		assert_same(s.decor, view, id + " keeps the same view")
		assert_eq(s.camera.transform, camera_was, id + " keeps the camera")
	var phase_was: String = s.phase()
	s.rules["train"]["phase"] = "council"
	assert_false(s.can_enter_decor("tail1"))
	assert_false(s.enter_decor("tail1"))
	assert_eq(s.decorating(), "guard", "the council lock does not close the view")
	assert_same(s.decor, view)
	s.rules["train"]["phase"] = phase_was
	s.exit_decor()


## Failed preflight must not queue an open room for deletion.
func test_the_flow_keeps_an_open_room_when_decorating_is_rejected() -> void:
	var f = SliceFlow.new()
	autofree(f)
	f.train = _scene()
	var room := Control.new()
	autofree(room)
	f.shop = room
	assert_eq(DecorUiData.lock_reason(f.train_g, false), "", "no domestic lock: the train's own check is what refuses")
	for id: String in ["store", "cold", "loco", "nowhere"]:
		assert_false(f.open_decor(id))
		assert_same(f.shop, room, id + " keeps the room")
		assert_false(room.is_queued_for_deletion(), id + " leaves the room alive")
	f.train.rules["train"]["phase"] = "council"
	assert_false(f.open_decor("guard"), "the train's council lock is checked too")
	assert_same(f.shop, room)
	assert_false(room.is_queued_for_deletion())
	assert_eq(f.decor_id, "")


## Identical situations leave the rules object alone; a changed community is applied once.
func test_decor_situation_sync_skips_unchanged_communities() -> void:
	var f = SliceFlow.new()
	autofree(f)
	f.train = _scene()
	var start: Array = SliceFlow.start_board()
	f.train_g = start[0]
	f.train_t = start[1]
	f._sync_decor_situation()
	var rules_was: Dictionary = f.train.rules
	watch_signals(f.train)
	f._sync_decor_situation()
	assert_true(is_same(f.train.rules, rules_was), "unchanged situations do not copy the rules")
	assert_signal_emit_count(f.train, "rules_applied", 0, "no unchanged community is reapplied")
	var comm: String = String(f.train_g["comms"].keys()[0])
	var expected: Array = (f.train.rules["comms"][comm]["sit"] as Array).duplicate()
	f.train.rules["comms"][comm]["sit"][0] = 0.0 if float(expected[0]) > 0.0 else 1.0
	f._sync_decor_situation()
	assert_eq(f.train.rules["comms"][comm]["sit"], expected, "the changed situation is restored")
	assert_false(is_same(f.train.rules, rules_was), "the changed situation replaces the rules")
	assert_signal_emit_count(f.train, "rules_applied", 1, "only the changed community is applied")


func test_a_finger_finds_the_place_under_it() -> void:
	var s := _scene()
	assert_true(s.enter_decor("guard"))
	var node: Node3D = s.car("guard")["node"]
	for cell: Array in [[3, 0], [15, 2], [27, 4], [0, 1], [30, 3]]:
		var at: Vector3 = DecorGrid.floor_center(cell[0], cell[1]) + Vector3(0.0, 0.012, 0.0)
		var screen: Vector2 = s.camera.unproject_position(node.to_global(at))
		assert_eq(s.decor_pick(screen), {"spot": "floor", "at": [cell[0], cell[1]]}, "floor %s" % [cell])
	var back: String = DecorGrid.of("guard")["back_wall"]
	var ix: int = back.find(".")
	assert_gte(ix, 0, "the guard car has a back wall place")
	for at: Array in [[ix, -1], [-1, 0], [-1, 1], [DecorGrid.NX, 0], [DecorGrid.NX, 1]]:
		var screen: Vector2 = s.camera.unproject_position(node.to_global(DecorView.place_of("wall", at).origin))
		assert_eq(s.decor_pick(screen), {"spot": "wall", "at": at}, "wall %s" % [at])
	assert_eq(s.decor_pick(Vector2(2.0, 2.0)), {}, "nothing over the sky")
	s.decor_hover("floor", [15, 2], false)
	var cursor: MeshInstance3D = node.get_node("DecorMarks/DecorCursor")
	assert_true(cursor.visible)
	assert_eq((cursor.material_override as StandardMaterial3D).albedo_color, DecorView.NO_COLOR, "red where it may not go")
	s.decor_hover("")
	assert_false(cursor.visible)


## Opened again in the same frame (one car, another, the first again): the marks keep their name.
func test_a_car_opened_again_at_once_keeps_its_marks() -> void:
	var s := _scene()
	assert_true(s.enter_decor("guard"))
	assert_true(s.enter_decor("tail1"))
	assert_true(s.enter_decor("guard"))
	var node: Node3D = s.car("guard")["node"]
	assert_not_null(node.get_node_or_null("DecorMarks/DecorCursor"), "the marks under their own name")
	await wait_physics_frames(1)
	assert_not_null(node.get_node_or_null("DecorMarks/DecorCursor"), "still there once the old ones are freed")
	assert_null((s.car("tail1")["node"] as Node3D).get_node_or_null("DecorMarks"), "none left in the car between")


## From the side view too: the shell cut as on the diagonal, and the camera kept to the window.
func test_decorating_from_the_side_view_cuts_the_shell_and_follows_the_window() -> void:
	var s := _scene()
	s.set_view_mode("section")
	assert_true(s.enter_decor("guard"))
	var c: Dictionary = s.car("guard")
	for top: Node3D in c.get("shell_top", []):
		assert_false(top.visible, "the shell over 2.2 m away while decorating")
	var viewport := s.get_viewport() as SubViewport
	viewport.size = Vector2i(1280, 720)
	await wait_physics_frames(1)
	assert_almost_eq(s.camera.size, 720.0 / (1280.0 / DecorView.WIDTH_M), 0.01, "the car still fills the new width")
	s.exit_decor()
	for top: Node3D in c.get("shell_top", []):
		assert_true(top.visible, "the side view's shell back")


## A car turned or moved in the train is seen the same: its length across the screen, the finger right.
func test_a_turned_car_is_seen_along_its_length() -> void:
	var s := _scene()
	var node: Node3D = s.car("guard")["node"]
	node.rotation.y = PI * 0.5
	node.position += Vector3(0.0, 0.0, 3.0)
	assert_true(s.enter_decor("guard"))
	var a: Vector2 = s.camera.unproject_position(node.to_global(Vector3(0.0, 0.0, 0.0)))
	var b: Vector2 = s.camera.unproject_position(node.to_global(Vector3(16.0, 0.0, 0.0)))
	assert_almost_eq(b.x - a.x, 1688.0 * 16.0 / DecorView.WIDTH_M, 2.0, "the car's length across the screen")
	assert_almost_eq(b.y, a.y, 1.0, "level")
	var at: Vector3 = DecorGrid.floor_center(15, 2) + Vector3(0.0, 0.012, 0.0)
	assert_eq(s.decor_pick(s.camera.unproject_position(node.to_global(at))), {"spot": "floor", "at": [15, 2]})


## The slice's way in and out (slice_flow.gd open_decor, leave_decor): not over a paper open to choose
## on; the gauges, plates and keys away while decorating and back after, the car still picked. The
## captain's and the dining car, with no people of their own, are picked by their plates too (결정 513).
func test_the_flow_opens_a_car_to_decorate_and_brings_the_train_back() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(f)
	await get_tree().process_frame
	f.train.set_view_mode("diag")
	assert_true(is_instance_valid(f.paper), "the first run brings a paper")
	assert_false(f.open_decor("guard"), "not while a paper is open to choose on")
	f.paper.set_folded(true)
	var weather_was: bool = f.weather.visible
	assert_true(f.open_decor("guard"))
	assert_eq(f.train.decorating(), "guard")
	for n: CanvasItem in [f.gauges, f.plates, f.home, f.weather]:
		if is_instance_valid(n):
			assert_false(n.visible, "%s away while decorating" % n.name)
	assert_false(f.open_decor("tail1"), "one car at a time")
	f.leave_decor()
	assert_eq(f.train.decorating(), "")
	assert_eq(f.weather.visible, weather_was, "the snow back as it was")
	for n: CanvasItem in [f.gauges, f.plates, f.home]:
		if is_instance_valid(n):
			assert_true(n.visible, "%s back" % n.name)
	assert_eq(f.sel, "guard", "the car still picked")
	for id: String in ["captain", "dining"]:
		var plate: Control = f.plates.get_node_or_null("Plate_" + id)
		assert_not_null(plate, id + " has a plate")
		if plate != null:
			assert_eq(plate.mouse_filter, Control.MOUSE_FILTER_STOP, id + "'s plate picks it")
		f._select(id)
		assert_eq(f.sel, id, id + " is picked")
		assert_true(f.open_decor(id), id + " opens to decorate")
		f.leave_decor()
	f._select("store")
	assert_eq(f.sel, "", "a car with nobody and nothing to decorate is not picked")
	# The train rebuilding its layout closes decorating; the flow's pane and screens follow next frame.
	assert_true(f.open_decor("guard"))
	f.train._rebuild_layout()
	assert_eq(f.train.decorating(), "")
	await get_tree().process_frame
	assert_eq(f.decor_id, "", "the flow is no longer decorating")
	assert_null(f.decor_pane, "the decorating pane is gone")
	for n: CanvasItem in [f.gauges, f.plates, f.home]:
		if is_instance_valid(n):
			assert_true(n.visible, "%s back after the rebuild" % n.name)
