extends "res://addons/gut/test.gd"
## 칸이 먼저, 사람은 뒤에(사용자 결정 2026-10-25): 칸 따뜻함이 바뀌면 난로가 먼저,
## 벽과 창 성에가 뒤따라 서서히 바뀌고, 사람은 room_lead 뒤에 다시 앉는다.
## 사람 수가 바뀌는 일은 바로 따른다. 값(난방 계산)은 읽기만 한다.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Look = preload("res://game/train/train_look.gd")
const SceneFile = preload("res://game/train/train.tscn")

const LEAD := 2.5
const EASE := 5.0


func _scene(lead: float = LEAD, ease_s: float = EASE) -> Node3D:
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.opts = {"seed": 7, "panel": false}
	s.room_lead = lead
	s.room_ease = ease_s
	add_child_autofree(s)
	return s


func _run(s: Node3D, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.001:
		s.step(0.1)
		t += 0.1


func _seats(c: Dictionary) -> Array:
	return (c["bodies"] as Array).map(func(b): return [b.position, b.pose, b.huddled, b.bowed])


func _frost(c: Dictionary) -> float:
	return float((c["glass"] as ShaderMaterial).get_shader_parameter("cold_car"))


func _share(from: float, now: float, to: float) -> float:
	return (now - from) / (to - from)


func test_the_train_screen_turns_the_room_first() -> void:
	var s: Node3D = autofree(SceneFile.instantiate())
	assert_gt(float(s.room_lead), 0.0, "train.tscn has the people wait")
	assert_gt(float(s.room_ease), float(s.room_lead), "and the room takes longer than that to turn")


func test_the_stove_goes_first_then_the_frost_then_the_people() -> void:
	var s := _scene()
	var c: Dictionary = s.car("tail1")
	var warm: float = float(c["room_w"])
	var burn0: float = Look.stove(warm)
	var frost0: float = Look.frost(warm)
	var before := _seats(c)
	var n: int = (c["bodies"] as Array).size()
	assert_true(s.set_sit("tail", 0, 15.0), "a freezing tail")
	var cold: float = float(c["room_to"])
	assert_lt(cold, warm)
	assert_gt(Look.frost(cold), frost0, "the test needs frost to grow")
	assert_eq(_seats(c), before, "nobody moves at the change")
	assert_almost_eq(_frost(c), frost0, 0.001, "nor does the room, yet")
	_run(s, 0.9)
	var burn_share := _share(burn0, float(c["room_vis"]["burn"]), Look.stove(cold))
	var frost_share := _share(frost0, _frost(c), Look.frost(cold))
	assert_gt(burn_share, 0.6, "the stove has gone down first")
	assert_between(frost_share, 0.01, burn_share - 0.3, "the frost has begun, behind the stove")
	assert_eq(_seats(c), before, "the people still sit as they were")
	_run(s, LEAD - 0.9 - 0.2)
	assert_gt(_share(frost0, _frost(c), Look.frost(cold)), 0.5, "most of the frost is in before anyone moves")
	assert_eq(_seats(c), before)
	_run(s, 0.4)
	assert_eq((c["bodies"] as Array).size(), n)
	assert_ne(_seats(c), before, "after the lead the people sit as a freezing car does")
	_run(s, EASE)
	assert_almost_eq(float(c["room_w"]), cold, 0.01, "the room has turned")
	assert_almost_eq(_frost(c), Look.frost(cold), 0.001)


func test_a_change_of_how_many_are_in_a_car_is_taken_at_once() -> void:
	var s := _scene()
	var c: Dictionary = s.car("tail1")
	var n: int = (c["bodies"] as Array).size()
	# Crowding sets how many are drawn: that is people coming and going, not a mood.
	assert_true(s.set_sit("tail", 2, 100.0))
	var m: int = (c["bodies"] as Array).size()
	if m == n:
		assert_true(s.set_sit("tail", 2, 0.0))
		m = (c["bodies"] as Array).size()
	assert_ne(m, n, "the count changed")
	assert_false(c.has("reseat_at"), "and nobody waits for the room")


func test_without_a_lead_everything_is_taken_at_once() -> void:
	var s := _scene(0.0, 0.0)
	var c: Dictionary = s.car("tail1")
	var before := _seats(c)
	assert_true(s.set_sit("tail", 0, 15.0))
	assert_ne(_seats(c), before)
	assert_almost_eq(float(c["room_w"]), float(c["room_to"]), 0.001)
	assert_almost_eq(_frost(c), Look.frost(float(c["room_to"])), 0.001)


func test_the_people_read_the_warmth_the_room_shows() -> void:
	var s := _scene()
	if s.people_view == null:
		pass_test("no baked people here")
		return
	var c: Dictionary = s.car("tail1")
	var warm: float = float(c["room_w"])
	s.set_sit("tail", 0, 15.0)
	assert_almost_eq(float(s.people_view.car_state(c)["warmth"]), warm, 0.01, "not the number, the room")
	_run(s, EASE + 0.2)
	assert_almost_eq(float(s.people_view.car_state(c)["warmth"]), float(c["room_to"]), 0.01)
