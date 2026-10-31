extends Control
## Domestic controls over the train's decorating view. No turn or clock is advanced here.

signal leave_requested
signal changed

const Data = preload("res://game/ui/decor_ui_data.gd")
const Paint = preload("res://game/ui/decor_paint.gd")
const Fonts = preload("res://game/ui/ui_fonts.gd")
const Bake = preload("res://game/ui/ui_bake.gd")
const Decor = preload("res://game/train/train_decor.gd")
const Mods = preload("res://game/train/train_mods.gd")
const Grid = preload("res://game/train/decor_grid.gd")
const K: float = Fonts.K
const TOP_CSS: float = 46.0
const STORE_CSS: float = 134.0
const CARD := Vector2(70.0, 92.0)
const PITCH: float = 77.0
const HOLD_SECONDS: float = 0.35
const NOTE_SECONDS: float = 2.0
const NO_PLACE := "놓을 자리를 골라 주세요."

var g: Dictionary = {}
var car_id: String = ""
var train = null
var data: Dictionary = {}
var tab: int = 0
var scroll: float = 0.0
var selected: int = -1
var drag_kind: String = ""
var drag_rot: int = 0
var dragging: bool = false
var note_text: String = ""
var note_left: float = 0.0
var exit_button: Button
var rotate_button: Button
var back_button: Button
var _row: Control
var _ghost: Control
var _note: Label
var _frame: Bake.Batch
var _card_shapes: Bake.Batch
var _tabs: Array[Rect2] = []
var _slot_boxes: Array[Rect2] = []
var _down: bool = false
var _finger: int = -1
var _start := Vector2.ZERO
var _pos := Vector2.ZERO
var _origin: String = ""
var _candidate: String = ""
var _candidate_index: int = -1
var _held: float = 0.0
var _moved: bool = false
var _scroll_start: float = 0.0
var _touches: Dictionary = {}
var _twist: float = 0.0


func _ready() -> void:
	name = "DecorPane"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row = Control.new()
	_row.name = "Cards"
	_row.clip_contents = true
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.draw.connect(_draw_cards)
	add_child(_row)
	exit_button = _button("Exit", "나가기", func() -> void: leave_requested.emit())
	rotate_button = _button("Rotate", "↻ 돌리기", rotate_selected)
	back_button = _button("TakeBack", "↧ 창고로", return_selected)
	_ghost = Control.new()
	_ghost.name = "DragGhost"
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.draw.connect(_draw_ghost)
	_ghost.visible = false
	add_child(_ghost)
	_note = Fonts.label("", Fonts.WORD, 400, 13.0, Paint.INK2)
	_note.name = "Note"
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.031, 0.043, 0.059, 0.84)
	box.set_corner_radius_all(int(round(4.0 * K)))
	box.content_margin_left = 10.0 * K
	box.content_margin_right = 10.0 * K
	_note.add_theme_stylebox_override("normal", box)
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.custom_minimum_size.y = 26.0 * K
	_note.visible = false
	add_child(_note)
	resized.connect(_layout)
	refresh()
	_restore_positions()


func show_car(g0: Dictionary, id: String, scene: Node) -> void:
	g = g0
	car_id = id
	train = scene
	refresh()
	if is_node_ready(): _restore_positions()


## S1 saves need not carry positions. Resolve them only when this S2 pane opens.
## Existing cells stay put; supports precede surface items, both in saved order.
func _restore_positions() -> void:
	if car_id == "" or Grid.of(car_id).is_empty(): return
	var repaired: bool = false
	var returned: bool = false
	for surface: bool in [false, true]:
		var pending: Array = Decor.items_of(g, car_id).duplicate()
		for item: Dictionary in pending:
			if item.has("at") or (Decor.spot_of(item) == "surface") != surface: continue
			var index: int = Decor.items_of(g, car_id).find(item)
			if index < 0: continue # Its support may already have returned it.
			var spot: String = Decor.spot_of(item)
			var trial: Dictionary = _placement_trial(index)
			var on: Variant = item.get("on")
			if on != null and int(on) > index: on = int(on) - 1
			var found: bool = false
			for at: Array in _legacy_cells(spot):
				var pick: Dictionary = {"spot": spot, "at": at}
				if item.has("on"): pick["on"] = item["on"]
				if placed_at(pick) >= 0: continue
				if Mods.can_place(trial, car_id, item["kind"], spot, at, item.get("rot", 0), on)["ok"]:
					item["at"] = at.duplicate()
					found = true
					repaired = true
					break
			if not found:
				var result: Dictionary = Mods.take_back(g, car_id, index)
				if result["ok"]:
					returned = true
					repaired = true
				else:
					show_note(String(result["why"]))
	if repaired:
		refresh()
		changed.emit()
	if returned: show_note("놓을 자리가 없어 창고로 옮겼어요.")


