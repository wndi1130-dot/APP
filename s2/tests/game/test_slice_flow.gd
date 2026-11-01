extends "res://addons/gut/test.gd"
## The slice's order of screens (slice_flow.gd): every step comes up in turn
## with the train behind it at the phase the step names, the receipt sheet
## reads a receipt, and the boot menu has the key that starts it.

const SliceFlow = preload("res://game/slice_flow.gd")
const ReceiptSheet = preload("res://game/ui/receipt_sheet.gd")
const Boot = preload("res://game/boot.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HaltTurn = preload("res://game/train/train_turn.gd")
const HaltVectors = preload("res://tests/train/train_vectors.gd")


func _halt_input(kind: String, after: bool = false) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/stranded_vectors.json"))
	var id: String = "en-route" if kind == "stranded" else "finish-ousted-from-travel"
	for row: Dictionary in data["cases"]:
		if row["id"] == id: return row["steps"][-1]["after" if after else "before"].duplicate(true)
	return {}


func _assert_halt_panel(f, kind: String) -> void:
	var reason: String = HaltTurn.END_TEXT["stranded" if kind == "stranded" else "ousted"]
	assert_true(f.panel.visible)
	assert_eq(f.title.text, "열차가 멈췄다" if kind == "stranded" else "축출", "an ending without stranding names its S1 ending")
	var shown: Array = _texts(f)
	assert_eq(shown[0], reason, "the end words remain first")
	if kind == "stranded":
		assert_eq(shown, [reason], "a stopped train has not ended")
		assert_false(f.train_g.has("endChronicle"))
	else:
		var lookback: Array = HaltTurn.lookback_lines(f.train_g, f.train_t)
		var expected: Array = [reason]
		expected.append_array(lookback.slice(0, 1))
		assert_eq(shown, expected)
		assert_false(f.train_g.has("endChronicle"))
		assert_false((f.train_g["journal"] as Array).any(func(line: Dictionary) -> bool: return String(line["text"]).begins_with("기록: 징후")))
		assert_lte(shown.size(), 2, "dark-off endings have no tone block")
	assert_eq(f.next_button.text, "끝")
	assert_eq(f.port_error, "", "game halt does not enter the port_error path")
	assert_false(is_instance_valid(f.paper))
	assert_false(is_instance_valid(f.card), "no stop, receipt or arrival card")
	assert_false(f.weather.moving)
	assert_false(f.train.running(), "the train scene stands still, an ending without stranding too")
	assert_eq(f.next_stop_line(), "")
	assert_eq(f.train.rules["train"].get("stranded"), f.train_g.get("stranded"), "train scene receives the stopped state")
	assert_false("\n".join(_texts(f)).contains("이식"))
	assert_false("\n".join(_texts(f)).contains("다음 판"))
	var held: Dictionary = f.train_g.duplicate(true)
	f.next_button.pressed.emit()
	assert_eq(f.current(), "end")
	assert_eq(_texts(f), shown, "the end step retains the same game words")
	assert_eq(HaltVectors.full_diffs(held, f.train_g), [], "end button does not turn a halt into a slice ending")


func test_train_key_halts_at_new_stranding_and_real_ending() -> void:
	for kind: String in ["stranded", "ending"]:
		var f = _flow()
		f.train_g = _halt_input(kind)
		f.train_on()
		assert_eq(f.current(), "train", "no step forward to stop selection")
		assert_false(f._returned())
		_assert_halt_panel(f, kind)


func test_direct_step_halts_before_fabricating_a_return() -> void:
	for kind: String in ["stranded", "ending"]:
		var f = _flow()
		f.train_g = _halt_input(kind)
		f.go(f._index_of("receipt"))
		assert_true(f.receipt.is_empty(), "no quiet return after the board stops")
		assert_false(f._returned())
		assert_true(f.arrival_g.is_empty())
		_assert_halt_panel(f, kind)


func test_run_to_station_halts_before_automatic_choices_and_arrival() -> void:
	for kind: String in ["stranded", "ending"]:
		var f = _flow()
		f.go(f._index_of("travel"))
		assert_true(f._returned(), "ordinary slice reached its real quiet return first")
		var records: Dictionary = f.train_g["fieldReturns"].duplicate(true)
		f.train_g = _halt_input(kind)
		f.train_g["fieldReturns"] = records
		f.go(f._index_of("arrive"))
		assert_true(f.arrival_g.is_empty(), "no arrival after a stopped rule step")
		assert_eq(f.train_g["fieldReturns"], records)
		_assert_halt_panel(f, kind)


func test_already_stranded_papers_are_never_automatically_chosen() -> void:
	var g: Dictionary = _halt_input("stranded", true)
	g["seg"] = 7
	g["cards"].append({"uid": 900, "kind": "trip_depart", "comm": "tail"})
	g["nextCardUid"] = 901
	var before: Dictionary = g.duplicate(true)
	var t: Dictionary = SliceFlow.start_board()[1]
	assert_eq(HaltVectors.full_diffs(before, SliceFlow.step_train(g, t)), [])
	assert_eq(HaltVectors.full_diffs(before, SliceFlow.pick_first(g, t)), [])
	assert_eq(HaltVectors.full_diffs(before, SliceFlow.to_travel(g, t)), [], "a halted board is not reset to the first segment")
	var f = _flow()
	f.train_g = g
	f.train_on()
	assert_eq(f.train_g["cards"], before["cards"], "the required trip card stays pending")
	_assert_halt_panel(f, "stranded")


func test_halt_words_prioritize_the_real_ending_and_exclude_slice_finish() -> void:
	for end: String in ["ousted", "lost_captain", "coup"]:
		assert_eq(SliceFlow.train_halt_line({"phase": "end", "end": end, "stranded": {}}), HaltTurn.END_TEXT[end])
	assert_eq(SliceFlow.train_halt_line({"phase": "end", "end": "revolt", "stranded": {}}), HaltTurn.STRANDED_REVOLT_TEXT)
	assert_eq(SliceFlow.train_halt_line({"phase": "end", "end": "slice"}), "")
	for end: String in ["ousted", "lost_captain", "coup", "revolt"]:
		assert_eq(SliceFlow.train_halt_title({"phase": "end", "end": end, "stranded": {}}), HaltTurn.END_TITLE[end])
	assert_eq(SliceFlow.train_halt_title({"stranded": {}}), "열차가 멈췄다")
	assert_eq(SliceFlow.train_halt_title({"phase": "end", "end": "slice"}), "")


func test_real_end_panel_words_fit_and_never_mutate_the_record() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/end_vectors.json"))
	for row: Dictionary in data["cases"]:
		var f = _flow()
		f.train_g = row["after"].duplicate(true)
		var before_draw: Dictionary = f.train_g.duplicate(true)
		f.go(f._index_of("receipt"))
		await wait_frames(2)
		var shown: Array = _texts(f)
		assert_eq(shown[0], SliceFlow.train_halt_line(f.train_g))
		assert_eq(shown, row["panelLines"])
		assert_lte(shown.size(), 2)
		assert_eq(HaltVectors.full_diffs(before_draw, f.train_g), [], "first drawing is read-only")
		assert_false(f.train_g.has("endChronicle"))
		var viewport: Rect2 = f.get_viewport().get_visible_rect()
		assert_true(viewport.encloses(f.panel.get_global_rect()), row["id"] + " panel stays on screen")
		var held: Dictionary = f.train_g.duplicate(true)
		f._show_end("처음으로")
		assert_eq(_texts(f), shown, "both real-end entry points agree")
		assert_eq(HaltVectors.full_diffs(held, f.train_g), [], "redrawing changes no state or journal entries")
		remove_child(f)
		f.queue_free()


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
			out.append(String(l.text).replace(UiFonts.WORD_JOINER, ""))
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


func test_diag_nameplates_use_the_front_lower_corner() -> void:
	var flow: SliceFlow = _flow()
	await wait_process_frames(2)
	flow.train.set_view_mode("diag")
	flow.train.focus_car(SliceFlow.FIRST_CAR)
	flow._process(0.0)
	assert_false(flow.outside.visible)
	assert_gt(flow.plates.get_child_count(), 0)
	var cam: Camera3D = flow.train.camera
	for plate: Control in flow.plates.get_children():
		var car_node: Node3D = plate.get_meta("car")
		var anchor: Vector3 = car_node.to_global(Vector3(float(plate.get_meta("x")), -0.45, 1.40))
		var expected: Vector2 = cam.unproject_position(anchor)
		var center: Vector2 = plate.position + plate.size * 0.5
		assert_almost_eq(center.x, expected.x, 2.0)
		assert_almost_eq(center.y, expected.y, 2.0)
	flow.train.set_view_mode("section")
	flow._process(0.0)
	assert_true(flow.outside.visible)
	var first_plate: Control = flow.plates.get_child(0) as Control
	var first_car: Node3D = first_plate.get_meta("car")
	var section_anchor: Vector3 = first_car.to_global(Vector3(float(first_plate.get_meta("x")), -0.45, 0.0))
	assert_true((first_plate.position + first_plate.size * 0.5).is_equal_approx(cam.unproject_position(section_anchor)))


func test_diag_marks_highlight_without_drawing_2d_marks() -> void:
	var flow: SliceFlow = _flow()
	await wait_process_frames(2)
	flow.train.set_view_mode("diag")
	flow._select(SliceFlow.FIRST_CAR)
	assert_eq(flow.card, flow.home)
	# A direct call outside draw would report an error if it drew any 2D marks.
	flow._draw_marks()
	var band: MeshInstance3D = flow.train.highlight_band
	assert_true(band.visible)
	var chosen: Node3D = flow.train.car(SliceFlow.FIRST_CAR)["node"]
	assert_eq(band.global_transform, chosen.global_transform)
	flow._draw_marks()
	assert_eq(flow.train.highlight_band, band)
	flow.card = null
	flow._draw_marks()
	assert_false(band.visible)
	flow.card = flow.home
	flow._draw_marks()
	assert_true(band.visible)
	var other_card: Control = Control.new()
	add_child_autofree(other_card)
	flow.card = other_card
	flow._draw_marks()
	assert_false(band.visible)
	flow.card = flow.home
	flow._select("")
	flow._draw_marks()
	assert_false(band.visible)
	for c: Dictionary in flow.train.cars:
		assert_false(bool(c["dimmed"]))


func test_council_builds_the_train_in_section_view() -> void:
	var flow: SliceFlow = _flow()
	await wait_process_frames(2)
	flow.train.set_view_mode("diag")
	flow.go(flow._index_of("council"))
	assert_eq(flow.current(), "council")
	assert_eq(flow.train.opts.get("view_mode"), "section", "set before the scene enters the tree")
	assert_eq(flow.train.view_mode, "section")
	assert_true(flow.outside.visible)
	assert_false(flow.train.snow_ground.visible)
	assert_false(flow.train.highlight_band.visible)


func test_the_steps_come_in_the_slice_order_with_the_train_behind_them() -> void:
	var f = _flow()
	var seen: Array = []
	var phases: Array = []
	var bands: Array = []
	while true:
		seen.append(f.current())
		phases.append(f.train.phase() if f.train != null else "")
		bands.append(String(f.train.rules["view"]["region"]) if f.train != null else "")
		assert_true(f.panel.visible or f.card != null, f.current() + " has its panel or its screen")
		if f.current() == "end":
			break
		f.next()
	assert_eq(seen, ["train", "stop_pick", "receipt", "council", "travel", "arrive", "end"], "the field is skipped here")
	assert_eq(phases, ["travel", "stop", "settle", "council", "travel", "stop", "end"])
	# The field's map is the first stop's own (K1) and the second station the stop after it (K3).
	assert_eq(bands, ["K1", "K1", "K1", "K1", "K3", "K3", "K3"], "running: the band of the stop ahead; standing: the stop's own")
	assert_eq(String(f.card.name), "EndCard")
	assert_eq(f.card.go_key.text, "처음으로", "the main key draws its own arrow")


func test_field_opts_carry_the_band_of_the_steps_stop() -> void:
	var f = _flow()
	for row: Array in [["stop_pick", "K1"], ["field", "K1"], ["arrive", "K3"]]:
		f.step = f._index_of(String(row[0]))
		assert_eq(f._field_opts()["region"], row[1], "the first stop's own map: " + String(row[0]))
	# A map any stop may use takes the band of the stop its stretch reaches.
	var any = _flow({"place": "houses_01"})
	for row: Array in [["stop_pick", "K3"], ["arrive", "K4"]]:
		any.step = any._index_of(String(row[0]))
		assert_eq(any._field_opts()["region"], row[1], "a shared map: " + String(row[0]))


## Decision 494: the field goes out in its stop's form on the route, and the map made ready
## while the train runs is made in it. The first stop's own map is the first stop, a city one;
## a map any stop may use is the stretch's stop (the second: an edge stop, the third: a siding).
## A form asked of the slice wins; a stop the route gives none leaves it to the place.
func test_field_opts_and_the_ready_map_carry_the_routes_stop_form() -> void:
	var f = _flow()
	f.step = f._index_of("field")
	assert_eq(f._field_opts()["stop_form"], "city", "the first stop's own map")
	assert_eq(f._stop_form(SliceFlow._field_seg()), "city", "made ready as it")
	var any = _flow({"place": "houses_01"})
	for row: Array in [["field", "edge"], ["arrive", "siding"]]:
		any.step = any._index_of(String(row[0]))
		assert_eq(any._field_opts()["stop_form"], row[1], "a shared map: " + String(row[0]))
	assert_eq(any._stop_form(SliceFlow._field_seg()), "edge", "the map made ready on the train is the field's stop's")
	var asked = _flow({"place": "houses_01", "stop_form": "remote", "stop_form_m": 500.0})
	asked.step = asked._index_of("field")
	assert_eq(asked._field_opts()["stop_form"], "remote", "asked of the slice")
	assert_eq(asked._field_opts()["stop_form_m"], 500.0)
	var none = _flow({"place": "houses_01", "stop_form": ""})
	none.step = none._index_of("field")
	assert_false(none._field_opts().has("stop_form"), "an empty form leaves it to the place")


## Decision 494: the stop's weather and cold are those of the season table's stretch it stands
## in (the first stop at 54 km: the fifth stretch), not the row with the slice's stretch number.
func test_field_opts_read_the_season_stretch_of_the_steps_stop() -> void:
	var f = _flow()
	for row: Array in [["stop_pick", 5], ["field", 5], ["arrive", 10]]:
		f.step = f._index_of(String(row[0]))
		var o: Dictionary = f._field_opts()
		assert_almost_eq(float(o["act_progress"]), SliceFlow.prologue_progress(int(row[1])), 0.0001, String(row[0]))
		assert_eq(o["weather"], f.stop_weather(int(row[1]))["rules"], String(row[0]))


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
	# Slots of its own, so a slice or a stop left on this machine does not open instead of the menu.
	boot.slice_save_path = "user://test_slice_flow_menu_slice.json"
	boot.train_save_path = "user://test_slice_flow_menu_train.json"
	boot.field_save_path = "user://test_slice_flow_menu_field.json"
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
