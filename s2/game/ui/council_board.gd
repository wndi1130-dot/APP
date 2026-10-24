extends Control
## The seats of a session (UI 3단계 시안 2차 k3c_views.js hemiSVG · pitHTML ·
## tallyHTML, c3.css .cn, B1; 424 × 284 at 190, 52): the wooden half-ring
## baked off the mockup (tex/council_board.png: its shadow, the brass rims, the
## grain and the pit's glass), a stone on it for each seat in a wedge a group,
## left to right in car order (the tail first), their name plates beyond the
## rim, the stones' four meanings in the corner, and in the pit three plates of
## one size (확보 · 예상 · 필요: the yes in hand, the yes to expect, the yes
## needed) with the bar under them that only helps. After the vote the
## undecided stones turn one by one in the order the count took them, the bar
## fills a vote at a time, and the verdict is stamped in the pit.
##
## Stones (tex/stone_*.png, the mockup's gradients): y yes, blue · u undecided,
## grey · s a no that can be won, pale red with a dark rim · n a no that will
## not move, dark red (after the vote every no) · a away from the session, an
## empty socket (the mockup has every seat filled; the game counts the away).
## In a wedge they fill a column at a time from the inside out: yes, undecided,
## the soft no, the hard no, the away, so each reads as one mass.
##
## The numbers are the model's (council_card.gd model): seats and the four
## counts a group, the yes in hand, expected and at most, and the need.
##
## A group is picked by its plate (or from the pane): its wedge lights, its band
## and plate turn lamp amber, and a line runs from it round the rim to the pane
## at the right (.hsel · .hband.on · .hplate.on · .hlink).

signal revealed
signal picked(gi: int)

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const BOARD := preload("res://game/ui/tex/council_board.png")
const STONES: Dictionary = {
	"y": preload("res://game/ui/tex/stone_y.png"),
	"u": preload("res://game/ui/tex/stone_u.png"),
	"s": preload("res://game/ui/tex/stone_s.png"),
	"n": preload("res://game/ui/tex/stone_n.png"),
}
const SOCKET := preload("res://game/ui/tex/stone_shadow.png")

const CSS_SIZE := Vector2(424, 284)
## Where the baked board lies in the block (its picture is 3 × this).
const BOARD_AT := Vector2(1, 29)
const BOARD_CSS := Vector2(406, 213)
## hemiSVG's geometry, mockup px in the block: the centre, the wedges' end
## margin and the gap between them, the board's rims, the four rows of seats.
const CX: float = 204.0
const CY: float = 232.0
const T0: float = 0.045
const GAP: float = 0.034
const RO: float = 192.0
const RI: float = 104.0
const ROWS: Array = [120.0, 139.0, 158.0, 177.0]
const BAND_R: float = 198.0
## A stone's sprite edge (16, the stone 6.4 round in it).
const STONE_BOX: float = 16.0
## The legend (.hkey) and the pit (.pit 107, 135, 194 × 97; .tally 107, 243).
const KEY_AT := Vector2(4, 4)
const PIT_X: float = 107.0
const PIT_W: float = 194.0
const PLATES_Y: float = 185.0
const TALLY_Y: float = 243.0
## The reveal: a turn every 85 ms from .5 s; the stamp .35 s after the last,
## the line under it .3 s after that (c3.css .flip, .pit.is-res).
const TURN_S: float = 0.085
const FIRST_S: float = 0.5
const STAMP_AFTER: float = 0.35
const LINE_AFTER: float = 0.65

const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const KEY_INK := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.8)
const PL_LABEL := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.66)
const SKY := Color("8bd0f2")
const RED := Color("e2604b")
const AMBER := Color("f2a63c")
const AMBER_L := Color("ffc66c")
const PLATE := Color("10161c")
const PLATE_LIP := Color(247 / 255.0, 230 / 255.0, 180 / 255.0, 0.5)
const PL_LIP := Color(247 / 255.0, 230 / 255.0, 180 / 255.0, 0.42)
const GOT_INK := Color("9fcbf3")
const SHORT_INK := Color("f2a493")
const SEP := Color(18 / 255.0, 9 / 255.0, 2 / 255.0, 0.66)
const BAND := Color(196 / 255.0, 206 / 255.0, 216 / 255.0, 0.4)
const GOT_BAR: Array = [[0.0, Color("bfe0fb")], [0.55, Color("5a9fe6")], [1.0, Color("2f6db5")]]
## The picked group: its wedge's light, its plate's ink and lip, and the line to
## the pane (an arc 204 round to .26 rad, then across to 403; a dot at its end).
const SEL_FILL := Color(1.0, 226 / 255.0, 170 / 255.0, 0.12)
const PLATE_ON_INK := Color("2a1804")
const PLATE_ON_LIP := Color(1, 1, 1, 0.55)
const LINK_R: float = 204.0
const LINK_A: float = 0.26
const LINK_X: float = 403.0

