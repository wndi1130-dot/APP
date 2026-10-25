extends RefCounted
## The politics port's sample sessions and second stations, for the screens' own tests
## (council_card, arrival_sheet, end_card). The slice no longer reads them: it plays on its
## own board (slice_flow.gd, J01).

const RECEIPT_SAMPLE := "res://tests/game/fixtures/field_v4/case1_symbol_kept.json"
const DEPARTURE_SAMPLE := "res://tests/game/fixtures/field_v4/departure_prologue.json"
const COUNCIL_SAMPLE := "res://tests/game/fixtures/field_port/field_vectors.json"


## [state, tables] of the session the sample opens when the sample departure goes out and
## its receipt comes back; [{}, {}] when there is none.
static func council_sample() -> Array:
	if not FileAccess.file_exists(COUNCIL_SAMPLE):
		return [{}, {}]
	var d = JSON.parse_string(FileAccess.get_file_as_string(COUNCIL_SAMPLE))
	if not d is Dictionary:
		return [{}, {}]
	var receipt: String = RECEIPT_SAMPLE.get_file().get_basename()
	var departure: String = DEPARTURE_SAMPLE.get_file().get_basename()
	for c in d.get("cases", []):
		if not c is Dictionary or not c.get("open") is Dictionary:
			continue
		var opened: Dictionary = c["open"]
		if c.get("receipt") == receipt and c.get("departure") == departure and opened.get("nextStep") == "council" and opened.get("after") is Dictionary:
			return [(opened["after"] as Dictionary).duplicate(true), d.get("tables", {})]
	return [{}, {}]


## [state, tables] of the second station in the sample, its session's record the one `left`
## holds when a session was left (its own vote); [{}, {}] when there is none.
static func arrival_sample(left: Dictionary = {}) -> Array:
	if not FileAccess.file_exists(COUNCIL_SAMPLE):
		return [{}, {}]
	var d = JSON.parse_string(FileAccess.get_file_as_string(COUNCIL_SAMPLE))
	if not d is Dictionary:
		return [{}, {}]
	var receipt0: String = RECEIPT_SAMPLE.get_file().get_basename()
	var departure: String = DEPARTURE_SAMPLE.get_file().get_basename()
	for c in d.get("cases", []):
		if not c is Dictionary or not c.get("arrival") is Dictionary:
			continue
		if c.get("receipt") != receipt0 or c.get("departure") != departure:
			continue
		var a: Dictionary = c["arrival"]
		if not a.get("state") is Dictionary:
			continue
		var g1: Dictionary = (a["state"] as Dictionary).duplicate(true)
		var ours: Variant = (left.get("fieldReturns", {}) as Dictionary).get("special") if left.get("fieldReturns") is Dictionary else null
		if ours is Dictionary and g1.get("fieldReturns") is Dictionary:
			g1["fieldReturns"]["special"] = (ours as Dictionary).duplicate(true)
		return [g1, d.get("tables", {})]
	return [{}, {}]
