extends Control
## The second station (밤 계획 2026-10-18 PR 3): what the train came to between
## the first stop and this one, on the stop's own sheet (UI 3단계 시안 2차, B1;
## the paper of 03 「정차」 and of the return receipt), the special session's bill
## laid beside it as the session's slip (05 「의회」 .bill) with what the session
## decided stamped on it. On the sheet: the kick (the stretch, what the paper
## is), the station in pen, the port's line for the arrival, three columns
## (사람 · 물자 · 온기: a word, the number now and how far it moved), the port's
## lines for the symbol and the promise, and the main key at the foot.
##
## Its words are the politics port's arrival summary (field_arrival.gd
## arrival_summary); its numbers are the same record and snapshot the summary
## reads, whole as the gauges above show them (int(round)), and how far one
## moved is between those whole numbers, so the three agree with each other and
## with the band. Who did not come back is a count, never names (결정 183). It
## sets nothing. The summary's lines are a big result's (결정 266), kept as the
## port writes them.

signal went_on

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const Paper = preload("res://game/ui/paper_parts.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const TypeLine = preload("res://game/ui/type_line.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const ReceiptSheet = preload("res://game/ui/receipt_sheet.gd")
const FieldArrival = preload("res://game/politics/field_arrival.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const SHEET_SHADER := preload("res://game/ui/paper_sheet.gdshader")
const PAPER_TEX := preload("res://game/ui/tex/paper.png")

## Where the mockup lays the sheet (the stop card's place) and the slip beside
## it, clear of the sheet's torn edge.
const SHEET_AT := Vector2(-10, 50)
const SLIP_AT := Vector2(452, 66)
## The three columns' widths and the room between them: 366 of the writing's 386.
const COL_W: Array = [150.0, 120.0, 96.0]
const COL_GAP: float = 10.0
## A wrapped line's next lines stand this far apart (its first is a row's 22).
const WRAP_LINE: float = 18.0
## The stock in the summary's order and words.
const STOCKS: Array = [["coal", "석탄"], ["food", "식량"], ["med", "의약품"], ["lux", "사치품"]]
const DEAD_WORD := "돌아오지 못한 사람"
const SAME := "그대로"
## The slip's rows drawn as a mark for their word.
const ROW_MARKS: Dictionary = {"신임": "trust", "긴장": "tension"}
const MINUS := "−"
## The slip (c3.css .bill): 180 wide, written 16 to 168 across, leaning; its
## drop-shadow(4px 6px 10px rgba(0,0,0,.62)).
const SLIP_W: float = 180.0
const SLIP_X0: float = 16.0
const SLIP_X1: float = 168.0
const SLIP_TILT: float = 0.8
## The bill's title in the hand at 27, smaller on one line, then on two, then
## three (council_card.gd TITLE_FITS): [size, most lines].
const TITLE_FITS: Array = [[27, 1], [25, 1], [23, 1], [21, 1], [23, 2], [21, 2], [19, 2], [17, 2], [17, 3]]
const STAMP_TILT_DEG: float = -8.0
const SLIP_RULE := Color(42 / 255.0, 32 / 255.0, 24 / 255.0, 0.16)

## The second station's state (the port's, at the stop) and its tables.
var g: Dictionary = {}
var t: Dictionary = {}
## The main key's word (the next step's).
var go_word: String = ""
var sheet: Control
var body: VBoxContainer
var slip: Control
var go_key: Button


## A number as the band shows it: whole, its minus a minus sign.
static func whole(v: Variant) -> String:
	var n: int = int(round(float(v)))
	return (MINUS + str(-n)) if n < 0 else str(n)


## How far a number moved between two whole numbers: 「+1」, 「−2」, or 「그대로」.
static func moved(before: Variant, after: Variant) -> String:
	var d: int = int(round(float(after))) - int(round(float(before)))
	if d == 0:
		return SAME
	return ("+" + str(d)) if d > 0 else (MINUS + str(-d))


## What the sheet and the slip say for the second station's state (tests read
## this; the sheet draws it); empty when the state has no first return in it.
static func model(g0: Dictionary, t0: Dictionary) -> Dictionary:
	if g0.is_empty() or t0.is_empty():
		return {}
	var sections: Variant = FieldArrival.arrival_summary(g0, t0)
	if not sections is Array:
		return {}
	var by: Dictionary = {}
	for s: Dictionary in sections:
		by[String(s["k"])] = s
	var fr: Dictionary = g0["fieldReturns"]
	var record: Dictionary = fr["records"][0]
	var before: Dictionary = record["before"]
	var now: Dictionary = FieldReturn.snapshot(g0, t0)
	var names: Dictionary = t0.get("COMM_NAME", {})
	# The same rows the summary writes, in its order (field_arrival.gd).
	var people: Array = []
	var dead: int = (record.get("dead", []) as Array).size()
	if dead > 0:
		people.append([DEAD_WORD, str(dead), ""])
	for c: String in t0["COMMS"]:
		if float(now["pop"][c]) != float(before["pop"][c]):
			people.append([String(names.get(c, c)), whole(now["pop"][c]) + "명", moved(before["pop"][c], now["pop"][c])])
	if float(now["injured"]) != float(before["injured"]):
		people.append(["다친 사람", whole(now["injured"]), moved(before["injured"], now["injured"])])
	if people.is_empty():
		people.append([String((by["people"]["lines"] as Array)[0]), "", ""])
	var stock: Array = []
	for pair: Array in STOCKS:
		stock.append([String(pair[1]), whole(now[pair[0]]), moved(before[pair[0]], now[pair[0]])])
	var warm: Array = []
	for c: String in t0["COMMS"]:
		if float(now["warm"][c]) != float(before["warm"][c]):
			warm.append([String(names.get(c, c)), whole(now["warm"][c]), moved(before["warm"][c], now["warm"][c])])
	if warm.is_empty():
		warm.append([String((by["warm"]["lines"] as Array)[0]), "", ""])
	var seen: Array = []
	for k: String in ["symbol", "promise"]:
		for line in by[k]["lines"]:
			seen.append([k, UiFonts.josa(String(line))])
	return {
		"seg": int(g0["seg"]),
		"title": String(by["arrive"]["title"]),
		"arrive": UiFonts.josa(String((by["arrive"]["lines"] as Array)[0])),
		"columns": [["사람", people], ["물자", stock], ["온기", warm]],
		"seen": seen,
		"council": council_of(fr.get("special"), t0, by["council"]["lines"]),
	}


## The slip: the session's stretch, the bill it decided and how, the votes,
## and how trust, tension and each group's relation moved over it. When no
## session sat, the summary's own line instead.
static func council_of(special: Variant, t0: Dictionary, lines: Array) -> Dictionary:
	if not special is Dictionary or special.get("status") != "opened":
		return {"open": false, "line": UiFonts.josa(String(lines[0])) if not lines.is_empty() else ""}
	var s: Dictionary = special
	var out := {"open": true, "seg": int(s.get("seg", 0)), "title": UiFonts.josa(String(s.get("picked", ""))), "stamp": "", "votes": [], "rows": []}
	if s.get("result") is Dictionary:
		var r: Dictionary = s["result"]
		out["stamp"] = "가결" if bool(r["passed"]) else "부결"
		out["votes"] = [["찬성", int(r["yes"])], ["반대", int(r["no"])], ["필요", int(r["need"])]]
	if s.get("before") is Dictionary and s.get("after") is Dictionary:
		var b: Dictionary = s["before"]
		var a: Dictionary = s["after"]
		var names: Dictionary = t0.get("COMM_NAME", {})
		out["rows"].append(change_row("신임", b["trust"], a["trust"]))
		out["rows"].append(change_row("긴장", b["tension"], a["tension"]))
		for c: String in t0["COMMS"]:
			if float(a["rel"][c]) != float(b["rel"][c]):
				out["rows"].append(change_row("%s 관계" % String(names.get(c, c)), b["rel"][c], a["rel"][c]))
	return out


## [word, before, after] as whole numbers; before "" when it did not move.
static func change_row(word: String, before: Variant, after: Variant) -> Array:
	if whole(before) == whole(after):
		return [word, "", whole(after)]
	return [word, whole(before), whole(after)]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper = PaperSheet.new()
	paper.name = "Sheet"
	paper.position = SHEET_AT * UiFonts.K
	sheet = paper
	add_child(paper)
	body = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.inner.add_child(body)
	var m: Dictionary = model(g, t)
	if m.is_empty():
		body.add_child(Paper.ink("도착 기록 없음", UiFonts.HAND, 400, 31.0))
	else:
		_head(m)
		var arrive = _runs(String(m["arrive"]), 18.0)
		arrive.name = "Arrive"
		body.add_child(arrive)
		body.add_child(_rule())
		_columns(m["columns"])
		body.add_child(_rule())
		_seen(m["seen"])
	var room := Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(room)
	_keys()
	if not m.is_empty():
		_build_slip(m["council"])


## The head, as the stop card's: the station in pen on a line of 28 in 26.
func _head(m: Dictionary) -> void:
	# The station in pen heads the sheet; no 「N 구간 정차 · 도착」 kick over it
	# (결정 417): the route line under the sheet says the stretch.
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(head)
	# Room over the pen's tall letters where the kick line was (half its 24),
	# so the name stays on the paper.
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, UiFonts.px(12.0))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(top)
	var title = TypeLine.new(28.0, 26.0)
	title.name = "Title"
	head.add_child(title)
	var place := Paper.ink(String(m["title"]), UiFonts.HAND, 400, 31.0)
	place.name = "Place"
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(place)


## A rule across the sheet in faint ink (2 px) in a row of 6.
func _rule() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, UiFonts.px(6.0))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(0, (c.size.y - UiFonts.px(2.0)) * 0.5, c.size.x, UiFonts.px(2.0)), Paper.LINE))
	return c


