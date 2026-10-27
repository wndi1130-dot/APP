extends "res://addons/gut/test.gd"
## 코어 덱(결정 474 S3, 442): 화물역·공장·탄광의 멈춘 기계에 보이는 코어가 남는 것은 정차를 넘는
## 덱 — 코어 장면이 있는 정차 20곳 중 정확히 3곳(기대치 0.15 그대로, 운으로 0개인 판이 없다).
## 숨은 코어는 보이는 코어가 안 나온 나머지에서 정차마다 제 몫. 덱 상태가 없으면 예전과 같다.

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


func test_the_deck_share_is_the_core_rate() -> void:
	assert_eq(float(LootDress.DECKS["core_scene"][1]), CoreScenes.P_CORE)
	assert_eq(int(LootDress.DECKS["core_scene"][0]), 20)


func test_with_no_deck_the_dice_fall_as_before() -> void:
	var differ := 0
	for s in range(1, 5001):
		var seed := ("%d:core:freight_01" % s).hash()
		if CoreScenes.roll(seed) != _old_roll(seed) or CoreScenes.roll(seed, {}) != _old_roll(seed):
			differ += 1
	assert_eq(differ, 0)


func test_over_twenty_core_stops_exactly_three_cores_are_left() -> void:
	for start in [1, 1001, 2001, 3001]:
		var deck := {}
		var cores := 0
		for i in range(40):
			if CoreScenes.roll(("%d:core:factory_01" % (start + i)).hash(), deck) == "core":
				cores += 1
			if i == 19:
				assert_eq(cores, 3, "the first twenty, start %d" % start)
		assert_eq(cores, 6, "forty, start %d" % start)
		assert_eq(int(deck["core_scene"]["seen"]), 0, "the batch starts again at twenty")


func test_the_hidden_core_keeps_its_share() -> void:
	var deck := {}
	var got := {"core": 0, "hidden": 0, "bare": 0}
	for i in range(4000):
		got[CoreScenes.roll(("%d:core:mine_01" % i).hash(), deck)] += 1
	assert_eq(got["core"], 600)
	assert_almost_eq(got["hidden"] / 4000.0, CoreScenes.P_HIDDEN, 0.02, str(got))


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
	var report := LootDress.dress(yard, 3, {"core_scene": {"n": 20, "k": 3, "seen": 19, "hit": 0}})
	var deck: Dictionary = report["loot_deck"]
	assert_eq(int(deck["core_scene"]["seen"]), 19, "dress keeps it as it came")
	var note := CoreScenes.apply(yard, 3, deck)
	assert_eq(String(note["state"]), "core", "the last card of a batch with no core yet")
	assert_eq(int(deck["core_scene"]["seen"]), 0)
