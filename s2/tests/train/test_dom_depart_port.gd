extends GutTest
## The domestic departure hook (S1 domestic/hooks.ts domesticDepart, knowledge.ts strikeRuns) in the
## S2 departure (turn_dom_depart.gd from turn_travel.gd depart), against S1's own departures
## (s1/tools/depart_port_fixtures.ts). A "match" row departs as S1 does, whole board (the breakdown
## roll's draw, the strike branches, the prologue deal, the stranded end); a "refuse" row is a state
## taking an S1 step S2 does not carry (pressure warning, other engines, stoker), which must come
## back as it came in with its F-NOT-PORTED reason. Design: coord/review/내정출발훅_설계_20261105.md.

const Advance = preload("res://game/train/train_advance.gd")
const Dom = preload("res://game/train/train_dom.gd")
const DomDepart = preload("res://game/train/turn/turn_dom_depart.gd")
const St = preload("res://game/train/train_state.gd")
const TV = preload("res://tests/train/train_vectors.gd")
const RestoreVectors = preload("res://tests/train/restore_vectors.gd")
const PATH: String = "res://tests/fixtures/train/depart_vectors.json"
const REFUSALS: Array[String] = ["domesticDepart: dom:pressure", "domesticDepart: anyoneDrives (c4)",
	"domesticDepart: breakdown (c1)", "domesticDepart: breakdown (c2)", "domesticStrikeRuns: stoker"]

var _data: Dictionary = {}
var _bad: Array[String] = []


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary: _data = parsed


func before_each() -> void:
	_bad = []


## Both ways, so a key only S2 has (a stray _turn_port_error) fails too.
func _same(want: Variant, got: Variant, label: String) -> void:
	var d: String = TV.diff(want, got, label)
	if d == "":
		d = TV.diff(got, want, label + " unexpected")
	if d != "" and _bad.size() < 20:
		_bad.append(d)


func _rows(prefix: String) -> Array:
	return (_data.get("rows", []) as Array).filter(func(r: Dictionary) -> bool: return String(r["name"]).begins_with(prefix))


func test_fixture_contract() -> void:
	assert_false(_data.is_empty(), "depart fixture exists and parses")
	if _data.is_empty(): return
	assert_eq(_data.get("format"), "depart-vectors-v1")
	var rows: Array = _data["rows"]
	assert_eq(rows.size(), 17 * (_data["seeds"] as Array).size())
	var refusals: Array = []
	for row: Dictionary in rows:
		if row["expect"] == "refuse":
			refusals.append(String(row["refusal"]))
	for word: String in REFUSALS:
		assert_true(refusals.has(word), "a row refused as " + word)
	for word: Variant in refusals:
		assert_true(REFUSALS.has(word), "known refusal " + str(word))
	var t: Dictionary = _data["tables"]
	assert_eq(t["LOCO_DEFAULT"], "c3")
	assert_eq(float(t["LOCO"]["c3"]["breakMult"]), 0.0, "the default engine never breaks down")


func test_every_departure_matches_s1_or_comes_back_refused_and_unchanged() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var matched := 0
	var refused := 0
	for row: Dictionary in _data["rows"]:
		var at: String = String(row["name"])
		var before: Dictionary = RestoreVectors.project(row["before"])
		assert_true(St.is_s1a(before), at + " ported board")
		var got: Dictionary = Advance.advance(before, t)
		if row["expect"] == "match":
			assert_false(got.has("_turn_port_error"), at + " " + str(got.get("_turn_port_error", "")))
			_same(RestoreVectors.project(row["after"]), got, at + " whole board")
			if got.get("dom") is Dictionary:
				assert_true(Dom.is_store(got["dom"]), at + " store")
			matched += 1
		else:
			assert_eq(got.get("_turn_port_error"), "F-NOT-PORTED: " + String(row["refusal"]), at + " refusal")
			var back: Dictionary = got.duplicate(true)
			back.erase("_turn_port_error")
			_same(before, back, at + " refused board as it came in")
			refused += 1
	assert_eq(matched, 11 * (_data["seeds"] as Array).size(), "match rows")
	assert_eq(refused, 6 * (_data["seeds"] as Array).size(), "refuse rows")
	assert_eq(_bad, [] as Array[String])


