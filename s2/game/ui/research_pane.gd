extends Control
## The research pane (decision 426 PR 6): the same smoked glass and keys as the
## workshop's pane (workshop_pane.gd). On it: the stores a restoration uses as
## their marks and numbers; then one row a technology, only those whose effect
## runs on S2's train (decision 446). A row says what the technology needs (its
## branch's fragments as pips, the stores as marks, red when short) or how far
## the workshop is with it, or, once it works, what it does in a few words; and
## its key: 복원 (결함판 when only the defective plate can be made), 취소 while
## the workshop is on it (a second press takes it back: the stores do not come
## back), 완성판 for a defective plate. When a restoration can go more than one
## way (decision 068's either-or), 복원 turns the row into a key for each way.
## A key that cannot is dimmed and shakes; why is its tooltip (결정 417: no
## sentence on the pane). A technology that only bends a law (train_lawtech.gd)
## names that law at the right of its name (or of the line under it when the
## name leaves no room), red with 없음 while it does not stand (S1 useTag), so
## none is bought unawares (7.3); its use line is the key's tooltip when
## nothing blocks it. A technology stood down (S1 standDown, the 「부품이
## 모자란다」 paper's 「하나를 세운다」) says 멈춤 before what it does and its key
## is 다시 돌리기, dimmed while the part it gave back cannot be paid again.
##
## The rules are train_research.gd; the pane asks them, and tries a start on a
## copy to know whether a way can go. It changes the state it was given.

signal folded
signal changed

const RowKeep = preload("res://game/ui/row_keep.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const Research = preload("res://game/train/train_research.gd")
const LawTech = preload("res://game/train/train_lawtech.gd")
const GLASS := preload("res://game/ui/tex/pane_glass.png")

## As tall as the workshop's pane while four rows fit; longer lists grow it.
const CSS_W: float = 330.0
const CSS_H_MIN: float = 286.0
## No higher than the car's pane (the band to the bottom bar): more rows than
## fit are dragged up under the stores (glass_pane.gd scroll), as mods_pane.gd.
const CSS_H_MAX: float = 286.0
const SHADE := Color("0b0e12")
## The shade under the stores while rows are scrolled up: half a row and a little.
const ABOVE_H: float = 30.0
## Where that shade starts across: the rows' branch marks stand at 44.
const ABOVE_X: float = 40.0
const STORES: Array = [["scrap", "it_nails"], ["wood", "it_plank"], ["parts", "gear"]]
const ICON: Dictionary = {"scrap": "it_nails", "wood": "it_plank", "parts": "gear", "core": "gear"}
## S1 ui/domestic.ts BRANCH_ICON.
const BRANCH_ICON: Dictionary = {"engine": "gear", "med": "med", "craft": "wrench", "radio": "radio", "expedition": "compass"}
## The technologies whose every S2 effect is on a law: S1 LAW_ONLY_TECHS but E5,
## whose insulation (the refit room) is of use with no law standing.
const LAW_TAGGED: Array[String] = ["e1", "e2", "e3", "m2", "m3", "x1"]
## What a working technology does on S2's train, in a few words (decision 449);
## a law technology's says which law and how (train_lawtech.gd TOUCHES·OPENS).
const EFFECT: Dictionary = {
	"w1": "공방 일 ×1.25", "e1": "눈 녹이기 당번: 벌 줄임", "e2": "난방 배당: 벌 줄임",
	"e3a": "공동 난방: 석탄 −0.65", "e3b": "난방 배당: 앞칸 온기 +5", "e5": "개조 방: 칸 단열",
	"x1": "아동 노동: 짐 꾸리기만", "m2": "중환자 분류: 기준 변형",
	"m3a": "종자곡 풀기: 반만 변형", "m3b": "공동 식당: 식량 −1.5",
	"w2a": "고철로 권총탄", "w2b": "화살 깎기", "w4": "태엽 미끼",
	"w6": "공방 생필품 만들기", "w7a": "일 −30% · 고철 +25%", "w7b": "일 +30% · 생산 1.5 · 고철 +50%",
	"w7": "생필품 조리법 선택", "w8": "고철 두 배로 좋은 물건",
}
const ROW_TOP: float = 66.0
const ROW_H: float = 54.0
const KEY_H: float = 44.0
const KEY_W: float = 84.0
const WAY_W: float = 80.0
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const HAIR := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.16)
const WELL := Color(0, 0, 0, 0.6)
const ACCENT := Color("f2a63c")
const RED := Color("e2604b")
const SOOT_CUT := Color("10151a")

