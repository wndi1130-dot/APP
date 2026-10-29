extends "res://addons/gut/test.gd"
## The land going by the train as laid (결정 495): the K1 pieces stand nothing tall
## between the camera and the cars, a neutral piece is bare, no closed wagon and no
## one by the wagons, the land keeps up with the train and frees what is behind it
## however long it runs, and the stop scene's corridor lays the same kit (K1 only so far).

const Journey = preload("res://game/train/journey/journey.gd")
const Kit = preload("res://game/train/journey/journey_kit.gd")
const Corridor = preload("res://game/train/journey/journey_corridor.gd")
const Wagons = preload("res://game/train/journey/journey_wagons.gd")
const Route = preload("res://game/train/journey/journey_route.gd")
const Director = preload("res://game/train/journey/journey_director.gd")

const LOOK: Dictionary = {"band": "day", "snow_level": 0, "wet_ground": 1.0, "season": "late_autumn", "fall": 0.0, "ice": 1.0, "kinds": ["overcast"]}


## A stand-in for the train scene: as long as the slice's train, running, its camera on
## the guard car, the diagonal view (train_scene view_mode).
class FakeTrain:
	extends Node3D
	var cam_x: float = 127.0
	var run: bool = true
	var view_mode: String = "diag"

	func running() -> bool:
		return run

	func train_length() -> float:
		return 220.0


func _instances(node: Node) -> Array:
	var out: Array = []
	for n in node.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		var h: float = mm.mesh.get_aabb().size.y if mm.mesh != null else 0.0
		for i in mm.instance_count:
			var t: Transform3D = mmi.transform * mm.get_instance_transform(i)
			out.append({"name": String(mmi.name), "at": t.origin, "tall": h * t.basis.get_scale().y})
	return out


func test_each_k1_piece_is_laid_and_keeps_the_camera_side_low() -> void:
	for kind: String in ["wood", "lake", "field", "village"]:
		for s: int in 6:
			var node: Node3D = Kit.build(kind, 600.0 * s, 600.0 * s + 120.0, {"seed": 40 + s, "mirror": s % 2 == 1}, LOOK, {"chunk": s % 3})
			add_child_autofree(node)
			var stood: Array = _instances(node)
			assert_gt(stood.size(), 10, "%s piece %d has things standing on it" % [kind, s])
			for e: Dictionary in stood:
				var at: Vector3 = e["at"]
				if at.z > 0.0 and at.z < Kit.NEAR_CLEAR:
					assert_lte(float(e["tall"]), Kit.NEAR_LOW + 0.05, "%s: %s %.1f m tall %.1f m out on the camera's side" % [kind, e["name"], float(e["tall"]), at.z])
			assert_not_null(node.get_node_or_null("Ground"), kind + " lays its ground")


func test_a_neutral_piece_is_bare() -> void:
	for kind: String in ["wood", "lake", "field"]:
		for s: int in 8:
			var node: Node3D = Kit.build(kind, 120.0 * s, 120.0 * s + 120.0, {"seed": 70 + s, "mirror": s % 2 == 0}, LOOK, {"neutral": true, "chunk": 1})
			add_child_autofree(node)
			assert_eq(int(node.get_meta("houses", 0)), 0, "no house, barn, hut or church in the border fields")
			for e: Dictionary in _instances(node):
				for banned: String in ["boat_on_blocks", "overturned_boat", "pier_deck", "mooring_post", "farm_cart", "hay_cart", "car", "pickup_truck", "wrecked_car_cluster", "signal_post"]:
					assert_false(String(e["name"]).begins_with(banned + "_"), "%s laid in a neutral %s piece" % [banned, kind])


func test_the_village_has_its_church_once_a_section() -> void:
	var churches: int = 0
	for s: int in 30:
		for chunk: int in 4:
			var node: Node3D = Kit.build("village", 0.0, 120.0, {"seed": 900 + s}, LOOK, {"chunk": chunk})
			add_child_autofree(node)
			churches += int(node.get_meta("churches", 0)) if chunk != 1 else 0
	assert_eq(churches, 0, "a church only in a section's second piece")


func test_the_wagons_left_on_the_siding_are_open_or_flat_and_far_side() -> void:
	for kind: String in Wagons.STRINGS:
		for w: String in Wagons.STRINGS[kind]:
			assert_true(w in ["wagon_coal", "wagon_open", "wagon_flat", "wagon_tender"], "only open, flat and coal wagons: " + w)
	assert_lt(Wagons.SIDING_Z, -3.0, "the siding is on the far side of the line")


