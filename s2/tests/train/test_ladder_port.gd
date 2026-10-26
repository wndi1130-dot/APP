extends GutTest
## The unrest ladder (정치 흐름 P2, #699): riot ticks (the unannounced riot held one
## settle, a dismissed protest that comes back, the lower line after a concession,
## an ongoing riot), the protest/riot/last-chance cards' choice labels and grey-outs,
## and the whole state after each choice, against S1's own states
## (s1/tools/ladder_port_fixtures.ts). The last chance's revolt is not ported.

const Settle = preload("res://game/train/turn/turn_settle.gd")
const Cards = preload("res://game/train/turn/turn_cards.gd")
const V = preload("res://tests/train/train_vectors.gd")
const PATH: String = "res://tests/fixtures/train/ladder_vectors.json"

var _data: Dictionary = {}


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary: _data = parsed


## As test_law_port.gd: Godot reads some 17-digit decimals one bit off S1's, so
## the ledger's deltas are compared to 1e-9 and the rest exactly.
func _snap_ledger(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	for row: Dictionary in out.get("ledger", []):
		row["d"] = snappedf(float(row["d"]), 1e-9)
	return out


func _card(g: Dictionary, uid: int) -> Dictionary:
	for row: Dictionary in g["cards"]:
		if int(row["uid"]) == uid: return row
	return {}


func test_fixture_contract() -> void:
	assert_false(_data.is_empty(), "ladder fixture exists and parses")
	if _data.is_empty(): return
	assert_eq(_data.get("format"), "ladder-vectors-v1")
	assert_eq(_data.get("seeds"), ["ladder-0", "ladder-1"])
	var kinds := {}
	for row: Dictionary in _data["cases"]:
		kinds[str(row["name"]).get_slice("/", 0)] = true
	for kind: String in ["tick", "view", "choose"]:
		assert_true(kinds.has(kind), kind)


func test_every_ladder_case_matches_s1() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var bad: Array[String] = []
	for row: Dictionary in _data["cases"]:
		var input: Dictionary = row["before"].duplicate(true)
		var action: Dictionary = row["action"]
		var at: String = str(row["name"])
		var got: Dictionary = {}
		match str(action["kind"]):
			"riot_tick":
				input["tension"] = float(action["tension"])
				Settle.riot_tick(input, t, [])
				got = input
			"view":
				var v: Dictionary = Cards.view(input, t, _card(input, int(action["uid"])))
				var labels: Array = []
				for c: Dictionary in v.get("choices", []):
					var one := {"label": c["label"]}
					if c.has("disabled"): one["disabled"] = c["disabled"]
					labels.append(one)
				bad.append_array(V.full_diffs(row["out"], labels, at + " out", 4))
				continue
			"choose":
				got = Cards.choose(input, t, int(action["uid"]), int(action["index"]))
		if got.has("_turn_port_error"):
			bad.append("%s: %s" % [at, got["_turn_port_error"]])
		else:
			bad.append_array(V.full_diffs(_snap_ledger(row["after"]), _snap_ledger(got), at, 8))
		if bad.size() >= 40: break
	assert_eq(bad.size(), 0, "First differences:\n" + "\n".join(bad.slice(0, 40)))