var g: Dictionary = {}
## The technologies listed; empty means the ones whose effect runs (Research.visible).
var techs: Array = []
var _parts: Control
## Where a row's parts go while the rows are laid (the scrolled list), else the pane.
var _into: Control = null
## The row whose ways are open (복원 pressed with more than one way), and the
## row whose 취소 waits for the second press.
var _choosing: String = ""
var _cancelling: String = ""


## What the pane says for state `g0` (tests read this; the pane draws it).
static func model(g0: Dictionary, ids: Array = []) -> Dictionary:
	var dom: Dictionary = g0.get("dom", {}) if g0.get("dom") is Dictionary else {}
	var stores: Array = []
	for row: Array in STORES:
		stores.append({"key": row[0], "icon": row[1], "n": float(dom.get(String(row[0]), 0))})
	var rows: Array = []
	for id: String in (ids if not ids.is_empty() else Research.visible(g0)):
		rows.append(_row_model(g0, dom, id))
	return {"stores": stores, "rows": rows}


static func _row_model(g0: Dictionary, dom: Dictionary, id: String) -> Dictionary:
	var def: Dictionary = Research.TECHS[id]
	var branch: String = String(def["branch"])
	var st: Dictionary = (dom.get("techs", {}) as Dictionary).get(id, {})
	var stage: String = String(st.get("stage", "new"))
	var picked: Variant = dom["pipeFlip"] if id == "e3" and dom.has("pipeFlip") else st.get("variant")
	var choices: Dictionary = Research.variants(g0, id)
	if id == "e3" and dom.has("pipeFlip"):
		choices = {}
		choices[picked] = def["variants"][picked]
	var cost: Dictionary = Research.restore_cost(id)
	var check: Dictionary = Research.restore_check(g0, id)
	var r := {
		"id": id, "name": String(def["name"]), "branch": branch, "stage": stage,
		"active": dom.get("restoring") == id, "finishing": bool(st.get("finishing", false)),
		"share": float(st.get("progress", 0)) / maxf(1.0, float(st.get("need", 1))),
		"have": int(float((dom.get("frags", {}) as Dictionary).get(branch, 0))),
		"variant": String(def["variants"][picked]["name"]) if picked != null and def.has("variants") else "",
		"effect": _effect(id, picked), "ways": [], "word": "", "can": false, "why": "", "cost": [],
		"law": law_tag(id, picked) if LAW_TAGGED.has(id) else "",
		"law_on": LawTech.law_standing(g0, id, picked),
		"use": UiFonts.josa(LawTech.use_line(g0, id, picked)) if LAW_TAGGED.has(id) else "",
		"relations": _row_relations(dom, st, id, stage, choices),
		# What it takes from the stores each stretch while it runs, and whether
		# they could not pay it last stretch (it ran at half: Research.mult).
		"upkeep": [], "starved": bool(st.get("starved", false)), "off": false,
	}
	var upkeep: Dictionary = Research.upkeep_of(g0, id)
	for key: String in ["parts", "wood", "scrap"]:
		if float(upkeep.get(key, 0)) > 0.0:
			r["upkeep"].append({"key": key, "icon": ICON[key], "n": float(upkeep[key])})
	if stage == "new":
		# S1 offers the defective plate only when the full one cannot be had (restoreCheck).
		var mode: String = "defect" if check.get("full") != null and check.get("defect") == null else "full"
		r["need"] = int(cost["frags"] if mode == "full" else cost["defectFrags"])
		for key: String in ["parts", "wood", "scrap", "core"]:
			if int(cost[key]) > 0:
				r["cost"].append({"key": key, "icon": ICON[key], "n": float(cost[key]),
					"short": float(dom.get("cores" if key == "core" else key, 0)) < float(cost[key])})
		for v: Variant in (choices.keys() if not choices.is_empty() else [null]):
			var copy: Dictionary = g0.duplicate(true)
			r["ways"].append({"mode": mode, "variant": v, "word": String(choices[v]["name"]) if v != null else "",
				"can": Research.start_restore(copy, id, mode, v),
				"relations": [_pipe_line(dom)] if id == "e3" else _rel_words(id, v)})
		r["word"] = "결함판" if mode == "defect" else "복원"
		r["why"] = String(check.get(mode, "")) if check.get(mode) != null else ""
		r["can"] = r["ways"].any(func(w: Dictionary) -> bool: return bool(w["can"]))
		if r["why"] == "" and not r["can"]:
			r["why"] = "부품이 모자라다"
	elif bool(r["active"]):
		r["word"] = "취소"
		r["can"] = true
	elif stage == "defective":
		var why: Variant = Research.finish_check(g0, id)
		r["word"] = "완성판"
		r["can"] = why == null
		r["why"] = "" if why == null else String(why)
		r["need"] = int(cost["frags"]) - int(cost["defectFrags"])
	# Stood down (S1 standDown): it runs again for the part it gave back (restartTech).
	if bool(st.get("off", false)) and stage in ["done", "defective"]:
		r["off"] = true
		r["word"] = "다시 돌리기"
		r["why"] = Research.restart_why(g0, id)
		r["can"] = r["why"] == ""
	return r


