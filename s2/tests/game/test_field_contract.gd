extends "res://addons/gut/test.gd"
## J09 and the field's side of J01 (s3_departure_receipt_contract.md 2·3): a stop sent under the
## train's departure contract goes out with the train's own people (the same ids, bodies, kit,
## hunger and soreness), and its receipt comes back v5 with the contract's ids, which the train
## takes in as it stands.

const FieldGame = preload("res://game/field_game.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const V = preload("res://tests/politics/field_vectors.gd")


func _state() -> Dictionary:
	return (V.data()["contracts"][0]["state"] as Dictionary).duplicate(true)


func _departure(g: Dictionary) -> Dictionary:
	return FieldDeparture.build(g, V.tables(), {"placeId": "sulechow_station"})


func _game(departure: Dictionary):
	var game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false, "raiders": false, "departure": departure}
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func _board(game) -> void:
	var r: Rect2i = game.data["boarding"][0]
	for q in game.squad:
		q.position = game.lift(r.position + Vector2i(r.size.x / 2, 0), 0)


func test_the_squad_is_the_contract_roster() -> void:
	var d := _departure(_state())
	var game = _game(d)
	var ids: Array = []
	for row: Dictionary in d["roster"]:
		ids.append(row["id"])
	var got: Array = []
	for p in game.squad:
		got.append(p.pid)
	assert_eq(got, ids, "the same people, the same ids")
	assert_eq(game.player.pid, FieldDeparture.CAPTAIN_ID, "the chief leads")
	for i: int in game.squad.size():
		var p = game.squad[i]
		var row: Dictionary = d["roster"][i]
		assert_eq(p.display_name, row["name"])
		for k: String in FieldDeparture.BODY_SKILLS:
			assert_eq(int(p.skills[k]), int(row["body"][k]), "%s %s from the train" % [p.pid, k])
		assert_eq(String(p.hands[0]["id"]), String(row["gear"]["hands"][0][0]), "%s carries the contract's kit" % p.pid)
	assert_true(game.receipt.is_stop_receipt(), "the receipt carries the contract's ids")


func test_hunger_and_soreness_from_the_train_take_from_the_blow() -> void:
	var d := _departure(_state())
	d["roster"][1]["hunger"] = 2
	d["roster"][2]["sore"] = 1
	var game = _game(d)
	var hungry = game.squad[1]
	var sore = game.squad[2]
	assert_eq(hungry.hunger_level, 2)
	assert_eq(sore.sore_level, 1)
	var full := float(hungry.mults()["melee_hit"])
	hungry.hunger_level = 0
	assert_lt(full, float(hungry.mults()["melee_hit"]), "a hungry hand lands fewer blows")


func test_the_return_is_v5_and_the_train_takes_it_in() -> void:
	var g := _state()
	var d := _departure(g)
	var game = _game(d)
	game.squad[1].body.add_wound("arm_left", "fracture", game.clock.elapsed)
	game.squad[1].body.splint_wound(0)
	_board(game)
	game.finish("departed")
	var r: Dictionary = JSON.parse_string(JSON.stringify(game.receipt.to_dict()))
	assert_eq(int(r["version"]), 5)
	assert_eq(Receipt.check(r), [] as Array[String])
	assert_eq(r["departureId"], d["departureId"])
	assert_eq((r["crew"] as Array).size(), game.squad.size(), "how each came back")
	assert_eq(FieldReturn.match_departure(d, r), [] as Array[String])
	var applied := FieldReturn.apply_field_return(g, V.tables(), d, r)
	assert_eq(applied["status"], "applied")
	var hurt_name: String = d["roster"][1]["name"]
	var book: Array = (applied["g"]["wounds"] as Array).filter(func(w: Dictionary) -> bool: return w["who"] == hurt_name)
	assert_eq(book.size(), 1)
	assert_eq([book[0]["grade"], book[0]["part"]], ["fracture", "armL"], "the field's break, not a new draw")
	assert_eq(applied["record"]["sent"], r["people"]["sent"])


func test_care_goes_out_with_the_wound() -> void:
	var b := BodyState.new()
	b.add_wound("arm_left", "fracture", 0.0)
	b.splint_wound(0)
	b.wounds[0]["quick"] = true
	assert_eq(b.receipt_wounds()[0]["treat"], {"splinted": true, "quick": true})
	var plain := BodyState.new()
	plain.add_wound("leg_right", "scratch", 0.0)
	assert_false((plain.receipt_wounds()[0] as Dictionary).has("treat"), "nothing done, nothing said")


func test_the_stop_card_says_who_goes_out_hungry_or_sore_and_what_eases_it() -> void:
	const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
	var lines := StopPickCard.squad_lines([
		{"name": "열차장", "hunger": 0, "sore": 0, "rest": 0},
		{"name": "톰", "hunger": 2, "sore": 1, "rest": 0},
		{"name": "요나", "hunger": 0, "sore": 0, "rest": 1},
	])
	assert_eq(lines.size(), 2, "nothing for the well")
	assert_eq(lines[0], "톰: 굶주림 · 근육통 — 휘두름이 덜 맞는다. 배급을 올리고 한 정차 쉬게 하면 풀린다")
	assert_eq(lines[1], "요나: 근육통 — 휘두름이 덜 맞는다. 한 정차 쉬게 하면 풀린다")
