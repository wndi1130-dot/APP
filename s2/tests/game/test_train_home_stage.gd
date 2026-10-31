extends GutTest
## A car's home stage (결정 486·517): the tier the domestic rules give each furnished car reaches
## the train screen (slice_flow.gd rules["train"]["home"] → train_scene.gd c["home_stage"]) and its
## light follows it (train_light.gd); the cars no one furnishes keep the default.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const TrainLight = preload("res://game/train/train_light.gd")
const TrainDecor = preload("res://game/train/train_decor.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Dom = preload("res://game/train/train_dom.gd")
const Mods = preload("res://game/train/train_mods.gd")
const KIT: String = "res://models/train_interior/catalog.json"


func _scene(home: Dictionary, daytime: String = "night") -> Scene:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1688, 780)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var s: Scene = Scene.new()
	s.rules = Rules.load_default()
	s.rules["view"]["daytime"] = daytime
	if not home.is_empty():
		s.rules["train"]["home"] = home
	s.opts = {"seed": 7, "panel": false, "baked_people": false, "view_mode": "diag"}
	viewport.add_child(s)
	return s


func test_each_car_takes_its_stage_and_its_light_follows() -> void:
	var s := _scene({"guard": 0, "front": 3})
	assert_eq(int(s.car("guard")["home_stage"]), 0)
	assert_eq(int(s.car("front")["home_stage"]), 3)
	for id: String in ["guard", "front"]:
		var c: Dictionary = s.car(id)
		var stage: int = int(c["home_stage"])
		assert_almost_eq(float(c["stove_share"]), float(TrainLight.spec(stage, "night")["stove"]), 0.0001, id + ": the stove's share by its stage")
		assert_true(c.get("lamp") is OmniLight3D, id + ": has its lamp")
		assert_almost_eq((c["lamp"] as OmniLight3D).omni_range, float(TrainLight.spec(stage, "night")["lamps"][0]["range"]), 0.0001, id + ": the lamp is its stage's")
	assert_ne(float(s.car("guard")["stove_share"]), float(s.car("front")["stove_share"]), "rags and nordic do not burn alike")


## The hour turning in the same scene keeps a rags car's candle reaching as far as its night plan:
## the lamp is built once and the hour only eases its colour and strength.
func test_a_rags_car_built_by_day_reaches_its_night_range_after_dark() -> void:
	var s := _scene({"guard": 0}, "day")
	assert_true(s.set_value("view.daytime", "night"), "the hour turns")
	var c: Dictionary = s.car("guard")
	assert_eq(TrainLight.daytime_of(s.rules.get("view", {})), "night")
	assert_almost_eq((c["lamp"] as OmniLight3D).omni_range, float(TrainLight.spec(0, "night")["lamps"][0]["range"]), 0.0001, "the candle's night reach")
	assert_gt(float(c["lamp_energy"]), 0.0, "the candle is lit after dark")


func test_a_car_no_one_furnishes_and_a_train_without_stages_keep_the_default() -> void:
	var s := _scene({"guard": 0})
	for c: Dictionary in s.cars:
		if String(c["id"]) != "guard":
			assert_eq(int(c["home_stage"]), TrainLight.STAGE_DEFAULT, String(c["id"]) + " keeps the default")
	var plain := _scene({})
	for c: Dictionary in plain.cars:
		assert_eq(int(c["home_stage"]), TrainLight.STAGE_DEFAULT, String(c["id"]) + ": no stages handed in")


## Check the rebuilt mesh and lamp, not only the cached stage number.
func _assert_stage(s: Scene, id: String, stage: int) -> int:
	var c: Dictionary = s.car(id)
	assert_eq(int(c["home_stage"]), stage, id + ": current stage")
	var expected: Dictionary = TrainLight.spec(stage, "night")
	assert_almost_eq(float(c["stove_share"]), float(expected["stove"]), 0.0001)
	var lamp: OmniLight3D = c["lamp"]
	var lamp_spec: Dictionary = expected["lamps"][0]
	assert_eq(lamp.light_color, TrainLight.kelvin(float(lamp_spec["kelvin"])), id + ": rebuilt lamp colour")
	assert_almost_eq(lamp.omni_range, float(lamp_spec["range"]), 0.0001, id + ": rebuilt lamp range")
	var kit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT))
	var triangles: int = 0
	for row: Dictionary in Catalog.layout(c["def"])["props"]:
		if row.has("cars") and not (row["cars"] as Array).has(id):
			continue
		var home: Array = row.get("home", [0, 3])
		if stage < int(home[0]) or stage > int(home[1]) or not bool(row.get("dress", false)):
			continue
		var model: String = String((row.get("home_model", {}) as Dictionary).get(str(stage), row["model"]))
		triangles += int(kit["assets"][model]["lod0_tris"])
	var dress: MeshInstance3D = s.life.rooms[id].dress
	assert_not_null(dress, id + ": rebuilt dress")
	if dress != null:
		assert_eq(dress.mesh.get_surface_count(), 1)
		var indices: PackedInt32Array = dress.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		assert_eq(int(indices.size() / 3.0), triangles, id + ": this stage's models")
	return triangles


