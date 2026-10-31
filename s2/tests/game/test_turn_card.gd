extends GutTest
## A train-turn card on paper (turn_card.gd): it shows S1's words for the card
## (turn_card_text.gd, checked against card-vectors-v1), a press answers the
## card through the train's own rule, a heavy way takes two presses, a shut way
## shakes, a kind not drawn yet hands back the rule's error, and every kind's
## longest card stays on the sheet.

const TurnCard = preload("res://game/ui/turn_card.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const PATH: String = "res://tests/fixtures/train/card_vectors.json"
## A whole train state to lay a case's part over: a press runs the whole rule.
const TRAIN: String = "res://tests/fixtures/train/train_vectors.json"
const TRAIN_POINT: int = 3

var _data: Dictionary = {}
var _whole: Dictionary = {}


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary: _data = parsed
	if not FileAccess.file_exists(TRAIN): return
	var train: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRAIN))
	if train is Dictionary: _whole = train["points"][TRAIN_POINT]["state"]


## The state of case `name` with its card on top of the pile: [g, uid]. The
## case keeps only what the card's words read, so it is laid over a whole state.
func _case(name: String) -> Array:
	for row: Dictionary in _data.get("cases", []):
		if str(row["name"]) == name:
			var g: Dictionary = _whole.duplicate(true)
			g.merge((row["state"] as Dictionary).duplicate(true), true)
			var card: Dictionary = (row["card"] as Dictionary).duplicate(true)
			g["cards"] = [card]
			return [g, int(card["uid"])]
	return [{}, -1]


func _card(g: Dictionary) -> Control:
	var c = TurnCard.new()
	add_child_autofree(c)
	c.show_card(g, _data["tables"])
	return c


func _key(c: Control, n: int) -> Button:
	return c.find_child("Key_%d" % n, true, false) as Button


func test_the_bitten_card_says_what_s1_says() -> void:
	assert_false(_data.is_empty(), "card fixture exists and parses")
	if _data.is_empty(): return
	var s: Array = _case("bitten/card-0/6/0/first")
	assert_false((s[0] as Dictionary).is_empty())
	var m: Dictionary = TurnCard.model(s[0], _data["tables"])
	assert_eq(m["title"], "물렸다")
	assert_ne(m["name"], "", "who was bitten is named")
	assert_gte(int(m["bust"]), 0, "a person brings it: an ink bust")
	assert_eq(m["count"], 1)
	var ch: Array = m["choices"]
	assert_eq(ch.size(), 3)
	assert_eq(ch.map(func(x: Dictionary) -> bool: return x["heavy"]), [false, false, true], "only leaving them is the black stone")
	assert_eq(ch[0]["effects"][0], {"icon": "med", "text": "−3", "tone": ""}, "a store is its mark and number")
	assert_eq(ch[1]["effects"], [{"icon": "", "text": "지금 드는 값 없음", "tone": "none"}], "hiding it costs nothing now")
	var tones: Array = ch[2]["effects"].map(func(e: Dictionary) -> String: return e["tone"])
	assert_true(tones.has("red"), "leaving them: a grudge in red")
	assert_eq(ch[2]["effects"][-1], {"icon": "tension", "text": "+2", "tone": ""}, "the top band's tension as its mark, in S1's order")
	assert_true(String(ch[0]["say"]).begins_with("지금 "), "what the captain says, not the label")


## A choice's extra lines (what it costs that is no effect) close its line in
## words, so a way that costs wood and coal never reads 「지금 드는 값 없음」.
func test_extra_lines_close_the_cost_line() -> void:
	var fx: Array = TurnCard.effects({"COMM_NAME": {}}, {"effs": [], "extra": ["목재 −10 · 고철 −6", "달리기 석탄 +0.4/구간"]})
	assert_eq(fx, [{"icon": "", "text": "목재 −10 · 고철 −6", "tone": ""}, {"icon": "", "text": "달리기 석탄 +0.4/구간", "tone": ""}])


