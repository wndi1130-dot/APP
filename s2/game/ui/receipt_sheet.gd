extends Control
## The return receipt on the stop's own sheet (UI 3단계 시안 2차, B1; the paper of
## 03 「정차 · 승강장 가」 handed back): the sheet comes in from the left where the
## stop card went out and says what the stop came to. The hours at the top
## right, the place in pen with the end stamped at its right,
## the head lines (leave_scene.gd), the four columns side by side, what was seen
## of the promises and of the symbol, and at the foot the main key that goes on.
## It reads the stop's own record (result["receipt"], S3 영수증 판 4) through
## receipt_card.gd and sets nothing. People are numbers here, never names.
##
## The look is the stop card's (stop_pick_card.gd) in the mockup's px × ui_fonts.gd
## K: the sheet 446 × 346 at (−10, 50); in it the head (50), the head lines (26 ·
## 18), a rule, the columns, a rule, a line of 22 for each thing seen and the
## keys (48) at the foot.

signal went_on

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const Paper = preload("res://game/ui/paper_parts.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const TypeLine = preload("res://game/ui/type_line.gd")
const ReceiptCard = preload("res://game/ui/receipt_card.gd")

## Where the mockup lays the sheet on its 844 × 390 stage (the stop card's place).
const SHEET_AT := Vector2(-10, 50)
## The four columns stand this far apart.
const COL_GAP: float = 10.0
## The end stamped askew, as a rubber stamp comes down.
const STAMP_TILT_DEG: float = -6.0

var result: Dictionary = {}
## The stretch the stop was on; 0 where there is none to say (the field played
## alone), and the kick says no number.
var seg: int = 1
## The main key's word (the next step's); "" leaves the foot bare, for keys of
## the caller's own off the paper (the field's end).
var go_word: String = ""
## Small keys of the paper's own (.ghost) at the foot's left, [word, Callable] each
## (the field's end: its two copies).
var side_keys: Array = []
var sheet: Control
var body: VBoxContainer
var go_key: Button


## What the sheet says for a field result (tests read this; the sheet draws it);
## empty when there is no receipt in it.
static func model(result0: Dictionary, seg0: int = 1) -> Dictionary:
	var r = result0.get("receipt", {})
	if not r is Dictionary or (r as Dictionary).is_empty():
		return {}
	var d: Dictionary = ReceiptCard.rows(result0)
	# The port's two-way particles settled (「과(와)」 → 「과」 or 「와」).
	d["head"] = (d["head"] as Array).map(func(s: Variant) -> String: return UiFonts.josa(String(s)))
	d["seen"] = (d["seen"] as Array).map(func(s: Variant) -> String: return UiFonts.josa(String(s)))
	d["seg"] = seg0
	return d


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
	var m: Dictionary = model(result, seg)
	if m.is_empty():
		body.add_child(Paper.ink("영수증 없음", UiFonts.HAND, 400, 31.0))
	else:
		_head(m)
		_head_lines(m["head"])
		body.add_child(_rule())
		_columns(m["columns"])
		if not (m["seen"] as Array).is_empty():
			body.add_child(_rule())
			_seen(m["seen"])
	var room := Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(room)
	_keys()


## The head (50, as the stop card's): the kick in its line of 24 (the stretch in
## the number face, what the paper is, and at the right the hours), then the
## place in pen on a line of 28 in 26 with the end stamped at its right.
func _head(m: Dictionary) -> void:
	var head := VBoxContainer.new()
	head.custom_minimum_size = Vector2(0, UiFonts.px(50.0))
	head.add_theme_constant_override("separation", 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(head)
	var kick := Paper.line_box(24.0)
	kick.name = "Kick"
	kick.add_theme_constant_override("separation", int(round(UiFonts.px(4.0))))
	# The row keeps only the hours at its right: no 「N 구간 정차 · 귀환 영수증」
	# (결정 417); the paper coming back from where the stop card went says it.
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kick.add_child(gap)
	if String(m["when"]) != "":
		var when = _runs(String(m["when"]), 0.0, 24.0)
		when.name = "When"
		kick.add_child(when)
	for c in kick.get_children():
		(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(kick)
	var title = TypeLine.new(28.0, 26.0)
	title.name = "Title"
	head.add_child(title)
	var place := Paper.ink(String(m["place"]), UiFonts.HAND, 400, 31.0)
	place.name = "Place"
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(place)
	if String(m["stamp"]) != "":
		title.add_child(_stamp(String(m["stamp"])))


## What the stop comes to in pen (a 24 line of 26, as a note's title), and how
## long it was in side ink under it (18).
func _head_lines(head: Array) -> void:
	if head.is_empty():
		return
	# The pen's tall letters want air between the place and this line.
	var air := Control.new()
	air.custom_minimum_size = Vector2(0, UiFonts.px(4.0))
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(air)
	var top = TypeLine.new(26.0, 26.0)
	var said := Paper.ink(UiFonts.keep_all(String(head[0])), UiFonts.HAND, 400, 24.0)
	said.name = "Head"
	top.add_child(said)
	body.add_child(top)
	if head.size() > 1:
		var under = _runs(String(head[1]), 0.0, 18.0)
		under.name = "Stay"
		body.add_child(under)


## A rule across the sheet in faint ink (2 px, the least a line that means
## something is), in a row of 8.
func _rule() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, UiFonts.px(8.0))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(0, (c.size.y - UiFonts.px(2.0)) * 0.5, c.size.x, UiFonts.px(2.0)), Paper.LINE))
	return c