var model: Dictionary = {}
var result: Dictionary = {}
## The picked group's index, -1 for none.
var sel: int = -1
## Per group: {"a0", "a1", "mid", "seats": [Vector2 mockup px]} in fill order.
var places: Array = []
## Per group, each seat's kind in fill order.
var kinds: Array = []
var _turns: Array = []         # the reveal's turns: {"g", "i", "to", "at"}
var _turn_from: Dictionary = {}  # "g:i" → the kind it turns from, while it turns
var _clock: float = -1.0
var _yes_shown: int = 0
var _labels: Dictionary = {}
var _glow: GradientTexture2D


func _init() -> void:
	# Only the plates take a tap (_has_point); the rest lets it through.
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = CSS_SIZE * UiFonts.K
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(false)


## Where each seat is (mockup px in the block) and each wedge's angles, for
## groups of `counts` seats (hemiSVG): the half-ring is shared by seats, less
## a margin at both ends and a gap between wedges; a wedge's seats go to the
## four rows by their length (what is left over to the rows with the most
## left), and are taken a column at a time (the longest row's columns), from
## the inside out.
static func layout(counts: Array) -> Array:
	var total: int = 0
	for n in counts:
		total += int(n)
	var span: float = PI - 2.0 * T0 - GAP * float(counts.size() - 1)
	var sum_r: float = 0.0
	for r in ROWS:
		sum_r += float(r)
	var a: float = PI - T0
	var out: Array = []
	for n0 in counts:
		var n: int = int(n0)
		var w: float = span * float(n) / float(maxi(1, total))
		var a0: float = a
		var a1: float = a - w
		a = a1 - GAP
		var raw: Array = []
		var cnt: Array = []
		var left: int = n
		for r in ROWS:
			var v: float = float(n) * float(r) / sum_r
			raw.append(v)
			cnt.append(int(floor(v)))
			left -= int(floor(v))
		var order: Array = range(ROWS.size())
		order.sort_custom(func(p: int, q: int) -> bool:
			var fp: float = float(raw[p]) - float(cnt[p])
			var fq: float = float(raw[q]) - float(cnt[q])
			return fp > fq if fp != fq else p < q)
		for j in left:
			cnt[order[j]] = int(cnt[order[j]]) + 1
		var most: int = 0
		for c in cnt:
			most = maxi(most, int(c))
		var ss: Array = []
		for kk in ROWS.size():
			var m: int = int(cnt[kk])
			for j in m:
				ss.append({"r": float(ROWS[kk]), "a": a0 - w * (float(j) + 0.5) / float(m), "c": int(floor(float(most) * (float(j) + 0.5) / float(m)))})
		ss.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
			return int(p["c"]) < int(q["c"]) if int(p["c"]) != int(q["c"]) else float(p["r"]) < float(q["r"]))
		var seats: Array = []
		for s: Dictionary in ss:
			seats.append(Vector2(CX + float(s["r"]) * cos(float(s["a"])), CY - float(s["r"]) * sin(float(s["a"]))))
		out.append({"a0": a0, "a1": a1, "mid": (a0 + a1) * 0.5, "seats": seats})
	return out


## Each seat's kind in a group before the vote, in fill order.
static func kinds_before(c: Dictionary) -> Array:
	var out: Array = []
	var y: int = int(c["yes"])
	var u: int = int(c["und"])
	var no: int = int(c["no"])
	var soft: int = no - int(c["hard"])
	for i in int(c["seats"]):
		if i < y:
			out.append("y")
		elif i < y + u:
			out.append("u")
		elif i < y + u + soft:
			out.append("s")
		elif i < y + u + no:
			out.append("n")
		else:
			out.append("a")
	return out


## The turns of a count `res` (cast_vote's flips, in the order it took them):
## each takes the next undecided seat of its group, to yes or to no.
static func turns_of(comms: Array, res: Dictionary) -> Array:
	var ids: Array = []
	var next: Array = []
	for c: Dictionary in comms:
		ids.append(String(c["id"]))
		next.append(int(c["yes"]))
	var out: Array = []
	for f: Dictionary in res.get("flips", []):
		var gi: int = ids.find(String(f.get("comm", "")))
		if gi < 0:
			continue
		var c: Dictionary = comms[gi]
		var i: int = int(next[gi])
		if i >= int(c["yes"]) + int(c["und"]):
			continue
		next[gi] = i + 1
		out.append({"g": gi, "i": i, "to": "y" if bool(f.get("yes", false)) else "n"})
	return out


## Pick group `gi` (-1: none). Nothing is picked once the vote is cast.
func select(gi: int) -> void:
	sel = gi if result.is_empty() else -1
	_build_labels()
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return plate_at_point(point) >= 0


## The group whose plate (its 44 high hit box) is under `point`, -1 for none;
## none after the vote.
func plate_at_point(point: Vector2) -> int:
	if model.is_empty() or not result.is_empty():
		return -1
	var k: float = UiFonts.K
	for gi in (model.get("comms", []) as Array).size():
		var p: Dictionary = _plate_at(gi)
		var r := Rect2(Vector2(float(p["x"]) - float(p["w"]) * 0.5 - 2.0, float(p["y"]) - 22.0) * k, Vector2(float(p["w"]) + 4.0, 44.0) * k)
		if r.has_point(point):
			return gi
	return -1