func test_a_press_answers_the_card_through_the_train_rule() -> void:
	if _data.is_empty(): return
	var s: Array = _case("bitten/card-0/6/0/first")
	var g: Dictionary = s[0]
	var before: String = JSON.stringify(g)
	var c := _card(g)
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	_key(c, 1).pressed.emit()
	assert_eq(got.size(), 1)
	assert_eq((got[0]["cards"] as Array).size(), 0, "the card is answered")
	assert_false(got[0].has("_turn_port_error"), "cut is a drawn way")
	assert_eq(JSON.stringify(g), before, "the state it was given is not changed")


func test_a_heavy_way_takes_two_presses() -> void:
	if _data.is_empty(): return
	var c := _card(_case("bitten/card-0/6/0/first")[0])
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	assert_null(c.find_child("Confirm", true, false))
	_key(c, 3).pressed.emit()
	assert_eq(got.size(), 0, "the first press only arms it")
	assert_not_null(c.find_child("Confirm", true, false), "「한 번 더 눌러 확정」")
	_key(c, 3).pressed.emit()
	assert_eq(got.size(), 1, "the second press says it")
	assert_eq((got[0]["cards"] as Array).size(), 0)


func test_another_way_after_arming_answers_at_once() -> void:
	if _data.is_empty(): return
	var c := _card(_case("bitten/card-0/6/0/first")[0])
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	_key(c, 3).pressed.emit()
	_key(c, 2).pressed.emit()
	assert_eq(got.size(), 1, "a light way is said with one press")


func test_a_shut_way_shakes_and_says_why() -> void:
	if _data.is_empty(): return
	var name: String = ""
	for row: Dictionary in _data["cases"]:
		if str(row["name"]).begins_with("afford/") and str(row["name"]).ends_with("/ration_line/food"):
			name = str(row["name"])
			break
	assert_ne(name, "")
	var c := _card(_case(name)[0])
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	var off := c.find_child("Off", true, false) as Label
	assert_not_null(off)
	assert_eq(off.text.strip_edges(), "식량이 모자라다")
	_key(c, 1).pressed.emit()
	assert_eq(got.size(), 0, "a way that cannot be paid is not said")
	assert_true(UiDeny.is_shaking(c.find_child("Say_1", true, false).get_node("Pad")))


func test_a_report_has_the_papers_mark() -> void:
	if _data.is_empty(): return
	var name: String = ""
	for row: Dictionary in _data["cases"]:
		if str(row["card"]["kind"]) == "need_warn":
			name = str(row["name"])
			break
	var m: Dictionary = TurnCard.model(_case(name)[0], _data["tables"])
	assert_eq(m["name"], "")
	assert_eq(m["bust"], -1, "no one brings it: the papers mark")


func test_the_ration_cut_demand_is_drawn() -> void:
	if _data.is_empty(): return
	var c := _card(_case("ration_cut/card-0/6/first")[0])
	var m: Dictionary = TurnCard.model(c.g, c.t)
	assert_eq(m["choices"].size(), 3)
	assert_eq(String(m["choices"][0]["say"]), "꼬리칸 그릇은 그대로 둔다. 나머지 칸이 줄인다.")
	assert_ne(String(m["choices"][0]["why"]), "", "what keeping the tail's bowl costs in food")
	assert_not_null(c.find_child("Why", true, false))


func test_one_turn_left_can_still_be_deferred_without_red() -> void:
	if _data.is_empty(): return
	var s: Array = _case("late/favor/front/1/base")
	var c := _card(s[0])
	await _settled(c)
	var m: Dictionary = TurnCard.model(c.g, c.t)
	assert_eq(m["lateLine"], "미룬 지 1차례 · 남은 1차례")
	assert_eq(m["choices"][-1]["id"], "later")
	assert_eq(m["choices"][-1]["label"], "나중에 정한다")
	assert_eq(m["choices"][-1]["say"], "더 중요한 문제가 있다. 그 부탁은 나중에 듣겠다.")
	var line := c.find_child("Late", true, false) as Label
	assert_not_null(line)
	assert_eq(line.text.replace("\u2060", ""), m["lateLine"])
	var last := c.body.get_child(c.body.get_child_count() - 1) as PanelContainer
	assert_eq(last.name, "Say_3")
	var border := last.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(border.border_color, TurnCard.Paper.TRACK)
	assert_eq(line.modulate, TurnCard.Paper.INK2)
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	_key(c, 3).pressed.emit()
	assert_eq(got.size(), 1)
	assert_eq(got[0]["cards"], [])
	assert_eq(got[0]["lateCards"][0]["late"], 2)


