extends "res://addons/gut/test.gd"

const Pane = preload("res://game/ui/decor_pane.gd")
const CarPane = preload("res://game/ui/car_pane.gd")
const Data = preload("res://game/ui/decor_ui_data.gd")
const Decor = preload("res://game/train/train_decor.gd")
const Mods = preload("res://game/train/train_mods.gd")
const Dom = preload("res://game/train/train_dom.gd")
const Sample = preload("res://game/ui/stop_pick_card.gd")
const Fonts = preload("res://game/ui/ui_fonts.gd")
const Flow = preload("res://game/slice_flow.gd")

class PickScene extends Node:
	var pick: Dictionary = {"spot": "floor", "at": [3, 0]}
	var hover: Dictionary = {}
	func decor_pick(_screen: Vector2) -> Dictionary:
		return pick.duplicate(true)
	func decor_hover(spot: String, at: Array = [], ok: bool = true) -> void:
		hover = {"spot": spot, "at": at, "ok": ok}


func _state() -> Dictionary:
	var g: Dictionary = Sample.sample()[0]
	g["dom"] = Dom.start()
	g["cards"] = []
	g["phase"] = "travel"
	g["food"] = 50.0
	g["lux"] = 50.0
	g["sup"] = 50.0
	return g


func _stock(g: Dictionary, kind: String, n: int = 1, value: Variant = null) -> void:
	var store: Dictionary = Decor.read_store(g)
	for _i: int in n:
		Decor.add_stored(store, kind, value)


func _pane(g: Dictionary, id: String = "guard") -> Pane:
	var scene := PickScene.new()
	add_child_autofree(scene)
	var ui := Pane.new()
	ui.g = g
	ui.car_id = id
	ui.train = scene
	add_child_autofree(ui)
	ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(1280, 720)
	return ui


func _placed(g: Dictionary, kind: String = "chair", at: Array = [3, 0]) -> void:
	_stock(g, kind, 1, Decor.DECOR[kind].get("v"))
	assert_true(Mods.place(g, "guard", kind, Decor.DECOR[kind]["spot"], at, 0)["ok"])


func test_eight_car_panes_have_percent_and_decor_button() -> void:
	var g := _state()
	var t: Dictionary = Sample.sample()[1]
	var pane := CarPane.new()
	add_child_autofree(pane)
	for id: String in Decor.DECOR_CARS:
		pane.show_car({"id": id, "name": Mods.CAR_NAME[id], "comm": Mods.CAR_COMM.get(id, "")}, g, t)
		var button := pane.find_child("DecorButton", true, false) as Button
		assert_not_null(button, id)
		assert_false(button.disabled, id + " open")
		assert_eq((pane.find_child("DecorPercent", true, false) as Label).text, "꾸밈 %d%%" % Data.percent(g, id))
		watch_signals(pane)
		button.pressed.emit()
		assert_signal_emitted_with_parameters(pane, "decor_pressed", [id])
		await wait_process_frames(1)


func test_common_cars_only_draw_the_small_glass_header() -> void:
	var pane := CarPane.new()
	add_child_autofree(pane)
	pane.pin(100)
	for id: String in ["captain", "dining"]:
		pane.show_car({"id": id, "name": Mods.CAR_NAME[id]}, _state(), Sample.sample()[1])
		assert_almost_eq(pane.size.y, CarPane.SMALL_PANE.y * Fonts.K, 0.1)
		assert_not_null(pane.get_node("Glass"))
		for child: String in ["Name", "DecorPercent", "DecorButton"]:
			assert_not_null(pane.find_child(child, true, false))
		for child: String in ["Thermo", "People", "Fold", "Furnish", "Stage"]:
			assert_null(pane.find_child(child, true, false))
		await wait_process_frames(1)


