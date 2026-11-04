extends "res://addons/gut/test.gd"
## 2026-11-02 user's pick: body burden and actual storage weight stay separate.

const Carry = preload("res://game/sim/carry.gd")
const Person = preload("res://game/actors/person.gd")
const FieldGame = preload("res://game/field_game.gd")
const Sled = preload("res://game/sim/sled.gd")
const Stamina = preload("res://game/sim/stamina.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const InventoryPane = preload("res://game/ui/inventory_pane.gd")


func _person(bag: String = "pack", count: int = 8):
	var p := Person.new()
	add_child_autofree(p)
	p.bag = bag
	p.items = {"wood": count}
	p.hands.clear()
	return p


func test_pack_eight_becomes_5_6() -> void:
	var p = _person()
	assert_almost_eq(p.body_burden(), 5.6, 0.00001)
	assert_eq(p.weight(), 8.0)
	assert_eq(p.carry_limit(), 8.0)


func test_big_pack_twelve_becomes_9_6() -> void:
	var p = _person("big_pack", 12)
	assert_almost_eq(p.body_burden(), 9.6, 0.00001)
	assert_eq(p.weight(), 12.0)
	assert_eq(p.carry_limit(), 12.0)


# What is packed past the bag's limit is not lightened: it weighs in whole on top
# of the lightened full bag (2026-11-02 user's pick, over-filling never runs free).
func test_packed_past_the_limit_is_not_relieved() -> void:
	var p = _person("pack", 10)
	assert_almost_eq(p.body_burden(), 8.0 * 0.7 + 2.0, 0.00001)
	p.items = {"wood": 8}
	assert_almost_eq(p.body_burden(), 5.6, 0.00001, "a full bag, all of it lightened")
	var big = _person("big_pack", 15)
	assert_almost_eq(big.body_burden(), 12.0 * 0.8 + 3.0, 0.00001)
	assert_almost_eq(Carry.body_burden("pack", 10.0, 1.0, 8.0), 1.0 + 5.6 + 2.0, 0.00001)
	assert_almost_eq(Carry.body_burden("pack", 10.0, 1.0, 10.0), 1.0 + 7.0, 0.00001, "a strong carrier's limit lightens all ten")


# Over (no running) is the bag packed past its limit, the weight outside the bag
# left out; or the body's load past the limit (2026-11-02 user's pick).
func test_a_full_bag_runs_and_an_over_filled_one_does_not() -> void:
	var p = _person("pack", 8)
	p.heat.wet = 1.0
	assert_almost_eq(p.weight(), 9.0, 0.00001, "a full pack and soaked clothes")
	assert_eq(p.carry_state(), 1, "a full pack with a start weight runs, short of breath sooner")
	assert_true(p.load_lets_run())
	p.items = {"wood": 10}
	assert_eq(p.carry_state(), 2, "packed past the limit: over")
	assert_false(p.load_lets_run())
	var bare = _person("pack", 10)
	assert_almost_eq(bare.body_burden(), 7.6, 0.00001, "lightened under the limit")
	assert_eq(bare.carry_state(), 2, "with no start weight an over-filled pack is still over")
	assert_false(bare.load_lets_run())
	bare.items = {"wood": 17}
	assert_lt(bare.body_burden(), 2.0 * bare.carry_limit(), "lightened short of double")
	assert_eq(bare.carry_state(), 3, "packed past double still cannot move")
	# Packed past the limit but short of double, the bell in the arms takes the whole past double.
	bare.items = {"wood": 13, "symbol_bell": 1}
	assert_almost_eq(bare.weight(), 17.0, 0.00001)
	assert_eq(bare.carry_state(), 3, "the whole weight past double, not only what is packed")
	bare.items = {"wood": 16}
	assert_eq(bare.carry_state(), 2, "exactly double still moves")


func test_what_is_held_can_put_the_body_over() -> void:
	var p = _person("pack", 6)
	p.items["symbol_bell"] = 1
	assert_almost_eq(p.body_burden(), 6.0 * 0.7 + 4.0, 0.00001, "the bell in the arms weighs in whole")
	assert_gt(p.body_burden(), p.carry_limit())
	assert_eq(p.carry_state(), 2, "the body's load past the limit: over")


func test_pockets_have_no_relief() -> void:
	var p = _person("pockets", 3)
	assert_eq(p.body_burden(), p.weight())
	assert_eq(p.carry_limit(), 3.0)
	assert_eq(Carry.body_burden("unknown", 3.0, 2.0, 3.0), 5.0)


func test_the_weapon_in_hand_weighs_as_it_did() -> void:
	var p = _person()
	p.hands = [{"id": "axe"}]
	assert_almost_eq(p.body_burden(), 5.6, 0.00001, "the weapon in hand still adds nothing")
	assert_eq(p.weight(), 8.0)
	p.bag = "pockets"
	assert_eq(p.body_burden(), p.weight(), "with no bag to lighten, the load is what it was")


func test_large_armful_is_not_a_bag_content() -> void:
	var p = _person("pack", 4)
	p.items["symbol_bell"] = 1
	assert_eq(p.weight(), 8.0)
	assert_almost_eq(p.body_burden(), 6.8, 0.00001)
	assert_false(p.load_lets_run(), "the existing both-arms rule still applies")


func test_reserve_and_soaked_clothes_keep_their_original_weight() -> void:
	var p = _person()
	p.hands = [{"id": ""}, {"id": "axe"}]
	p.heat.wet = 1.0
	assert_almost_eq(p.body_burden(), 5.6 + 1.5 + 1.0, 0.00001)
	assert_almost_eq(p.weight(), 8.0 + 1.5 + 1.0, 0.00001)


func test_body_state_drops_one_tier_at_half_and_full_boundaries() -> void:
	var p = _person("pack", 5)
	assert_eq(Carry.state(p.weight(), p.carry_limit()), 1)
	assert_eq(p.carry_state(), 0)
	# A full pack and a spare axe: over by the whole weight, not by the body's load.
	p.items = {"wood": 8}
	p.hands = [{"id": ""}, {"id": "axe"}]
	assert_eq(Carry.state(p.weight(), p.carry_limit()), 2)
	assert_eq(p.carry_state(), 1)
	assert_true(p.load_lets_run(), "small packed items allow running here")
	p.running = true
	p.moving = true
	assert_eq(p.body_context()["carry_state"], 1)
	var breath: Vector2 = Stamina.advance(0.0, 1.0, 1.0, p.body_context())
	var expected: Vector2 = Stamina.advance(0.0, 1.0, 1.0, {"running": true, "moving": true, "carry_state": 1})
	assert_almost_eq(breath.y, expected.y, 0.00001)


func test_raw_state_and_sled_capacity_still_use_actual_weight() -> void:
	assert_eq(Carry.state(8.01, 8.0), 2)
	assert_eq(Carry.state(16.01, 8.0), 3)
	assert_eq(Sled.weight({"items": {"wood": 13}}), 13.0)
	assert_eq(Sled.state({"items": {"wood": 13}}), 2)
	var box := {"furniture": "nightstand", "items": ["wood", "wood", "wood", "wood", "wood", "wood"]}
	assert_eq(Carry.box_load(box), 6.0)
	assert_eq(Carry.box_room(box, "wood"), 0)


func _field():
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false}
	add_child_autofree(game)
	game.set_process(false)
	game.player.bag = "pack"
	game.player.skills["strength"] = 5
	game.player.items = {"wood": 8}
	game.player.hands.clear()
	return game


