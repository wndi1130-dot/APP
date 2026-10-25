extends "res://addons/gut/test.gd"
## The research pane (research_pane.gd, decision 426 PR 6): only the
## technologies whose effect runs (decision 446), what each needs as pips and
## marks, keys a finger can take (48 dp), a key that cannot dimmed with its why
## as a tooltip and no sentence, a start, a cancel that asks twice, the ways of
## an either-or, and the finishing of a defective plate.

const ResearchPane = preload("res://game/ui/research_pane.gd")
const Research = preload("res://game/train/train_research.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")


## The rows a press draws again are freed a frame later; let them go before GUT counts orphans.
func after_each() -> void:
	await wait_process_frames(1)


func _game(craft: int = 1) -> Dictionary:
	var g := {"seg": 1, "gearOn": false, "dom": TrainDom.start()}
	g["dom"]["frags"]["craft"] = craft
	return g


## Enough for w2 (its tier needs w1 working first, S1 prereqs).
func _ready_for_w2() -> Dictionary:
	var g := _game(2)
	g["dom"]["wood"] = 20
	g["dom"]["scrap"] = 20
	g["dom"]["techs"]["w1"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	return g


func _pane(g: Dictionary, ids: Array = []) -> Control:
	var holder := Control.new()
	holder.size = Vector2(844.0, 390.0) * UiFonts.K
	add_child_autofree(holder)
	var p = ResearchPane.new()
	p.techs = ids
	holder.add_child(p)
	p.pin(48.0)
	p.show_state(g)
	return p


func _key(p: Control, key_name: String) -> Button:
	return p.find_child(key_name, true, false) as Button


func _row(m: Dictionary, id: String) -> Dictionary:
	for r: Dictionary in m["rows"]:
		if r["id"] == id:
			return r
	return {}


func _word(b: Button) -> String:
	return (b.get_node("Word") as Label).text


func test_only_what_runs_is_listed_with_what_it_needs() -> void:
	var m: Dictionary = ResearchPane.model(_game())
	assert_eq(m["rows"].map(func(r: Dictionary) -> String: return r["id"]), Research.visible(_game()))
	var w1: Dictionary = _row(m, "w1")
	assert_eq([w1["id"], w1["word"], w1["can"], w1["have"], w1["need"]], ["w1", "복원", true, 1, 1])
	assert_eq(w1["cost"].map(func(c: Dictionary) -> Array: return [c["key"], c["n"], c["short"]]), [["wood", 4.0, false]])
	var none: Dictionary = _row(ResearchPane.model(_game(0)), "w1")
	assert_false(none["can"])
	assert_eq(none["why"], "설계도 조각이 모자라다")


func test_every_key_takes_a_finger_48_dp_wide() -> void:
	var p := _pane(_game())
	await wait_process_frames(1)
	for key_name: String in ["Fold", "Key_w1"]:
		var b: Button = _key(p, key_name)
		assert_not_null(b, key_name)
		assert_gte(b.size.y, FieldHud.MIN_TOUCH - 0.01, key_name + " tall enough")
		assert_gte(b.size.x, FieldHud.MIN_TOUCH * 0.6, key_name)


func test_a_key_that_cannot_is_dim_says_why_only_as_a_tooltip_and_shakes() -> void:
	var g := _game(0)
	var p := _pane(g)
	await wait_process_frames(1)
	var key: Button = _key(p, "Key_w1")
	assert_almost_eq(key.modulate.a, UiDeny.DIM, 1e-6)
	assert_eq(key.tooltip_text, "설계도 조각이 모자라다")
	assert_null(p.find_child("Why_w1", true, false), "no sentence on the pane (결정 417)")
	var pips: Control = p.find_child("Pips_w1", true, false)
	assert_eq([pips.get_meta("have"), pips.get_meta("need")], [0, 1])
	key.pressed.emit()
	assert_true(UiDeny.is_shaking(key))
	assert_eq(g["dom"]["techs"], {}, "nothing started")


func test_start_then_cancel_asks_twice() -> void:
	var g := _game()
	var p := _pane(g)
	await wait_process_frames(1)
	_key(p, "Key_w1").pressed.emit()
	assert_eq(g["dom"]["restoring"], "w1")
	assert_eq(float(g["dom"]["wood"]), 6.0)
	await wait_process_frames(1)
	assert_not_null(p.find_child("Progress_w1", true, false), "its row shows how far along")
	assert_eq(_word(_key(p, "Key_w1")), "취소")
	_key(p, "Key_w1").pressed.emit()
	assert_eq(g["dom"]["restoring"], "w1", "the first press only asks")
	await wait_process_frames(1)
	assert_eq(_word(_key(p, "Key_w1")), "정말 취소")
	_key(p, "Key_w1").pressed.emit()
	assert_null(g["dom"]["restoring"])
	assert_eq(float(g["dom"]["frags"]["craft"]), 1.0, "the fragment comes back")
	assert_eq(float(g["dom"]["wood"]), 6.0, "the wood does not")


func test_an_either_or_opens_its_ways_and_a_way_starts_it() -> void:
	var g := _ready_for_w2()
	var p := _pane(g, ["w2"])
	await wait_process_frames(1)
	assert_eq(_word(_key(p, "Key_w2")), "복원")
	_key(p, "Key_w2").pressed.emit()
	assert_false(g["dom"]["techs"].has("w2"), "a way is not picked yet")
	await wait_process_frames(1)
	assert_eq(_word(_key(p, "Key_w2")), "뒤로")
	var way: Button = _key(p, "Way_w2_a")
	assert_not_null(way)
	assert_eq(_word(way), Research.TECHS["w2"]["variants"]["a"]["name"])
	assert_gte(way.size.y, FieldHud.MIN_TOUCH - 0.01, "a way is a full key")
	way.pressed.emit()
	assert_eq(g["dom"]["restoring"], "w2")
	assert_eq(g["dom"]["techs"]["w2"]["variant"], "a")
	await wait_process_frames(1)
	assert_eq((p.find_child("Name_w2", true, false) as Label).text, Research.TECHS["w2"]["variants"]["a"]["name"])


func test_back_closes_the_ways() -> void:
	var g := _ready_for_w2()
	var p := _pane(g, ["w2"])
	await wait_process_frames(1)
	_key(p, "Key_w2").pressed.emit()
	await wait_process_frames(1)
	assert_not_null(p.find_child("Way_w2_a", true, false))
	_key(p, "Key_w2").pressed.emit()
	await wait_process_frames(1)
	assert_null(p.find_child("Way_w2_a", true, false))
	assert_eq(_word(_key(p, "Key_w2")), "복원")


func test_a_defective_plate_is_finished_from_its_row() -> void:
	var g := _game(2)
	var cost: Dictionary = Research.restore_cost("w2")
	g["dom"]["techs"]["w2"] = {"stage": "defective", "defect": true, "progress": cost["work"], "need": cost["work"], "variant": "a"}
	var p := _pane(g, ["w2"])
	await wait_process_frames(1)
	assert_eq(_word(_key(p, "Key_w2")), "완성판")
	assert_not_null(p.find_child("Effect_w2", true, false))
	_key(p, "Key_w2").pressed.emit()
	assert_true(bool(g["dom"]["techs"]["w2"]["finishing"]))
	assert_eq(g["dom"]["restoring"], "w2")


func test_a_working_technology_says_what_it_does_and_has_no_key() -> void:
	var g := _game()
	g["dom"]["techs"]["w1"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	var p := _pane(g)
	await wait_process_frames(1)
	assert_eq((p.find_child("Effect_w1", true, false) as Label).text, ResearchPane.EFFECT["w1"])
	assert_null(_key(p, "Key_w1"))


## A technology that only bends a law names it at the right of its name: red
## with 없음 while it does not stand, dim ink once it does (S1 useTag); the
## key's tooltip is its use line (train_lawtech.gd use_line).
func test_a_law_technology_names_its_law_and_whether_it_stands() -> void:
	var g := _game()
	var p := _pane(g, ["e1"])
	await wait_process_frames(1)
	var tag: Label = p.find_child("Law_e1", true, false)
	assert_not_null(tag)
	assert_eq(tag.text, "눈 녹이기 당번 없음")
	assert_eq(tag.get_theme_color("font_color"), ResearchPane.RED)
	var key: Button = _key(p, "Key_e1")
	assert_eq(key.tooltip_text, "쓸모: 눈 녹이기 당번이(가) 서 있을 때(지금은 없다)")
	var name: Label = p.find_child("Name_e1", true, false)
	assert_lt(name.position.x + name.size.x, tag.position.x, "the tag does not run over the name")
	assert_lt(tag.position.x + tag.size.x, key.position.x, "nor under the key")
	g["passed"] = {"snow_duty": 0}
	p.show_state(g)
	await wait_process_frames(1)
	tag = p.find_child("Law_e1", true, false)
	assert_eq(tag.text, "눈 녹이기 당번")
	assert_eq(_row(ResearchPane.model(g), "e1")["law_on"], true)
	assert_eq(_row(ResearchPane.model(g), "w1")["law"], "", "a technology no law touches has no tag")
	assert_eq([_row(ResearchPane.model(g), "e5")["law"], _row(ResearchPane.model(g), "e5")["use"]], ["", ""],
		"insulation is of use with no law standing: no tag, no use line")


## A name that leaves no room for the tag puts it at the end of the line under it.
func test_a_long_name_s_tag_goes_under_it() -> void:
	var g := _game()
	g["dom"]["frags"]["expedition"] = 1
	var p := _pane(g, ["x1"])
	await wait_process_frames(1)
	var tag: Label = p.find_child("Law_x1", true, false)
	var name: Label = p.find_child("Name_x1", true, false)
	assert_not_null(tag)
	assert_eq(tag.text, "아동 노동 없음")
	assert_gt(tag.position.y, name.position.y + name.size.y * 0.5, "on the line under the name")
	assert_lt(tag.position.x + tag.size.x, _key(p, "Key_x1").position.x, "clear of the key")


## Both ways' laws when no way is picked; the way's own law once it is.
func test_an_either_or_law_technology_tags_both_laws_then_its_own() -> void:
	var g := _game()
	assert_eq(_row(ResearchPane.model(g, ["e3"]), "e3")["law"], "난방 배당·공동 난방")
	g["dom"]["techs"]["e3"] = {"stage": "done", "defect": false, "progress": 4, "need": 4, "variant": "a"}
	var r: Dictionary = _row(ResearchPane.model(g, ["e3"]), "e3")
	assert_eq([r["law"], r["effect"]], ["공동 난방", ResearchPane.EFFECT["e3a"]])


## Six technologies do not fit under the stores: the pane stays the car pane's
## height over the bottom bar and the rows are dragged up inside it, the glass
## darkening at the foot while some are left below.
func test_more_rows_than_fit_scroll_inside_the_pane() -> void:
	var ids: Array = ["e1", "e2", "e3", "e5", "w1", "x1"]
	var p := _pane(_game(), ids)
	await wait_process_frames(2)
	assert_almost_eq(p.size.y / UiFonts.K, ResearchPane.CSS_H_MAX, 0.5, "no higher than the car's pane")
	var s := p.find_child("List", true, false) as ScrollContainer
	var rows := p.find_child("Rows", true, false) as Control
	assert_gt(rows.size.y, s.size.y, "six rows are longer than the room for them")
	var more := p.find_child("More", true, false) as Control
	assert_true(more != null and more.visible, "the glass darkens where rows are left below")
	s.scroll_vertical = 10000
	await wait_process_frames(2)
	assert_false(more.visible, "dragged to the end, the shade goes")
	var few := _pane(_game(), ["e5", "w1"])
	await wait_process_frames(1)
	assert_null(few.find_child("More", true, false), "rows that fit: no shade")


func test_the_fold_key_folds() -> void:
	var p := _pane(_game())
	await wait_process_frames(1)
	watch_signals(p)
	_key(p, "Fold").pressed.emit()
	assert_signal_emitted(p, "folded")