## The three columns side by side, each its title in side ink over its rows.
func _columns(columns: Array) -> void:
	var cols := HBoxContainer.new()
	cols.name = "Columns"
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_theme_constant_override("separation", int(round(UiFonts.px(COL_GAP))))
	body.add_child(cols)
	for i in columns.size():
		var column: Array = columns[i]
		# A column's width in whole game px: a container rounds what it lays out.
		var w: float = floorf(UiFonts.px(float(COL_W[i])))
		var c := VBoxContainer.new()
		c.name = "Col_" + String(column[0])
		c.add_theme_constant_override("separation", 0)
		c.custom_minimum_size = Vector2(w, 0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cols.add_child(c)
		var head = TypeLine.new(0.0, 18.0)
		head.add_child(Paper.ink(String(column[0]), UiFonts.WORD, 400, 12.0, Paper.INK2, 1.44))
		c.add_child(head)
		for row: Array in column[1]:
			c.add_child(_cell(row, w))


## One row: 「석탄 96 −2」 — the word, the number now in the number face, how far
## it moved in side ink — on a line of 21; a line with no number (the summary's
## own 「그대로다」) in side ink, wrapping as the mockup wraps.
func _cell(row: Array, w: float) -> Control:
	if String(row[1]) == "":
		var l := Paper.ink(UiFonts.keep_all(String(row[0])), UiFonts.WORD, 400, 12.0, Paper.INK2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w, 0)
		return l
	var line = TypeLine.new(0.0, 21.0)
	line.add_child(Paper.ink(String(row[0]) + " ", UiFonts.WORD, 500, 14.0, Paper.INK))
	for r: Array in ReceiptSheet.num_runs(String(row[1])):
		if bool(r[1]):
			line.add_child(Paper.ink(String(r[0]), UiFonts.NUMBER, 500, 17.0, Paper.INK, 0.17))
		else:
			line.add_child(Paper.ink(String(r[0]), UiFonts.WORD, 500, 14.0, Paper.INK))
	var d: String = String(row[2])
	if d == SAME:
		line.add_child(Paper.ink(" " + SAME, UiFonts.WORD, 400, 12.0, Paper.INK2))
	elif d != "":
		line.add_child(Paper.ink(" " + d, UiFonts.NUMBER, 400, 14.0, Paper.INK2, 0.21))
	return line


## What came of the symbol and the promise (.promline, 22 each, a long one
## wrapping), each with the stop card's mark for it.
func _seen(seen: Array) -> void:
	var box := VBoxContainer.new()
	box.name = "Seen"
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(box)
	var room: float = UiFonts.px(PaperSheet.SIZE.x - PaperSheet.INSET_L - PaperSheet.INSET_R - 16.0 - 6.0)
	for item: Array in seen:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(round(UiFonts.px(6.0))))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The mark in the first line's box of 22.
		var at := CenterContainer.new()
		at.custom_minimum_size = Vector2(UiFonts.px(16.0), UiFonts.px(22.0))
		at.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		at.mouse_filter = Control.MOUSE_FILTER_IGNORE
		at.add_child(Paper.mark("promise" if String(item[0]) == "promise" else "inv", 16.0))
		row.add_child(at)
		row.add_child(_para(String(item[1]), floorf(room)))
		box.add_child(row)