## Floor rows then columns; back wall left to right, then each end wall;
## surface slots left to right on the saved support. Only grid '.' cells are free.
func _legacy_cells(spot: String) -> Array:
	var cells: Dictionary = Grid.of(car_id)
	var result: Array = []
	match spot:
		"floor":
			for z: int in Grid.NZ:
				for x: int in Grid.NX:
					if cells["floor"][z][x] == ".": result.append([x, z])
		"wall":
			for x: int in Grid.NX:
				if cells["back_wall"][x] == ".": result.append([x, -1])
			for side: int in 2:
				for z: int in 2:
					if cells["end_walls"][side * 2 + z] == ".": result.append([-1 if side == 0 else Grid.NX, z])
		"surface":
			for x: int in int(Decor.DECOR_SLOTS[Decor.tier_of(g, car_id)]["surface"]):
				result.append([x, 0])
	return result


func refresh() -> void:
	if car_id == "" or not is_instance_valid(_row):
		return
	data = Data.model(g, car_id, tab)
	_layout()


func _button(node_name: String, word: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = word
	button.focus_mode = Control.FOCUS_NONE
	Fonts.style(button, Fonts.WORD, 500, 11.5, Paint.INK)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(action)
	add_child(button)
	return button


func store_rect() -> Rect2:
	return Rect2(Vector2(10.0, size.y / K - STORE_CSS) * K, Vector2(size.x / K - 20.0, STORE_CSS) * K)


func _layout() -> void:
	if not is_instance_valid(_row) or data.is_empty():
		return
	var w: float = size.x / K
	var y: float = store_rect().position.y / K
	exit_button.position = Vector2(12, 10) * K
	exit_button.size = Vector2(78, 30) * K
	rotate_button.position = Vector2(w - 174, 89) * K
	rotate_button.size = Vector2(76, 24) * K
	back_button.position = Vector2(w - 94, 89) * K
	back_button.size = Vector2(76, 24) * K
	rotate_button.visible = selected >= 0
	back_button.visible = selected >= 0
	rotate_button.disabled = selected >= 0 and Decor.spot_of(Decor.items_of(g, car_id)[selected]) != "floor"
	_row.position = Vector2(20, y + 36) * K
	_row.size = Vector2(w - 40, CARD.y + 2) * K
	scroll = clampf(scroll, 0.0, max_scroll())
	_frame = Bake.Batch.new()
	_frame.polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, TOP_CSS * K), Vector2(0, TOP_CSS * K)]),
		PackedColorArray([Color(0.039, 0.047, 0.059, 0.5), Color(0.039, 0.047, 0.059, 0.5), Color(0.039, 0.047, 0.059, 0), Color(0.039, 0.047, 0.059, 0)]))
	Paint.glass(_frame, Rect2(12, 10, 78, 30), 15)
	_frame.polyline(PackedVector2Array([Vector2(28, 19) * K, Vector2(22, 25) * K, Vector2(28, 31) * K]), PackedColorArray([Paint.INK]), 1.6 * K)
	Paint.glass(_frame, Rect2(10, y, w - 20, STORE_CSS - 2), 10)
	_frame.rect(Rect2(Vector2(10, y + 27) * K, Vector2(w - 20, 0.5) * K), Paint.HAIR)
	_slot_boxes.resize(3)
	var right: float = w - 12
	for i: int in range(2, -1, -1):
		var slot: Dictionary = data["slots"][i]
		var count: String = "%d/%d" % [slot["used"], slot["total"]]
		var label_w: float = Fonts.face(Fonts.WORD).get_string_size(slot["word"], HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.size(10.5)).x / K
		var count_w: float = Fonts.face(Fonts.NUMBER, 600).get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.size(13.5)).x / K
		var width: float = label_w + count_w + 23
		right -= width
		_slot_boxes[i] = Rect2(right, 10, width, 24)
		Paint.glass(_frame, _slot_boxes[i], 12)
		right -= 5
	_tabs.clear()
	var x: float = 20.0
	for i: int in Data.TABS.size():
		var width: float = 53.0 if i < 4 else 63.0
		_tabs.append(Rect2(x * K, y * K, width * K, 27 * K))
		if i == tab:
			_frame.rect(Rect2(Vector2(x + 5, y + 26) * K, Vector2(width - 10, 1.5) * K), Paint.ACCENT)
		x += width
	if selected >= 0:
		Paint.glass(_frame, Rect2(w - 178, 86, 164, 30), 14)
	_rebuild_cards()
	queue_redraw()


