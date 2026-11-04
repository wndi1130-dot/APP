extends "res://addons/gut/test.gd"
## The bag and the selected place side by side (결정 558 「나」). A press still
## moves a thing to the place shown, box, ground or train's hold.

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


func test_the_bag_and_what_is_near_stand_side_by_side() -> void:
	var game = _game()
	var p = game.player
	var box := _at_a_box(game)
	assert_ne(box, "")
	p.add_item("scrap", 1)
	game.hud.bag_panel()
	var places: Array = _texts(game.hud, "Places")
	var place_ids: Array = game.hud.modal.find_child("Places", true, false).get_children().map(func(b) -> String: return String(b.get_meta("place_id")) if b.has_meta("place_id") else "")
	assert_has(place_ids, box)
	assert_has(places, "바닥")
	assert_false(places.has("열차"), "the hold only by the train")
	assert_eq(String(game.hud.inv_near["kind"]), "box", "a box near comes first away from the train")
	assert_false(_texts(game.hud, "Bag").is_empty(), "the bag's rows")
	game.hud._inv_place({"kind": "box", "id": box})
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


## The box's load against its limit, at the head of the place's column.
func _box_load_text(hud) -> String:
	var node := hud.modal.find_child("Side", true, false) as Label
	return "" if node == null else node.text.replace(UiFonts.WORD_JOINER, "")


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
	assert_eq(_box_load_text(game.hud), "5.0 / 6")
	game.hud._inv_put("scrap")
	assert_eq(c["items"].count("scrap"), 1, "one more fits")
	assert_eq(_box_load_text(game.hud), "6.0 / 6")
	game.hud.bag_panel()
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
	assert_eq(_box_load_text(game.hud), "7.0 / 6", "what the map put there stays")
	game.hud._loot_take(box, 0)
	while p.action == "take":
		p.action_t = 0.001
		game._update_person(p, 0.1)
	assert_eq(int(p.items.get("food_pack", 0)), 1, "and can be taken")
	p.add_item("bandage", 1)
	assert_eq(Carry.box_room(c, "bandage"), 0, "but nothing goes back while it is over")
	game.hud._close_modal()


## On a wide phone the canvas is 390 mockup px high: a full box, a full bag and a full coat
## still leave 「모두 담기」 on the screen — the lists give up height (decision 472 6).
func test_a_full_pane_stays_inside_the_screen() -> void:
	var game = _game()
	var p = game.player
	var box := _at_a_box(game)
	var c: Dictionary = game.data["containers"][box]
	c["items"] = ["food_pack", "scrap", "wood", "cloth", "bandage", "document", "plank", "medkit", "flare", "scrap", "wood", "food_pack"]
	for id in ["scrap", "wood", "cloth", "bandage", "plank", "flare", "document", "medkit", "bottle_spirit", "tweezers"]:
		p.add_item(id, 1)
	game.hud.loot(box)
	var pane: Control = game.hud.modal.find_child("Pane", true, false)
	var bottom: float = pane.position.y + pane.get_combined_minimum_size().y
	assert_lte(bottom, pane.get_viewport_rect().size.y, "the foot is on the screen")
	var keys: Array = game.hud.modal.find_children("*", "Button", true, false).map(func(b) -> String: return String(b.text))
	assert_has(keys, "모두 담기")
	assert_eq(_texts(game.hud, "Near").size(), c["items"].size(), "every row still there, to drag to")
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


func _hand(id: String) -> Dictionary:
	return {"id": id, "quality": "factory", "condition": 1.0, "loaded": 0}


## The weapons at the bag's top are their names only; a press on one shows how
## fast it attacks and its weight, a second press hides them (결정 555). No
## words about what it does.
func test_the_bag_names_its_weapons_and_a_press_shows_speed_and_weight() -> void:
	var game = _game()
	var p = game.player
	p.hands = [_hand("axe"), _hand("pistol")]
	game.hud.bag_panel()
	var held: Node = game.hud.modal.find_child("Weapons", true, false)
	assert_not_null(held, "the weapons' block at the bag's top")
	var first: Button = held.find_child("WeaponName0", true, false) as Button
	var second: Button = held.find_child("WeaponName1", true, false) as Button
	assert_not_null(first)
	assert_not_null(second)
	assert_eq(first.text, game.hud.short_weapon(p))
	assert_eq(second.text, InventoryPane._last_word(String(InventoryPane.W.get_data("pistol")["name"])))
	assert_null(held.find_child("WeaponStats", true, false), "names only until one is pressed")
	# Nothing but the names: one row of the two weapon keys and the swap key (결정
	# 558), and no other words anywhere in the block (no line under them, however
	# short) — each key's own name the only word on it.
	assert_eq(held.get_child_count(), 1, "the keys' row alone")
	var names_row: Node = held.get_child(0)
	assert_eq(names_row.get_children().map(func(n: Node) -> String: return String(n.name)), ["WeaponName0", "WeaponName1", "Swap"])
	var words: Array = held.find_children("*", "Label", true, false) + held.find_children("*", "RichTextLabel", true, false)
	assert_eq(words.map(func(n: Node) -> String: return String(n.get("text"))), [first.text, second.text], "no words but the two names")
	first.pressed.emit()
	held = game.hud.modal.find_child("Weapons", true, false)
	assert_not_null(held.find_child("WeaponStats", true, false), "a press shows the numbers")
	assert_eq((held.find_child("WeaponSpeed", true, false) as Label).text, "1.2초", "a hatchet's swing 0.9 and rest 0.3")
	assert_eq((held.find_child("WeaponWeight", true, false) as Label).text, "3.0")
	(held.find_child("WeaponName1", true, false) as Button).pressed.emit()
	held = game.hud.modal.find_child("Weapons", true, false)
	assert_eq((held.find_child("WeaponSpeed", true, false) as Label).text, "1.0초", "the other weapon's numbers instead")
	assert_eq((held.find_child("WeaponWeight", true, false) as Label).text, "2.0")
	(held.find_child("WeaponName1", true, false) as Button).pressed.emit()
	held = game.hud.modal.find_child("Weapons", true, false)
	assert_null(held.find_child("WeaponStats", true, false), "pressed again, hidden")
	(held.find_child("WeaponName0", true, false) as Button).pressed.emit()
	game.hud._close_modal()
	game.hud.bag_panel()
	assert_null(game.hud.modal.find_child("WeaponStats", true, false), "a bag opened afresh shows the names only")
	game.hud._close_modal()
	p.hands = []
	game.hud.bag_panel()
	assert_null(game.hud.modal.find_child("WeaponName0", true, false), "bare hands: no weapon to press")
	game.hud._close_modal()


