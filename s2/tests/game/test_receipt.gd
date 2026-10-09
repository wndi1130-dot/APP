extends "res://addons/gut/test.gd"
## Receipt builder tests.
## Shared fixture loop: _sample() below is written to tests/game/fixtures/receipt_gd_sample.json,
## and s1/tests/receipt.test.ts validates that same file against s1/schema/receipt.schema.json.
## Regenerate after changing the builder or _sample():
##   S2_WRITE_RECEIPT_SAMPLE=/home/claude/APP/s2/tests/game/fixtures/receipt_gd_sample.json \
##     /tmp/claude-0/run_s2_tests.sh /home/claude/APP/s2 -gselect=test_receipt
## (writes to_json() + "\n" to that absolute path; rerun without the variable to confirm it matches).

const Receipt = preload("res://game/sim/receipt.gd")
const SAMPLE_PATH := "res://tests/game/fixtures/receipt_gd_sample.json"


func _sample() -> Receipt:
	var r := Receipt.new("first_leg_01_sulechow", "freight", "s2_graybox")
	r.set_time("D1 10:30", "D1 15:30", 300)
	r.add_stock("coal", 7)
	r.add_stock("food", 1)
	r.add_stock("ammo_pistol", -9)
	r.add_stock("ammo_craft", -3)
	r.add_stock("medicine", 2)
	r.add_stock("ammo_pistol", 4)
	r.gain_item("symbol_departure_bell")
	r.lose_item("weapon_pipe_shotgun")
	for id: String in ["s2_lead", "s2_medic", "s2_shooter", "s2_scout", "s2_crew_01", "s2_crew_02", "s2_escort_01"]:
		r.person("sent", id)
	r.person("injured", "s2_shooter")
	r.person("bitten", "s2_crew_02")
	r.person("leftBehind", "s2_crew_02")
	r.person("rescued", "npc_signalman")
	r.witness("s2_lead", "left_bitten_crewman", "west_siding", "D1 15:20", "bitten", ["s2_medic", "s2_escort_01"])
	r.witness("s2_scout", "shoveled_snow_into_tower", "water_tower", "D1 11:05", "water_tower_frozen", ["s2_crew_01"])
	r.decision("water_tower", "shovel_snow")
	r.decision("raider_surrender", "bind_take")
	r.set_place_state(0.35, 3)
	r.place_note("raidersTaken", 2)
	r.promise("rep_engine", "bring_symbol_departure_bell", true)
	r.set_end("limit")
	return r


## Ints become floats through JSON; compare numerically.
func _norm(v: Variant) -> Variant:
	if v is int:
		return float(v)
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(_norm(x))
		return a
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[k] = _norm(v[k])
		return d
	return v


func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(_norm(a), "", true) == JSON.stringify(_norm(b), "", true)


func _has_problem(problems: Array[String], prefix: String) -> bool:
	for p: String in problems:
		if p.begins_with(prefix):
			return true
	return false


func test_sample_passes_check() -> void:
	assert_eq(Receipt.check(_sample().to_dict()), [] as Array[String])


func test_fresh_builder_has_all_required_keys_but_no_time() -> void:
	var d := Receipt.new("first_leg_01_sulechow").to_dict()
	for key: String in Receipt.REQUIRED:
		assert_true(d.has(key), key)
	assert_eq(d["place"], {"id": "first_leg_01_sulechow", "type": "freight", "variant": "s2_graybox"})
	assert_eq(d["source"], "direct")
	assert_false(d.has("endReason"))
	assert_false(d.has("decisions"))
	var problems := Receipt.check(d)
	assert_true(_has_problem(problems, "time.arrive"))
	assert_true(_has_problem(problems, "time.depart"))
	assert_eq(problems.size(), 2, str(problems))


func test_each_missing_required_key_is_caught() -> void:
	for key: String in Receipt.REQUIRED:
		var d := _sample().to_dict()
		d.erase(key)
		var problems := Receipt.check(d)
		assert_eq(problems, ["%s: 없음" % key] as Array[String], key)