func test_only_zero_turns_left_warns_that_deferring_picks_the_worst() -> void:
	if _data.is_empty(): return
	for n: int in [0, 1, 2]:
		var c := _card(_case("late/favor/front/%d/base" % n)[0])
		await _settled(c)
		var m: Dictionary = TurnCard.model(c.g, c.t)
		var urgent: bool = int(m["lateLeft"]) == 0
		for ch: Dictionary in m["choices"]:
			assert_eq(bool(ch["lateUrgent"]), urgent)
			var row := c.find_child("Say_%d" % int(ch["n"]), true, false) as PanelContainer
			assert_eq((row.get_theme_stylebox("panel") as StyleBoxFlat).border_color, TurnCard.RED if urgent else TurnCard.Paper.TRACK)
		var line := c.find_child("Late", true, false) as Label
		assert_eq(line != null, n > 0)
		var text: String = "" if n == 0 else ("미룬 지 2차례 · 또 미루면 가장 나쁜 쪽으로" if urgent else "미룬 지 1차례 · 남은 1차례")
		assert_eq(m["lateLine"], text)
		if line != null:
			assert_eq(line.text.replace("\u2060", ""), text)
			assert_eq(line.modulate, TurnCard.RED if urgent else TurnCard.Paper.INK2)


func test_a_kind_not_drawn_hands_back_the_rule_error() -> void:
	if _data.is_empty(): return
	var g: Dictionary = _case(str(_data["cases"][0]["name"]))[0]
	g["cards"] = [{"uid": 77, "kind": "trip_depart", "comm": "tail"}]
	var c = TurnCard.new()
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	add_child_autofree(c)
	c.show_card(g, _data["tables"])
	assert_eq(TurnCard.model(g, _data["tables"]), {})
	await get_tree().process_frame
	assert_eq(got.size(), 1)
	assert_true(String(got[0].get("_turn_port_error", "")).begins_with("F-NOT-PORTED"), "the rule's own error, as it is")


## Each kind's case with the most words: the ways stay on the sheet and the
## scene is all there to read (in print when pen would not fit).
func test_every_existing_kind_longest_card_stays_on_the_sheet() -> void:
	if _data.is_empty(): return
	var longest: Dictionary = {}
	for row: Dictionary in _data["cases"]:
		if String(row["name"]).begins_with("late/"): continue
		var v: Dictionary = row["view"]
		var words: int = String(v["body"]).length() + String(v["title"]).length()
		for ch: Dictionary in v["choices"]:
			words += String(ch.get("say", ch["label"])).length() + String(ch.get("why", "")).length() + 12
		var kind: String = str(row["card"]["kind"])
		if not longest.has(kind) or words > int(longest[kind][1]):
			longest[kind] = [str(row["name"]), words]
	for kind: String in longest:
		var c := _card(_case(String(longest[kind][0]))[0])
		await _settled(c)
		var inner: Control = c.sheet.inner
		var need: float = c.body.get_combined_minimum_size().y
		var parts: Array = []
		for p: Control in c.body.get_children():
			parts.append("%s %.0f" % [p.name, p.get_combined_minimum_size().y / UiFonts.K])
		var at: String = "%s (%s)" % [kind, longest[kind][0]]
		var overflow := c.find_child("Overflow", true, false) as ScrollContainer
		assert_null(overflow, at + ": existing cards keep their fit")
		assert_lte(need, inner.size.y + 0.5, "%s: %.0f of %.0f | %s" % [at, need, inner.size.y, ", ".join(parts)])
		var said := c.find_child("Said", true, false) as Control
		var scene := c.find_child("Scene", true, false) as Control
		assert_lte(scene.get_combined_minimum_size().y, said.size.y + 0.5, "%s: the scene is all there (%.0f in %.0f)" % [at, scene.get_combined_minimum_size().y, said.size.y])
		assert_lte(c.sheet.size.x / UiFonts.K, TurnCard.WIDE + 0.5, at + ": no wider than WIDE")


