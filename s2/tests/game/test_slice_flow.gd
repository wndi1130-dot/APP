extends "res://addons/gut/test.gd"
## The slice's order of screens (slice_flow.gd): every step comes up in turn
## with the train behind it at the phase the step names, the receipt sheet
## reads a receipt, and the boot menu has the key that starts it.

const SliceFlow = preload("res://game/slice_flow.gd")
const ReceiptSheet = preload("res://game/ui/receipt_sheet.gd")
const Boot = preload("res://game/boot.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


## Without the stop scene (cinema off) unless asked: the card at once, as the
## order of screens has it; the scene's own tests turn it on.
func _flow(extra: Dictionary = {}):
	var f = SliceFlow.new()
	var o := {"skip_field": true, "seed": 3, "cinema": false}
	o.merge(extra, true)
	f.opts = o
	add_child_autofree(f)
	return f


## With the stop scene, its map built at once, as if seen whole or not.
func _cinema_flow(extra: Dictionary = {}):
	var o := {"cinema": true, "map_threads": false, "cinema_seen": false}
	o.merge(extra, true)
	var f = _flow(o)
	return f


## Tick the stop scene by hand till `beat` (or it is gone).
func _tick_to(f, beat: String, limit: float = 60.0) -> void:
	var spent: float = 0.0
	while is_instance_valid(f.cinema) and f.cinema.beat != beat and spent < limit:
		f.cinema._step(0.05)
		spent += 0.05


func _texts(f) -> Array:
	var out: Array = []
	for l in f.lines.get_children():
		if not l.is_queued_for_deletion():
			out.append(String(l.text))
	return out


## GUI positions stay local while the pointer and the moving plate are in viewport px.
func _plate_gesture(flow: SliceFlow, id: String, movement: Vector2, use_touch: bool) -> void:
	flow._process(0.0)
	var plate: Control = flow.plates.get_node("Plate_" + id) as Control
	var plate_transform: Transform2D = plate.get_global_transform_with_canvas()
	var start_local: Vector2 = plate.size * 0.5
	var end_view: Vector2 = plate_transform * start_local + movement
	var local_movement: Vector2 = plate_transform.affine_inverse().basis_xform(movement)
	if use_touch:
		var touch_down: InputEventScreenTouch = InputEventScreenTouch.new()
		touch_down.index = 0
		touch_down.position = start_local
		touch_down.pressed = true
		plate.gui_input.emit(touch_down)
		var touch_drag: InputEventScreenDrag = InputEventScreenDrag.new()
		touch_drag.index = 0
		touch_drag.position = start_local + local_movement
		touch_drag.relative = local_movement
		plate.gui_input.emit(touch_drag)
		flow._process(0.0)
		var touch_up: InputEventScreenTouch = InputEventScreenTouch.new()
		touch_up.index = 0
		touch_up.position = plate.get_global_transform_with_canvas().affine_inverse() * end_view
		touch_up.pressed = false
		plate.gui_input.emit(touch_up)
	else:
		var mouse_down: InputEventMouseButton = InputEventMouseButton.new()
		mouse_down.button_index = MOUSE_BUTTON_LEFT
		mouse_down.position = start_local
		mouse_down.pressed = true
		plate.gui_input.emit(mouse_down)
		var mouse_drag: InputEventMouseMotion = InputEventMouseMotion.new()
		mouse_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		mouse_drag.position = start_local + local_movement
		mouse_drag.relative = local_movement
		plate.gui_input.emit(mouse_drag)
		flow._process(0.0)
		var mouse_up: InputEventMouseButton = InputEventMouseButton.new()
		mouse_up.button_index = MOUSE_BUTTON_LEFT
		mouse_up.position = plate.get_global_transform_with_canvas().affine_inverse() * end_view
		mouse_up.pressed = false
		plate.gui_input.emit(mouse_up)


func test_plate_drags_do_not_select_but_short_taps_do() -> void:
	var flow: SliceFlow = _flow()
	await wait_process_frames(2)
	flow._select("")
	for use_touch: bool in [false, true]:
		var before: float = float(flow.train.cam_x)
		_plate_gesture(flow, SliceFlow.FIRST_CAR, Vector2(30.0, 0.0), use_touch)
		assert_eq(flow.sel, "", "30 px is a drag")
		assert_lt(float(flow.train.cam_x), before, "a drag on a plate reaches the train")
		_plate_gesture(flow, SliceFlow.FIRST_CAR, Vector2(3.0, 4.0), use_touch)
		assert_eq(flow.sel, SliceFlow.FIRST_CAR, "5 px is still a tap")
		flow._select("")


func test_diag_selection_uses_the_covered_pane_width_and_clears_it() -> void:
	var flow: SliceFlow = _flow()
	await wait_process_frames(2)
	flow.train.set_view_mode("diag")
	flow._select(SliceFlow.FIRST_CAR)
	var pane_rect: Rect2 = flow.pane.get_global_rect()
	var covered_px: float = flow.get_viewport().get_visible_rect().size.x - pane_rect.position.x
	assert_gt(pane_rect.size.x, 0.0)
	assert_almost_eq(float(flow.train.pane_px), covered_px, 0.001)
	assert_eq(str(flow.train.zoom), "near")
	flow._select("")
	assert_eq(float(flow.train.pane_px), 0.0)
	assert_eq(str(flow.train.zoom), "wide")
	assert_eq(float(flow.train.camera.h_offset), 0.0)


func test_the_steps_come_in_the_slice_order_with_the_train_behind_them() -> void:
	var f = _flow()
	var seen: Array = []
	var phases: Array = []
	while true:
		seen.append(f.current())
		phases.append(f.train.phase() if f.train != null else "")
		assert_true(f.panel.visible or f.card != null, f.current() + " has its panel or its screen")
		if f.current() == "end":
			break
		f.next()
	assert_eq(seen, ["train", "stop_pick", "receipt", "council", "travel", "arrive", "end"], "the field is skipped here")
	assert_eq(phases, ["travel", "stop", "settle", "council", "travel", "stop", "end"])
	assert_eq(String(f.card.name), "EndCard")
	assert_eq(f.card.go_key.text, "처음으로", "the main key draws its own arrow")


func test_the_second_station_is_its_sheet_and_the_end_the_long_sheet() -> void:
	var f = _flow()
	f.go(f._index_of("arrive"))
	assert_eq(f.current(), "arrive")
	assert_not_null(f.card, "the arrival sheet stands in for the panel")
	assert_eq(String(f.card.name), "ArrivalSheet")
	assert_false(f.panel.visible)
	assert_eq(f.gauges.g, f.arrival_g, "the gauges read the station's state")
	assert_false(f.soot_bot.visible, "the sheet lies over the bottom edge")
	assert_eq(f.card.go_key.text, "끝 카드")
	f.card.go_key.pressed.emit()
	assert_eq(f.current(), "end", "its key goes on")
	assert_eq(String(f.card.name), "EndCard", "gone with its step")
	assert_false(f.panel.visible)
	assert_eq(f.gauges.g, f.card.g, "the gauges read the finished state")
	assert_eq(String(f.card.g["phase"]), "end", "the slice finished at the second station")


func test_the_second_station_carries_the_slice_s_own_session() -> void:
	var f = _flow()
	f.go(f._index_of("council"))
	f.card.cast()
	f.card.close()
	f.next()
	assert_eq(f.current(), "arrive")
	assert_eq(f.arrival_g["fieldReturns"]["special"], f.council_g["fieldReturns"]["special"], "the slip is the session the slice sat")


func test_the_receipt_step_is_the_quiet_receipt_of_the_contract_when_the_field_is_skipped() -> void:
	var f = _flow()
	f.next()
	f.next()
	assert_eq(f.current(), "receipt")
	assert_not_null(f.card, "the receipt sheet stands in for the panel")
	assert_eq(String(f.card.name), "ReceiptSheet")
	assert_false(f.panel.visible)
	assert_true(f.gauges.visible, "the train's gauges over it, as over the stop card")
	assert_false(f.soot_bot.visible, "the sheet lies over the bottom edge")
	# The field skipped: the contract's searchers went and came back with nothing (slice_flow.gd quiet_receipt),
	# on the board's own departure, and that return is on the board once.
	assert_eq(f.receipt["departureId"], f._departure()["departureId"], "the receipt of the slice's own contract")
	assert_eq((f.train_g["fieldReturns"]["records"] as Array).size(), 1, "taken onto the board once")
	assert_true(bool(f.train_g["stop"]["done"]), "the stop closed with the field's result")
	var texts: Array = []
	for l in f.card.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_has(texts, "출발", "the end stamped")
	assert_has(texts, "술레후프")
	var made: Dictionary = SliceFlow.result_of(f.receipt)
	assert_eq(made["stay"], 120)
	assert_eq(made["boarded"], (f._departure()["roster"] as Array).size(), "everyone sent came back")
	f.card.go_key.pressed.emit()
	assert_eq(f.current(), "council", "its key goes on")
	assert_eq(String(f.card.name), "CouncilCard", "gone with its step")


func test_after_the_field_a_key_goes_on_to_its_own_receipt() -> void:
	var f = _flow({"skip_field": false, "seed": 5})
	f.next()
	f.next()
	assert_eq(f.current(), "field")
	assert_not_null(f.field)
	# The train's own departure contract (s3, J09): its people and its promises, none at the first stop.
	assert_eq(f.field.opts["departure"], f._departure(), "the field goes out under the train's contract")
	assert_eq(f.field.squad[0].pid, "captain", "the chief and the train's own people")
	assert_eq(f.field.hud.promise_label.text.replace(UiFonts.WORD_JOINER, ""), "", "no promise rides on the first stop")
	assert_false(f.panel.visible, "nothing over the stop while it is played")
	assert_false(f.weather.visible or f.film.visible, "the field brings its own weather")
	f.field.set_process(false)
	f.field.finish("departed")
	assert_true(f.panel.visible, "a key over the end card")
	f.next()
	assert_eq(f.current(), "receipt")
	assert_eq(f.receipt, f.result["receipt"], "the field's own receipt")
	assert_eq(String(f.card.name), "ReceiptSheet")
	assert_eq(f.card.result, f.result, "the sheet reads the field's own result")


func test_the_special_session_is_the_session_card_and_closing_it_goes_on() -> void:
	var f = _flow()
	f.go(f._index_of("council"))
	assert_eq(f.current(), "council")
	assert_not_null(f.card, "the session card stands in for the panel")
	assert_eq(String(f.card.name), "CouncilCard")
	assert_false(f.panel.visible)
	assert_false(f.weather.visible or f.frost.visible or f.film.visible, "the dining car is the room behind it, no snow")
	assert_eq(f.gauges.g, f.card.g, "the gauges read the session's state")
	assert_eq(f.gauges.focus, ["trust", "mood", "food", "lux"])
	f.card.cast()
	f.card.close()
	assert_eq(f.current(), "travel", "closed: on to the next stretch")
	assert_eq(f.gauges.g, f.train_g, "the slice's own state again")


func test_the_boot_menu_has_the_slice_key() -> void:
	var boot = Boot.new()
	add_child_autofree(boot)
	assert_not_null(boot.find_child("SliceButton", true, false))


func test_choosing_the_stop_is_the_paper_card_and_its_keys_go_on() -> void:
	var f = _flow()
	f.next()
	assert_eq(f.current(), "stop_pick")
	assert_not_null(f.card, "the stop card stands in for the panel")
	assert_false(f.panel.visible)
	assert_eq((f.card.find_child("Place", true, false) as Label).text, "술레후프")
	(f.card.find_child("Send", true, false) as Button).pressed.emit()
	assert_eq(f.current(), "receipt", "sent: the field (skipped here), then its receipt")
	assert_eq(String(f.card.name), "ReceiptSheet", "the stop card gone with its step, its receipt in its place")
	var g = _flow()
	g.next()
	(g.card.find_child("PassBy", true, false) as Button).pressed.emit()
	assert_eq(g.current(), "travel", "passed by: on to the next stretch")


func test_choosing_the_stop_goes_onto_the_roof_and_the_card_comes_up_over_the_station() -> void:
	var f = _cinema_flow()
	assert_true(f.loader.has_data(), "the stop's map made ready on the train")
	f.next()
	assert_eq(f.current(), "stop_pick")
	assert_not_null(f.cinema, "the roof of the running train first")
	assert_eq(f.cinema.stop_opts["act_progress"], f._field_opts()["act_progress"], "in the field's own weather")
	assert_null(f.card, "no card straight away")
	assert_false(f.gauges.visible, "nothing over the roof but the scene")
	assert_null(f.train, "the train's inside is not drawn under it")
	_tick_to(f, "hold")
	assert_not_null(f.card, "the station in sight: the card")
	assert_eq((f.card.find_child("Place", true, false) as Label).text, "술레후프")
	assert_true(f.gauges.visible, "the gauges over the card, as before")
	(f.card.find_child("Send", true, false) as Button).pressed.emit()
	assert_null(f.card, "sent: the card goes")
	assert_eq(f.cinema.beat, "brake")
	assert_true(f.cinema.ready_to_land, "no field to wait for when it is skipped")
	_tick_to(f, "out")
	assert_eq(f.current(), "receipt", "over the stop: the field (skipped here), then its receipt")


func test_passing_the_stop_by_brings_the_train_back_without_a_field() -> void:
	var f = _cinema_flow({"skip_field": false})
	f.next()
	_tick_to(f, "hold")
	(f.card.find_child("PassBy", true, false) as Button).pressed.emit()
	assert_eq(f.cinema.beat, "away")
	assert_null(f.loader.field, "no field is built for a stop passed by")
	_tick_to(f, "out")
	assert_eq(f.current(), "travel", "back on the line")
	assert_null(f.pending_field)


## Passed by on the board: the stop resolved as passed (S1 resolveStop), no return, no
## session, and the slice ends there without running the train on.
func test_a_stop_passed_by_ends_the_slice_on_the_board_without_a_return() -> void:
	var f = _flow()
	f.next()
	assert_eq(f.current(), "stop_pick")
	f.card.passed_by.emit()
	assert_eq(f.current(), "travel", "back on the line")
	assert_true(f.passed)
	assert_true(bool(f.train_g["stop"]["done"]), "the stop resolved as passed")
	assert_false(f._returned(), "no field, no return")
	var seg: int = int(f.train_g["seg"])
	f.next()
	assert_eq(f.current(), "arrive")
	assert_eq(int(f.train_g["seg"]), seg, "the train is not run on past the stop")
	assert_eq(f.port_error, "", "nothing outside the port was asked")
	f.next()
	assert_eq(f.current(), "end")


func test_sent_the_field_is_built_under_the_scene_and_shown_when_it_lands() -> void:
	var f = _cinema_flow({"skip_field": false, "seed": 5})
	f.loader.resting = true
	f.next()
	_tick_to(f, "hold")
	(f.card.find_child("Send", true, false) as Button).pressed.emit()
	var roof_look: Dictionary = f.cinema.look
	var building = f.loader.field
	assert_not_null(building, "the field goes up as the brakes go on")
	assert_false(building.visible)
	assert_eq(building.opts["seed"], 5)
	await wait_for_signal(f.loader.field_built, 60)
	# The scene wore the weather this field opens in, whatever the season table
	# gives this stop: what falls, how cold it is, the season's look.
	assert_eq(String(roof_look["falls"]), String(building.atmo["falls"]), "the same rain, sleet or snow over the roof and the field")
	assert_almost_eq(float(roof_look["temp_c"]), float(building.atmo["temp_c"]), 0.01, "as cold")
	assert_eq(String(roof_look["season"]), String(building.atmo["season"]), "the same season's look")
	# The scene runs on its own meanwhile: it may have handed the field over already.
	assert_true(f.pending_field == building or f.field == building, "handed to the slice")
	_tick_to(f, "out")
	await wait_process_frames(2)
	assert_eq(f.current(), "field")
	assert_eq(f.field, building, "the field built under the scene is the one played")
	assert_true(f.field.visible)
	assert_false(f.field.standing_by, "shown: it starts")
	assert_eq(f.field.opts["departure"], f._departure(), "with the train's contract, as before")


func test_skipping_the_scene_changes_nothing_the_field_goes_out_with() -> void:
	var a = _cinema_flow({"skip_field": false, "seed": 5})
	var b = _cinema_flow({"skip_field": false, "seed": 5, "cinema_seen": true})
	assert_eq_deep(a._field_opts(), b._field_opts())
	b.next()
	b.cinema._step(0.05)
	b.cinema.skip()
	assert_eq(b.cinema.beat, "hold", "seen before: a tap goes to the card")
	assert_not_null(b.card)