## What the row itself says about relations (design 2c-1 6, 10-6). A technology without ways
## says it beside its name before it starts, and only when relations move. E3's relations move
## at the council's ratification, so its row says how while a restore of it waits for that vote,
## and before a start whose result an earlier rejection fixed (one way, no vote).
static func _row_relations(dom: Dictionary, st: Dictionary, id: String, stage: String, choices: Dictionary) -> Array[String]:
	if id == "e3":
		if (stage == "new" and choices.size() <= 1) or bool(st.get("pending", false)):
			return [_pipe_line(dom)]
		return []
	return _rel_words(id, null) if stage == "new" and choices.is_empty() else []


## S1 sideLine: every liking car, then every disliking car, with U+2212.
static func _rel_words(id: String, variant: Variant) -> Array[String]:
	var words: Array[String] = []
	var sides: Dictionary = Research.rel_sides(id, variant)
	for side: String in ["like", "dislike"]:
		for comm: String in sides[side]:
			words.append("%s %s%d" % [Research.COMM_NAME[comm], "+" if side == "like" else "−", int(Research.D["techRel"])])
	return words


static func _pipe_line(dom: Dictionary) -> String:
	if dom.has("pipeFlip"):
		return "앞 추인 결과로 고정"
	if dom.has("pipeMoved"):
		return "앞 추인(변형 %s)과 같은 결과면 관계 그대로, 다른 결과면 그 변형 쪽으로 관계가 움직임" % Research.TECHS["e3"]["variants"][dom["pipeMoved"]]["name"]
	return "추인 결과 쪽으로 ±5"


static func _effect(id: String, variant: Variant) -> String:
	return String(EFFECT.get(id + String(variant) if variant != null else id, EFFECT.get(id, "")))


## The laws this technology (way) needs, by title (「난방 배당·공동 난방」), or "".
static func law_tag(id: String, variant: Variant) -> String:
	var titles: Array[String] = []
	for law: String in LawTech.tech_laws(id, variant):
		titles.append(String(LawTech.LAW_TITLE[law]))
	return "·".join(titles)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var glass := TextureRect.new()
	glass.name = "Glass"
	glass.texture = GLASS
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.stretch_mode = TextureRect.STRETCH_SCALE
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(glass)
	_parts = Control.new()
	_parts.name = "Parts"
	_parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_parts)
	_draw_all()


## The pane's size for `rows` rows, in CSS px.
static func css_size(rows: int) -> Vector2:
	return Vector2(CSS_W, clampf(ROW_TOP + ROW_H * rows + 12.0, CSS_H_MIN, CSS_H_MAX))


