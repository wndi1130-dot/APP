extends "res://addons/gut/test.gd"
## Whole-board S1 comparisons and the frozen pre-2a S2 oracle below.
const V = preload("res://tests/politics/field_vectors.gd")
const Workshop = preload("res://game/train/train_workshop.gd")
const Order = preload("res://game/train/train_work_order.gd")
const Dom = preload("res://game/train/train_dom.gd")
const State = preload("res://game/train/train_state.gd")
const Settle = preload("res://game/train/turn/turn_settle.gd")
const Save = preload("res://game/politics/save_slot.gd")
const PATH = "res://tests/fixtures/train/supplies_vectors.json"
const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const RouteState = preload("res://game/train/route_state.gd")
var _flows: Array = []
var _slot: String = "user://supplies_2a_%d_" % OS.get_process_id()
var _data: Dictionary
var _t: Dictionary


class ResumeProbe extends SliceFlow:
	var replayed: bool = false
	var posted: Array = []
	func _post_shop_events(events: Array) -> void:
		posted.append_array(events)
		super._post_shop_events(events)
	func _take(g: Dictionary) -> void:
		super._take(g)
		for event: Dictionary in pending_shop_events:
			if event.get("test_old_shop", false): replayed = true


func after_each() -> void:
	for flow: Variant in _flows:
		if is_instance_valid(flow): flow.free()
	_flows.clear()
	for kind: String in ["slice", "train", "field"]:
		SliceSave.clear(_slot + kind + ".json")