## A line in side ink with its numbers in the number face, wrapping between
## words in `w` game px: its first line centred in a row of 22, the next lines
## WRAP_LINE apart.
func _para(text: String, w: float) -> Control:
	var r := RichTextLabel.new()
	r.name = "Line"
	r.bbcode_enabled = false
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(w, 0)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var word: Font = UiFonts.face(UiFonts.WORD, 400)
	var num: Font = UiFonts.face(UiFonts.NUMBER, 400, 0.21)
	var ws: int = UiFonts.size(12.0)
	var ns: int = UiFonts.size(14.0)
	r.add_theme_font_override("normal_font", word)
	r.add_theme_font_size_override("normal_font_size", ws)
	r.add_theme_color_override("default_color", Paper.INK2)
	var line_h: float = maxf(word.get_height(ws), num.get_height(ns))
	r.add_theme_constant_override("line_separation", int(round(UiFonts.px(WRAP_LINE) - line_h)))
	var runs: Array = ReceiptSheet.num_runs(text)
	for i in runs.size():
		var run: Array = runs[i]
		var s: String = UiFonts.keep_all(String(run[0]))
		# A number keeps to the word it counts (「2명」), as the letters of a word do.
		if i > 0 and not s.begins_with(" ") and not String(runs[i - 1][0]).ends_with(" "):
			s = UiFonts.WORD_JOINER + s
		if bool(run[1]):
			r.push_font(num, ns)
			r.push_color(Paper.INK)
			r.add_text(s)
			r.pop()
			r.pop()
		else:
			r.add_text(s)
	var pad: float = maxf(0.0, (UiFonts.px(22.0) - line_h) * 0.5)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_top", int(round(pad)))
	m.add_theme_constant_override("margin_bottom", int(round(pad)))
	m.add_child(r)
	return m


