extends GutTest

const Agenda = preload("res://game/politics/council_agenda.gd")
const V = preload("res://tests/train/train_vectors.gd")
const RestoreVectors = preload("res://tests/train/restore_vectors.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const PATH: String = "res://tests/fixtures/train/turn_vectors.json"


func test_regular_agenda_matches_whole_turn_samples() -> void:
	assert_true(FileAccess.file_exists(PATH), "turn fixture exists")
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_true(parsed is Dictionary, "turn fixture JSON")
	if not parsed is Dictionary: return
	var data: Dictionary = parsed
	assert_eq(data.get("format"), "turn-vectors-v1")
	var bad: Array[String] = []
	var count: int = 0
	for run: Dictionary in data["runs"]:
		for row: Dictionary in run["steps"]:
			var before: Dictionary = row["before"].duplicate(true)
			var label: String = "%s/%d agenda" % [run["seed"], int(row["step"])]
			var got: Dictionary = Agenda.agenda_options(before, data["tables"])
			bad.append_array(V.full_diffs(row["agenda"], got, label, 40 - bad.size()))
			bad.append_array(V.full_diffs(row["before"], before, label + " input", 40 - bad.size()))
			count += 1
	print("TURN_AGENDA checked=%d differences=%d" % [count, bad.size()])
	assert_true(count >= 4, "every seed was sampled")
	assert_eq(bad.size(), 0, "\n".join(bad))


func _pipe_input(variant: String = "a") -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/lawtech_vectors.json"))
	for row: Dictionary in data["sequences"]:
		if row["name"] == "pipe-matrix/%s/passed=true/complete=false" % variant:
			return {"g": RestoreVectors.project(row["steps"][0]["after"]), "t": data["tables"]}
	return {}


func test_pipe_agenda_follows_law_ratification_and_precedes_proposals() -> void:
	var input: Dictionary = _pipe_input()
	var g: Dictionary = input["g"]
	var t: Dictionary = input["t"]
	g["ratify"] = ["common_heating"]
	g["proposals"] = [{"kind": "motion", "motion": "field_symbol", "subject": "tail"}]
	var before: String = JSON.stringify(g, "", false)
	var got: Dictionary = Agenda.agenda_options(g, t)
	assert_false(got["forced"])
	assert_eq((got["options"] as Array).slice(0, 3), [{"law": "common_heating", "repeal": false, "ratify": true},
		{"kind": "motion", "motion": "pipe"}, {"kind": "motion", "motion": "field_symbol", "subject": "tail"}])
	assert_eq(JSON.stringify(g, "", false), before, "agenda reads do not mutate")
	assert_eq(Agenda.agenda_options(g, t)["options"], got["options"], "unvoted pipe is supplied next time too")
	g["coal"] = 0
	var crisis: Dictionary = Agenda.agenda_options(g, t)
	assert_true(crisis["forced"])
	assert_false((crisis["options"] as Array).has({"kind": "motion", "motion": "pipe"}), "forced crisis delays pipe as S1 does")
	g["coal"] = 1000
	g["dom"]["techs"]["e3"]["pending"] = false
	assert_false((Agenda.agenda_options(g, t)["options"] as Array).has({"kind": "motion", "motion": "pipe"}))


func test_pipe_stance_uses_pending_variant_and_sick_rounding() -> void:
	var agenda: Dictionary = {"kind": "motion", "motion": "pipe"}
	for variant: String in ["a", "b", "none"]:
		var input: Dictionary = _pipe_input()
		var g: Dictionary = input["g"]
		var t: Dictionary = input["t"]
		if variant == "none": g["dom"]["techs"]["e3"]["pending"] = false
		else: g["dom"]["techs"]["e3"]["variant"] = variant
		for sick: bool in [false, true]:
			for comm: String in t["COMMS"]:
				if sick: g["comms"][comm]["sick"] = {}
				else: g["comms"][comm].erase("sick")
				var want: float = 0.0
				if variant != "none" and comm in ["tail", "front"]:
					want = (3.0 if sick else 2.0) * (1.0 if (variant == "a" and comm == "tail") or (variant == "b" and comm == "front") else -1.0)
				var before: String = JSON.stringify(g, "", false)
				var got: Dictionary = Vote.stance(g, t, comm, agenda)
				assert_eq(float(got["mat"]), want, "%s/%s/sick=%s" % [variant, comm, sick])
				assert_eq(float(got["ideo"]), 0.0)
				assert_eq(JSON.stringify(g, "", false), before)
		assert_eq(Vote.agenda_need(t, agenda), 51)
		assert_eq(Vote.agenda_title(t, agenda), "배관 추인")
