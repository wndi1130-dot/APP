extends "res://addons/gut/test.gd"
## 설계도 조각(S1 domestic 5.2, data.ts BYPRODUCT): 정차마다 장소 종류의 확률로 하나,
## 그 장소의 연구 분야 가운데 하나, 사무실 상자(없으면 건물 안 아무 상자)에. 열차에 실은
## 조각은 정차 영수증 extras.fragments에 한 개당 한 칸.

const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

## The first map of each kind of place with a chance.
const MAPS: Dictionary = {"freight": "freight_01", "houses": "houses_01", "hospital": "hospital_01", "factory": "factory_01", "church": "church_01", "office": "office_01"}


func test_the_chances_and_fields_are_the_s1_table() -> void:
	assert_eq(LootDress.FRAGMENT_PLACES, {
		"freight": [0.3, ["engine", "expedition"]], "houses": [0.15, ["med", "expedition"]],
		"hospital": [0.4, ["med"]], "factory": [0.4, ["craft", "engine"]],
		"church": [0.05, "any"], "office": [0.4, ["radio"]],
	})
	assert_eq(Array(LootDress.FRAGMENT_FIELDS), Receipt.FRAGMENT_KINDS, "the receipt's fields")
	for field: String in Receipt.FRAGMENT_KINDS:
		var id := "frag_" + field
		assert_true(FieldItems.has(id), id)
		assert_eq(FieldItems.fragment_of(id), field)
		assert_eq(String(FieldItems.stock_of(id)[0]), "", "not a stock number")
		assert_lte(FieldItems.weight(id), 0.1, "light: moved by the handful")
	assert_eq(FieldItems.fragment_of("document"), "")


func test_each_kind_of_place_finds_one_about_as_often_as_s1_says() -> void:
	# The dice alone, on two boxes of a building (the maps are dressed below).
	for kind: String in LootDress.FRAGMENT_PLACES:
		var row: Array = LootDress.FRAGMENT_PLACES[kind]
		var fields: Array = Receipt.FRAGMENT_KINDS if row[1] is String else row[1]
		var found := 0
		var runs := 2000
		var seen: Dictionary = {}
		for seed in range(1, runs + 1):
			var boxes := {"a": {"name": "사무실 책상", "building": 0, "items": []}, "b": {"name": "창고 상자", "building": 0, "items": []}}
			var report := {"finds": [], "fragment": ""}
			LootDress._fragment(boxes, kind, seed, report)
			var piece := String(report["fragment"])
			if piece == "":
				continue
			found += 1
			seen[FieldItems.fragment_of(piece)] = true
			assert_has(fields, FieldItems.fragment_of(piece), "%s seed %d" % [kind, seed])
			assert_eq(boxes["a"]["items"], [piece], "with the papers")
		assert_almost_eq(found / float(runs), float(row[0]), 0.03, kind)
		if float(row[0]) >= 0.15:
			assert_eq(seen.size(), fields.size(), "every field turns up: " + kind)


func test_on_the_maps_one_piece_at_most_indoors_and_never_in_a_goal_box() -> void:
	for kind: String in MAPS:
		var base: Dictionary = FieldMaps.build(MAPS[kind])
		assert_eq(String(base["place_kind"]), kind, MAPS[kind])
		for seed in range(1, 31):
			var data: Dictionary = base.duplicate(true)
			var report: Dictionary = LootDress.dress(data, seed)
			var pieces: Array = []
			for id: String in data["containers"]:
				for item in data["containers"][id]["items"]:
					if FieldItems.fragment_of(String(item)) != "":
						pieces.append(id)
			assert_lte(pieces.size(), 1, "one a stop at most")
			assert_eq(pieces.size(), 0 if String(report["fragment"]) == "" else 1, "as the report says")
			for id: String in pieces:
				var c: Dictionary = data["containers"][id]
				assert_gte(int(c.get("building", -1)), 0, "indoors")
				assert_false(c.has("pick"), "not a goal's box")


func test_it_lies_with_the_papers_when_the_stop_has_an_office() -> void:
	var base: Dictionary = FieldMaps.build("office_01")
	var offices := 0
	for id: String in base["containers"]:
		var c: Dictionary = base["containers"][id]
		if LootDress.room_of(c) == "office" and int(c.get("building", -1)) >= 0 and not c.has("pick") and not LootDress.LootTables.FIXED.has(id):
			offices += 1
	assert_gt(offices, 0, "the office stop has desks")
	for seed in range(1, 31):
		var data: Dictionary = base.duplicate(true)
		var report: Dictionary = LootDress.dress(data, seed)
		for row: Array in report["finds"]:
			if FieldItems.fragment_of(String(row[0])) != "":
				assert_eq(LootDress.room_of(data["containers"][row[1]]), "office", "seed %d" % seed)


func test_other_places_have_none_and_the_same_seed_gives_the_same_piece() -> void:
	for kind: String in ["lake", "lodge", "mine", "sawmill", "summit", "bare_line"]:
		assert_false(LootDress.FRAGMENT_PLACES.has(kind), kind)
	var a: Dictionary = FieldMaps.build("office_01")
	var b: Dictionary = a.duplicate(true)
	assert_eq(str(LootDress.dress(a, 21)["finds"]), str(LootDress.dress(b, 21)["finds"]))


func _game(place: String):
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "place": place}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	return game


func _board(game) -> void:
	var r: Rect2i = game.data["boarding"][0]
	for q in game.squad:
		q.position = game.lift(r.position + Vector2i(r.size.x / 2, 0), 0)


func test_pieces_aboard_go_on_the_stop_receipt_one_entry_each() -> void:
	var game = _game("office_01")
	assert_true(game.receipt.set_ids("ret_test_01", "stop_test"))
	game.player.add_item("frag_radio", 2)
	game.player.add_item("frag_med")
	_board(game)
	game.finish("departed")
	var d: Dictionary = game.receipt.to_dict()
	var got: Array = d["extras"]["fragments"]
	got.sort()
	assert_eq(got, ["med", "radio", "radio"])
	assert_eq(Array(Receipt.check(d)), [], "the stop receipt's shape")


func test_the_one_who_picks_it_up_says_what_it_is_once() -> void:
	var game = _game("office_01")
	var p = game.player
	p.add_item("frag_craft")
	game._watch_named()
	game._watch_named()
	assert_true(game.named_seen.has("frag_craft"))
	var said := 0
	for n in game.hud.toast_box.find_children("*", "Label", true, false):
		if String(n.text).replace(UiFonts.WORD_JOINER, "").contains("공작 설계도 조각을 찾았다"):
			said += 1
	assert_eq(said, 1, "said once")


func test_a_piece_left_behind_is_not_on_the_receipt() -> void:
	var game = _game("office_01")
	assert_true(game.receipt.set_ids("ret_test_01", "stop_test"))
	var p = game.player
	p.add_item("frag_engine")
	p.position = game.lift(Vector2i(60, 40), 0)
	for q in game.squad:
		if q != p:
			q.position = game.lift(game.data["boarding"][0].position, 0)
	game.finish("departed")
	assert_eq(Array(game.receipt.to_dict()["extras"]["fragments"]), [])
