extends "res://addons/gut/test.gd"
## Every S1 hands.ts function against the S1-generated train-vectors answers.

const V = preload("res://tests/train/train_vectors.gd")
const Hands = preload("res://game/train/train_hands.gd")
const Workshop = preload("res://game/train/train_workshop.gd")
const Dom = preload("res://game/train/train_dom.gd")
const St = preload("res://game/train/train_state.gd")
const CarPane = preload("res://game/ui/car_pane.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

var _t: Dictionary


func before_all() -> void:
	_t = V.tables()


func _check(bad: Array[String], label: String, want: Variant, got: Variant) -> void:
	var d := V.diff(want, got, label)
	if d != "" and bad.size() < 8:
		bad.append(d)


func _read_matches(key: String, read: Callable) -> void:
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		_check(bad, V.where(point) + " " + key, point["reads"][key], read.call(point["state"]))
	assert_eq(bad, [] as Array[String])


func _comm_matches(key: String, read: Callable) -> void:
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		for c: String in _t["COMMS"]:
			_check(bad, V.where(point) + " " + key + " " + c, point["reads"][key][c], read.call(point["state"], c))
	assert_eq(bad, [] as Array[String])


func test_tables_and_fixture_coverage() -> void:
	assert_eq(V.data()["format"], V.FORMAT)
	assert_eq(V.diff(_t["HANDS"], Hands.HANDS), "", "fallback is the whole S1 table")
	var missing := 0
	var injured := 0
	var short := {}
	for job: String in _t["HANDS"]["order"]:
		short[job] = 0
	for point: Dictionary in V.points():
		var g: Dictionary = point["state"]
		if g.get("hands") == null:
			missing += 1
		if float(g["injured"]) > 0.0:
			injured += 1
		for job: String in short:
			if Hands.hand_short(g, job) > 0.01:
				short[job] += 1
	assert_gt(missing, 0, "new games without settled hands")
	assert_gt(injured, 0, "injured hands are removed")
	for job: String in short:
		assert_gt(short[job], 0, "short " + job)


func test_work_share_matches_s1() -> void:
	_comm_matches("workShare", func(_g: Dictionary, c: String) -> float: return Hands.work_share(_t, c))
	var t := {"PROFILES": [{"community": "test", "age": 15}, {"community": "test", "age": 16}, {"community": "test", "age": 65}, {"community": "test", "age": 66}]}
	assert_eq(Hands.work_share(t, "test"), 0.5, "16 and 65 included")
	assert_eq(Hands.work_share(t, "absent"), 0.75, "S1 empty-profile fallback")


func test_hands_will_matches_s1() -> void:
	_comm_matches("handsWill", func(g: Dictionary, c: String) -> float: return Hands.hands_will(g, _t, c))


func test_hands_offered_matches_s1() -> void:
	_comm_matches("handsOffered", func(g: Dictionary, c: String) -> float: return Hands.hands_offered(g, _t, c))


func test_hands_now_matches_s1() -> void:
	_read_matches("handsNow", func(g: Dictionary) -> Dictionary: return Hands.hands_now(g, _t))


func test_hand_short_matches_s1() -> void:
	_read_matches("handShort", func(g: Dictionary) -> Dictionary:
		var out := {}
		for job: String in _t["HANDS"]["order"]:
			out[job] = Hands.hand_short(g, job)
		return out)


func test_hands_coal_matches_s1() -> void:
	_read_matches("handsCoal", func(g: Dictionary) -> float: return Hands.hands_coal(g, _t))


func test_hands_watch_mult_matches_s1() -> void:
	_read_matches("handsWatchMult", func(g: Dictionary) -> float: return Hands.hands_watch_mult(g, _t))


func test_hands_work_mult_matches_s1() -> void:
	_read_matches("handsWorkMult", func(g: Dictionary) -> float: return Hands.hands_work_mult(g, _t))
	_read_matches("handsWorkMult", func(g: Dictionary) -> float: return Workshop.work_power(g) / Workshop.work_power())


func test_hands_track_boost_matches_s1() -> void:
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		for row: Dictionary in point["reads"]["handsTrackBoost"]:
			var pool: Array = row["pool"].duplicate()
			_check(bad, V.where(point), row["out"], Hands.hands_track_boost(point["state"], _t, pool))
			_check(bad, "pool unchanged", row["pool"], pool)
	assert_eq(bad, [] as Array[String])
	var boundary := {"hands": {"short": {"roof": 0.5}}}
	assert_eq(Hands.hands_track_boost(boundary, _t, ["snow_drift"]), ["snow_drift"], "strictly over 0.5")


func test_settle_matches_s1_without_mutating_input() -> void:
	var bad: Array[String] = []
	for point: Dictionary in V.points():
		var g: Dictionary = point["state"].duplicate(true)
		var notes: Array = []
		var got := Hands.settle(g, _t, notes)
		var want: Dictionary = point["changes"]["handsSettle"]
		_check(bad, V.where(point) + " hands", want["hands"], got["hands"])
		_check(bad, V.where(point) + " notes", want["notes"], notes)
		_check(bad, V.where(point) + " input", point["state"], g)
	assert_eq(bad, [] as Array[String])


func test_old_saves_and_stored_share() -> void:
	var g: Dictionary = V.points()[0]["state"].duplicate(true)
	g.erase("hands")
	assert_eq(Hands.hands_coal(g, _t), 0.0)
	assert_eq(Hands.hands_watch_mult(g, _t), 1.0)
	assert_eq(Hands.hands_work_mult(g, _t), 1.0)
	assert_eq(Hands.shortage_line(g, _t), "")
	var before := St.situation(g, _t, "tail")
	g["hands"] = {"have": 0, "short": {"stove": 0.5}}
	assert_eq(St.situation(g, _t, "tail")[3], before[3], "old hands without expose")
	assert_eq(St.situation(g, _t, "tail")[0], maxf(0.0, before[0] - 5.0))
	g["hands"]["short"] = {"stoker": 0.01}
	assert_eq(Hands.shortage_line(g, _t), "", "S1 note threshold")
	for c: String in _t["COMMS"]:
		g["comms"][c]["pop"] = 0
	assert_eq(Hands.hands_coal(g, _t), 0.03, "read stored share until settle")
	var notes: Array = ["앞선 정산 줄"]
	g = Hands.settle(g, _t, notes)
	assert_eq(Hands.hands_coal(g, _t), 3.0)
	assert_eq(notes.size(), 2)
	assert_eq(notes[0], "앞선 정산 줄")


func test_workshop_run_uses_repair_share() -> void:
	var g := {"seg": 2, "dom": Dom.start(), "hands": {"short": {"repair": 1.0}}}
	g["dom"]["target"] = 10
	var result := Workshop.run(g)
	assert_eq(result["parts"], 2, "4 work becomes 2; actual run reads hands")
	assert_eq(float(g["dom"]["parts"]), 6.0)


func test_car_pane_adds_one_noninteractive_line_only_when_short() -> void:
	var g: Dictionary = V.points()[0]["state"].duplicate(true)
	g.erase("hands")
	var pane := CarPane.new()
	add_child_autofree(pane)
	pane.show_car({"comm": "tail", "name": "꼬리칸"}, g, _t)
	assert_null(pane.get_node_or_null("Parts/HandsShortage"))
	var full := {}
	for job: String in _t["HANDS"]["order"]:
		full[job] = 1.0
	g["hands"] = {"short": full}
	pane.refresh(g, _t)
	var line := pane.get_node("Parts/HandsShortage") as Label
	assert_eq(line.text, "일손 부족 · 화실·난로·보초·선로·수리 빈다.")
	assert_eq(line.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(line.autowrap_mode, TextServer.AUTOWRAP_OFF)
	assert_lte(line.get_minimum_size().x, 272.0 * UiFonts.K, "all five jobs fit one line")
	assert_gt(line.position.y, (pane.get_node("Parts/People") as Label).position.y)
	assert_lt(line.position.y + line.get_minimum_size().y, 75.0 * UiFonts.K, "above thermometer")
	g.erase("hands")
	pane.refresh(g, _t)
	assert_null(pane.get_node_or_null("Parts/HandsShortage"), "line disappears")
	await get_tree().process_frame
