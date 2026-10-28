extends "res://addons/gut/test.gd"
## The workshop's pane (workshop_pane.gd, decision 426 PR 3): what it reads off
## the stores, keys a finger can take (48 dp), a short store in red with no
## sentence, a press that puts a thing on the line and one that takes it back;
## and the bottom bar's 공방 room opening it while the other rooms stay 「준비 중」.

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
	return p.find_child(key_name, true, false) as Button


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
	assert_eq((p.find_child("Have_crowbar", true, false) as Label).text, "×1")
	assert_null(p.find_child("Have_bow", true, false), "none held: no number")


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
	var s: ScrollContainer = p.find_child("List", true, false) as ScrollContainer
	assert_not_null(s)
	assert_true(s.is_ancestor_of(_key(p, "Key_core_remake")), "the core's key is in the dragged list")
	assert_not_null(p.find_child("More", true, false), "a shade while a row is below")
	assert_eq((p.find_child("Have_core_remake", true, false) as Label).text, "×2")


func test_a_short_store_is_red_and_its_key_will_not_start() -> void:
	var g := _game()
	var p := _pane(g)
	await wait_frames(1)
	var cloth: Label = p.find_child("Cost_coat_long_cloth", true, false) as Label
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
	assert_not_null(p.find_child("Progress_crowbar", true, false), "its row shows how far along")
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
	assert_null(p.find_child("Name_rounds", true, false))
	g["dom"]["techs"]["w2"] = {"stage": "done", "defect": false, "progress": 6.0, "need": 6.0, "variant": "a"}
	p.show_state(g)
	await wait_frames(1)
	var rounds: Label = p.find_child("Name_rounds", true, false) as Label
	assert_not_null(rounds)
	if rounds != null:
		assert_eq(rounds.text, "권총탄 한 줌")
	assert_eq((p.find_child("Have_rounds", true, false) as Label).text, "×16")
	assert_null(p.find_child("Name_arrows", true, false))
	g["dom"]["techs"]["w2"]["variant"] = "b"
	p.show_state(g)
	await wait_frames(1)
	assert_null(p.find_child("Name_rounds", true, false))
	assert_eq((p.find_child("Name_arrows", true, false) as Label).text, "화살 묶음")
	assert_eq((p.find_child("Have_arrows", true, false) as Label).text, "×9")
	g["dom"]["techs"]["w2"]["variant"] = "a"
	g["dom"]["techs"]["w2"]["off"] = true
	p.show_state(g)
	await wait_frames(1)
	assert_null(p.find_child("Name_rounds", true, false), "the selected way is off")
	assert_null(p.find_child("Name_arrows", true, false))


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