## A pane opened afresh another way than the bag key (a box) names the weapons
## only too, however it was left.
func test_a_box_opening_the_pane_afresh_shows_the_names_only() -> void:
	var game = _game()
	var p = game.player
	p.hands = [_hand("axe"), _hand("pistol")]
	game.hud.bag_panel()
	game.hud._inv_weapon(0)
	assert_not_null(game.hud.modal.find_child("WeaponStats", true, false))
	game.hud._close_modal()
	game.hud.loot(_at_a_box(game))
	game.hud.bag_panel()
	assert_not_null(game.hud.modal.find_child("WeaponName0", true, false))
	assert_null(game.hud.modal.find_child("WeaponStats", true, false), "opened by the box: names only")
	game.hud._close_modal()


## The numbers stay with the weapon pressed: one taken into the hand goes first and
## the pressed one moves to the second place, its numbers with it; gone, they close.
func test_the_numbers_follow_the_weapon_pressed() -> void:
	var game = _game()
	var p = game.player
	p.hands = [_hand("axe"), _hand("pistol")]
	game.hud.bag_panel()
	game.hud._inv_weapon(0)
	p.hands.insert(0, _hand("knife"))
	game.hud.bag_panel()
	var held: Node = game.hud.modal.find_child("Weapons", true, false)
	assert_eq((held.find_child("WeaponSpeed", true, false) as Label).text, "1.2초", "still the hatchet's numbers")
	assert_eq(game.hud.inv_weapon_open, 1, "now the second named")
	assert_eq(((held.find_child("WeaponName1", true, false) as Button).get_theme_stylebox("normal") as StyleBoxFlat).border_color, InventoryPane.BONE, "its key the lit one")
	assert_eq(((held.find_child("WeaponName0", true, false) as Button).get_theme_stylebox("normal") as StyleBoxFlat).border_color, InventoryPane.GlassPane.HAIR, "the new one unlit")
	p.hands.remove_at(1)
	game.hud.bag_panel()
	assert_null(game.hud.modal.find_child("WeaponStats", true, false), "the hatchet gone from the two: closed")
	assert_eq(game.hud.inv_weapon_open, -1)
	game.hud._close_modal()


## Two weapons, a full bag and one weapon's numbers open (a row more at the
## bag's top): the pane still lands on the screen.
func test_a_full_bag_with_a_weapons_numbers_open_stays_on_the_screen() -> void:
	var game = _game()
	var p = game.player
	p.hands = [_hand("pistol"), _hand("knife")]
	for id in ["scrap", "wood", "cloth", "bandage", "plank", "flare", "document", "medkit", "bottle_spirit", "tweezers"]:
		p.add_item(id, 1)
	game.hud.bag_panel()
	game.hud._inv_weapon(1)
	assert_not_null(game.hud.modal.find_child("WeaponStats", true, false), "the numbers are open")
	# The pane fits itself once its slide lands, and the bag's wrapped foot knows
	# its height only once laid out: land it, then lay out.
	var glass = game.hud.modal_pane
	glass.set_process(false)
	for _i in range(120):
		if not glass.is_sliding():
			break
		glass.motion_step(1.0 / 60.0)
	assert_false(glass.is_sliding(), "the pane landed")
	for _i in range(3):
		await get_tree().process_frame
	assert_lte(glass.get_global_rect().end.y, glass.get_viewport_rect().size.y, "a full bag with the numbers open still on the screen")
	game.hud._close_modal()


## Seconds an attack: a melee blow's swing and rest, a gun's aim closing again,
## a single-round weapon's reload; as they read (two places only when needed).
func test_attack_seconds_read_as_the_weapon_paces() -> void:
	assert_almost_eq(InventoryPane.attack_seconds("knife"), 0.6, 0.001)
	assert_almost_eq(InventoryPane.attack_seconds("crowbar"), 0.85, 0.001)
	assert_almost_eq(InventoryPane.attack_seconds("pistol"), 1.0, 0.001)
	assert_almost_eq(InventoryPane.attack_seconds("pipe_shotgun"), 3.0, 0.001, "one round: its reload")
	assert_almost_eq(InventoryPane.attack_seconds("bow"), 1.6, 0.001, "one round, but the aim takes longer")
	assert_eq(InventoryPane.attack_seconds(""), 0.0)
	assert_eq(InventoryPane.seconds_word(0.85), "0.85")
	assert_eq(InventoryPane.seconds_word(0.6), "0.6")
	assert_eq(InventoryPane.seconds_word(3.0), "3.0")
	for id in InventoryPane.W.DATA.keys() + InventoryPane.W.IMPROVISED.keys():
		assert_gt(InventoryPane.attack_seconds(String(id)), 0.0, "%s has a pace" % id)
