extends "res://addons/gut/test.gd"

const Dom = preload("res://game/train/train_dom.gd")
const Order = preload("res://game/train/train_work_order.gd")
const Research = preload("res://game/train/train_research.gd")
const Supplies = preload("res://game/train/train_supplies.gd")
const Workshop = preload("res://game/train/train_workshop.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const Settle = preload("res://game/train/turn/turn_settle.gd")
const V = preload("res://tests/politics/field_vectors.gd")
const PATH = "res://tests/fixtures/train/supplies_vectors.json"

var data: Dictionary
var tables: Dictionary

func before_all() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	tables = data["tables"]

func _board() -> Dictionary:
	var g: Dictionary = data["groups"]["settles"][0]["before"].duplicate(true)
	g["supOn"] = true
	g["supFine"] = 0.0
	g["dom"] = Dom.start()
	g["dom"]["scrap"] = 100.0
	g["dom"]["parts"] = 100.0
	g["dom"]["target"] = 0
	g["dom"]["order"] = ["sup", "parts", "restore", "modify"]
	g["dom"]["experts"] = [{"name": "craft", "comm": "front", "field": "craft", "skill": 3}]
	for id: String in ["w6", "w7", "w8"]:
		g["dom"]["techs"][id] = {"stage": "done", "defect": false, "progress": 3.0, "need": 3.0}
	return g

func _project(g: Dictionary) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	for key: String in data["s2DomOmit"]:
		out["dom"].erase(key)
	return out

func test_supplies_recipes_cap_progress_match_s1() -> void:
	var rows: Array = data["groups"].get("workshop", [])
	assert_false(rows.is_empty(), "lead must regenerate the 2b fixtures")
	for row: Dictionary in rows:
		var g: Dictionary = _project(row["before"])
		assert_true(Dom.is_store(g["dom"]), row["name"])
		var result: Dictionary = Workshop.run(g, tables)
		assert_eq(V.diff(row["value"], {"used": result["used"], "did": result["did"]}), "", row["name"] + " result")
		var expected: Dictionary = _project(row["after"])
		if not expected.has("contentFlags") and g.get("contentFlags") == {}: g.erase("contentFlags")
		if not expected.has("wounds") and g.get("wounds") == []: g.erase("wounds")
		assert_eq(V.diff(expected, g), "", row["name"] + " whole board including supplies and ledger")

func test_supplies_workshop_settlement_matches_s1() -> void:
	var count: int = 0
	for row: Dictionary in data["groups"].get("workshop_settles", []):
		if not String(row["name"]).begins_with("supplies/"): continue
		count += 1
		var g: Dictionary = _project(row["before"])
		var result: Dictionary = Workshop.settle_stretch(g, tables)
		assert_eq(V.diff(row["value"], {"used": result["used"], "did": result["did"], "starved": result["starved"]}), "", row["name"] + " result")
		var expected: Dictionary = _project(row["after"])
		if not expected.has("contentFlags") and g.get("contentFlags") == {}: g.erase("contentFlags")
		if not expected.has("wounds") and g.get("wounds") == []: g.erase("wounds")
		assert_eq(V.diff(expected, g), "", row["name"] + " whole board")
	assert_eq(count, 2, "lead must regenerate the 2b fixtures")

func test_fine_mode_switch_keeps_progress() -> void:
	var g: Dictionary = _board()
	g["dom"]["supWork"] = 0.2
	assert_true(Workshop.set_sup_fine(g, true))
	assert_eq(g["dom"]["supWork"], 0.2)
	var rows: Array = data["groups"].get("fine_mode", [])
	assert_false(rows.is_empty(), "lead must regenerate the 2b fixtures")
	for row: Dictionary in rows:
		var state: Dictionary = _project(row["before"])
		var accepted: bool = Workshop.set_sup_fine(state, bool(row["after"]["dom"]["supFineOn"]))
		assert_eq(accepted, row["value"], row["name"])
		assert_eq(V.diff(_project(row["after"]), state), "", row["name"] + " whole board")
	assert_true(Workshop.set_sup_fine(g, false))
	assert_eq(g["dom"]["supWork"], 0.2)

func test_supplies_off_hides_w6_w8_and_controls() -> void:
	var research_rows: Array = data["groups"].get("research", [])
	assert_false(research_rows.is_empty(), "lead must regenerate the 2b fixtures")
	for row: Dictionary in research_rows:
		var board: Dictionary = _project(row["before"])
		var id: String = String(row["name"]).split("/")[0]
		assert_eq(Research.visible(board).has(id), row["value"]["shown"], row["name"])
		assert_eq(Research.restore_block(board, id), row["value"]["block"], row["name"])
	for flag: Variant in [null, false]:
		var g: Dictionary = _board()
		if flag == null: g.erase("supOn")
		else: g["supOn"] = flag
		var before: PackedByteArray = var_to_bytes(g)
		for id: String in ["w6", "w7", "w8"]:
			assert_false(Research.visible(g).has(id))
			var check: Dictionary = g.duplicate(true)
			check["dom"]["techs"].erase(id)
			assert_eq(Research.restore_block(check, id), "아직 이 열차에서 못 쓴다")
		assert_false(Workshop.set_sup_fine(g, true))
		Order.move(g, "sup", 1)
		assert_eq(var_to_bytes(g), before)

func test_fine_promise_preview_matches_settle_make() -> void:
	var g: Dictionary = _board()
	g["dom"]["supFineOn"] = true
	var before: PackedByteArray = var_to_bytes(g)
	var room: float = Vote.fine_room(g, tables)
	assert_eq(var_to_bytes(g), before, "preview preserves the input")
	var copy: Dictionary = g.duplicate(true)
	Workshop.settle_stretch(copy, tables)
	assert_gt(float(copy["supFine"]), 0.0)
	assert_almost_eq(room, float(copy["supFine"]), 0.000000001)

func test_w6_done_mid_run_visits_sup_same_settle() -> void:
	var g: Dictionary = _board()
	g["dom"]["order"] = ["restore", "parts", "modify"]
	g["dom"]["restoring"] = "w6"
	g["dom"]["techs"]["w6"] = {"stage": "restoring", "defect": false, "progress": 0.0, "need": 0.1}
	var before: float = float(g.get("sup", 0))
	Workshop.run(g, tables)
	assert_eq(g["dom"]["order"].count("sup"), 1)
	assert_gt(float(g.get("sup", 0)), before)

func test_supplies_make_after_use_before_due_promise_once() -> void:
	var g: Dictionary = _board()
	for comm: String in tables["COMMS"]:
		g["comms"][comm]["pop"] = 40
		g["comms"][comm]["away"] = 0
		g["comms"][comm]["promise"] = null
	g["seg"] = 2
	g["sup"] = 5.0
	g["coal"] = 10000.0
	g["food"] = 10000.0
	g["med"] = 10000.0
	g["ledger"] = []
	g["comms"]["tail"]["promise"] = {"kind": "open", "cond": {"kind": "give_sup", "amount": 2.0}, "due": 2, "label": "생필품", "madeSession": 0}
	var after: Dictionary = Settle.settle(g, tables)
	var rows: Array = []
	for row: Dictionary in after["ledger"]:
		if row.get("k") == "sup": rows.append([row.get("why"), row.get("d")])
	assert_eq(rows, [["sup.use", -4.0], ["sup.make", 1.0], ["promise", -2.0]])
	assert_almost_eq(float(after["sup"]), 0.0, 0.000000001)

func test_fine_offer_requires_stock_or_planned_make() -> void:
	var g: Dictionary = _board()
	var without: int = 0
	var with_plan: int = 0
	for session: int in 12:
		g["session"] = session
		g["dom"]["supFineOn"] = false
		for cond: Dictionary in Vote.open_conditions(g, tables, "front"):
			if cond["kind"] == "give_fine": without += 1
		g["dom"]["supFineOn"] = true
		for cond: Dictionary in Vote.open_conditions(g, tables, "front"):
			if cond["kind"] == "give_fine": with_plan += 1
	assert_eq(without, 0)
	assert_gt(with_plan, 0)

func test_fine_offer_subtracts_unpaid_fine_promises() -> void:
	var g: Dictionary = _board()
	g["supFine"] = 4.0
	for amounts: Array in [[], [1.0], [1.0, 2.0]]:
		for comm: String in tables["COMMS"]: g["comms"][comm]["promise"] = null
		for i: int in amounts.size():
			g["comms"][tables["COMMS"][i]]["promise"] = {"cond": {"kind": "give_fine", "amount": amounts[i]}}
		var reserved: float = 0.0
		for amount: float in amounts: reserved += amount
		assert_almost_eq(Vote.fine_room(g, tables), 4.0 - reserved, 0.000000001)

func test_supplies_store_accepts_only_valid_progress_and_mode() -> void:
	var d: Dictionary = Dom.start()
	d["supWork"] = 0.0
	d["supFineOn"] = false
	assert_true(Dom.is_store(d))
	for bad: Variant in [-1.0, INF, NAN, "1", true]:
		d["supWork"] = bad
		assert_false(Dom.is_store(d))
	d["supWork"] = 0.0
	d["supFineOn"] = 1
	assert_false(Dom.is_store(d))
