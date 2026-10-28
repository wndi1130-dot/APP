extends "res://addons/gut/test.gd"
## Decisions 482/484 (469 V1): the kind a stop aims at first turns with the train's state, the season and the
## promise ledger (turn_travel.gd suggest_target, the same rules as s1 turn.ts suggestTarget).

const Travel = preload("res://game/train/turn/turn_travel.gd")
const Advance = preload("res://game/train/train_advance.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const SaveSlot = preload("res://game/politics/save_slot.gd")
const PATH: String = "res://tests/fixtures/train/turn_vectors.json"
const START: String = "res://game/train/slice_start.json"
const SLICE: String = "res://tests/fixtures/train/slice_vectors.json"
const LOOT: Dictionary = {"coal": 40, "food": 40, "medicine": 30, "luxury": 5, "symbol": 5, "secret": 5}

var _data: Dictionary = {}
var _start: Dictionary = {}
var _slice: Dictionary = {}


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func before_all() -> void:
	_data = _json(PATH)
	_start = _json(START)
	_slice = _json(SLICE)


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


func test_a_kind_under_eight_stretches_is_not_handed_over_and_one_at_eight_is() -> void:
	var t: Dictionary = _data["tables"]
	assert_eq(Travel.ROTATE_GUARD, 8.0)
	var g: Dictionary = _hungry()
	var edge: float = Travel.ROTATE_GUARD * float(TrainTurn.forecast(g, t)["food"])
	g["targetRun"] = {"target": "food", "n": 2}
	g["food"] = maxf(0.0, edge - 1.0)
	assert_eq(Travel.suggest_target(g, t, LOOT), "food")
	g["food"] = edge
	assert_eq(Travel.suggest_target(g, t, LOOT), "coal", "딱 8구간 치")
	g["food"] = edge + 1.0
	assert_eq(Travel.suggest_target(g, t, LOOT), "coal")


func test_a_tie_on_what_the_place_holds_goes_to_the_earlier_kind() -> void:
	var t: Dictionary = _data["tables"]
	assert_eq(Travel.rotate_to(t, {"coal": 30, "food": 40, "medicine": 30, "luxury": 30, "symbol": 0, "secret": 0}, "food"), "coal")
	assert_eq(Travel.rotate_to(t, {"coal": 0, "food": 40, "medicine": 30, "luxury": 30, "symbol": 30, "secret": 30}, "food"), "medicine")
	assert_eq(Travel.rotate_to(t, {"coal": 0, "food": 40, "medicine": 0, "luxury": 0, "symbol": 30, "secret": 30}, "food"), "symbol")


func test_a_tie_on_need_keeps_coal_food_medicine_order() -> void:
	var t: Dictionary = _data["tables"]
	var g: Dictionary = _hungry()
	g["coal"] = 63  # 63 / 252, 60 / 240 and 5 / 20 are all 0.25
	g["food"] = 60
	g["med"] = 5
	assert_eq(Travel.target_candidates(g, t, LOOT).slice(0, 3), ["coal", "food", "medicine"])


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


## The slice's first stop (S1 target_rotation.test.ts atStop) with a run on the kind it aims at.
func _stop(n: int) -> Dictionary:
	var g: Dictionary = SliceFlow.first_stop(_start["state"], _start["tables"])
	g["targetRun"] = {"target": g["stop"]["target"], "n": n}
	return g


## The slice's first return made to answer `departure`.
func _receipt(departure: Dictionary, id: String) -> Dictionary:
	var r: Dictionary = (_slice["cases"][0]["receipt"] as Dictionary).duplicate(true)
	r["receiptId"] = id
	r["departureId"] = departure["departureId"]
	r["stopId"] = departure["stopId"]
	return r


func _run(g: Dictionary) -> Array:
	return [g["targetRun"]["target"], int(g["targetRun"]["n"])]


func test_a_field_return_closing_the_stop_counts_once_and_a_duplicate_does_not() -> void:
	var t: Dictionary = _start["tables"]
	var g: Dictionary = _stop(1)
	var target: String = g["stop"]["target"]
	var departure: Dictionary = FieldDeparture.build(g, t, {"placeId": _slice["placeId"]})
	var receipt: Dictionary = _receipt(departure, "ret_rotation")
	var once: Dictionary = FieldReturn.apply_field_return(g, t, departure, receipt)
	assert_eq(once["status"], "applied")
	assert_true(bool(once["g"]["stop"]["done"]))
	assert_eq(_run(once["g"]), [target, 2])
	var twice: Dictionary = FieldReturn.apply_field_return(once["g"], t, departure, receipt)
	assert_eq(twice["status"], "duplicate")
	assert_eq(_run(twice["g"]), [target, 2])


func test_a_late_receipt_from_an_earlier_stretch_brings_its_goods_but_leaves_this_stop_open() -> void:
	var t: Dictionary = _start["tables"]
	var g: Dictionary = _stop(1)
	var target: String = g["stop"]["target"]
	var place: String = _slice["placeId"]
	var old: Dictionary = FieldDeparture.build(g, t, {"placeId": place})
	var seg: int = int(old["segment"]) - 1
	old["segment"] = seg
	old["departureId"] = "dep_%s_%d" % [place, seg]
	old["stopId"] = "stop_%s_%d" % [place, seg]
	var receipt: Dictionary = _receipt(old, "ret_late")
	var out: Dictionary = FieldReturn.apply_field_return(g, t, old, receipt)
	assert_eq(out["status"], "applied")
	assert_almost_eq(float(out["g"]["coal"]), float(g["coal"]) + float(receipt["stock"]["coal"]), 0.0001)
	assert_false(bool(out["g"]["stop"]["done"]))
	assert_eq(_run(out["g"]), [target, 1])


func test_a_passed_or_empty_handed_stop_neither_breaks_nor_extends_the_run() -> void:
	var t: Dictionary = _start["tables"]
	var g: Dictionary = _stop(2)
	var target: String = g["stop"]["target"]
	var passed: Dictionary = Advance.resolve_stop(g, t, false)
	assert_true(bool(passed["stop"]["result"]["passed"]))
	assert_eq(_run(passed), [target, 2])
	g["stop"]["crewSize"] = 0
	var empty: Dictionary = Advance.resolve_stop(g, t, true)
	assert_true(bool(empty["stop"]["result"]["passed"]))
	assert_eq(_run(empty), [target, 2])


func test_a_dispatched_stop_counts_once_and_reads_back_the_same_from_a_save() -> void:
	var t: Dictionary = _start["tables"]
	var g: Dictionary = _stop(1)
	var target: String = g["stop"]["target"]
	var went: Dictionary = Advance.resolve_stop(g, t, true)
	assert_false(bool(went["stop"]["result"]["passed"]))
	assert_eq(_run(went), [target, 2])
	var back: Dictionary = SaveSlot.read_save(JSON.parse_string(JSON.stringify(went)), t)
	assert_true(bool(back["ok"]), String(back.get("why", "")))
	assert_eq(_run(back["g"]), [target, 2])
	assert_eq(Travel.suggest_target(back["g"], t, LOOT), Travel.suggest_target(went, t, LOOT))
