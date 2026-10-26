extends GutTest
## The outside temperature on the train (train_climate.gd) against S1 with climate
## and the track freeze on (s1/tools/turn_port_fixtures.ts --climate): the same
## four seeds' whole states step by step, a board leaving late autumn at stretch
## 17 through its frozen stretch to the thaw, and departures S1 makes on purpose —
## the season table turning colder (stretch 17, the track freezing), staying, and a
## regular winter-drop stretch, which climate replaces.

const Advance = preload("res://game/train/train_advance.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const St = preload("res://game/train/train_state.gd")
const SeasonTable = preload("res://game/season_table.gd")
const V = preload("res://tests/train/train_vectors.gd")
const CardText = preload("res://game/train/turn/turn_card_text.gd")
const PATH: String = "res://tests/fixtures/train/turn_vectors_climate.json"

var _data: Dictionary = {}


func before_all() -> void:
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed


func _act(g: Dictionary, t: Dictionary, action: Dictionary) -> Dictionary:
	match str(action["kind"]):
		"advance": return Advance.advance(g, t)
		"resolve_stop": return Advance.resolve_stop(g, t, bool(action["go"]))
		"choose_card": return Advance.choose_card(g, t, int(action["uid"]), int(action["index"]))
		"cast_vote": return Advance.cast_vote(g, t)
	return {"_turn_port_error": "F-BAD-FIXTURE-ACTION"}


func test_fixture_contract() -> void:
	assert_false(_data.is_empty(), "the climate record exists and parses")
	if _data.is_empty():
		return
	assert_eq(_data.get("format"), "turn-vectors-climate-v2")
	assert_eq(int(_data["freezeOn"]), 1, "the track freeze is on in this record")
	var stepped: int = 0
	var changed: int = 0
	var froze: int = 0
	var thawed: int = 0
	for run: Dictionary in _data["runs"]:
		for row: Dictionary in run["steps"]:
			assert_true(bool(row["before"]["climate"]))
			stepped += 1
			if row["after"].get("climateChange") != row["before"].get("climateChange"):
				changed += 1
			var was: float = float(row["before"].get("freeze", 0))
			var now: float = float(row["after"].get("freeze", 0))
			froze += int(was == 0.0 and now > 0.0)
			thawed += int(was > 0.0 and now == 0.0)
	assert_gt(stepped, 100)
	assert_gt(changed, 0, "the season table's stage changes within the record")
	assert_gt(froze, 0, "a departure freezes the track within the record")
	assert_gt(thawed, 0, "and a settle thaws it")


## Every step of the four climate runs ends in S1's whole state (stage, warmth,
## the lines, the stops' weather and words, the coal the heating burns).
func test_every_climate_step_matches_s1() -> void:
	var bad: Array[String] = []
	var count: int = 0
	var unported: Array[String] = []
	for run: Dictionary in _data.get("runs", []):
		for row: Dictionary in run["steps"]:
			var input: Dictionary = row["before"].duplicate(true)
			var got: Dictionary = _act(input, _data["tables"], row["action"])
			var at: String = "%s/%d %s:%s" % [run["seed"], int(row["step"]), row["before"]["phase"], row["action"]["kind"]]
			if got.has("_turn_port_error"):
				unported.append(at + " " + str(got["_turn_port_error"]))
				continue
			bad.append_array(V.full_diffs(row["after"], got, at, 10).slice(0, maxi(0, 30 - bad.size())))
			count += 1
	assert_gt(count, 100)
	assert_eq(bad, [] as Array[String], "\n".join(bad))
	assert_eq(unported, [] as Array[String], "\n".join(unported))


## The departures S1 makes on purpose: colder (two lines, warmth −5, ×0.9), the
## same stage (nothing), and a winter-drop stretch (no drop with climate on).
func test_climate_departures_match_s1() -> void:
	var names: Array = []
	for part: Dictionary in _data.get("parts", []):
		names.append(part["name"])
		var got: Dictionary = _act(part["before"].duplicate(true), _data["tables"], part["action"])
		assert_false(got.has("_turn_port_error"), str(got.get("_turn_port_error", "")))
		assert_eq(V.full_diffs(part["after"], got, String(part["name"]), 10), [] as Array[String])
	assert_eq(names, ["climate/drop", "climate/same", "climate/winter"])


## The heating coal is the stage's multiple of the same heating with climate off,
## and a board with climate off is as before.
func test_heat_cost_is_the_stage_s_multiple() -> void:
	var t: Dictionary = _data["tables"]
	var g: Dictionary = (_data["runs"][0]["steps"][0]["before"] as Dictionary).duplicate(true)
	var off: Dictionary = g.duplicate(true)
	off["climate"] = false
	for stage: int in (t["CL"]["mult"] as Array).size():
		g["outside"] = stage
		assert_almost_eq(TrainTurn.heat_cost(g, t), TrainTurn.heat_cost(off, t) * float(t["CL"]["mult"][stage]), 1e-9, "stage %d" % stage)
	assert_eq(TrainClimate.temp_mult(off, t), 1.0)


## The season shares S2 draws a stop's weather from are the season table S1 reads.
func test_the_seasons_are_s1_s() -> void:
	var t: Dictionary = _data["tables"]
	for row: Dictionary in t["SEASON_ROWS"]:
		assert_true(SeasonTable.data()["seasons"].has(String(row["season"])), String(row["season"]))
	assert_eq(t["FALLS"], SeasonTable.data()["falls"])


## A board whose track has frozen is one S2 carries, as a climate board is.
func test_a_frozen_track_is_a_board_s2_carries() -> void:
	var g: Dictionary = (_data["runs"][0]["steps"][0]["before"] as Dictionary).duplicate(true)
	assert_true(St.is_s1a(g), "climate on, no freeze")
	g["freeze"] = 1
	assert_true(St.is_s1a(g), "a freeze in force")


## What the track freeze asks of a departure: a colder stage left wet. Late
## autumn is wet; a dry stage freezes only after sleet; the same or a warmer
## stage never; climate off never (S1 freezeDepart).
func test_a_colder_wet_departure_freezes_the_track() -> void:
	var t: Dictionary = (_data["tables"] as Dictionary).duplicate(true)
	var g: Dictionary = (_data["runs"][0]["steps"][0]["before"] as Dictionary).duplicate(true)
	g["lastStop"] = {"weather": "fog"}
	for case: Array in [[{"from": 0, "to": 1}, "fog", 1.0], [{"from": 1, "to": 2}, "fog", 0.0],
			[{"from": 1, "to": 2}, "sleet", 1.0], [{"from": 0, "to": 0}, "sleet", 0.0], [{"from": 1, "to": 0}, "sleet", 0.0]]:
		var h: Dictionary = g.duplicate(true)
		h["freeze"] = 0
		h["lastStop"] = {"weather": case[1]}
		TrainClimate.freeze_depart(h, t, case[0])
		assert_eq(float(h["freeze"]), float(case[2]), "%s after %s" % [case[0], case[1]])
	var off: Dictionary = g.duplicate(true)
	off["climate"] = false
	off["freeze"] = 0
	TrainClimate.freeze_depart(off, t, {"from": 0, "to": 1})
	assert_eq(float(off["freeze"]), 0.0, "climate off")


## A frozen stretch: a coal more and half a day's food more in the forecast, its
## own rows on the ledger (내역 판 「선로 결빙」), the track events in the pool
## twice; none of it once it has thawed.
func test_a_frozen_stretch_costs_more_and_draws_the_track_twice() -> void:
	var t: Dictionary = _data["tables"]
	var g: Dictionary = (_data["runs"][0]["steps"][0]["before"] as Dictionary).duplicate(true)
	g["freeze"] = 0
	var dry: Dictionary = TrainTurn.forecast(g, t)
	var frozen := g.duplicate(true)
	frozen["freeze"] = 1
	var cold: Dictionary = TrainTurn.forecast(frozen, t)
	assert_almost_eq(float(cold["coal"]) - float(dry["coal"]), float(t["CL"]["freezeCoal"]), 1e-9)
	assert_almost_eq(float(cold["food"]) - float(dry["food"]), TrainTurn.food_cost(g, t) * float(t["CL"]["freezeFood"]), 1e-9)
	var parts: Dictionary = TrainTurn.forecast_parts(frozen, t)
	var coal_why: Array = (parts["coal"] as Array).map(func(r: Array) -> String: return String(r[0]))
	var food_why: Array = (parts["food"] as Array).map(func(r: Array) -> String: return String(r[0]))
	assert_true(coal_why.has("freeze") and food_why.has("freeze"))
	var plain: Dictionary = TrainTurn.forecast_parts(g, t)
	assert_false((plain["coal"] as Array).map(func(r: Array) -> String: return String(r[0])).has("freeze"), "no row unfrozen")
	assert_eq(TrainClimate.track_boost(frozen, t, ["tail_cold", "water_tower"]), ["tail_cold", "water_tower", "water_tower"])
	assert_eq(TrainClimate.track_boost(g, t, ["tail_cold", "water_tower"]), ["tail_cold", "water_tower"])


## Where ice does not stand (late autumn, no night frost, no cold weather) the
## guard's roof card is S1's soaked post, not frostbite; climate off, frostbite.
func test_the_roof_guard_is_soaked_where_ice_does_not_stand() -> void:
	var t: Dictionary = _data["tables"]
	var g: Dictionary = (_data["runs"][0]["steps"][0]["before"] as Dictionary).duplicate(true)
	var card := {"uid": 1, "kind": "travel", "text": "guard_frost"}
	g["cards"] = [card]
	var late: int = -1
	for row: Dictionary in t["SEASON_ROWS"]:
		if late < 0 and not bool(row["night_freeze"]) and not bool(row["snow"]):
			late = int(row["seg"])
	assert_gt(late, 0, "the season table has a stretch with no ice")
	g["seg"] = late
	g["stop"] = null
	g["lastStop"] = {"weather": "fog"}
	assert_false(TrainClimate.holds(g, t, "frost"))
	var v: Dictionary = CardText.view(g, t, card)
	assert_eq(v["title"], "젖은 보초")
	assert_string_starts_with(String(v["body"]), "지붕 경계를 서던 대원 둘이 찬비에 흠뻑 젖어")
	g["lastStop"] = {"weather": "cold"}
	assert_eq(CardText.view(g, t, card)["title"], "동상", "cold weather: ice stands")
	g["climate"] = false
	g["lastStop"] = {"weather": "fog"}
	assert_eq(CardText.view(g, t, card)["title"], "동상", "climate off: always winter")