func test_open_paper_and_council_disable_the_button_with_a_reason() -> void:
	var g := _state()
	var pane := CarPane.new()
	add_child_autofree(pane)
	for phase: String in ["paper", "council"]:
		g["phase"] = "council" if phase == "council" else "travel"
		g["cards"] = [{"uid": 1}] if phase == "paper" else []
		pane.show_car({"id": "dining"}, g, Sample.sample()[1])
		assert_true((pane.find_child("DecorButton", true, false) as Button).disabled)
		assert_eq((pane.find_child("DecorLock", true, false) as Label).text, Data.lock_reason(g))
		assert_ne(Data.lock_reason(g), "")
		await wait_process_frames(1)


func test_folded_paper_keeps_the_existing_entry_contract() -> void:
	var g := _state()
	g["cards"] = [{"uid": 1}]
	var pane := CarPane.new()
	add_child_autofree(pane)
	pane.choosing_paper = false
	pane.show_car({"id": "dining"}, g, Sample.sample()[1])
	assert_false((pane.find_child("DecorButton", true, false) as Button).disabled)


func test_top_strip_uses_live_percent_and_used_plus_open_slots() -> void:
	var g := _state()
	_placed(g, "table")
	var m: Dictionary = Data.model(g, "guard")
	assert_eq(m["title"], "경비대칸 꾸미기")
	assert_true(m["subtitle"].ends_with("꾸밈 %d%%" % Data.percent(g, "guard")))
	assert_eq(m["slots"][0]["text"], "바닥 1/8")
	assert_eq(m["slots"][1]["text"], "벽 0/0")
	assert_true(m["slots"][1]["dim"])
	assert_eq(m["slots"][2]["text"], "면 위 0/2")


func test_tabs_count_available_items_and_filter_without_changing_stock() -> void:
	var g := _state()
	_stock(g, "chair", 2)
	_stock(g, "painting", 1, 0.75)
	_stock(g, "can_beans", 3, 0.5)
	assert_eq(Data.model(g, "guard")["counts"], [6, 2, 1, 3, 0, 1])
	assert_eq(Data.model(g, "guard", 1)["cards"].size(), 1)
	assert_eq(Data.model(g, "guard", 2)["cards"][0]["kind"], "painting")
	assert_true(Data.model(g, "guard", 4)["cards"].is_empty())
	assert_true(Data.in_tab({"res": "sup"}, 4))
	assert_eq(Decor.read_store(g)["chair"]["n"], 2)


func test_cards_show_size_light_actual_oldest_tag_value_and_exhausted_kind() -> void:
	var g := _state()
	_placed(g)
	_stock(g, "oil_lamp")
	_stock(g, "can_beans", 1, 0.3)
	_stock(g, "can_beans", 1, 0.5)
	var cards: Dictionary = {}
	for row: Dictionary in Data.model(g, "guard")["cards"]: cards[row["kind"]] = row
	assert_eq(cards["chair"]["detail"], "다 놓음")
	assert_eq(cards["chair"]["count"], "×0")
	assert_eq(cards["oil_lamp"]["detail"], "바닥 · 작음 · 빛")
	assert_eq(cards["can_beans"]["cost"], "놓으면 식량 −0.3")
	assert_eq(cards["can_beans"]["count"], "×2")
	assert_eq(Data.number(0.75), "0.8")
	assert_eq(Data.number(2.0), "2")
	assert_eq(Data.item_name("bottle_spirit"), "술 한 병")
	for kind: String in Decor.DECOR:
		assert_ne(Data.item_name(kind), kind, "a player word for " + kind)


func test_drag_from_card_through_fake_pick_places_once_and_does_not_advance_time() -> void:
	var g := _state()
	_stock(g, "chair")
	var ui := _pane(g)
	var before: Dictionary = g.duplicate(true)
	var start: Vector2 = ui._row.position + Vector2(35, 35) * Fonts.K
	ui.pointer_down(start)
	ui.pointer_move(Vector2(500, 250))
	assert_true(ui.dragging)
	assert_true(ui.train.hover["ok"])
	ui.pointer_up(Vector2(500, 250))
	assert_eq(Decor.items_of(g, "guard").size(), 1)
	assert_eq(Decor.items_of(g, "guard")[0]["at"], [3, 0])
	assert_eq(ui.train.hover["spot"], "")
	for key: String in ["seg", "phase", "clock", "time", "turn", "hour"]:
		assert_eq(g.get(key), before.get(key), key + " unchanged")


