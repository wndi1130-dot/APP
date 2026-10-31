extends GutTest
## The slice's own path on the live board (J01): the start asset the slice reads
## (s2/game/train/slice_start.json, S1 createGame) played as slice_flow.gd plays it —
## to the first stop, the departure contract, a return, the special session, its vote,
## the run to the second station and the end — against S1 doing the same
## (s1/tools/slice_vectors.ts). Three receipts on one contract must open different
## sessions or second stations.

const Advance = preload("res://game/train/train_advance.gd")
const Agenda = preload("res://game/politics/council_agenda.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const FieldCouncil = preload("res://game/politics/field_council.gd")
const FieldArrival = preload("res://game/politics/field_arrival.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const V = preload("res://tests/train/train_vectors.gd")
const START: String = "res://game/train/slice_start.json"
const PATH: String = "res://tests/fixtures/train/slice_vectors.json"

var _start: Dictionary = {}
var _data: Dictionary = {}


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func before_all() -> void:
	_start = _read(START)
	_data = _read(PATH)


func _bad(bad: Array[String], want: Variant, got: Variant, at: String) -> void:
	if bad.size() < 40:
		bad.append_array(V.full_diffs(want, got, at, 40 - bad.size()))


func test_the_start_asset_is_s1s_new_game() -> void:
	assert_eq(_start.get("format"), "slice-start-v1")
	assert_eq(_start.get("seed"), _data.get("seed"))
	assert_true(_start.get("state") is Dictionary and _start.get("tables") is Dictionary)
	var live: Array = SliceFlow.start_board()
	assert_eq(live[0].get("lateOn"), true, "new playable S2 boards enable decision 514")
	assert_false(_start["state"].has("lateOn"), "the old reference input stays unchanged")


func test_the_slice_reaches_its_first_stop_as_s1() -> void:
	var t: Dictionary = _start["tables"]
	var g: Dictionary = SliceFlow.first_stop(_start["state"], t)
	var bad: Array[String] = []
	_bad(bad, _data["stop"], g, "stop")
	_bad(bad, _data["departure"], FieldDeparture.build(g, t, {"placeId": _data["placeId"]}), "departure")
	assert_eq(bad, [] as Array[String])


func test_each_return_plays_to_the_second_station_as_s1() -> void:
	var t: Dictionary = _start["tables"]
	var stop: Dictionary = SliceFlow.first_stop(_start["state"], t)
	var departure: Dictionary = FieldDeparture.build(stop, t, {"placeId": _data["placeId"]})
	var bad: Array[String] = []
	for c: Dictionary in _data["cases"]:
		var at: String = String(c["name"])
		var applied: Dictionary = FieldReturn.apply_field_return(stop, t, departure, c["receipt"])
		_bad(bad, c["apply"]["status"], applied["status"], at + " status")
		_bad(bad, c["apply"]["record"], applied["record"], at + " record")
		_bad(bad, c["apply"]["after"], applied["g"], at + " apply")
		var g: Dictionary = applied["g"]
		var regular: Dictionary = Agenda.agenda_options(g, t)
		_bad(bad, c["regular"], regular, at + " regular")
		var stepped: Dictionary = FieldCouncil.next_field_step(g, t, regular["options"])
		_bad(bad, c["nextStep"], stepped["step"], at + " next step")
		g = stepped["g"]
		_bad(bad, c["opened"], g, at + " opened")
		var candidates: Array = []
		if g["fieldReturns"].get("special") is Dictionary and g["fieldReturns"]["special"].get("status") == "opened":
			candidates = FieldCouncil.special_candidates(g, t, g["fieldReturns"]["records"][0], regular["options"])
		_bad(bad, c["candidates"], candidates, at + " candidates")
		_bad(bad, c["reasons"], FieldCouncil.special_reasons(g), at + " reasons")
		if c["vote"] != null:
			g = Advance.cast_vote(g, t)
			_bad(bad, c["vote"]["after"], g, at + " vote")
			var left: Dictionary = FieldCouncil.leave_special_council(g, t)
			_bad(bad, c["left"]["left"], left["left"], at + " left")
			g = left["g"]
			_bad(bad, c["left"]["after"], g, at + " left after")
		var i: int = 0
		for row: Dictionary in c["steps"]:
			_bad(bad, row["before"], g, "%s step %d before" % [at, i])
			g = SliceFlow.step_train(g, t)
			_bad(bad, row["after"], g, "%s step %d" % [at, i])
			i += 1
		assert_true(c["arrival"] != null, at + " reaches the second station in S1")
		if c["arrival"] == null: continue
		assert_true(FieldArrival.second_station_reached(g), at + " reaches the second station")
		_bad(bad, c["arrival"]["state"], g, at + " arrival")
		_bad(bad, c["arrival"]["sections"], FieldArrival.arrival_summary(g, t), at + " sections")
		_bad(bad, c["arrival"]["endCard"], FieldArrival.end_card(g), at + " end card")
		var done: Dictionary = FieldArrival.finish_slice(g, t)
		_bad(bad, c["arrival"]["finished"], done["finished"], at + " finished")
		_bad(bad, c["arrival"]["after"], done["g"], at + " finished after")
	assert_eq(bad, [] as Array[String])


## J01's first acceptance: different finds, rescues and losses on the same people make a
## different session or a different second station.
func test_different_returns_open_different_sessions_or_stations() -> void:
	var seen: Dictionary = {}
	for c: Dictionary in _data["cases"]:
		var key: String = JSON.stringify([c["candidates"], c["arrival"]["sections"] if c["arrival"] != null else null])
		assert_false(seen.has(key), "%s opens the same session and station as %s" % [c["name"], seen.get(key, "")])
		seen[key] = c["name"]
	assert_eq(seen.size(), (_data["cases"] as Array).size())


## J01's second acceptance: the slice plays on its own state, no test fixture. The game's
## code reads nothing under res://tests/ but the stop card's own sample, which it takes only
## when no state is given (a card shown alone); the slice always gives it the board.
const FIXTURE_READERS: Array[String] = ["res://game/ui/stop_pick_card.gd"]


func test_the_slice_reads_no_test_fixture() -> void:
	var src: String = FileAccess.get_file_as_string("res://game/slice_flow.gd")
	assert_false(src.contains("res://tests/"), "slice_flow.gd reads nothing under res://tests/")
	assert_true(src.contains("c.g = train_g.duplicate(true)"), "the stop card gets the board, so its sample stays unread")
	var readers: Array[String] = []
	_scan("res://game", readers)
	assert_eq(readers, FIXTURE_READERS, "game code that names res://tests/")


func _scan(dir: String, out: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + sub, out)
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir + "/" + f).contains("res://" + "tests/"):
			out.append(dir + "/" + f)
