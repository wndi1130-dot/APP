extends "res://addons/gut/test.gd"
## train_stop.gd against the S1 answers in the train-vectors file: the work crew, the risk line
## of the stop card and setting up the stop.

const V = preload("res://tests/train/train_vectors.gd")
const St = preload("res://game/train/train_state.gd")
const Stop = preload("res://game/train/train_stop.gd")

var _t: Dictionary


func before_all() -> void:
	_t = V.tables()


func _check(bad: Array[String], label: String, want: Variant, got: Variant) -> void:
	var d := V.diff(want, got, label)
	if d != "" and bad.size() < 8:
		bad.append(d)


func test_hash_matches_s1() -> void:
	var bad: Array[String] = []
	for row: Dictionary in V.data()["scalars"]["hash"]:
		_check(bad, "hash %s" % row["s"], row["h"], Stop.hash_text(row["s"]))
	assert_eq(bad, [] as Array[String])


func test_crew_curves_match_s1() -> void:
	var bad: Array[String] = []
	var s: Dictionary = V.data()["scalars"]
	for row: Dictionary in s["crewMult"]:
		_check(bad, "crewMult %s" % row, row["m"], Stop.crew_mult(row["r"], row["curve"], _t))
	for row: Dictionary in s["crewBand"]:
		_check(bad, "crewBand %s" % row, row["band"], Stop.crew_band(row["r"], _t))
	for row: Dictionary in s["crewGain"]:
		var got := Stop.crew_gain_of(row["size"], row["cost"], _t)
		_check(bad, "crewGain %s" % row, {"gain": row["gain"], "cap": row["cap"]}, got)
		_check(bad, "crewAway %s" % row, row["away"], Stop.crew_away_of(row["size"], row["cost"], _t))
	for row: Dictionary in s["crewHaul"]:
		_check(bad, "crewHaul %s" % row, row["mult"], Stop.crew_haul_mult(row["size"], row["need"], row["haul"], _t))
	for row: Dictionary in s["threat"]:
		_check(bad, "threatStep %s" % row, row["step"], Stop.threat_step(row["t"], _t))
		for i: int in [-2, -1, 0, 1, 2].size():
			var stop := {"threat": row["t"], "noise": [-2, -1, 0, 1, 2][i]}
			_check(bad, "effThreat %s %d" % [row, i], row["eff"][i], Stop.eff_threat(stop, _t))
	assert_eq(bad, [] as Array[String])


func test_stop_risk_matches_s1() -> void:
	var bad: Array[String] = []
	var n := 0
	var levels := {}
	for point: Dictionary in V.points():
		var r: Dictionary = point["reads"]
		if not r.has("stopRisk"):
			continue
		var g: Dictionary = point["state"]
		var at := V.where(point)
		var want: Dictionary = (r["stopRisk"] as Dictionary).duplicate()
		var level: String = want["level"]
		want.erase("level")
		var got := Stop.stop_risk(g, _t)
		_check(bad, at + " stopRisk", want, got)
		_check(bad, at + " riskLevel", level, Stop.risk_level(got))
		_check(bad, at + " crewNames", r["crewNames"], Stop.crew_names(g, _t, g["stop"]["crewComm"], int(g["stop"]["crewSize"])))
		_check(bad, at + " effThreat", r["effThreat"], Stop.eff_threat(g["stop"], _t))
		levels[level] = true
		n += 1
	assert_gt(n, 100, "states with a stop")
	assert_eq(levels.size(), 4, "every promise step appears: %s" % [levels.keys()])
	assert_eq(bad, [] as Array[String])


func test_crew_preview_and_exposure_match_s1() -> void:
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		var g: Dictionary = point["state"]
		var r: Dictionary = point["reads"]
		var at := V.where(point)
		for c: String in St.comms(_t):
			_check(bad, "%s exposeMult %s" % [at, c], r["exposeMult"][c], Stop.expose_mult(g, _t, c))
		if r.has("crewPreview"):
			for c: String in r["crewPreview"]:
				_check(bad, "%s crewPreview %s" % [at, c], r["crewPreview"][c], Stop.crew_preview(g, _t, c))
	assert_eq(bad, [] as Array[String])


func test_set_stop_matches_s1() -> void:
	var bad: Array[String] = []
	var n := 0
	for point: Dictionary in V.points():
		var ch: Dictionary = point["changes"]
		if not ch.has("setStop"):
			continue
		var got := Stop.set_stop(point["state"], _t, ch["setStop"]["patch"])
		_check(bad, V.where(point) + " setStop", ch["setStop"]["stop"], got["stop"])
		n += 1
	assert_gt(n, 50)
	assert_eq(bad, [] as Array[String])