## The keys at the foot (.sh__act, 48): the main key at the right.
func _keys() -> void:
	var foot := Paper.line_box(48.0)
	body.add_child(foot)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(fill)
	go_key = LampKey.new(go_word)
	go_key.name = "Go"
	go_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_key.pressed.connect(func() -> void: went_on.emit())
	foot.add_child(go_key)


# ── the session's slip ────────────────────────────────────────────────────

## A loose slip as the session card's bill is (council_card.gd _build_bill):
## the kick, the bill in the hand, the seal of what the vote came to, the
## votes, a rule and the moves, each on the dotted line under it.
func _build_slip(c: Dictionary) -> void:
	var k: float = UiFonts.K
	slip = Control.new()
	slip.name = "Slip"
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slip.position = SLIP_AT * k
	add_child(slip)
	var parts := Control.new()
	parts.name = "Parts"
	parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var y: float = 7.0
	if bool(c["open"]):
		# The slip's name, as the closed slip's (no stretch number: 결정 417).
		var kick := _slip_ink("특별 회기", UiFonts.WORD, 400, 12.0, Paper.INK2, 1.2)
		kick.name = "SlipKick"
		parts.add_child(kick)
		GlassParts.put(kick, SLIP_X0, y, 17.0)
		y += 17.0 + 4.0
		y = _slip_title(parts, String(c["title"]), y)
		if String(c["stamp"]) != "":
			var st: Control = _stamp(String(c["stamp"]))
			parts.add_child(st)
			st.position = Vector2(SLIP_X1 * k - st.custom_minimum_size.x, (y - 4.0) * k - st.custom_minimum_size.y * 0.5)
		if not (c["votes"] as Array).is_empty():
			y = _slip_votes(parts, c["votes"], y + 4.0)
		_slip_rule(parts, y + 6.0, false)
		y += 6.0 + 2.0 + 2.0
		for row: Array in c["rows"]:
			y = _slip_row(parts, row, y)
	else:
		var head := _slip_ink("특별 회기", UiFonts.WORD, 400, 12.0, Paper.INK2, 1.2)
		head.name = "SlipKick"
		parts.add_child(head)
		GlassParts.put(head, SLIP_X0, y, 17.0)
		y += 17.0 + 6.0
		var line := _slip_ink(UiFonts.keep_all(String(c["line"])), UiFonts.WORD, 400, 12.5, Paper.INK2)
		line.name = "SlipLine"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var w: float = (SLIP_X1 - SLIP_X0) * k
		line.custom_minimum_size = Vector2(w, 0.0)
		line.size = Vector2(w, 0.0)
		line.position = Vector2(SLIP_X0, y) * k
		parts.add_child(line)
		y += WRAP_LINE * float(_lines_of(line, w)) + 2.0
	var h: float = y + 8.0
	var size_px := Vector2(SLIP_W, h) * k
	slip.size = size_px
	slip.pivot_offset = size_px * 0.5
	slip.rotation = deg_to_rad(SLIP_TILT)
	var sigma: float = 5.0 * k
	var reach: float = sigma * 3.0
	var sh := ColorRect.new()
	sh.name = "Shadow"
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.material = _slip_material(size_px, true, reach, sigma)
	sh.position = Vector2(4.0, 6.0) * k - Vector2(reach, reach)
	sh.size = size_px + Vector2(reach, reach) * 2.0
	slip.add_child(sh)
	var paper := ColorRect.new()
	paper.name = "Paper"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.material = _slip_material(size_px, false, 0.0, 0.0)
	paper.size = size_px
	slip.add_child(paper)
	parts.size = size_px
	slip.add_child(parts)