## Every late fixture row at both game widths, including repeated names and
## consecutive cards on one sheet: ways fit or advertise the remaining scroll.
func test_all_late_cases_keep_choices_visible_or_show_a_reachable_scroll_end() -> void:
	if _data.is_empty(): return
	for width: int in [1560, 1280]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(width, 720)
		add_child_autofree(viewport)
		var c := TurnCard.new()
		# The same width limit as slice_flow._show_paper, including the car pane.
		c.fit_w = float(width) / UiFonts.K - 330.0 + 44.0 - 6.0 - TurnCard.SHEET_AT.x
		viewport.add_child(c)
		var count := 0
		for row: Dictionary in _data["cases"]:
			if not String(row["name"]).begins_with("late/"): continue
			# Some fixture names repeat: measure each row, not _case's first match.
			var g: Dictionary = _whole.duplicate(true)
			g.merge((row["state"] as Dictionary).duplicate(true), true)
			g["cards"] = [row["card"].duplicate(true)]
			c.show_card(g, _data["tables"])
			await _settled(c)
			await get_tree().process_frame
			var at := "%d/%s/%d" % [width, row["name"], count]
			assert_lte(c.body.size.x, c.sheet.inner.size.x + 0.5, at + ": fixed rows also fit the paper width")
			var overflow := c.find_child("Overflow", true, false) as ScrollContainer
			var more := c.find_child("PaperMore", true, false) as Control
			if overflow == null:
				assert_lte(c.body.get_combined_minimum_size().y, c.sheet.inner.size.y + 0.5, at + ": fixed rows fit")
				assert_null(more, at + ": no whole-paper scroll cue")
				for ch: Control in c.body.get_children():
					assert_lte(ch.position.y + ch.size.y, c.sheet.inner.size.y + 1.0, at + ": " + ch.name + " stays on paper")
			else:
				assert_eq(str(c.get_meta("fit_stage")), "2c", at + ": only the last resort scrolls the paper")
				assert_gt(_fixed_rows_height(c), c.sheet.inner.size.y + 0.5, at + ": even a zero-line scene cannot fit the fixed rows")
				assert_not_null(more, at + ": the extra choices are signposted")
				if more != null: assert_true(more.visible, at + ": paper cue starts visible")
				await _check_scroll_end(c, overflow, more, c.body, at)
			var said := c.find_child("Said", true, false) as ScrollContainer
			var scene := c.find_child("Scene", true, false) as Control
			var scene_more := c.find_child("SceneMore", true, false) as Control
			if overflow == null and scene.size.y > said.size.y + 0.5:
				assert_not_null(scene_more, at + ": clipped scene is signposted")
				assert_gt(said.size.y, 0.0, at + ": scene can be read")
				if scene_more != null: assert_true(scene_more.visible, at + ": scene cue starts visible")
				await _check_scroll_end(c, said, scene_more, scene, at)
			else:
				assert_true(scene_more == null or not scene_more.visible, at + ": no unnecessary scene cue")
			var m: Dictionary = TurnCard.model(g, _data["tables"])
			var urgent: bool = int(m["late"]) > 0 and int(m["lateLeft"]) == 0
			for ch: Dictionary in m["choices"]:
				var way := c.find_child("Say_%d" % int(ch["n"]), true, false) as PanelContainer
				assert_eq(bool(ch["lateUrgent"]), urgent, at + ": warning order")
				assert_eq((way.get_theme_stylebox("panel") as StyleBoxFlat).border_color, TurnCard.RED if urgent else TurnCard.Paper.TRACK, at + ": border")
				assert_gte(way.size.y, TurnCard.SAY_H * UiFonts.K, at + ": minimum tap height preserved")
				if ch["id"] == "later":
					var quote := way.find_child("Quote", true, false) as Label
					var joiner: String = " · " if str(c.get_meta("fit_stage")) in ["2b", "2c"] else "\n"
					assert_eq(quote.text.replace("\u2060", ""), String(ch["label"]) + joiner + "「%s」" % String(ch["say"]), at + ": only the forced line break changes")
			var late := c.find_child("Late", true, false) as Label
			if late != null:
				var expected: String = ("미룬 지 %d차례 · 또 미루면 가장 나쁜 쪽으로" % int(m["late"])) if urgent else ("미룬 지 %d차례 · 남은 %d차례" % [int(m["late"]), int(m["lateLeft"])])
				assert_eq(late.text.replace("\u2060", ""), expected, at + ": late line")
				assert_eq(late.modulate, TurnCard.RED if urgent else TurnCard.Paper.INK2, at + ": late ink")
				if late.get_parent().name == "Who":
					assert_lte(late.position.x + late.size.x, (late.get_parent() as Control).size.x + 0.5, at + ": late line fits beside name")
			count += 1
		assert_eq(count, 142, "%d: every late fixture row, including duplicate names" % width)
		c.free()


