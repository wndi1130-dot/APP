extends GutTest

const Agenda = preload("res://game/politics/council_agenda.gd")
const V = preload("res://tests/train/train_vectors.gd")
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
