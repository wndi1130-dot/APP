extends "res://addons/gut/test.gd"
## The refit pane (mods_pane.gd, decision 426 PR 4): the cars of this train the
## people live in, what insulating each gives in S1's numbers, keys a finger can
## take (48 dp), the research it waits for named in the head, a start that pays
## the wood, a take-back only while the workshop has not touched it, and a done
## car with its numbers and no key.

const ModsPane = preload("res://game/ui/mods_pane.gd")
const TrainMods = preload("res://game/train/train_mods.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const HomeBar = preload("res://game/ui/home_bar.gd")
const SliceFlow = preload("res://game/slice_flow.gd")


## The rows a press draws again are freed a frame later; let them go before GUT counts orphans.
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
	return p.find_child(key_name, true, false) as Button


func _word(b: Button) -> String:
	return (b.get_node("Word") as Label).text


func test_the_rows_are_this_trains_lived_in_cars_with_s1s_numbers() -> void:
	var m: Dictionary = ModsPane.model(_game())
	assert_eq(m["rows"].map(func(r: Dictionary) -> String: return r["id"]), ["tail1", "medtech", "front"],
		"the default train's cars the people live in, in train order (not the dining car or the captain's)")
	for r: Dictionary in m["rows"]:
		assert_eq(r["gain"], TrainMods.insulate_numbers(r["id"]))
		assert_eq([r["word"], r["can"]], ["단열", true])
	assert_eq(m["rows"][0]["gain"], "온기 +2, 난방 −1할, 과밀 +2", "one of the tail's three cars")
	assert_eq(m["need"], "")


func test_without_its_research_the_keys_wait_and_the_head_names_it() -> void:
	var g := _game(false)
	var m: Dictionary = ModsPane.model(g)
	assert_eq(m["need"], "단열 개조")
	var p := _pane(g)
	await wait_process_frames(1)
	assert_eq((p.find_child("Need", true, false) as Label).text, "단열 개조")
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
	var cost: Label = p.find_child("Cost_front_wood", true, false) as Label
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
	assert_not_null(p.find_child("Progress_medtech", true, false))
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
	assert_eq((p.find_child("Gain_front", true, false) as Label).text, TrainMods.insulate_numbers("front"))
	assert_null(p.find_child("Cost_front_wood", true, false), "no price on a done car")


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
	assert_false(f.pane.visible, "the car's pane makes way")
	f._open_room("gear")
	await wait_process_frames(1)
	assert_false(is_instance_valid(f.mods), "the workshop takes the refit pane's place")
	assert_true(is_instance_valid(f.shop))
	f._close_room()
	await wait_process_frames(1)
	assert_eq(f.sel, was, "folding brings back the car picked before either room")
	assert_true(f.pane.visible)
	f._open_room("wrench")
	f._select(was)
	await wait_process_frames(1)
	assert_false(is_instance_valid(f.mods), "a car picked puts the room away")
