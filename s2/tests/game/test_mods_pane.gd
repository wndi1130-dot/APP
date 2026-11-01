extends "res://addons/gut/test.gd"
## The refit pane (mods_pane.gd, decision 426 PR 4): the cars of this train the
## people live in, what insulating each gives in S1's numbers, keys a finger can
## take (48 dp), the research it waits for named in the head, a start that pays
## the wood, a take-back only while the workshop has not touched it, and a done
## car with its numbers and no key.

const RowKeep = preload("res://game/ui/row_keep.gd")
const ModsPane = preload("res://game/ui/mods_pane.gd")
const TrainMods = preload("res://game/train/train_mods.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const HomeBar = preload("res://game/ui/home_bar.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const PaneMotion = preload("res://game/ui/pane_motion.gd")


## Let queued frees settle before GUT counts orphans.
func after_each() -> void:
	await wait_process_frames(1)


func _game(e5: bool = true) -> Dictionary:
	var g := {"seg": 1, "dom": TrainDom.start()}
	if e5:
		g["dom"]["techs"]["e5"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	return g


func _pane(g: Dictionary) -> Control:
	var holder := Control.new()
	holder.size = Vector2(844.0, 390.0) * UiFonts.K
	add_child_autofree(holder)
	var p = ModsPane.new()
	holder.add_child(p)
	p.pin(48.0)
	p.show_state(g)
	return p


func _key(p: Control, key_name: String) -> Button:
	return _live(p, key_name) as Button


func _word(b: Button) -> String:
	return (b.get_node("Word") as Label).text


func test_the_rows_are_this_trains_lived_in_cars_with_s1s_numbers() -> void:
	var m: Dictionary = ModsPane.model(_game())
	var insulation: Array = m["rows"].filter(func(r: Dictionary) -> bool: return r["kind"] == "insulate")
	assert_eq(insulation.map(func(r: Dictionary) -> String: return r["id"]), ["tail3", "tail2", "tail1", "medtech", "guard", "front", "engine"],
		"the default train's cars the people live in, in train order (not the dining car, the captain's or the workshop)")
	for r: Dictionary in insulation:
		assert_eq(r["gain"], TrainMods.insulate_numbers(r["id"]))
		assert_eq([r["word"], r["can"]], ["단열", true])
	assert_eq(m["rows"][0]["gain"], "온기 +2, 난방 −1할, 과밀 +2", "one of the tail's three cars")
	assert_eq(m["need"], "")


func test_furnish_row_shows_the_score_after_a_job_that_will_not_reach_the_next_tier() -> void:
	var g: Dictionary = _game()
	g["dom"]["furnish"] = {"front": {"work": 0, "jobs": [], "furnPts": 0, "tier": 1, "best": 1, "items": []}}
	var row: Dictionary = (ModsPane.model(g)["rows"] as Array).filter(func(r: Dictionary) -> bool: return r["id"] == "furnish_front")[0]
	assert_eq(row["gain"], "살림 1단 · 작업 뒤 점수 5/8")


func test_furnish_rows_show_each_cars_next_tier_and_pay_and_refund_cloth() -> void:
	var g: Dictionary = _game()
	var rows: Array = ModsPane.model(g)["rows"].filter(func(r: Dictionary) -> bool: return r["kind"] == "furnish")
	assert_eq(rows.size(), 6)
	assert_eq(rows.map(func(r: Dictionary) -> String: return r["car"]), ["tail3", "tail2", "tail1", "medtech", "guard", "front"])
	var p := _pane(g)
	await wait_process_frames(1)
	var key: Button = _key(p, "Key_furnish_front")
	assert_eq((_live(p, "Gain_furnish_front") as Label).text, "살림 0단 → 1단")
	assert_eq(key.tooltip_text, "목재 1 · 고철 3 · 일 1", "the first tier needs no cloth")
	assert_null(_key(p, "Key_furnish_engine"))
	g["dom"]["cloth"] = 2
	p.show_state(g)
	await wait_process_frames(1)
	_key(p, "Key_furnish_front").pressed.emit()
	assert_eq(g["dom"]["job"]["kind"], "furnish")
	assert_eq(float(g["dom"]["cloth"]), 2.0)
	await wait_process_frames(1)
	assert_not_null(_live(p, "Progress_furnish_front"))
	assert_null(_live(p, "Progress_front"), "insulation row is not this job")
	assert_eq(_word(_key(p, "Key_furnish_front")), "취소")
	_key(p, "Key_furnish_front").pressed.emit()
	assert_null(g["dom"]["job"])
	assert_eq([float(g["dom"]["wood"]), float(g["dom"]["scrap"]), float(g["dom"]["cloth"])], [10.0, 10.0, 2.0])


## Seven lived-in cars do not fit under the stores: the pane stays the car
## pane's height and the rows are dragged up inside it.
func test_more_cars_than_fit_scroll_inside_the_pane() -> void:
	var p := _pane(_game())
	await wait_process_frames(2)
	assert_almost_eq(p.size.y / UiFonts.K, ModsPane.CSS_H_MAX, 0.5, "no higher than the car's pane")
	var s := _live(p, "List") as ScrollContainer
	assert_not_null(s)
	var rows := _live(p, "Rows") as Control
	assert_gt(rows.size.y, s.size.y, "seven rows are longer than the room for them")
	assert_lte(s.position.y + s.size.y, p.size.y + 0.5, "the list ends inside the pane")
	assert_not_null(_live(p, "Key_engine"), "the last car's key is there to drag up to")
	var more := _live(p, "More") as Control
	assert_not_null(more, "the glass darkens where rows are left below")
	assert_true(more.visible)
	s.scroll_vertical = 10000
	await wait_process_frames(2)
	assert_false(more.visible, "dragged to the end, the shade goes")


func test_without_its_research_the_keys_wait_and_the_head_names_it() -> void:
	var g := _game(false)
	var m: Dictionary = ModsPane.model(g)
	assert_eq(m["need"], "단열 개조")
	var p := _pane(g)
	await wait_process_frames(1)
	assert_eq((_live(p, "Need") as Label).text, "단열 개조")
	var key: Button = _key(p, "Key_tail1")
	assert_almost_eq(key.modulate.a, UiDeny.DIM, 1e-6)
	assert_eq(key.tooltip_text, "단열 개조를 아직 모른다")
	key.pressed.emit()
	assert_true(UiDeny.is_shaking(key))
	assert_null(g["dom"]["job"])


func test_every_key_takes_a_finger_48_dp_wide() -> void:
	var p := _pane(_game())
	await wait_process_frames(1)
	for key_name: String in ["Fold", "Key_tail1", "Key_medtech", "Key_front"]:
		var b: Button = _key(p, key_name)
		assert_not_null(b, key_name)
		assert_gte(b.size.y, FieldHud.MIN_TOUCH - 0.01, key_name + " tall enough")
		assert_gte(b.size.x, FieldHud.MIN_TOUCH - 0.01, key_name + " wide enough")


func test_short_wood_is_red_and_will_not_start() -> void:
	var g := _game()
	g["dom"]["wood"] = 3
	var p := _pane(g)
	await wait_process_frames(1)
	var cost: Label = _live(p, "Cost_front_wood") as Label
	assert_eq(cost.get_theme_color("font_color"), ModsPane.RED)
	_key(p, "Key_front").pressed.emit()
	assert_null(g["dom"]["job"])


func test_start_then_take_back_before_the_workshop_touches_it() -> void:
	var g := _game()
	var p := _pane(g)
	await wait_process_frames(1)
	_key(p, "Key_medtech").pressed.emit()
	assert_eq(String(g["dom"]["job"]["car"]), "medtech")
	assert_eq(float(g["dom"]["wood"]), 2.0)
	await wait_process_frames(1)
	assert_not_null(_live(p, "Progress_medtech"))
	assert_eq(_word(_key(p, "Key_medtech")), "취소")
	assert_almost_eq(_key(p, "Key_front").modulate.a, UiDeny.DIM, 1e-6, "one job on the line")
	_key(p, "Key_medtech").pressed.emit()
	assert_null(g["dom"]["job"])
	assert_eq(float(g["dom"]["wood"]), 10.0, "the wood comes back")


func test_once_touched_the_job_stays() -> void:
	var g := _game()
	TrainMods.start_job(g, "insulate", "tail1")
	g["dom"]["job"]["progress"] = 1.0
	var p := _pane(g)
	await wait_process_frames(1)
	var key: Button = _key(p, "Key_tail1")
	assert_almost_eq(key.modulate.a, UiDeny.DIM, 1e-6)
	key.pressed.emit()
	assert_not_null(g["dom"]["job"])


func test_a_done_car_shows_what_it_gets_and_has_no_key() -> void:
	var g := _game()
	g["dom"]["insulated"] = ["front"]
	var p := _pane(g)
	await wait_process_frames(1)
	assert_null(_key(p, "Key_front"))
	assert_eq((_live(p, "Gain_front") as Label).text, TrainMods.insulate_numbers("front"))
	assert_null(_live(p, "Cost_front_wood"), "no price on a done car")


func test_the_fold_key_folds() -> void:
	var p := _pane(_game())
	await wait_process_frames(1)
	watch_signals(p)
	_key(p, "Fold").pressed.emit()
	assert_signal_emitted(p, "folded")

## The bottom bar's 개조 key is a room of its own, as the workshop's (slice_flow.gd opens the pane).
func test_the_refit_room_opens_from_the_bottom_bar() -> void:
	var holder := Control.new()
	holder.size = Vector2(844.0, 390.0) * UiFonts.K
	add_child_autofree(holder)
	var bar = HomeBar.new()
	bar.main_word = "정차 고르기"
	bar.open_rooms = ["wrench", "gear"]
	holder.add_child(bar)
	await wait_frames(2)
	watch_signals(bar)
	(bar.get_node("Room_wrench") as Button).pressed.emit()
	assert_signal_emitted_with_parameters(bar, "room_pressed", ["wrench"])
	assert_null(bar.get_node_or_null("Note"), "the refit room says nothing over its key")

## On the train's home the 개조 room's pane stands where the car's did; the
## workshop opened over it takes its place, folding brings the car picked
## before back, and a car picked puts a room away.
func test_the_slice_opens_one_room_at_a_time() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 3, "cinema": false}
	add_child_autofree(f)
	await wait_process_frames(1)
	assert_eq(f.current(), "train")
	var was: String = f.sel
	assert_ne(was, "", "the home comes up with a car picked")
	f._open_room("wrench")
	assert_true(is_instance_valid(f.mods), "the refit pane is up")
	assert_eq(String(f.mods.name), "ModsPane")
	assert_false(PaneMotion.shown(f.pane), "the car's pane makes way")
	f._open_room("gear")
	await wait_process_frames(1)
	assert_false(is_instance_valid(f.mods), "the workshop takes the refit pane's place")
	assert_true(is_instance_valid(f.shop))
	f._close_room()
	await wait_process_frames(1)
	assert_eq(f.sel, was, "folding brings back the car picked before either room")
	assert_true(PaneMotion.shown(f.pane))
	f._open_room("wrench")
	f._select(was)
	await wait_process_frames(1)
	assert_false(is_instance_valid(f.mods), "a car picked puts the room away")



func _live(p: Control, key_name: String) -> Control:
	# Hidden parts and retiring rows no longer belong to the current list.
	for found: Node in p.find_children(key_name, "Control", true, false):
		var control: Control = found as Control
		if not control.is_visible_in_tree():
			continue
		var ancestor: Node = control
		var leaving: bool = false
		while ancestor != null and ancestor != p:
			if ancestor.has_meta(RowKeep.LEAVING_META):
				leaving = true
				break
			ancestor = ancestor.get_parent()
		if not leaving:
			return control
	return null


func test_show_state_keeps_scroll_row_controls_and_pressed_key() -> void:
	var g: Dictionary = _game()
	var p: Control = _pane(g)
	await wait_process_frames(2)
	var scroll: ScrollContainer = p.get_node("Parts/List") as ScrollContainer
	scroll.scroll_vertical = 80
	await wait_process_frames(1)
	var saved: int = scroll.scroll_vertical
	assert_gt(saved, 0)
	var row: Control = p.get_node("Parts/List/Rows/Item_tail1") as Control
	var row_id: int = row.get_instance_id()
	var key: Button = row.get_node("Key_tail1") as Button
	var key_id: int = key.get_instance_id()
	var store: Label = p.get_node("Parts/Store_wood") as Label
	var store_id: int = store.get_instance_id()
	key.toggle_mode = true
	key.set_pressed_no_signal(true)
	g["dom"]["wood"] = float(g["dom"]["wood"]) + 1.0
	p.show_state(g)
	assert_eq(scroll.scroll_vertical, saved)
	await wait_process_frames(2)
	assert_eq(scroll.scroll_vertical, saved)
	assert_eq(p.get_node("Parts/List/Rows/Item_tail1").get_instance_id(), row_id)
	assert_eq(row.get_node("Key_tail1").get_instance_id(), key_id)
	assert_eq(p.get_node("Parts/Store_wood").get_instance_id(), store_id)
	assert_eq(store.text, str(int(g["dom"]["wood"])))
	assert_true(key.button_pressed)