func max_scroll() -> float:
	return maxf(0.0, float(data.get("cards", []).size()) * PITCH - 7.0 - _row.size.x / K)


func _rebuild_cards() -> void:
	_card_shapes = Bake.Batch.new()
	for i: int in data["cards"].size():
		var card: Dictionary = data["cards"][i]
		var x: float = i * PITCH - scroll
		var alpha: float = 0.4 if int(card["n"]) == 0 else (0.35 if dragging and selected < 0 and card["kind"] == drag_kind else 1.0)
		Paint.rounded(_card_shapes, Rect2(x, 0, CARD.x, CARD.y), 7, Color(0, 0, 0, 0.42 * alpha))
		var border := preload("res://game/ui/glass_parts.gd").outline(Rect2(Vector2(x, 0) * K, CARD * K), 7 * K)
		border.append(border[0])
		_card_shapes.polyline(border, PackedColorArray([Color(Paint.HAIR, alpha * Paint.HAIR.a)]), K)
		Paint.icon(_card_shapes, card["kind"], card["spot"], Vector2(x + 19, 7), 32, Color(Paint.INK, alpha * 0.92))
		if card["cost"] != "":
			Paint.rounded(_card_shapes, Rect2(x, 77, CARD.x, 15), 5, Color(Paint.ACCENT, 0.16 * alpha))
	_row.queue_redraw()