func test_bad_drop_uses_rule_reason_red_hover_and_two_second_note() -> void:
	var g := _state()
	_stock(g, "chair")
	var ui := _pane(g)
	ui.train.pick = {"spot": "wall", "at": [4, -1]}
	ui.begin_stock_drag("chair")
	ui._hover(Vector2(500, 250))
	assert_false(ui.train.hover["ok"])
	assert_false(ui.apply_drop(ui.train.pick))
	assert_eq(ui.note_text, "이 물건을 놓는 면이 아니다")
	assert_eq(Decor.read_store(g)["chair"]["n"], 1)
	ui._process(1.99)
	assert_ne(ui.note_text, "")
	ui._process(0.02)
	assert_eq(ui.note_text, "")


func test_empty_pick_rejects_without_consuming_stock() -> void:
	var g := _state()
	_stock(g, "chair")
	var ui := _pane(g)
	ui.begin_stock_drag("chair")
	assert_false(ui.apply_drop({}))
	assert_eq(ui.note_text, Pane.NO_PLACE)
	assert_eq(Decor.read_store(g)["chair"]["n"], 1)


func test_long_press_threshold_selects_and_a_short_tap_does_not() -> void:
	var g := _state()
	_placed(g)
	var ui := _pane(g)
	ui.pointer_down(Vector2(500, 250))
	ui._process(0.34)
	assert_eq(ui.selected, -1)
	ui._process(0.011)
	assert_eq(ui.selected, 0)
	assert_true(ui.rotate_button.visible)
	assert_true(ui.back_button.visible)
	ui.pointer_up(Vector2(500, 250))
	assert_false(ui.dragging)
	assert_eq(Decor.items_of(g, "guard").size(), 1)


func test_motion_before_hold_cancels_pickup() -> void:
	var g := _state()
	_placed(g)
	var ui := _pane(g)
	ui.pointer_down(Vector2(500, 250))
	ui.pointer_move(Vector2(550, 250))
	ui._process(1.0)
	assert_eq(ui.selected, -1)


func test_selected_item_moves_without_needing_another_stock_item() -> void:
	var g := _state()
	_placed(g)
	var ui := _pane(g)
	ui.pick_up(0)
	assert_true(ui.apply_drop({"spot": "floor", "at": [8, 0]}))
	assert_eq(Decor.items_of(g, "guard")[0]["at"], [8, 0])
	assert_eq(Decor.items_of(g, "guard").size(), 1)
	assert_false(Decor.read_store(g).has("chair"))


func test_rotate_button_turns_a_floor_item_in_quarter_turns() -> void:
	var g := _state()
	_placed(g)
	var ui := _pane(g)
	ui.pick_up(0)
	for i: int in 4:
		ui.rotate_button.pressed.emit()
		assert_eq(Decor.items_of(g, "guard")[0]["rot"], (i + 1) % 4)


func test_take_back_button_and_drag_to_store_both_return_the_item() -> void:
	for by_drag: bool in [false, true]:
		var g := _state()
		_placed(g)
		var ui := _pane(g)
		ui.pointer_down(Vector2(500, 250))
		ui._process(0.36)
		if by_drag:
			var target: Vector2 = ui.store_rect().get_center()
			ui.pointer_move(target)
			ui.pointer_up(target)
		else:
			ui.pointer_up(Vector2(500, 250))
			ui.back_button.pressed.emit()
		assert_true(Decor.items_of(g, "guard").is_empty())
		assert_eq(Decor.read_store(g)["chair"]["n"], 1)
		assert_eq(ui.selected, -1)