## The paper's shader as a loose slip: no side bands, no fold, no torn edge.
func _slip_material(sheet_px: Vector2, is_shadow: bool, reach: float, sigma: float) -> ShaderMaterial:
	var k: float = UiFonts.K
	var mat := ShaderMaterial.new()
	mat.shader = SHEET_SHADER
	mat.set_shader_parameter("paper_tex", PAPER_TEX)
	mat.set_shader_parameter("sheet_size", sheet_px)
	mat.set_shader_parameter("tile", 240.0 * k)
	mat.set_shader_parameter("cut", 0.0)
	mat.set_shader_parameter("tear", Vector2(1.0, 240.0 * k))
	mat.set_shader_parameter("paper", Vector4(Paper.PAPER.r, Paper.PAPER.g, Paper.PAPER.b, 1.0))
	mat.set_shader_parameter("bands", false)
	mat.set_shader_parameter("fold", false)
	mat.set_shader_parameter("shadow", is_shadow)
	mat.set_shader_parameter("reach", reach)
	mat.set_shader_parameter("sigma", sigma)
	mat.set_shader_parameter("shadow_alpha", 0.62)
	return mat


## The bill in the hand across the slip's writing, as large as fits (TITLE_FITS);
## returns where the next part starts (slip px).
func _slip_title(parts: Control, text: String, top: float) -> float:
	var k: float = UiFonts.K
	var title := _slip_ink(UiFonts.keep_all(text), UiFonts.HAND, 400, 27.0, Paper.INK)
	title.name = "Bill"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var room: float = (SLIP_X1 - SLIP_X0) * k
	var lines: int = 1
	var css: float = 27.0
	for fit: Array in TITLE_FITS:
		css = float(fit[0])
		title.add_theme_font_size_override("font_size", UiFonts.size(css))
		lines = _lines_of(title, room)
		if lines <= int(fit[1]):
			break
	var font: Font = title.get_theme_font("font")
	var fs: int = title.get_theme_font_size("font_size")
	var line_h: float = font.get_height(fs) if lines == 1 else css * k
	if lines > 1:
		title.add_theme_constant_override("line_spacing", int(round(line_h - font.get_height(fs))))
	title.custom_minimum_size = Vector2(room, 0.0)
	title.size = Vector2(room, line_h * float(lines))
	title.position = Vector2(SLIP_X0 * k, top * k)
	parts.add_child(title)
	return top + line_h * float(lines) / k


