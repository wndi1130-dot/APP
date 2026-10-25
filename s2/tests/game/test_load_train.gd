extends "res://addons/gut/test.gd"
## Putting loads aboard (decision 448-13): by the train the player puts the bag's
## loads aboard with a key, the near-things key first and the bag's own; the
## companions go on loading by themselves.

const FieldGame = preload("res://game/field_game.gd")


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	return game


func _at_the_train(game, p, dx: int = 3) -> void:
	var rect: Rect2i = game.data["unload"]
	p.position = game.lift(rect.position + Vector2i(dx, 1), 0)


func _buttons(hud) -> Array:
	return hud.modal.find_children("*", "Button", true, false).map(func(b) -> String: return String(b.text))


func test_the_player_loads_with_a_key_and_the_companions_by_themselves() -> void:
	var game = _game()
	var p = game.player
	var q = game.squad[1]
	p.add_item("scrap", 2)
	q.add_item("plank", 1)
	_at_the_train(game, p)
	_at_the_train(game, q, 4)
	game.actions._auto_unload()
	assert_eq(int(p.items.get("scrap", 0)), 2, "nothing goes aboard from the player's bag unasked")
	assert_eq(int(game.unloaded.get("plank", 0)), 1, "a companion loads what it carries")
	var rows: Array = game.actions._near_things(p)
	assert_eq(String(rows[0]["label"]), "열차에 싣기", "the first thing by the train")
	rows[0]["call"].call()
	assert_eq(int(game.unloaded.get("scrap", 0)), 2)
	assert_false(p.items.has("scrap"))
	assert_false(game.actions._near_things(p).any(func(r: Dictionary) -> bool: return r["label"] == "열차에 싣기"), "nothing left to put aboard")


func test_what_stays_on_the_body_is_not_offered_and_away_from_the_train_nothing_goes() -> void:
	var game = _game()
	var p = game.player
	p.add_item("can_opener")
	_at_the_train(game, p)
	assert_eq(game.actions.loadable(p), [], "the opener stays with the one who has it")
	assert_false(game.actions._near_things(p).any(func(r: Dictionary) -> bool: return r["label"] == "열차에 싣기"))
	p.add_item("scrap", 1)
	p.position = game.lift(Vector2i(60, 40), 0)
	assert_false(game.actions.at_unloading(p))
	assert_false(game.actions.load_train(p), "only by the train")
	assert_eq(int(p.items.get("scrap", 0)), 1)


func test_the_bag_has_the_key_by_the_train() -> void:
	var game = _game()
	var p = game.player
	p.add_item("food_pack", 1)
	p.position = game.lift(Vector2i(60, 40), 0)
	game.hud.bag_panel()
	assert_false(_buttons(game.hud).has("열차에 싣기"), "away from the train, no such key")
	game.hud._close_modal()
	_at_the_train(game, p)
	game.hud.bag_panel()
	assert_true(_buttons(game.hud).has("열차에 싣기"))
	game.hud._load_train()
	assert_eq(int(game.unloaded.get("food_pack", 0)), 1)
	assert_false(_buttons(game.hud).has("열차에 싣기"), "the bag shown again, nothing left to load")
	game.hud._close_modal()