func test_the_land_keeps_up_with_the_train_and_frees_what_is_behind() -> void:
	var host := FakeTrain.new()
	add_child_autofree(host)
	var j: Node3D = Journey.attach(host, host, LOOK, 1, {"seed": 3, "remember": false})
	j.calm = true
	for i in int(60.0 * 12.0 / 0.1):
		j.step(0.1)
		if i % 600 == 0:
			var first: Dictionary = j.chunks[0]
			var last: Dictionary = j.chunks[-1]
			assert_lte(float(first["s0"]) - j.travelled, -Journey.MARGIN, "land behind the tail")
			assert_gte(float(last["s1"]) - j.travelled, host.train_length() + Journey.MARGIN, "land ahead of the engine")
	assert_lte(j.chunks.size(), 9, "what passed behind is freed")
	assert_lte(absf(j.land.position.x), Journey.REBASE_M + 1.0, "the land's place stays small (rebased)")
	assert_gt(j.travelled, 5000.0, "it ran")
	for c: Dictionary in j.chunks:
		var n: Node3D = c["node"]
		assert_lte(absf(n.position.x), Journey.REBASE_M * 2.0 + 400.0)


func test_on_the_side_on_screen_it_waits_unseen_and_lays_nothing() -> void:
	var host := FakeTrain.new()
	host.view_mode = "section"
	add_child_autofree(host)
	var j: Node3D = Journey.attach(host, host, LOOK, 1, {"seed": 2, "remember": false})
	await wait_process_frames(3)
	assert_false(j.visible)
	assert_eq(j.chunks.size(), 0, "nothing laid where it is not seen")
	assert_true(j.handoff().is_empty(), "the stop scene then goes by the stretch")
	host.view_mode = "diag"
	await wait_until(func() -> bool: return j.visible, 5.0)
	assert_true(j.visible, "shown once the land worked out reaches past the train")
	assert_gte(j.laid_to - j.travelled, host.train_length() + Journey.MARGIN)
	assert_gt(j.chunks.size(), 2, "the diagonal view on: the land laid round the train")


