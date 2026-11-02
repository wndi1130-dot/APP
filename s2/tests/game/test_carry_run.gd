extends "res://addons/gut/test.gd"
## 짐과 뛰기(결정 448-19 「물건 들고 뛰거나 이런 거 바보 같아」, 카드 G 가 — 결정 442로 적용):
## 넘침이면 못 뛰고, 한 개 무게 3 이상(종·코어·궤짝)을 지니면 안고 걷는다. 절반 넘음에서 뛰면
## 숨이 1.5배. 걷는 빠르기는 그대로. 뛰기를 누르면 왜 걷는지 한 줄.

const FieldGame = preload("res://game/field_game.gd")
const Carry = preload("res://game/sim/carry.gd")
const Stamina = preload("res://game/sim/stamina.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_values_are_the_listed_ones() -> void:
	assert_eq(Carry.BIG_THING, 3.0)
	assert_eq(Stamina.LOAD_BREATH_MULT, [1.0, 1.5, 1.5, 2.8], "past half a run costs half as much breath again")
	assert_true(Carry.has_big({"symbol_bell": 1}), "the bell")
	assert_true(Carry.has_big({"core_engine": 1}), "a core")
	assert_false(Carry.has_big({"scrap": 6}), "many small things are a load, not a big thing")
	assert_false(Carry.has_big({"shotgun": 1}), "a spare gun is slung")
	assert_false(Carry.has_big({"symbol_bell": 0}))


func test_over_the_limit_or_with_a_big_thing_the_feet_walk() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	p.add_item("scrap", 2)
	assert_true(p.load_lets_run(), "light")
	p.items.clear()
	p.add_item("scrap", int(ceil(p.carry_limit() * 0.75)))
	assert_eq(p.carry_state(), 1)
	assert_true(p.load_lets_run(), "past half still runs, short of breath sooner")
	p.items.clear()
	p.add_item("scrap", int(ceil(p.carry_limit() * 1.5)))
	assert_eq(p.carry_state(), 2)
	assert_false(p.load_lets_run(), "over the limit: a walk")
	p.items.clear()
	p.add_item("symbol_bell")
	assert_lt(p.carry_state(), 2, "not over the limit: the bell itself keeps the feet to a walk")
	assert_false(p.load_lets_run(), "held in both arms")
	# The run asked for is a walk: the walk's speed, not running now.
	p.running = true
	p.moving = true
	var floor_kind: int = FieldGrid.Floor.SNOW
	var asked: float = p.speed(floor_kind)
	p.running = false
	assert_almost_eq(asked, p.speed(floor_kind), 0.0001, "the same as walking")
	p.running = true
	assert_false(p.is_running_now())


func test_past_half_a_run_drains_the_breath_half_again() -> void:
	var light := {"running": true, "carry_state": 0}
	var half := {"running": true, "carry_state": 1}
	var a: Vector2 = Stamina.advance(0.0, 1.0, 1.0, light)
	var b: Vector2 = Stamina.advance(0.0, 1.0, 1.0, half)
	assert_almost_eq(1.0 - b.y, (1.0 - a.y) * 1.5, 0.0001)


func test_a_run_asked_for_with_the_bell_says_why_and_not_every_time() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	p.add_item("symbol_bell")
	game.hud.run_button.button_pressed = true
	game.hud._toggle_run()
	game.hud.run_button.button_pressed = false
	game.hud._toggle_run()
	game.hud.run_button.button_pressed = true
	game.hud._toggle_run()
	var said := 0
	for n in game.hud.toast_box.find_children("*", "Label", true, false):
		if String(n.text).replace(UiFonts.WORD_JOINER, "").contains("안고는 못 뛴다"):
			said += 1
	assert_eq(said, 1, "once, not at every press")
	p.items.clear()
	game.clock.elapsed += game.hud.LOAD_WALK_EVERY + 1.0
	game.hud._toggle_run()
	said = 0
	for n in game.hud.toast_box.find_children("*", "Label", true, false):
		if String(n.text).replace(UiFonts.WORD_JOINER, "").contains("못 뛴다"):
			said += 1
	assert_eq(said, 1, "a light load says nothing")
