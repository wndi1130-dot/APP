extends GutTest
## Technology that bends a law (결정 426 PR 7, decision 446): the situation
## share, 모두를 치료's medicine, 공동 난방's coal and 공동 식당's food, which
## variant law opens, the use, law and journal lines, and the variant laws
## enacted, amended, voted and repealed, against S1's own answers
## (s1/tools/lawtech_port_fixtures.ts).

const LawTech = preload("res://game/train/train_lawtech.gd")
const St = preload("res://game/train/train_state.gd")
const Turn = preload("res://game/train/train_turn.gd")
const Agenda = preload("res://game/politics/council_agenda.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const Advance = preload("res://game/train/train_advance.gd")
const Dom = preload("res://game/train/train_dom.gd")
const Research = preload("res://game/train/train_research.gd")
const Workshop = preload("res://game/train/train_workshop.gd")
const TV = preload("res://tests/train/train_vectors.gd")
const RestoreVectors = preload("res://tests/train/restore_vectors.gd")
const Pipe = preload("res://game/train/train_pipe.gd")
const Content = preload("res://game/train/turn/turn_content.gd")
const PATH: String = "res://tests/fixtures/train/lawtech_vectors.json"
## The variant-law checks compare their owned state; the pipe sequences below
## compare whole boards, including the council result, log and restore state.
const VARIANT_KEYS: Array[String] = ["passed", "repealedAt", "boughtBy", "onceTaken", "comms", "coal", "food",
	"med", "trust", "tension", "fear", "journal", "ledger", "cards", "guidedLeft", "dom", "council", "contentFlags"]

var _data: Dictionary = {}
var _bad: Array[String] = []


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary: _data = parsed


func test_x1_has_workshop_use_outside_law() -> void:
	# S1 keeps x1 law-only for the bot and the chief; its use line still says 법 쓸모 (S2 making).
	assert_true(LawTech.LAW_ONLY_TECHS.has("x1"))
	assert_true(LawTech.use_line({"passed": {}}, "x1").begins_with("법 쓸모: "))
	assert_true(LawTech.use_line({"passed": {}}, "e1").begins_with("쓸모: "))


func before_each() -> void:
	_bad = []


func _same(want: Variant, got: Variant, label: String) -> void:
	var d: String = TV.diff(want, got, label)
	if d == "":
		d = TV.diff(got, want, label + " unexpected")
	if d != "" and _bad.size() < 20:
		_bad.append(d)


func test_fixture_contract() -> void:
	assert_false(_data.is_empty(), "lawtech fixture exists and parses")
	if _data.is_empty(): return
	assert_eq(_data.get("format"), "lawtech-vectors-v1")
	var t: Dictionary = _data["tables"]
	for key: String in LawTech.D:
		_same(t["D"][key], LawTech.D[key], "D." + key)
	for law: String in LawTech.LAW_MATS:
		_same(t["LAWS"][law]["mats"], LawTech.LAW_MATS[law], "mats." + law)
	for law: String in LawTech.LAW_TITLE:
		_same(t["LAWS"][law]["title"], LawTech.LAW_TITLE[law], "title." + law)
	var variants: Array = (t["LAW_VARIANT_OF"] as Dictionary).keys()
	variants.sort()
	var ours: Array = Vote.VARIANT_LAWS.duplicate()
	ours.sort()
	_same(variants, ours, "variant laws")
	for id: String in _data["techs"]:
		assert_true(Research.TECHS.has(id), id)
	assert_eq(_bad, [] as Array[String])


func test_every_profile_matches_s1() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var count := 0
	for row: Dictionary in _data["cases"]:
		var g: Dictionary = RestoreVectors.project(row["state"])
		var at: String = "%s/%d" % [row["seed"], int(row["profile"])]
		assert_true(St.is_s1a(g), at + " ported dom")
		for c: String in t["COMMS"]:
			_same(row["situation"][c], St.situation(g, t, c), "%s situation.%s" % [at, c])
		_same(row["medMult"], St.law_mult(g, t, "medMult"), at + " medMult")
		_same(row["coal"], LawTech.coal(g), at + " coal")
		_same(row["food"], LawTech.food(g), at + " food")
		_same(-float(row["coal"]), Turn.dom_coal(g), at + " forecast coal share")
		_same(-float(row["food"]), Turn.dom_food(g), at + " forecast food share")
		for law: String in _data["openLaws"]:
			_same(row["open"][law], Agenda.law_open(g, t, law), "%s open.%s" % [at, law])
		for key: String in row["use"]:
			var want: Variant = row["use"][key]
			var variant: Variant = key.substr(2) if key.length() > 2 else null
			_same("" if want == null else want, LawTech.use_line(g, key.substr(0, 2), variant), "%s use.%s" % [at, key])
		for law: String in _data["touchLaws"]:
			_same(row["lines"][law], LawTech.law_lines(g, law), "%s lines.%s" % [at, law])
		for id: String in _data["techs"]:
			_same(row["news"][id], LawTech.news(g, id), "%s news.%s" % [at, id])
		count += 1
	assert_eq(count, int(_data["profiles"]) * (_data["seeds"] as Array).size())
	assert_eq(_bad, [] as Array[String])


func _run(row: Dictionary) -> Dictionary:
	var input: Dictionary = RestoreVectors.project(row["before"])
	var t: Dictionary = _data["tables"]
	var action: Dictionary = row["action"]
	match str(action["kind"]):
		"enact": return Vote.enact_law(input, t, str(action["law"]))
		"repeal": return Vote.repeal_law(input, t, str(action["law"]))
		"cast_vote": return Advance.cast_vote(input, t)
	return {"_turn_port_error": "F-BAD-FIXTURE-ACTION"}


## As test_law_port.gd: a ledger delta Godot reads one bit off is compared to 1e-9.
func _pick(state: Dictionary) -> Dictionary:
	var out := {}
	var projected: Dictionary = RestoreVectors.project(state)
	for key: String in VARIANT_KEYS:
		if projected.has(key):
			out[key] = projected[key]
	for row: Dictionary in out.get("ledger", []):
		row["d"] = snappedf(float(row["d"]), 1e-9)
	return out


func test_variant_laws_match_s1() -> void:
	if _data.is_empty(): return
	var kinds := {}
	var bad: Array[String] = []
	for row: Dictionary in _data["variants"]:
		var at: String = str(row["name"])
		kinds[at.get_slice("/", 0)] = true
		var got: Dictionary = _run(row)
		if got.has("_turn_port_error"):
			bad.append("%s: %s" % [at, got["_turn_port_error"]])
		else:
			bad.append_array(TV.full_diffs(_pick(row["after"]), _pick(got), at, 8))
			var returned: Variant = got.get("council", {}).get("result") if row["action"]["kind"] == "cast_vote" else null
			_same(row["result"], returned, at + " returned value")
		if bad.size() >= 40: break
	for kind: String in ["enact", "vote", "amend", "vote-amend", "repeal"]:
		assert_true(kinds.has(kind), kind)
	assert_eq(bad, [] as Array[String], "First differences:\n" + "\n".join(bad.slice(0, 40)))
	assert_eq(_bad, [] as Array[String])


## An amendment's title names both laws (politics.ts agendaTitle).
func test_amendment_title() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	assert_eq(Vote.agenda_title(t, {"law": "child_pack", "repeal": false, "amend": "child_labor"}), "아동 노동 개정: 아동 노동(짐 꾸리기만)")
	assert_eq(Vote.agenda_title(t, {"law": "child_pack", "repeal": false}), "아동 노동(짐 꾸리기만)")


## The settle's workshop receipt (lastSettle.workshop, the train scene's 2c-2 events) is S2's own;
## S1's boards have none. It is checked here and left out of the whole-board comparison.
func _without_shop_receipt(g: Dictionary, at: String) -> Dictionary:
	var settle: Variant = g.get("lastSettle")
	if not settle is Dictionary or not (settle as Dictionary).has("workshop"):
		return g
	var shop: Variant = settle["workshop"]
	# Made at a settle of this stretch, kept through the next stretch's start until the next settle.
	assert_true(shop is Dictionary and shop.get("events") is Array and int(shop.get("seg", -1)) >= 1 and int(shop.get("seg", -1)) <= int(g["seg"]), at + " shop receipt")
	var out: Dictionary = g.duplicate(true)
	out["lastSettle"].erase("workshop")
	return out


## The pipe sequences, step after step on one board (s1/tools/lawtech_port_fixtures.ts). Their
## boards have S1's restore offers already made and no greedy workshop chief (restorationBoard):
## offers (offerRestores) and the chief (delegate.ts) are S1 domestic parts S2 has not ported.
func test_pipe_restart_matrix_settle_boundary_sequences_match_s1_whole_boards() -> void:
	assert_eq((_data["sequences"] as Array).size(), 18)
	var t: Dictionary = _data["tables"]
	for row: Dictionary in _data["sequences"]:
		var g: Dictionary = RestoreVectors.project(row["initial"])
		for step: Dictionary in row["steps"]:
			var action: Dictionary = step["action"]
			var at: String = String(row["name"]) + "/" + String(action["kind"])
			_same(RestoreVectors.project(step["before"]), _without_shop_receipt(g, at + " input"), at + " input")
			var value: Variant = null
			match String(action["kind"]):
				"start_restore": value = Research.start_restore(g, String(action["id"]), String(action["mode"]), action.get("variant"))
				"cancel_restore": Research.cancel_restore(g)
				"open_pipe_vote":
					g["council"] = {"options": [{"kind": "motion", "motion": "pipe"}], "idx": 0, "locked": false, "deals": [], "result": null}
					g["voteShift"] = []
					for comm: String in t["COMMS"]:
						(g["voteShift"] as Array).append({"comm": comm, "n": 1000, "side": "yes" if bool(action["passed"]) else "no"})
				"cast_vote":
					g = Advance.cast_vote(g, t)
					value = g["council"]["result"]
				"ratify_pipe": Pipe.ratify(g, t, bool(action["passed"]))
				"run_workshop":
					if action.has("workDebt"):
						# Debt itself is not ported: the boundary input is its remaining available work.
						var restored: Dictionary = Research.advance_restore(g, maxf(0.0, Workshop.work_power(g, t) - float(action["workDebt"])))
						if restored.has("done"):
							Workshop.after_restore(g, t, String(restored["done"]), bool(restored["finishing"]))
						value = {"used": restored["used"], "did": restored["did"]}
					else:
						var worked: Dictionary = Workshop.run(g, t)
						value = {"used": worked["used"], "did": worked["did"]}
				"advance": g = Advance.advance(g, t)
				"achieved_pool":
					# Design 10-7: the travel events that need the ratification flag, as the next stretch's
					# departure is about to draw (S1 contentPool, recorded by the generator).
					var gated: Array = []
					for ev: Dictionary in Content.content_pool(g, t):
						if (ev["trigger"] as Array).any(func(c: Dictionary) -> bool: return c.get("type") == "flag" and c.get("id") == "ev_achieved"):
							gated.append(String(ev["id"]))
					value = gated
				_: fail_test("Unknown pipe action: " + str(action))
			_same(step["result"], value, at + " returned value")
			if action["kind"] == "advance":
				for resource: String in ["coal", "food", "med"]:
					_same(step["after"][resource], g[resource], at + " first settlement " + resource)
			_same(RestoreVectors.project(step["after"]), _without_shop_receipt(g, at), at + " whole board")
			assert_true(Dom.is_store(g["dom"]), at + " store")
		if String(row["name"]).begins_with("pipe-settle/"):
			# The sequence reaches the next stretch's departure draw: a card is on the table, and a
			# passed ratification put the flagged events in the pool where a rejected one did not.
			assert_eq(g["phase"], "travel", String(row["name"]) + " reaches the next travel draw")
			assert_false((g["cards"] as Array).is_empty(), String(row["name"]) + " departure drew a card")
			var pools: Array = (row["steps"] as Array).filter(func(s: Dictionary) -> bool: return s["action"]["kind"] == "achieved_pool")
			assert_eq(pools.size(), 1, String(row["name"]) + " one pool step")
			if pools.size() == 1:
				assert_eq((pools[0]["result"] as Array).is_empty(), not String(row["name"]).contains("passed=true"), String(row["name"]) + " flagged events in the pool only after a passed vote")
			var expected_achievement: bool = bool(row["steps"][-1]["after"].get("contentFlags", {}).get("ev_achieved", false))
			var content_probe: Dictionary = g.duplicate(true)
			assert_eq(Content.holds(content_probe, t, {"type": "flag", "id": "ev_achieved", "value": true}), expected_achievement, "content reads the ratification flag after settlement")
	assert_eq(_bad, [] as Array[String])


func test_pipe_without_pending_is_readable_and_ratification_has_no_effect() -> void:
	for g: Dictionary in [{}, {"dom": null}, {"dom": {}}, {"dom": {"techs": {"e3": {"variant": "a", "pending": false}}}}]:
		var before: String = JSON.stringify(g, "", false)
		assert_null(Pipe.pending(g))
		Pipe.ratify(g, {}, true)
		Pipe.ratify(g, {}, false)
		assert_eq(JSON.stringify(g, "", false), before)


## A technology restored while the law it bends stands says so in the journal
## (S1 completeTech's lawTechNews); the situation share changes at once.
func test_restoring_a_law_technology_writes_its_news() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var g: Dictionary = RestoreVectors.project(_data["cases"][0]["state"])
	g["passed"] = {"snow_duty": 0}
	g["journal"] = []
	var d: Dictionary = g["dom"]
	d["techs"] = {"e1": {"stage": "restoring", "defect": false, "progress": 2.5, "need": 3}}
	d["restoring"] = "e1"
	for e: Dictionary in d["experts"]:
		e["skill"] = 3
	g["comms"]["front"]["base"][0] = 40.0
	var before: float = St.situation(g, t, "front")[0]
	Workshop.run(g)
	assert_eq(String(d["techs"]["e1"]["stage"]), "done")
	var lines: Array = (g["journal"] as Array).map(func(r: Dictionary) -> String: return String(r["text"]))
	assert_has(lines, "눈 녹이기 당번이(가) 바뀐다: 온기 벌 없음, 노출 벌 절반.")
	assert_gt(St.situation(g, t, "front")[0], before, "the front is warmer under 눈 녹이기 당번 at once")


## Without a dom (S1a's game, the field slice) the variants stay shut and nothing moves.
func test_no_dom_changes_nothing() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var g: Dictionary = (_data["cases"][0]["state"] as Dictionary).duplicate(true)
	g.erase("dom")
	for law: String in Vote.VARIANT_LAWS:
		assert_false(Agenda.law_open(g, t, law), law)
	assert_eq(LawTech.sit(g, "tail"), [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(Turn.dom_coal(g), 0.0)
