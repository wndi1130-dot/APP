extends "res://addons/gut/test.gd"
## 궤 줄 모으기(결정 550으로 돌아감, 결정 558 줄 목록 안에서): 궤 안 같은 물건은 한 줄 「×n」,
## 누르면 하나(누를 때 궤에서 다시 찾음), 펼친 칸의 「모두 ×n」은 그 물건만 하나씩 이어 꺼낸다.
## 상태가 다른 것(상한·얼어붙은 고기, 시든 사과)은 이미 다른 물건이라 따로 남고, 숨은 상태
## (찌그러진 통조림 가운데 상한 것, 맞춰 둔 손목시계)는 겉모습 그대로 함께 모여 비밀이 새지 않는다.
## 줌 「−」「+」와 「D」는 디버그 판에서만 시계 줄에 놓인다.

const FieldGame = preload("res://game/field_game.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const InventoryPane = preload("res://game/ui/inventory_pane.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Carry = preload("res://game/sim/carry.gd")


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.player.items.clear()
	return game


## A searched drawer away from the train, the player at it, holding `items`.
func _box(game, items: Array) -> String:
	for id: String in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if int(c.get("level", 0)) == 0 and not bool(c.get("locked", false)) and not c.has("pick") and not game.FieldMaps.by_train(game.data, c["cell"], "unloading"):
			c["searched"] = true
			c["furniture"] = "dresser"
			c["items"] = items.duplicate()
			game.player.position = game.actions._container_at(c)
			game.player.stop()
			return id
	return ""


func _near_rows(hud) -> Array:
	var near: Node = hud.modal.find_child("Near", true, false)
	var out: Array = []
	for child: Node in near.get_children():
		if child is Button:
			out.append(child)
	return out


func _row(hud, id: String) -> Button:
	for b: Button in _near_rows(hud):
		if b.has_meta("item_id") and String(b.get_meta("item_id")) == id:
			return b
	return null


func _count_word(row: Button) -> String:
	var count := row.find_child("Count", true, false) as Label
	return count.text if count != null else ""


## One step of the field's tick for the player, the action's time all but gone.
func _step(game, p) -> void:
	p.action_t = 0.001
	game._update_person(p, 0.1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# ---------------------------------------------------------------- the rule


func test_shown_as_is_the_plain_twin_for_a_hidden_state_and_itself_otherwise() -> void:
	assert_eq(FieldItems.shown_as("can_dented_bad"), "can_dented", "gone off, it still looks dented")
	assert_eq(FieldItems.shown_as("wrist_watch_set"), "wrist_watch", "set, it still looks a watch")
	assert_eq(FieldItems.shown_as("can_dented"), "can_dented")
	assert_eq(FieldItems.shown_as("meat_spoiled"), "meat_spoiled", "a state you can see is its own kind")
	assert_eq(FieldItems.shown_as("no_such_thing"), "no_such_thing", "an unknown id stands for itself")
	assert_eq(FieldItems.shown_as(""), "")
	# The twins must keep looking alike for the gathering to keep the secret.
	for twin: Array in [["can_dented_bad", "can_dented"], ["wrist_watch_set", "wrist_watch"]]:
		assert_eq(FieldItems.item_name(twin[0]), FieldItems.item_name(twin[1]))
		assert_almost_eq(Carry.item_weight(twin[0]), Carry.item_weight(twin[1]), 0.0001)


func test_box_stacks_gather_a_kind_in_the_order_it_first_lies() -> void:
	var stacks: Array = InventoryPane.box_stacks(["can_beans", "scrap", "can_beans", "can_beans"])
	assert_eq(stacks.size(), 2)
	assert_eq([stacks[0]["key"], stacks[0]["n"], stacks[0]["first"]], ["can_beans", 3, 0])
	assert_eq([stacks[1]["key"], stacks[1]["n"], stacks[1]["first"]], ["scrap", 1, 1])
	assert_almost_eq(float(stacks[0]["weight"]), Carry.item_weight("can_beans") * 3.0, 0.0001)
	assert_almost_eq(float(stacks[1]["weight"]), Carry.item_weight("scrap"), 0.0001)


func test_box_stacks_keep_seen_states_apart_and_hidden_ones_together() -> void:
	var seen: Array = InventoryPane.box_stacks(["meat_spoiled", "meat_frozen", "meat_frozen", "apple", "apple_wilted"])
	assert_eq(seen.map(func(s: Dictionary) -> Array: return [s["key"], s["n"]]), [["meat_spoiled", 1], ["meat_frozen", 2], ["apple", 1], ["apple_wilted", 1]])
	var hidden: Array = InventoryPane.box_stacks(["can_dented", "can_dented_bad", "can_dented", "wrist_watch_set", "wrist_watch"])
	assert_eq(hidden.map(func(s: Dictionary) -> Array: return [s["key"], s["n"]]), [["can_dented", 3], ["wrist_watch", 2]], "one row each, no tell")
	assert_almost_eq(float(hidden[0]["weight"]), Carry.item_weight("can_dented") * 2.0 + Carry.item_weight("can_dented_bad"), 0.0001)


func test_box_stacks_of_nothing_is_nothing() -> void:
	assert_eq(InventoryPane.box_stacks([]), [])


func test_stack_index_finds_the_first_that_shows_as_the_kind() -> void:
	assert_eq(InventoryPane.stack_index(["wood", "can_dented_bad", "can_dented"], "can_dented"), 1, "the hidden twin is one of the kind")
	assert_eq(InventoryPane.stack_index(["wood", "scrap"], "scrap"), 1)
	assert_eq(InventoryPane.stack_index(["wood"], "scrap"), -1, "none left")
	assert_eq(InventoryPane.stack_index([], "scrap"), -1)


# ---------------------------------------------------------------- the rows


func test_three_of_a_kind_are_one_row_with_their_count_and_weight() -> void:
	var game = _game()
	game.hud.loot(_box(game, ["can_beans", "scrap", "can_beans", "can_beans"]))
	var rows: Array = _near_rows(game.hud)
	assert_eq(rows.size(), 2, "a row to a kind")
	var beans: Button = _row(game.hud, "can_beans")
	assert_not_null(beans)
	assert_eq(_count_word(beans), "×3")
	assert_eq(beans.text, "%s ×3" % game.item_name("can_beans"))
	var kg := beans.find_child("Weight", true, false) as Label
	assert_eq(kg.text, "%.1f" % (Carry.item_weight("can_beans") * 3.0))
	assert_eq(_count_word(_row(game.hud, "scrap")), "", "one alone shows no count")
	game.hud._close_modal()


func test_the_heavier_stack_comes_first_and_by_name_when_sorted_so() -> void:
	var game = _game()
	var hud = game.hud
	# One sack outweighs one tin, but two tins together outweigh the sack: by a
	# thing's own weight the sack would lead, by the stack's the tins do.
	assert_gt(Carry.item_weight("oats"), Carry.item_weight("can_beans"))
	assert_lt(Carry.item_weight("oats"), Carry.item_weight("can_beans") * 2.0)
	hud.loot(_box(game, ["oats", "can_beans", "can_beans"]))
	var rows: Array = _near_rows(hud)
	assert_eq(String(rows[0].get_meta("item_id")), "can_beans", "the stack's weight, not one thing's")
	hud.inv_sort = "name"
	hud.bag_panel()
	var names: Array = _near_rows(hud).map(func(b: Button) -> String: return game.item_name(String(b.get_meta("item_id"))))
	var sorted: Array = names.duplicate()
	sorted.sort()
	assert_eq(names, sorted)
	hud._close_modal()


func test_states_you_can_see_are_their_own_rows() -> void:
	var game = _game()
	game.hud.loot(_box(game, ["meat_spoiled", "meat_frozen", "meat_frozen"]))
	assert_eq(_near_rows(game.hud).size(), 2)
	assert_eq(_count_word(_row(game.hud, "meat_frozen")), "×2")
	assert_eq(_count_word(_row(game.hud, "meat_spoiled")), "")
	game.hud._close_modal()


func test_a_tin_gone_off_gathers_with_the_dented_ones_and_leaves_no_row_of_its_own() -> void:
	var game = _game()
	game.hud.loot(_box(game, ["can_dented_bad", "can_dented"]))
	assert_eq(_near_rows(game.hud).size(), 1)
	assert_null(_row(game.hud, "can_dented_bad"), "no row names the bad one")
	assert_eq(_count_word(_row(game.hud, "can_dented")), "×2")
	game.hud._close_modal()


func test_a_press_takes_one_and_the_row_counts_down() -> void:
	var game = _game()
	var p = game.player
	var id: String = _box(game, ["can_beans", "scrap", "can_beans", "can_beans"])
	var c: Dictionary = game.data["containers"][id]
	game.hud.loot(id)
	_row(game.hud, "can_beans").pressed.emit()
	assert_eq(game.actions.taking_item(p), "can_beans")
	assert_eq(c["items"].size(), 4, "still in the box while it comes out")
	_step(game, p)
	assert_eq(p.action, "", "only one comes out")
	assert_eq(int(p.items.get("can_beans", 0)), 1)
	assert_eq(c["items"].count("can_beans"), 2)
	assert_eq(_count_word(_row(game.hud, "can_beans")), "×2", "laid again with what is left")
	game.hud._close_modal()


func test_a_press_on_a_stack_gone_meanwhile_takes_nothing() -> void:
	var game = _game()
	var p = game.player
	var id: String = _box(game, ["scrap", "scrap"])
	game.hud.loot(id)
	var row: Button = _row(game.hud, "scrap")
	game.data["containers"][id]["items"] = ["wood"]
	row.pressed.emit()
	assert_eq(p.action, "", "nothing of the kind is left to take")
	assert_eq(game.data["containers"][id]["items"], ["wood"], "the wood is not taken in its place")
	assert_null(_row(game.hud, "scrap"), "laid again without it")
	game.hud._close_modal()


## What the box side shows while the first of the dented pair comes out, by a
## real press of its row: the rows' words, which row has the bar and how full at
## half the time, and the time the take costs.
func _seen_while_taking(game, items: Array) -> Dictionary:
	var p = game.player
	p.items.clear()
	var id: String = _box(game, items)
	game.hud.loot(id)
	_row(game.hud, "can_dented").pressed.emit()
	var taking: String = game.actions.taking_item(p)
	var total: float = p.action_total
	p.action_t = total * 0.5
	game.hud.loot(id)
	var rows: Array = _near_rows(game.hud).map(func(b: Button) -> String: return "%s|%s" % [b.text, str(b.disabled)])
	var barred: Array = []
	var fill: float = -1.0
	for b: Button in _near_rows(game.hud):
		var bar := b.get_node_or_null("TakeBar") as ProgressBar
		if bar != null:
			barred.append(String(b.get_meta("item_id")))
			fill = bar.value
	# Let it finish, so the next box starts with free hands.
	_step(game, p)
	game.hud._close_modal()
	return {"taking": taking, "total": total, "rows": rows, "barred": barred, "fill": fill}


func test_a_tin_gone_off_comes_out_looking_and_timing_as_a_plain_one() -> void:
	var game = _game()
	var plain: Dictionary = _seen_while_taking(game, ["can_dented", "can_dented", "scrap"])
	var hidden: Dictionary = _seen_while_taking(game, ["can_dented_bad", "can_dented", "scrap"])
	assert_eq(hidden["taking"], "can_dented_bad", "the press took the first in the box, the bad one")
	assert_eq(plain["taking"], "can_dented")
	assert_almost_eq(float(hidden["total"]), float(plain["total"]), 0.0001, "the same time")
	assert_eq(hidden["rows"], plain["rows"], "the same rows, words and waiting")
	assert_eq(hidden["barred"], ["can_dented"], "the bar on the dented row")
	assert_eq(hidden["barred"], plain["barred"])
	assert_almost_eq(float(hidden["fill"]), float(plain["fill"]), 0.0001, "as full at half the time")


func test_rows_of_one_weight_keep_the_order_they_lie_in() -> void:
	var game = _game()
	var hud = game.hud
	# Three openers (0.1 each, added up in floats) weigh what one handful of springs does.
	assert_almost_eq(Carry.item_weight("can_opener") * 3.0, Carry.item_weight("springs"), 0.0001)
	assert_eq(InventoryPane.weight_key(0.1 + 0.1 + 0.1), InventoryPane.weight_key(0.3))
	hud.loot(_box(game, ["springs", "can_opener", "can_opener", "can_opener"]))
	var rows: Array = _near_rows(hud).map(func(b: Button) -> String: return String(b.get_meta("item_id")))
	assert_eq(rows, ["springs", "can_opener"], "a tie keeps the first laid first")
	hud._lay_bag_again()
	rows = _near_rows(hud).map(func(b: Button) -> String: return String(b.get_meta("item_id")))
	assert_eq(rows, ["springs", "can_opener"], "and again when laid over itself")
	hud._close_modal()


func test_a_held_stack_stays_open_as_it_counts_down_and_closes_when_gone() -> void:
	var game = _game()
	var p = game.player
	var hud = game.hud
	var id: String = _box(game, ["can_beans", "scrap", "can_beans", "can_beans"])
	hud.loot(id)
	hud._inv_expand("near", "can_beans")
	for left: int in [2, 1, 0]:
		(hud.modal.find_child("Take", true, false) as Button).pressed.emit()
		assert_null(hud.modal.find_child("More", true, false), "rows wait (and fold) while it comes out")
		_step(game, p)
		var more := hud.modal.find_child("More", true, false) as Control
		var every := hud.modal.find_child("TakeKind", true, false) as Button
		if left == 0:
			assert_null(_row(hud, "can_beans"), "the last one out: no row")
			assert_null(more, "and nothing held open")
		else:
			assert_not_null(more, "open again with %d left" % left)
			assert_eq(_count_word(_row(hud, "can_beans")), "×%d" % left if left > 1 else "")
			if left > 1:
				assert_eq((every.find_child("Word", true, false) as Label).text, "×%d" % left)
			else:
				assert_null(every, "one left: the take is all of it")
	assert_eq(int(p.items.get("can_beans", 0)), 3)
	hud._close_modal()


func test_a_held_stack_opens_only_beside_its_own_box() -> void:
	var game = _game()
	var hud = game.hud
	var id: String = _box(game, ["scrap", "scrap"])
	game.ground_items.append({"pos": game.player.position, "id": "scrap", "n": 1})
	hud.loot(id)
	hud._inv_expand("near", "scrap")
	assert_not_null(hud.modal.find_child("More", true, false))
	hud._inv_place({"kind": "ground", "id": "", "name": "바닥"})
	assert_not_null(_row(hud, "scrap"), "the floor's scrap is there")
	assert_null(hud.modal.find_child("More", true, false), "the box's held row does not open on the floor")
	hud._inv_place({"kind": "box", "id": id, "name": "궤"})
	assert_not_null(hud.modal.find_child("More", true, false), "back at the box, it is still held open")
	hud._close_modal()


func test_a_kind_taken_away_while_it_comes_out_is_not_given_twice() -> void:
	var game = _game()
	var p = game.player
	var id: String = _box(game, ["scrap", "scrap", "wood"])
	var c: Dictionary = game.data["containers"][id]
	game.actions.take_kind(p, id, "scrap")
	assert_eq(game.actions.taking_item(p), "scrap")
	# A companion takes one of the two meanwhile: one is left for this hand.
	c["items"].erase("scrap")
	_step(game, p)
	assert_eq(int(p.items.get("scrap", 0)), 1)
	assert_eq(p.action, "", "none left to go on with")
	assert_eq(c["items"], ["wood"])
	assert_false(game.actions.take_queue.has(p.get_instance_id()), "the queue is gone")
	# All of it taken away meanwhile: nothing is given.
	c["items"] = ["scrap", "wood"]
	game.actions.take_kind(p, id, "scrap")
	c["items"] = ["wood"]
	_step(game, p)
	assert_eq(int(p.items.get("scrap", 0)), 1, "nothing out of thin air")
	assert_eq(c["items"], ["wood"])


func test_a_new_take_after_a_stop_does_not_go_on_with_the_old_kind() -> void:
	var game = _game()
	var p = game.player
	var id: String = _box(game, ["scrap", "scrap", "scrap", "wood"])
	var c: Dictionary = game.data["containers"][id]
	game.hud.loot(id)
	game.actions.take_kind(p, id, "scrap")
	_step(game, p)
	p.stick = Vector2(1, 0)
	game._update_person(p, 0.05)
	p.stick = Vector2.ZERO
	assert_ne(p.action, "take")
	game.hud._loot_take_kind(id, "wood")
	assert_eq(game.actions.taking_item(p), "wood")
	_step(game, p)
	assert_eq(p.action, "", "the wood alone")
	assert_eq(c["items"], ["scrap", "scrap"], "the scrap left stays")
	assert_eq([int(p.items.get("scrap", 0)), int(p.items.get("wood", 0))], [1, 1])
	game.hud._close_modal()


func test_all_of_a_kind_skips_weapons_put_away_on_a_sled() -> void:
	var game = _game()
	var p = game.player
	p.sled_weapon_stowed = true
	var id: String = _box(game, ["knife", "knife", "wood"])
	game.actions.take_kind(p, id, "knife")
	assert_eq(p.action, "", "no hand free for them")
	assert_false(game.actions.take_queue.has(p.get_instance_id()))
	assert_eq(game.data["containers"][id]["items"], ["knife", "knife", "wood"])


func test_a_held_stack_offers_all_of_its_kind_and_takes_only_those() -> void:
	var game = _game()
	var p = game.player
	var hud = game.hud
	var id: String = _box(game, ["can_beans", "scrap", "can_beans", "can_beans"])
	var c: Dictionary = game.data["containers"][id]
	hud.loot(id)
	_row(hud, "can_beans").button_down.emit()
	await _wait(InventoryPane.LONG_S + 0.15)
	var every := hud.modal.find_child("TakeKind", true, false) as Button
	assert_not_null(every, "a stack of three offers them all")
	assert_eq((every.find_child("Word", true, false) as Label).text, "×3", "its count drawn on it")
	assert_not_null(hud.modal.find_child("Take", true, false), "beside the one-at-a-time key")
	every.pressed.emit()
	var order: Array = []
	for i in range(8):
		if p.action != "take":
			break
		order.append(game.actions.taking_item(p))
		_step(game, p)
	assert_eq(order, ["can_beans", "can_beans", "can_beans"], "one after another, the scrap left")
	assert_eq(c["items"], ["scrap"])
	assert_eq(int(p.items.get("can_beans", 0)), 3)
	hud._close_modal()


func test_all_of_a_kind_takes_the_hidden_twin_as_one_of_them() -> void:
	var game = _game()
	var p = game.player
	var id: String = _box(game, ["can_dented", "wood", "can_dented_bad"])
	var c: Dictionary = game.data["containers"][id]
	game.actions.take_kind(p, id, "can_dented")
	for i in range(6):
		if p.action != "take":
			break
		_step(game, p)
	assert_eq(c["items"], ["wood"])
	assert_eq([int(p.items.get("can_dented", 0)), int(p.items.get("can_dented_bad", 0))], [1, 1], "each keeps its own id in the bag")


func test_all_of_a_kind_stops_where_the_stick_lets_it_go() -> void:
	var game = _game()
	var p = game.player
	var id: String = _box(game, ["scrap", "scrap", "scrap"])
	var c: Dictionary = game.data["containers"][id]
	game.actions.take_kind(p, id, "scrap")
	_step(game, p)
	assert_eq(c["items"].size(), 2, "one out")
	p.stick = Vector2(1, 0)
	game._update_person(p, 0.05)
	p.stick = Vector2.ZERO
	for i in range(3):
		game._update_person(p, 0.1)
	assert_eq(c["items"].size(), 2, "the rest stays in")
	assert_eq(p.action, "")


func test_all_of_a_kind_with_none_left_or_clothes_only_does_nothing() -> void:
	var game = _game()
	var p = game.player
	var garment: String = "hat_knit"
	var id: String = _box(game, [garment, garment, "wood"])
	game.actions.take_kind(p, id, "scrap")
	assert_eq(p.action, "", "no scrap in the box")
	game.actions.take_kind(p, id, garment)
	assert_eq(p.action, "", "clothes are put on one at a time")
	assert_eq(game.data["containers"][id]["items"], [garment, garment, "wood"])


func test_one_alone_and_clothes_offer_no_all_key() -> void:
	var game = _game()
	var hud = game.hud
	var garment: String = "hat_knit"
	hud.loot(_box(game, ["scrap", garment, garment]))
	_row(hud, "scrap").button_down.emit()
	await _wait(InventoryPane.LONG_S + 0.15)
	assert_not_null(hud.modal.find_child("Take", true, false))
	assert_null(hud.modal.find_child("TakeKind", true, false), "one alone: the take is all of it")
	hud._inv_expand("near", "scrap")
	hud._inv_expand("near", garment)
	assert_not_null(hud.modal.find_child("More", true, false))
	assert_eq(_count_word(_row(hud, garment)), "×2")
	assert_null(hud.modal.find_child("TakeKind", true, false), "clothes are put on one at a time")
	hud._close_modal()


# ---------------------------------------------------------------- the test keys


func test_zoom_and_debug_keys_are_for_debug_builds_only() -> void:
	assert_eq(FieldHud.test_key_words(false), [], "a release export shows none")
	assert_eq(FieldHud.test_key_words(true), ["−", "+", "D"])
	for word: String in FieldHud.test_key_words(true):
		assert_true(FieldHud.TEST_KEY_W.has(word), "a width for %s" % word)


func test_a_debug_run_lays_the_three_test_keys_in_order() -> void:
	var game = _game()
	assert_true(OS.is_debug_build(), "tests run in a debug build")
	var words: Array = game.hud.test_keys.get_children().map(func(k: Node) -> String: return (k as Button).text)
	assert_eq(words, ["−", "+", "D"])