## At the right of the screen under a band `top` game px high (as workshop_pane.gd).
func pin(top: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var s: Vector2 = css_size((techs if not techs.is_empty() else Research.visible(g)).size()) * UiFonts.K
	offset_left = -s.x
	offset_right = 0.0
	offset_top = top
	offset_bottom = top + s.y


func show_state(g0: Dictionary) -> void:
	g = g0
	_draw_all()


func _draw_all() -> void:
	if _parts == null:
		return
	_parts.visible = not g.is_empty()
	if g.is_empty():
		return
	var m: Dictionary = model(g, techs)
	RowKeep.begin(_parts)
	_head()
	_stores(m["stores"])
	var rows: Array = m["rows"]
	var ids: Array = []
	var by_id: Dictionary = {}
	for data: Dictionary in rows:
		var id: String = String(data["id"])
		ids.append(id)
		by_id[id] = data
		if _choosing == id and (String(data["stage"]) != "new" or bool(data["active"]) or (data["ways"] as Array).size() <= 1):
			_choosing = ""
		if _cancelling == id and not bool(data["active"]):
			_cancelling = ""
	if not ids.has(_choosing):
		_choosing = ""
	if not ids.has(_cancelling):
		_cancelling = ""
	var k: float = UiFonts.K
	var s: ScrollContainer = RowKeep.part(_parts, "List", func() -> Control: return ScrollContainer.new()) as ScrollContainer
	var saved: int = s.scroll_vertical
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	RowKeep.pass_mouse(s)
	s.position = Vector2(0.0, ROW_TOP) * k
	var list: Control = RowKeep.part(s, "Rows", func() -> Control: return Control.new())
	RowKeep.pass_mouse(list)
	# The fill runs in list order; the shared dictionary retains the accumulated height.
	var layout: Dictionary = {"height": 0.0}
	RowKeep.sync(list, ids, func(_id: String) -> Control:
		var row := Control.new()
		RowKeep.pass_mouse(row)
		return row,
		func(row: Control, id: String, _index: int) -> void:
			row.position = Vector2(0.0, float(layout["height"])) * k
			_into = row
			RowKeep.begin(row)
			var height: float = _row(by_id[id], 0.0)
			row.size = Vector2(CSS_W, height) * k
			layout["height"] = float(layout["height"]) + height
			RowKeep.finish(row)
			_into = null)
	list.custom_minimum_size = Vector2(CSS_W, float(layout["height"])) * k
	# The scroll range is the list's minimum height as the container last read it, and nothing
	# above this pane asks it again. Size the container after the list, asking afresh, so an
	# opened row's foot can be scrolled to and folding it gives the range back.
	s.update_minimum_size()
	s.size = Vector2(CSS_W, css_size(rows.size()).y - ROW_TOP - 12.0) * k
	RowKeep.restore_scroll(s, saved)
	_above(s)
	if list.custom_minimum_size.y > s.size.y + 0.5:
		_more(s)
	RowKeep.finish(_parts)


## While rows are left under the list's foot, the glass darkens there (as mods_pane.gd).
func _more(s: ScrollContainer) -> Control:
	var k: float = UiFonts.K
	var fade: Control = RowKeep.part(_parts, "More", func() -> Control: return Control.new())
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.position = Vector2(0.0, s.position.y + s.size.y - 22.0 * k)
	fade.size = Vector2(s.size.x, 22.0 * k)
	var bar: ScrollBar = s.get_v_scroll_bar()
	if not fade.has_meta("wired"):
		fade.set_meta("wired", true)
		fade.draw.connect(func() -> void:
			var w: float = fade.size.x
			var h: float = fade.size.y
			fade.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([Color(SHADE, 0.0), Color(SHADE, 0.0), Color(SHADE, 0.85), Color(SHADE, 0.85)])))
		bar.value_changed.connect(func(v: float) -> void: fade.visible = v < bar.max_value - bar.page - 1.0)
	fade.visible = s.scroll_vertical < (s.get_child(0) as Control).custom_minimum_size.y - s.size.y - 1.0
	return fade


## While rows are scrolled up under the stores, the glass darkens there too, half a row deep:
## a row cut at the top shows as shade, not as a strip of letter tops. The list's scroll cannot
## stop on row edges (its end is where the last row's foot shows), so the shade covers the cut.
func _above(s: ScrollContainer) -> Control:
	var k: float = UiFonts.K
	var fade: Control = RowKeep.part(_parts, "Above", func() -> Control: return Control.new())
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Over the rows' text column only: across the glass's soft left edge it would show a hard corner.
	fade.position = Vector2(ABOVE_X * k, s.position.y)
	fade.size = Vector2(s.size.x - ABOVE_X * k, ABOVE_H * k)
	var bar: ScrollBar = s.get_v_scroll_bar()
	if not fade.has_meta("wired"):
		fade.set_meta("wired", true)
		fade.draw.connect(func() -> void:
			var w: float = fade.size.x
			var h: float = fade.size.y
			fade.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([Color(SHADE, 1.0), Color(SHADE, 1.0), Color(SHADE, 0.0), Color(SHADE, 0.0)])))
		bar.value_changed.connect(func(v: float) -> void: fade.visible = v > 1.0)
	fade.visible = s.scroll_vertical > 1
	return fade


func _add(c: Control) -> Control:
	if c.get_parent() == null:
		_host().add_child(c)
	c.set_meta(RowKeep.USED_META, true)
	if not c.visible:
		c.show()
	return c


func _text(l: Label, x_css: float, base_css: float) -> void:
	_add(l)
	GlassParts.put_on(l, x_css * UiFonts.K, base_css * UiFonts.K)


## 연구 at the name's place, 접기 at the top right (workshop_pane.gd _head).
func _head() -> void:
	var k: float = UiFonts.K
	var name_l := _label("Name", "연구", UiFonts.WORD, 500, 18.0, INK, 2.16)
	name_l.name = "Name"
	_text(name_l, 44.0, 27.0)
	var fold := _bare("Fold")
	fold.position = Vector2(266.0, 0.0) * k
	fold.size = Vector2(56.0, 44.0) * k
	if fold.has_meta("wired"):
		return
	fold.set_meta("wired", true)
	fold.pressed.connect(func() -> void: folded.emit())
	_add(fold)
	var mark := TextureRect.new()
	var px: int = int(round(14.0 * k))
	mark.texture = HudIcons.texture("fwd", px, INK2, 2.0, SOOT_CUT)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2(px, px)
	mark.position = Vector2(36.0, 15.0) * k
	fold.add_child(mark)
	var word := UiFonts.label("접기", UiFonts.WORD, 400, 13.0, INK2, 1.3)
	fold.add_child(word)
	GlassParts.put_on(word, mark.position.x - 3.0 * k - GlassParts.text_w(word), 26.5 * k)


