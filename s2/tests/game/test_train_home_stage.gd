extends GutTest
## A car's home stage (결정 486·517): the tier the domestic rules give each furnished car reaches
## the train screen (slice_flow.gd rules["train"]["home"] → train_scene.gd c["home_stage"]) and its
## light follows it (train_light.gd); the cars no one furnishes keep the default.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const TrainLight = preload("res://game/train/train_light.gd")
const TrainDecor = preload("res://game/train/train_decor.gd")
const SliceFlow = preload("res://game/slice_flow.gd")


func _scene(home: Dictionary) -> Scene:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1688, 780)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var s: Scene = Scene.new()
	s.rules = Rules.load_default()
	s.rules["view"]["daytime"] = "night"
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
	assert_ne(float(s.car("guard")["stove_share"]), float(s.car("front")["stove_share"]), "rags and nordic do not burn alike")


func test_a_car_no_one_furnishes_and_a_train_without_stages_keep_the_default() -> void:
	var s := _scene({"guard": 0})
	for c: Dictionary in s.cars:
		if String(c["id"]) != "guard":
			assert_eq(int(c["home_stage"]), TrainLight.STAGE_DEFAULT, String(c["id"]) + " keeps the default")
	var plain := _scene({})
	for c: Dictionary in plain.cars:
		assert_eq(int(c["home_stage"]), TrainLight.STAGE_DEFAULT, String(c["id"]) + ": no stages handed in")


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
		if not c.is_empty():
			assert_eq(int(c["home_stage"]), int(home[id]), id + ": on the train screen")
	assert_eq(int(home.get("guard", -1)), 0, "a new train starts in rags")