## The votes on a line of 20: each word in side ink, its number in the number face.
func _slip_votes(parts: Control, votes: Array, top: float) -> float:
	var k: float = UiFonts.K
	var x: float = SLIP_X0 * k
	var base: float = -1.0
	for v: Array in votes:
		var w := _slip_ink(String(v[0]), UiFonts.WORD, 400, 12.0, Paper.INK2, 0.72)
		parts.add_child(w)
		if base < 0.0:
			GlassParts.put(w, SLIP_X0, top, 20.0)
			base = GlassParts.base_of(w)
		else:
			GlassParts.put_on(w, x, base)
		x += GlassParts.text_w(w) + 3.0 * k
		var n := _slip_ink(str(int(v[1])), UiFonts.NUMBER, 600, 15.0, Paper.INK)
		n.name = "Vote_" + String(v[0])
		parts.add_child(n)
		GlassParts.put_on(n, x, base)
		x += GlassParts.text_w(n) + 9.0 * k
	return top + 20.0


## One move as the bill's change row: the word at the left, at the right the
## number before in side ink, an arrow and the number now, or the number now
## and 「그대로」; the dotted line under it. Returns where the next row starts.
func _slip_row(parts: Control, row: Array, top: float) -> float:
	var k: float = UiFonts.K
	var pad: float = 5.0
	# Trust and tension by their marks, as the gauges above show them (decisions.md
	# 「계기는 글자 대신 아이콘과 숫자」, 결정 417); a group's relation keeps its
	# name. The empty word holds the line.
	var mark_id: String = String(ROW_MARKS.get(String(row[0]), ""))
	var label := _slip_ink("" if mark_id != "" else String(row[0]), UiFonts.WORD, 400, 12.5, Paper.INK2)
	parts.add_child(label)
	if mark_id != "":
		var mark: TextureRect = Paper.mark(mark_id, 15.0, Paper.INK2)
		mark.name = "Mark_" + mark_id
		parts.add_child(mark)
		mark.size = mark.custom_minimum_size
		mark.position = Vector2(SLIP_X0, top + pad + 3.0) * k
	var right: Array = []
	if String(row[1]) == "":
		right.append(_slip_ink(SAME, UiFonts.WORD, 400, 12.0, Paper.INK2))
		right.append(_slip_ink(String(row[2]), UiFonts.NUMBER, 600, 18.0, Paper.INK))
	else:
		right.append(_slip_ink(String(row[1]), UiFonts.NUMBER, 400, 14.0, Paper.INK2, 0.21))
		right.append(_slip_ink("→", UiFonts.WORD, 400, 12.0, Paper.INK2))
		right.append(_slip_ink(String(row[2]), UiFonts.NUMBER, 600, 18.0, Paper.INK))
	GlassParts.put(label, SLIP_X0, top + pad, 22.0)
	var base: float = GlassParts.base_of(label)
	var x1: float = SLIP_X1 * k
	for i in range(right.size() - 1, -1, -1):
		var p: Label = right[i]
		p.name = "Move_%s_%d" % [String(row[0]), i]
		parts.add_child(p)
		GlassParts.put_on(p, x1 - GlassParts.text_w(p), base)
		x1 = p.position.x - 4.0 * k
	var h: float = 31.0
	_slip_rule(parts, top + h - 2.0, true)
	return top + h