func test_stay_minutes_boundary() -> void:
	var r := _sample()
	assert_true(r.set_time("D1 10:30", "D1 10:30", 0))
	assert_eq(Receipt.check(r.to_dict()), [] as Array[String])
	# The builder never writes a negative stay; check() still catches one.
	assert_true(r.set_time("D1 10:30", "D1 10:30", -1))
	assert_eq(r.to_dict()["time"]["stayGameMinutes"], 0)
	var d := r.to_dict()
	d["time"]["stayGameMinutes"] = -1
	assert_true(_has_problem(Receipt.check(d), "time.stayGameMinutes"))


func test_clock_format_boundaries() -> void:
	var r := _sample()
	assert_true(r.set_time("D1 00:00", "D12 23:59", 10))
	assert_eq(Receipt.check(r.to_dict()), [] as Array[String])
	for bad: String in ["D0 10:30", "D1 24:00", "D1 10:60", "10:30", "D1 9:30", ""]:
		# The builder refuses and keeps the last good clocks.
		assert_false(r.set_time(bad, "D1 12:00", 10), bad)
		assert_false(r.set_time("D1 12:00", bad, 10), bad)
		assert_eq(r.to_dict()["time"]["arrive"], "D1 00:00", bad)
		var d := r.to_dict()
		d["time"]["arrive"] = bad
		assert_true(_has_problem(Receipt.check(d), "time.arrive"), bad)


func test_builder_refuses_bad_ids_and_empty_witness_text() -> void:
	var r := _sample()
	var before := r.to_json()
	assert_false(r.gain_item("Bell"))
	assert_false(r.lose_item(""))
	assert_false(r.person("sent", "S2 lead"))
	assert_false(r.decision("water tower", "shovel_snow"))
	assert_false(r.decision("water_tower", ""))
	assert_false(r.promise("rep_engine", "Bring bell", true))
	assert_false(r.witness("s2_lead", "", "west_siding", "D1 15:20", "bitten", []))
	assert_false(r.witness("s2_lead", "x", "west_siding", "D1 15:20", "bitten", ["Medic"]))
	assert_false(r.witness("s2_lead", "x", "west_siding", "D1 15:20", "bitten", [{"person": "s2_medic", "text": ""}]))
	assert_eq(r.to_json(), before)
	assert_true(r.witness("s2_lead", "x", "west_siding", "D1 15:20", "bitten", [{"person": "s2_medic", "text": "봤다."}]))
	assert_eq(r.problems(), [] as Array[String])


func test_stock_accumulates_in_fixed_order_and_refuses_unknown_keys() -> void:
	var r := Receipt.new("x")
	assert_true(r.add_stock("ammo_craft", -1))
	assert_true(r.add_stock("coal", 3))
	assert_true(r.add_stock("coal", -3))
	assert_false(r.add_stock("gold", 5))
	assert_false(r.add_stock("secret", 1))
	var stock: Dictionary = r.to_dict()["stock"]
	assert_eq(stock.keys(), ["coal", "ammo_craft"])
	assert_eq(stock["coal"], 0)
	assert_eq(stock["ammo_craft"], -1)


func test_all_stock_keys_accepted() -> void:
	var r := _sample()
	for key: String in Receipt.STOCK_KEYS:
		assert_true(r.add_stock(key, 1), key)
	assert_eq(Receipt.check(r.to_dict()), [] as Array[String])
	assert_eq((r.to_dict()["stock"] as Dictionary).keys(), Receipt.STOCK_KEYS)


func test_people_lists_dedupe_and_refuse_unknown_list() -> void:
	var r := Receipt.new("x")
	assert_true(r.person("sent", "p_001"))
	assert_true(r.person("sent", "p_001"))
	assert_true(r.person("sent", "s2_lead"))
	assert_false(r.person("heroes", "p_001"))
	var people: Dictionary = r.to_dict()["people"]
	assert_eq(people["sent"], ["p_001", "s2_lead"])
	assert_eq(people.keys(), Receipt.PEOPLE_LISTS)
	for list_name: String in Receipt.PEOPLE_LISTS:
		assert_true(people.has(list_name), list_name)