func _gui_input(e: InputEvent) -> void:
	var up_click: bool = e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not e.is_pressed()
	var up_touch: bool = e is InputEventScreenTouch and not e.is_pressed()
	if not (up_click or up_touch):
		return
	var gi: int = plate_at_point(e.get("position"))
	if gi >= 0:
		accept_event()
		picked.emit(gi)


func show_model(m: Dictionary) -> void:
	model = m
	result = {}
	_clock = -1.0
	_turns = []
	_turn_from = {}
	set_process(false)
	var comms: Array = m.get("comms", [])
	var counts: Array = []
	for c: Dictionary in comms:
		counts.append(int(c["seats"]))
	places = layout(counts)
	kinds = []
	for c: Dictionary in comms:
		kinds.append(kinds_before(c))
	_yes_shown = int(m.get("got", 0))
	_build_labels()
	queue_redraw()


## Cast: the reveal of count `res` (cast_vote's result) starts.
func play(res: Dictionary) -> void:
	result = res
	sel = -1
	var comms: Array = model.get("comms", [])
	# After the vote every no is the same red.
	for gi in kinds.size():
		for i in (kinds[gi] as Array).size():
			if kinds[gi][i] == "s":
				kinds[gi][i] = "n"
	_turns = turns_of(comms, res)
	for j in _turns.size():
		_turns[j]["at"] = FIRST_S + TURN_S * float(j)
	_clock = 0.0
	_yes_shown = int(model.get("got", 0))
	_build_labels()
	set_process(true)
	queue_redraw()


## The reveal at its end at once (a key pressed while it plays).
func finish_reveal() -> void:
	if _clock < 0.0 or result.is_empty() or not is_processing():
		return
	_clock = _end_s() + 1.0
	_process(0.0)


func revealing() -> bool:
	return _clock >= 0.0 and _clock < _end_s() + 0.4


func _end_s() -> float:
	return FIRST_S + TURN_S * float(_turns.size()) + LINE_AFTER


func _process(delta: float) -> void:
	if _clock < 0.0:
		set_process(false)
		return
	var was: float = _clock
	_clock += delta
	for t: Dictionary in _turns:
		var at: float = float(t["at"])
		if was < at and _clock >= at or (delta == 0.0 and _clock >= at and not t.has("done")):
			if t.has("done"):
				continue
			t["done"] = true
			var key: String = "%d:%d" % [int(t["g"]), int(t["i"])]
			_turn_from[key] = kinds[int(t["g"])][int(t["i"])]
			kinds[int(t["g"])][int(t["i"])] = t["to"]
			if t["to"] == "y":
				_yes_shown += 1
	var stamp_at: float = FIRST_S + TURN_S * float(_turns.size()) + STAMP_AFTER
	var line_at: float = FIRST_S + TURN_S * float(_turns.size()) + LINE_AFTER
	var st: Label = _labels.get("stamp")
	if st:
		var f: float = clampf((_clock - stamp_at) / 0.45, 0.0, 1.0)
		st.visible = f > 0.0
		st.modulate.a = f
		var s: float = lerpf(1.05, 1.0, f)
		st.pivot_offset = st.size * 0.5
		st.scale = Vector2(s, s)
	for key in ["r_yes_w", "r_yes", "r_need", "r_no_w", "r_no"]:
		var l: Label = _labels.get(key)
		if l:
			var f2: float = clampf((_clock - line_at) / 0.4, 0.0, 1.0)
			l.visible = f2 > 0.0
			l.modulate.a = f2
	queue_redraw()
	if _clock > line_at + 0.4 + 0.26:
		set_process(false)
		revealed.emit()