func test_companion_cannot_use_relief_as_extra_storage() -> void:
	var game = _field()
	var p = game.player
	var box := {"items": ["wood"]}
	assert_lt(p.body_burden(), p.carry_limit())
	game.actions._companion_take(p, box)
	assert_eq(p.items["wood"], 8, "a full bag cannot accept another item")
	assert_eq(box["items"], ["wood"], "the item stays in the box")
	# With room by the actual weight the same call does take it.
	p.items = {"wood": 7}
	game.actions._companion_take(p, box)
	assert_eq(int(p.items.get("wood", 0)), 8, "room in the bag takes the item")
	assert_true((box["items"] as Array).is_empty(), "the box gives it up")


# The bag's head keeps its weight against the limit, its stage in the number's
# colour (결정 560: the same scale's stage, no state words to cut off); the body's
# load is its own number by the running mark on the rounds' line (결정 558).
func test_body_number_is_on_the_bag_weight_line() -> void:
	var game = _field()
	game.hud.bag_panel()
	var p = game.player
	var load_l := game.hud.modal.find_child("BagLoad", true, false) as Label
	assert_not_null(load_l)
	if load_l != null:
		var head := load_l.text.replace(UiFonts.WORD_JOINER, "")
		assert_eq(head, "8.0 / 8")
		assert_eq(p.carry_state(), 1, "a full pack is past half")
		assert_eq(load_l.get_theme_color("font_color"), InventoryPane.carry_ink(1), "the stage in the number's ink")
		assert_true(load_l.tooltip_text.contains(Carry.STATE_NAMES[1]), "the state's word kept for a long look")
	var head_node: Node = game.hud.modal.find_child("BagHead", true, false)
	assert_not_null(head_node)
	if head_node != null:
		var words: Array = head_node.find_children("*", "Label", true, false).map(func(l) -> String: return String(l.text))
		assert_false("".join(words).contains("몸 부담"), "the head holds the bag alone")
	var burden := game.hud.modal.find_child("Burden", true, false) as Label
	assert_not_null(burden)
	if burden != null:
		assert_eq(burden.text.replace(UiFonts.WORD_JOINER, ""), "%.1f" % p.body_burden())
		assert_eq(burden.text.replace(UiFonts.WORD_JOINER, ""), "5.6")
		assert_eq(burden.tooltip_text, "몸 부담")
		assert_eq(String(burden.get_parent().name), "Ammo", "on the rounds' line")


# 결정 560: worn clothes keep bone bars even when their condition is low.
func test_worn_condition_bars_keep_one_bone_colour() -> void:
	var game = _field()
	for slot: String in InventoryPane.Wear.SLOTS:
		var garment: Dictionary = InventoryPane.Wear.occupant(game.player, slot)
		if not garment.is_empty():
			garment["wear"] = 0.9
	var parts: Array = InventoryPane._worn(game.hud, game.player)
	add_child_autofree(parts[0])
	add_child_autofree(parts[1])
	var bars: Array = parts[0].find_children("*", "ProgressBar", true, false)
	assert_gt(bars.size(), 0)
	for bar: ProgressBar in bars:
		assert_eq((bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color, InventoryPane.BONE)