## S1 rolls the breakdown before testing its chance, so a departure that does not draw a travel
## event (a strike, the prologue deal) still moves the generator one step; one that ends stranded
## does not reach the roll.
func test_hook_draws_on_every_branch_that_reaches_the_roll() -> void:
	if _data.is_empty(): return
	for row: Dictionary in _data["rows"]:
		if row["expect"] != "match": continue
		var name: String = String(row["name"])
		var want: int = 0 if name.begins_with("engine-0") or name.begins_with("no-dom") else 1
		assert_eq(int(row["hookDraws"]), want, name + " hook draws")
	for prefix: String in ["strike/stops", "strike/ban", "prologue-deal", "substitute/strike-ban"]:
		assert_false(_rows(prefix).is_empty(), prefix + " rows")


## Old saves and S1a boards carry stores without an expert roster (TrainDom.ensure): that is S1's
## run with no dom, so the hook does not run — no draw, no stranded end — whatever the stores hold.
func test_stores_without_experts_depart_as_s1_without_dom() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var rows: Array = _rows("no-dom/")
	assert_eq(rows.size(), (_data["seeds"] as Array).size())
	for row: Dictionary in rows:
		var at: String = String(row["name"])
		var before: Dictionary = RestoreVectors.project(row["before"])
		assert_false(before.has("dom"), at + " S1 board has no dom")
		before["dom"] = Dom.empty()
		assert_false(DomDepart.on(before), at + " stores only")
		assert_true(St.is_s1a(before), at + " stores board ported")
		var got: Dictionary = Advance.advance(before, t)
		assert_false(got.has("_turn_port_error"), at)
		assert_eq(got["dom"], Dom.empty(), at + " stores untouched")
		got.erase("dom")
		_same(RestoreVectors.project(row["after"]), got, at + " whole board")
	assert_eq(_bad, [] as Array[String])


## refusal() reads the engine before the stall: an engine anyone drives passes S1's stall check, so
## an engine-0 crew on c4 is refused rather than ended; an engine id the table lacks is refused too.
func test_refusal_reads_the_engine_first() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var row: Dictionary = _rows("c3/default/")[0]
	var g: Dictionary = RestoreVectors.project(row["before"])
	assert_eq(DomDepart.refusal(g, t), "")
	for e: Dictionary in g["dom"]["experts"]:
		if e["field"] == "engine": e["skill"] = 0
	assert_eq(DomDepart.refusal(g, t), "", "engine 0 on c3 is ported (the run ends)")
	assert_false(DomDepart.depart(g.duplicate(true), t), "no one to drive")
	g["loco"] = "c4"
	assert_eq(DomDepart.refusal(g, t), "domesticDepart: anyoneDrives (c4)")
	g["loco"] = "c9"
	assert_eq(DomDepart.refusal(g, t), "domesticDepart: locomotive c9")
	g["loco"] = null
	assert_eq(DomDepart.refusal(g, t), "")
	# An empty roster (no one left) is a domestic run whose best engine hand is 0.
	g["dom"]["experts"] = []
	assert_true(DomDepart.on(g))
	assert_false(DomDepart.depart(g.duplicate(true), t))


## A substitute driver matters only where S1 calls strikeRuns: a strike with no strike ban.
func test_stoker_refusal_only_on_a_strike_without_the_ban() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var calm: Dictionary = RestoreVectors.project(_rows("substitute/calm/")[0]["before"])
	assert_eq(DomDepart.strike_refusal(calm), "domesticStrikeRuns: stoker", "the roster has a substitute")
	assert_false(Advance.advance(calm, t).has("_turn_port_error"), "not striking: S1 never asks")
	var banned: Dictionary = RestoreVectors.project(_rows("substitute/strike-ban/")[0]["before"])
	assert_false(Advance.advance(banned, t).has("_turn_port_error"), "strike ban: S1 never asks")
	var striking: Dictionary = RestoreVectors.project(_rows("substitute/strike/")[0]["before"])
	assert_eq(Advance.advance(striking, t).get("_turn_port_error"), "F-NOT-PORTED: domesticStrikeRuns: stoker")
