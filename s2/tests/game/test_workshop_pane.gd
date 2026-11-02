extends "res://addons/gut/test.gd"
## The workshop's pane (workshop_pane.gd, decision 426 PR 3): what it reads off
## the stores, keys a finger can take (48 dp), a short store in red with no
## sentence, a press that puts a thing on the line and one that takes it back
## (its row stays while it is on the line, even when its technique stops);
## and the bottom bar's 공방 room opening it while the other rooms stay 「준비 중」.

const RowKeep = preload("res://game/ui/row_keep.gd")
const WorkshopPane = preload("res://game/ui/workshop_pane.gd")
const HomeBar = preload("res://game/ui/home_bar.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const TrainWorkshop = preload("res://game/train/train_workshop.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _game() -> Dictionary:
	return {"seg": 1, "dom": TrainDom.start()}


func _pane(g: Dictionary) -> Control:
	var holder := Control.new()
	holder.size = Vector2(844.0, 390.0) * UiFonts.K
	add_child_autofree(holder)
	var p = WorkshopPane.new()
	holder.add_child(p)
	p.pin(48.0)
	p.show_state(g)
	return p


func _key(p: Control, key_name: String) -> Button:
	return _live(p, key_name) as Button


func test_transport_recipes_use_existing_rows_counts_and_cap_tooltips() -> void:
	var g: Dictionary = _game()
	for id: String in ["x1", "x4"]:
		g["dom"]["techs"][id] = {"stage": "done", "defect": false, "progress": 6, "need": 6}
	g["dom"].merge({"sleds": 1, "long_sleds": 1, "stretchers": 1, "carts": 1, "runners": 2}, true)
	var ids: Array = ["sled", "stretcher", "cart", "long_sled", "runner"]
	var rows: Array = WorkshopPane.model(g)["rows"].filter(func(r: Dictionary) -> bool: return ids.has(r["id"]))
	assert_eq(rows.map(func(r: Dictionary) -> String: return r["id"]), ids)
	assert_eq(rows.map(func(r: Dictionary) -> String: return r["name"]), ["썰매", "들것", "손수레", "긴 썰매", "쇠 날"])
	var p := _pane(g)
	await wait_process_frames(1)
	for row: Dictionary in rows:
		var key: Button = _key(p, "Key_" + String(row["id"]))
		assert_not_null(key)
		assert_eq(key.tooltip_text, row["why"])
		assert_ne(row["why"], "")
		key.pressed.emit()
		assert_null(g["dom"].get("make"))
	assert_eq((_live(p, "Have_runner") as Label).text, "×2")
	await wait_process_frames(1)


func test_the_model_reads_the_stores_and_the_things_to_make() -> void:
	var m: Dictionary = WorkshopPane.model(_game())
	var ns: Array = []
	for s: Dictionary in m["stores"]:
		ns.append([s["key"], s["n"]])
	assert_eq(ns, [["scrap", 10.0], ["wood", 10.0], ["parts", 4.0], ["cloth", 0.0]])
	assert_eq(m["parts"]["target"], 5)
	var ids: Array = []
	for r: Dictionary in m["rows"]:
		ids.append(r["id"])
	assert_eq(ids, ["bow", "crowbar", "coat_long", "core_remake"])
	var coat: Dictionary = m["rows"][2]
	assert_true(bool(coat["cost"][0]["short"]), "no cloth: the coat's cloth is short")
	assert_eq(coat["why"], "천 4 모자람")
	assert_eq(m["rows"][1]["have"], 3, "the start armory's three crowbars (PR 5)")


func test_what_the_train_holds_shows_by_its_name() -> void:
	var g := _game()
	g["dom"]["armory"] = [{"id": "crowbar", "quality": "usable", "condition": 1.0}, {"id": "axe", "quality": "factory", "condition": 0.5}]
	g["dom"]["wardrobe"] = [{"id": "coat_long", "condition": 0.7}]
	var m: Dictionary = WorkshopPane.model(g)
	assert_eq([m["rows"][0]["have"], m["rows"][1]["have"], m["rows"][2]["have"]], [0, 1, 1])
	var p := _pane(g)
	await wait_frames(1)
	assert_eq((_live(p, "Have_crowbar") as Label).text, "×1")
	assert_null(_live(p, "Have_bow"), "none held: no number")


func test_every_key_takes_a_finger_48_dp_wide() -> void:
	var p := _pane(_game())
	await wait_frames(1)
	for key_name: String in ["Fold", "TargetDown", "TargetUp", "Key_bow", "Key_crowbar", "Key_coat_long", "Key_core_remake"]:
		var b: Button = _key(p, key_name)
		assert_not_null(b, key_name)
		assert_gte(b.size.y, FieldHud.MIN_TOUCH - 0.01, key_name + " tall enough")
		assert_gte(b.size.x, FieldHud.MIN_TOUCH * 0.6, key_name)
	for key_name: String in ["TargetDown", "TargetUp", "Key_bow"]:
		assert_gte(_key(p, key_name).size.x, FieldHud.MIN_TOUCH - 0.01, key_name + " wide enough")


## The remade core's row (decision 474 S3) counts the cores in the stores; it
## is the fifth row, so the pane keeps the car pane's height and that row is
## dragged up, a shade at the foot until it is.
func test_the_core_row_counts_the_cores_and_the_rows_scroll() -> void:
	var g := _game()
	g["dom"]["cores"] = 2
	var m: Dictionary = WorkshopPane.model(g)
	var core: Dictionary = m["rows"][3]
	assert_eq(core["id"], "core_remake")
	assert_eq(core["have"], 2, "the cores in the stores")
	assert_eq(core["why"], "부품 2 모자람")
	var p := _pane(g)
	await wait_frames(1)
	assert_almost_eq(p.size.y, WorkshopPane.CSS_SIZE.y * UiFonts.K, 0.5, "no taller than the car's pane")
	var s: ScrollContainer = _live(p, "List") as ScrollContainer
	assert_not_null(s)
	assert_true(s.is_ancestor_of(_key(p, "Key_core_remake")), "the core's key is in the dragged list")
	assert_not_null(_live(p, "More"), "a shade while a row is below")
	assert_eq((_live(p, "Have_core_remake") as Label).text, "×2")


func test_a_short_store_is_red_and_its_key_will_not_start() -> void:
	var g := _game()
	var p := _pane(g)
	await wait_frames(1)
	var cloth: Label = _live(p, "Cost_coat_long_cloth") as Label
	assert_not_null(cloth)
	assert_eq(cloth.get_theme_color("font_color"), WorkshopPane.RED)
	_key(p, "Key_coat_long").pressed.emit()
	assert_null(TrainWorkshop.line(g), "nothing on the line")


func test_make_then_take_back() -> void:
	var g := _game()
	var p := _pane(g)
	await wait_frames(1)
	_key(p, "Key_crowbar").pressed.emit()
	assert_eq(String((TrainWorkshop.line(g) as Dictionary)["id"]), "crowbar")
	assert_eq(float(g["dom"]["scrap"]), 6.0)
	await wait_frames(1)
	assert_not_null(_live(p, "Progress_crowbar"), "its row shows how far along")
	_key(p, "Key_crowbar").pressed.emit()
	assert_null(TrainWorkshop.line(g), "taken back")
	assert_eq(float(g["dom"]["scrap"]), 10.0)


func test_the_target_keys() -> void:
	var g := _game()
	var p := _pane(g)
	await wait_frames(1)
	_key(p, "TargetUp").pressed.emit()
	assert_eq(TrainWorkshop.target(g), 6)
	await wait_frames(1)
	_key(p, "TargetDown").pressed.emit()
	assert_eq(TrainWorkshop.target(g), 5)


func test_the_workshop_room_opens_and_the_others_wait() -> void:
	var holder := Control.new()
	holder.size = Vector2(844.0, 390.0) * UiFonts.K
	add_child_autofree(holder)
	var bar = HomeBar.new()
	bar.main_word = "정차 고르기"
	bar.open_rooms = ["gear"]
	holder.add_child(bar)
	await wait_frames(2)
	watch_signals(bar)
	(bar.get_node("Room_gear") as Button).pressed.emit()
	assert_signal_emitted_with_parameters(bar, "room_pressed", ["gear"])
	assert_null(bar.get_node_or_null("Note"), "the workshop says nothing over its key")
	(bar.get_node("Room_papers") as Button).pressed.emit()
	assert_not_null(bar.get_node_or_null("Note"), "research is still 준비 중")


func test_rounds_row_only_appears_while_w2_a_runs() -> void:
	var g: Dictionary = _game()
	var p: Control = _pane(g)
	await wait_frames(1)
	assert_null(_live(p, "Name_rounds"))
	g["dom"]["techs"]["w2"] = {"stage": "done", "defect": false, "progress": 6.0, "need": 6.0, "variant": "a"}
	p.show_state(g)
	await wait_frames(1)
	var rounds: Label = _live(p, "Name_rounds") as Label
	assert_not_null(rounds)
	if rounds != null:
		assert_eq(rounds.text, "권총탄 한 줌")
	assert_eq((_live(p, "Have_rounds") as Label).text, "×16")
	assert_null(_live(p, "Name_arrows"))
	g["dom"]["techs"]["w2"]["variant"] = "b"
	p.show_state(g)
	await wait_frames(1)
	assert_null(_live(p, "Name_rounds"))
	assert_eq((_live(p, "Name_arrows") as Label).text, "화살 묶음")
	assert_eq((_live(p, "Have_arrows") as Label).text, "×9")
	g["dom"]["techs"]["w2"]["variant"] = "a"
	g["dom"]["techs"]["w2"]["off"] = true
	p.show_state(g)
	await wait_frames(1)
	assert_null(_live(p, "Name_rounds"), "the selected way is off")
	assert_null(_live(p, "Name_arrows"))


func test_research_recipe_rows_count_their_store_amounts() -> void:
	var g: Dictionary = _game()
	g["dom"]["lures"] = 2
	g["dom"]["techs"]["w2"] = {"stage": "done", "defect": false, "progress": 6.0, "need": 6.0, "variant": "b"}
	g["dom"]["techs"]["w4"] = {"stage": "done", "defect": false, "progress": 3.0, "need": 3.0}
	var amounts: Dictionary = {}
	for row: Dictionary in WorkshopPane.model(g)["rows"]:
		amounts[row["id"]] = row["have"]
	assert_eq(amounts.get("arrows"), 9)
	assert_eq(amounts.get("lure"), 2)
	assert_false(amounts.has("rounds"))


func test_the_thing_on_the_line_keeps_its_row_when_its_way_stops() -> void:
	var g: Dictionary = _game()
	g["dom"]["techs"]["w2"] = {"stage": "done", "defect": false, "progress": 6.0, "need": 6.0, "variant": "a"}
	var p: Control = _pane(g)
	await wait_frames(1)
	_key(p, "Key_rounds").pressed.emit()
	assert_eq(String((TrainWorkshop.line(g) as Dictionary)["id"]), "rounds")
	g["dom"]["techs"]["w2"]["off"] = true
	assert_false(TrainWorkshop.shown(g).has("rounds"), "the stopped way is off the list of things to make")
	p.show_state(g)
	await wait_frames(1)
	assert_not_null(_live(p, "Name_rounds"), "but the thing on the line keeps its row")
	assert_not_null(_live(p, "Progress_rounds"))
	assert_null(_live(p, "Name_arrows"))
	_key(p, "Key_rounds").pressed.emit()
	assert_null(TrainWorkshop.line(g), "nothing done yet: it can be taken back")
	p.show_state(g)
	await wait_frames(1)
	assert_null(_live(p, "Name_rounds"), "off the line, the stopped way's row goes")



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


func test_show_state_keeps_scroll_row_and_the_started_jobs_key() -> void:
	var g: Dictionary = _game()
	var p: Control = _pane(g)
	await wait_process_frames(2)
	var scroll: ScrollContainer = p.get_node("Parts/List") as ScrollContainer
	scroll.scroll_vertical = 80
	await wait_process_frames(1)
	var saved: int = scroll.scroll_vertical
	assert_gt(saved, 0)
	var row: Control = p.get_node("Parts/List/Rows/Item_crowbar") as Control
	var row_id: int = row.get_instance_id()
	var key: Button = row.get_node("Key_crowbar") as Button
	var key_id: int = key.get_instance_id()
	var name_id: int = row.get_node("Name_crowbar").get_instance_id()
	key.toggle_mode = true
	key.set_pressed_no_signal(true)
	key.pressed.emit()
	assert_eq(String((TrainWorkshop.line(g) as Dictionary)["id"]), "crowbar")
	p.show_state(g)
	assert_eq(scroll.scroll_vertical, saved)
	await wait_process_frames(2)
	assert_eq(scroll.scroll_vertical, saved)
	assert_eq(p.get_node("Parts/List/Rows/Item_crowbar").get_instance_id(), row_id)
	assert_eq(row.get_node("Key_crowbar").get_instance_id(), key_id)
	assert_eq(row.get_node("Name_crowbar").get_instance_id(), name_id)
	assert_eq((key.get_node("Word") as Label).text, "취소")
	assert_true(key.button_pressed)