## The words on the board: the plates' names, the legend, the pit's.
func _build_labels() -> void:
	for l in _labels.values():
		if is_instance_valid(l):
			l.queue_free()
	_labels = {}
	var comms: Array = model.get("comms", [])
	# The plates (.hplate): the name 9 in, its number 8 from the right end.
	for gi in comms.size():
		var c: Dictionary = comms[gi]
		var p: Dictionary = _plate_at(gi)
		var ink: Color = PLATE_ON_INK if gi == sel else INK
		var name_l: Label = _label("plate_n%d" % gi, String(c["name"]), UiFonts.WORD, 500, 12.5, ink, 1.0)
		GlassParts.put_on(name_l, (float(p["x"]) - float(p["w"]) * 0.5 + 9.0) * UiFonts.K, (float(p["y"]) + 4.5) * UiFonts.K)
		var num_l: Label = _label("plate_v%d" % gi, str(int(c["seats"])), UiFonts.NUMBER, 500, 15.0, ink)
		GlassParts.put_on(num_l, (float(p["x"]) + float(p["w"]) * 0.5 - 8.0) * UiFonts.K - GlassParts.text_w(num_l), (float(p["y"]) + 5.0) * UiFonts.K)
	# The legend: two columns, 10 apart; a row 16 high, 2 between.
	var words: Array = _key_rows()
	var col_w: float = 0.0
	for i in words.size():
		if i % 2 == 0:
			var l0: Label = _label("key%d" % i, String(words[i][1]), UiFonts.WORD, 400, 12.0, KEY_INK, 0.48)
			col_w = maxf(col_w, 14.0 + GlassParts.text_w(l0) / UiFonts.K)
	for i in words.size():
		var l: Label = _labels.get("key%d" % i)
		if l == null:
			l = _label("key%d" % i, String(words[i][1]), UiFonts.WORD, 400, 12.0, KEY_INK, 0.48)
		var x: float = KEY_AT.x + (0.0 if i % 2 == 0 else col_w + 10.0)
		var y: float = KEY_AT.y + 18.0 * float(i / 2)
		GlassParts.put(l, x + 14.0, y, 16.0)
	if result.is_empty():
		_pit_labels()
	else:
		_result_labels()
	var tk: Label = _label("tick", str(int(model.get("need", 51))), UiFonts.NUMBER, 600, 14.0, AMBER_L)
	GlassParts.put(tk, 0.0, TALLY_Y + 20.0, 14.0)
	tk.position.x = (PIT_X + PIT_W * _share(int(model.get("need", 51)))) * UiFonts.K - GlassParts.text_w(tk) * 0.5


## The legend's rows: [kind, word]; the away only when some are.
func _key_rows() -> Array:
	var rows: Array = [["y", "찬성"], ["u", "미정"], ["s", "설득 가능"], ["n", "꿈쩍 않음"]] if result.is_empty() else [["y", "찬성"], ["n", "반대"]]
	for c: Dictionary in model.get("comms", []):
		if int(c["absent"]) > 0:
			rows.append(["a", "부재"])
			break
	return rows


## The pit before the vote: what is counted (or 「필요 표 확보」 when the yes in
## hand is enough), the three plates' words and numbers.
func _pit_labels() -> void:
	var got: int = int(model.get("got", 0))
	var need: int = int(model.get("need", 51))
	var mid_x: float = PIT_X + PIT_W * 0.5
	if got >= need:
		var sure: Label = _label("sure", "필요 표 확보", UiFonts.WORD, 600, 13.0, SKY, 1.56)
		GlassParts.put(sure, 0.0, PLATES_Y - 5.0 - 22.0, 22.0)
		sure.position.x = mid_x * UiFonts.K - (GlassParts.text_w(sure) - _spacing(600, 1.56)) * 0.5
	else:
		# The yes stone alone heads the plates (결정 417: no 「찬성 표」); its word
		# is left empty so the stone keeps its place, centred.
		var cap: Label = _label("cap", "", UiFonts.WORD, 400, 12.0, INK2, 1.68)
		GlassParts.put(cap, mid_x - 4.5 + 14.0, PLATES_Y - 5.0 - 18.0, 18.0)
	var mean: int = int(model.get("mean", 0))
	var rows: Array = [["확보", got, GOT_INK], ["예상", mean, GOT_INK if mean >= need else SHORT_INK], ["필요", need, INK]]
	for i in 3:
		var x0: float = PIT_X + 17.0 + 55.0 * float(i)
		var l: Label = _label("pl_l%d" % i, String(rows[i][0]), UiFonts.WORD, 400, 12.0, PL_LABEL, 1.68)
		GlassParts.put(l, 0.0, PLATES_Y + 2.5, 14.0)
		l.position.x = (x0 + 25.0) * UiFonts.K - (GlassParts.text_w(l) - _spacing(400, 1.68)) * 0.5
		var v: Label = _label("pl_v%d" % i, str(int(rows[i][1])), UiFonts.NUMBER, 500, 24.0, rows[i][2])
		GlassParts.put(v, 0.0, PLATES_Y + 16.5, 25.0)
		v.position.x = (x0 + 25.0) * UiFonts.K - GlassParts.text_w(v) * 0.5


