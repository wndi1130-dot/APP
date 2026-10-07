extends "res://addons/gut/test.gd"

const C = preload("res://game/sim/carry.gd")


func test_bags_and_limit_by_strength() -> void:
	assert_eq(C.limit("pockets", 5), 3.0)
	assert_eq(C.limit("pack", 5), 8.0)
	assert_eq(C.limit("big_pack", 5), 12.0)
	assert_eq(C.limit("pack", 7), 10.0)
	assert_eq(C.limit("pack", 6), 8.0)
	assert_eq(C.limit("pack", 4), 8.0)
	assert_eq(C.limit("pack", 3), 6.0)
	assert_eq(C.limit("pockets", 1), 1.0)
	assert_eq(C.limit("nonsense", 5), 3.0)


func test_state_boundaries() -> void:
	assert_eq(C.state(0.0, 8.0), 0)
	assert_eq(C.state(4.0, 8.0), 0)
	assert_eq(C.state(4.01, 8.0), 1)
	assert_eq(C.state(8.0, 8.0), 1)
	assert_eq(C.state(8.01, 8.0), 2)
	assert_eq(C.state(16.0, 8.0), 2)
	assert_eq(C.state(16.01, 8.0), 3)


func test_item_weights_and_names() -> void:
	assert_eq(C.ITEM_WEIGHTS["symbol_bell"], 4.0)
	assert_eq(C.ITEM_WEIGHTS["document"], 0.5)
	assert_eq(C.ITEM_WEIGHTS["bandage"], 0.1)
	for id: String in C.ITEM_WEIGHTS:
		assert_true(C.ITEM_NAMES.has(id), id)
	assert_eq(C.item_weight("axe"), 3.0)
	assert_eq(C.item_weight("nothing"), 0.0)
	assert_almost_eq(C.total_weight({"food_pack": 2, "bandage": 3, "pistol": 1}), 4.3, 0.0001)


func test_symbol_bell_overloads_pockets() -> void:
	assert_eq(C.state(C.total_weight({"symbol_bell": 1}), C.limit("pockets", 5)), 2)


func test_swap_time() -> void:
	assert_eq(C.swap_time("hand", 3), 0.5)
	assert_eq(C.swap_time("belt", 3), 1.0)
	assert_eq(C.swap_time("bag", 0), 2.5)
	assert_eq(C.swap_time("bag", 1), 3.5)
	assert_eq(C.swap_time("bag", 2), 3.5)
