extends "res://addons/gut/test.gd"
## train_turn.gd's hunger count and end checks against whole S1 settles (the train-vectors
## "settle" cases). turn.ts does not export hungerTick or checkEnd, so each case is one S1 settle
## run by advance; in an S1a settle nothing after them touches what they read or write, so their
## input is the settle's after-state with the before-state's own fields put back — save the
## food need (needTick, right after hungerTick), which takes 3 + its hits floored at 0: food left
## above 0 keeps the count's sign, food it took to 0 hides it (FOOD_NEED_HIT, those cases skipped).

const V = preload("res://tests/train/train_vectors.gd")
const Turn = preload("res://game/train/train_turn.gd")

## needs.ts food hit lines (turn_needs.gd hit), one per settle the food need came due in.
const FOOD_NEED_HIT := ["몇 상자가 사라졌다", "상자 몇 개가 또 사라졌다", "사라진 상자 목록을 들고 왔다", "줄 앞에 선 사람이 많이 가져간다"]
## Cards and journal lines only checkEnd writes.
const END_CARD_WHO := ["긴장 경고"]
const END_LINES := ["신임이 바닥났다. 3구간 안에 25까지 되돌려야 한다.", "불신임의 말이 잦아들었다."]

var _t: Dictionary


func before_all() -> void:
	_t = V.tables()


func _cases() -> Array:
	return V.data().get("settle", [])


func _where(row: Dictionary) -> String:
	return "%s step %d%s" % [row["seed"], int(row["step"]), " (varied)" if bool(row["vary"]) else ""]


func _check(bad: Array[String], label: String, want: Variant, got: Variant) -> void:
	var d := V.diff(want, got, label)
	if d != "" and bad.size() < 8:
		bad.append(d)


func _end_cards(cards: Array) -> Array:
	return cards.filter(func(k: Dictionary) -> bool:
		return k["kind"] in ["trust_crisis", "tension_crisis"] or (k["kind"] == "info" and k["who"] in END_CARD_WHO))


func _end_lines(journal: Array) -> Array:
	var ends: Array = Turn.END_TEXT.values()
	return journal.filter(func(j: Dictionary) -> bool: return j["text"] in END_LINES or j["text"] in ends)


func test_end_checks_match_s1_settles() -> void:
	var bad: Array[String] = []
	var seen := {"crisis": 0, "cleared": 0, "ended": 0, "warned": 0}
	for row: Dictionary in _cases():
		var before: Dictionary = row["before"]
		var after: Dictionary = row["after"]
		var g: Dictionary = after.duplicate(true)
		for key: String in ["trustCrisis", "tensionWarned", "tensionCrisisUsed", "phase", "end"]:
			g[key] = before[key]
		var got := Turn.check_end(g, _t)
		var at := _where(row)
		for key: String in ["trustCrisis", "tensionWarned", "end", "food"]:
			_check(bad, "%s %s" % [at, key], after[key], got[key])
		_check(bad, at + " ended", after["phase"] == "end", got["phase"] == "end")
		_check(bad, at + " cards", _end_cards(row["cards"]), got.get("cards", []))
		_check(bad, at + " journal", _end_lines(row["journal"]), got.get("journal", []))
		if before["trustCrisis"] == null and after["trustCrisis"] != null:
			seen["crisis"] += 1
		if before["trustCrisis"] != null and after["trustCrisis"] == null:
			seen["cleared"] += 1
		if after["end"] != null:
			seen["ended"] += 1
		if not bool(before["tensionWarned"]) and bool(after["tensionWarned"]):
			seen["warned"] += 1
	for key: String in seen:
		assert_gt(seen[key], 3, "settles where " + key)
	assert_eq(bad, [] as Array[String])


func test_hunger_count_matches_s1_settles() -> void:
	var bad: Array[String] = []
	var hungry := 0
	var starved := 0
	var hidden := 0
	for row: Dictionary in _cases():
		var before: Dictionary = row["before"]
		var after: Dictionary = row["after"]
		if float(after["food"]) <= 0.0 and _food_need_took(row):
			hidden += 1
			continue
		var g: Dictionary = before.duplicate(true)
		g["food"] = after["food"]
		var got := Turn.hunger_tick(g, _t)
		var at := _where(row)
		_check(bad, at + " hunger", after["hunger"], got["state"]["hunger"])
		var want_card: Array = (row["cards"] as Array).filter(func(k: Dictionary) -> bool: return k["who"] == "식량이 떨어졌다")
		_check(bad, at + " hunger card", want_card, got["state"].get("cards", []))
		for note: String in got["notes"]:
			if not note in row["notes"]:
				bad.append("%s: note %s not in S1's %s" % [at, note, row["notes"]])
		var died := (row["journal"] as Array).any(func(j: Dictionary) -> bool: return (j["text"] as String).ends_with("굶어 죽었다."))
		_check(bad, at + " starves", died, got["starves"])
		if int(after["hunger"]) > 0:
			hungry += 1
		if died:
			starved += 1
	assert_gt(hungry, 10, "settles with no food")
	assert_gt(starved, 3, "settles where somebody starves")
	assert_lt(hidden, 6, "settles whose count the food need hid")
	assert_eq(bad, [] as Array[String])


## Whether the food need came due in this settle (and so took food after the hunger count).
func _food_need_took(row: Dictionary) -> bool:
	for note: String in row["notes"]:
		for line: String in FOOD_NEED_HIT:
			if line in note:
				return true
	return false


func test_end_checks_leave_the_given_state_alone() -> void:
	var row: Dictionary = _cases()[0]
	var before := JSON.stringify(row["after"])
	Turn.check_end(row["after"], _t)
	Turn.hunger_tick(row["after"], _t)
	assert_eq(JSON.stringify(row["after"]), before)