## The pit after the vote: the stamp (가결 · 부결) and the count under it,
## both kept hidden till their moment in the reveal.
func _result_labels() -> void:
	var yes: int = int(result.get("yes", 0))
	var no: int = int(result.get("no", 0))
	var need: int = int(result.get("need", model.get("need", 51)))
	var passed: bool = bool(result.get("passed", yes >= need))
	var col: Color = SKY if passed else RED
	var mid_x: float = PIT_X + PIT_W * 0.5
	var st: Label = _label("stamp", "가결" if passed else "부결", UiFonts.WORD, 600, 27.0, col, 8.1)
	GlassParts.put(st, 0.0, 158.0, 34.0)
	st.position.x = mid_x * UiFonts.K - (GlassParts.text_w(st) - _spacing(600, 8.1)) * 0.5
	st.visible = false
	var parts: Array = [
		["r_yes_w", "찬성", UiFonts.WORD, 400, 12.0, INK2, 0.72],
		["r_yes", str(yes), UiFonts.NUMBER, 500, 22.0, SKY, 0.22],
		["r_need", "/ %d" % need, UiFonts.NUMBER, 400, 15.0, INK2, 0.0],
		["r_no_w", "반대", UiFonts.WORD, 400, 12.0, INK2, 0.72],
		["r_no", str(no), UiFonts.NUMBER, 500, 17.0, RED, 0.0],
	]
	var widths: Array = []
	var run: float = 0.0
	for i in parts.size():
		var p: Array = parts[i]
		var l: Label = _label(String(p[0]), String(p[1]), int(p[2]), int(p[3]), float(p[4]), p[5], float(p[6]))
		l.visible = false
		widths.append(GlassParts.text_w(l))
		run += GlassParts.text_w(l)
	# 4 between the parts, 10 more before 「반대」 (.pit__r small margin-left).
	run += 4.0 * UiFonts.K * 4.0 + 10.0 * UiFonts.K
	var x: float = mid_x * UiFonts.K - run * 0.5
	var base: float = (198.0 + 20.0) * UiFonts.K
	for i in parts.size():
		if i == 3:
			x += 10.0 * UiFonts.K
		GlassParts.put_on(_labels[String(parts[i][0])], x, base)
		x += float(widths[i]) + 4.0 * UiFonts.K


func _label(key: String, text: String, kind: int, weight: int, css_px: float, color: Color, spacing: float = 0.0) -> Label:
	var l := UiFonts.label(text, kind, weight, css_px, color, spacing)
	l.name = key.capitalize().replace(" ", "")
	add_child(l)
	_labels[key] = l
	return l


static func _spacing(weight: int, spacing: float) -> float:
	return float(UiFonts.face(UiFonts.WORD, weight, spacing).get_spacing(TextServer.SPACING_GLYPH))


## Where a group's plate stands (hemiSVG): beyond the rim at its wedge's middle,
## kept inside the block; the two end wedges' plates level with the board's foot.
func _plate_at(gi: int) -> Dictionary:
	var c: Dictionary = model["comms"][gi]
	var mid: float = float(places[gi]["mid"])
	var w: float = float(String(c["name"]).length()) * 12.5 + 32.0
	var edge: bool = mid < 0.38 or mid > PI - 0.38
	var x: float
	var y: float
	if edge:
		x = CX + signf(cos(mid)) * 152.0
		y = CY + 19.0
	else:
		x = clampf(CX + 222.0 * cos(mid), w * 0.5 + 2.0, 398.0 - w * 0.5)
		y = maxf(12.0, CY - 222.0 * sin(mid))
	return {"x": x, "y": y, "w": w}


## A count's share of the seats (the bar is all of them).
func _share(n: int) -> float:
	var total: int = int(model.get("total", 100))
	return clampf(float(n) / float(maxi(1, total)), 0.0, 1.0)


func _draw() -> void:
	if model.is_empty():
		return
	var k: float = UiFonts.K
	if not result.is_empty():
		_draw_warmth()
	draw_texture_rect(BOARD, Rect2(BOARD_AT * k, BOARD_CSS * k), false)
	var center := Vector2(CX, CY) * k
	var comms: Array = model.get("comms", [])
	if sel >= 0 and sel < places.size():
		draw_colored_polygon(_wedge(sel, RI + 2.5, RO - 2.5), SEL_FILL)
	for gi in places.size():
		var p: Dictionary = places[gi]
		# The line between two wedges (.hsep), its ends round.
		if gi > 0:
			var a: float = float(p["a0"]) + GAP * 0.5
			var d := Vector2(cos(a), -sin(a))
			var p0: Vector2 = center + d * (RI + 3.0) * k
			var p1: Vector2 = center + d * (RO - 3.0) * k
			draw_line(p0, p1, SEP, 2.0 * k, true)
			draw_circle(p0, 1.0 * k, SEP, true, -1.0, true)
			draw_circle(p1, 1.0 * k, SEP, true, -1.0, true)
		var seats: Array = p["seats"]
		for i in seats.size():
			_draw_seat(gi, i, seats[i])
		# The band round the wedge's rim (.hband); the picked one's lamp amber,
		# 4 wide, its glow round it (drop-shadow 0 0 4px rgba(242,166,60,.75)).
		if gi == sel:
			for j in 3:
				draw_arc(center, BAND_R * k, -float(p["a0"]), -float(p["a1"]), 48, Color(AMBER, 0.11 + 0.08 * j), (11.0 - 2.5 * j) * k, true)
			draw_arc(center, BAND_R * k, -float(p["a0"]), -float(p["a1"]), 48, AMBER, 4.0 * k, true)
		else:
			draw_arc(center, BAND_R * k, -float(p["a0"]), -float(p["a1"]), 48, BAND, 3.0 * k, true)
	if sel >= 0 and sel < comms.size():
		_draw_link(sel)
	for gi in comms.size():
		_draw_plate(gi)
	_draw_key()
	if result.is_empty():
		_draw_pit_plates()
	else:
		_draw_stamp_ring()
	_draw_tally()


