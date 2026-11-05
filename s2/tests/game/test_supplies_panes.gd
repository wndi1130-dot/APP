extends "res://addons/gut/test.gd"

const WorkshopPane = preload("res://game/ui/workshop_pane.gd")
const ResearchPane = preload("res://game/ui/research_pane.gd")
const Dom = preload("res://game/train/train_dom.gd")
const Research = preload("res://game/train/train_research.gd")
const Order = preload("res://game/train/train_work_order.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


## The research pane tries each restore on a copy, and a start writes its journal line and the
## cars' relations as S1 startRestore does, so the board has both.
func _game() -> Dictionary:
	var g := {"seg": 1, "dom": Dom.start(), "comms": {}, "journal": []}
	for comm: String in ["tail", "medtech", "guard", "front", "engine"]:
		g["comms"][comm] = {"pop": 40, "rel": 0}
	return g


func _enable_techs(g: Dictionary) -> void:
	g["supOn"] = true
	g["sup"] = 5.0
	g["supFine"] = 2.0
	g["dom"]["supWork"] = 0.125
	g["dom"]["experts"] = [{"name": "공방", "comm": "front", "field": "craft", "skill": 3}]
	for id: String in ["w6", "w7", "w8"]:
		g["dom"]["techs"][id] = {"stage": "done", "defect": false, "progress": 3.0, "need": 3.0}
	g["dom"]["techs"]["w7"]["variant"] = "a"


func _pane(g: Dictionary) -> Control:
	var holder := Control.new()
	holder.size = Vector2(844.0, 390.0) * UiFonts.K
	add_child_autofree(holder)
	var p = WorkshopPane.new()
	holder.add_child(p)
	p.pin(48.0)
	p.show_state(g)
	return p


func _find(p: Control, id: String) -> Control:
	return p.find_child(id, true, false) as Control


func test_supplies_research_rows_and_controls_save_without_running_workshop() -> void:
	var g: Dictionary = _game()
	_enable_techs(g)
	var research: Dictionary = ResearchPane.model(g)
	var ids: Array = research["rows"].map(func(row: Dictionary) -> String: return String(row["id"]))
	for id: String in ["w6", "w7", "w8"]:
		assert_true(ids.has(id), id + " research row")
		var matching: Array = research["rows"].filter(func(row: Dictionary) -> bool: return row["id"] == id)
		assert_ne(String(matching[0]["effect"]), "", id + " effect")
	var initial: Dictionary = WorkshopPane.model(g)
	assert_eq(initial["order"], ["parts", "restore", "modify", "sup"] as Array[String])
	assert_almost_eq(float(initial["supplies"]["cap"]), 1.0, 0.000001)
	assert_almost_eq(float(initial["supplies"]["progress"]), 0.125, 0.000001)
	var p := _pane(g)
	var changes: Array = []
	p.connect("changed", func() -> void: changes.append(true))
	await wait_process_frames(2)
	var before: Array = [g["dom"]["parts"], g["dom"]["scrap"], g["dom"]["supWork"], g["supFine"], g["sup"]]
	var up: Button = _find(p, "Order_sup_up") as Button
	var fine: Button = _find(p, "SuppliesFine") as Button
	var first_up: Button = _find(p, "Order_parts_up") as Button
	assert_not_null(up)
	assert_not_null(fine)
	assert_not_null(first_up)
	if up == null or fine == null or first_up == null: return
	var before_denied: PackedByteArray = var_to_bytes(g)
	first_up.pressed.emit()
	assert_eq(var_to_bytes(g), before_denied)
	assert_eq(changes.size(), 0)
	up.pressed.emit()
	assert_eq(g["dom"]["order"], ["parts", "restore", "sup", "modify"] as Array[String])
	assert_eq(changes.size(), 1)
	var down: Button = _find(p, "Order_sup_down") as Button
	assert_not_null(down)
	if down == null: return
	down.pressed.emit()
	assert_eq(g["dom"]["order"], ["parts", "restore", "modify", "sup"] as Array[String])
	assert_eq(changes.size(), 2)
	fine.pressed.emit()
	assert_true(g["dom"]["supFineOn"])
	assert_eq(changes.size(), 3)
	assert_eq([g["dom"]["parts"], g["dom"]["scrap"], g["dom"]["supWork"], g["supFine"], g["sup"]], before)
	var reopened: Dictionary = WorkshopPane.model(g)
	assert_eq(reopened["order"], Order.normalized(g))
	assert_true(bool(reopened["supplies"]["fine"]))
	assert_almost_eq(float(reopened["supplies"]["scrap"]), 2.5, 0.000001)
	# The displayed fractional final batch and its cost use the same cap as the rules.
	g["comms"]["engine"]["pop"] = 15
	g["dom"]["scrap"] = 1.0
	p.show_state(g)
	var short: Dictionary = WorkshopPane.model(g)["supplies"]
	assert_almost_eq(float(short["cap"]), 0.875, 0.000001)
	assert_almost_eq(float(short["scrap"]), 2.1875, 0.000001)
	assert_true(bool(short["short"]))
	var cost: Label = _find(p, "SuppliesCost_scrap") as Label
	assert_not_null(cost)
	if cost != null:
		assert_eq(cost.text, "2.19", "two places on a phone")
		assert_eq(cost.get_theme_color("font_color"), WorkshopPane.RED)


func test_supplies_off_panes_unchanged() -> void:
	var g: Dictionary = _game()
	var before: PackedByteArray = var_to_bytes(g)
	var legacy: Dictionary = WorkshopPane.model(g)
	assert_eq(legacy.keys(), ["stores", "parts", "rows"])
	assert_eq(legacy["stores"].map(func(s: Dictionary) -> Array: return [s["key"], s["n"]]), [["scrap", 10.0], ["wood", 10.0], ["parts", 4.0], ["cloth", 0.0]])
	assert_eq(legacy["parts"]["target"], 5)
	assert_eq(legacy["rows"].map(func(row: Dictionary) -> String: return String(row["id"])), ["bow", "crowbar", "coat_long", "core_remake"])
	var legacy_research: Dictionary = ResearchPane.model(g)
	assert_eq(legacy_research["rows"].map(func(row: Dictionary) -> String: return String(row["id"])), Research.VISIBLE)
	assert_eq(var_to_bytes(g), before)
	g["supOn"] = false
	var off: PackedByteArray = var_to_bytes(g)
	assert_eq(WorkshopPane.model(g), legacy)
	assert_eq(ResearchPane.model(g), legacy_research)
	var p := _pane(g)
	await wait_process_frames(1)
	assert_null(_find(p, "Order_parts_up"))
	assert_null(_find(p, "SuppliesFine"))
	assert_null(_find(p, "SuppliesName"))
	assert_eq(var_to_bytes(g), off)
	# Previously completed technologies do not introduce controls on an off board.
	_enable_techs(g)
	g.erase("supOn")
	var without_flag: Dictionary = WorkshopPane.model(g)
	var off_bytes: PackedByteArray = var_to_bytes(g)
	assert_false(without_flag.has("order"))
	assert_false(without_flag.has("supplies"))
	assert_eq(var_to_bytes(g), off_bytes)
	g["supOn"] = false
	assert_eq(WorkshopPane.model(g), without_flag)
	assert_false(ResearchPane.model(g)["rows"].any(func(row: Dictionary) -> bool: return row["id"] in ["w6", "w7", "w8"]))


func test_supplies_keys_fit_rows_and_keep_touch_size() -> void:
	var g: Dictionary = _game()
	_enable_techs(g)
	var p := _pane(g)
	await wait_process_frames(2)
	for id: String in ["parts", "restore", "modify", "sup"]:
		for direction: String in ["up", "down"]:
			var key: Button = _find(p, "Order_%s_%s" % [id, direction]) as Button
			assert_not_null(key)
			if key == null: continue
			assert_gte(key.size.x, WorkshopPane.KEY_H * UiFonts.K - 0.01)
			assert_gte(key.size.y, WorkshopPane.KEY_H * UiFonts.K - 0.01)
			assert_true(Rect2(Vector2.ZERO, (key.get_parent() as Control).size).encloses(Rect2(key.position, key.size)), key.name + " within row")
	var fine: Button = _find(p, "SuppliesFine") as Button
	assert_not_null(fine)
	if fine != null:
		assert_gte(fine.size.x, WorkshopPane.KEY_H * UiFonts.K - 0.01)
		assert_gte(fine.size.y, WorkshopPane.KEY_H * UiFonts.K - 0.01)
		assert_true(Rect2(Vector2.ZERO, (fine.get_parent() as Control).size).encloses(Rect2(fine.position, fine.size)))


func test_supplies_rows_follow_working_technology() -> void:
	var g: Dictionary = _game()
	g["supOn"] = true
	assert_false(WorkshopPane.model(g)["order"].has("sup"))
	assert_false(WorkshopPane.model(g).has("supplies"))
	_enable_techs(g)
	g["dom"]["supFineOn"] = true
	g["dom"]["techs"]["w8"]["off"] = true
	var m: Dictionary = WorkshopPane.model(g)
	assert_true(m["order"].has("sup"))
	assert_false(bool(m["supplies"]["can_fine"]))
	assert_false(bool(m["supplies"]["fine"]))
	g["dom"]["techs"]["w6"]["off"] = true
	assert_false(WorkshopPane.model(g).has("supplies"))


func test_supplies_cap_uses_supplied_tables() -> void:
	var g: Dictionary = _game()
	_enable_techs(g)
	var tables: Dictionary = WorkshopPane._supply_tables().duplicate(true)
	tables["P"]["supPer100"] = 4.0
	assert_almost_eq(float(WorkshopPane.model(g, tables)["supplies"]["cap"]), 2.0, 0.000001)
	var p := _pane(g)
	p.show_state(g, tables)
	var label: Label = _find(p, "SuppliesCap") as Label
	assert_not_null(label)
	if label != null: assert_eq(label.text, "상한 2")
