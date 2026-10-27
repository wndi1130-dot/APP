extends "res://addons/gut/test.gd"
## 코어 덱(결정 474 S3·442): 화물역·공장·탄광의 멈춘 기계에 보이는 코어가 남는 것은 정차를 넘는
## 덱 — 코어 장면이 있는 정차 7곳 중 정확히 1곳(한 판에 장면 정차가 7곳쯤이라, 코어를 하나도 못 보는
## 판이 줄어든다). 새 묶음의 첫 장은 예전처럼 0.15. 숨은 코어는 보이는 코어가 안 나온 나머지에서
## 정차마다 제 몫. 덱 상태가 없으면 예전과 같다.

const CoreScenes = preload("res://game/world/core_scenes.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")


func _old_roll(dice_seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = dice_seed
	var r := rng.randf()
	if r < CoreScenes.P_CORE:
		return "core"
	return "hidden" if r < CoreScenes.P_CORE + CoreScenes.P_HIDDEN else "bare"


func test_the_deck_is_one_of_seven_at_the_core_rate() -> void:
	assert_eq(float(LootDress.DECKS["core_scene"][1]), CoreScenes.P_CORE)
	assert_eq(int(LootDress.DECKS["core_scene"][0]), 7)
	assert_eq(int(LootDress._deck_row({}, "core_scene")["k"]), 1)


func test_with_no_deck_the_dice_fall_as_before() -> void:
	var differ := 0
	for s in range(1, 5001):
		var seed := ("%d:core:freight_01" % s).hash()
		if CoreScenes.roll(seed) != _old_roll(seed) or CoreScenes.roll(seed, {}) != _old_roll(seed):
			differ += 1
	assert_eq(differ, 0)


func test_over_seven_core_stops_exactly_one_core_is_left() -> void:
	for start in [1, 1001, 2001, 3001, 4001]:
		var deck := {}
		var cores := 0
		for i in range(21):
			if CoreScenes.roll(("%d:core:factory_01" % (start + i)).hash(), deck) == "core":
				cores += 1
			if i == 6:
				assert_eq(cores, 1, "the first seven, start %d" % start)
		assert_eq(cores, 3, "twenty-one, start %d" % start)
		assert_eq(int(deck["core_scene"]["seen"]), 0, "the batch starts again at seven")


func test_the_hidden_core_keeps_its_share() -> void:
	var deck := {}
	var got := {"core": 0, "hidden": 0, "bare": 0}
	for i in range(3990):
		got[CoreScenes.roll(("%d:core:mine_01" % i).hash(), deck)] += 1
	assert_eq(got["core"], 570, "one of every seven")
	assert_almost_eq(got["hidden"] / 3990.0, CoreScenes.P_HIDDEN, 0.02, str(got))


func test_a_stop_with_no_machine_turns_no_card() -> void:
	var deck := {}
	var data := FieldMaps.build("houses_01")
	assert_eq(CoreScenes.apply(data, 7, deck), {})
	assert_false(deck.has("core_scene"))
	var yard := FieldMaps.build("freight_01")
	assert_false(CoreScenes.apply(yard, 7, deck).is_empty())
	assert_eq(int(deck["core_scene"]["seen"]), 1)


func test_the_stop_carries_the_core_card_on_with_the_other_decks() -> void:
	# dress hands back every deck; the core scene turns its card in the same state.
	var yard := FieldMaps.build("freight_01")
	var report := LootDress.dress(yard, 3, {"core_scene": {"n": 7, "k": 1, "seen": 6, "hit": 0}})
	var deck: Dictionary = report["loot_deck"]
	assert_eq(int(deck["core_scene"]["seen"]), 6, "dress keeps it as it came")
	var note := CoreScenes.apply(yard, 3, deck)
	assert_eq(String(note["state"]), "core", "the last card of a batch with no core yet")
	assert_eq(int(deck["core_scene"]["seen"]), 0)
	# One of the old size starts a new batch.
	var old := {"core_scene": {"n": 20, "k": 3, "seen": 19, "hit": 0}}
	CoreScenes.roll(5, old)
	assert_eq(int(old["core_scene"]["n"]), 7)
	assert_eq(int(old["core_scene"]["seen"]), 1)