## The four columns (실은 것, 탄 사람, 다친 사람, 남긴 것) side by side, each its
## title in side ink over its rows: a count in words and the number face, or a
## line of its own in side ink that wraps in its column between words.
func _columns(columns: Array) -> void:
	var cols := HBoxContainer.new()
	cols.name = "Columns"
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(cols)
	# A column's width in whole game px: a container rounds what it lays out, so
	# four of them and their gaps stay inside the writing's width.
	var gap: int = int(round(UiFonts.px(COL_GAP)))
	var room: float = UiFonts.px(PaperSheet.SIZE.x - PaperSheet.INSET_L - PaperSheet.INSET_R)
	var w: float = floorf((room - gap * 3.0) / 4.0)
	cols.add_theme_constant_override("separation", gap)
	for column: Array in columns:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 0)
		c.custom_minimum_size = Vector2(w, 0)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cols.add_child(c)
		var t = TypeLine.new(0.0, 18.0)
		t.add_child(Paper.ink(String(column[0]), UiFonts.WORD, 400, 12.0, Paper.INK2, 1.44))
		c.add_child(t)
		for row in column[1]:
			c.add_child(_cell(String(row), w))


## One row of a column: 「석탄 6」 and 「4명」 as words and numbers on a line of
## 21; a line with no number in it in side ink, wrapping as the mockup wraps.
func _cell(text: String, w: float) -> Control:
	var runs: Array = num_runs(text)
	if runs.any(func(r: Array) -> bool: return bool(r[1])):
		var line = TypeLine.new(0.0, 21.0)
		for r: Array in runs:
			if bool(r[1]):
				line.add_child(Paper.ink(String(r[0]), UiFonts.NUMBER, 500, 17.0, Paper.INK, 0.17))
			else:
				line.add_child(Paper.ink(String(r[0]), UiFonts.WORD, 500, 14.0, Paper.INK))
		return line
	var l := Paper.ink(UiFonts.keep_all(text), UiFonts.WORD, 400, 12.0, Paper.INK2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	return l


## What was seen (.promline, 22 each): the promises with the stop card's mark
## for them, the symbol with the four-square one. A promise with no 지킴 · 어김
## stamped on it is one the train has not called yet (결정 417: no line saying so).
func _seen(seen: Array) -> void:
	var box := VBoxContainer.new()
	box.name = "Seen"
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(box)
	for line in seen:
		var s: String = String(line)
		var row := Paper.line_box(22.0)
		row.add_theme_constant_override("separation", int(round(UiFonts.px(6.0))))
		row.add_child(Paper.mark("promise" if s.begins_with("약속") else "inv", 16.0))
		var words = _runs(s, 0.0, 22.0)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)
		box.add_child(row)


## The keys at the foot (.sh__act, 48): the small ones at the left, the main key
## at the right, as 보내기 is.
func _keys() -> void:
	if go_word == "" and side_keys.is_empty():
		return
	var foot := Paper.line_box(48.0)
	foot.name = "Foot"
	body.add_child(foot)
	for pair in side_keys:
		var k := Paper.ghost(String(pair[0]))
		# Each a full finger high on the foot's line of 48.
		k.custom_minimum_size.y = UiFonts.px(48.0)
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		k.pressed.connect(pair[1])
		foot.add_child(k)
	if go_word == "":
		return
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(fill)
	go_key = LampKey.new(go_word)
	go_key.name = "Go"
	go_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_key.pressed.connect(func() -> void: went_on.emit())
	foot.add_child(go_key)


## The end, stamped at the place's right (도장 #7e3f1c): the seal's ring round the
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
	var fit := func() -> void:
		var need: Vector2 = l.get_combined_minimum_size()
		holder.custom_minimum_size = need
		l.size = need
		l.pivot_offset = need * 0.5
	l.minimum_size_changed.connect(fit)
	fit.call()
	l.rotation = deg_to_rad(STAMP_TILT_DEG)
	return holder


## A line in side ink with its numbers in the number face on its baseline
## (.promline .num), in a line box of `box_css`.
func _runs(text: String, line_css: float, box_css: float) -> Control:
	var line = TypeLine.new(line_css, box_css)
	for r: Array in num_runs(text):
		if bool(r[1]):
			line.add_child(Paper.ink(String(r[0]), UiFonts.NUMBER, 400, 14.0, Paper.INK, 0.21))
		else:
			line.add_child(Paper.ink(String(r[0]), UiFonts.WORD, 400, 12.0, Paper.INK2))
	return line


## `text` cut into runs of numbers and of the rest: [[run, is_number], …]. A
## number keeps what joins its digits (「10:30」, 「0/2」, 「1.5」) in one run.
static func num_runs(text: String) -> Array:
	var re := RegEx.create_from_string("[0-9]+(?:[:./][0-9]+)*")
	var out: Array = []
	var at: int = 0
	for m: RegExMatch in re.search_all(text):
		if m.get_start() > at:
			out.append([text.substr(at, m.get_start() - at), false])
		out.append([m.get_string(), true])
		at = m.get_end()
	if at < text.length():
		out.append([text.substr(at), false])
	return out
