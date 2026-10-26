extends "res://addons/gut/test.gd"
## The people who live at a stop (J21, field_residents.gd): an old railwayman
## and his daughter upstairs in the signal box. Help, take or pass by, once a
## stop; what is done goes home as a witnessed row with the companions who saw it.

const FieldGame = preload("res://game/field_game.gd")
const FieldResidents = preload("res://game/field_residents.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false, "raiders": false, "resident_pattern": "b"}
	add_child_autofree(game)
	game.set_process(false)


func _rows(template: String) -> Array:
	var out: Array = []
	for row: Dictionary in game.receipt.to_dict()["witnessed"]:
		if String(row.get("template", "")) == template:
			out.append(row)
	return out


func _stock(key: String) -> int:
	return int(game.receipt.to_dict()["stock"].get(key, 0))


func _count(item: String) -> int:
	var n := 0
	for q in game.squad:
		n += int(q.items.get(item, 0))
	return n


func test_two_live_upstairs_in_the_signal_box_and_are_not_of_the_squad() -> void:
	assert_eq(game.residents.people.size(), 2)
	for p in game.residents.people:
		assert_eq(game.level_of(p.position), 1, "upstairs")
		assert_eq(p.team, "resident")
		assert_false(game.people.has(p), "not counted, followed or healed with the squad")
		assert_false(game.allies_alive().has(p))


func test_the_chief_coming_up_is_warned_and_shown_the_card() -> void:
	assert_false(game.residents.met)
	game.player.position = game.residents.people[0].position + Vector3(1.5, 0, 0)
	game.residents.tick(0.1)
	assert_true(game.residents.met)
	game.residents.tick(0.1)
	assert_eq(game.residents.outcome, "", "the card waits for the chief")


func test_helping_gives_a_bandage_and_a_kit_and_brings_back_the_line_map() -> void:
	var bandages := _count("bandage")
	var kits := _count("medkit")
	game.residents.choose("aid")
	assert_eq(_count("bandage"), bandages - 1)
	assert_eq(_count("medkit"), kits - 1)
	assert_eq(_stock("info"), 1)
	assert_eq(_stock("food"), 1)
	var rows := _rows("resident_aid")
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["who"], game.player.pid)


func test_taking_their_stores_is_seen_by_the_companions_under_the_same_roof() -> void:
	var mate = game.squad[1]
	mate.position = game.residents.people[1].position + Vector3(1.0, 0, 0)
	game.residents.choose("robbed")
	assert_eq(_stock("food"), 2)
	assert_eq(_stock("info"), 1)
	var rows := _rows("resident_robbed")
	assert_eq(rows.size(), 1)
	assert_has(rows[0]["witnesses"], mate.pid)
	assert_does_not_have(rows[0]["witnesses"], game.player.pid, "the one who did it is not their own witness")


func test_passing_by_costs_nothing_now_and_is_kept_once() -> void:
	game.residents.choose("ignored")
	assert_eq(_stock("food"), 0)
	assert_eq(_rows("resident_ignored").size(), 1)
	game.residents.choose("robbed")
	assert_eq(_rows("resident_robbed").size(), 0, "a second choice is not taken")
	assert_eq(game.residents.outcome, "ignored")


func test_the_card_says_what_each_choice_costs_now_and_nothing_after() -> void:
	var labels: Array = []
	for o: Dictionary in game.residents.options():
		labels.append(String(o["label"]))
	assert_true(String(labels[0]).contains("붕대 1"))
	assert_true(String(labels[1]).contains("먹을 것 2"))
	for l: String in labels:
		assert_false(l.contains("기억") or l.contains("나중"), "no later result on the card (decisions 239, 364)")


func test_a_map_without_them_or_a_start_turned_off_has_none() -> void:
	var off = FieldGame.new()
	off.opts = {"seed": 4, "auto_pause": false, "raiders": false, "residents": false}
	add_child_autofree(off)
	off.set_process(false)
	assert_eq(off.residents.people.size(), 0)
	off.residents.tick(0.1)
	assert_false(off.residents.met)