func _stores(stores: Array) -> void:
	for i in stores.size():
		var s: Dictionary = stores[i]
		var x: float = 44.0 + 68.0 * i
		_add(_mark(String(s["icon"]), 18.0, Vector2(x, 39.0), INK2, "StoreMark_" + String(s["key"])))
		var n := _label("Store_" + String(s["key"]), _num(float(s["n"])), UiFonts.NUMBER, 500, 15.0, INK, 0.225)
		n.name = "Store_" + String(s["key"])
		_text(n, x + 22.0, 54.0)


## A technology: its branch mark and name; what it needs, how far it is, or
## what it does; its key, or a key for each way while its ways are open.
func _row(r: Dictionary, top: float) -> float:
	var k: float = UiFonts.K
	var id: String = String(r["id"])
	_add(_mark(BRANCH_ICON[String(r["branch"])], 15.0, Vector2(44.0, top + 5.0), INK2, "Branch_" + id))
	if _choosing == id:
		var way_height: float = _ways(r, top)
		var back := _key("뒤로", "Key_" + id, true)
		_add(back)
		back.position = Vector2(232.0, top + 5.0) * k
		back.size = Vector2(KEY_W, KEY_H) * k
		back.tooltip_text = ""
		_wire_key(back, r)
		return way_height
	# A picked way is the thing itself (S1 techTitle): its name stands for the technology's.
	var title: String = String(r["variant"]) if String(r["variant"]) != "" else String(r["name"])
	var word := _label("Name_" + id, title, UiFonts.WORD, 500, 13.0, INK, 2.08)
	word.name = "Name_" + id
	_text(word, 64.0, top + 18.0)
	var law_x1: float = 226.0 if String(r["word"]) != "" else 312.0
	var stage: String = String(r["stage"])
	# A running technology's upkeep stands where its key would; the name line's
	# law tag stops short of it (the line under the name has the width).
	var name_x1: float = law_x1
	if not bool(r["active"]) and not bool(r["off"]) and stage != "new" and not (r["upkeep"] as Array).is_empty():
		name_x1 = minf(law_x1, _upkeep(r, top) - 8.0)
	var tagged: bool = _law(r, top + 18.0, 64.0 + GlassParts.text_w(word) / k + 8.0, name_x1)
	# Where the line under the name ends, for a tag the name line had no room for.
	var under_x: float = 0.0
	if bool(r["active"]):
		_bar(id, float(r["share"]), top)
		under_x = 208.0
	elif stage == "new":
		_pips(id, int(r["have"]), int(r["need"]), top)
		under_x = _cost(r["cost"], top + 40.0, "Cost_" + id, 44.0 + (14.0 * int(r["need"]) + 10.0 if int(r["need"]) > 0 else 0.0))
	else:
		var half: bool = not bool(r["off"]) and (stage == "defective" or bool(r["starved"]))
		_add(_mark("check", 13.0, Vector2(44.0, top + 28.0), ACCENT if half else INK2, "Done_" + id))
		var said := _label("Effect_" + id, ("멈춤 " if bool(r["off"]) else ("½ " if half else "")) + String(r["effect"]), UiFonts.WORD, 400, 12.0, INK2, 0.52)
		said.name = "Effect_" + id
		_text(said, 62.0, top + 40.0)
		under_x = 62.0 + GlassParts.text_w(said) / k
	var law_under: bool = false
	if not tagged:
		law_under = _law(r, top + 40.0, under_x + 8.0, law_x1)
	var height: float = ROW_H
	var relations: Array = r["relations"]
	if not relations.is_empty():
		var x0: float = maxf(64.0 + GlassParts.text_w(word) / k + 8.0, under_x + 8.0)
		var x1: float = name_x1
		var base: float = top + 18.0
		if String(r["law"]) != "":
			x0 = under_x + 8.0
			x1 = law_x1
			base = top + 40.0
			# The law tag stands on the line under the name (not beside it): stop short of it.
			if law_under and _host().has_node("Law_" + id):
				var tag: Label = _host().get_node("Law_" + id) as Label
				x1 = minf(x1, tag.position.x / k - 8.0)
		var widest: float = 0.0
		for text: String in relations:
			widest = maxf(widest, _rel_width(text))
		if x1 - x0 < widest:
			x0 = 64.0
			x1 = law_x1
			base = top + ROW_H + _rel_height()
		height = maxf(height, _relations(relations, "Rel_" + id + "_", x0, x1, base, true) - top + 5.0)
	if String(r["word"]) == "":
		return height
	var cancelling: bool = _cancelling == id
	var key := _key("정말 취소" if cancelling else String(r["word"]), "Key_" + id, bool(r["can"]))
	_add(key)
	key.position = Vector2(232.0, top + 5.0) * k
	key.size = Vector2(KEY_W, KEY_H) * k
	key.tooltip_text = String(r["why"]) if String(r["why"]) != "" else String(r["use"])
	_wire_key(key, r)
	return height