func test_items_keep_duplicates() -> void:
	var r := Receipt.new("x")
	r.gain_item("weapon_pistol")
	r.gain_item("weapon_pistol")
	assert_eq(r.to_dict()["items"], {"gained": ["weapon_pistol", "weapon_pistol"], "lost": []})


func test_decision_same_id_replaces() -> void:
	var r := Receipt.new("x")
	r.decision("raider_surrender", "shoot")
	r.decision("water_tower", "melt_with_fire")
	r.decision("raider_surrender", "disarm_release")
	assert_eq(r.to_dict()["decisions"], [
		{"id": "raider_surrender", "choice": "disarm_release"},
		{"id": "water_tower", "choice": "melt_with_fire"},
	])


func test_end_and_source_accept_only_known_values() -> void:
	var r := Receipt.new("x")
	for reason: String in Receipt.END_REASONS:
		assert_true(r.set_end(reason), reason)
		assert_eq(r.to_dict()["endReason"], reason)
	assert_false(r.set_end("fled"))
	assert_eq(r.to_dict()["endReason"], "wiped")
	assert_true(r.set_source("auto"))
	assert_false(r.set_source("manual"))
	assert_eq(r.to_dict()["source"], "auto")


func test_place_state_clamps_and_keeps_extra_keys() -> void:
	var r := Receipt.new("x")
	r.set_place_state(1.5, -2)
	r.place_note("bridgeOder", "blocked")
	r.place_note("looted", 0.1)
	assert_eq(r.to_dict()["placeState"], {"looted": 1.0, "remainingRisk": 0, "bridgeOder": "blocked"})
	r.set_place_state(-0.1, 4)
	assert_eq(r.to_dict()["placeState"]["looted"], 0.0)


const BREAKS := [
	"place.type", "place.id", "stock.gold", "stock.coal", "items.gained", "people.sent",
	"people.dead", "people.heroes", "witnessed.0.why", "witnessed.1.when", "witnessed.0.what",
	"placeState.looted", "placeState.remainingRisk", "promises.0", "source", "endReason",
	"decisions.1", "extra", "content_type",
	"place.extra", "time.extra", "items.extra", "witnessed.0.extra", "witnessed.0.witnesses.0",
	"witnessed.1.witnesses.1", "witnessed.0.weight", "witnessed.0.template", "promises.0.extra",
	"decisions.0.extra", "version", "people.wounds.0.part", "people.wounds.0.extra",
]


## Breaks one field of a valid receipt; the problem list should start with `prefix`.
func _break(d: Dictionary, prefix: String) -> void:
	match prefix:
		"place.type":
			d["place"]["type"] = "station"
		"place.id":
			d["place"]["id"] = "Sulechow"
		"stock.gold":
			d["stock"]["gold"] = 1
		"stock.coal":
			d["stock"]["coal"] = 1.5
		"items.gained":
			d["items"]["gained"] = "bell"
		"people.sent":
			d["people"]["sent"].append("s2_lead")
		"people.dead":
			d["people"].erase("dead")
		"people.heroes":
			d["people"]["heroes"] = []
		"witnessed.0.why":
			d["witnessed"][0].erase("why")
		"witnessed.1.when":
			d["witnessed"][1]["when"] = -1
		"witnessed.0.what":
			d["witnessed"][0]["what"] = ""
		"placeState.looted":
			d["placeState"]["looted"] = 1.01
		"placeState.remainingRisk":
			d["placeState"]["remainingRisk"] = 1.5
		"promises.0":
			d["promises"][0]["kept"] = "yes"
		"source":
			d["source"] = "manual"
		"endReason":
			d["endReason"] = "fled"
		"decisions.1":
			d["decisions"][1].erase("choice")
		"extra":
			d["extra"] = 1
		"content_type":
			d["content_type"] = "chronicle"
		"place.extra":
			d["place"]["extra"] = 1
		"time.extra":
			d["time"]["extra"] = 1
		"items.extra":
			d["items"]["extra"] = []
		"witnessed.0.extra":
			d["witnessed"][0]["extra"] = 1
		"witnessed.0.witnesses.0":
			d["witnessed"][0]["witnesses"][0] = "Medic"
		"witnessed.1.witnesses.1":
			d["witnessed"][1]["witnesses"].append({"person": "s2_crew_01", "text": "", "extra": 1})
		"witnessed.0.weight":
			d["witnessed"][0]["weight"] = -1
		"witnessed.0.template":
			d["witnessed"][0]["template"] = "Bad Template"
		"promises.0.extra":
			d["promises"][0]["extra"] = 1
		"decisions.0.extra":
			d["decisions"][0]["extra"] = 1
		"version":
			# Wounds need version 2; leaving it out is wrong.
			d["people"]["wounds"] = [{"person": "s2_shooter", "part": "arm_left", "kind": "deep"}]
		"people.wounds.0.part":
			d["version"] = 2
			d["people"]["wounds"] = [{"person": "s2_shooter", "part": "hand", "kind": "deep"}]
		"people.wounds.0.extra":
			d["version"] = 2
			d["people"]["wounds"] = [{"person": "s2_shooter", "part": "arm_left", "kind": "deep", "extra": 1}]