## A rule across the slip at `y` (slip px): solid under the votes, dotted under a move.
func _slip_rule(parts: Control, y: float, dotted: bool) -> void:
	var k: float = UiFonts.K
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(SLIP_X0, y) * k
	c.size = Vector2(SLIP_X1 - SLIP_X0, 2.0) * k
	c.draw.connect(func() -> void:
		if not dotted:
			c.draw_rect(Rect2(Vector2.ZERO, c.size), SLIP_RULE)
			return
		# 2px dotted: round dots 2 across, 4 apart.
		var step: float = 4.0 * k
		var r: float = 1.0 * k
		var x: float = r
		while x < c.size.x:
			c.draw_circle(Vector2(x, r), r, SLIP_RULE, true, -1.0, true)
			x += step)
	parts.add_child(c)


## What the vote came to, stamped (도장 #7e3f1c): the seal's ring round the
## word, askew. A line sets its parts straight, so it leans in a holder its size.
func _stamp(word: String) -> Control:
	var l := Paper.ink(word, UiFonts.WORD, 600, 15.0, Color(Paper.SEAL, 0.88), 3.0)
	l.name = "Stamp"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Paper.SEAL, 0.05)
	sb.set_border_width_all(int(round(UiFonts.px(2.0))))
	sb.border_color = Color(Paper.SEAL, 0.8)
	sb.set_corner_radius_all(int(round(UiFonts.px(4.0))))
	sb.corner_detail = 6
	# The last letter's spacing hangs past it: a little less room on its side.
	sb.content_margin_left = UiFonts.px(10.0)
	sb.content_margin_right = UiFonts.px(7.0)
	sb.content_margin_top = UiFonts.px(1.0)
	sb.content_margin_bottom = UiFonts.px(1.0)
	l.add_theme_stylebox_override("normal", sb)
	var holder := Control.new()
	holder.name = "StampHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	var need: Vector2 = l.get_combined_minimum_size()
	holder.custom_minimum_size = need
	holder.size = need
	l.size = need
	l.pivot_offset = need * 0.5
	l.rotation = deg_to_rad(STAMP_TILT_DEG)
	return holder


## A line in side ink with its numbers in the number face on its baseline, in a
## line box of `box_css`.
func _runs(text: String, box_css: float) -> Control:
	var line = TypeLine.new(0.0, box_css)
	for r: Array in ReceiptSheet.num_runs(text):
		if bool(r[1]):
			line.add_child(Paper.ink(String(r[0]), UiFonts.NUMBER, 400, 14.0, Paper.INK, 0.21))
		else:
			line.add_child(Paper.ink(String(r[0]), UiFonts.WORD, 400, 12.0, Paper.INK2))
	return line


func _slip_ink(text: String, kind: int, weight: int, css: float, col: Color, spacing: float = 0.0) -> Label:
	return UiFonts.label(text, kind, weight, css, col, spacing)


func _lines_of(l: Label, width: float) -> int:
	var f: Font = l.get_theme_font("font")
	var s: int = l.get_theme_font_size("font_size")
	var para := TextParagraph.new()
	para.width = width
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.add_string(l.text, f, s)
	return maxi(1, para.get_line_count())
