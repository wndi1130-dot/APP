extends Control
## What a stretch costs in coal or food and why (J12 「예보와 결과에 같은
## 원인」): the same smoked glass as a carriage's pane (car_pane.gd), where it
## stands, when the gauges' coal or food is pressed (train_gauges.gd
## stock_pressed). Two columns over the same causes: 이번, this stretch's
## forecast split over its parts as settle will split it (train_turn.gd
## forecast_parts, turn_common.gd split_parts), and 지난, what the last settle
## put on the ledger for each. So a cause's 이번 is what its 지난 will read when
## nothing changes before the train leaves. Under 칸 난방, what the insulated
## cars keep off it this stretch.
##
## The causes' words are S1's (s1/src/ui/why_names.ts). It only reads the state.

signal folded

const RowKeep = preload("res://game/ui/row_keep.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const St = preload("res://game/train/train_state.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")
const TurnCommon = preload("res://game/train/turn/turn_common.gd")
const GLASS := preload("res://game/ui/tex/pane_glass.png")

const CSS_SIZE := Vector2(330, 286)
const STOCK: Dictionary = {"coal": ["coal", "석탄"], "food": ["food", "식량"]}
## s1/src/ui/why_names.ts, the forecast's parts.
const WHY_NAME: Dictionary = {
	"run": "기관 운행", "idle": "꼬리칸이 손을 놓음", "heat": "칸 난방", "calm.pot": "저녁 솥불",
	"disaster": "재난", "loco": "기관차", "hands": "일손이 모자람", "upkeep": "열차 살림",
	"ration": "배급", "freeze": "선로 결빙",
}
const SAVED := "단열로 아낌"
const REST := "그 밖의 정산"
const TOTAL := "합계"
const NONE := "–"
## Rows of words under the column heads; the two columns end at these.
const ROW_TOP: float = 84.0
const ROW_H: float = 22.0
const NOW_X: float = 238.0
const LAST_X: float = 306.0
## A share smaller than this reads as nothing (one decimal on the pane).
const NIL: float = 0.05
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const INK3 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.54)
const HAIR := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.16)
const SOOT_CUT := Color("10151a")

## "coal" or "food".
var which: String = "coal"
var g: Dictionary = {}
var t: Dictionary = {}
var _parts: Control
var _into: Control = null


## What the pane says for `key` in state `g0` (tests read this; the pane draws
## it): {key, word, icon, now, last, rows: [{why, word, now, last, saved?}],
## rest}. `now` is the forecast as the stock moves (a cost is negative); `last`
## is null before the first settle; a row's `last` is null when the ledger has
## no line for it.
static func model(g0: Dictionary, t0: Dictionary, key: String) -> Dictionary:
	if g0.is_empty() or t0.is_empty() or not STOCK.has(key):
		return {}
	var cost: float = float(TrainTurn.forecast(g0, t0)[key])
	var parts: Array = TrainTurn.forecast_parts(g0, t0)[key]
	var now: Dictionary = {}
	if cost != 0.0:
		for row: Array in TurnCommon.split_parts(-cost, parts):
			now[String(row[0])] = float(now.get(String(row[0]), 0.0)) + float(row[1])
	var settled: Variant = g0.get("lastSettle")
	var last_total: Variant = float(settled[key]) if settled is Dictionary and settled.has(key) else null
	var last: Dictionary = settle_rows(g0, key, parts) if last_total != null else {}
	var rows: Array = []
	for part: Array in parts:
		var why: String = String(part[0])
		var n: float = float(now.get(why, 0.0))
		var l: Variant = last.get(why)
		if absf(n) < NIL and (l == null or absf(float(l)) < NIL):
			continue
		var row := {"why": why, "word": String(WHY_NAME.get(why, why)), "now": n, "last": l}
		if why == "heat" and key == "coal":
			var kept: float = insulation_kept(g0, t0)
			if kept >= NIL:
				row["saved"] = kept
		rows.append(row)
	var rest: Variant = null
	if last_total != null:
		var named: float = 0.0
		for v: Variant in last.values():
			named += float(v)
		if absf(float(last_total) - named) >= NIL:
			rest = float(last_total) - named
	return {"key": key, "word": String(STOCK[key][1]), "icon": String(STOCK[key][0]), "now": -cost, "last": last_total, "rows": rows, "rest": rest}


