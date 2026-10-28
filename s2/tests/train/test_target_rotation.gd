extends "res://addons/gut/test.gd"
## Decisions 482/484 (469 V1): the kind a stop aims at first turns with the train's state, the season and the
## promise ledger (turn_travel.gd suggest_target, the same rules as s1 turn.ts suggestTarget).

const Travel = preload("res://game/train/turn/turn_travel.gd")
const Advance = preload("res://game/train/train_advance.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")
const PATH: String = "res://tests/fixtures/train/turn_vectors.json"
const LOOT: Dictionary = {"coal": 40, "food": 40, "medicine": 30, "luxury": 5, "symbol": 5, "secret": 5}

var _data: Dictionary = {}


func before_all() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed


## Food short of coal, but with more than ROTATE_GUARD stretches' forecast left.
func _hungry() -> Dictionary:
	var g: Dictionary = (_data["runs"][0]["steps"][0]["before"] as Dictionary).duplicate(true)
	g["coal"] = 1000
	g["med"] = 20
	g["climate"] = false
	g.erase("targetRun")
	for comm: String in g["comms"]:
		(g["comms"][comm] as Dictionary).erase("promise")
	g["food"] = Travel.ROTATE_GUARD * float(TrainTurn.forecast(g, _data["tables"])["food"]) + 10.0
	return g


func test_a_third_run_in_a_row_hands_over_to_what_the_place_holds_most() -> void:
	var t: Dictionary = _data["tables"]
	var g: Dictionary = _hungry()
	assert_eq(Travel.suggest_target(g, t, LOOT), "food")
	Advance._note_target(g, "food")
	assert_eq(Travel.suggest_target(g, t, LOOT), "food", "두 번째 연속까지는 그대로")
	Advance._note_target(g, "food")
	assert_eq(g["targetRun"], {"target": "food", "n": 2})
	assert_eq(Travel.suggest_target(g, t, LOOT), "coal", "세 번째가 될 자리")
	Advance._note_target(g, "coal")
	assert_eq(g["targetRun"], {"target": "coal", "n": 1})
	assert_eq(Travel.suggest_target(g, t, LOOT), "food")


func test_a_kind_under_eight_stretches_is_not_handed_over() -> void:
	var t: Dictionary = _data["tables"]
	assert_eq(Travel.ROTATE_GUARD, 8.0)
	var g: Dictionary = _hungry()
	g["food"] = maxf(0.0, Travel.ROTATE_GUARD * float(TrainTurn.forecast(g, t)["food"]) - 1.0)
	g["targetRun"] = {"target": "food", "n": 2}
	assert_eq(Travel.suggest_target(g, t, LOOT), "food")


func test_a_hospital_hands_food_over_to_medicine_and_a_church_to_its_symbol() -> void:
	var t: Dictionary = _data["tables"]
	var g: Dictionary = _hungry()
	g["targetRun"] = {"target": "food", "n": 2}
	assert_eq(Travel.suggest_target(g, t, {"coal": 0, "food": 10, "medicine": 55, "luxury": 0, "symbol": 10, "secret": 25}), "medicine")
	assert_eq(Travel.suggest_target(g, t, {"coal": 0, "food": 10, "medicine": 0, "luxury": 10, "symbol": 60, "secret": 20}), "symbol")


func test_nothing_to_hand_over_keeps_the_kind() -> void:
	var t: Dictionary = _data["tables"]
	var g: Dictionary = _hungry()
	g["targetRun"] = {"target": "food", "n": 2}
	assert_eq(Travel.suggest_target(g, t, {"coal": 5, "food": 35, "medicine": 10, "luxury": 20, "symbol": 20, "secret": 10}), "food", "주택가")


func test_a_passed_stop_neither_breaks_nor_extends_the_run() -> void:
	var g: Dictionary = _hungry()
	Advance._note_target(g, "food")
	Advance._note_target(g, null)
	assert_eq(g["targetRun"], {"target": "food", "n": 1})


func test_coal_comes_first_when_the_season_turns_colder_after_this_stretch() -> void:
	var t: Dictionary = _data["tables"]
	var g: Dictionary = _hungry()
	g["climate"] = true
	var seg: int = 1
	while seg < 24 and not TrainClimate.stage_at(t, seg + 1) > TrainClimate.stage_at(t, seg):
		seg += 1
	assert_gt(TrainClimate.stage_at(t, seg + 1), TrainClimate.stage_at(t, seg))
	g["seg"] = seg
	assert_eq(Travel.target_candidates(g, t, LOOT)[0], "coal")
	g["seg"] = seg + 1
	assert_eq(Travel.target_candidates(g, t, LOOT)[0], "food")


func test_the_promise_ledger_puts_its_kind_first() -> void:
	var t: Dictionary = _data["tables"]
	var g: Dictionary = _hungry()
	g["comms"]["medtech"]["promise"] = {"kind": "fetch", "cond": {"kind": "target", "target": "medicine"}, "label": "의약품 6", "due": int(g["seg"]) + 1}
	assert_eq(Travel.target_candidates(g, t, LOOT)[0], "medicine")
	assert_eq(Travel.suggest_target(g, t, LOOT), "medicine")
	g["comms"]["medtech"]["promise"]["due"] = int(g["seg"]) - 1
	assert_eq(Travel.target_candidates(g, t, LOOT)[0], "food", "지난 약속은 보태지 않는다")
