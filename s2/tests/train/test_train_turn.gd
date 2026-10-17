extends "res://addons/gut/test.gd"
## train_turn.gd against the S1 answers in the train-vectors file: the stretch's coal and food,
## levers, relation drift, the support band and stepping to the next stretch.

const V = preload("res://tests/train/train_vectors.gd")
const St = preload("res://game/train/train_state.gd")
const Turn = preload("res://game/train/train_turn.gd")

var _t: Dictionary


func before_all() -> void:
	_t = V.tables()


func _check(bad: Array[String], label: String, want: Variant, got: Variant) -> void:
	var d := V.diff(want, got, label)
	if d != "" and bad.size() < 8:
		bad.append(d)


func test_stretch_costs_match_s1() -> void:
	var bad: Array[String] = []
	var stalls := 0
	for point: Dictionary in V.points():
		var g: Dictionary = point["state"]
		var r: Dictionary = point["reads"]
		var at := V.where(point)
		_check(bad, at + " heatCost", r["heatCost"], Turn.heat_cost(g, _t))
		_check(bad, at + " foodCost", r["foodCost"], Turn.food_cost(g, _t))
		_check(bad, at + " forecast", r["forecast"], Turn.forecast(g, _t))
		_check(bad, at + " tailIdle", r["tailIdle"], Turn.tail_idle(g))
		_check(bad, at + " stallsEnRoute", r["stallsEnRoute"], Turn.stalls_en_route(g, _t))
		_check(bad, at + " predictStall", r["predictStall"], Turn.predict_stall(g, _t))
		_check(bad, at + " segKm", r["segKm"], Turn.seg_km_of(g, _t))
		if r["predictStall"] != null:
			stalls += 1
	assert_gt(stalls, 10, "states where the coal runs out on the way")
	assert_eq(bad, [] as Array[String])


func test_stall_km_matches_s1() -> void:
	var bad: Array[String] = []
	for row: Dictionary in V.data()["scalars"]["stallKm"]:
		_check(bad, "stallKm %s" % row, row["km"], Turn.stall_km(row["segKm"], row["coalBefore"], row["need"]))
	assert_eq(bad, [] as Array[String])


func test_support_band_and_ration_keeper_match_s1() -> void:
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		var g: Dictionary = point["state"]
		var r: Dictionary = point["reads"]
		var at := V.where(point)
		_check(bad, at + " standings", r["standings"], Turn.standings(g, _t))
		_check(bad, at + " autoLeverStatus", r["autoLeverStatus"], Turn.auto_lever_status(g, _t))
		_check(bad, at + " rationComm", r["rationComm"], Turn.ration_comm(g))
		for c: String in St.comms(_t):
			_check(bad, "%s relStage %s" % [at, c], r["relStage"][c], Turn.rel_stage(g, _t, c))
	assert_eq(bad, [] as Array[String])


func test_levers_match_s1() -> void:
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		var g: Dictionary = point["state"]
		var at := V.where(point)
		for row: Dictionary in point["changes"]["setLever"]:
			g = Turn.set_lever(g, _t, row["c"], row["which"], row["value"])
			_check(bad, "%s setLever %s" % [at, row], row["after"], g["comms"][row["c"]][row["which"]])
	assert_eq(bad, [] as Array[String])


func test_ration_keeper_moves_levers_as_s1() -> void:
	var bad: Array[String] = []
	var moved := 0
	for point: Dictionary in V.points():
		var want: Dictionary = point["changes"]["autoLevers"]
		var got := Turn.auto_levers(point["state"], _t)
		var at := V.where(point)
		_check(bad, at + " autoLevers changes", want["changes"], got["changes"])
		for c: String in St.comms(_t):
			_check(bad, "%s autoLevers heat %s" % [at, c], want["heat"][c], got["state"]["comms"][c]["heat"])
			_check(bad, "%s autoLevers ration %s" % [at, c], want["ration"][c], got["state"]["comms"][c]["ration"])
		if not (want["changes"] as Array).is_empty():
			moved += 1
	assert_gt(moved, 50)
	assert_eq(bad, [] as Array[String])


func test_drift_matches_s1() -> void:
	var bad: Array[String] = []
	var heated := 0
	for point: Dictionary in V.points():
		var want: Dictionary = point["changes"]["drift"]
		var got := Turn.drift(point["state"], _t)
		var at := V.where(point)
		for c: String in St.comms(_t):
			_check(bad, "%s drift %s" % [at, c], want["comms"][c], got["comms"][c])
		_check(bad, at + " drift journal", want["journal"], got.get("journal", []))
		if not (want["journal"] as Array).is_empty():
			heated += 1
	assert_gt(heated, 10, "states where a car's fervor climbs")
	assert_eq(bad, [] as Array[String])


func test_drift_leaves_the_given_state_alone() -> void:
	var point: Dictionary = V.points()[0]
	var before := JSON.stringify(point["state"])
	Turn.drift(point["state"], _t)
	assert_eq(JSON.stringify(point["state"]), before)


func test_next_segment_matches_s1() -> void:
	var bad: Array[String] = []
	var cases: Array = V.data()["nextSegment"]
	for row: Dictionary in cases:
		var at := "%s step %d%s" % [row["seed"], int(row["step"]), " (varied)" if bool(row["vary"]) else ""]
		if not Turn.next_segment_covers(row["before"], _t):
			bad.append(at + ": outside next_segment_covers")
			continue
		var got := Turn.next_segment(row["before"], _t)
		_check(bad, at + " next segment", row["after"], got)
		_check(bad, at + " next segment journal", row["journal"], got.get("journal", []))
		_check(bad, at + " next segment cards", row["cards"], got.get("cards", []))
	assert_gt(cases.size(), 40)
	assert_eq(bad, [] as Array[String])
