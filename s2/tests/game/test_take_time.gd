extends "res://addons/gut/test.gd"
## 챙기는 데 시간(카드 R1 가): 상자에서 하나 꺼내는 데 무게 1에 0.6초, 한 번에 2초까지,
## 상자 곁에 서서. 조이스틱이나 맞는 것은 손을 떼게 하고 물건은 상자에 남는다. 「모두 담기」는
## 옷을 빼고 무거운 것부터 하나씩 이어 간다. 가방 창은 고를 때 멈춰 있고 꺼내는 동안만 필드가
## 흐르며, 꺼내는 줄에 얇은 막대가 찬다(카드 P2 가).

const FieldGame = preload("res://game/field_game.gd")
const Combat = preload("res://game/field_combat.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")


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


func test_a_thing_takes_its_weight_s_time() -> void:
	assert_eq([SearchRules.TAKE_PER_WEIGHT, SearchRules.TAKE_MOST], [0.6, 2.0], "the values in the PR")
	assert_almost_eq(SearchRules.take_seconds("food_pack"), 0.6, 0.0001, "weight 1")
	assert_almost_eq(SearchRules.take_seconds("bandage"), 0.06, 0.0001, "weight 0.1")
	assert_almost_eq(SearchRules.take_seconds("symbol_bell"), 2.0, 0.0001, "weight 4 stops at two seconds")


func test_taking_out_waits_at_the_box_then_bags_it() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["food_pack", "bandage"])
	assert_ne(box, "")
	var c: Dictionary = game.data["containers"][box]
	game.actions.take(p, box, 0)
	assert_eq(p.action, "take")
	assert_almost_eq(p.action_total, 0.6, 0.0001)
	assert_eq(c["items"], ["food_pack", "bandage"], "still in the box while it comes out")
	assert_eq(game.actions.taking_item(p), "food_pack")
	game.actions.take(p, box, 1)
	assert_eq(game.actions.taking_item(p), "food_pack", "one thing at a time")
	_step(game, p)
	assert_eq(p.action, "")
	assert_eq(c["items"], ["bandage"])
	assert_eq(int(p.items.get("food_pack", 0)), 1)


func test_the_stick_or_a_blow_lets_it_go_and_it_stays_in_the_box() -> void:
	assert_true(FieldGame.STICK_BREAKS.has("take"))
	assert_true(Combat.BLOW_BREAKS.has("take"))
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["scrap"])
	var c: Dictionary = game.data["containers"][box]
	game.actions.take(p, box, 0)
	assert_eq(p.action, "take")
	p.stick = Vector2(1, 0)
	game._update_person(p, 0.05)
	p.stick = Vector2.ZERO
	assert_ne(p.action, "take", "walked away from it")
	assert_eq(c["items"], ["scrap"], "the thing stays in the box")
	assert_false(p.items.has("scrap"))
	assert_false(bool(c.get("busy", false)), "the box is free again")


func test_take_all_goes_heaviest_first_and_leaves_clothes() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["bandage", "hat_knit", "scrap", "document", "symbol_bell"])
	var c: Dictionary = game.data["containers"][box]
	assert_almost_eq(game.actions.take_all_seconds(c), 0.06 + 0.6 + 0.3 + 2.0, 0.0001, "the time it would take, clothes not counted")
	game.actions.take_all(p, box)
	var order: Array = []
	for i in range(10):
		if p.action != "take":
			break
		order.append(game.actions.taking_item(p))
		_step(game, p)
	assert_eq(order, ["symbol_bell", "scrap", "document", "bandage"], "the heaviest first, one after another")
	assert_eq(c["items"], ["hat_knit"], "the hat is put on by itself")


func test_take_all_stops_where_the_stick_lets_it_go() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["bandage", "scrap", "food_pack"])
	var c: Dictionary = game.data["containers"][box]
	game.actions.take_all(p, box)
	_step(game, p)
	assert_eq(c["items"].size(), 2, "one out")
	p.stick = Vector2(1, 0)
	game._update_person(p, 0.05)
	p.stick = Vector2.ZERO
	for i in range(3):
		game._update_person(p, 0.1)
	assert_eq(c["items"].size(), 2, "the rest stays in")
	assert_eq(p.action, "")


func test_the_pane_runs_the_field_only_while_a_thing_comes_out() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["scrap", "bandage"])
	var c: Dictionary = game.data["containers"][box]
	game.paused = false
	game.hud.loot(box)
	assert_true(game.paused, "looking is free: the field stops under the pane")
	game.hud._loot_take(box, 0)
	assert_eq(p.action, "take")
	assert_false(game.paused, "the field goes on while it comes out")
	assert_eq(game.hud.taking_box, box)
	assert_not_null(game.hud.modal.find_child("TakeBar", true, false), "a bar on the row coming out")
	var keys: Array = game.hud.modal.find_children("*", "Button", true, false).map(func(b) -> String: return String(b.text))
	assert_has(keys, "멈추기")
	game.hud.tick(0.016)
	_step(game, p)
	assert_eq(c["items"], ["bandage"])
	assert_true(game.paused, "out: the pane stops the field again")
	assert_eq(game.hud.taking_box, "")
	assert_null(game.hud.modal.find_child("TakeBar", true, false))
	game.hud._close_modal()


func test_stop_keeps_the_rest_in_the_box() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game, ["scrap", "food_pack"])
	var c: Dictionary = game.data["containers"][box]
	game.hud.loot(box)
	game.hud._loot_all(box)
	assert_eq(p.action, "take")
	game.hud._loot_stop(box)
	assert_eq(p.action, "")
	for i in range(3):
		game._update_person(p, 0.1)
	assert_eq(c["items"].size(), 2, "nothing more comes out")
	assert_true(game.paused)
	game.hud._close_modal()


func test_a_work_let_go_under_the_pane_puts_it_away() -> void:
	var game = _game()
	var p = game.player
	var box := _at_a_box(game, ["scrap"])
	game.paused = false
	game.hud.loot(box)
	game.hud._loot_take(box, 0)
	assert_eq(game.hud.taking_box, box)
	# A blow lands (field_combat.gd BLOW_BREAKS): the hands come off the box.
	p.cancel_action()
	game.hud.tick(0.016)
	assert_false(game.hud.modal_open, "the pane goes so the blow can be met")
	assert_false(game.paused)