## Measure title/name/late/portrait and ways without the scene; independent
## of the full-scrolling Said minimum, which includes its complete text.
func _fixed_rows_height(c: Control) -> float:
	var top := c.body.get_child(0) as HBoxContainer
	var words := top.get_child(1) as VBoxContainer
	var text_height := 0.0
	for part: Control in words.get_children():
		if part.name != "Said": text_height += part.get_combined_minimum_size().y
	var needed: float = maxf(text_height, (top.get_child(0) as Control).get_combined_minimum_size().y)
	for i: int in range(1, c.body.get_child_count()):
		needed += (c.body.get_child(i) as Control).get_combined_minimum_size().y
	return needed


func _check_scroll_end(c: Control, scroll: ScrollContainer, more: Control, content: Control, at: String) -> void:
	var last := c.body.get_child(c.body.get_child_count() - 1) as Control
	var before := last.position
	scroll.scroll_vertical = int(ceil(content.size.y))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(scroll.scroll_vertical, 0, at + ": scroll reaches more content")
	assert_lte(content.position.y + content.size.y, scroll.size.y + 1.0, at + ": final line reachable")
	if more != null:
		assert_false(more.visible, at + ": cue disappears at the bottom")
		assert_eq(more.mouse_filter, Control.MOUSE_FILTER_IGNORE, at + ": cue does not intercept taps")
	if scroll.name == "Said": assert_eq(last.position, before, at + ": scrolling the scene leaves choices still")


## A short card keeps the mockup's sheet and its pen; a long one is cut wider,
## and shows once it has settled.
func test_a_long_card_is_cut_wider_a_short_one_is_not() -> void:
	if _data.is_empty(): return
	var short := _card(_case("bitten/card-0/6/0/first")[0])
	await _settled(short)
	assert_almost_eq(short.sheet.size.x / UiFonts.K, 446.0, 0.5)
	assert_false((short.find_child("Scene", true, false) as Node).has_meta("print"), "the bitten card's scene is in pen")
	var long := _card(_case("ration_cut/card-0/6/first")[0])
	assert_eq(long.sheet.modulate.a, 0.0, "not shown before it settles")
	await _settled(long)
	assert_gt(long.sheet.size.x / UiFonts.K, 446.0)
	assert_eq(long.sheet.modulate.a, 1.0)


