extends "res://addons/gut/test.gd"
## The bag and what is near on one glass (decision 448-1): a press on a row moves
## it across to the place chosen at the right; a box searched, the ground and the
## train's hold are the places.

const FieldGame = preload("res://game/field_game.gd")
const InventoryPane = preload("res://game/ui/inventory_pane.gd")
const Carry = preload("res://game/sim/carry.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	return game


func _texts(hud, under: String) -> Array:
	var node: Node = hud.modal.find_child(under, true, false)
	if node == null:
		return []
	return node.find_children("*", "Button", true, false).map(func(b) -> String: return String(b.text))


## A box searched and the player at it, away from the train.
func _at_a_box(game) -> String:
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if int(c.get("level", 0)) == 0 and not bool(c.get("locked", false)) and not game.FieldMaps.by_train(game.data, c["cell"], "unloading"):
			c["searched"] = true
			c["items"] = ["food_pack"]
			game.player.position = game.actions._container_at(c)
			return String(id)
	return ""


func test_the_bag_and_what_is_near_side_by_side() -> void:
	var game = _game()
	var p = game.player
	var box := _at_a_box(game)
	assert_ne(box, "")
	p.add_item("scrap", 1)
	game.hud.bag_panel()
	var places: Array = _texts(game.hud, "Places")
	assert_has(places, String(game.data["containers"][box]["name"]))
	assert_has(places, "바닥")
	assert_false(places.has("열차 짐칸"), "the hold only by the train")
	assert_eq(String(game.hud.inv_near["kind"]), "box", "a box near comes first away from the train")
	assert_false(_texts(game.hud, "Bag").is_empty(), "the bag's rows")
	assert_eq(_texts(game.hud, "Near").size(), 1, "the box's one thing")
	game.hud._close_modal()


func test_a_press_moves_a_thing_across() -> void:
	var game = _game()
	var p = game.player
	var box := _at_a_box(game)
	var c: Dictionary = game.data["containers"][box]
	p.add_item("scrap", 2)
	# Into the box, one at a time.
	game.hud.loot(box)
	assert_eq(String(game.hud.inv_near["id"]), box)
	game.hud._inv_put("scrap")
	assert_eq(int(p.items.get("scrap", 0)), 1)
	assert_eq(c["items"].count("scrap"), 1)
	# And out of it again.
	game.hud._loot_take(box, c["items"].find("scrap"))
	while p.action == "take":
		p.action_t = 0.001
		game._update_person(p, 0.1)
	assert_eq(int(p.items.get("scrap", 0)), 2)
	# Onto the ground; a small thing goes by the handful.
	p.add_item("ammo_pistol", 3)
	assert_eq(game.actions.move_count(p, "ammo_pistol"), 3, "a handful at a press")
	assert_eq(game.actions.move_count(p, "scrap"), 1)
	game.hud._inv_place({"kind": "ground", "id": "", "name": "바닥"})
	game.hud._inv_put("scrap")
	assert_eq(int(p.items.get("scrap", 0)), 1)
	var near: Array = game.actions.near_ground(p)
	assert_false(near.is_empty(), "lying at the feet")
	game.hud._inv_pick(near[near.size() - 1])
	assert_eq(int(p.items.get("scrap", 0)), 2, "and picked up again")
	game.hud._close_modal()


func test_by_the_train_the_hold_is_chosen_and_what_stays_cannot_go() -> void:
	var game = _game()
	var p = game.player
	var rect: Rect2i = game.data["unload"]
	p.position = game.lift(rect.position + Vector2i(3, 1), 0)
	p.add_item("scrap", 2)
	game.hud.bag_panel()
	assert_eq(String(game.hud.inv_near["kind"]), "train", "the train's hold first by the train")
	for b in game.hud.modal.find_child("Bag", true, false).find_children("*", "Button", true, false):
		if String(b.text).begins_with(game.item_name("bandage")):
			assert_true(b.disabled, "a bandage stays on the body")
	game.hud._inv_put("scrap")
	assert_eq(int(game.unloaded.get("scrap", 0)), 2, "the kind goes aboard")
	assert_false(p.items.has("scrap"))
	game.hud._close_modal()


func _box_load_text(hud) -> String:
	var node: Node = hud.modal.find_child("BoxLoad", true, false)
	if node == null:
		return ""
	var words: Array = node.find_children("*", "Label", true, false).map(func(l) -> String: return String(l.text))
	return "".join(words).replace(UiFonts.WORD_JOINER, "")


func test_a_box_takes_from_the_bag_only_up_to_its_limit() -> void:
	assert_eq(Carry.box_limit({"furniture": "nightstand"}), Carry.BOX_SMALL)
	assert_eq(Carry.box_limit({"furniture": "dresser"}), Carry.BOX_MID)
	assert_eq(Carry.box_limit({"furniture": "crate_stack"}), Carry.BOX_BIG)
	assert_eq(Carry.box_limit({}), Carry.BOX_BIG, "a box of its own is a crate")
	assert_eq(Carry.box_limit({"furniture": "no_such_thing"}), Carry.BOX_MID)
	var game = _game()
	var p = game.player
	var box := _at_a_box(game)
	var c: Dictionary = game.data["containers"][box]
	c["furniture"] = "nightstand"
	c["items"] = ["food_pack", "food_pack", "food_pack", "food_pack", "food_pack"]
	p.add_item("scrap", 2)
	game.hud.loot(box)
	assert_eq(_box_load_text(game.hud), "담긴 무게 5.0 / 6")
	game.hud._inv_put("scrap")
	assert_eq(c["items"].count("scrap"), 1, "one more fits")
	assert_eq(_box_load_text(game.hud), "담긴 무게 6.0 / 6")
	for b in game.hud.modal.find_child("Bag", true, false).find_children("*", "Button", true, false):
		if String(b.text).begins_with(game.item_name("scrap")):
			assert_true(b.disabled, "no room for the second")
	game.hud._inv_put("scrap")
	assert_eq(int(p.items.get("scrap", 0)), 1, "it stays in the bag")
	# A handful goes in as far as it fits.
	c["items"] = ["food_pack", "food_pack", "food_pack", "food_pack", "food_pack", "document"]
	p.add_item("ammo_pistol", 30)
	game.hud._inv_put("ammo_pistol")
	assert_eq(c["items"].count("ammo_pistol"), 5, "half a weight's room takes five rounds")
	assert_eq(int(p.items.get("ammo_pistol", 0)), 25)
	# The ground takes what the box does not.
	game.hud._inv_place({"kind": "ground", "id": "", "name": "바닥"})
	game.hud._inv_put("scrap")
	assert_false(p.items.has("scrap"), "the ground has no limit")
	game.hud._close_modal()


func test_a_box_dressed_over_its_limit_still_gives() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var box := _at_a_box(game)
	var c: Dictionary = game.data["containers"][box]
	c["furniture"] = "nightstand"
	c["items"] = ["food_pack", "food_pack", "food_pack", "food_pack", "food_pack", "food_pack", "food_pack"]
	game.hud.loot(box)
	assert_eq(_box_load_text(game.hud), "담긴 무게 7.0 / 6", "what the map put there stays")
	game.hud._loot_take(box, 0)
	while p.action == "take":
		p.action_t = 0.001
		game._update_person(p, 0.1)
	assert_eq(int(p.items.get("food_pack", 0)), 1, "and can be taken")
	p.add_item("bandage", 1)
	assert_eq(Carry.box_room(c, "bandage"), 0, "but nothing goes back while it is over")
	game.hud._close_modal()


func test_the_bag_is_ordered_by_weight_or_by_name() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	p.add_item("scrap", 1)
	p.add_item("bandage", 1)
	p.add_item("food_pack", 2)
	assert_eq(InventoryPane.bag_order(game, p, "weight")[0], "food_pack", "the heaviest first")
	var by_name: Array = InventoryPane.bag_order(game, p, "name")
	var names: Array = by_name.map(func(id: String) -> String: return game.item_name(id))
	var sorted_names: Array = names.duplicate()
	sorted_names.sort()
	assert_eq(names, sorted_names)
	game.hud.bag_panel()
	game.hud._inv_sort()
	assert_eq(game.hud.inv_sort, "name")
	game.hud._close_modal()
