extends "res://addons/gut/test.gd"
## The research pane (research_pane.gd, decision 426 PR 6): only the
## technologies whose effect runs (decision 446), what each needs as pips and
## marks, keys a finger can take (48 dp), a key that cannot dimmed with its why
## as a tooltip and no sentence, a start, a cancel that asks twice, the ways of
## an either-or, and the finishing of a defective plate.

const RowKeep = preload("res://game/ui/row_keep.gd")
const ResearchPane = preload("res://game/ui/research_pane.gd")
const Research = preload("res://game/train/train_research.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const PaneMotion = preload("res://game/ui/pane_motion.gd")
const RestoreVectors = preload("res://tests/train/restore_vectors.gd")
const Advance = preload("res://game/train/train_advance.gd")
const Pipe = preload("res://game/train/train_pipe.gd")
const LAWTECH_PATH: String = "res://tests/fixtures/train/lawtech_vectors.json"
## S1 sideLine's literal names and amount; expectations do not call the pane's helpers.
const REL_NAMES: Dictionary = {"tail": "꼬리칸", "medtech": "기술·의무진", "guard": "경비대", "front": "앞칸", "engine": "기관실"}

var _lawtech: Dictionary = {}


## Let queued frees settle before GUT counts orphans.
func after_each() -> void:
	await wait_process_frames(1)


## A small board with what a restore start writes to (its journal line, the cars' relations).
func _game(craft: int = 1) -> Dictionary:
	var comms: Dictionary = {}
	for comm: String in ["tail", "medtech", "guard", "front", "engine"]:
		comms[comm] = {"rel": 0}
	var g := {"seg": 1, "gearOn": false, "journal": [], "comms": comms, "dom": TrainDom.start()}
	g["dom"]["frags"]["craft"] = craft
	return g


## Enough for w2 (its tier needs w1 working first, S1 prereqs).
func _ready_for_w2() -> Dictionary:
	var g := _game(2)
	g["dom"]["wood"] = 20
	g["dom"]["scrap"] = 20
	g["dom"]["techs"]["w1"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	return g


func _pane(g: Dictionary, ids: Array = [], resolution: Vector2 = Vector2.ZERO) -> Control:
	var holder := Control.new()
	holder.size = resolution if resolution != Vector2.ZERO else Vector2(844.0, 390.0) * UiFonts.K
	add_child_autofree(holder)
	var p = ResearchPane.new()
	p.techs = ids
	holder.add_child(p)
	p.pin(48.0)
	p.show_state(g)
	return p


func _key(p: Control, key_name: String) -> Button:
	return _live(p, key_name) as Button


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
	assert_null(_live(p, "Why_w1"), "no sentence on the pane (결정 417)")
	var pips: Control = _live(p, "Pips_w1")
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
	assert_not_null(_live(p, "Progress_w1"), "its row shows how far along")
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
	assert_eq((_live(p, "Name_w2") as Label).text, Research.TECHS["w2"]["variants"]["a"]["name"])


func test_back_closes_the_ways() -> void:
	var g := _ready_for_w2()
	var p := _pane(g, ["w2"])
	await wait_process_frames(1)
	_key(p, "Key_w2").pressed.emit()
	await wait_process_frames(1)
	assert_not_null(_live(p, "Way_w2_a"))
	_key(p, "Key_w2").pressed.emit()
	await wait_process_frames(1)
	assert_null(_live(p, "Way_w2_a"))
	assert_eq(_word(_key(p, "Key_w2")), "복원")


func test_a_defective_plate_is_finished_from_its_row() -> void:
	var g := _game(2)
	var cost: Dictionary = Research.restore_cost("w2")
	g["dom"]["techs"]["w2"] = {"stage": "defective", "defect": true, "progress": cost["work"], "need": cost["work"], "variant": "a"}
	var p := _pane(g, ["w2"])
	await wait_process_frames(1)
	assert_eq(_word(_key(p, "Key_w2")), "완성판")
	assert_not_null(_live(p, "Effect_w2"))
	_key(p, "Key_w2").pressed.emit()
	assert_true(bool(g["dom"]["techs"]["w2"]["finishing"]))
	assert_eq(g["dom"]["restoring"], "w2")


func test_a_working_technology_says_what_it_does_and_has_no_key() -> void:
	var g := _game()
	g["dom"]["techs"]["w1"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	var p := _pane(g)
	await wait_process_frames(1)
	assert_eq((_live(p, "Effect_w1") as Label).text, ResearchPane.EFFECT["w1"])
	assert_null(_key(p, "Key_w1"))


## A technology that only bends a law names it at the right of its name: red
## with 없음 while it does not stand, dim ink once it does (S1 useTag); the
## key's tooltip is its use line (train_lawtech.gd use_line) with its particles
## settled (UiFonts.josa).
func test_a_law_technology_names_its_law_and_whether_it_stands() -> void:
	var g := _game()
	var p := _pane(g, ["e1"])
	await wait_process_frames(1)
	var tag: Label = _live(p, "Law_e1")
	assert_not_null(tag)
	assert_eq(tag.text, "눈 녹이기 당번 없음")
	assert_eq(tag.get_theme_color("font_color"), ResearchPane.RED)
	var key: Button = _key(p, "Key_e1")
	assert_eq(key.tooltip_text, "쓸모: 눈 녹이기 당번이 서 있을 때(지금은 없다)")
	var name: Label = _live(p, "Name_e1")
	assert_lt(name.position.x + name.size.x, tag.position.x, "the tag does not run over the name")
	assert_lt(tag.position.x + tag.size.x, key.position.x, "nor under the key")
	g["passed"] = {"snow_duty": 0}
	p.show_state(g)
	await wait_process_frames(1)
	tag = _live(p, "Law_e1")
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
	var tag: Label = _live(p, "Law_x1")
	var name: Label = _live(p, "Name_x1")
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
	var s := _live(p, "List") as ScrollContainer
	var rows := _live(p, "Rows") as Control
	assert_gt(rows.size.y, s.size.y, "six rows are longer than the room for them")
	var more := _live(p, "More") as Control
	assert_true(more != null and more.visible, "the glass darkens where rows are left below")
	s.scroll_vertical = 10000
	await wait_process_frames(2)
	assert_false(more.visible, "dragged to the end, the shade goes")
	var few := _pane(_game(), ["e5", "w1"])
	await wait_process_frames(1)
	assert_null(_live(few, "More"), "rows that fit: no shade")


func test_the_fold_key_folds() -> void:
	var p := _pane(_game())
	await wait_process_frames(1)
	watch_signals(p)
	_key(p, "Fold").pressed.emit()
	assert_signal_emitted(p, "folded")


## On the train's home the 연구 room's pane stands where the car's did, as the
## refit room's and the workshop's: one room at a time, folding brings the car
## picked before back.
func test_the_slice_opens_the_research_room() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 3, "cinema": false}
	add_child_autofree(f)
	await wait_process_frames(1)
	assert_eq(f.current(), "train")
	assert_true((f.bar.open_rooms as Array).has("papers"), "the 연구 key opens a room, not 「준비 중」")
	var was: String = f.sel
	f._open_room("papers")
	assert_true(is_instance_valid(f.research), "the research pane is up")
	assert_eq(String(f.research.name), "ResearchPane")
	assert_false(PaneMotion.shown(f.pane), "the car's pane makes way")
	f._open_room("wrench")
	await wait_process_frames(1)
	assert_false(is_instance_valid(f.research), "the refit room takes its place")
	f._open_room("papers")
	f._close_room()
	await wait_process_frames(1)
	assert_false(is_instance_valid(f.research))
	assert_eq(f.sel, was, "folding brings back the car picked before the rooms")


## A running technology shows what it takes a stretch where its key would be,
## in S1 upkeepText's words (「유지 ⚙ 0.25/구간」); when the stores could not
## pay it, the line turns red and it runs at ½.
func test_a_running_technology_shows_its_upkeep_and_when_it_starves() -> void:
	var g := _game()
	g["dom"]["techs"]["e2"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	var r: Dictionary = ResearchPane.model(g, ["e2"])["rows"][0]
	assert_eq(r["upkeep"], [{"key": "parts", "icon": "gear", "n": 0.25}])
	assert_false(bool(r["starved"]))
	var p := _pane(g, ["e2"])
	var n := _live(p, "Upkeep_e2_parts") as Label
	assert_eq(n.text, "0.25")
	var word := _live(p, "UpkeepWord_e2") as Label
	var per := _live(p, "UpkeepPer_e2") as Label
	assert_eq(word.text, "유지")
	assert_eq(per.text, "/구간")
	var mark := _live(p, "UpkeepMark_e2_parts") as Control
	assert_lte(word.position.x + GlassParts.text_w(word), mark.position.x, "유지 ends before the mark")
	assert_lte(mark.position.x + mark.size.x, n.position.x, "the mark ends before the amount")
	assert_lte(n.position.x + GlassParts.text_w(n), per.position.x, "the amount ends before /구간")
	assert_almost_eq(per.position.x + GlassParts.text_w(per), 316.0 * UiFonts.K, 1.0, "the line ends where the key would")
	var tag := _live(p, "Law_e2") as Label
	assert_not_null(tag, "e2 carries a law tag")
	var tag_box := _ink_box(tag)
	assert_gt(tag_box.size.y, 0.0, "the tag has a height to compare")
	for part: Control in [word, mark, n, per]:
		assert_false(tag_box.intersects(_ink_box(part)), "the law tag keeps clear of " + String(part.name))
	assert_false((_live(p, "Effect_e2") as Label).text.begins_with("½"))
	g["dom"]["techs"]["e2"]["starved"] = true
	var p2 := _pane(g, ["e2"])
	assert_true((_live(p2, "Effect_e2") as Label).text.begins_with("½ "), "it runs at half")
	assert_eq((_live(p2, "Upkeep_e2_parts") as Label).get_theme_color("font_color"), ResearchPane.RED)
	assert_eq((_live(p2, "UpkeepWord_e2") as Label).get_theme_color("font_color"), ResearchPane.RED)
	assert_eq((_live(p2, "UpkeepPer_e2") as Label).get_theme_color("font_color"), ResearchPane.RED)
	g["dom"]["techs"]["e5"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	var p3 := _pane(g, ["e5"])
	assert_null(p3.find_child("Upkeep_e5_parts", true, false), "no upkeep, nothing drawn")
	assert_null(p3.find_child("UpkeepWord_e5", true, false), "no upkeep, no words either")
	assert_null(p3.find_child("UpkeepPer_e5", true, false))


## The stores row names each mark in the workshop's words (player review round 1, item 8): mark,
## name, count from left to right on one line, each store clear of the one before, and the last
## count inside the keys' edge (316, as the upkeep line) — for three-digit and four-digit counts,
## at both resolutions.
func test_the_stores_row_names_each_mark_before_its_count() -> void:
	var names: Dictionary = {"scrap": "고철", "wood": "목재", "parts": "부품"}
	for count: int in [999, 9999]:
		for res: Vector2 in [Vector2(1280.0, 720.0), Vector2(1688.0, 780.0)]:
			var g := _game()
			for key: String in names:
				g["dom"][key] = count
			var p := _pane(g, [], res)
			await wait_process_frames(1)
			var at: String = "%d at %s" % [count, res]
			var end_before: float = -1.0
			for key: String in names:
				var mark := _live(p, "StoreMark_" + key)
				var word := _live(p, "StoreName_" + key) as Label
				var n := _live(p, "Store_" + key) as Label
				assert_not_null(word, key + " has a name")
				if mark == null or word == null or n == null:
					continue
				assert_eq(word.text, names[key], at)
				assert_eq(n.text, str(count), at)
				assert_gt(mark.position.x, end_before, "%s %s keeps clear of the store before" % [at, key])
				assert_lte(mark.position.x + mark.size.x, word.position.x, "%s %s mark before its name" % [at, key])
				assert_lte(word.position.x + GlassParts.text_w(word), n.position.x, "%s %s name before its count" % [at, key])
				assert_almost_eq(_ink_box(word).end.y, _ink_box(n).end.y, 4.0 * UiFonts.K, "%s %s name and count share a line" % [at, key])
				end_before = n.position.x + GlassParts.text_w(n)
			assert_lte(end_before, 316.0 * UiFonts.K, at + " the last count ends inside the keys' edge")


## The upkeep line is redrawn in place: red while starved and back again, the
## mark with it, gone while the technology is stood down and back when it runs.
func test_the_upkeep_line_follows_its_row_when_redrawn() -> void:
	var g := _game()
	g["dom"]["techs"]["e2"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	var p := _pane(g, ["e2"])
	var px: int = int(round(15.0 * UiFonts.K))
	var look := func(color: Color) -> void:
		for key: String in ["UpkeepWord_e2", "Upkeep_e2_parts", "UpkeepPer_e2"]:
			assert_eq((_live(p, key) as Label).get_theme_color("font_color"), color, key)
		assert_eq((_live(p, "UpkeepMark_e2_parts") as TextureRect).texture, HudIcons.texture("gear", px, color, 2.0, ResearchPane.SOOT_CUT), "the mark's colour")
	look.call(ResearchPane.INK2)
	g["dom"]["techs"]["e2"]["starved"] = true
	p.show_state(g)
	look.call(ResearchPane.RED)
	g["dom"]["techs"]["e2"]["starved"] = false
	p.show_state(g)
	look.call(ResearchPane.INK2)
	g["dom"]["techs"]["e2"]["off"] = true
	p.show_state(g)
	for key: String in ["UpkeepWord_e2", "Upkeep_e2_parts", "UpkeepPer_e2", "UpkeepMark_e2_parts"]:
		assert_null(_live(p, key), key + " hides while it is stood down")
	g["dom"]["techs"]["e2"].erase("off")
	p.show_state(g)
	look.call(ResearchPane.INK2)


## A technology stood down (the 「부품이 모자란다」 paper's 「하나를 세운다」,
## S1 standDown): 멈춤 before what it does, no upkeep, and 다시 돌리기 — dimmed
## with the part it owes as its tooltip, and a press runs it again once it can.
func test_a_stood_down_technology_runs_again_from_its_row() -> void:
	var g := _game()
	g["dom"]["techs"]["e2"] = {"stage": "done", "defect": false, "progress": 2, "need": 2, "off": true, "refund": true}
	g["dom"]["parts"] = 0
	var r: Dictionary = ResearchPane.model(g, ["e2"])["rows"][0]
	assert_true(bool(r["off"]))
	assert_eq(r["word"], "다시 돌리기")
	assert_false(bool(r["can"]))
	var p := _pane(g, ["e2"])
	await wait_process_frames(1)
	assert_true((_live(p, "Effect_e2") as Label).text.begins_with("멈춤 "))
	assert_null(_live(p, "Upkeep_e2_parts"), "a stood-down technology pays no upkeep")
	assert_null(_live(p, "UpkeepWord_e2"))
	assert_null(_live(p, "UpkeepPer_e2"))
	var key: Button = _key(p, "Key_e2")
	assert_eq(_word(key), "다시 돌리기")
	assert_eq(key.tooltip_text, "세울 때 돌려받은 부품 1이 든다")
	key.pressed.emit()
	assert_true(bool(g["dom"]["techs"]["e2"]["off"]), "owed a part: it stays down")
	g["dom"]["parts"] = 2
	var p2 := _pane(g, ["e2"])
	await wait_process_frames(1)
	_key(p2, "Key_e2").pressed.emit()
	assert_false(bool(g["dom"]["techs"]["e2"]["off"]), "it runs again")
	assert_eq(float(g["dom"]["parts"]), 1.0)


func test_w4_row_names_the_clockwork_lure_without_scouting() -> void:
	var g: Dictionary = _game()
	g["dom"]["techs"]["w4"] = {"stage": "done", "defect": false, "progress": 3.0, "need": 3.0}
	assert_eq(_row(ResearchPane.model(g), "w4").get("effect"), "태엽 미끼")
	var p: Control = _pane(g)
	await wait_process_frames(1)
	var effect: Label = _live(p, "Effect_w4") as Label
	assert_not_null(effect)
	if effect != null:
		assert_eq(effect.text, "태엽 미끼")
	assert_null(_key(p, "Key_w4"))


func test_w2_variants_name_their_workshop_recipes() -> void:
	var g: Dictionary = _ready_for_w2()
	g["dom"]["techs"]["w2"] = {"stage": "done", "defect": false, "progress": 6.0, "need": 6.0, "variant": "a"}
	assert_eq(_row(ResearchPane.model(g), "w2").get("effect"), "고철로 권총탄")
	g["dom"]["techs"]["w2"]["variant"] = "b"
	assert_eq(_row(ResearchPane.model(g), "w2").get("effect"), "화살 깎기")



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


func test_show_state_keeps_scroll_row_way_selection_and_pressed_key() -> void:
	var g: Dictionary = _ready_for_w2()
	var p: Control = _pane(g)
	await wait_process_frames(2)
	var scroll: ScrollContainer = p.get_node("Parts/List") as ScrollContainer
	scroll.scroll_vertical = 80
	await wait_process_frames(1)
	var saved: int = scroll.scroll_vertical
	assert_gt(saved, 0)
	var row: Control = p.get_node("Parts/List/Rows/Item_w2") as Control
	var row_id: int = row.get_instance_id()
	var key: Button = row.get_node("Key_w2") as Button
	var key_id: int = key.get_instance_id()
	key.toggle_mode = true
	key.set_pressed_no_signal(true)
	key.pressed.emit()
	var way: Button = row.get_node("Way_w2_a") as Button
	var way_id: int = way.get_instance_id()
	p.show_state(g)
	assert_eq(scroll.scroll_vertical, saved)
	await wait_process_frames(2)
	assert_eq(scroll.scroll_vertical, saved)
	assert_eq(p.get_node("Parts/List/Rows/Item_w2").get_instance_id(), row_id)
	assert_eq(row.get_node("Key_w2").get_instance_id(), key_id)
	assert_eq(row.get_node("Way_w2_a").get_instance_id(), way_id)
	assert_eq(String(p.get("_choosing")), "w2")
	assert_eq(_word(key), "뒤로")
	assert_true(way.visible)
	assert_true(key.button_pressed)

## Where a part's ink sits in its row: a label by its text width and line
## height (its box may be wider, or not sized yet), a mark by its square.
func _ink_box(c: Control) -> Rect2:
	if c is Label:
		var l := c as Label
		var h: float = l.get_theme_font("font").get_height(l.get_theme_font_size("font_size"))
		return Rect2(l.position, Vector2(GlassParts.text_w(l), h))
	return Rect2(c.position, c.size)


func _pipe_sequence(sequence_name: String) -> Dictionary:
	if _lawtech.is_empty():
		assert_true(FileAccess.file_exists(LAWTECH_PATH), "S1 lawtech fixture exists")
		if not FileAccess.file_exists(LAWTECH_PATH): return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAWTECH_PATH))
		assert_true(parsed is Dictionary, "S1 lawtech fixture parses")
		if not parsed is Dictionary:
			return {}
		_lawtech = parsed
	for sequence: Dictionary in _lawtech["sequences"]:
		if String(sequence["name"]) == sequence_name:
			return sequence
	fail_test("Missing S1 sequence: " + sequence_name)
	return {}


func _relation_labels(row: Control, prefix: String) -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in row.get_children():
		if child is Label and child.visible and String(child.name).begins_with(prefix):
			labels.append(child as Label)
	labels.sort_custom(func(a: Label, b: Label) -> bool: return a.position.y < b.position.y)
	return labels


func _relation_text(row: Control, prefix: String = "Rel_") -> String:
	var words: Array[String] = []
	for label: Label in _relation_labels(row, prefix):
		words.append(label.text)
	return " ".join(words).replace(" · ", " ")


func _pane_row(p: Control, id: String) -> Control:
	return p.get_node("Parts/List/Rows/Item_" + id) as Control


func _assert_fixture_relations(g: Dictionary, expected: Dictionary, context: String) -> void:
	for comm: String in REL_NAMES:
		assert_almost_eq(float(g["comms"][comm]["rel"]), float(expected["comms"][comm]["rel"]), 1e-8, context + " " + comm)


## E3's ways share one notice under both keys (the ratification, not the way, moves relations).
func test_e3_first_ratification_guidance_is_under_the_ways() -> void:
	var sequence: Dictionary = _pipe_sequence("pipe-restart/approved/revote=true")
	if sequence.is_empty(): return
	var g: Dictionary = RestoreVectors.project(sequence["initial"])
	var p: Control = _pane(g, ["e3"])
	assert_eq(_relation_text(_pane_row(p, "e3")), "", "a closed two-way row says it under its ways")
	_key(p, "Key_e3").pressed.emit()
	var row: Control = _pane_row(p, "e3")
	assert_eq(_relation_text(row, "Rel_e3_ways_"), "추인 결과 쪽으로 ±5")
	assert_eq(_relation_text(row, "Rel_e3_a_") + _relation_text(row, "Rel_e3_b_"), "", "said once, not per key")
	var a: Button = _key(p, "Way_e3_a")
	var b: Button = _key(p, "Way_e3_b")
	for line: Label in _relation_labels(row, "Rel_e3_ways_"):
		assert_gte(line.position.y, a.position.y + a.size.y, "under the keys")
		assert_gte(line.position.x, a.position.x - 0.5)
		assert_lte(_ink_box(line).end.x, b.position.x + b.size.x + 0.5, "within the two keys")
	_assert_relation_boxes(row)
	assert_eq(g["dom"]["techs"].get("e3"), null, "opening ways does not start a restore")
	_assert_fixture_relations(g, sequence["initial"], "first offer")


func test_e3_revote_sequences_show_previous_result_and_match_s1_relations() -> void:
	for passed: bool in [true, false]:
		var sequence: Dictionary = _pipe_sequence("pipe-restart/approved/revote=" + ("true" if passed else "false"))
		if sequence.is_empty(): return
		var steps: Array = sequence["steps"]
		# S1's first approval is unfinished; cancel and restart it through the pane.
		var g: Dictionary = RestoreVectors.project(steps[3]["before"])
		var p: Control = _pane(g, ["e3"])
		_key(p, "Key_e3").pressed.emit()
		_key(p, "Key_e3").pressed.emit()
		assert_false((g["dom"]["techs"] as Dictionary).has("e3"))
		_assert_fixture_relations(g, steps[3]["after"], "cancel keeps first approval relations")
		_key(p, "Key_e3").pressed.emit()
		assert_eq(_relation_text(_pane_row(p, "e3"), "Rel_e3_ways_"),
			"앞 추인(변형 꼬리칸까지)과 같은 결과면 관계 그대로, 다른 결과면 그 변형 쪽으로 관계가 움직임")
		_key(p, "Way_e3_a").pressed.emit()
		assert_eq(Pipe.pending(g), "a", "restart waits for a new ratification")
		_assert_fixture_relations(g, steps[4]["after"], "restart itself does not move relations")
		assert_eq(_relation_text(_pane_row(p, "e3")),
			"앞 추인(변형 꼬리칸까지)과 같은 결과면 관계 그대로, 다른 결과면 그 변형 쪽으로 관계가 움직임")
		# While the vote is ahead the row itself says it: the longest row notice, wrapped in the row.
		_assert_relation_boxes(_pane_row(p, "e3"))
		# The last step's before-board includes the S1 vote setup, without recreating it here.
		g = RestoreVectors.project(steps[6]["before"])
		var before_tail: float = float(g["comms"]["tail"]["rel"])
		g = Advance.cast_vote(g, _lawtech["tables"])
		p.show_state(g)
		_assert_fixture_relations(g, steps[6]["after"], "second vote")
		assert_almost_eq(float(g["comms"]["tail"]["rel"]) - before_tail, 0.0 if passed else -5.0, 1e-8)
		assert_eq(g["dom"]["pipeMoved"], "a" if passed else "b")
		# The vote is over (no pending ratification): the row no longer says how a vote moves relations.
		assert_eq(_relation_text(_pane_row(p, "e3")), "")
		if not passed:
			assert_eq((_live(p, "Name_e3") as Label).text, "앞칸 직결")
			assert_eq((_live(p, "Law_e3") as Label).text, "난방 배당 없음")


func test_e3_fixed_sequences_use_the_fixed_variant_after_cancellation() -> void:
	for asked: String in ["a", "b"]:
		var sequence: Dictionary = _pipe_sequence("pipe-restart/rejected/" + asked)
		if sequence.is_empty(): return
		var steps: Array = sequence["steps"]
		var g: Dictionary = RestoreVectors.project(steps[3]["before"])
		var fixed: String = "b" if asked == "a" else "a"
		var title: String = "앞칸 직결" if fixed == "b" else "꼬리칸까지"
		var law: String = "난방 배당" if fixed == "b" else "공동 난방"
		var p: Control = _pane(g, ["e3"])
		assert_eq((_live(p, "Name_e3") as Label).text, title)
		assert_eq(_relation_text(_pane_row(p, "e3")), "", "a running restore with no vote ahead says nothing of relations")
		_key(p, "Key_e3").pressed.emit()
		_key(p, "Key_e3").pressed.emit()
		assert_false((g["dom"]["techs"] as Dictionary).has("e3"), "cancel removes the technology, not its fixed result")
		assert_eq(g["dom"]["pipeFlip"], fixed)
		var row: Dictionary = _row(ResearchPane.model(g, ["e3"]), "e3")
		assert_eq(row["variant"], title)
		assert_eq(row["law"], law)
		assert_eq(row["effect"], "난방 배당: 앞칸 온기 +5" if fixed == "b" else "공동 난방: 석탄 −0.65")
		assert_eq((row["ways"] as Array).size(), 1)
		assert_eq(row["ways"][0]["variant"], fixed)
		assert_eq((_live(p, "Name_e3") as Label).text, title)
		assert_true((_live(p, "Law_e3") as Label).text.begins_with(law))
		assert_eq(_relation_text(_pane_row(p, "e3")), "앞 추인 결과로 고정")
		assert_null(_live(p, "Way_e3_a"))
		assert_null(_live(p, "Way_e3_b"))
		_key(p, "Key_e3").pressed.emit()
		assert_eq(g["dom"]["techs"]["e3"]["variant"], fixed, "the ordinary restore key starts the fixed way")
		assert_null(Pipe.pending(g))
		assert_eq(String(p.get("_choosing")), "")
		_assert_fixture_relations(g, steps[4]["after"], "fixed restart")


func test_way_relations_show_disliked_neutral_and_all_multiple_cars() -> void:
	var p: Control = _pane(_ready_for_w2(), ["w2"])
	_key(p, "Key_w2").pressed.emit()
	assert_eq(_relation_text(_pane_row(p, "w2"), "Rel_w2_a_"), "관계 안 움직임")
	assert_eq(_relation_text(_pane_row(p, "w2"), "Rel_w2_b_"), "꼬리칸 +5 경비대 −5")
	# r2b is S1's four-car sample; a disabled technology still exercises the shared way layout.
	p.techs = ["r2"]
	p.set("_choosing", "r2")
	p.show_state(_game())
	assert_eq(_relation_text(_pane_row(p, "r2"), "Rel_r2_b_"), "경비대 +5 기관실 +5 꼬리칸 −5 기술·의무진 −5")


func test_single_technology_relations_only_show_when_they_move() -> void:
	var p: Control = _pane(_game(), ["e1", "e5"])
	assert_eq(_relation_text(_pane_row(p, "e1")), "")
	assert_eq(_relation_text(_pane_row(p, "e5")), "꼬리칸 +5 기관실 −5")
	_assert_relation_boxes(_pane_row(p, "e5"))


## Scrolled to the foot of an opened E3 (the lead's 1280×720 shot left a strip of letter tops of
## the row above under the stores): a row cut to under half its height lies under the top shade.
func test_a_row_cut_under_the_stores_lies_under_the_shade() -> void:
	var sequence: Dictionary = _pipe_sequence("pipe-restart/approved/revote=true")
	if sequence.is_empty(): return
	var ids: Array = ["w1", "w4", "e1", "w5", "e3"]
	for resolution: Vector2 in [Vector2(1280, 720), Vector2(1688, 780)]:
		var p: Control = _pane(RestoreVectors.project(sequence["steps"][4]["before"]), ids, resolution)
		await wait_process_frames(2)
		assert_null(_live(p, "Above"), "at the top of the list: no shade")
		_key(p, "Key_e3").pressed.emit()
		await wait_seconds(RowKeep.MOVE_S + 0.03)
		var scroll: ScrollContainer = p.get_node("Parts/List") as ScrollContainer
		scroll.scroll_vertical = 100000
		await wait_process_frames(2)
		var above: Control = _live(p, "Above")
		assert_not_null(above, "scrolled: the shade is on")
		if above == null: return
		assert_almost_eq(above.position.y, scroll.position.y, 0.5, "the shade starts where the list does")
		# A line of text the list's top edge cuts through (the shot's strip of letter tops):
		# what is left of it shows inside the shade.
		var top: float = float(scroll.scroll_vertical)
		var cut_lines: int = 0
		for id: String in ids:
			var row: Control = _pane_row(p, id)
			for child: Node in row.get_children():
				if not child is Label or not (child as Label).visible:
					continue
				var box: Rect2 = _ink_box(child as Control)
				var y0: float = row.position.y + box.position.y
				var y1: float = y0 + box.size.y
				if y0 < top - 0.5 and y1 > top + 0.5:
					cut_lines += 1
					assert_lte(y1 - top, above.size.y + 0.5, "%s/%s: its %.1f px left show inside the shade" % [id, child.name, y1 - top])
		assert_gt(cut_lines, 0, "this scene cuts a line of text at the top (the shot's strip)")
		scroll.scroll_vertical = 0
		await wait_process_frames(2)
		assert_null(_live(p, "Above"), "back at the top the shade goes")


func test_e3_revote_notice_wraps_below_keys_at_two_resolutions() -> void:
	var sequence: Dictionary = _pipe_sequence("pipe-restart/approved/revote=true")
	if sequence.is_empty(): return
	var ids: Array = ["w1", "w4", "e1", "w5", "e3"]
	for resolution: Vector2 in [Vector2(1280, 720), Vector2(1688, 780)]:
		var g: Dictionary = RestoreVectors.project(sequence["steps"][4]["before"])
		var p: Control = _pane(g, ids, resolution)
		_key(p, "Key_e3").pressed.emit()
		await wait_seconds(RowKeep.MOVE_S + 0.03)
		await wait_process_frames(2)
		var row: Control = _pane_row(p, "e3")
		assert_eq(_relation_text(row, "Rel_e3_ways_"),
			"앞 추인(변형 꼬리칸까지)과 같은 결과면 관계 그대로, 다른 결과면 그 변형 쪽으로 관계가 움직임")
		_assert_list_positions(p, ids)
		await _assert_last_relation_reachable(p, row)


func _expected_relations(id: String, variant: Variant) -> Array[String]:
	var def: Dictionary = Research.TECHS[id]
	var sides: Dictionary = def["variants"][variant] if variant != null else def
	var entries: Array[String] = []
	if (sides["dislike"] as Array).is_empty(): return entries
	for comm: String in sides["like"]:
		entries.append(String(REL_NAMES[comm]) + " +5")
	for comm: String in sides["dislike"]:
		entries.append(String(REL_NAMES[comm]) + " −5")
	return entries


## Measure whole car entries with the real face, not array length or pane wrap helpers.
func _measured_relation_height(entries: Array[String], width: float) -> float:
	if entries.is_empty(): return 0.0
	var probe: Label = UiFonts.label("", UiFonts.WORD, 400, 11.0, Color.WHITE)
	var lines: int = 0
	var used: String = ""
	for entry: String in entries:
		probe.text = entry if used == "" else used + " · " + entry
		if GlassParts.text_w(probe) <= width * UiFonts.K:
			used = probe.text
		else:
			if used != "": lines += 1
			probe.text = entry
			# Notices can exceed one column; Label's own shaper measures those wraps.
			probe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			probe.size = Vector2(width * UiFonts.K, 0.0)
			lines += maxi(0, probe.get_line_count() - 1)
			probe.autowrap_mode = TextServer.AUTOWRAP_OFF
			used = entry
	if used != "": lines += 1
	var height: float = lines * (probe.get_theme_font("font").get_height(probe.get_theme_font_size("font_size")) + 2.0 * UiFonts.K)
	probe.free()
	return height


## The ordinary row's actual name, law and cost ink delimit its remaining width.
func _ordinary_relation_width(p: Control, id: String, entries: Array[String]) -> float:
	var row: Control = _pane_row(p, id)
	var name_label: Label = _live(p, "Name_" + id) as Label
	var need: int = int(Research.restore_cost(id)["frags"])
	var under: float = 44.0 + (14.0 * need + 10.0 if need > 0 else 0.0)
	for child: Node in row.get_children():
		if child is Control and child.visible and String(child.name).begins_with("Cost_" + id + "_"):
			under = maxf(under, _ink_box(child as Control).end.x / UiFonts.K)
	var x0: float = maxf(_ink_box(name_label).end.x / UiFonts.K + 8.0, under + 8.0)
	var x1: float = 226.0
	var law: Label = _live(p, "Law_" + id) as Label
	if law != null:
		x0 = under + 8.0
		if GlassParts.base_of(law) / UiFonts.K > 30.0:
			x1 = minf(x1, law.position.x / UiFonts.K - 8.0)
	var widest: float = 0.0
	var probe: Label = UiFonts.label("", UiFonts.WORD, 400, 11.0, Color.WHITE)
	for entry: String in entries:
		probe.text = entry
		widest = maxf(widest, GlassParts.text_w(probe) / UiFonts.K)
	probe.free()
	return x1 - x0 if x1 - x0 >= widest else 162.0


func _largest_wrapped_case(p: Control, choosing: bool) -> Dictionary:
	var best: Dictionary = {"height": -1.0}
	var measured: int = 0
	for id: String in Research.TECHS:
		var def: Dictionary = Research.TECHS[id]
		var variants: Dictionary = def.get("variants", {})
		p.techs = [id]
		p.set("_choosing", "")
		p.show_state(_game())
		for variant: Variant in (variants.keys() if not variants.is_empty() else [null]):
			var entries: Array[String] = _expected_relations(id, variant)
			if choosing and entries.is_empty(): entries = ["관계 안 움직임"]
			var width: float = 80.0 if choosing else _ordinary_relation_width(p, id, entries)
			var height: float = _measured_relation_height(entries, width)
			measured += 1
			# Every TECHS/variant is measured. Chapter 6 only shows ordinary new-row
			# relations for non-variant technologies; variants compete in the 80px case.
			# E3's ways share one notice across both keys, not an 80px column; its notices
			# have their own tests (the revote one is the longest and is wrapped there).
			var eligible: bool = (not variants.is_empty() and id != "e3") if choosing else variants.is_empty() and not entries.is_empty()
			if eligible and height > float(best["height"]):
				best = {"id": id, "variant": variant, "entries": entries, "width": width, "height": height}
	assert_gt(measured, Research.TECHS.size(), "all variants, including unavailable technologies, were measured")
	assert_true(best.has("id"), "a measured relation row was selected")
	return best


func _assert_relation_boxes(row: Control) -> void:
	for relation: Label in _relation_labels(row, "Rel_"):
		var box: Rect2 = _ink_box(relation)
		assert_eq(relation.get_theme_font_size("font_size"), UiFonts.size(11.0))
		assert_eq(relation.get_theme_color("font_color"), ResearchPane.INK2)
		assert_gte(box.position.x, 0.0, String(relation.name))
		assert_gte(box.position.y, 0.0, String(relation.name))
		assert_lte(box.end.x, row.size.x + 0.5, String(relation.name) + " inside row width")
		assert_lte(box.end.y, row.size.y + 0.5, String(relation.name) + " inside row height")
		for child: Node in row.get_children():
			if child is Control and child != relation and child.visible:
				assert_false(box.intersects(_ink_box(child as Control)), "%s clear of %s" % [relation.name, child.name])


func _assert_list_positions(p: Control, ids: Array) -> void:
	var top: float = 0.0
	for id: String in ids:
		var row: Control = _pane_row(p, id)
		assert_almost_eq(row.position.y, top, 0.5, id + " follows preceding row heights")
		_assert_relation_boxes(row)
		top += row.size.y
	var rows: Control = p.get_node("Parts/List/Rows") as Control
	assert_almost_eq(rows.custom_minimum_size.y, top, 0.5, "list height is the sum of row heights")


func _assert_last_relation_reachable(p: Control, row: Control) -> void:
	var scroll: ScrollContainer = p.get_node("Parts/List") as ScrollContainer
	scroll.scroll_vertical = 100000
	await wait_process_frames(2)
	var lines: Array[Label] = _relation_labels(row, "Rel_")
	assert_false(lines.is_empty())
	if not lines.is_empty():
		var last: Label = lines[-1]
		var bottom: float = row.position.y + _ink_box(last).end.y - scroll.scroll_vertical
		assert_lte(bottom, scroll.size.y + 1.0, "last row's last relation line is reachable")
		assert_gt(bottom, 0.0, "last line is inside the viewport at the end")


func test_actual_font_worst_wraps_fit_both_row_forms_at_two_resolutions() -> void:
	for resolution: Vector2 in [Vector2(1280, 720), Vector2(1688, 780)]:
		for choosing: bool in [true, false]:
			var probe: Control = _pane(_game(), ["w1"], resolution)
			# Select by real wrapped font height in each row form, rather than by car count.
			var worst: Dictionary = _largest_wrapped_case(probe, choosing)
			if not worst.has("id"): return
			var id: String = String(worst["id"])
			var ids: Array = ["w1", "w4", "e1", "w5", id]
			var p: Control = _pane(_game(), ids, resolution)
			if choosing:
				p.set("_choosing", id)
				p.show_state(_game())
			await wait_seconds(RowKeep.MOVE_S + 0.03)
			await wait_process_frames(2)
			var row: Control = _pane_row(p, id)
			var prefix: String = "Rel_%s_%s_" % [id, worst["variant"]] if choosing else "Rel_" + id + "_"
			assert_eq(_relation_text(row, prefix), " ".join(worst["entries"]), "all S1 like/dislike names in order")
			if choosing:
				var way: Button = _key(p, "Way_%s_%s" % [id, worst["variant"]])
				for line: Label in _relation_labels(row, prefix):
					assert_gte(line.position.y, way.position.y + way.size.y, "relation is below its key")
					assert_gte(line.position.x, way.position.x - 0.5)
					assert_lte(_ink_box(line).end.x, way.position.x + way.size.x + 0.5, "inside 80px column")
			_assert_list_positions(p, ids)
			assert_almost_eq(p.size.y / UiFonts.K, 286.0, 0.5)
			assert_gte(p.global_position.x, -0.5)
			assert_lte(p.global_position.x + p.size.x, resolution.x + 0.5)
			assert_lte(p.global_position.y + p.size.y, resolution.y + 0.5)
			await _assert_last_relation_reachable(p, row)


func _layout_game() -> Dictionary:
	var g: Dictionary = _ready_for_w2()
	g["gearOn"] = true
	g["supOn"] = true
	g["dom"]["wood"] = 100
	g["dom"]["scrap"] = 100
	g["dom"]["parts"] = 100
	g["dom"]["cores"] = 10
	for branch: String in ["engine", "med", "craft", "radio", "expedition"]:
		g["dom"]["frags"][branch] = 50
		(g["dom"]["experts"] as Array).append({"name": branch, "comm": "engine", "field": branch, "skill": 3})
	g["dom"]["techs"]["e1"] = {"stage": "done", "defect": false}
	g["dom"]["techs"]["w6"] = {"stage": "done", "defect": false}
	return g


func test_first_middle_last_expansion_and_fold_restore_layout_and_scroll_at_two_resolutions() -> void:
	var ids: Array = ["e3", "e5", "w2", "w1", "w7"]
	for resolution: Vector2 in [Vector2(1280, 720), Vector2(1688, 780)]:
		var p: Control = _pane(_layout_game(), ids, resolution)
		await wait_process_frames(2)
		var scroll: ScrollContainer = p.get_node("Parts/List") as ScrollContainer
		var rows: Control = scroll.get_node("Rows") as Control
		var baseline: Dictionary = {}
		for id: String in ids:
			var row: Control = _pane_row(p, id)
			baseline[id] = {"instance": row.get_instance_id(), "position": row.position, "size": row.size}
		var total: float = rows.custom_minimum_size.y
		var end: float = scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page
		assert_gt(end, 0.0)
		for id: String in ["e3", "w2", "w7"]:
			scroll.scroll_vertical = 100000
			await wait_process_frames(1)
			_key(p, "Key_" + id).pressed.emit()
			await wait_seconds(RowKeep.MOVE_S + 0.03)
			await wait_process_frames(2)
			assert_eq(String(p.get("_choosing")), id)
			assert_gt(_pane_row(p, id).size.y, (baseline[id]["size"] as Vector2).y, "the open row grows")
			_assert_list_positions(p, ids)
			assert_almost_eq(scroll.get_v_scroll_bar().max_value, rows.custom_minimum_size.y, 0.5,
				"the scroll range takes the open row in (its foot can be scrolled to)")
			# Fold from the expanded end to exercise restore_scroll's smaller-range clamp.
			scroll.scroll_vertical = 100000
			await wait_process_frames(1)
			_key(p, "Key_" + id).pressed.emit()
			await wait_seconds(RowKeep.MOVE_S + 0.03)
			await wait_process_frames(2)
			assert_eq(String(p.get("_choosing")), "")
			_assert_list_positions(p, ids)
			for other: String in ids:
				var row: Control = _pane_row(p, other)
				assert_eq(row.get_instance_id(), baseline[other]["instance"], "RowKeep reuses " + other)
				# Heights are sums of measured lines in game px: equal to float rounding.
				assert_almost_eq(row.size, baseline[other]["size"] as Vector2, Vector2(0.01, 0.01), other + " size restored")
				assert_almost_eq(row.position, baseline[other]["position"] as Vector2, Vector2(0.01, 0.01), other + " position restored")
			assert_almost_eq(rows.custom_minimum_size.y, total, 0.5)
			assert_almost_eq(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page, end, 0.5)
			assert_almost_eq(float(scroll.scroll_vertical), floorf(end), 1.0, "scroll range and end return after folding")
