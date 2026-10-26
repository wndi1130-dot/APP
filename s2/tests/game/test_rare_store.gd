extends "res://addons/gut/test.gd"
## 샛길 끝 희귀 창고(결정 450, 카드 F 가 — 결정 442로 적용): 건물 이름이 「희귀 창고」인
## 건물의 상자는 장소 종류의 「가득 찬 창고」 표로 상자마다 세 번 굴려 새로 채우고, 드문 것
## 하나(철도 자재: 코어 반·아니면 부품감 묶음, 보관소: 총과 그 탄, 겨울 물자: 털옷과 연료 통)를
## 한 상자에 둔다. 샛길·건물·잠긴 문은 map-layout 몫이다.

const FieldGame = preload("res://game/field_game.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const Carry = preload("res://game/sim/carry.gd")
const W = preload("res://game/sim/weapons.gd")
const Wear = preload("res://game/sim/wear.gd")

const PLACE_KINDS: Array[String] = ["freight", "factory", "mine", "sawmill", "bare_line", "houses", "office", "hospital", "church", "lodge", "lake", "summit"]


## A stop with a house and, if asked, the rare store of five boxes.
func _stop(place_kind: String, store: bool) -> Dictionary:
	var d := {"place_kind": place_kind, "buildings": [{"name": "주택 가"}], "containers": {
		"h1": {"name": "부엌 찬장", "building": 0, "items": ["food_pack", "cloth"]},
		"h2": {"name": "안방 옷장", "building": 0, "items": ["luxury_pack"]},
	}}
	if store:
		d["buildings"].append({"name": LootDress.RARE_STORE})
		for i in range(5):
			d["containers"]["rs%d" % i] = {"name": "희귀 창고의 선반 %d" % i, "building": 1, "items": ["food_pack"]}
	return d


func _store_items(d: Dictionary) -> Array:
	var out: Array = []
	for id: String in d["containers"]:
		if id.begins_with("rs"):
			out.append_array(d["containers"][id]["items"])
	return out


func test_every_kind_of_place_has_a_store_and_every_thing_is_known() -> void:
	for kind: String in PLACE_KINDS:
		assert_true(LootDress.RARE_STORE_KIND.has(kind), kind)
	assert_eq(LootDress.RARE_STORE_KIND["freight"], "rail")
	assert_eq(LootDress.RARE_STORE_KIND["houses"], "arms")
	assert_eq(LootDress.RARE_STORE_KIND["lodge"], "winter")
	for kind: String in LootDress.RARE_STORE_TABLES:
		for row: Array in LootDress.RARE_STORE_TABLES[kind]:
			assert_gt(Carry.item_weight(String(row[1])), 0.0, "a thing that weighs: " + String(row[1]))
	for row: Array in LootDress.RARE_GUNS:
		assert_true(W.is_ranged(String(row[0])), String(row[0]))
	for row: Array in LootDress.RARE_FURS:
		assert_true(Wear.is_garment(String(row[0])), String(row[0]))
	assert_eq([LootDress.RARE_STORE_ROLLS, LootDress.RARE_CORE_CHANCE, LootDress.RARE_PARTS], [3, 0.5, Vector2i(4, 6)], "the listed values")


func test_a_stop_without_the_store_is_dressed_as_before() -> void:
	var a := _stop("freight", false)
	var b := _stop("freight", false)
	var ra := LootDress.dress(a, 9)
	LootDress.dress(b, 9)
	assert_eq(String(ra["store"]), "")
	assert_eq(str(a["containers"]), str(b["containers"]))


func test_the_store_is_full_and_holds_its_rare_thing_once() -> void:
	for kind: String in ["freight", "houses", "lodge"]:
		for seed in range(1, 41):
			var d := _stop(kind, true)
			var report := LootDress.dress(d, seed)
			var store: String = LootDress.RARE_STORE_KIND[kind]
			assert_eq(String(report["store"]), store)
			for id: String in d["containers"]:
				if id.begins_with("rs"):
					assert_gte((d["containers"][id]["items"] as Array).size(), LootDress.RARE_STORE_ROLLS, "three rolls, no empty row: %s %s" % [kind, id])
			var items := _store_items(d)
			assert_false(items.has("food_pack"), "the bundles are named")
			match store:
				"rail":
					var cores := items.count(LootDress.RARE_CORE)
					var parts := 0
					for item in items:
						if String(item) in ["gears", "springs", "wire_coil"]:
							parts += 1
					assert_true(cores == 1 or parts >= LootDress.RARE_PARTS.x, "a core or a crate of parts: seed %d" % seed)
				"arms":
					var guns := items.filter(func(i) -> bool: return W.is_ranged(String(i)))
					assert_eq(guns.size(), 1, "one gun: seed %d" % seed)
					assert_gte(items.count(LootDress.RARE_GUN_ROUNDS[guns[0]][0]), 2, "and its rounds")
				"winter":
					assert_true(items.has("coat_wool_long") or items.has("boots_fur"), "a fur garment: seed %d" % seed)
					assert_has(items, "fuel_can")


func test_a_core_half_the_time_in_a_rail_store() -> void:
	var cores := 0
	var runs := 400
	for seed in range(1, runs + 1):
		var d := _stop("mine", true)
		LootDress.dress(d, seed)
		cores += _store_items(d).count(LootDress.RARE_CORE)
	assert_almost_eq(cores / float(runs), LootDress.RARE_CORE_CHANCE, 0.06)


func test_the_store_is_found_by_its_building_id() -> void:
	# A map whose building ids are not their places in the list (map-layout 05:1x).
	var d := {"place_kind": "freight", "buildings": [{"id": 7, "name": "역사"}, {"id": 3, "name": LootDress.RARE_STORE}], "containers": {
		"a": {"name": "희귀 창고의 궤짝", "building": 3, "items": []},
		"b": {"name": "역사 사무실 책상", "building": 7, "items": []},
		"c": {"name": "희귀 창고의 선반", "building": 1, "items": []},
	}}
	assert_eq(LootDress.rare_store_of(d["buildings"]), 3)
	LootDress.dress(d, 5)
	assert_gte((d["containers"]["a"]["items"] as Array).size(), LootDress.RARE_STORE_ROLLS, "the store's box is filled")
	assert_lt((d["containers"]["c"]["items"] as Array).size(), LootDress.RARE_STORE_ROLLS, "a box of building 1 is not the store")


func test_the_same_seed_fills_the_same_store() -> void:
	var a := _stop("office", true)
	var b := _stop("office", true)
	LootDress.dress(a, 33)
	LootDress.dress(b, 33)
	assert_eq(str(a["containers"]), str(b["containers"]))


func test_a_gun_from_a_box_goes_into_a_free_hand_empty() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var p = game.player
	p.hands = [p.hands[0]]
	p.set_weapon_slots(p.hands)
	var box := ""
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if int(c.get("level", 0)) == 0 and not bool(c.get("locked", false)):
			box = String(id)
			break
	var c: Dictionary = game.data["containers"][box]
	c["searched"] = true
	c["items"] = ["shotgun"]
	p.position = game.actions._container_at(c)
	game.actions.take(p, box, 0)
	while p.action == "take":
		p.action_t = 0.001
		game._update_person(p, 0.1)
	assert_eq(p.hands.size(), 2, "in the free hand")
	assert_eq(String(p.hands[0]["id"]), "shotgun")
	assert_eq(int(p.hands[0]["loaded"]), 0, "empty until loaded")
	assert_false(p.items.has("shotgun"), "not in the bag")