func test_check_catches_wrong_types_and_values() -> void:
	for prefix: String in BREAKS:
		var d := _sample().to_dict()
		_break(d, prefix)
		var problems := Receipt.check(d)
		assert_true(_has_problem(problems, prefix), "%s -> %s" % [prefix, str(problems)])


func test_check_accepts_segment_when_and_content_type() -> void:
	var d := _sample().to_dict()
	d["witnessed"][0]["when"] = 0
	d["content_type"] = "receipt"
	assert_eq(Receipt.check(d), [] as Array[String])


func test_check_accepts_v2_wounds_and_chronicle_extras() -> void:
	var d := _sample().to_dict()
	d["version"] = 2
	d["people"]["wounds"] = [
		{"person": "s2_shooter", "part": "arm_left", "kind": "deep"},
		{"person": "s2_crew_02", "part": "leg_right", "kind": "bite", "festering": false},
	]
	d["witnessed"][0]["id"] = "w_001"
	d["witnessed"][0]["weight"] = 1.5
	d["witnessed"][0]["template"] = "left_behind"
	d["witnessed"][1]["witnesses"].append({"person": "s2_crew_02", "text": "물 탱크에 눈을 퍼 넣었다."})
	assert_eq(Receipt.check(d), [] as Array[String])
	d["version"] = 1
	assert_true(_has_problem(Receipt.check(d), "version"))


func test_to_json_round_trips_with_fixed_key_order() -> void:
	var r := _sample()
	var text := r.to_json()
	assert_true(text.begins_with("{\n  \"place\": {\n    \"id\""), text.substr(0, 40))
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary)
	assert_true(_same(parsed, r.to_dict()))
	assert_eq((parsed as Dictionary).keys(), ["place", "time", "stock", "items", "people", "witnessed", "placeState", "promises", "source", "endReason", "decisions"])
	assert_eq(Receipt.check(parsed), [] as Array[String])
	assert_eq(r.to_json(), text)


func test_gd_sample_fixture_matches_builder() -> void:
	var text := _sample().to_json()
	var out_path := OS.get_environment("S2_WRITE_RECEIPT_SAMPLE")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		assert_not_null(f, "cannot write %s" % out_path)
		if f != null:
			f.store_string(text + "\n")
			f.close()
	assert_true(FileAccess.file_exists(SAMPLE_PATH), SAMPLE_PATH)
	var stored := FileAccess.get_file_as_string(SAMPLE_PATH)
	assert_eq(stored, text + "\n", "fixture is stale; regenerate (see header)")
	var parsed: Variant = JSON.parse_string(stored)
	assert_true(parsed is Dictionary)
	if parsed is Dictionary:
		assert_eq(Receipt.check(parsed), [] as Array[String])


# --- version 2 wounds (body_injury 4.6) ---

func test_builder_without_wounds_stays_version_one() -> void:
	var d := _sample().to_dict()
	assert_false(d.has("version"))
	assert_false((d["people"] as Dictionary).has("wounds"))


