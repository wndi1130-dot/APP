extends GutTest
## The outside temperature on the train (train_climate.gd) against S1 with climate
## on and the track freeze off (s1/tools/turn_port_fixtures.ts --climate): the same
## four seeds' whole states step by step, and departures S1 makes on purpose — the
## season table turning colder (stretch 17), staying, and a regular winter-drop
## stretch, which climate replaces.

const Advance = preload("res://game/train/train_advance.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const St = preload("res://game/train/train_state.gd")
const SeasonTable = preload("res://game/season_table.gd")
const V = preload("res://tests/train/train_vectors.gd")
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
	assert_eq(_data.get("format"), "turn-vectors-climate-v1")
	assert_eq(int(_data["freezeOn"]), 0, "the track freeze is off in this record")
	var stepped: int = 0
	var changed: int = 0
	for run: Dictionary in _data["runs"]:
		for row: Dictionary in run["steps"]:
			assert_true(bool(row["before"]["climate"]))
			stepped += 1
			if row["after"].get("climateChange") != row["before"].get("climateChange"):
				changed += 1
	assert_gt(stepped, 100)
	assert_gt(changed, 0, "the season table's stage changes within the record")


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


## A board whose track has frozen is not one S2 carries yet; a climate board is.
func test_a_frozen_track_is_not_ported_yet() -> void:
	var g: Dictionary = (_data["runs"][0]["steps"][0]["before"] as Dictionary).duplicate(true)
	assert_true(St.is_s1a(g), "climate on, no freeze")
	g["freeze"] = 1
	assert_false(St.is_s1a(g), "a freeze in force")