## The law a law technology is for, on the baseline `base`, right-aligned
## between `x0` and `x1`: dim ink while it stands, red with 없음 while it does
## not. When both laws do not fit, the first. False when nothing was put (no
## law, or no room: the caller tries the line under).
func _law(r: Dictionary, base: float, x0: float, x1: float) -> bool:
	if String(r["law"]) == "":
		return true
	var on: bool = bool(r["law_on"])
	var k: float = UiFonts.K
	for text: String in [String(r["law"]), String(r["law"]).get_slice("·", 0)]:
		var tag := _label("Law_" + String(r["id"]), text + ("" if on else " 없음"), UiFonts.WORD, 400, 11.0, INK2 if on else RED, 0.44)
		tag.name = "Law_" + String(r["id"])
		var w: float = GlassParts.text_w(tag) / k
		if x1 - w >= x0:
			_text(tag, x1 - w, base)
			return true
		tag.set_meta(RowKeep.USED_META, false)
	return false


## A running technology's upkeep a stretch where its key would stand: each
## store's mark and amount, red when the stores could not pay it. Returns
## where it starts (CSS px), so the name line's law tag stops short of it.
func _upkeep(r: Dictionary, top: float) -> float:
	var k: float = UiFonts.K
	var x: float = 316.0
	var upkeep: Array = r["upkeep"]
	# S1 upkeepText's words around the marks: 「유지 ⚙ 0.25/구간」, what it takes a stretch.
	var tint: Color = RED if bool(r["starved"]) else INK2
	var per := _label("UpkeepPer_" + String(r["id"]), "/구간", UiFonts.WORD, 400, 12.0, tint, 0.0)
	per.name = "UpkeepPer_" + String(r["id"])
	x -= GlassParts.text_w(per) / k
	_text(per, x, top + 26.0)
	x -= 1.0
	for i in range(upkeep.size() - 1, -1, -1):
		var u: Dictionary = upkeep[i]
		var color: Color = tint
		var n := _label("Upkeep_%s_%s" % [r["id"], u["key"]], str(snappedf(float(u["n"]), 0.01)), UiFonts.NUMBER, 400, 13.0, color, 0.52)
		n.name = "Upkeep_%s_%s" % [r["id"], u["key"]]
		x -= GlassParts.text_w(n) / k
		_text(n, x, top + 26.0)
		x -= 19.0
		_add(_mark(String(u["icon"]), 15.0, Vector2(x, top + 13.0), color, "UpkeepMark_%s_%s" % [r["id"], u["key"]]))
		x -= 10.0
	var word := _label("UpkeepWord_" + String(r["id"]), "유지", UiFonts.WORD, 400, 12.0, tint, 0.0)
	word.name = "UpkeepWord_" + String(r["id"])
	x += 4.0 - GlassParts.text_w(word) / k
	_text(word, x, top + 26.0)
	return x