func _flow(campaign: bool, resume: Dictionary = {}) -> ResumeProbe:
	var flow := ResumeProbe.new()
	flow.opts = {"save": true, "seed": 1, "cinema": false, "map_threads": false, "still": true,
		"slice_save_path": _slot + "slice.json", "train_save_path": _slot + "train.json",
		"field_save_path": _slot + "field.json", "resume": resume}
	if campaign:
		flow.opts["mode"] = "campaign"
		flow.opts["run"] = "supplies_2a_campaign"
		flow.opts["start_board"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/game/fixtures/campaign_starts.json"))[0]
	_flows.append(flow)
	add_child(flow)
	flow.set_process(false)
	return flow


func _picked(t: Dictionary) -> Dictionary:
	return SliceSave.pick(_slot + "slice.json", _slot + "train.json", t, _slot + "field.json")


## Old news on the board. By default it was shown before the save (the train stood
## after that settlement), as in play; `seen = false` leaves it unshown.
func _old_shop(flow: ResumeProbe, seen: bool = true) -> void:
	flow.train_g["supOn"] = true
	var seg: int = int(flow.train_g["seg"]) - 1
	flow.train_g["lastSettle"] = {"workshop": {"seg": seg,
		"events": [{"kind": "made", "car": "", "comm": "", "sign": 1, "size": 0.4, "day": 0, "test_old_shop": true}]}}
	if seen:
		flow.train_g["shopSeen"] = seg
	assert_true(flow._save_slice())


func test_enabled_board_one_stretch_per_settle_through_slice() -> void:
	for campaign: bool in [false, true]:
		var flow: ResumeProbe = _flow(campaign)
		var g: Dictionary = flow.train_g.duplicate(true)
		g["supOn"] = true
		g["dom"]["target"] = 0
		g["coal"] = 10000.0
		assert_true(Workshop.start(g, "bow"))
		var after: Dictionary = Settle.settle(g, flow.train_t)
		assert_eq(after["lastSettle"]["workshop"]["events"].size(), 1)
		if campaign:
			# A bare settlement leaves no valid route around it (an open visit needs a
			# stop), so carry its results onto the flow's own route board.
			var routed: Dictionary = flow.train_g.duplicate(true)
			for key: String in ["supOn", "dom", "lastSettle"]:
				routed[key] = after[key]
			assert_eq(RouteState.problem(routed, flow.train_t), "")
			after = routed
		flow._take(after)
		assert_eq(flow.pending_shop_events, after["lastSettle"]["workshop"]["events"])
		flow.pending_shop_events.clear()
		var bytes: PackedByteArray = var_to_bytes(flow.train_g)
		flow._take(flow.train_g.duplicate(true))
		assert_eq(var_to_bytes(flow.train_g), bytes)
		assert_true(flow.pending_shop_events.is_empty())
		after_each()


func test_enabled_halted_settle_still_shows_workshop_news_once() -> void:
	var flow: ResumeProbe = _flow(false)
	var g: Dictionary = flow.train_g.duplicate(true)
	g["supOn"] = true
	g["dom"]["target"] = 0
	assert_true(Workshop.start(g, "bow"))
	g["coal"] = 0.0
	var after: Dictionary = Settle.settle(g, flow.train_t)
	assert_ne(SliceFlow.train_halt_line(after), "", "this settlement halts the train")
	var made: Array = after["lastSettle"]["workshop"]["events"]
	assert_eq(made.size(), 1)
	flow._take(after)
	flow.go(flow._index_of("travel"))
	await wait_process_frames(2)
	assert_eq(flow.posted, made, "the halt screen still shows what was made")
	assert_true(flow.pending_shop_events.is_empty())
	flow.go(flow._index_of("travel"))
	await wait_process_frames(2)
	assert_eq(flow.posted, made, "once")


func test_enabled_workshop_events_not_replayed_on_resume() -> void:
	for campaign: bool in [false, true]:
		var flow: ResumeProbe = _flow(campaign)
		_old_shop(flow)
		var t: Dictionary = flow.train_t
		flow.free()
		var picked: Dictionary = _picked(t)
		assert_false(picked.is_empty())
		var resumed: ResumeProbe = _flow(campaign, picked)
		resumed._take(resumed.train_g.duplicate(true))
		assert_false(resumed.replayed)
		assert_true(resumed.pending_shop_events.is_empty())
		after_each()


func test_enabled_resume_with_unapplied_field_end_keeps_old_shop_events_out() -> void:
	for campaign: bool in [false, true]:
		var flow: ResumeProbe = _flow(campaign)
		if campaign:
			for _turn: int in range(32):
				if flow.current() == "stop_pick" or flow.campaign_error != "": break
				if flow.current() not in ["train", "travel"]: break
				if SliceFlow.papers_of(flow.train_g):
					flow._take(SliceFlow.pick_first(flow.train_g, flow.train_t))
				flow.train_on()
			assert_eq(flow.current(), "stop_pick")
			assert_eq(flow.campaign_error, "")
			flow.next()
		else:
			flow.go(flow._index_of("field"))
		assert_true(is_instance_valid(flow.field))
		if not is_instance_valid(flow.field): return
		_old_shop(flow)
		var old_train: String = FileAccess.get_file_as_string(_slot + "train.json")
		var old_slice: String = FileAccess.get_file_as_string(_slot + "slice.json")
		var t: Dictionary = flow.train_t
		flow.field.finish("departed")
		assert_eq(FieldSave.read(_slot + "field.json")["phase"], "ended")
		flow.free()
		# Keep the ended field but restore the train/meta from before its return.
		var file := FileAccess.open(_slot + "train.json", FileAccess.WRITE)
		file.store_string(old_train)
		file.close()
		file = FileAccess.open(_slot + "slice.json", FileAccess.WRITE)
		file.store_string(old_slice)
		file.close()
		var picked: Dictionary = _picked(t)
		assert_false(picked.is_empty())
		var resumed: ResumeProbe = _flow(campaign, picked)
		assert_true(resumed._returned(), "the ended field really applied on resume")
		assert_false(resumed.replayed, "old receipt was seeded before the first field return")
		assert_true(resumed.pending_shop_events.is_empty())
		after_each()


## A new run carries supplies and has seen no settlement: `shopSeen` -1 from the start.
func test_a_new_run_starts_with_supplies_on_and_no_news_seen() -> void:
	for campaign: bool in [false, true]:
		var flow: ResumeProbe = _flow(campaign)
		assert_true(bool(flow.train_g.get("supOn", false)), "campaign %s" % campaign)
		assert_eq(int(flow.train_g.get("shopSeen", -9)), -1)
		after_each()


## Left before the train stood after a settlement: the resumed run shows that
## settlement's news once, writes it seen at once, and a second resume shows none.
func test_unseen_workshop_news_shows_once_after_resume() -> void:
	for campaign: bool in [false, true]:
		var flow: ResumeProbe = _flow(campaign)
		_old_shop(flow, false)
		var t: Dictionary = flow.train_t
		var made: Array = flow.train_g["lastSettle"]["workshop"]["events"].duplicate(true)
		var seg: int = int(flow.train_g["lastSettle"]["workshop"]["seg"])
		flow.free()
		var resumed: ResumeProbe = _flow(campaign, _picked(t))
		var waiting: Array = resumed.pending_shop_events.duplicate(true)
		assert_eq(resumed.posted + waiting, made, "campaign %s: shown as the train stands, or waiting for it" % campaign)
		if not waiting.is_empty():
			resumed._show_shop_news(waiting)
			resumed.pending_shop_events = []
		assert_eq(resumed.posted, made, "shown once")
		assert_eq(int(resumed.train_g["shopSeen"]), seg)
		var saved: Dictionary = _picked(t)
		assert_eq(int(saved["g"].get("shopSeen", -9)), seg, "written seen at once")
		resumed.free()
		var again: ResumeProbe = _flow(campaign, saved)
		assert_true(again.pending_shop_events.is_empty() and again.posted.is_empty(), "a second resume shows none")
		after_each()


## A run saved before `shopSeen` (2b and earlier) reads its last settlement as seen.
func test_a_save_without_shop_seen_keeps_the_old_reading() -> void:
	var flow: ResumeProbe = _flow(false)
	_old_shop(flow, false)
	flow.train_g.erase("shopSeen")
	assert_true(flow._save_slice())
	var t: Dictionary = flow.train_t
	flow.free()
	var picked: Dictionary = _picked(t)
	assert_false(picked["g"].has("shopSeen"), "the save carries no shopSeen")
	var resumed: ResumeProbe = _flow(false, picked)
	assert_true(resumed.pending_shop_events.is_empty() and resumed.posted.is_empty(), "nothing shown again")
	# The train standing again writes that last settlement as the one seen.
	if resumed.train_g.has("shopSeen"):
		assert_eq(int(resumed.train_g["shopSeen"]), int(picked["g"]["lastSettle"]["workshop"]["seg"]))


## `shopSeen` stands beside the board, not in its dom: a board carrying it is still an
## S2 board (State.is_s1a, Dom.is_store), saves and reads, and its workshop still works.
func test_shop_seen_keeps_the_board_an_s2_board() -> void:
	var flow: ResumeProbe = _flow(false)
	var g: Dictionary = flow.train_g.duplicate(true)
	g["shopSeen"] = 3
	assert_true(State.is_s1a(g))
	assert_true(Dom.is_store(g["dom"]))
	assert_null(Save.shape_problem(g, flow.train_t))
	for bad: Variant in [-2, 1.5, "3", true]:
		var odd: Dictionary = g.duplicate(true)
		odd["shopSeen"] = bad
		assert_not_null(Save.shape_problem(odd, flow.train_t), "shopSeen %s" % str(bad))
	g["dom"]["target"] = 0
	g["coal"] = 10000.0
	assert_true(Workshop.start(g, "bow"))
	var after: Dictionary = Settle.settle(g, flow.train_t)
	assert_eq(after["lastSettle"]["workshop"]["events"].size(), 1, "the workshop still works its stretch")
	assert_eq(int(after["shopSeen"]), 3, "the settlement leaves it as it was")
	flow._take(after)
	assert_true(flow._save_slice())
	var t: Dictionary = flow.train_t
	flow.free()
	var resumed: ResumeProbe = _flow(false, _picked(t))
	assert_true(State.is_s1a(resumed.train_g), "still an S2 board after the resume")


func before_all() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_t = _data["tables"]
	assert_true(_data.has("s2DomOmit"), "lead must regenerate PR 2a fixtures")
	for group: String in ["work_order", "workshop_settles"]:
		assert_false(_data["groups"].get(group, []).is_empty(), group + " must exist")


func _convert(g: Dictionary) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	if out.get("dom") is Dictionary:
		for key: String in _data.get("s2DomOmit", []):
			out["dom"].erase(key)
	return out


## S1 completeRestore also writes 「…을(를) 복원했다.」 to the journal. S2 has never ported
## that line (nor its stats or the m4 card), on any board, so 2a leaves it out: porting it
## would change the supplies-off board. Only that line is dropped; other journal lines compare.
func _drop_s1_restore_line(g: Dictionary) -> Dictionary:
	if not g.get("journal") is Array:
		return g
	var line := RegEx.create_from_string("^[^:]+: .+을\\(를\\) (결함판으로 )?복원했다\\.")
	var kept: Array = []
	for row: Variant in g["journal"]:
		if row is Dictionary and line.search(String(row.get("text", ""))) != null:
			continue
		kept.append(row)
	g["journal"] = kept
	return g


func _same(want: Variant, got: Variant, label: String) -> void:
	var compared: Variant = got
	if want is Dictionary and got is Dictionary and want.has("comms"):
		compared = got.duplicate(true)
		if not want.has("contentFlags") and compared.get("contentFlags") is Dictionary and compared["contentFlags"].is_empty():
			compared.erase("contentFlags")
		if not want.has("wounds") and compared.get("wounds") is Array and compared["wounds"].is_empty():
			compared.erase("wounds")
	assert_eq(V.diff(want, compared, label), "", label)


func _board() -> Dictionary:
	var g: Dictionary = _data["groups"]["settles"][0]["before"].duplicate(true)
	g["dom"] = Dom.start()
	return g


func test_s1_work_order_whole_board_vectors() -> void:
	for row: Dictionary in _data["groups"].get("work_order", []):
		var g: Dictionary = _convert(row["before"])
		assert_true(Dom.is_store(g["dom"]), row["name"])
		var result: Dictionary = Workshop.run(g, _t)
		_same(row["value"], {"used": result["used"], "did": result["did"]}, row["name"])
		_same(_drop_s1_restore_line(_convert(row["after"])), _convert(g), row["name"] + " whole board")


func test_s1_workshop_settles_whole_board_vectors() -> void:
	for row: Dictionary in _data["groups"].get("workshop_settles", []):
		var g: Dictionary = _convert(row["before"])
		assert_true(Dom.is_store(g["dom"]), row["name"])
		var result: Dictionary = Workshop.settle_stretch(g, _t)
		assert_true(result.get("ran", false))
		_same(row["value"], {"used": result["used"], "did": result["did"], "starved": result["starved"]}, row["name"])
		_same(_convert(row["after"]), _convert(g), row["name"] + " whole board")


func test_enabled_settle_runs_one_stretch_after_use_before_leak() -> void:
	var g: Dictionary = _board()
	g["dom"]["parts"] = 0
	g["dom"]["target"] = Workshop.TARGET_MAX
	g["dom"]["scrap"] = 100.0
	g["dom"]["wood"] = 100.0
	# One stretch's parts on this board (its craftsman and hands set the work), and
	# proof that a second stretch would show in the count.
	var one: Dictionary = g.duplicate(true)
	Workshop.settle_stretch(one, _t)
	var per_stretch: int = int(one["dom"]["parts"])
	Workshop.settle_stretch(one, _t)
	assert_gt(per_stretch, 0)
	assert_gt(int(one["dom"]["parts"]), per_stretch, "a second stretch would add parts")
	var before: String = JSON.stringify(g)
	var after: Dictionary = Settle.settle(g, _t)
	assert_eq(JSON.stringify(g), before, "settle preserves input")
	assert_true(after["lastSettle"].has("workshop"))
	assert_eq(after["lastSettle"]["workshop"]["seg"], int(g["seg"]))
	assert_eq(int(after["dom"]["parts"]), per_stretch, "one stretch only")
	assert_eq(after["lastSettle"]["notes"].count("공방: 부품 %d." % per_stretch), 1, "S1 hooks.ts note")
	# Check the placement as well as the observable one-stretch receipt.
	var source: String = FileAccess.get_file_as_string("res://game/train/turn/turn_settle.gd")
	assert_lt(source.find("Supplies.use(g, t)"), source.find("TrainWorkshop.settle_stretch(g, t)"))
	assert_lt(source.find("TrainWorkshop.settle_stretch(g, t)"), source.find("hub_leak_tick(g, t, notes)"))


func test_enabled_settle_without_dom_keeps_dom_absent() -> void:
	var g: Dictionary = _board()
	g.erase("dom")
	var bytes: PackedByteArray = var_to_bytes(g)
	assert_eq(Workshop.settle_stretch(g, _t), {})
	assert_eq(var_to_bytes(g), bytes)
	var after: Dictionary = Settle.settle(g, _t)
	assert_false(after.has("dom"))
	assert_false(after["lastSettle"].has("workshop"))
	for bad: Variant in [null, {"unknown": 1}, {"order": ["parts", "parts"]}]:
		g["dom"] = bad
		bytes = var_to_bytes(g)
		assert_eq(Workshop.settle_stretch(g, _t), {})
		assert_eq(var_to_bytes(g), bytes, "reject before ensure")


func test_old_stretch_entry_is_noop_on_enabled_board() -> void:
	var g: Dictionary = _board()
	var bytes: PackedByteArray = var_to_bytes(g)
	assert_eq(Workshop.stretch(g), {})
	assert_eq(var_to_bytes(g), bytes)
	g.erase("dom")
	assert_eq(Workshop.stretch(g), {})
	assert_false(g.has("dom"))


func test_work_order_repairs_missing_empty_and_unlocked_sup() -> void:
	for order: Variant in [null, [], ["modify"], ["restore", "sup"]]:
		var g := {"dom": {"techs": {}}}
		if order != null: g["dom"]["order"] = order
		var bytes: PackedByteArray = var_to_bytes(g)
		var result: Array[String] = Order.normalized(g)
		for task: String in Order.DEFAULT: assert_true(result.has(task))
		assert_eq(var_to_bytes(g), bytes, "read never writes order")
		for stage: String in ["done", "defective"]:
			g["dom"]["techs"] = {"w6": {"stage": stage}}
			assert_eq(Order.normalized(g).count("sup"), 1)
	assert_eq(Order.normalized({"dom": {"order": ["modify"]}}), Order.DEFAULT)
	for bad: Variant in [null, {}, "parts", [1], ["unknown"], ["parts", "parts"]]:
		assert_false(Order.is_order(bad))
	assert_true(Order.is_order([]))


func test_work_order_keeps_user_order_and_visits_new_sup_once() -> void:
	var g: Dictionary = _board()
	g["dom"]["order"] = ["restore", "parts", "modify"]
	g["dom"]["target"] = 0
	g["dom"]["scrap"] = 0
	g["dom"]["restoring"] = "w6"
	g["dom"]["techs"] = {"w6": {"stage": "restoring", "defect": false, "progress": 0.0, "need": 1.0}}
	var before: Array = g["dom"]["order"].duplicate()
	var result: Dictionary = Workshop.run(g, _t)
	assert_eq(result["used"], 1.0)
	assert_eq(result["did"].count("생활 공방 복원"), 1)
	assert_eq(Order.normalized(g), ["restore", "parts", "modify", "sup"] as Array[String])
	# S1 completeRestore: w6 done on a supplies run puts sup at the end of the stored order, once.
	assert_eq(g["dom"]["order"], before + ["sup"])
	Workshop.run(g, _t)
	assert_eq(g["dom"]["order"].count("sup"), 1, "once")
	assert_false(g["dom"].has("supWork"), "no scrap means no supplies work was spent")


func test_enabled_dom_with_order_stays_s1a() -> void:
	var g: Dictionary = _board()
	g["dom"]["order"] = ["sup", "modify", "restore", "parts"]
	assert_true(Dom.is_store(g["dom"]))
	assert_true(State.is_s1a(g))
	g["dom"]["order"] = ["sup", "sup"]
	assert_false(Dom.is_store(g["dom"]))


func test_supplies_off_keeps_legacy_dom_state_rng_cards() -> void:
	var old_shop := GDScript.new()
	old_shop.source_code = LEGACY_WORKSHOP_SOURCE
	assert_eq(old_shop.reload(), OK)
	var old_settle := GDScript.new()
	old_settle.source_code = LEGACY_SETTLE_SOURCE
	assert_eq(old_settle.reload(), OK)
	for flag: Variant in [null, false]:
		for mode: String in ["parts", "making", "zero", "starved", "no-dom"]:
			var actual: Dictionary = _board()
			actual.erase("supOn")
			if flag != null: actual["supOn"] = flag
			actual["dom"]["parts"] = 0
			if mode == "making":
				actual["dom"]["target"] = 0
				assert_true(Workshop.start(actual, "bow"))
			if mode == "zero": actual["dom"]["scrap"] = 0
			if mode == "starved":
				actual["dom"]["scrap"] = 0
				actual["dom"]["techs"] = {"w2": {"stage": "done", "defect": false, "variant": "a", "progress": 0.0, "need": 0.0}}
				actual["dom"]["experts"] = [{"name": "공방장", "field": "craft", "comm": "front", "skill": 2}]
			if mode == "no-dom": actual.erase("dom")
			var expected: Dictionary = actual.duplicate(true)
			var untouched: PackedByteArray = var_to_bytes(actual)
			assert_eq(Workshop.settle_stretch(actual, _t), {})
			assert_eq(var_to_bytes(actual), untouched)
			for stretch: int in range(3):
				assert_eq(var_to_bytes(Workshop.stretch(actual)), var_to_bytes(old_shop.stretch(expected)))
				assert_eq(var_to_bytes(actual), var_to_bytes(expected), "whole board including RNG/cards")
				actual = Settle.settle(actual, _t)
				expected = old_settle.settle(expected, _t)
				assert_eq(var_to_bytes(actual), var_to_bytes(expected), "pre-2a settlement baseline")
				assert_eq(JSON.stringify(Save.slot_board(actual), "", false), JSON.stringify(Save.slot_board(expected), "", false), "exact save bytes")
				assert_false(actual["lastSettle"].has("workshop"))


# Frozen from 013e5f2e; never reconstructed from the implementation under test.
const LEGACY_WORKSHOP_SOURCE = """
extends RefCounted
## The train's workshop (decision 426 PR 3): it makes parts up to a target and
## one thing on its line at a time from the stores (train_dom.gd), a stretch's
## work each time the train leaves a stop. S1's workshop (s1/src/game/domestic/
## workshop.ts runWorkshop) with its numbers (domestic/data.ts D); what S2 does
## not have yet (the craftsman's skill, the workshop car's place, the W1
## technique) stands as a constant until it comes over.
##
## The three things to make are decision 070's (decisions.md 「공방 '만들기'는
## 셋부터다」): the hunting bow and the crowbar go to the armory as the field
## carries weapons, the long coat to the wardrobe. What they cost and how long
## they take are new values (the PR's table). What they do is the field's: the
## train only holds them.
##
## The fourth is the remade core (decision 474 S3: a thing that holds progress
## back has three ways or more to get it). A tier-3 restoration takes a core;
## the field has the rare store and the stopped machines (core_scenes.gd), and
## the workshop can remake one from parts and scrap, slow but sure. It goes to
## the stores' cores, where the field's cores go (train_dom.gd take_extras).
##
## Decision 449 adds W2's rounds/arrows and W4's lures to the stores.
## Their costs, work and counts are new values (decision 442, the PR's table).
## Decision 486 adds X1's sled/stretcher and X4's cart/long sled/runners,
## with the shared two-sled limit. These recipes stop at the train's stores.
##
## The work is shared: parts, the making line, restoration, then refits.
## Making a thing slows a refit (decision 070); the order is fixed in S2.
##
## A stretch (`stretch`) is S1 domesticSettle's order: the running technologies
## take their upkeep from the stores first (payUpkeep), then the workshop works
## (`run`, S1 runWorkshop), then furnishing's comparison/piano tick. One the stores cannot keep runs at half that
## stretch (train_research.gd pay_upkeep, mult). S1's 「부품이 모자란다」 card is
## not here yet: S2 runs on, as that card's 「그냥 달린다」.

const TrainDom = preload(\"res://game/train/train_dom.gd\")
const TrainHands = preload(\"res://game/train/train_hands.gd\")
const TrainResearch = preload(\"res://game/train/train_research.gd\")
const TrainLawTech = preload(\"res://game/train/train_lawtech.gd\")
const TrainMods = preload(\"res://game/train/train_mods.gd\")

## S1 D.work, D.workSkill[2] (숙련), ZONE_WORK.front, W1 off: a stretch's work.
const WORK: float = 4.0
const SKILL: float = 1.0
const ZONE: float = 1.0
## S1 D.partWork, D.partScrap, D.partWood: one part.
const PART_WORK: float = 1.0
const PART_SCRAP: float = 2.0
const PART_WOOD: float = 1.0
## S1 D.target0, D.targetMax: how many parts the workshop keeps.
const TARGET0: int = 5
const TARGET_MAX: int = 10
## How well the train's workshop makes a weapon (weapons.gd QUALITY).
const QUALITY: String = \"usable\"
## The stores' names on the screen.
const STORE_NAME: Dictionary = {\"scrap\": \"고철\", \"wood\": \"목재\", \"parts\": \"부품\", \"cloth\": \"천\"}
## Decision 070's three and the remade core: name, what they cost, the work
## they take, where they go. The core's 8 is two stretches of the starting
## workshop: the longest thing on the line, yet the line takes its work before
## restoration does (`run`), so not three stretches of a tier-3 one's 12.
const RECIPES: Dictionary = {
	\"bow\": {\"name\": \"사냥 활\", \"cost\": {\"wood\": 4, \"scrap\": 1}, \"work\": 3.0, \"to\": \"armory\"},
	\"crowbar\": {\"name\": \"쇠지렛대\", \"cost\": {\"scrap\": 4}, \"work\": 2.0, \"to\": \"armory\"},
	\"coat_long\": {\"name\": \"두꺼운 겉옷\", \"cost\": {\"cloth\": 4}, \"work\": 3.0, \"to\": \"wardrobe\"},
	\"core_remake\": {\"name\": \"재생 코어\", \"cost\": {\"parts\": 6, \"scrap\": 8}, \"work\": 8.0, \"to\": \"cores\"},
	\"rounds\": {\"name\": \"권총탄 한 줌\", \"cost\": {\"scrap\": 2}, \"work\": 1.0, \"to\": \"ammo_pistol\", \"n\": 6, \"needs\": {\"tech\": \"w2\", \"variant\": \"a\"}},
	\"arrows\": {\"name\": \"화살 묶음\", \"cost\": {\"wood\": 2}, \"work\": 1.0, \"to\": \"ammo_craft\", \"n\": 3, \"needs\": {\"tech\": \"w2\", \"variant\": \"b\"}},
	\"lure\": {\"name\": \"태엽 미끼\", \"cost\": {\"parts\": 1}, \"work\": 1.0, \"to\": \"lures\", \"n\": 1, \"needs\": {\"tech\": \"w4\"}},
	\"sled\": {\"name\": \"썰매\", \"cost\": {\"wood\": 2, \"scrap\": 1}, \"work\": 1.0, \"to\": \"sleds\", \"n\": 1, \"needs\": {\"tech\": \"x1\"}},
	\"stretcher\": {\"name\": \"들것\", \"cost\": {\"wood\": 2, \"cloth\": 1}, \"work\": 1.0, \"to\": \"stretchers\", \"n\": 1, \"needs\": {\"tech\": \"x1\"}},
	\"cart\": {\"name\": \"손수레\", \"cost\": {\"wood\": 3, \"scrap\": 2, \"parts\": 1}, \"work\": 2.0, \"to\": \"carts\", \"n\": 1, \"needs\": {\"tech\": \"x4\"}},
	\"long_sled\": {\"name\": \"긴 썰매\", \"cost\": {\"wood\": 4, \"scrap\": 1}, \"work\": 2.0, \"to\": \"long_sleds\", \"n\": 1, \"needs\": {\"tech\": \"x4\", \"complete\": true}},
	\"runner\": {\"name\": \"쇠 날\", \"cost\": {\"scrap\": 2}, \"work\": 1.0, \"to\": \"runners\", \"n\": 1, \"needs\": {\"tech\": \"x4\", \"complete\": true}},
}
const ORDER: Array[String] = [\"bow\", \"crowbar\", \"coat_long\", \"core_remake\", \"rounds\", \"arrows\", \"lure\", \"sled\", \"stretcher\", \"cart\", \"long_sled\", \"runner\"]


## Decision 446: show only recipes the train can use now, in their usual order.
static func shown(g: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in ORDER:
		var needs: Dictionary = RECIPES[id].get(\"needs\", {})
		if needs.is_empty():
			out.append(id)
			continue
		var tech: String = String(needs[\"tech\"])
		if bool(needs.get(\"complete\", false)) and g.get(\"dom\", {}).get(\"techs\", {}).get(tech, {}).get(\"stage\") != \"done\":
			continue
		var effect: float = TrainLawTech.variant_mult(g, tech, String(needs[\"variant\"])) if needs.has(\"variant\") else TrainResearch.mult(g, {}, tech)
		if effect > 0.0:
			out.append(id)
	return out


## A stretch's work.
static func work_power(g: Dictionary = {}, t: Dictionary = {}) -> float:
	return TrainResearch.work_power(g, t)


## How many parts the workshop keeps.
static func target(g: Dictionary) -> int:
	return int((g[\"dom\"] as Dictionary).get(\"target\", TARGET0))


static func set_target(g: Dictionary, n: int) -> void:
	TrainDom.ensure(g)
	g[\"dom\"][\"target\"] = clampi(n, 0, TARGET_MAX)


## What is on the line: {id, progress, need, paid}, or null.
static func line(g: Dictionary) -> Variant:
	return (g[\"dom\"] as Dictionary).get(\"make\")


## Why `id` cannot go on the line now (\"\" when it can): another thing on it,
## or the store it lacks most and by how much (「고철 2 모자람」).
static func why_not(g: Dictionary, id: String) -> String:
	if not RECIPES.has(id):
		return \"만들 수 없다\"
	if not shown(g).has(id):
		return \"아직 만들 줄 모른다\"
	var dom: Dictionary = g.get(\"dom\", {})
	if dom.get(\"make\") != null:
		return \"다른 것을 만드는 중\"
	var sleds: float = float(dom.get(\"sleds\", 0)) + float(dom.get(\"long_sleds\", 0))
	if id in [\"sled\", \"long_sled\"] and sleds >= 2.0:
		return \"썰매 자리는 둘까지\"
	if id in [\"stretcher\", \"cart\"] and float(dom.get(RECIPES[id][\"to\"], 0)) >= 1.0:
		return \"%s 자리는 하나까지\" % String(RECIPES[id][\"name\"])
	if id == \"runner\" and float(dom.get(\"runners\", 0)) >= sleds:
		return \"쇠 날은 썰매·긴 썰매마다 하나\"
	var cost: Dictionary = RECIPES[id][\"cost\"]
	for key: String in cost:
		var short: float = float(cost[key]) - float(dom.get(key, 0))
		if short > 0.0:
			return \"%s %s 모자람\" % [STORE_NAME.get(key, key), _num(short)]
	return \"\"


## Put `id` on the line: its stores are paid now. False when it cannot.
static func start(g: Dictionary, id: String) -> bool:
	TrainDom.ensure(g)
	if why_not(g, id) != \"\":
		return false
	var dom: Dictionary = g[\"dom\"]
	var cost: Dictionary = RECIPES[id][\"cost\"]
	var paid := {}
	for key: String in cost:
		dom[key] = float(dom.get(key, 0)) - float(cost[key])
		paid[key] = float(cost[key])
	dom[\"make\"] = {\"id\": id, \"progress\": 0.0, \"need\": float(RECIPES[id][\"work\"]), \"paid\": paid}
	return true


## Take the line back while the workshop has not touched it: what was paid
## comes back whole (S1 cancelOpen). False once work has gone into it.
static func cancel(g: Dictionary) -> bool:
	var dom: Dictionary = g.get(\"dom\", {})
	var m: Variant = dom.get(\"make\")
	if not m is Dictionary or float(m[\"progress\"]) > 0.0:
		return false
	var paid: Dictionary = m[\"paid\"]
	for key: String in paid:
		dom[key] = float(dom.get(key, 0)) + float(paid[key])
	dom[\"make\"] = null
	return true


## A stretch leaving a stop: the upkeep, then the work. `run`'s answer with
## \"starved\", the running technologies whose upkeep the stores could not pay.
static func stretch(g: Dictionary) -> Dictionary:
	TrainDom.ensure(g)
	var starved: Array[String] = TrainResearch.pay_upkeep(g)
	var out: Dictionary = run(g)
	TrainLawTech.furnish_tick(g)
	out[\"starved\"] = starved
	return out


## A stretch of work (the train leaving a stop): parts up to the target while
## the stores last, then the line. {\"parts\": made, \"made\": [ids], \"events\": [...]}
## — the events in the train scene's form (train_scene post_event).
static func run(g: Dictionary) -> Dictionary:
	TrainDom.ensure(g)
	var dom: Dictionary = g[\"dom\"]
	var w: float = work_power(g)
	var initial_work: float = w
	var did: Array[String] = []
	var parts_made: int = 0
	var made: Array[String] = []
	var events: Array = []
	var want: int = target(g)
	while w > 0.0 and float(dom.get(\"parts\", 0)) < float(want) \\
			and float(dom.get(\"scrap\", 0)) >= PART_SCRAP and float(dom.get(\"wood\", 0)) >= PART_WOOD:
		var done_part: float = float(dom.get(\"partWork\", 0.0))
		var spend: float = minf(w, PART_WORK - done_part)
		done_part += spend
		w -= spend
		if done_part >= PART_WORK - 1e-9:
			done_part = 0.0
			dom[\"scrap\"] = float(dom[\"scrap\"]) - PART_SCRAP
			dom[\"wood\"] = float(dom[\"wood\"]) - PART_WOOD
			dom[\"parts\"] = float(dom.get(\"parts\", 0)) + 1.0
			parts_made += 1
		dom[\"partWork\"] = done_part
	if parts_made > 0:
		did.append(\"부품 %d\" % parts_made)
	var m: Variant = dom.get(\"make\")
	if w > 0.0 and m is Dictionary:
		var spend_line: float = minf(w, float(m[\"need\"]) - float(m[\"progress\"]))
		m[\"progress\"] = float(m[\"progress\"]) + spend_line
		w -= spend_line
		if float(m[\"progress\"]) >= float(m[\"need\"]) - 1e-9:
			var id: String = String(m[\"id\"])
			_deliver(dom, id)
			dom[\"make\"] = null
			made.append(id)
			# No workshop car on S2's train yet: the train as a whole made it.
			events.append({\"kind\": \"made\", \"car\": \"\", \"comm\": \"\", \"sign\": 1, \"size\": 0.4, \"day\": int(g.get(\"seg\", 0))})
	# Preserve the existing making line immediately after parts. Restoration
	# receives the remaining work (S1 parts -> restore when no making is queued).
	var restored: Dictionary = TrainResearch.advance_restore(g, w)
	w -= float(restored[\"used\"])
	did.append_array(restored[\"did\"])
	# A standing law the restored technology bends says so (S1 completeTech's lawTechNews).
	if restored.get(\"done\") != null:
		for news: String in TrainLawTech.news(g, String(restored[\"done\"])):
			if not g.get(\"journal\") is Array:
				g[\"journal\"] = []
			g[\"journal\"].append({\"seg\": int(g.get(\"seg\", 0)), \"text\": news, \"tone\": \"good\"})
	var modified: Dictionary = TrainMods.advance_job(g, w)
	w -= float(modified[\"used\"])
	did.append_array(modified[\"did\"])
	events.append_array(modified[\"events\"])
	return {\"parts\": parts_made, \"made\": made, \"events\": events, \"used\": initial_work - w, \"did\": did}


## What the workshop is doing for the screen: the line's thing and how far
## along (0..1), or parts, or nothing; and the share of a stretch it waits.
static func now(g: Dictionary) -> Dictionary:
	var dom: Dictionary = g.get(\"dom\", {})
	var m: Variant = dom.get(\"make\")
	if m is Dictionary:
		return {\"id\": String(m[\"id\"]), \"share\": clampf(float(m[\"progress\"]) / maxf(float(m[\"need\"]), 1e-9), 0.0, 1.0),
			\"can_cancel\": float(m[\"progress\"]) <= 0.0}
	return {\"id\": \"\", \"share\": 0.0, \"can_cancel\": false}


static func _deliver(dom: Dictionary, id: String) -> void:
	var recipe: Dictionary = RECIPES[id]
	var to: String = String(recipe[\"to\"])
	if TrainDom.AMOUNTS.has(to):
		dom[to] = float(dom.get(to, 0)) + float(recipe.get(\"n\", 1))
	elif to == \"wardrobe\":
		if not dom.get(\"wardrobe\") is Array:
			dom[\"wardrobe\"] = []
		(dom[\"wardrobe\"] as Array).append({\"id\": id, \"condition\": 1.0})
	else:
		if not dom.get(\"armory\") is Array:
			dom[\"armory\"] = []
		(dom[\"armory\"] as Array).append({\"id\": id, \"quality\": QUALITY, \"condition\": 1.0})


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else \"%.1f\" % v
"""

# Frozen from 013e5f2e; never reconstructed from the implementation under test.
const LEGACY_SETTLE_SOURCE = """
extends RefCounted
const Late = preload(\"res://game/train/turn/turn_late.gd\")
const C = preload(\"res://game/train/turn/turn_common.gd\")
const St = preload(\"res://game/train/train_state.gd\")
const Turn = preload(\"res://game/train/train_turn.gd\")
const Care = preload(\"res://game/train/turn/turn_settle_care.gd\")
const Supplies = preload(\"res://game/train/train_supplies.gd\")
const TrainHands = preload(\"res://game/train/train_hands.gd\")
const W = preload(\"res://game/train/turn/turn_wounds.gd\")
const People = preload(\"res://game/train/turn/turn_people.gd\")
const Death = preload(\"res://game/train/turn/turn_death.gd\")
const Needs = preload(\"res://game/train/turn/turn_needs.gd\")
const Field = preload(\"res://game/politics/field_return.gd\")
const Agenda = preload(\"res://game/politics/council_agenda.gd\")
const Vote = preload(\"res://game/politics/council_vote.gd\")
const Ladder = preload(\"res://game/train/turn/turn_ladder.gd\")
const TrainClimate = preload(\"res://game/train/train_climate.gd\")
const TrainDecor = preload(\"res://game/train/train_decor.gd\")
const Stranded = preload(\"res://game/train/turn/turn_stranded.gd\")

static func settle(g0: Dictionary, t: Dictionary) -> Dictionary:
	if g0.get(\"deathWeight\", false): return C.unsupported(g0, \"settle: deathWeight\")
	for law: String in g0.get(\"ratify\", []):
		if St.law_active(g0, law): return C.unsupported(g0, \"dropUnratified: repeal\")
	for law: String in g0.get(\"ratifyRepeal\", []):
		if not St.law_active(g0, law): return C.unsupported(g0, \"dropUnratified: enact\")
	var g: Dictionary = g0.duplicate(true)
	var was_stranded: bool = g.get(\"stranded\") != null and int(g[\"stranded\"][\"since\"]) < int(g[\"seg\"])
	var before: Dictionary = {}
	for key: String in [\"coal\", \"food\", \"med\", \"trust\", \"tension\"]: before[key] = g[key]
	if g.get(\"stranded\") != null and g[\"stranded\"][\"since\"] == g[\"seg\"]: before[\"coal\"] += float(g[\"stranded\"].get(\"burned\", 0))
	before[\"rel\"] = {}
	for comm: String in t[\"COMMS\"]: before[\"rel\"][comm] = g[\"comms\"][comm][\"rel\"]
	var notes: Array = []
	var f: Dictionary = Turn.forecast(g, t)
	var p: Dictionary = t[\"P\"]
	var parts: Dictionary = Turn.forecast_parts(g, t)
	C.bump_parts(g, \"coal\", -float(f[\"coal\"]), parts[\"coal\"])
	C.bump_parts(g, \"food\", -float(f[\"food\"]), parts[\"food\"])
	if float(g[\"coal\"]) <= 0 and g.get(\"stranded\") == null: Stranded.enter_stranded(g, t, float(before[\"coal\"]), float(f[\"coal\"]))
	if bool(g[\"inStrike\"]): C.bump(g, \"tension\", 3, \"strike\")
	elif was_stranded:
		C.bump(g, \"tension\", float(p[\"strandedTension\"]), \"stranded\")
		Stranded.stranded_settle(g, t)
	else: g[\"comms\"][\"engine\"][\"base\"][3] += float(p[\"engineFatigue\"])
	if g.get(\"space\") is Dictionary and g[\"space\"].get(\"giver\") != null and float(g[\"space\"].get(\"step\", 0)) > 0: C.bump_rel(g, g[\"space\"][\"giver\"], float(p[\"spaceHoldRel\"]) * float(g[\"space\"][\"step\"]), \"situation\")
	g[\"forcedRun\"] = false
	g[\"guardEscort\"] = false
	Care.medicine(g, t, notes)
	Care.child_settle(g, t, notes)
	Care.heat_settle(g, t, notes)
	var supplies: Dictionary = Supplies.use(g, t)
	# 내정 훅 자리: domesticSettle(g, notes).
	hub_leak_tick(g, t, notes)
	g = Turn.drift(g, t)
	Supplies.relations(g, t, supplies)
	Care.calm_settle(g, t)
	check_due_promises(g, t)
	# arrivalsSettle: gated at the action boundary until the arrivals branch is ported.
	hunger_tick(g, t, notes)
	bite_tick(g, t)
	Needs.tick(g, t, notes)
	People.tick(g, t)
	Care.calm_night(g, t)
	if g.get(\"council\") is Dictionary:
		if not bool(g[\"council\"].get(\"emergency\", false)) and not bool(g[\"council\"].get(\"martial\", false)):
			g[\"ratify\"] = []
			g[\"ratifyRepeal\"] = []
		bribe_detection(g, t)
	leash_tick(g, t)
	ai_leaders(g, t, bool(supplies.get(\"plenty\", false)))
	g = Turn.meters(g, t)
	if g[\"phase\"] != \"end\": riot_tick(g, t, notes)
	for comm: String in t[\"COMMS\"]: g[\"comms\"][comm][\"away\"] = 0
	if was_stranded: Stranded.trip_tick(g, t)
	Stranded.reapply_away(g)
	# S1 arrivalsAway stands here; arrivals are outside this port.
	# hands.ts handsSettle: the one rule for the hands, the S1a board's and the domestic train's alike (train_hands.gd).
	g = TrainHands.settle(g, t, notes)
	if g[\"phase\"] != \"end\": g = Turn.check_end(g, t)
	# S1 disasterSettle stands here (no disasters in S2), then climateSettle: a frozen stretch goes by.
	if g[\"phase\"] != \"end\": TrainClimate.settle(g, t)
	# decor.ts reconcileStore: the dual-use tags melt, newest first, by what the settlement spent.
	TrainDecor.reconcile_store(g)
	Turn.track_lookback(g)
	var receipt: Dictionary = {\"rel\": {}, \"notes\": notes}
	for key: String in [\"coal\", \"food\", \"med\", \"trust\", \"tension\"]: receipt[key] = float(g[key]) - float(before[key])
	for comm: String in t[\"COMMS\"]: receipt[\"rel\"][comm] = float(g[\"comms\"][comm][\"rel\"]) - float(before[\"rel\"][comm])
	g[\"lastSettle\"] = receipt
	if g[\"phase\"] != \"end\": g[\"phase\"] = \"settle\"
	return g

static func hub_leak_tick(g: Dictionary, t: Dictionary, notes: Array) -> void:
	if int(g[\"seg\"]) < int(t[\"P\"][\"segments\"]) - 1 or int(g[\"seg\"]) > int(t[\"P\"][\"segments\"]): return
	var hub: Dictionary = C.hub(g)
	var total: float = 0
	for comm: String in t[\"COMMS\"]: total += float(g[\"comms\"][comm][\"pop\"])
	total = maxf(1, total)
	var any: bool = false
	for comm: String in hub[\"warned\"]:
		var share: float = Agenda._depart_share(g, t, comm)
		if share <= 0: continue
		var k: float = share * (float(g[\"comms\"][comm][\"pop\"]) / total) * float(t[\"HUB\"][\"leak\"])
		var food: float = maxf(0, floor(float(g[\"food\"]) * k * 10 + 0.5) / 10)
		var med: float = maxf(0, floor(float(g[\"med\"]) * k * 10 + 0.5) / 10)
		if food + med <= 0: continue
		C.bump(g, \"food\", -food, \"hub.stash\")
		C.bump(g, \"med\", -med, \"hub.stash\")
		if not hub[\"stash\"].has(comm): hub[\"stash\"][comm] = {\"food\": 0, \"med\": 0}
		hub[\"stash\"][comm][\"food\"] += food
		hub[\"stash\"][comm][\"med\"] += med
		any = true
	if any:
		var line: String = \"창고 장부와 자루 수가 안 맞는다. 모자란 건 하필 오래 가는 것들이다.\"
		notes.append(line)
		C.journal(g, line, \"dark\")

static func bribe_detection(g: Dictionary, t: Dictionary) -> void:
	for deal: Dictionary in g[\"council\"].get(\"deals\", []):
		var comm: String = deal[\"comm\"]
		if deal[\"tool\"] == \"bribe\" and not bool(deal.get(\"refused\", false)) and deal.get(\"label\") != \"뇌물을 거절당함\":
			var s: Dictionary = g[\"comms\"][comm]
			if C.rnd(g) < float(t[\"BRIBE_EXPOSE\"][s[\"leader\"][\"trait\"]]):
				s[\"coh\"] = clampf(float(s[\"coh\"]) - 0.2, 0, 1)
				s[\"disgraced\"] = true
				C.bump(g, \"trust\", -10, \"leak\")
				Field._offend(g, comm)
				C.journal(g, \"뇌물이 드러났다. %s의 정당성이 무너지고 열차장도 신임을 잃었다.\" % s[\"leader\"][\"name\"], \"bad\")
		elif deal[\"tool\"] == \"favor\" and C.rnd(g) < 0.15:
			for other: String in t[\"COMMS\"]:
				if other != comm: C.bump_rel(g, other, -5, \"deal\")
			C.journal(g, \"%s의 표가 빚 때문이었다는 말이 돈다. 공정성 시비가 붙었다.\" % g[\"comms\"][comm][\"leader\"][\"name\"], \"bad\")
	g[\"council\"] = null

static func check_due_promises(g: Dictionary, t: Dictionary) -> void:
	for comm: String in t[\"COMMS\"]:
		var s: Dictionary = g[\"comms\"][comm]
		var promise: Variant = s.get(\"promise\")
		if not promise is Dictionary or int(promise[\"due\"]) > int(g[\"seg\"]): continue
		var kind: String = promise[\"cond\"][\"kind\"]
		if promise[\"kind\"] == \"fetch\" or kind in [\"target\", \"skip_dispatch\"]:
			if bool(g[\"inStrike\"]): promise[\"due\"] = int(g[\"seg\"]) + 1
			continue
		# 내정 훅 자리: domesticPromise(g, comm, promise).
		var ok: bool = false
		if kind in [\"heat\", \"ration\"]: ok = float(s[kind]) >= float(promise.get(\"baseline\", 0)) + 1
		elif kind == \"keep_ration\": ok = float(s[\"ration\"]) >= float(promise.get(\"baseline\", 0))
		elif kind in [\"give_med\", \"give_lux\"]:
			var resource: String = \"med\" if kind == \"give_med\" else \"lux\"
			var amount: float = float(promise[\"cond\"].get(\"amount\", 0))
			ok = float(g[resource]) >= amount
			if ok: C.bump(g, resource, -amount, \"promise\")
		elif kind in [\"give_sup\", \"give_fine\"]:
			var resource: String = \"sup\" if kind == \"give_sup\" else \"supFine\"
			var amount: float = float(promise[\"cond\"].get(\"amount\", 0))
			ok = Supplies.asks(g) and float(g.get(resource, 0)) >= amount
			if ok:
				if resource == \"sup\": C.bump(g, resource, -amount, \"promise\")
				else: g[resource] = float(g.get(resource, 0)) - amount
		if ok: Field._keep_promise(g, t, comm, str(promise.get(\"label\", \"\")))
		else: Field._break_promise(g, t, comm, str(promise.get(\"label\", \"\")))

static func hunger_tick(g: Dictionary, t: Dictionary, notes: Array) -> void:
	if float(g[\"food\"]) > 0:
		g[\"hunger\"] = 0
		return
	g[\"hunger\"] = int(g.get(\"hunger\", 0)) + 1
	if int(g[\"hunger\"]) == 1:
		C.card(g, {\"kind\": \"info\", \"who\": \"식량이 떨어졌다\", \"text\": \"사람들은 허리띠를 졸라매고 버틴다. 3구간을 넘기면 굶어 죽는 사람이 나온다.\"}, t)
	elif int(g[\"hunger\"]) <= 3: notes.append(\"굶은 지 %d구간째다.\" % int(g[\"hunger\"]))
	else:
		var victims: Array = People.pick_victims(g, t, 1, \"hunger\", g)
		if not victims.is_empty():
			var person: Dictionary = victims[0]
			Death.on_death(g, t, person[\"community\"], [person[\"name\"]])
			C.journal(g, \"%s의 %s(%d)이(가) 굶어 죽었다.\" % [t[\"COMM_NAME\"][person[\"community\"]], person[\"name\"], int(person[\"age\"])], \"bad\")
			notes.append(\"굶어 죽은 사람이 나왔다.\")

static func bite_tick(g: Dictionary, t: Dictionary) -> void:
	var keep: Array = []
	for b: Dictionary in g.get(\"hiddenBites\", []):
		if int(g[\"seg\"]) >= int(b[\"due\"]):
			var bitten: int = 0
			var waiting: bool = false
			for card: Dictionary in g[\"cards\"]:
				if card[\"kind\"] == \"bite_found\" and card.get(\"who\") == b[\"who\"]: waiting = true
			if bool(b.get(\"isolated\", false)): C.journal(g, \"격리된 %s이(가) 숨을 거뒀다. 일어나기 전에 경비대가 처리했다.\" % b[\"who\"], \"dark\")
			elif not bool(b.get(\"found\", false)) or not waiting:
				bitten = 1 + (1 if C.rnd(g) < 0.5 else 0)
				C.bump(g, \"tension\", 8, \"corpse\")
				g[\"fear\"] = clampf(float(g[\"fear\"]) + 5, 0, 100)
				C.journal(g, \"%s이(가) %s 안에서 일어났다. %d명이 물렸다.\" % [b[\"who\"], t[\"COMM_NAME\"][b[\"comm\"]], bitten], \"bad\")
			else:
				keep.append(b)
				continue
			Death.on_death(g, t, b[\"comm\"], [b[\"who\"]], \"chosen\")
			if bitten > 0:
				g[\"injured\"] += bitten
				W.note_injury(g, t, bitten, \"rise\", \"물림\", {\"comm\": b[\"comm\"]})
			continue
		if not bool(b.get(\"found\", false)) and (St.law_active(g, \"patrol\") or C.rnd(g) < 0.5):
			b[\"found\"] = true
			C.card(g, {\"kind\": \"bite_found\", \"comm\": b[\"comm\"], \"who\": b[\"who\"], \"text\": \"귀환 검사에서 드러났다.\" if St.law_active(g, \"patrol\") else \"열이 오르는 걸 의무장이 알아챘다.\"}, t)
		keep.append(b)
	g[\"hiddenBites\"] = keep

static func leash_tick(g: Dictionary, t: Dictionary) -> void:
	var keep: Array = []
	for leash: Dictionary in g[\"leashes\"]:
		var s: Dictionary = g[\"comms\"][leash[\"comm\"]]
		if C.rnd(g) < float(s[\"grudge\"]) * float(leash[\"weight\"]) * 0.04:
			C.bump_rel(g, leash[\"comm\"], -(int(g[\"seg\"]) - int(leash[\"since\"])) * 3, \"deal\")
			C.bump(g, \"trust\", -5, \"deal\")
			Field._offend(g, leash[\"comm\"])
			C.card(g, {\"kind\": \"leash\", \"comm\": leash[\"comm\"]}, t)
			C.journal(g, \"%s이(가) 목줄을 끊었다. 협박이 드러났다.\" % s[\"leader\"][\"name\"], \"bad\")
		else: keep.append(leash)
	g[\"leashes\"] = keep

static func ai_leaders(g: Dictionary, t: Dictionary, sup_plenty: bool = false) -> void:
	var cards: int = 0
	var worst: String = \"\"
	var worst_gap: float = 0
	for comm: String in t[\"COMMS\"]:
		var s: Dictionary = g[\"comms\"][comm]
		if int(s[\"demandCool\"]) > 0:
			s[\"demandCool\"] -= 1
			continue
		var sit: Array = St.situation(g, t, comm)
		var gap: float = float(sit[3]) - 50 + 5 if comm == \"engine\" and float(sit[3]) > 50 else (maxf(0, 45 - float(sit[0])) if float(s[\"heat\"]) < 4 else 0.0) + (maxf(0, 45 - float(sit[1])) if float(s[\"ration\"]) < 4 else 0.0)
		if gap > worst_gap:
			worst = comm
			worst_gap = gap
	if worst != \"\" and not C.has_card(g, \"demand\") and not Late.pending(g, \"demand\"):
		C.card(g, {\"kind\": \"demand\", \"comm\": worst}, t)
		var seen: int = maxi(int(g.get(\"eventLog\", {}).get(\"demand:\" + worst, {}).get(\"n\", 0)), int(g.get(\"eventLog\", {}).get(\"demand:engine_shift\", {}).get(\"n\", 0)) if worst == \"engine\" else 0)
		g[\"comms\"][worst][\"demandCool\"] = 3 + mini(seen, 2) * 3
		if sup_plenty: g[\"comms\"][worst][\"demandCool\"] += int(t[\"P\"][\"supDemandCool\"])
		cards += 1
	var engine: Dictionary = g[\"comms\"][\"engine\"]
	var engine_sit: Array = St.situation(g, t, \"engine\")
	if int(engine[\"fervor\"]) == 0 and float(engine[\"rel\"]) <= -8 and (float(engine_sit[3]) > 50 or float(engine_sit[1]) < 45) and int(g[\"seg\"]) - int(g[\"strikeWarned\"]) >= 4 and cards < 2:
		g[\"strikeWarned\"] = g[\"seg\"]
		C.card(g, {\"kind\": \"strike_warn\", \"comm\": \"engine\"}, t)
		cards += 1
	for comm: String in t[\"COMMS\"]:
		var s: Dictionary = g[\"comms\"][comm]
		if int(s[\"favorCool\"]) > 0:
			s[\"favorCool\"] -= 1
			continue
		if cards < 2 and float(s[\"rel\"]) >= 15 and not bool(s[\"debt\"]) and not C.has_card(g, \"favor\") and not Late.pending(g, \"favor\") and C.rnd(g) < 0.3:
			C.card(g, {\"kind\": \"favor\", \"comm\": comm}, t)
			s[\"favorCool\"] = 4
			cards += 1
	for i: int in t[\"COMMS\"].size():
		var comm: String = t[\"COMMS\"][i]
		var s: Dictionary = g[\"comms\"][comm]
		if int(s[\"agitateCool\"]) > 0:
			s[\"agitateCool\"] -= 1
			continue
		if float(s[\"rel\"]) <= -15 and C.rnd(g) < 0.25:
			C.bump(g, \"tension\", 3, \"mood\")
			C.bump_rel(g, t[\"COMMS\"][(i + 1) % t[\"COMMS\"].size()], -3, \"mood\")
			s[\"agitateCool\"] = 3
			C.journal(g, \"밤중에 %s에서 수상한 모임이 있었다.\" % t[\"COMM_NAME\"][comm], \"dark\")
	if (int(g[\"seg\"]) + 1) % int(t[\"P\"][\"sessionEvery\"]) != 0: return
	g[\"session\"] += 1
	var options: Array = Agenda.agenda_options(g, t)[\"options\"].filter(func(x: Dictionary) -> bool: return x.get(\"kind\") != \"motion\")
	g[\"session\"] -= 1
	var seat_map: Dictionary = St.seats(g, t)
	var comms: Array = (t[\"COMMS\"] as Array).duplicate()
	comms.sort_custom(func(a: String, b: String) -> bool: return float(seat_map[a]) > float(seat_map[b]) if seat_map[a] != seat_map[b] else t[\"COMMS\"].find(a) < t[\"COMMS\"].find(b))
	var best: Dictionary = {}
	for comm: String in comms:
		for idx: int in options.size():
			var own: float = float(Vote.stance(g, t, comm, options[idx], false)[\"score\"])
			var hostile: bool = int(g[\"comms\"][comm][\"grudge\"]) >= 3 and bool(options[idx].get(\"repeal\", false))
			var score: float = own + (3 if hostile else 0)
			if (own >= 3 or (bool(options[idx].get(\"repeal\", false)) and own >= 2) or hostile) and (best.is_empty() or score > float(best[\"score\"])): best = {\"c\": comm, \"idx\": idx, \"score\": score}
	if best.is_empty(): return
	var pick: Dictionary = options[int(best[\"idx\"])].duplicate(true)
	var proposals: Array = []
	var same: bool = false
	for proposal: Dictionary in g[\"proposals\"]:
		if proposal.get(\"kind\") == \"motion\" or not bool(proposal.get(\"promise\", false)): continue
		if Agenda.same_agenda(proposal, pick): same = true
		else: proposals.append(proposal)
	pick[\"by\"] = best[\"c\"]
	if same: pick[\"promise\"] = true
	proposals.append(pick)
	g[\"proposals\"] = proposals
	C.journal(g, \"%s(%s)이(가) 다음 회기 안건을 냈다: %s.\" % [g[\"comms\"][best[\"c\"]][\"leader\"][\"name\"], t[\"COMM_NAME\"][best[\"c\"]], Vote.agenda_title(t, options[int(best[\"idx\"])])])

static func riot_tick(g: Dictionary, t: Dictionary, notes: Array) -> void:
	var p: Dictionary = t[\"P\"]
	var from: float = float(p[\"riotFrom\"])
	if from <= 0: return
	var r: Dictionary = g[\"riot\"]
	var prev: float = float(r[\"prev\"])
	var now: float = float(g[\"tension\"])
	r[\"prev\"] = now
	var ongoing: bool = int(r[\"stage\"]) == 2
	var line: float = Ladder.protest_line(g, t)
	var pending: bool = bool(r.get(\"pending\", false))
	var crossed: bool = not ongoing and ((prev < from and now >= from) or (pending and now >= from))
	# Crossing the riot line in one settle without a protest first: only the protest comes now (정치 흐름 4.1).
	var skipped: bool = crossed and not pending and prev < line
	if skipped: r[\"pending\"] = true
	elif pending and (crossed or now < from): r.erase(\"pending\")
	var starts: bool = crossed and not skipped
	if ongoing or starts:
		if starts:
			r[\"stage\"] = 2
			r[\"riots\"] += 1
		Ladder.riot_fell(g, t, int(p[\"riotFall\"]))
		r[\"spilled\"] += 1
		notes.append(\"난장판이 이어진다.\")
		if not C.has_card(g, \"protest\"):
			r[\"riotCards\"] += 1
			C.card(g, {\"kind\": \"protest\", \"comm\": \"tail\", \"text\": \"riot\"}, t)
	else:
		r[\"stage\"] = 1 if now >= float(p[\"protestFrom\"]) else 0
		if int(r[\"spilled\"]) > 0 and r[\"fire\"].is_empty():
			notes.append(\"엎어진 물건 %d더미를 치웠다.%s\" % [int(r[\"spilled\"]), \" 그을음과 부서진 선반은 남는다.\" if not r[\"scorched\"].is_empty() else \"\"])
			r[\"spilled\"] = 0
		# A dismissed protest comes back if tension is still over the line (unresolved); otherwise it is done.
		var again: bool = false
		if r.has(\"ignoredAt\") and int(g[\"seg\"]) - int(r[\"ignoredAt\"]) >= int(Ladder.LADDER[\"ignoreAgain\"]):
			again = now >= line
			r.erase(\"ignoredAt\")
		if ((prev < line and now >= line) or skipped or again) and not C.has_card(g, \"protest\"):
			r[\"protests\"] += 1
			C.card(g, {\"kind\": \"protest\", \"comm\": \"tail\", \"text\": \"protest\"}, t)
"""
