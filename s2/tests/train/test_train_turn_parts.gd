extends GutTest
const Advance = preload("res://game/train/train_advance.gd")
const Death = preload("res://game/train/turn/turn_death.gd")
const Wounds = preload("res://game/train/turn/turn_wounds.gd")
const V = preload("res://tests/train/train_vectors.gd")
const Late = preload("res://game/train/turn/turn_late.gd")
const Travel = preload("res://game/train/turn/turn_travel.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const SaveSlot = preload("res://game/politics/save_slot.gd")
const Budget = preload("res://game/train/turn/turn_budget.gd")
const Common = preload("res://game/train/turn/turn_common.gd")
var _errors: Dictionary = {}
var _count: int = 0
var _matched: int = 0
var _names: Array = []
var _tables: Dictionary = {}

func before_all() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/turn_vectors.json"))
	var rows: Array = []
	_tables = data["tables"]
	for part: Dictionary in data.get("parts", []):
		var action: Dictionary = part["action"]
		var g: Dictionary = part["before"].duplicate(true)
		var notes: Array = []
		match str(action["kind"]):
			"choose_card": g = Advance.choose_card(g, data["tables"], int(action["uid"]), int(action["index"]))
			"advance": g = Advance.advance(g, data["tables"])
			"resolve_stop": g = Advance.resolve_stop(g, data["tables"], bool(action["go"]))
			"death": Death.on_death(g, data["tables"], action["comm"], action["names"], action["cause"], bool(action["witness"]), bool(action["quiet"]))
			"wound_tick": Wounds.tick(g, data["tables"], notes, float(action["medMult"]))
			"late_next": Late.next_segment(g, data["tables"])
			"budget_pass": Budget.pass_cards(g, data["tables"])
			"budget_next": Budget.next_segment(g, data["tables"])
			"add_card": Common.card(g, action["card"], data["tables"])
			"draw_event": Travel.draw_event(g, data["tables"])
			"repeal_ration": g = Vote.repeal_law(g, data["tables"], "emergency_ration")
			"read_save":
				var read: Dictionary = SaveSlot.read_save(g, data["tables"])
				assert_true(read["ok"], part["name"])
				g = read["g"]
				# S1 represents old defaults by absent keys; S2 writes the same off/empty values.
				if not part["after"].has("lateOn") and g.get("lateOn") == false: g.erase("lateOn")
				if not part["after"].has("lateCards") and g.get("lateCards") == []: g.erase("lateCards")
		var differences: Array[String] = V.full_diffs(part["after"], g, part["name"], 20)
		if part.has("notes"): differences.append_array(V.full_diffs(part["notes"], notes, str(part["name"]) + ".notes", 20))
		var group: String = str(part["name"]).get_slice("/", 0)
		if not _errors.has(group): _errors[group] = []
		_errors[group].append_array(differences)
		_names.append(str(part["name"]))
		_count += 1
		if differences.is_empty(): _matched += 1
		rows.append({"name": part["name"], "matched": differences.is_empty(), "differences": differences})
	var report: Dictionary = {"checked": _count, "matched": _matched, "errors": _errors, "parts": rows}
	if OS.get_environment("GUT_NO_REPORT_FILES") != "1":
		var file: FileAccess = FileAccess.open("res://.godot/turn_port_2_parts_audit.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("TURN_PARTS checked=%d matched=%d" % [_count, _matched])

func test_alternative_card_choices_match_s1() -> void:
	assert_true(_errors.has("card"), "card fixtures must exist")
	assert_eq(_errors.get("card", []), [], "card alternatives and invalid indices")

func test_late_choices_returns_expiry_duplicates_and_saves_match_s1() -> void:
	assert_true(_errors.has("late"), "late fixtures must exist")
	# Every decision 514 path must be there to be compared: a missing row fails.
	var need: Array[String] = ["late/save/old", "late/save/held", "late/repeal", "late/unsupported/info"]
	for mode: String in ["gone", "former", "law-down", "answered", "duplicate", "order"]: need.append("late/return/" + mode)
	for mode: String in ["pick", "return-order", "protect-returned", "expiry", "merge", "gone", "gone-player"]: need.append("late/budget/" + mode)
	for i: int in 12: need.append_array(["late/settle-duplicate/%d" % i, "late/travel-duplicate/%d" % i])
	var tags: Array[String] = ["late/ration_cut/tail", "late/travel/tail"]
	for comm: String in _tables["COMMS"]:
		for kind: String in ["demand", "favor", "promise_ledger"]: tags.append("late/%s/%s" % [kind, comm])
	for tag: String in tags:
		for step: String in ["defer-1", "return-1", "answer-1-0", "defer-2", "return-2", "answer-2-0", "defer-3"]: need.append(tag + "/" + step)
	for row: String in need: assert_true(_names.has(row), row + " is compared")
	assert_eq(_errors.get("late", []), [], "all appended decision 514 inputs")

func test_shared_death_and_wound_hooks_match_s1() -> void:
	assert_true(_errors.has("death") and _errors.has("wounds"), "death/wound fixtures must exist")
	assert_eq(_errors.get("death", []), [], "family, corpse laws and death wound hook")
	assert_eq(_errors.get("wounds", []), [], "treatment with and without medicine")

func test_settlement_parts_match_s1() -> void:
	assert_true(_errors.has("settle"), "settlement fixtures must exist")
	assert_eq(_errors.get("settle", []), [], "child, heating, needs, calm, deals and hub")

func test_stop_death_and_child_hands_match_s1() -> void:
	assert_true(_errors.has("stop"), "stop fixtures must exist")
	assert_eq(_errors.get("stop", []), [], "death and child hands in stop resolution")

func test_hub_boundary_returns_unchanged_copy_with_error() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/turn_vectors.json"))
	var original: Dictionary = data["runs"][0]["steps"][0]["before"].duplicate(true)
	original["phase"] = "settle"
	original["seg"] = 22
	original["cards"] = []
	var saved: Dictionary = original.duplicate(true)
	var got: Dictionary = Advance.advance(original, data["tables"])
	assert_true(str(got.get("_turn_port_error", "")).begins_with("F-NOT-PORTED: "))
	got.erase("_turn_port_error")
	assert_eq(V.full_diffs(saved, got, "unsupported copy", 10), [])
	assert_eq(V.full_diffs(saved, original, "unsupported input", 10), [])
