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
const PATH: String = "res://tests/fixtures/train/lawtech_vectors.json"
## What a variant law's enactment, amendment, vote and repeal touch. S1's council
## log (councilLog, S3 연결 ports it) is not on S2's council yet, so the whole state is
## not compared.
const VARIANT_KEYS: Array[String] = ["passed", "repealedAt", "boughtBy", "onceTaken", "comms", "coal", "food",
	"med", "trust", "tension", "fear", "journal", "ledger", "cards", "guidedLeft"]

var _data: Dictionary = {}
var _bad: Array[String] = []


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary: _data = parsed


func test_x1_has_workshop_use_outside_law() -> void:
	assert_false(LawTech.LAW_ONLY_TECHS.has("x1"))
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
		var g: Dictionary = row["state"]
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
	var input: Dictionary = row["before"].duplicate(true)
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
	for key: String in VARIANT_KEYS:
		if state.has(key):
			out[key] = state[key].duplicate(true) if state[key] is Dictionary or state[key] is Array else state[key]
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
		if bad.size() >= 40: break
	for kind: String in ["enact", "vote", "amend", "vote-amend", "repeal"]:
		assert_true(kinds.has(kind), kind)
	assert_eq(bad, [] as Array[String], "First differences:\n" + "\n".join(bad.slice(0, 40)))


## An amendment's title names both laws (politics.ts agendaTitle).
func test_amendment_title() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	assert_eq(Vote.agenda_title(t, {"law": "child_pack", "repeal": false, "amend": "child_labor"}), "아동 노동 개정: 아동 노동(짐 꾸리기만)")
	assert_eq(Vote.agenda_title(t, {"law": "child_pack", "repeal": false}), "아동 노동(짐 꾸리기만)")


## A technology restored while the law it bends stands says so in the journal
## (S1 completeTech's lawTechNews); the situation share changes at once.
func test_restoring_a_law_technology_writes_its_news() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var g: Dictionary = (_data["cases"][0]["state"] as Dictionary).duplicate(true)
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
