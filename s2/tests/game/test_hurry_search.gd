extends "res://addons/gut/test.gd"
## 서둘러 뒤지기(결정 481): 가방 창 「모두 담기」 밑 「서둘러 ½」. 누르면 그 상자의 남은 시간과
## 아직 꺼낼 것마다의 시간이 절반, 뒤지는 소리가 닿는 넓이가 두 배(바깥 3 → 6 m, 실내 1.5 → 3 m),
## 소리 간격(누른 때 한 번, 그 뒤 4초마다)은 그대로. 넓이는 소리 물결로 바닥에 보인다.
## 안 누르면 예전과 똑같다.

const FieldGame = preload("res://game/field_game.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")
const SimNoise = preload("res://game/sim/noise.gd")


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	return game


## A box searched and the player at it, holding `items`.
func _at_a_box(game, items: Array) -> String:
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if int(c.get("level", 0)) == 0 and not bool(c.get("locked", false)) and not c.has("pick"):
			c["searched"] = true
			c["items"] = items.duplicate()
			game.player.position = game.actions._container_at(c)
			game.player.stop()
			return String(id)
	return ""


## One step of the field's tick for the player, the action's time all but gone.
func _step(game, p) -> void:
	p.action_t = 0.001
	game._update_person(p, 0.1)


func _sounds(game, tag: String) -> int:
	return game.sounds.filter(func(s: Dictionary) -> bool: return String(s["tag"]) == tag).size()


func test_the_values_are_the_decision_s() -> void:
	assert_eq(SearchRules.HURRY_TIME, 0.5, "half the time")
	var row: Dictionary = SimNoise.SOURCES["search_hurry"]
	assert_eq(row["levels"], [SimNoise.Level.QUIET], "the rummage's own level")
	assert_eq(SimNoise.reach("search_hurry"), 2.0, "twice its reach")
	assert_almost_eq(SimNoise.radius(SimNoise.Level.QUIET, false) * SimNoise.reach("search"), 3.0, 0.0001, "the rummage: 3 m out of doors")
	assert_almost_eq(SimNoise.radius(SimNoise.Level.QUIET, false) * SimNoise.reach("search_hurry"), 6.0, 0.0001, "hurried: 6 m")
	assert_almost_eq(SimNoise.radius(SimNoise.Level.QUIET, true) * SimNoise.reach("search"), 1.5, 0.0001, "indoors 1.5 m")
	assert_almost_eq(SimNoise.radius(SimNoise.Level.QUIET, true) * SimNoise.reach("search_hurry"), 3.0, 0.0001, "hurried indoors: 3 m")
	assert_has(FieldGame.RIPPLE_TAGS, "search_hurry", "its reach shows on the ground")
	assert_eq(SearchRules.NOISE_EVERY, 4.0, "as often as before")


func test_hurry_halves_what_is_left_and_each_thing_still_to_come() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["food_pack", "food_pack"])
	game.actions.take_all(p, box)
	assert_almost_eq(p.action_total, 0.6, 0.0001, "weight 1, as before")
	p.action_t = 0.4
	game.actions.hurry(p, box)
	assert_almost_eq(p.action_t, 0.2, 0.0001, "half of what was left")
	assert_almost_eq(p.action_total, 0.3, 0.0001, "the bar keeps its place")
	assert_true(game.actions.hurried(p))
	_step(game, p)
	assert_eq(p.action, "take", "the next comes out")
	assert_almost_eq(p.action_total, 0.3, 0.0001, "the next takes half its time")
	_step(game, p)
	assert_eq(p.action, "")
	assert_eq(int(p.items.get("food_pack", 0)), 2)
	assert_false(game.actions.hurried(p), "the hurry ends with the work")
	assert_false(game.actions.hurrying.has(p.get_instance_id()))


func test_hurry_at_rest_takes_everything_out_hurried() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["scrap", "hat_knit"])
	game.actions.hurry(p, box)
	assert_eq(game.actions.taking_item(p), "scrap", "모두 담기, the clothes left")
	assert_almost_eq(p.action_total, SearchRules.take_seconds("scrap") * 0.5, 0.0001)


func test_not_hurried_is_as_before_and_quiet_while_taking() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["food_pack", "symbol_bell"])
	game.actions.take_all(p, box)
	assert_almost_eq(p.action_total, 2.0, 0.0001, "the bell, two seconds")
	for i in range(30):
		game.actions.search_noise(p, 0.5)
	assert_eq(_sounds(game, "search") + _sounds(game, "search_hurry"), 0, "taking out makes no rummage")
	_step(game, p)
	assert_almost_eq(p.action_total, 0.6, 0.0001, "the next, its whole time")


func test_the_hurried_rummage_is_heard_at_once_then_every_four_seconds() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["symbol_bell", "symbol_bell", "symbol_bell", "symbol_bell", "symbol_bell", "symbol_bell"])
	game.actions.take_all(p, box)
	game.actions.hurry(p, box)
	assert_eq(_sounds(game, "search_hurry"), 1, "at once")
	assert_eq(game.ripples.rings.size(), 1, "its ring on the ground")
	# Six bells at a second each, hurried: the rummage at 4 s, as often as ever.
	var t := 0.0
	while t < 3.9:
		game.actions.search_noise(p, 0.1)
		t += 0.1
	assert_eq(_sounds(game, "search_hurry"), 1, "not before four seconds")
	game.actions.search_noise(p, 0.2)
	assert_eq(_sounds(game, "search_hurry"), 2, "at four seconds")
	assert_eq(_sounds(game, "search"), 0)


func test_the_pane_has_the_key_under_take_all() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["scrap", "food_pack"])
	game.hud.loot(box)
	var under: Node = game.hud.modal.find_child("Hurry", true, false)
	assert_not_null(under, "a row under 「모두 담기」")
	var key: Button = under.get_child(0)
	assert_eq(key.text, "서둘러 ½")
	key.pressed.emit()
	assert_eq(p.action, "take")
	assert_true(game.actions.hurried(p))
	var now: Button = game.hud.modal.find_child("Hurry", true, false).get_child(0)
	assert_eq(now.text, "서두르는 중")
	assert_true(now.disabled)
	game.hud._close_modal()


func test_an_empty_box_or_clothes_only_has_no_key() -> void:
	var game = _game()
	var box := _at_a_box(game, ["hat_knit"])
	game.hud.loot(box)
	assert_null(game.hud.modal.find_child("Hurry", true, false))
	game.hud._close_modal()