## The kit's pieces as data on a worker (Kit.plan) are the pieces worked out here,
## and their buffers lay each instance as MultiMesh.set_instance_transform would.
func test_a_piece_worked_out_on_a_worker_is_the_piece_worked_out_here() -> void:
	Kit.warm()
	for kind: String in ["wood", "lake", "field", "village"]:
		var sec: Dictionary = {"seed": 77, "mirror": true}
		var here: Dictionary = Kit.plan(kind, 240.0, 360.0, sec, LOOK, {"chunk": 2})
		var box: Dictionary = {}
		var task: int = WorkerThreadPool.add_task(func() -> void: box["plan"] = Kit.plan(kind, 240.0, 360.0, sec, LOOK, {"chunk": 2}))
		WorkerThreadPool.wait_for_task_completion(task)
		var there: Dictionary = box["plan"]
		assert_eq((there["props"] as Dictionary).keys(), (here["props"] as Dictionary).keys(), kind + ": the same models a block")
		for key: String in here["props"]:
			assert_eq(there["props"][key]["buffer"], here["props"][key]["buffer"], "%s %s: the same places" % [kind, key])
		assert_eq(there["ground"], here["ground"], kind + ": the same ground")
		assert_eq(int(there["houses"]), int(here["houses"]))
	var t := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3(1.3, 1.3, 1.3)) * Basis(Vector3.RIGHT, 0.02), Vector3(12.5, -0.85, -18.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# A mesh, as the kit's have: a drawing renderer will not keep a MultiMesh with none.
	mm.mesh = BoxMesh.new()
	mm.instance_count = 1
	mm.set_instance_transform(0, t)
	var want: PackedFloat32Array = mm.buffer
	gut.p("MultiMesh buffer read back: %d floats" % want.size())
	if want.is_empty():
		pass_test("this renderer keeps no MultiMesh buffer to read back (headless): the places above still match")
		return
	var packed: PackedFloat32Array = Kit._prop_buffers({"props": {"spruce|0": [t]}})["spruce|0"]["buffer"]
	assert_eq(packed.size(), want.size())
	for i in want.size():
		assert_almost_eq(packed[i], want[i], 0.0001, "float %d of the 3x4 matrix" % i)


## Worked out on workers or here, the same land in the same order.
func test_the_land_worked_out_ahead_is_the_land_laid_here() -> void:
	var lands: Array = []
	for sync: bool in [true, false]:
		var host := FakeTrain.new()
		add_child_autofree(host)
		var j: Node3D = Journey.attach(host, host, LOOK, 1, {"seed": 21, "remember": false, "sync": sync})
		j.calm = true
		var laid: Array = []
		for i in 2400:
			j.step(0.1)
			_note_laid(j, laid)
		# What a worker is still on is made too (stepped straight through, the last may not
		# be done): both have worked out as far.
		while not j._planned.is_empty():
			j._make_next(true)
		_note_laid(j, laid)
		var last_s1: float = -INF
		for c: Dictionary in j.chunks:
			if last_s1 > -INF:
				assert_almost_eq(float(c["s0"]), last_s1, 0.001, "no gap and no overlap between pieces")
			last_s1 = float(c["s1"])
		lands.append(laid)
	assert_gt((lands[1] as Array).size(), 10)
	assert_eq(lands[0], lands[1])


static func _note_laid(j: Node3D, laid: Array) -> void:
	for c: Dictionary in j.chunks:
		var row: String = "%d %d %s %s" % [int(c["s0"]), int(c["s1"]), String(c["kind"]), String((c["node"] as Node3D).name)]
		if not laid.has(row):
			laid.append(row)


func test_no_event_while_a_card_is_up_and_some_when_not() -> void:
	var host := FakeTrain.new()
	add_child_autofree(host)
	var j: Node3D = Journey.attach(host, host, LOOK, 1, {"seed": 11, "remember": false})
	j.quiet = true
	for i in int(600.0 / 0.1):
		j.step(0.1)
	assert_eq(j.director.started.size(), 0, "ten minutes under a card: no event")
	j.quiet = false
	for i in int(900.0 / 0.1):
		j.step(0.1)
	assert_gt(j.director.started.size(), 3, "a quarter hour without one: several")


## Stretch 2 runs into the border fields at 18 km: a card put away there moves the land
## on, and what was laid ahead of the view for the window before goes.
func test_a_border_field_window_takes_back_the_land_laid_ahead_out_of_sight() -> void:
	var dropped_villages: int = 0
	for s: int in 20:
		var host := FakeTrain.new()
		add_child_autofree(host)
		var j: Node3D = Journey.attach(host, host, LOOK, 2, {"seed": 40 + s, "remember": false})
		j.calm = true
		for i in 150 + 37 * s:
			j.step(0.1)
		var keep_to: float = j.travelled + host.cam_x + Journey.SIGHT_M
		for c: Dictionary in j.chunks:
			if float(c["s0"]) >= keep_to and String(c["kind"]) == "village":
				dropped_villages += 1
		j.next_window()
		assert_true(bool(j.window()["neutral"]), "seed %d: the border fields" % s)
		for c: Dictionary in j.chunks:
			assert_lt(float(c["s0"]), keep_to, "seed %d: nothing of the window before left out of sight ahead" % s)
		var cut: float = j.laid_to
		for i in 600:
			j.step(0.1)
		for c: Dictionary in j.chunks:
			if float(c["s0"]) >= cut:
				assert_ne(String(c["kind"]), "village", "seed %d: no village in the border fields" % s)
				assert_eq(int((c["node"] as Node3D).get_meta("houses", 0)), 0, "seed %d: no house laid there" % s)
	assert_gt(dropped_villages, 0, "some village laid ahead was taken back (the case is met)")


## A card opened and put away while the train stood (at a stop): once it runs again the
## next event still waits AFTER_CARD of running time.
func test_a_card_put_away_while_the_train_stood_still_holds_the_next_event_off() -> void:
	var host := FakeTrain.new()
	add_child_autofree(host)
	var j: Node3D = Journey.attach(host, host, LOOK, 1, {"seed": 11, "remember": false})
	host.run = false
	for i in 200:
		j.step(0.1)
	assert_lt(j.speed, 0.5, "it has stopped")
	j.quiet = true
	for i in 50:
		j.step(0.1)
	j.director.due = 0.0
	j.quiet = false
	for i in 50:
		j.step(0.1)
	var put_away: float = j.clock
	var before: int = j.director.started.size()
	host.run = true
	for i in 900:
		j.step(0.1)
		if j.director.started.size() > before:
			break
	assert_gt(j.director.started.size(), before, "an event comes once it runs again")
	var first: Dictionary = j.director.started[before]
	assert_gte(float(first["at"]) - put_away, Director.AFTER_CARD.x, "not inside AFTER_CARD of the card put away")


func test_the_stop_corridor_lays_the_same_kit_and_only_where_there_is_one() -> void:
	var c = Corridor.make({}, 1, 1)
	assert_not_null(c, "K1 has its kit")
	var world := Node3D.new()
	add_child_autofree(world)
	var x: float = -200.0
	while x < 240.0:
		c.lay(world, x, x + 60.0, 0.0, 0.3)
		x += 60.0
	assert_gt(world.get_child_count(), 6)
	for n in world.get_children():
		assert_null((n as Node).get_node_or_null("Ground"), "the stop scene keeps its own ground")
	assert_null(Corridor.make({}, 11, 1), "K4 has no kit yet: the stop scene's own corridor")
	# The section the train's screen was laying goes on first, then the order from its history.
	var carried: int = 0
	for s: int in 6:
		var host := FakeTrain.new()
		add_child_autofree(host)
		var j: Node3D = Journey.attach(host, host, LOOK, 1, {"seed": 5 + s, "remember": false})
		for i in 40 * s:
			j.step(0.1)
		var hand: Dictionary = j.handoff()
		var went_on = Corridor.make(hand, 1, 5)
		assert_not_null(went_on)
		assert_eq((went_on.seq.history as Array).size(), (j.seq.history as Array).size(), "the order goes on from the train's screen")
		if float(hand["section_left_m"]) <= 0.5:
			continue
		carried += 1
		var road := Node3D.new()
		add_child_autofree(road)
		went_on.lay(road, -40.0, 20.0, 0.0, 0.3)
		var kind: String = String(j._section["kind"])
		assert_true(String(road.get_child(0).name).begins_with("Land_%s_" % kind), "seed %d: the stop's first piece goes on with the train's %s" % [s, kind])
		assert_eq(int(went_on._section["seed"]), int(j._section["seed"]), "the same dressing")
	assert_gt(carried, 0, "a section was under way at the cut in some seed")