## Each car's own nodes as the test sees them: the car, its room's root, the stove and lamp.
func _ids(s: Scene) -> Dictionary:
	var out: Dictionary = {}
	for c: Dictionary in s.cars:
		var id: String = String(c["id"])
		out[id] = [(c["node"] as Node3D).get_instance_id(), (s.life.rooms[id].root as Node3D).get_instance_id()]
	return out


## A stage change dresses only that car again, in the same scene: its room and lamp are new,
## the car itself, the other cars and the room's traces stay, and nothing is left twice.
func test_a_stage_change_redresses_only_that_car_in_both_directions() -> void:
	var s := _scene({"guard": 0})
	var scene_id: int = s.get_instance_id()
	var rags: int = _assert_stage(s, "guard", 0)
	var traced: Array = s.life.rooms["guard"].traces.keys()
	if not traced.is_empty():
		s.life.rooms["guard"].traces[traced[0]]["scorched"] = true
	for stage: int in [3, 0]:
		var before: Dictionary = _ids(s)
		s.rules["train"]["home"]["guard"] = stage
		s.apply_rules()
		assert_eq(s.get_instance_id(), scene_id, "the train scene stays open")
		var after: Dictionary = _ids(s)
		for id: String in after:
			assert_eq(after[id][0], before[id][0], id + ": the car itself stays")
			if id == "guard":
				assert_ne(after[id][1], before[id][1], "guard: its room is dressed again")
			else:
				assert_eq(after[id][1], before[id][1], id + ": another car's room stays")
		var node: Node3D = s.car("guard")["node"]
		for part: String in ["Interior", "Stove", "StovePipeLow", "StovePipeTop", "Lamp0", "LampPool"]:
			# A second node of the same name would be renamed @name@n by add_child.
			var found: int = node.get_children().filter(func(n: Node) -> bool: return String(n.name) == part or String(n.name).begins_with("@%s@" % part)).size()
			assert_true(found <= 1, "guard: one %s, not %d" % [part, found])
		assert_eq(node.get_children().filter(func(n: Node) -> bool: return n is OmniLight3D).size(),
			2 if s.car("guard").has("stove_light") else 1, "guard: the lamp and the stove's glow only")
		if not traced.is_empty():
			assert_true(bool(s.life.rooms["guard"].traces[traced[0]]["scorched"]), "guard: the room's traces carry over")
		var triangles: int = _assert_stage(s, "guard", stage)
		if stage == 3:
			assert_gt(triangles, rags, "stage three adds its furnishings")
		else:
			assert_eq(triangles, rags, "removing furniture returns to rags")
		var settled: Dictionary = _ids(s)
		s.apply_rules()
		assert_eq(_ids(s), settled, "an unchanged stage keeps every car and room")
		_assert_stage(s, "guard", stage)