## Folded to the left only its edge stays in sight, and a press there opens it
## again, never a way under it; a new card comes open (결정 508).
func test_a_folded_card_leaves_its_edge_and_opens_from_it() -> void:
	if _data.is_empty(): return
	var g: Dictionary = _case("bitten/card-0/6/0/first")[0]
	var c := _card(g)
	await _settled(c)
	var got: Array = []
	var folds: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	c.fold_changed.connect(func(on: bool) -> void: folds.append(on))
	var open := c.sheet.get_node("Open") as Button
	assert_false(open.visible, "open, the ways take their presses")
	(c.sheet.get_node("Fold") as Button).pressed.emit()
	assert_true(c.folded)
	await get_tree().create_timer(TurnCard.FOLD_S + 0.1).timeout
	var edge: float = TurnCard.TAB * UiFonts.K
	assert_almost_eq(c.sheet.position.x + c.sheet.size.x, edge, 0.5, "only its edge in sight")
	assert_almost_eq(c.folded_edge(), edge, 0.5)
	assert_true(open.visible)
	assert_false(c.sheet.inner.visible, "no cut-off words on the edge")
	assert_eq(open.get_index(), c.sheet.get_child_count() - 1, "the open key lies over all else on the sheet")
	assert_eq(open.size, c.sheet.size, "over the whole edge in sight")
	open.pressed.emit()
	assert_false(c.folded)
	assert_true(c.sheet.inner.visible)
	assert_true(open.visible, "till it has lain open the paper is still the open key")
	open.pressed.emit()
	assert_eq(got.size(), 0, "a press on the edge answers nothing, nor a second tap of it")
	assert_eq(folds, [true, false])
	await get_tree().create_timer(TurnCard.FOLD_S + TurnCard.OPEN_GUARD + 0.1).timeout
	assert_false(open.visible, "lain open, the ways take their presses")
	c.set_folded(true)
	c.show_card(g, _data["tables"])
	assert_false(c.folded, "a new card comes open")
	assert_almost_eq(c.sheet.position.x, TurnCard.SHEET_AT.x * UiFonts.K, 0.5)


## A real tap on the folded edge reaches the open key, not the way under it; a
## heavy way armed before the fold comes back unarmed; a paper cut wider while
## folded stays bare on its edge.
func test_the_folded_edge_takes_a_real_tap_and_keeps_nothing_armed() -> void:
	if _data.is_empty(): return
	var c := _card(_case("bitten/card-0/6/0/first")[0])
	await _settled(c)
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	_key(c, 3).pressed.emit()
	assert_not_null(c.find_child("Confirm", true, false), "armed")
	c.set_folded(true)
	await _settled(c)
	await get_tree().create_timer(TurnCard.FOLD_S + 0.1).timeout
	assert_null(c.find_child("Confirm", true, false), "folding lets the heavy way go")
	# What a tap on the edge in sight lands on: the topmost control there, picked as the
	# GUI picks (last child first, rotation and all).
	for y_share: float in [0.1, 0.45, 0.6, 0.9]:
		var at := Vector2(TurnCard.TAB * UiFonts.K * 0.5, c.sheet.global_position.y + c.sheet.size.y * y_share)
		var hit := _top_at(c, at)
		assert_not_null(hit)
		if hit != null:
			assert_eq(String(hit.name), "Open", "a tap on the edge at %.2f lands on the open key" % y_share)
	(c.sheet.get_node("Open") as Button).pressed.emit()
	assert_false(c.folded, "a tap on the edge opens it")
	assert_eq(got.size(), 0, "and answers nothing")
	var long := _card(_case("ration_cut/card-0/6/first")[0])
	long.set_folded(true)
	await _settled(long)
	assert_gt(long.sheet.size.x / UiFonts.K, 446.0, "cut wider while folded")
	assert_false(long.sheet.inner.visible, "its edge stays bare")
	assert_true((long.sheet.get_node("Open") as Control).visible)


## The control a press at `at` (view px) goes to under `n`: children drawn later first,
## only shown ones that take the mouse, each tested in its own (rotated) frame.
func _top_at(n: Node, at: Vector2) -> Control:
	for i: int in range(n.get_child_count() - 1, -1, -1):
		var child := n.get_child(i)
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		var hit := _top_at(child, at)
		if hit != null:
			return hit
	if n is Control:
		var ctl := n as Control
		if ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			var local: Vector2 = ctl.get_global_transform().affine_inverse() * at
			if Rect2(Vector2.ZERO, ctl.size).has_point(local):
				return ctl
	return null


## Wait for the card's fit to settle (a few frames).
func _settled(c: Control) -> void:
	for i: int in 40:
		await get_tree().process_frame
		if not c.is_processing():
			return
	assert_false(c.is_processing(), "card layout settles within 40 frames")
