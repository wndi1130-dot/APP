extends GutTest
## The decorating view (decor_view.gd through train_scene.gd enter_decor): the eight cars a player
## dresses open with their grid and wall places and close as they were, and a finger finds the place under it.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const DecorGrid = preload("res://game/train/decor_grid.gd")
const DecorView = preload("res://game/train/decor_view.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
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
	assert_true(f.open_decor("guard"))
	assert_eq(f.train.decorating(), "guard")
	for n: CanvasItem in [f.gauges, f.plates, f.home]:
		if is_instance_valid(n):
			assert_false(n.visible, "%s away while decorating" % n.name)
	assert_false(f.open_decor("tail1"), "one car at a time")
	f.leave_decor()
	assert_eq(f.train.decorating(), "")
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
