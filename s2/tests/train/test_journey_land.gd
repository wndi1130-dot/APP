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

const LOOK: Dictionary = {"band": "day", "snow_level": 0, "wet_ground": 1.0, "season": "late_autumn", "fall": 0.0, "ice": 1.0, "kinds": ["overcast"]}


## A stand-in for the train scene: as long as the slice's train, running, its camera on the guard car.
class FakeTrain:
	extends Node3D
	var cam_x: float = 127.0
	var run: bool = true

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
	var host := FakeTrain.new()
	add_child_autofree(host)
	var j: Node3D = Journey.attach(host, host, LOOK, 1, {"seed": 5, "remember": false})
	var went_on = Corridor.make(j.handoff(), 1, 5)
	assert_not_null(went_on)
	assert_eq((went_on.seq.history as Array).size(), (j.seq.history as Array).size(), "the order goes on from the train's screen")