## The ways a restoration can go, a full key each, in the row's place (its
## branch mark stays so the row is still the same technology's).
func _ways(r: Dictionary, top: float) -> float:
	var k: float = UiFonts.K
	var ways: Array = r["ways"]
	var height: float = ROW_H
	for i: int in ways.size():
		var w: Dictionary = ways[i]
		var key := _key(String(w["word"]), "Way_%s_%s" % [r["id"], w["variant"]], bool(w["can"]))
		key.position = Vector2(64.0 + (WAY_W + 4.0) * i, top + 5.0) * k
		key.size = Vector2(WAY_W, KEY_H) * k
		key.tooltip_text = UiFonts.josa(LawTech.use_line(g, String(r["id"]), w["variant"]))
		key.set_meta("tech_id", String(r["id"]))
		key.set_meta("way", w)
		# Each way's own cars under its key (S1 sideLine per way row). E3's ways share one
		# notice (the ratification decides), said once under both keys below.
		var relations: Array = w["relations"]
		if relations.is_empty():
			relations = ["관계 안 움직임"]
		if String(r["id"]) != "e3":
			height = maxf(height, _relations(relations, "Rel_%s_%s_" % [r["id"], w["variant"]],
				64.0 + (WAY_W + 4.0) * i, 64.0 + (WAY_W + 4.0) * i + WAY_W, top + ROW_H + _rel_height()) - top + 5.0)
		if key.has_meta("wired"):
			continue
		key.set_meta("wired", true)
		key.pressed.connect(func() -> void:
			if not key.has_meta("way") or not key.has_meta("tech_id"):
				return
			var current: Dictionary = key.get_meta("way")
			if not Research.start_restore(g, String(key.get_meta("tech_id")), String(current["mode"]), current["variant"]):
				UiDeny.shake(key)
				return
			_choosing = ""
			_after())
	if String(r["id"]) == "e3" and not ways.is_empty():
		height = maxf(height, _relations(ways[0]["relations"], "Rel_e3_ways_",
			64.0, 64.0 + (WAY_W + 4.0) * ways.size() - 4.0, top + ROW_H + _rel_height()) - top + 5.0)
	return height


static func _rel_width(text: String) -> float:
	return UiFonts.face(UiFonts.WORD, 400).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.size(11.0)).x / UiFonts.K


static func _rel_height() -> float:
	return UiFonts.face(UiFonts.WORD, 400).get_height(UiFonts.size(11.0)) / UiFonts.K


## Keep each car's name and amount together when it fits; longer notices wrap at spaces.
static func _rel_lines(words: Array, width: float) -> Array[String]:
	var lines: Array[String] = []
	var line: String = ""
	for word: String in words:
		var joined: String = word if line == "" else line + " · " + word
		if _rel_width(joined) <= width:
			line = joined
			continue
		if line != "":
			lines.append(line)
		var rest: String = word
		while rest.length() > 1 and _rel_width(rest) > width:
			var cut: int = rest.length() - 1
			while cut > 1 and _rel_width(rest.left(cut)) > width:
				cut -= 1
			var space: int = rest.rfind(" ", cut)
			if space > 0:
				cut = space
			lines.append(rest.left(cut).strip_edges())
			rest = rest.substr(cut).strip_edges()
		line = rest
	if line != "":
		lines.append(line)
	return lines


## One label per measured line makes its ink and its row's bottom explicit.
func _relations(words: Array, prefix: String, x0: float, x1: float, base: float, right: bool = false) -> float:
	var lines: Array[String] = _rel_lines(words, x1 - x0)
	var bottom: float = 0.0
	for i: int in lines.size():
		var label: Label = _label(prefix + str(i), lines[i], UiFonts.WORD, 400, 11.0, INK2)
		var h: float = _rel_height()
		_text(label, x1 - GlassParts.text_w(label) / UiFonts.K if right else x0, base + (h + 2.0) * i)
		bottom = maxf(bottom, label.position.y / UiFonts.K + maxf(h, label.size.y / UiFonts.K))
	return bottom


func _press(r: Dictionary, key: Button) -> void:
	var id: String = String(r["id"])
	if not bool(r["can"]):
		UiDeny.shake(key)
		return
	if bool(r["off"]):
		if Research.restart(g, id):
			_after()
		else:
			UiDeny.shake(key)
		return
	if bool(r["active"]):
		if _cancelling != id:
			_cancelling = id
			_draw_all()
			return
		Research.cancel_restore(g)
		_cancelling = ""
		_after()
		return
	_cancelling = ""
	if String(r["stage"]) == "defective":
		if Research.start_finish(g, id):
			_after()
		return
	var ways: Array = r["ways"]
	if ways.size() > 1:
		_choosing = id
		_draw_all()
		return
	var w: Dictionary = ways[0]
	if Research.start_restore(g, id, String(w["mode"]), w["variant"]):
		_after()
	else:
		UiDeny.shake(key)


## The branch's fragments the plate needs: a filled pip for each one held.
func _pips(id: String, have: int, need: int, top: float) -> void:
	var k: float = UiFonts.K
	var pips: Control = RowKeep.part(_host(), "Pips_" + id, func() -> Control: return Control.new())
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.position = Vector2(44.0, top + 30.0) * k
	pips.size = Vector2(14.0 * maxi(need, 1), 12.0) * k
	pips.set_meta("have", have)
	pips.set_meta("need", need)
	if not pips.has_meta("wired"):
		pips.set_meta("wired", true)
		pips.draw.connect(func() -> void:
			for i: int in int(pips.get_meta("need")):
				var c := Vector2((14.0 * i + 5.0) * k, 6.0 * k)
				if i < int(pips.get_meta("have")):
					pips.draw_circle(c, 4.0 * k, INK)
				else:
					pips.draw_arc(c, 4.0 * k, 0.0, TAU, 20, RED, 1.5 * k, true))
	pips.queue_redraw()


