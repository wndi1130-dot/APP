extends "res://addons/gut/test.gd"

const Dom = preload("res://game/train/train_dom.gd")
const Order = preload("res://game/train/train_work_order.gd")
const Research = preload("res://game/train/train_research.gd")
const Supplies = preload("res://game/train/train_supplies.gd")
const Workshop = preload("res://game/train/train_workshop.gd")
const Save = preload("res://game/politics/save_slot.gd")
const RestoreVectors = preload("res://tests/train/restore_vectors.gd")
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
	var out: Dictionary = RestoreVectors.project(g)
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
	var t: Dictionary = tables.duplicate(true)
	var fine: Dictionary = {}
	for cond: Dictionary in t["CONDITIONS"]["front"]:
		if cond["kind"] == "give_fine": fine = cond.duplicate(true)
	assert_false(fine.is_empty())
	t["CONDITIONS"]["guard"].append(fine.duplicate(true))
	g = _board()
	g["supFine"] = 1.0
	var shared_session: int = -1
	for session: int in 12:
		g["session"] = session
		if _offered(g, t, "front") and _offered(g, t, "guard"):
			shared_session = session
			break
	assert_gte(shared_session, 0, "both cars have an offer in one session")
	if shared_session < 0: return
	# First car makes a promise in this session; the second car cannot reuse it.
	g["comms"]["front"]["promise"] = {"kind": "open", "cond": fine.duplicate(true), "due": int(g["seg"]) + 3, "madeSession": shared_session}
	assert_false(_offered(g, t, "guard"), "same session reservation")
	# The front car's earlier promise must also reserve the stock now.
	g["comms"]["front"]["promise"]["madeSession"] = shared_session - 1
	assert_false(_offered(g, t, "guard"), "earlier session reservation")
	g["comms"]["front"]["promise"] = null
	# One settlement can make exactly one: once promised, no second offer can spend it.
	for comm: String in t["COMMS"]: g["comms"][comm]["pop"] = 40
	g["supFine"] = 0.0
	g["dom"]["supFineOn"] = true
	assert_almost_eq(Vote.fine_room(g, t), 1.0, 0.000000001)
	assert_true(_offered(g, t, "guard"), "planned goods open the offer")
	g["comms"]["front"]["promise"] = {"kind": "open", "cond": fine.duplicate(true), "due": int(g["seg"]) + 3, "madeSession": shared_session}
	assert_false(_offered(g, t, "guard"), "planned goods already promised")

func _offered(g: Dictionary, t: Dictionary, comm: String) -> bool:
	for cond: Dictionary in Vote.open_conditions(g, t, comm):
		if cond.get("kind") == "give_fine": return true
	return false

func test_fine_condition_cycles_and_classified_differences() -> void:
	var rows: Array = data["groups"].get("fine_conditions", [])
	var reports: Array = data["groups"].get("fine_conditions_report", [])
	assert_eq(rows.size(), 6, "regenerate fine condition fixtures")
	assert_eq(reports.size(), 1, "missing classified difference report")
	if reports.size() != 1: return
	var report: Dictionary = reports[0]
	var allowed: Dictionary = {}
	for category: String in ["s1c", "fine_policy"]:
		for entry: Dictionary in report[category]:
			var key: String = "%s/%s/%d/%d" % [entry["name"], entry["comm"], int(entry["session"]), int(entry["condition"])]
			assert_false(allowed.has(key), "duplicate allowed cell " + key)
			allowed[key] = {"category": category, "entry": entry}
	var same: int = 0
	var fine_count: int = 0
	var s1c_count: int = 0
	var seen: Dictionary = {}
	for row: Dictionary in rows:
		var g: Dictionary = _project(row["before"])
		assert_eq((row["rounds"] as Array).size(), 12, row["name"])
		for round: Dictionary in row["rounds"]:
			g["session"] = int(round["session"])
			for comm: String in tables["COMMS"]:
				var raw: Array = round["s1_raw"][comm]
				var expected: Array = round["s2_policy"][comm]
				var actual: Array = Vote.open_conditions(g, tables, comm)
				assert_eq(V.diff(expected, actual), "", "%s/%s/%d policy" % [row["name"], comm, int(g["session"])])
				assert_eq(raw.size(), 3)
				assert_eq(expected.size(), 3)
				if raw.size() != 3 or expected.size() != 3: continue
				for i: int in 3:
					var key: String = "%s/%s/%d/%d" % [row["name"], comm, int(g["session"]), i + 1]
					if V.diff(raw[i], expected[i]) == "":
						same += 1
						assert_false(allowed.has(key), "equal cell listed: " + key)
						continue
					assert_true(allowed.has(key), "unlisted difference: " + key)
					if not allowed.has(key): continue
					var item: Dictionary = allowed[key]
					assert_eq(V.diff(raw[i], item["entry"]["s1_raw"]), "", key + " raw")
					assert_eq(V.diff(expected[i], item["entry"]["s2_policy"]), "", key + " policy")
					seen[key] = true
					if item["category"] == "s1c": s1c_count += 1
					else: fine_count += 1
	assert_eq(seen.size(), allowed.size(), "unused allowed cells")
	assert_eq(same, int(report["same"]))
	assert_eq(fine_count, int(report["fine_count"]))
	assert_eq(s1c_count, int(report["s1c_count"]))
	assert_eq(same + fine_count + s1c_count, 6 * 12 * (tables["COMMS"] as Array).size() * 3)