## One seat: an empty socket for the away; else the stone, turning while it turns.
func _draw_seat(gi: int, i: int, at_css: Vector2) -> void:
	var k: float = UiFonts.K
	var kind: String = kinds[gi][i]
	var rect := Rect2((at_css - Vector2(STONE_BOX, STONE_BOX) * 0.5) * k, Vector2(STONE_BOX, STONE_BOX) * k)
	if kind == "a":
		draw_texture_rect(SOCKET, rect, false, Color(1, 1, 1, 0.9))
		return
	var key: String = "%d:%d" % [gi, i]
	var at: float = -1.0
	if _turn_from.has(key):
		for t: Dictionary in _turns:
			if int(t["g"]) == gi and int(t["i"]) == i:
				at = float(t["at"])
				break
	var since: float = _clock - at if at >= 0.0 else 99.0
	if since < 0.26:
		# The old stone fades in .18 s; the new one springs from .3 to full in .26 s.
		var out_a: float = clampf(1.0 - since / 0.18, 0.0, 1.0)
		if out_a > 0.0:
			draw_texture_rect(SOCKET, rect, false, Color(1, 1, 1, out_a))
			draw_texture_rect(STONES[_turn_from[key]], rect, false, Color(1, 1, 1, out_a))
		var f: float = LeverKeyMath.bezier(since / 0.26, 0.3, 1.6, 0.5, 1.0)
		var s: float = lerpf(0.3, 1.0, f)
		var r2 := Rect2(rect.get_center() - rect.size * s * 0.5, rect.size * s)
		var a: float = clampf(f, 0.0, 1.0)
		draw_texture_rect(SOCKET, r2, false, Color(1, 1, 1, a))
		draw_texture_rect(STONES[kind], r2, false, Color(1, 1, 1, a))
		return
	draw_texture_rect(SOCKET, rect, false)
	draw_texture_rect(STONES[kind], rect, false)


## A group's plate (.hplate): dark enamel 22 high, radius 2, a lip of light along
## its top, a drop shadow (0 2px 2px rgba(0,0,0,.7)).
func _draw_plate(gi: int) -> void:
	var k: float = UiFonts.K
	var p: Dictionary = _plate_at(gi)
	var r := Rect2((Vector2(float(p["x"]) - float(p["w"]) * 0.5, float(p["y"]) - 11.0)) * k, Vector2(float(p["w"]), 22.0) * k)
	GlassParts.shadow(self, r, 2.0 * k, 2.0 * k, 2.0 * k, Color(0, 0, 0, 0.7))
	GlassParts.round_rect(self, r, 2.0 * k, AMBER if gi == sel else PLATE)
	GlassParts.round_rect(self, Rect2(r.position, Vector2(r.size.x, 2.0 * k)), 1.0 * k, PLATE_ON_LIP if gi == sel else PLATE_LIP)


## The picked wedge's light (.hsel): its ring from `r0` to `r1`, half a gap past
## each of its ends.
func _wedge(gi: int, r0: float, r1: float) -> PackedVector2Array:
	var k: float = UiFonts.K
	var a0: float = float(places[gi]["a0"]) + GAP * 0.5
	var a1: float = float(places[gi]["a1"]) - GAP * 0.5
	var pts := PackedVector2Array()
	var n: int = 40
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(Vector2(CX + r1 * cos(a), CY - r1 * sin(a)) * k)
	for i in n + 1:
		var a: float = lerpf(a1, a0, float(i) / float(n))
		pts.append(Vector2(CX + r0 * cos(a), CY - r0 * sin(a)) * k)
	return pts


## The line from the picked group to the pane (.hlink, 2 wide, round ends): from
## an end plate straight across; else round the rim from its wedge's middle to
## .26 rad, then across; a dot 3.5 round where it meets the pane.
func _draw_link(gi: int) -> void:
	var k: float = UiFonts.K
	var p: Dictionary = _plate_at(gi)
	var mid: float = float(places[gi]["mid"])
	var end_y: float
	if mid < 0.38 or mid > PI - 0.38:
		end_y = float(p["y"])
		draw_line(Vector2(float(p["x"]) + float(p["w"]) * 0.5, end_y) * k, Vector2(LINK_X, end_y) * k, AMBER, 2.0 * k, true)
	else:
		end_y = CY - LINK_R * sin(LINK_A)
		draw_arc(Vector2(CX, CY) * k, LINK_R * k, -mid, -LINK_A, 64, AMBER, 2.0 * k, true)
		draw_line(Vector2(CX + LINK_R * cos(LINK_A), end_y) * k, Vector2(LINK_X, end_y) * k, AMBER, 2.0 * k, true)
	draw_circle(Vector2(LINK_X, end_y) * k, 3.5 * k, AMBER, true, -1.0, true)