func test_surface_contract_uses_on_and_grid_coordinates_from_pick() -> void:
	var g := _state()
	_placed(g, "table")
	_stock(g, "can_beans", 1, 0.5)
	var ui := _pane(g)
	ui.begin_stock_drag("can_beans")
	ui.train.pick = {"spot": "surface", "at": [1, 0], "on": 0}
	ui._hover(Vector2(500, 250))
	assert_true(ui.train.hover["ok"])
	assert_true(ui.apply_drop(ui.train.pick))
	assert_eq(Decor.items_of(g, "guard")[1]["on"], 0)
	assert_eq(Decor.items_of(g, "guard")[1]["at"], [1, 0])
	assert_eq(g["food"], 49.5)
	ui.pick_up(0)
	ui.return_selected()
	assert_true(Decor.items_of(g, "guard").is_empty(), "support returns its objects too")
	assert_eq(g["food"], 50.0)


func test_swipe_moves_strip_and_does_not_place_a_card() -> void:
	var g := _state()
	for kind: String in Decor.DECOR:
		_stock(g, kind, 1, Decor.DECOR[kind].get("v"))
	var ui := _pane(g)
	var start: Vector2 = ui._row.position + Vector2(200, 35) * Fonts.K
	ui.pointer_down(start)
	ui.pointer_move(start - Vector2(100, 0) * Fonts.K)
	ui.pointer_up(start - Vector2(100, 0) * Fonts.K)
	assert_gt(ui.scroll, 0.0)
	assert_false(ui.dragging)
	assert_true(Decor.items_of(g, "guard").is_empty())


func test_store_drag_cancel_and_exit_have_no_state_cost() -> void:
	var g := _state()
	_stock(g, "chair")
	var ui := _pane(g)
	var start: Vector2 = ui._row.position + Vector2(35, 35) * Fonts.K
	ui.pointer_down(start)
	ui.pointer_move(Vector2(500, 250))
	ui.pointer_up(ui.store_rect().get_center())
	assert_eq(Decor.read_store(g)["chair"]["n"], 1)
	watch_signals(ui)
	ui.exit_button.pressed.emit()
	assert_signal_emitted(ui, "leave_requested")


func test_mouse_events_reach_the_same_drag_and_drop_path() -> void:
	var g := _state()
	_stock(g, "chair")
	var ui := _pane(g)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = ui._row.position + Vector2(35, 35) * Fonts.K
	ui._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(500, 250)
	ui._input(motion)
	assert_true(ui.dragging)
	press.pressed = false
	press.position = motion.position
	ui._input(press)
	assert_eq(Decor.items_of(g, "guard").size(), 1)


func test_only_wheel_buttons_scroll_the_store() -> void:
	var g := _state()
	for kind: String in Decor.DECOR:
		_stock(g, kind, 1, Decor.DECOR[kind].get("v"))
	var ui := _pane(g)
	var event := InputEventMouseButton.new()
	event.position = ui.store_rect().get_center()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_RIGHT
	ui._input(event)
	assert_eq(ui.scroll, 0.0)
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ui._input(event)
	assert_gt(ui.scroll, 0.0)


func test_flow_button_opens_overlay_exit_restores_pane_and_council_is_locked() -> void:
	var flow := Flow.new()
	flow.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(flow)
	await get_tree().process_frame
	flow._select("dining")
	assert_true((flow.pane.find_child("DecorButton", true, false) as Button).disabled)
	flow.paper.set_folded(true)
	assert_false((flow.pane.find_child("DecorButton", true, false) as Button).disabled)
	(flow.pane.find_child("DecorButton", true, false) as Button).pressed.emit()
	assert_true(is_instance_valid(flow.decor_pane))
	assert_eq(flow.decor_id, "dining")
	flow.decor_pane.exit_button.pressed.emit()
	assert_eq(flow.decor_id, "")
	assert_true(flow.pane.visible)
	flow.train_g["phase"] = "council"
	assert_false(flow.open_decor("dining"))
	await wait_process_frames(1)
