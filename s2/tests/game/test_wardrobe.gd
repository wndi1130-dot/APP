extends "res://addons/gut/test.gd"
## 옷 PR D(결정 443, 카드 E 가): 겉옷만 열차 옷장 하나로 — 철도원 외투 6벌·장갑 6켤레로 시작,
## 열차장과 동료는 나갈 때 옷장에서 외투와 장갑을 꺼내 입고(상태·구멍 그대로), 비면 외투 없이
## 나가며 필드 시작에 「외투 없음 — 추위」. 작업조는 기본 차림. 옷장이 없는 열차(S1)는 그대로.

const FieldGame = preload("res://game/field_game.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const KitPick = preload("res://game/politics/kit_pick.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const Wear = preload("res://game/sim/wear.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const V = preload("res://tests/politics/field_vectors.gd")


func _state(with_stores: bool) -> Dictionary:
	var g: Dictionary = (V.data()["contracts"][0]["state"] as Dictionary).duplicate(true)
	if with_stores:
		g["dom"] = TrainDom.start()
	return g


func _departure(g: Dictionary) -> Dictionary:
	return FieldDeparture.build(g, V.tables(), {"placeId": "sulechow_station"})


func _game(departure: Dictionary):
	var game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false, "raiders": false, "departure": departure}
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	return game


func test_the_wardrobe_holds_the_outer_things_only() -> void:
	var d: Dictionary = TrainDom.start()
	assert_eq((d["wardrobe"] as Array).filter(func(c) -> bool: return c["id"] == "jacket_short").size(), 6, "six railway coats")
	assert_eq((d["wardrobe"] as Array).filter(func(c) -> bool: return c["id"] == "gloves").size(), 6, "six pairs of gloves")
	assert_true(TrainDom.is_store(d))
	for id: String in ["jacket_short", "coat_long", "coat_leather", "raincoat", "gloves"]:
		assert_true(TrainDom.is_wearable({"id": id, "condition": 0.5}), id)
	for id: String in ["undershirt_cotton", "shirt_cotton", "trousers_cotton", "cape"]:
		assert_false(TrainDom.is_wearable({"id": id, "condition": 0.5}), "not kept in the wardrobe: " + id)
	assert_true(TrainDom.is_wearable({"id": "jacket_short", "condition": 0.4, "holes": {"torso": true}}))
	assert_false(TrainDom.is_wearable({"id": "gloves", "condition": 0.4, "holes": {"torso": true}}), "a hole where it does not cover")
	assert_false(TrainDom.is_wearable({"id": "jacket_short", "condition": 1.2}))


func test_the_first_departure_goes_out_dressed_as_before() -> void:
	var game = _game(_departure(_state(true)))
	var plain = _game(_departure(_state(false)))
	for i in game.squad.size():
		assert_eq(Wear.worn_ids(game.squad[i]), Wear.worn_ids(plain.squad[i]), "the same clothes")
		assert_almost_eq(float(game.squad[i].worn["jacket"]["wear"]), 0.0, 0.0001, "an unworn coat")
	var said := 0
	for n in game.hud.toast_box.find_children("*", "Label", true, false):
		if String(n.text).replace(UiFonts.WORD_JOINER, "").contains("외투 없음"):
			said += 1
	assert_eq(said, 0, "nobody went out bare")


func test_a_short_wardrobe_sends_some_out_with_no_coat_and_says_so() -> void:
	var g := _state(true)
	g["dom"]["wardrobe"] = [{"id": "jacket_short", "condition": 0.6, "holes": {"torso": true}}, {"id": "gloves", "condition": 1.0}]
	var d := _departure(g)
	var roster: Array = d["roster"]
	assert_eq(roster[0]["gear"]["wear"]["jacket"], {"id": "jacket_short", "condition": 0.6, "holes": {"torso": true}}, "the chief first")
	for i in range(1, roster.size()):
		assert_eq(roster[i]["gear"]["wear"]["jacket"], "", "none left")
		assert_eq(roster[i]["gear"]["wear"]["hands"], "")
	for row: Dictionary in d["workCrew"]:
		assert_eq(row["gear"]["wear"], {}, "the work crew goes in what everyone wears")
	var game = _game(d)
	var chief = game.squad[0]
	assert_almost_eq(float(chief.worn["jacket"]["wear"]), 0.4, 0.0001, "worn as kept")
	assert_true((chief.worn["jacket"].get("holes", {}) as Dictionary).has("torso"), "with its hole")
	assert_false(game.squad[1].worn.has("jacket"), "no coat")
	assert_false(game.squad[1].worn.has("hands"), "no gloves")
	var said := ""
	for n in game.hud.toast_box.find_children("*", "Label", true, false):
		var t := String(n.text).replace(UiFonts.WORD_JOINER, "")
		if t.contains("외투 없음"):
			said = t
	assert_true(said.contains(String(game.squad[1].display_name)), said)
	assert_false(said.contains(String(chief.display_name)), "the chief has one")


func test_the_best_kept_coat_goes_first_and_another_for_the_place_will_do() -> void:
	var closet: Array = [{"id": "jacket_short", "condition": 0.5}, {"id": "coat_leather", "condition": 0.9}, {"id": "jacket_short", "condition": 0.8}]
	var gear := KitPick.dress({"hands": [], "items": {}, "wear": {}, "bag": "pack"}, closet)
	assert_eq(gear["wear"]["jacket"], {"id": "jacket_short", "condition": 0.8}, "the wished coat, the better one")
	gear = KitPick.dress({"hands": [], "items": {}, "wear": {}, "bag": "pack"}, closet)
	assert_eq(gear["wear"]["jacket"], {"id": "jacket_short", "condition": 0.5})
	gear = KitPick.dress({"hands": [], "items": {}, "wear": {}, "bag": "pack"}, closet)
	assert_eq(gear["wear"]["jacket"], {"id": "coat_leather", "condition": 0.9}, "then any jacket")
	assert_eq(closet, [], "taken as they went")
	assert_eq(KitPick.dress({"hands": [], "items": {}, "wear": {}, "bag": "pack"}, null)["wear"], {}, "no wardrobe: as it is")