## The legend's stones, 10 across, 4 before their words.
func _draw_key() -> void:
	var k: float = UiFonts.K
	var rows: Array = _key_rows()
	for i in rows.size():
		var l: Label = _labels.get("key%d" % i)
		if l == null:
			continue
		var y: float = KEY_AT.y + 18.0 * float(i / 2) + 8.0
		var x: float = l.position.x / k - 14.0 + 5.0
		var sr := Rect2((Vector2(x, y) - Vector2(5, 5)) * k, Vector2(10, 10) * k)
		# The stone sprites hold a 12.8 stone in 16: drawn so the stone is 10.
		var big := sr.grow(sr.size.x * (STONE_BOX / 12.8 - 1.0) * 0.5)
		if rows[i][0] == "a":
			# An empty seat off the wood: its hollow and a faint rim, so it shows on the glass.
			draw_circle(sr.get_center(), 5.0 * k, Color(0, 0, 0, 0.55), true, -1.0, true)
			draw_circle(sr.get_center(), 4.5 * k, Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.38), false, 1.0 * k, true)
		else:
			draw_texture_rect(STONES[rows[i][0]], big, false)


## The pit's three plates (.pl 50 × 44, 5 apart): dark, radius 3, a lip of
## light inside the top, a drop shadow; the need's a lamp line inside its foot.
func _draw_pit_plates() -> void:
	var k: float = UiFonts.K
	var got: int = int(model.get("got", 0))
	var need: int = int(model.get("need", 51))
	if got < need:
		# The caption's stone, 9 across, 5 before its word.
		var cap: Label = _labels.get("cap")
		if cap:
			var x: float = cap.position.x / k - 14.0
			var sr := Rect2(Vector2(x, PLATES_Y - 5.0 - 18.0 + 4.5) * k, Vector2(9, 9) * k)
			draw_texture_rect(STONES["y"], sr.grow(sr.size.x * (STONE_BOX / 12.8 - 1.0) * 0.5), false)
	else:
		var sure: Label = _labels.get("sure")
		if sure:
			var w: float = GlassParts.text_w(sure) - _spacing(600, 1.56) + 2.0 * (9.0 + 1.56) * k
			var r := Rect2(Vector2((PIT_X + PIT_W * 0.5) * k - w * 0.5, (PLATES_Y - 5.0 - 22.0) * k), Vector2(w, 22.0 * k))
			_ring(r, 2.0 * k, SKY, 2.0 * k)
	for i in 3:
		var r := Rect2(Vector2(PIT_X + 17.0 + 55.0 * float(i), PLATES_Y) * k, Vector2(50, 44) * k)
		GlassParts.shadow(self, r, 3.0 * k, 2.0 * k, 3.0 * k, Color(0, 0, 0, 0.55))
		GlassParts.round_rect(self, r, 3.0 * k, PLATE)
		GlassParts.round_rect(self, Rect2(r.position + Vector2(1.0, 0.0) * k, Vector2(r.size.x - 2.0 * k, 2.0 * k)), 1.0 * k, PL_LIP)
		if i == 2:
			GlassParts.round_rect(self, Rect2(Vector2(r.position.x + 1.0 * k, r.end.y - 2.0 * k), Vector2(r.size.x - 2.0 * k, 2.0 * k)), 1.0 * k, AMBER_L)


## The stamp's ring (.pit__st: inset 0 0 0 2px currentColor, radius 3).
func _draw_stamp_ring() -> void:
	var st: Label = _labels.get("stamp")
	if st == null or not st.visible:
		return
	var k: float = UiFonts.K
	var w: float = GlassParts.text_w(st) - _spacing(600, 8.1) + 2.0 * (6.0 + 8.1) * k
	var s: float = st.scale.x
	var c := Vector2((PIT_X + PIT_W * 0.5) * k, (158.0 + 17.0) * k)
	var r := Rect2(c - Vector2(w, 34.0 * k) * s * 0.5, Vector2(w, 34.0 * k) * s)
	_ring(r, 3.0 * k, Color(st.get_theme_color("font_color"), st.modulate.a), 2.0 * k)