## The last settle's lines for `key` on the ledger, {why: share}: the block
## bump_parts wrote, read back from the newest line of one of `parts`' causes
## while the lines run on in the same stock and are causes not yet seen.
static func settle_rows(g0: Dictionary, key: String, parts: Array) -> Dictionary:
	var whys: Array = parts.map(func(p: Array) -> String: return String(p[0]))
	var ledger: Variant = g0.get("ledger")
	var out: Dictionary = {}
	if not ledger is Array:
		return out
	var i: int = (ledger as Array).size() - 1
	while i >= 0 and not _in_block(ledger[i], key, whys, {}):
		i -= 1
	while i >= 0 and _in_block(ledger[i], key, whys, out):
		out[String(ledger[i]["why"])] = float(ledger[i]["d"])
		i -= 1
	return out


static func _in_block(row: Variant, key: String, whys: Array, seen: Dictionary) -> bool:
	return row is Dictionary and String(row.get("k", "")) == key and whys.has(String(row.get("why", ""))) \
		and not seen.has(String(row.get("why", "")))


## How much coal the insulated cars keep off this stretch's heating: the
## heating with none insulated less the heating as it is, by the laws' heat
## multiplier and the outside's stage as forecast takes them.
static func insulation_kept(g0: Dictionary, t0: Dictionary) -> float:
	var bare: float = 0.0
	var now: float = 0.0
	for c: String in St.comms(t0):
		bare += TrainTurn.comm_heat(g0, c, false)
		now += TrainTurn.comm_heat(g0, c)
	return (bare - now) * float(t0["P"]["coalHeatPerLever"]) * TrainClimate.temp_mult(g0, t0) * St.law_mult(g0, t0, "heatMult")


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