func _draw() -> void:
	if _frame == null or data.is_empty():
		return
	_frame.draw(self)
	var w: float = size.x / K
	var title_width: float = maxf(150, w - 448)
	Paint.text(self, data["title"], Rect2((w - title_width) * 0.5, 5, title_width, 22), 16, Paint.INK, false, HORIZONTAL_ALIGNMENT_CENTER, 500)
	var split: int = String(data["subtitle"]).rfind(" ") + 1
	var prefix: String = String(data["subtitle"]).substr(0, split)
	var percent: String = String(data["subtitle"]).substr(split)
	var prefix_w: float = Fonts.face(Fonts.WORD).get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.size(11)).x / K
	var percent_w: float = Fonts.face(Fonts.NUMBER, 600).get_string_size(percent, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.size(13)).x / K
	var subtitle_x: float = (w - prefix_w - percent_w) * 0.5
	Paint.text(self, prefix, Rect2(subtitle_x, 27, prefix_w + 0.1, 16), 11, Paint.INK2)
	Paint.text(self, percent, Rect2(subtitle_x + prefix_w, 27, percent_w + 0.1, 16), 13, Paint.ACCENT, true, HORIZONTAL_ALIGNMENT_LEFT, 600)
	for i: int in 3:
		var slot: Dictionary = data["slots"][i]
		var box: Rect2 = _slot_boxes[i]
		var count: String = "%d/%d" % [slot["used"], slot["total"]]
		var label_w: float = Fonts.face(Fonts.WORD).get_string_size(slot["word"], HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.size(10.5)).x / K
		var alpha: float = 0.55 if slot["dim"] else 1.0
		Paint.text(self, slot["word"], Rect2(box.position + Vector2(9, 0), Vector2(label_w + 0.1, 24)), 10.5, Color(Paint.INK2, Paint.INK2.a * alpha))
		Paint.text(self, count, Rect2(box.position + Vector2(14 + label_w, 0), Vector2(box.size.x - label_w - 23 + 0.1, 24)), 13.5, Color(Paint.INK, alpha), true, HORIZONTAL_ALIGNMENT_LEFT, 600)
	for i: int in _tabs.size():
		var rect: Rect2 = _tabs[i]
		Paint.text(self, "%s %d" % [Data.TABS[i], data["counts"][i]], Rect2(rect.position / K, rect.size / K), 11.5, Paint.INK if i == tab else Paint.INK3, false, HORIZONTAL_ALIGNMENT_CENTER)
	var hint_x: float = _tabs[-1].end.x / K + 7
	var hint_w: float = w - hint_x - 20
	var hint_y: float = store_rect().position.y / K + 1
	Paint.text(self, Data.HINT, Rect2(hint_x, hint_y, hint_w, 23), 10, Paint.INK3, false, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_cards() -> void:
	if _card_shapes == null:
		return
	_card_shapes.draw(_row)
	# Group equal font sizes so neighboring cards can batch their glyphs.
	for field: String in ["name", "detail", "cost", "count"]:
		for i: int in data["cards"].size():
			var card: Dictionary = data["cards"][i]
			var x: float = i * PITCH - scroll
			if x + CARD.x < 0 or x > _row.size.x / K:
				continue
			var alpha: float = 0.4 if card["n"] == 0 else (0.35 if dragging and selected < 0 and card["kind"] == drag_kind else 1.0)
			match field:
				"name": Paint.text(_row, card[field], Rect2(x + 3, 43, 64, 17), 10.5, Color(Paint.INK, alpha), false, HORIZONTAL_ALIGNMENT_CENTER)
				"detail": Paint.text(_row, card[field], Rect2(x + 2, 62, 66, 12), 8.5, Color(Paint.INK3, Paint.INK3.a * alpha), false, HORIZONTAL_ALIGNMENT_CENTER)
				"cost": Paint.text(_row, card[field], Rect2(x + 2, 77, 66, 15), 8.5, Color(Paint.ACCENT, alpha), false, HORIZONTAL_ALIGNMENT_CENTER, 400, 7.0)
				"count": Paint.text(_row, card[field], Rect2(x + 40, 2, 25, 15), 12, Color(Paint.INK2, Paint.INK2.a * alpha), true, HORIZONTAL_ALIGNMENT_RIGHT, 600)
	var edge := Bake.Batch.new()
	for side: int in 2:
		if (side == 0 and scroll <= 0) or (side == 1 and scroll >= max_scroll()):
			continue
		var x: float = 0.0 if side == 0 else _row.size.x / K - 22
		var points := PackedVector2Array([Vector2(x, 0), Vector2(x + 22, 0), Vector2(x + 22, 94), Vector2(x, 94)])
		for i: int in points.size(): points[i] *= K
		var dark := Color(0.047, 0.059, 0.071, 0.95)
		var clear := Color(dark, 0)
		edge.polygon(points, PackedColorArray([dark, clear, clear, dark] if side == 0 else [clear, dark, dark, clear]))
	edge.draw(_row)


func _draw_ghost() -> void:
	if drag_kind == "": return
	var batch := Bake.Batch.new()
	Paint.rounded(batch, Rect2(0, 5, 62, 62), 9, Color(0, 0, 0, 0.4))
	Paint.rounded(batch, Rect2(0, 0, 62, 62), 9, Paint.ACCENT)
	Paint.rounded(batch, Rect2(1.5, 1.5, 59, 59), 8, Color(0.086, 0.106, 0.125, 0.92))
	Paint.icon(batch, drag_kind, Decor.DECOR[drag_kind]["spot"], Vector2(13, 13), 36)
	batch.draw(_ghost)


func finger_lift() -> float:
	var dpi: float = float(DisplayServer.screen_get_dpi())
	if dpi <= 0: dpi = 96.0
	# DPI is physical pixels; input and ghost positions use this viewport's pixels.
	var physical_scale: float = maxf(get_viewport().get_screen_transform().get_scale().y, 0.01)
	return 0.6 / 2.54 * dpi / physical_scale


func pick_at(pos: Vector2) -> Dictionary:
	if not is_instance_valid(train): return {}
	return train.decor_pick(get_global_transform_with_canvas() * pos)


## Cells by value: a save read back from JSON holds 0.0 where the grid says 0,
## and Array == does not take the one for the other.
static func _same_at(a: Variant, b: Variant) -> bool:
	if not (a is Array and b is Array) or (a as Array).size() != (b as Array).size(): return false
	for i: int in (a as Array).size():
		if float(a[i]) != float(b[i]): return false
	return true


func placed_at(pick: Dictionary) -> int:
	if pick.is_empty(): return -1
	var items: Array = Decor.items_of(g, car_id)
	for i: int in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[i]
		if Decor.spot_of(item) == pick.get("spot") and _same_at(item.get("at", []), pick.get("at", [])) and (Decor.spot_of(item) != "surface" or item.get("on") == pick.get("on")):
			return i
	return -1


func pointer_down(pos: Vector2, finger: int = -1) -> void:
	if _down: return
	for button: Button in [exit_button, rotate_button, back_button]:
		if button.visible and Rect2(button.position, button.size).has_point(pos):
			if not button.disabled: button.pressed.emit()
			return
	for i: int in _tabs.size():
		if _tabs[i].has_point(pos):
			tab = i
			scroll = 0
			refresh()
			return
	_down = true
	_finger = finger
	_start = pos
	_pos = pos
	_held = 0
	_moved = false
	_candidate = ""
	_candidate_index = -1
	if store_rect().has_point(pos):
		_origin = "store"
		_scroll_start = scroll
		var local: Vector2 = (pos - _row.position) / K
		var index: int = int(floor((local.x + scroll) / PITCH))
		if local.y >= 0 and local.y <= CARD.y and index >= 0 and index < data["cards"].size() and fposmod(local.x + scroll, PITCH) <= CARD.x:
			var card: Dictionary = data["cards"][index]
			if int(card["n"]) > 0: _candidate = card["kind"]
	else:
		_origin = "scene"
		_candidate_index = placed_at(pick_at(pos))
		if selected >= 0 and _candidate_index == selected:
			pick_up(selected)


func pointer_move(pos: Vector2, finger: int = -1) -> void:
	if not _down or finger != _finger: return
	_pos = pos
	var delta: Vector2 = (pos - _start) / K
	if delta.length() > 6.0:
		_moved = true
		if _origin == "store" and not dragging:
			if absf(delta.x) > absf(delta.y) and store_rect().has_point(pos):
				_origin = "scroll"
			elif _candidate != "":
				begin_stock_drag(_candidate)
	if _origin == "scroll":
		scroll = clampf(_scroll_start - delta.x, 0.0, max_scroll())
		_rebuild_cards()
	if dragging: _hover(pos)


func pointer_up(pos: Vector2, finger: int = -1) -> void:
	if not _down or finger != _finger: return
	if dragging and (selected < 0 or _moved):
		if store_rect().has_point(pos):
			if selected >= 0: return_selected()
		else:
			apply_drop(_drop_pick(pos))
	elif not dragging and _origin == "scene" and _candidate_index < 0:
		selected = -1
	_down = false
	_finger = -1
	_origin = ""
	stop_drag()


func begin_stock_drag(kind: String) -> void:
	selected = -1
	drag_kind = kind
	drag_rot = 0
	dragging = true
	_ghost.visible = true
	_ghost.queue_redraw()
	_layout()
	_hover(_pos)


func pick_up(index: int) -> void:
	var items: Array = Decor.items_of(g, car_id)
	if index < 0 or index >= items.size(): return
	selected = index
	drag_kind = items[index]["kind"]
	drag_rot = int(items[index].get("rot", 0))
	dragging = true
	_ghost.visible = true
	_ghost.queue_redraw()
	_layout()
	_hover(_pos)


func preview(pick: Dictionary) -> Dictionary:
	if pick.is_empty(): return {"ok": false, "why": NO_PLACE}
	if selected < 0:
		return Mods.can_place(g, car_id, drag_kind, pick["spot"], pick["at"], drag_rot, pick.get("on"))
	var item: Dictionary = Decor.items_of(g, car_id)[selected]
	if pick["spot"] != Decor.spot_of(item):
		return {"ok": false, "why": "이 물건을 놓는 면이 아니다"}
	if item.get("on") != pick.get("on"):
		return {"ok": false, "why": "다른 가구로 옮기려면 창고로 거둬 주세요."}
	var on: Variant = pick.get("on")
	if on != null and int(on) > selected: on = int(on) - 1
	return Mods.can_place(_placement_trial(selected), car_id, drag_kind, pick["spot"], pick["at"], drag_rot, on)


func _placement_trial(index: int) -> Dictionary:
	var item: Dictionary = Decor.items_of(g, car_id)[index]
	# A move does not consume another stock item or another slot. Check a detached copy.
	var trial: Dictionary = {"dom": {
		"furnish": g["dom"].get("furnish", {}).duplicate(true),
		"store": {}}}
	for resource: String in Data.RESOURCES:
		trial[resource] = g.get(resource, 0.0)
	var items: Array = Decor.items_of(trial, car_id)
	items.remove_at(index)
	for other: Dictionary in items:
		if other.has("on") and int(other["on"]) > index: other["on"] -= 1
	if item.has("v"): trial[Decor.DECOR[item["kind"]]["res"]] += item["v"]
	Decor.add_stored(trial["dom"]["store"], item["kind"], item.get("v"))
	return trial


func _drop_pick(pos: Vector2) -> Dictionary:
	return {} if store_rect().has_point(pos) or pos.y < TOP_CSS * K else pick_at(pos)


func _hover(pos: Vector2) -> void:
	_ghost.position = pos - Vector2(31 * K, 62 * K + finger_lift())
	var pick: Dictionary = _drop_pick(pos)
	if is_instance_valid(train):
		if pick.is_empty(): train.decor_hover("")
		else: train.decor_hover(pick["spot"], pick["at"], bool(preview(pick)["ok"]))


func apply_drop(pick: Dictionary) -> bool:
	var result: Dictionary = preview(pick)
	if bool(result["ok"]):
		if selected >= 0: result = Mods.move(g, car_id, selected, pick["at"], drag_rot)
		else: result = Mods.place(g, car_id, drag_kind, pick["spot"], pick["at"], drag_rot, pick.get("on"))
	return _result(result)


func rotate_selected(direction: int = 1) -> void:
	if selected < 0 or Decor.spot_of(Decor.items_of(g, car_id)[selected]) != "floor": return
	drag_rot = posmod(int(Decor.items_of(g, car_id)[selected].get("rot", 0)) + direction, 4)
	_result(Mods.rotate(g, car_id, selected, drag_rot))
	if dragging: _hover(_pos)


func return_selected() -> void:
	if selected < 0: return
	var result: Dictionary = Mods.take_back(g, car_id, selected)
	if bool(result["ok"]):
		selected = -1
		stop_drag()
	_result(result)


func _result(result: Dictionary) -> bool:
	if not bool(result["ok"]):
		show_note(String(result.get("why", NO_PLACE)))
		return false
	refresh()
	changed.emit()
	return true


func stop_drag() -> void:
	dragging = false
	drag_kind = ""
	_ghost.visible = false
	if is_instance_valid(train): train.decor_hover("")
	_layout()


func cancel_drag() -> void:
	_down = false
	_finger = -1
	_origin = ""
	_candidate_index = -1
	_touches.clear()
	selected = -1
	stop_drag()


func show_note(word: String) -> void:
	note_text = word
	note_left = NOTE_SECONDS
	_note.text = word
	_note.size = _note.get_combined_minimum_size()
	_note.position = Vector2((size.x - _note.size.x) * 0.5, (TOP_CSS + 4) * K)
	_note.visible = true
	_note.modulate.a = 1.0


func _process(delta: float) -> void:
	if note_left > 0:
		note_left = maxf(0, note_left - delta)
		_note.modulate.a = minf(1, note_left / 0.4)
		_note.visible = note_left > 0
		if note_left == 0: note_text = ""
	if _down and _origin == "scene" and not dragging and not _moved and _candidate_index >= 0:
		_held += delta
		if _held >= HOLD_SECONDS: pick_up(_candidate_index)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or data.is_empty(): return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event is InputEventScreenTouch:
			if event.canceled:
				cancel_drag()
				get_viewport().set_input_as_handled()
				return
			if event.pressed:
				_touches[event.index] = pos
				if _touches.size() == 1: pointer_down(pos, event.index)
				elif _touches.size() == 2: _twist = _touch_angle()
			else:
				_touches.erase(event.index)
				pointer_up(pos, event.index)
		else:
			if not _touches.has(event.index): return
			_touches[event.index] = pos
			pointer_move(pos, event.index)
			if _down and dragging and _touches.size() == 2 and selected >= 0:
				var angle: float = _touch_angle()
				var delta: float = wrapf(angle - _twist, -PI, PI)
				if absf(delta) >= PI / 4:
					rotate_selected(1 if delta > 0 else -1)
					_twist = angle
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		# Touch already owns this gesture; ignore its emulated mouse events.
		if event.device == -1:
			get_viewport().set_input_as_handled()
			return
		var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed: pointer_down(pos)
				else: pointer_up(pos)
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] and store_rect().has_point(pos):
				var direction: float = -1 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1
				scroll = clampf(scroll + direction * PITCH, 0, max_scroll())
				_rebuild_cards()
		else: pointer_move(pos)
		get_viewport().set_input_as_handled()


func _touch_angle() -> float:
	var points: Array = _touches.values()
	return (points[1] - points[0]).angle()


func _exit_tree() -> void:
	if is_instance_valid(train): train.decor_hover("")