func _bar(id: String, share: float, top: float) -> void:
	var k: float = UiFonts.K
	var bar: Control = RowKeep.part(_host(), "Progress_" + id, func() -> Control: return Control.new())
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(44.0, top + 30.0) * k
	bar.size = Vector2(164.0, 6.0) * k
	bar.set_meta("share", share)
	if not bar.has_meta("wired"):
		bar.set_meta("wired", true)
		bar.draw.connect(func() -> void:
			var rad: float = 3.0 * k
			GlassParts.round_rect(bar, Rect2(Vector2.ZERO, bar.size), rad, WELL)
			bar.draw_polyline(GlassParts.outline(Rect2(Vector2.ZERO, bar.size), rad), HAIR, 1.0 * k, true)
			var w: float = bar.size.x * float(bar.get_meta("share"))
			if w > 0.5:
				GlassParts.round_rect(bar, Rect2(0, 0, maxf(w, rad * 2.0), bar.size.y), rad, ACCENT))
	bar.queue_redraw()


## What a plate costs besides fragments: each store's mark and number, red when
## short. Gives where the last number ends (css px).
func _cost(cost: Array, base: float, prefix: String, x0: float) -> float:
	var k: float = UiFonts.K
	var x: float = x0
	for c: Dictionary in cost:
		var short: bool = bool(c["short"])
		_add(_mark(String(c["icon"]), 15.0, Vector2(x, base - 13.0), RED if short else INK2, prefix + "_mark_" + String(c["key"])))
		var n := _label("%s_%s" % [prefix, c["key"]], _num(float(c["n"])), UiFonts.NUMBER, 400, 13.0, RED if short else INK2, 0.52)
		n.name = "%s_%s" % [prefix, c["key"]]
		_text(n, x + 19.0, base)
		x += 19.0 + GlassParts.text_w(n) / k + 12.0
	return x - 12.0 if not cost.is_empty() else x0


func _after() -> void:
	_draw_all()
	changed.emit()


func _mark(icon: String, css: float, at: Vector2, color: Color = INK2, key_name: String = "") -> TextureRect:
	var mark: TextureRect = TextureRect.new() if key_name == "" else RowKeep.part(_host(), key_name, func() -> Control: return TextureRect.new()) as TextureRect
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px: int = int(round(css * UiFonts.K))
	mark.texture = HudIcons.texture(icon, px, color, 2.0, SOOT_CUT) if icon != "" else null
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size = Vector2(px, px)
	mark.position = at * UiFonts.K
	return mark


## A matte key with its word; dimmed when it cannot (a press then shakes it).
func _key(word: String, key_name: String, can: bool) -> Button:
	var k: float = UiFonts.K
	var b: Button = _bare(key_name)
	var lab: Label = b.get_node_or_null("Word") as Label
	if lab == null:
		b.draw.connect(func() -> void:
			var rect := Rect2(Vector2(1, 1) * k, b.size - Vector2(2, 2) * k)
			GlassParts.round_rect(b, rect, 8.0 * k, Color(1, 1, 1, 0.06))
			b.draw_polyline(GlassParts.outline(rect, 8.0 * k), HAIR, 1.5 * k, true))
		lab = UiFonts.label("", UiFonts.WORD, 500, 13.0, INK, 0.52)
		lab.name = "Word"
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lab)
	lab.text = word
	UiDeny.dim(b, not can)
	return b


func _bare(key_name: String) -> Button:
	return RowKeep.part(_host(), key_name, func() -> Control:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		return b) as Button


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v



func _host() -> Control:
	return _into if _into != null else _parts


func _label(key_name: String, word: String, kind: int, weight: int, css: float, color: Color, spacing: float = 0.0) -> Label:
	var lab: Label = RowKeep.part(_host(), key_name, func() -> Control:
		return UiFonts.label("", kind, weight, css, color, spacing)) as Label
	lab.text = word
	lab.add_theme_color_override("font_color", color)
	return lab


func _wire_key(key: Button, data: Dictionary) -> void:
	key.set_meta("row", data)
	if key.has_meta("wired"):
		return
	key.set_meta("wired", true)
	key.pressed.connect(func() -> void:
		if not key.has_meta("row"):
			return
		var current: Dictionary = key.get_meta("row")
		if _choosing == String(current["id"]):
			_choosing = ""
			_draw_all()
		else:
			_press(current, key))