## At the right of the screen under a band `top` game px high (as car_pane.gd).
func pin(top: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var s: Vector2 = CSS_SIZE * UiFonts.K
	offset_left = -s.x
	offset_right = 0.0
	offset_top = top
	offset_bottom = top + s.y


func show_state(g0: Dictionary, t0: Dictionary) -> void:
	g = g0
	t = t0
	_draw_all()


func _draw_all() -> void:
	if _parts == null:
		return
	var m: Dictionary = model(g, t, which)
	_parts.visible = not m.is_empty()
	if m.is_empty():
		return
	RowKeep.begin(_parts)
	_head(m)
	_heads()
	var ids: Array = ["total"]
	var rows: Dictionary = {"total": {"word": TOTAL, "key": "Total", "now": float(m["now"]), "last": m["last"],
		"base": ROW_TOP, "color": INK, "weight": 500}}
	var y: float = ROW_TOP + ROW_H + 4.0
	for data: Dictionary in m["rows"]:
		var id: String = "why_" + String(data["why"])
		ids.append(id)
		rows[id] = {"word": String(data["word"]), "key": "Row_" + String(data["why"]), "now": float(data["now"]),
			"last": data["last"], "base": y, "color": INK2, "weight": 400}
		y += ROW_H
		if data.has("saved"):
			var saved_id: String = "saved_" + String(data["why"])
			ids.append(saved_id)
			rows[saved_id] = {"word": SAVED, "key": "Saved", "now": float(data["saved"]), "last": null,
				"base": y, "color": INK3, "weight": 400, "indent": 14.0, "no_last": true}
			y += ROW_H
	if m["rest"] != null:
		ids.append("rest")
		rows["rest"] = {"word": REST, "key": "Rest", "now": 0.0, "last": m["rest"],
			"base": y, "color": INK3, "weight": 400, "no_now": true}
		y += ROW_H
	var k: float = UiFonts.K
	var top: float = ROW_TOP - 18.0
	var fresh_scroll: bool = not _parts.has_node("List")
	var s: ScrollContainer = RowKeep.part(_parts, "List", func() -> Control: return ScrollContainer.new()) as ScrollContainer
	var saved: int = s.scroll_vertical
	if fresh_scroll:
		s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		RowKeep.pass_mouse(s)
		s.position = Vector2(0.0, top) * k
		s.size = Vector2(CSS_SIZE.x, CSS_SIZE.y - top) * k
	var list: Control = RowKeep.part(s, "Rows", func() -> Control: return Control.new())
	RowKeep.pass_mouse(list)
	list.custom_minimum_size = Vector2(CSS_SIZE.x, y - top) * k
	RowKeep.sync(list, ids, func(_id: String) -> Control:
		var row := Control.new()
		RowKeep.pass_mouse(row)
		row.size = Vector2(CSS_SIZE.x, ROW_H) * k
		return row,
		func(row: Control, id: String, _index: int) -> void:
			var data: Dictionary = rows[id]
			row.position = Vector2(0.0, float(data["base"]) - ROW_TOP) * k
			_into = row
			RowKeep.begin(row)
			_line(String(data["word"]), String(data["key"]), float(data["now"]), data["last"], 18.0,
				data["color"], int(data["weight"]), float(data.get("indent", 0.0)), bool(data.get("no_last", false)), bool(data.get("no_now", false)))
			if id == "total":
				_add(_rule(26.0))
			RowKeep.finish(row)
			_into = null)
	RowKeep.restore_scroll(s, saved)
	RowKeep.finish(_parts)


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


## The stock's mark and word at the name's place, 접기 at the top right (workshop_pane.gd _head).
func _head(m: Dictionary) -> void:
	var k: float = UiFonts.K
	_add(_mark(String(m["icon"]), 18.0, Vector2(18.0, 13.0), INK2, "StockMark"))
	var name_l := _label("Name", String(m["word"]), UiFonts.WORD, 500, 18.0, INK, 2.16)
	name_l.name = "Name"
	_text(name_l, 44.0, 27.0)
	var fold: Button = _bare("Fold")
	fold.position = Vector2(266.0, 0.0) * k
	fold.size = Vector2(56.0, 44.0) * k
	if fold.has_meta("wired"):
		return
	fold.set_meta("wired", true)
	fold.pressed.connect(func() -> void: folded.emit())
	_add(fold)
	var mark := _mark("fwd", 14.0, Vector2(36.0, 15.0))
	fold.add_child(mark)
	var word := UiFonts.label("접기", UiFonts.WORD, 400, 13.0, INK2, 1.3)
	fold.add_child(word)
	GlassParts.put_on(word, mark.position.x - 3.0 * k - GlassParts.text_w(word), 26.5 * k)


## 이번 and 지난 over their columns.
func _heads() -> void:
	for h: Array in [["이번", "HeadNow", NOW_X], ["지난", "HeadLast", LAST_X]]:
		var l := _label(String(h[1]), String(h[0]), UiFonts.WORD, 400, 12.0, INK3, 0.24)
		l.name = String(h[1])
		_right(l, float(h[2]), 58.0)


## A cause's word at the left, its 이번 and 지난 ending at their columns.
## `last` null draws 「–」 for the total and nothing for a row.
func _line(word: String, key_name: String, now: float, last: Variant, base: float, color: Color, weight: int,
		indent: float = 0.0, no_last: bool = false, no_now: bool = false) -> void:
	var w := _label(key_name, word, UiFonts.WORD, weight, 13.0, color, 0.52)
	w.name = key_name
	_text(w, 44.0 + indent, base)
	if not no_now:
		var n := _label(key_name + "_now", signed(now), UiFonts.NUMBER, weight, 13.0, color, 0.195)
		n.name = key_name + "_now"
		_right(n, NOW_X, base)
	if no_last:
		return
	var text: String = signed(float(last)) if last != null else (NONE if key_name == "Total" else "")
	if text == "":
		return
	var l := _label(key_name + "_last", text, UiFonts.NUMBER, weight, 13.0, color, 0.195)
	l.name = key_name + "_last"
	_right(l, LAST_X, base)


func _right(l: Label, x_css: float, base_css: float) -> void:
	_add(l)
	GlassParts.put_on(l, x_css * UiFonts.K - GlassParts.text_w(l), base_css * UiFonts.K)


func _rule(base: float) -> Control:
	var k: float = UiFonts.K
	var rule: Control = RowKeep.part(_host(), "Rule", func() -> Control: return Control.new())
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.position = Vector2(44.0, base) * k
	rule.size = Vector2(LAST_X - 44.0, 1.0) * k
	if not rule.has_meta("wired"):
		rule.set_meta("wired", true)
		rule.draw.connect(func() -> void: rule.draw_line(Vector2.ZERO, Vector2(rule.size.x, 0), HAIR, 1.0 * k, true))
	return rule


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


## −4, +0.5 or 0, with one decimal at most.
static func signed(v: float) -> String:
	var r: float = snappedf(v, 0.1)
	if absf(r) < 0.05:
		return "0"
	var a: float = absf(r)
	return ("−" if r < 0.0 else "+") + (str(int(a)) if is_equal_approx(a, roundf(a)) else "%.1f" % a)



func _host() -> Control:
	return _into if _into != null else _parts


func _label(key_name: String, word: String, kind: int, weight: int, css: float, color: Color, spacing: float = 0.0) -> Label:
	var lab: Label = RowKeep.part(_host(), key_name, func() -> Control:
		return UiFonts.label("", kind, weight, css, color, spacing)) as Label
	lab.text = word
	lab.add_theme_color_override("font_color", color)
	return lab


func _bare(key_name: String) -> Button:
	return RowKeep.part(_host(), key_name, func() -> Control:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		return b) as Button
