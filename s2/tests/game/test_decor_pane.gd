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
const TurnCard = preload("res://game/ui/turn_card.gd")
const Grid = preload("res://game/train/decor_grid.gd")

class PickScene extends Node:
	var pick: Dictionary = {}
	var hover: Dictionary = {}
	var canvas := Transform2D.IDENTITY
	var cell_width: float = 60.0
	var last_screen := Vector2.ZERO
	func decor_pick(screen: Vector2) -> Dictionary:
		last_screen = screen
		if not pick.is_empty(): return pick.duplicate(true)
		var local: Vector2 = canvas.affine_inverse() * screen
		var cell := Vector2i(((local - Vector2(290, 215)) / Vector2(cell_width, 60)).floor())
		if cell.x < 0 or cell.x >= Grid.NX or cell.y < 0 or cell.y >= Grid.NZ: return {}
		return {"spot": "floor", "at": [cell.x, cell.y]}
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
	scene.canvas = ui.get_global_transform_with_canvas()
	return ui


func _cell(at: Array, width: float = 60.0) -> Vector2:
	return Vector2(290 + (int(at[0]) + 0.5) * width, 245 + int(at[1]) * 60)


func _touch(ui: Pane, index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = ui.get_global_transform_with_canvas() * pos
	event.pressed = pressed
	ui._input(event)


func _drag(ui: Pane, index: int, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = ui.get_global_transform_with_canvas() * pos
	ui._input(event)


func _transformed(ui: Pane) -> void:
	ui.position = Vector2(83, 41)
	ui.scale = Vector2(1.1, 0.9)
	ui.train.canvas = ui.get_global_transform_with_canvas()


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
		for child: String in ["Name", "DecorPercent", "DecorButton", "Fold"]:
			assert_not_null(pane.find_child(child, true, false))
		for child: String in ["Thermo", "People", "Furnish", "Stage"]:
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
	_stock(g, "painting", 1, 0.75)
	var cards: Dictionary = {}
	for row: Dictionary in Data.model(g, "guard")["cards"]: cards[row["kind"]] = row
	assert_eq(cards["chair"]["detail"], "다 놓음")
	assert_eq(cards["chair"]["count"], "×0")
	assert_eq(cards["oil_lamp"]["detail"], "바닥 · 작음 · 빛")
	assert_eq(cards["can_beans"]["cost"], "놓으면 식량 −0.3")
	assert_eq(cards["can_beans"]["count"], "×2")
	assert_eq(cards["painting"]["cost"], "놓으면 사치품 −0.75")
	assert_eq(Data.number(0.75), "0.75")
	assert_eq(Data.number(0.5), "0.5")
	assert_eq(Data.number(1.0), "1")
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


## The first free floor cell other than [0, 0], in the order the pane walks (rows, then columns).
func _first_free_after_origin() -> Array:
	var cells: Dictionary = Grid.of("guard")
	for z: int in Grid.NZ:
		for x: int in Grid.NX:
			if cells["floor"][z][x] == "." and [x, z] != [0, 0]: return [x, z]
	return []


func test_old_save_gets_first_free_cell_then_touch_move_and_take_back() -> void:
	var free: Array = _first_free_after_origin()
	var old := _state()
	_placed(old, "chair", [0, 0])
	_stock(old, "chair")
	assert_true(Mods.place(old, "guard", "chair", "floor")["ok"])
	var g: Dictionary = JSON.parse_string(JSON.stringify(old))
	Decor.migrate(g)
	var again: Dictionary = g.duplicate(true)
	var ui := _pane(g)
	var other := _pane(again)
	assert_eq(Decor.items_of(g, "guard")[1]["at"], free, "row then column; the saved [0.0, 0.0] cell stays occupied")
	assert_eq(g, again, "same save opens in the same order")
	assert_eq(Decor.items_of(g, "guard")[0]["at"], [0.0, 0.0])
	assert_eq(ui.placed_at({"spot": "floor", "at": [0, 0]}), 0, "a cell read back from JSON is still found")
	# Reach the recovered item with a coordinate-based picker in the viewport.
	ui.train.cell_width = 20.0
	_touch(ui, 7, _cell(free, 20), true)
	ui._process(0.36)
	assert_eq(ui.selected, 1)
	_drag(ui, 7, _cell([8, 0], 20))
	_touch(ui, 7, _cell([8, 0], 20), false)
	assert_eq(Decor.items_of(g, "guard")[1]["at"], [8, 0])
	ui.rotate_button.pressed.emit()
	assert_eq(Decor.items_of(g, "guard")[1]["rot"], 1)
	ui.back_button.pressed.emit()
	assert_eq(Decor.items_of(g, "guard").size(), 1)
	assert_eq(Decor.read_store(g)["chair"]["n"], 1)
	assert_eq(other.selected, -1)


func test_legacy_wall_without_a_rule_slot_returns_its_exact_value() -> void:
	var g := _state()
	g["dom"]["furnish"]["guard"] = {"work": 0, "jobs": [], "furnPts": 0, "tier": 0, "best": 0,
		"items": [{"kind": "painting", "size": "small", "v": 0.75}]}
	Decor.migrate(g)
	var ui := _pane(g)
	assert_true(Decor.items_of(g, "guard").is_empty())
	assert_eq(Decor.read_store(g)["painting"]["n"], 1)
	assert_eq(Decor.oldest(Decor.read_store(g)["painting"])["v"], 0.75)
	assert_eq(g["lux"], 50.75)
	assert_eq(ui.note_text, "놓을 자리가 없어 창고로 옮겼다.")
	ui.show_car(g, "guard", ui.train)
	assert_eq(g["lux"], 50.75, "opening again does not refund twice")


func test_legacy_support_and_surface_keep_their_link_and_resource() -> void:
	var g := _state()
	_stock(g, "table")
	assert_true(Mods.place(g, "guard", "table", "floor")["ok"])
	_stock(g, "record", 1, 0.5)
	assert_true(Mods.place(g, "guard", "record", "surface", null, null, 0)["ok"])
	var before: float = g["lux"]
	var ui := _pane(g)
	assert_eq(Decor.items_of(g, "guard")[0]["at"], [0, 0])
	assert_eq(Decor.items_of(g, "guard")[1]["at"], [0, 0])
	assert_eq(Decor.items_of(g, "guard")[1]["on"], 0)
	assert_eq(g["lux"], before)
	ui.pick_up(0)
	ui.return_selected()
	assert_true(Decor.items_of(g, "guard").is_empty())
	assert_eq(g["lux"], before + 0.5)


func test_screen_touch_stock_drop_uses_transformed_finger_and_last_preview() -> void:
	var g := _state()
	_stock(g, "chair")
	var ui := _pane(g)
	_transformed(ui)
	_touch(ui, 7, ui._row.position + Vector2(35, 35) * Fonts.K, true)
	_drag(ui, 7, _cell([3, 0]))
	assert_eq(ui.train.hover["at"], [3, 0])
	_drag(ui, 7, _cell([8, 0]))
	assert_eq(ui.train.hover["at"], [8, 0])
	assert_true(ui.train.hover["ok"])
	assert_almost_eq(ui.train.last_screen, ui.get_global_transform_with_canvas() * _cell([8, 0]), Vector2.ONE * 0.01)
	_touch(ui, 7, _cell([8, 0]), false)
	assert_eq(Decor.items_of(g, "guard")[0]["at"], [8, 0])
	assert_false(ui._ghost.visible)
	assert_eq(ui.train.hover["spot"], "")


func _two_finger_drop(direction: int, primary_first: bool) -> void:
	var g := _state()
	_placed(g)
	var ui := _pane(g)
	_transformed(ui)
	var start := _cell([3, 0])
	_touch(ui, 7, start, true)
	ui._process(0.36)
	_touch(ui, 2, start + Vector2(100, 0), true)
	_drag(ui, 2, start + Vector2(0, direction * 100))
	assert_eq(Decor.items_of(g, "guard")[0]["rot"], 1 if direction > 0 else 3)
	var target := start + Vector2(120, 0)
	_drag(ui, 7, target)
	assert_almost_eq(ui._pos, target, Vector2.ONE * 0.01)
	assert_eq(ui.train.hover["at"], [5, 0], "primary keeps moving during the twist")
	assert_almost_eq(ui._ghost.position, target - Vector2(31 * Fonts.K, 62 * Fonts.K + ui.finger_lift()), Vector2.ONE * 0.01)
	var shown: Array = ui.train.hover["at"].duplicate()
	var rotation: int = ui.drag_rot
	if primary_first:
		_touch(ui, 7, target, false)
		assert_false(ui.dragging, "primary release ends the gesture")
		var snapshot: Dictionary = g.duplicate(true)
		_drag(ui, 2, ui.store_rect().get_center())
		_touch(ui, 2, ui.store_rect().get_center(), false)
		assert_eq(g, snapshot, "remaining finger cannot move, rotate or return the item")
	else:
		_touch(ui, 2, start + Vector2(0, direction * 100), false)
		assert_true(ui.dragging)
		_drag(ui, 7, _cell([8, 0]))
		shown = ui.train.hover["at"].duplicate()
		_touch(ui, 7, _cell([8, 0]), false)
	assert_eq(Decor.items_of(g, "guard")[0]["at"], shown)
	assert_eq(Decor.items_of(g, "guard")[0]["rot"], rotation)
	assert_false(ui._ghost.visible)
	assert_eq(ui.train.hover["spot"], "")
	assert_true(ui._touches.is_empty())


func test_clockwise_twist_primary_released_first() -> void:
	_two_finger_drop(1, true)


func test_counterclockwise_twist_primary_released_first() -> void:
	_two_finger_drop(-1, true)


func test_clockwise_twist_primary_released_last() -> void:
	_two_finger_drop(1, false)


func test_counterclockwise_twist_primary_released_last() -> void:
	_two_finger_drop(-1, false)


func test_primary_can_drag_to_store_while_second_finger_is_down() -> void:
	var g := _state()
	_placed(g)
	var ui := _pane(g)
	_touch(ui, 7, _cell([3, 0]), true)
	ui._process(0.36)
	_touch(ui, 2, _cell([3, 0]) + Vector2(100, 0), true)
	var target := ui.store_rect().get_center()
	_drag(ui, 7, target)
	assert_almost_eq(ui._pos, target, Vector2.ONE * 0.01)
	assert_eq(ui.train.hover["spot"], "", "store preview is cleared before release")
	_touch(ui, 7, target, false)
	_touch(ui, 2, _cell([3, 0]), false)
	assert_true(Decor.items_of(g, "guard").is_empty())
	assert_eq(Decor.read_store(g)["chair"]["n"], 1)


## A whole card state laid as test_turn_card.gd lays it: tail_cold's second way,
## 「담요를 나눈다」, costs one lux. With 1.0 lux it is payable; a placed record
## (0.5) leaves too little.
const LUX_CASE: String = "travel/card-0/6/tail_cold/first"


func _card_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/card_vectors.json"))


func _lux_state() -> Dictionary:
	var whole: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/train_vectors.json"))["points"][3]["state"]
	var g: Dictionary = whole.duplicate(true)
	for row: Dictionary in _card_data()["cases"]:
		if str(row["name"]) == LUX_CASE:
			g.merge((row["state"] as Dictionary).duplicate(true), true)
			g["cards"] = [(row["card"] as Dictionary).duplicate(true)]
	g["dom"] = Dom.start()
	g["phase"] = "travel"
	g["lux"] = 1.0
	_placed(g, "table")
	_stock(g, "record", 1, 0.5)
	return g


func _lux_uid(g: Dictionary) -> int:
	return int((g["cards"] as Array)[0]["uid"])


func _lux_key(card: TurnCard) -> Button:
	return card.find_child("Key_2", true, false) as Button


func test_unfold_rechecks_locked_choice_after_decor_return() -> void:
	var g := _lux_state()
	assert_true(Mods.place(g, "guard", "record", "surface", [0, 0], 0, 0)["ok"])
	var card := TurnCard.new()
	add_child_autofree(card)
	card.show_card(g, _card_data()["tables"], _lux_uid(g))
	assert_ne(_lux_key(card).tooltip_text, "")
	card.set_folded(true)
	var ui := _pane(g)
	ui.pick_up(1)
	ui.return_selected()
	assert_eq(g["lux"], 1.0)
	card.set_folded(false)
	assert_eq(card.uid, _lux_uid(g))
	assert_false(card.folded)
	assert_eq(_lux_key(card).tooltip_text, "")
	watch_signals(card)
	_lux_key(card).pressed.emit()
	assert_signal_emitted(card, "chose", "the stale lock no longer refuses a payable choice")


func test_unfold_rechecks_open_choice_after_decor_placement() -> void:
	var g := _lux_state()
	var card := TurnCard.new()
	add_child_autofree(card)
	card.show_card(g, _card_data()["tables"], _lux_uid(g))
	assert_eq(_lux_key(card).tooltip_text, "")
	card.set_folded(true)
	var ui := _pane(g)
	ui.begin_stock_drag("record")
	assert_true(ui.apply_drop({"spot": "surface", "at": [0, 0], "on": 0}))
	assert_eq(g["lux"], 0.5)
	card.set_folded(false)
	assert_eq(card.uid, _lux_uid(g))
	assert_ne(_lux_key(card).tooltip_text, "")
	watch_signals(card)
	_lux_key(card).pressed.emit()
	assert_signal_not_emitted(card, "chose", "the newly unaffordable choice is locked")


func test_leaving_decor_refreshes_both_lux_locks_and_keeps_fold_and_uid() -> void:
	var flow := Flow.new()
	flow.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(flow)
	await get_tree().process_frame
	var g := _lux_state()
	flow._take(g)
	flow._show_paper()
	flow._select("guard", false)
	var card := flow.paper as TurnCard
	card.set_folded(true)
	assert_true(flow.open_decor("guard"))
	flow.decor_pane.begin_stock_drag("record")
	assert_true(flow.decor_pane.apply_drop({"spot": "surface", "at": [0, 0], "on": 0}))
	flow.leave_decor()
	assert_true(card.folded)
	assert_eq(card.uid, _lux_uid(g))
	# The folded paper is refilled as it opens (turn_card set_folded), not under the fold.
	card.set_folded(false)
	assert_ne(_lux_key(card).tooltip_text, "")
	card.set_folded(true)
	assert_true(flow.open_decor("guard"))
	flow.decor_pane.pick_up(1)
	flow.decor_pane.return_selected()
	flow.leave_decor()
	assert_true(card.folded)
	assert_eq(card.uid, _lux_uid(g))
	card.set_folded(false)
	assert_eq(_lux_key(card).tooltip_text, "")
	await wait_process_frames(1)


func test_exit_council_and_open_card_cancel_both_drag_origins_and_restore_ui() -> void:
	var flow := Flow.new()
	flow.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(flow)
	await get_tree().process_frame
	flow.train_g["dom"] = Dom.start()
	_stock(flow.train_g, "chair", 2)
	assert_true(Mods.place(flow.train_g, "guard", "chair", "floor", [3, 0], 0)["ok"])
	flow._select("guard", false)
	for why: String in ["exit", "council", "paper"]:
		for from_stock: bool in [true, false]:
			flow.train_g["phase"] = "travel"
			flow.paper.set_folded(true)
			assert_true(flow.open_decor("guard"))
			var ui := flow.decor_pane as Pane
			var hidden: Array = flow._decor_hidden.duplicate()
			for node: CanvasItem in hidden: assert_false(node.visible)
			var before: Dictionary = flow.train_g.duplicate(true)
			if from_stock:
				_touch(ui, 7, ui._row.position + Vector2(35, 35) * Fonts.K, true)
				_drag(ui, 7, Vector2(500, 250))
			else:
				ui.pick_up(0)
			assert_true(ui.dragging)
			assert_true(ui._ghost.visible)
			match why:
				"exit": ui.exit_button.pressed.emit()
				"council":
					flow.train_g["phase"] = "council"
					flow._process(0.0)
				"paper": flow.paper.set_folded(false)
			assert_eq(flow.decor_id, "")
			assert_null(flow.decor_pane)
			assert_eq(flow.train.decorating(), "")
			assert_false(ui.dragging)
			assert_false(ui._ghost.visible)
			assert_eq(ui.selected, -1)
			assert_false(ui._down)
			assert_true(ui._touches.is_empty())
			assert_eq(flow.train_g["dom"], before["dom"], "no placement, loss or duplicate return")
			assert_eq(flow.sel, "guard")
			assert_true(flow.pane.visible)
			assert_true(flow._decor_hidden.is_empty())
			for node: CanvasItem in hidden: assert_true(node.visible)
			await wait_process_frames(1)


func test_board_replacement_and_stage_clear_leave_decor_first() -> void:
	var flow := Flow.new()
	flow.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(flow)
	await get_tree().process_frame
	flow.paper.set_folded(true)
	assert_true(flow.open_decor("guard"))
	var ui := flow.decor_pane as Pane
	ui.begin_stock_drag("chair")
	var replacement: Dictionary = flow.train_g.duplicate(true)
	flow._take(replacement)
	assert_true(is_same(flow.train_g, replacement))
	assert_eq(flow.decor_id, "")
	assert_false(ui._ghost.visible)
	assert_eq(flow.train.decorating(), "")
	assert_true(flow.open_decor("guard"))
	ui = flow.decor_pane as Pane
	ui.begin_stock_drag("chair")
	var old_train = flow.train
	flow._clear_stage()
	assert_eq(flow.decor_id, "")
	assert_null(flow.train)
	assert_eq(old_train.decorating(), "", "exit occurs before the old train is freed")
	assert_false(ui._ghost.visible)
	await wait_process_frames(1)


func test_selected_plate_toggles_off_for_common_and_ordinary_cars() -> void:
	var flow := Flow.new()
	flow.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(flow)
	await get_tree().process_frame
	for id: String in ["captain", "dining", "guard"]:
		flow._select("", false)
		for expected: String in [id, ""]:
			var event := InputEventScreenTouch.new()
			event.index = 3
			event.position = Vector2(5, 5)
			event.pressed = true
			flow._plate_input(event, id)
			event.pressed = false
			flow._plate_input(event, id)
			assert_eq(flow.sel, expected)
			assert_eq(flow.pane.visible, expected != "")
		flow._process(0.0)
		var shown: int = 0
		for plate: Control in flow.plates.get_children():
			if plate.visible: shown += 1
		assert_gt(shown, 1, "other cars are reachable again")
	await wait_process_frames(1)


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