## Furnishing raises a car's stage while it is being decorated (결정 517); leaving shows the new
## stage at once, in that car only, without waiting for the next stop.
func test_furnishing_a_car_shows_its_new_stage_when_decorating_ends() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(f)
	await get_tree().process_frame
	f.train_g["dom"] = Dom.start()
	var store: Dictionary = TrainDecor.read_store(f.train_g)
	for kind: String in ["chair", "table"]:
		TrainDecor.add_stored(store, kind)
	f._select("guard", false)
	f.train_g["phase"] = "travel"
	f.paper.set_folded(true)
	assert_eq(int(f.train.car("guard")["home_stage"]), 0, "the guard car starts in rags")
	var stages_before: Dictionary = f._home_of(f.train_g)
	assert_true(f.open_decor("guard"))
	for kind: String in ["chair", "table"]:
		assert_true(Mods.place(f.train_g, "guard", kind, "floor")["ok"], kind + " placed")
	var tier: int = TrainDecor.tier_of(f.train_g, "guard")
	assert_eq(tier, 1, "a chair and a table make the first stage")
	var before: Dictionary = _ids(f.train)
	f.leave_decor()
	var c: Dictionary = f.train.car("guard")
	assert_eq(int(c["home_stage"]), tier, "the car shows its new stage on leaving")
	var daytime: String = TrainLight.daytime_of(f.train.rules.get("view", {}))
	assert_almost_eq(float(c["stove_share"]), float(TrainLight.spec(tier, daytime)["stove"]), 0.0001, "the stove burns as the new stage")
	assert_almost_eq((c["lamp"] as OmniLight3D).omni_range, float(TrainLight.spec(tier, daytime)["lamps"][0]["range"]), 0.0001, "the lamp is the new stage's")
	# The captain's and dining cars take the highest tier of the cars people live in
	# (train_decor.gd common_tier), so the guard car's first stage lifts them too.
	var stages_after: Dictionary = f._home_of(f.train_g)
	for id: String in ["captain", "dining"]:
		assert_eq(int(stages_after[id]), tier, id + ": the shared tier follows the guard car")
		assert_eq(int(f.train.car(id)["home_stage"]), tier, id + ": shows the shared tier on leaving")
	var after: Dictionary = _ids(f.train)
	var redressed: int = 0
	for id: String in after:
		assert_eq(after[id][0], before[id][0], id + ": the car itself stays")
		if int(stages_after.get(id, -1)) != int(stages_before.get(id, -1)):
			assert_ne(after[id][1], before[id][1], id + ": its stage changed, so its room is dressed again")
			redressed += 1
		else:
			assert_eq(after[id][1], before[id][1], id + ": its stage did not change, so its room stays")
	assert_eq(redressed, 3, "the guard car and the two cars on the shared tier, no others")


func test_an_unchanged_initial_stage_keeps_every_car_instance() -> void:
	var s := _scene({"guard": 0})
	var nodes: Dictionary = {}
	for c: Dictionary in s.cars:
		nodes[c["id"]] = (c["node"] as Node3D).get_instance_id()
	s.apply_rules()
	for c: Dictionary in s.cars:
		assert_eq((c["node"] as Node3D).get_instance_id(), int(nodes[c["id"]]), String(c["id"]))


## The slice hands every furnished car its tier: a new train's cars start in rags (결정 486).
func test_the_flow_hands_a_new_train_its_rags() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(f)
	await get_tree().process_frame
	var home: Dictionary = (f.train.rules["train"] as Dictionary).get("home", {})
	assert_eq(home.size(), TrainDecor.DECOR_CARS.size(), "every car a player furnishes")
	for id: String in TrainDecor.DECOR_CARS:
		assert_eq(int(home.get(id, -1)), TrainDecor.tier_of(f.train_g, id), id + ": its tier")
		var c: Dictionary = f.train.car(id)
		assert_false(c.is_empty(), id + ": is on the default train")
		if not c.is_empty():
			assert_eq(int(c["home_stage"]), int(home[id]), id + ": on the train screen")
	assert_eq(int(home.get("guard", -1)), 0, "a new train starts in rags")


## Furnished cars reach the screen with their own tiers through the slice, lamps and all; the
## captain's and dining cars take the highest tier of the cars people live in (common_tier).
func test_the_flow_hands_furnished_cars_their_tiers_and_lamps() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(f)
	await get_tree().process_frame
	var phase: String = String(f.train.rules["train"]["phase"])
	var seg: int = int(f.train.rules["train"]["seg"])
	f.train_g["dom"]["furnish"]["guard"] = {"tier": 2, "items": []}
	f.train_g["dom"]["furnish"]["front"] = {"tier": 3, "items": []}
	f._clear_stage()
	f._show_train(phase, seg)
	await get_tree().process_frame
	var want: Dictionary = {"guard": 2, "front": 3, "captain": 3, "dining": 3, "medtech": 0}
	var home: Dictionary = (f.train.rules["train"] as Dictionary).get("home", {})
	var daytime: String = TrainLight.daytime_of(f.train.rules.get("view", {}))
	for id: String in want:
		assert_eq(int(home.get(id, -1)), int(want[id]), id + ": its tier in the rules")
		var c: Dictionary = f.train.car(id)
		assert_false(c.is_empty(), id + ": is on the train")
		if c.is_empty():
			continue
		assert_eq(int(c["home_stage"]), int(want[id]), id + ": its tier on the screen")
		assert_almost_eq((c["lamp"] as OmniLight3D).omni_range, float(TrainLight.spec(int(want[id]), daytime)["lamps"][0]["range"]), 0.0001, id + ": its stage's lamp")