func test_add_wound_makes_a_version_two_receipt_that_passes_check() -> void:
	var r := _sample()
	assert_true(r.add_wound("s2_shooter", "leg_left", "embedded"))
	assert_true(r.add_wound("s2_shooter", "arm_right", "laceration"))
	assert_true(r.add_wound("s2_crew_01", "torso", "scratch", true))
	var d := r.to_dict()
	assert_eq(d["version"], 2)
	assert_eq(d["people"]["wounds"], [
		{"person": "s2_shooter", "part": "leg_left", "kind": "embedded"},
		{"person": "s2_shooter", "part": "arm_right", "kind": "laceration"},
		{"person": "s2_crew_01", "part": "torso", "kind": "scratch", "festering": true},
	])
	assert_eq(Receipt.check(d), [] as Array[String])
	assert_eq(Receipt.check(r.to_dict()), r.problems())


func test_version_sits_between_promises_and_source_in_the_json() -> void:
	var r := _sample()
	r.add_wound("s2_shooter", "arm_left", "fracture")
	var parsed: Variant = JSON.parse_string(r.to_json())
	assert_eq((parsed as Dictionary).keys(), ["place", "time", "stock", "items", "people", "witnessed", "placeState", "promises", "version", "source", "endReason", "decisions"])
	assert_eq(Receipt.check(parsed), [] as Array[String])
	assert_true(_same(parsed, r.to_dict()))


func test_add_wound_refuses_unknown_names_and_bad_ids() -> void:
	var r := _sample()
	assert_false(r.add_wound("s2_shooter", "hand_left", "scratch"))
	assert_false(r.add_wound("s2_shooter", "torso", "burn"))
	assert_false(r.add_wound("S2 Shooter", "torso", "scratch"))
	assert_false(r.to_dict().has("version"), "nothing was added")
	for part: String in Receipt.WOUND_PARTS:
		for kind: String in Receipt.WOUND_KINDS:
			assert_true(r.add_wound("s2_scout", part, kind), "%s %s" % [part, kind])
	assert_eq(Receipt.check(r.to_dict()), [] as Array[String])


func test_add_wound_folds_bites_and_serious_wounds_into_the_lists() -> void:
	var r := Receipt.new("first_leg_01_sulechow")
	r.add_wound("s2_lead", "arm_left", "bite")
	r.add_wound("s2_medic", "leg_right", "fracture")
	r.add_wound("s2_scout", "torso", "deep")
	r.add_wound("s2_shooter", "leg_left", "embedded")
	r.add_wound("s2_crew_01", "arm_right", "laceration")
	r.add_wound("s2_crew_02", "torso", "scratch")
	var people: Dictionary = r.to_dict()["people"]
	assert_eq(people["bitten"], ["s2_lead"])
	assert_eq(people["injured"], ["s2_medic", "s2_scout", "s2_shooter"])
	assert_eq(Receipt.fold_gaps(r.to_dict()), [] as Array[String])


func test_fold_gaps_names_what_is_missing_and_skips_the_gone() -> void:
	var d := _sample().to_dict()
	d["version"] = 2
	d["people"]["wounds"] = [
		{"person": "s2_crew_01", "part": "leg_right", "kind": "fracture"},
		{"person": "s2_lead", "part": "arm_left", "kind": "bite"},
		{"person": "s2_crew_02", "part": "torso", "kind": "bite"},
		{"person": "s2_scout", "part": "torso", "kind": "laceration"},
	]
	assert_eq(Receipt.fold_gaps(d), ["s2_crew_01 fracture not in injured", "s2_lead bite not in bitten"] as Array[String])
	assert_eq(Receipt.check(d), [] as Array[String], "folding is a separate check")
	assert_eq(Receipt.fold_gaps(_sample().to_dict()), [] as Array[String])


func test_check_still_wants_version_two_for_wounds_from_the_builder() -> void:
	var d := _sample().to_dict()
	d["people"]["wounds"] = [{"person": "s2_shooter", "part": "torso", "kind": "deep"}]
	assert_true(_has_problem(Receipt.check(d), "version"))
	d["version"] = 2
	assert_eq(Receipt.check(d), [] as Array[String])