func test_supplies_research_start_and_completion_whole_board() -> void:
	var rows: Array = data["groups"].get("research_actions", [])
	assert_eq(rows.size(), 6, "regenerate research action fixtures")
	for row: Dictionary in rows:
		var g: Dictionary = _project(row["before"])
		var id: String = row["id"]
		assert_eq(Research.restore_block(g, id), row["block"], row["name"] + " block")
		assert_eq(bool(row["result"]), bool(g.get("supOn", false)), row["name"] + " expected availability")
		assert_eq(Research.start_restore(g, id, "full", row["variant"]), row["result"], row["name"] + " start")
		assert_eq(V.diff(_project(row["started"]), g), "", row["name"] + " started whole board")
		for step: Dictionary in row["work_steps"]:
			g = _project(step["before"])
			var got: Dictionary = Workshop.run(g, tables)
			assert_eq(V.diff(step["value"], {"used": got["used"], "did": got["did"]}), "", row["name"] + " work result")
			assert_eq(V.diff(_project(step["after"]), g), "", row["name"] + " work whole board")
		if bool(row["result"]):
			assert_gt((row["work_steps"] as Array).size(), 0)
			if not (row["work_steps"] as Array).is_empty():
				assert_eq(row["work_steps"][-1]["after"]["dom"]["techs"][id]["stage"], "done")

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


func test_restore_relations_history_finish_cancel_and_reload_sequences_match_s1() -> void:
	var rows: Array = data["groups"]["restore_sequences"]
	assert_eq(rows.size(), 11)
	for row: Dictionary in rows:
		var g: Dictionary = _project(row["initial"])
		var reloaded: bool = false
		for step: Dictionary in row["steps"]:
			var at: String = String(row["name"]) + "/" + String(step["action"]["kind"])
			var expected_before: Dictionary = _project(step["before"])
			if reloaded:
				expected_before["lateOn"] = false
				expected_before["lateCards"] = []
			assert_eq(V.diff(expected_before, g), "", at + " input")
			var action: Dictionary = step["action"]
			var value: Variant = null
			match String(action["kind"]):
				"start_restore": value = Research.start_restore(g, String(action["id"]), String(action["mode"]), action.get("variant"))
				"cancel_restore": Research.cancel_restore(g)
				"start_finish": value = Research.start_finish(g, String(action["id"]))
				"run_workshop":
					var result: Dictionary = Workshop.run(g, tables)
					value = {"used": result["used"], "did": result["did"]}
				"add_frags":
					var field: String = String(Research.TECHS[action["id"]]["branch"])
					g["dom"]["frags"][field] = float(g["dom"]["frags"][field]) + float(action["amount"])
				"save_load":
					# The S1 action is a raw JSON/read round trip, not slot_board's version upgrade.
					var loaded: Dictionary = Save.read_save(JSON.parse_string(JSON.stringify(g)), tables)
					value = loaded["ok"]
					assert_true(loaded["ok"], at)
					if loaded["ok"]: g = loaded["g"]
					reloaded = true
				_: fail_test("Unknown restore action: " + str(action))
			assert_eq(V.diff(step["value"], value), "", at + " returned value")
			var expected_after: Dictionary = _project(step["after"])
			if reloaded:
				# S2-only late-event defaults are literal expectations, never computed by Save.
				expected_after["lateOn"] = false
				expected_after["lateCards"] = []
			assert_eq(V.diff(expected_after, g), "", at + " whole board")
			assert_true(Dom.is_store(g["dom"]), at + " store")
