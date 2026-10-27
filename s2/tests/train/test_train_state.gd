extends "res://addons/gut/test.gd"
## train_state.gd against the S1 answers in the train-vectors file: each car's situation, head
## counts, seats-free reads, laws and the evening pot, at every sampled state.

const V = preload("res://tests/train/train_vectors.gd")
const St = preload("res://game/train/train_state.gd")

var _t: Dictionary


func before_all() -> void:
	_t = V.tables()


func _check(bad: Array[String], label: String, want: Variant, got: Variant) -> void:
	var d := V.diff(want, got, label)
	if d != "" and bad.size() < 8:
		bad.append(d)


func test_the_vectors_file_is_there() -> void:
	assert_eq(V.data().get("format"), V.FORMAT)
	assert_gt(V.points().size(), 100, "sampled states")
	assert_eq((_t.get("COMMS", []) as Array).size(), 5)


func test_sampled_states_are_the_s1a_game() -> void:
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		if not St.is_s1a(point["state"]):
			bad.append(V.where(point))
	assert_eq(bad, [] as Array[String])


func test_situation_matches_s1() -> void:
	var bad: Array[String] = []
	var n := 0
	for point: Dictionary in V.points():
		for c: String in St.comms(_t):
			_check(bad, "%s situation %s" % [V.where(point), c], point["reads"]["situation"][c], St.situation(point["state"], _t, c))
			n += 1
	assert_gt(n, 500)
	assert_eq(bad, [] as Array[String])


func test_counts_and_stages_match_s1() -> void:
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		var g: Dictionary = point["state"]
		var r: Dictionary = point["reads"]
		var at := V.where(point)
		_check(bad, at + " totalPop", r["totalPop"], St.total_pop(g, _t))
		_check(bad, at + " supportShare", r["supportShare"], St.support_share(g, _t))
		_check(bad, at + " isSessionSeg", r["isSessionSeg"], St.is_session_seg(int(g["seg"]), _t))
		for c: String in St.comms(_t):
			_check(bad, "%s stage %s" % [at, c], r["stage"][c], St.stage_of(float(g["comms"][c]["rel"]), _t))
	assert_eq(bad, [] as Array[String])


func test_laws_pot_and_engine_match_s1() -> void:
	var bad: Array[String] = []
	var with_laws := 0
	for point: Dictionary in V.points():
		var g: Dictionary = point["state"]
		var r: Dictionary = point["reads"]
		var at := V.where(point)
		if not (g["passed"] as Dictionary).is_empty():
			with_laws += 1
		_check(bad, at + " heatFloor", r["heatFloor"], St.law_floor(g, _t, "heatFloor"))
		_check(bad, at + " rationFloor", r["rationFloor"], St.law_floor(g, _t, "rationFloor"))
		_check(bad, at + " potRunning", r["potRunning"], St.pot_running(g, _t))
		_check(bad, at + " calmCoal", r["calmCoal"], St.calm_coal(g, _t))
		_check(bad, at + " calmTension", r["calmTension"], St.calm_tension(g, _t))
		_check(bad, at + " ledgerLevel", r["ledgerLevel"], St.ledger_level(g, _t))
		_check(bad, at + " locoCoal", r["locoCoal"], St.loco_coal(g, _t))
	assert_gt(with_laws, 50, "states with laws in force")
	assert_eq(bad, [] as Array[String])


func test_a_switched_on_branch_is_not_s1a() -> void:
	assert_true(St.is_s1a({"comms": {}}))
	# The stores, the workshop and research (train_dom.gd) are not the whole
	# domestic branch; a key not ported yet, like S1's people, is.
	assert_true(St.is_s1a({"dom": {"wood": 1}}))
	assert_true(St.is_s1a({"dom": {"wood": 1, "techs": {}}}))
	assert_false(St.is_s1a({"dom": {"wood": 1, "people": []}}))
	# The outside's stages and the track freeze are ported (train_climate.gd).
	assert_true(St.is_s1a({"climate": true}))
	assert_true(St.is_s1a({"climate": true, "freeze": 1}))
	assert_true(St.is_s1a({"climate": false, "dark": null}))


func test_to_rules_fits_the_train_interior_shape() -> void:
	var rules_file: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/train/train_rules.json"))
	assert_true(rules_file is Dictionary, "train_rules.json loads")
	var train_keys: Array = (rules_file["train"] as Dictionary).keys()
	var comm_keys: Array = (rules_file["comms"]["tail"] as Dictionary).keys()
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		var view := St.to_rules(point["state"], _t)
		for key: String in (view["train"] as Dictionary):
			if not train_keys.has(key) and bad.size() < 8:
				bad.append("train.%s is not a train_rules.json key" % key)
		for c: String in St.comms(_t):
			for key: String in (view["comms"][c] as Dictionary):
				if not comm_keys.has(key) and bad.size() < 8:
					bad.append("comms.%s.%s is not a train_rules.json key" % [c, key])
			_check(bad, "%s to_rules sit %s" % [V.where(point), c], point["reads"]["situation"][c], view["comms"][c]["sit"])
	assert_eq(bad, [] as Array[String])