## The bar under the pit (.tally): the yes in hand full blue, the range to
## every undecided coming a pale blue, the expected a white dot, the need a
## lamp tick with its number under it. After the vote the blue fills a yes at
## a time to the count's yes.
func _draw_tally() -> void:
	var k: float = UiFonts.K
	var bar := Rect2(Vector2(PIT_X, TALLY_Y) * k, Vector2(PIT_W, 8.0) * k)
	GlassParts.round_rect(self, bar.grow(2.0 * k), 6.0 * k, Color(202 / 255.0, 164 / 255.0, 92 / 255.0, 0.45))
	GlassParts.round_rect(self, bar, 4.0 * k, Color(6 / 255.0, 8 / 255.0, 10 / 255.0, 0.72))
	var got: int = int(model.get("got", 0))
	if result.is_empty():
		var mx: int = int(model.get("max", got))
		if mx > got:
			draw_rect(Rect2(bar.position + Vector2(bar.size.x * _share(got), 0.0), Vector2(bar.size.x * (_share(mx) - _share(got)), bar.size.y)), Color(110 / 255.0, 170 / 255.0, 235 / 255.0, 0.32))
		_got_fill(bar, _share(got))
	else:
		_got_fill(bar, _share(_yes_shown))
	# inset 0 1px 2px rgba(0,0,0,.7) along the bed's top.
	draw_rect(Rect2(bar.position + Vector2(3.0 * k, 0.0), Vector2(bar.size.x - 6.0 * k, 1.0 * k)), Color(0, 0, 0, 0.35))
	if result.is_empty():
		var dot := Vector2(bar.position.x + bar.size.x * _share(int(model.get("mean", got))), bar.position.y + 4.0 * k)
		draw_circle(dot, 6.0 * k, PLATE, true, -1.0, true)
		draw_circle(dot, 4.0 * k, Color("f3efe6"), true, -1.0, true)
	var tx: float = bar.position.x + bar.size.x * _share(int(model.get("need", 51)))
	var tick := Rect2(Vector2(tx - 1.0 * k, bar.position.y - 5.0 * k), Vector2(2.0, 18.0) * k)
	for i in 3:
		GlassParts.round_rect(self, tick.grow(float(3 - i) * 1.2 * k), 1.0 * k + float(3 - i) * 1.2 * k, Color(242 / 255.0, 166 / 255.0, 60 / 255.0, 0.12))
	GlassParts.round_rect(self, tick.grow(1.0 * k), 2.0 * k, Color(16 / 255.0, 10 / 255.0, 2 / 255.0, 0.7))
	GlassParts.round_rect(self, tick, 1.0 * k, AMBER_L)


## The yes's blue in the bar, its light from the top (linear-gradient(#bfe0fb, #5a9fe6 55%, #2f6db5)).
func _got_fill(bar: Rect2, share: float) -> void:
	var w: float = bar.size.x * share
	if w <= 0.5:
		return
	var n: int = 8
	for i in n:
		var f0: float = float(i) / float(n)
		var f1: float = float(i + 1) / float(n)
		var c0: Color = GlassParts.grad_at(GOT_BAR, f0)
		var c1: Color = GlassParts.grad_at(GOT_BAR, f1)
		var y0: float = bar.position.y + bar.size.y * f0
		var y1: float = bar.position.y + bar.size.y * f1
		draw_polygon(PackedVector2Array([Vector2(bar.position.x, y0), Vector2(bar.position.x + w, y0), Vector2(bar.position.x + w, y1), Vector2(bar.position.x, y1)]), PackedColorArray([c0, c0, c1, c1]))


## The warm light the lamp throws on the board once the vote is cast
## (#stage[data-res] .cn::before: radial-gradient(50% 60% at 50% 78%,
## rgba(255,190,110,.2), transparent) in 404 × 250 at 10, 0).
func _draw_warmth() -> void:
	var k: float = UiFonts.K
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(1.0, 190 / 255.0, 110 / 255.0, 0.2), Color(1.0, 190 / 255.0, 110 / 255.0, 0.0)])
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 256
		_glow.height = 256
	# The ellipse is 202 × 150 round (10 + 202, 195); the box stops at 250.
	var full := Rect2(Vector2(10.0, 195.0 - 150.0) * k, Vector2(404.0, 300.0) * k)
	var keep: float = (250.0 - 45.0) / 300.0
	draw_texture_rect_region(_glow, Rect2(full.position, Vector2(full.size.x, full.size.y * keep)), Rect2(0, 0, 256, 256.0 * keep))


## A ring of `width` inside rect `r` with corners of `radius`.
func _ring(r: Rect2, radius: float, col: Color, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.0)
	sb.border_color = col
	sb.set_border_width_all(int(round(width)))
	sb.set_corner_radius_all(int(round(radius)))
	sb.corner_detail = 8
	sb.anti_aliasing_size = 0.7
	draw_style_box(sb, r)


## The spring of a turning stone (cubic-bezier(.3, 1.6, .5, 1)).
class LeverKeyMath:
	static func bezier(f: float, x1: float, y1: float, x2: float, y2: float) -> float:
		f = clampf(f, 0.0, 1.0)
		var u: float = f
		for i in 8:
			var x: float = 3.0 * (1.0 - u) * (1.0 - u) * u * x1 + 3.0 * (1.0 - u) * u * u * x2 + u * u * u
			var dx: float = 3.0 * (1.0 - u) * (1.0 - u) * x1 + 6.0 * (1.0 - u) * u * (x2 - x1) + 3.0 * u * u * (1.0 - x2)
			if absf(dx) < 1e-5:
				break
			u = clampf(u - (x - f) / dx, 0.0, 1.0)
		return 3.0 * (1.0 - u) * (1.0 - u) * u * y1 + 3.0 * (1.0 - u) * u * u * y2 + u * u * u
