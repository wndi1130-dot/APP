extends "res://addons/gut/test.gd"
## Each person's own memory (person_memory.gd, a port of s1 memory.ts) against the S1 answers in
## field_vectors.json "memories": one return that carries every witnessed template is applied the
## same way, and the departure made again after it carries the same stance and cues.

const V = preload("res://tests/politics/field_vectors.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const PersonMemory = preload("res://game/politics/person_memory.gd")

var _tables: Dictionary


func before_all() -> void:
	_tables = V.tables()


func _check(bad: Array[String], label: String, want: Variant, got: Variant) -> void:
	var problem := V.diff(want, got, label)
	if problem != "" and bad.size() < 40:
		bad.append(problem)


func _memories() -> Array:
	return V.data().get("memories", [])


func test_the_fixture_has_a_memory_case_a_seed() -> void:
	assert_eq(_memories().size(), 3)


func test_a_return_leaves_the_same_memories_as_s1() -> void:
	var bad: Array[String] = []
	for row: Dictionary in _memories():
		var at: String = row["seed"]
		var applied := FieldReturn.apply_field_return(row["state"], _tables, row["departure"], row["receipt"])
		_check(bad, at + " status", row["apply"]["status"], applied["status"])
		_check(bad, at + " memory", row["apply"]["after"]["memory"], applied["g"].get("memory"))
		_check(bad, at + " chronicle", row["apply"]["after"].get("chronicle"), applied["g"].get("chronicle"))
		_check(bad, at + " again", row["again"], FieldDeparture.build(applied["g"], _tables, row["opts"]))
		# The whole state is not compared here: this case has one of the roll die, and the train's own
		# side of a death (deathLog, mourning) is the return port's to match (test_field_departure.gd).
	assert_eq(bad, [] as Array[String])


func test_the_same_return_twice_is_kept_once() -> void:
	var row: Dictionary = _memories()[0]
	var g: Dictionary = row["apply"]["after"].duplicate(true)
	var before: int = (g["memory"]["rows"] as Array).size()
	var again := PersonMemory.from_return(g, _tables, row["departure"], row["receipt"], FieldReturn.returned_of(row["receipt"]))
	assert_eq(again, [])
	assert_eq((g["memory"]["rows"] as Array).size(), before)


func test_memories_leave_the_cars_alone() -> void:
	var row: Dictionary = _memories()[0]
	var g: Dictionary = row["state"].duplicate(true)
	var rel_before: Dictionary = {}
	for comm: String in _tables["COMMS"]:
		rel_before[comm] = g["comms"][comm]["rel"]
	PersonMemory.from_return(g, _tables, row["departure"], row["receipt"], FieldReturn.returned_of(row["receipt"]))
	for comm: String in _tables["COMMS"]:
		assert_eq(g["comms"][comm]["rel"], rel_before[comm], comm + " rel unchanged by memory")
	assert_true((g["memory"]["rows"] as Array).size() > 0)


func test_the_voice_hash_matches_s1() -> void:
	# memory.ts voiceOf for every profile (FNV-1a over "<id>:voice"), field_vectors.json "voices".
	var want: Dictionary = V.data().get("voices", {})
	assert_eq(want.size(), (_tables["PROFILES"] as Array).size())
	var bad: Array[String] = []
	for id: String in want:
		if PersonMemory.voice_of(id) != String(want[id]):
			bad.append(id)
	assert_eq(bad, [] as Array[String])
