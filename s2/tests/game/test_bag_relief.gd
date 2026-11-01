extends "res://addons/gut/test.gd"
## 2026-11-02 사용자 결정: body burden and actual storage weight stay separate.

const Carry = preload("res://game/sim/carry.gd")
const Person = preload("res://game/actors/person.gd")
const FieldGame = preload("res://game/field_game.gd")
const Sled = preload("res://game/sim/sled.gd")
const Stamina = preload("res://game/sim/stamina.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


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


func test_pockets_have_no_relief() -> void:
	var p = _person("pockets", 3)
	assert_eq(p.body_burden(), p.weight())
	assert_eq(p.carry_limit(), 3.0)
	assert_eq(Carry.body_burden("unknown", 3.0, 2.0), 5.0)


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
	p.items = {"wood": 9}
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


func test_body_number_is_on_the_person_bag_header() -> void:
	var game = _field()
	game.hud._inv_bag()
	var side := game.hud.modal.find_child("Side", true, false) as Label
	assert_not_null(side)
	if side != null:
		var text := side.text.replace(UiFonts.WORD_JOINER, "")
		assert_true(text.contains("8.0 / 8"))
		assert_true(text.contains("몸 부담 5.6"))
