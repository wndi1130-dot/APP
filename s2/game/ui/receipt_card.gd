extends RefCounted
## The return receipt as a paper slip (UI 3단계 시안 2차, B1 「성에 낀 계기」):
## the end card of a stop. Paper and ink, the way the train hands over a
## receipt, with the end of the stop stamped on it. It reads the stop's own
## record (result["receipt"]) and sets nothing. People are numbers here, never
## names (user decision 183), so the dead are only ever counted.
##
## The promises the stop made are observations only (receipt.gd see_promise):
## who saw them and which carriage heard. Whether one was kept is the train's
## call, on its return.

const HudSkin = preload("res://game/ui/hud_skin.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const LeaveScene = preload("res://game/ui/leave_scene.gd")
const TrainRules = preload("res://game/train/train_rules.gd")

const PAPER_W: float = 760.0
## 디자인 토큰 2차 2절: paper's shade, the side ink at 72%, the stamp.
const PAPER_SHADE := Color("b3a78c")
const INK_SIDE := Color(35 / 255.0, 26 / 255.0, 18 / 255.0, 0.72)
const STAMP := Color("7e3f1c")
const TEAR_H: float = 9.0
const TEAR_STEP: float = 14.0
const PLACE_NAME := "술레후프"
const REASONS: Dictionary = {"departed": "출발", "limit": "시간 끝", "wiped": "모두 쓰러짐"}
## The promise kinds the first trial has (s3_first_trial_scope 1절), by the
## short name the field shows.
const PROMISE_NAMES: Dictionary = {"prologue": "서막", "skip_dispatch": "교대", "research_pick": "연구"}


static var _comms: Dictionary = {}


## A carriage's name from the train's rules ("tail" → 꼬리칸).
static func comm_name(id: String) -> String:
	if _comms.is_empty():
		_comms = TrainRules.load_default().get("comms", {})
	var comms: Dictionary = _comms
	return String((comms.get(id, {}) as Dictionary).get("name", id))


## A promise in a few words: the state the train sent ("state"), or else what
## the departure says, cut to a word or two (decision 293 ③: no 「~한다」).
static func promise_state(p: Dictionary) -> String:
	if p.has("state"):
		return String(p["state"])
	var made_to: String = String(p.get("madeTo", ""))
	match String(p.get("kind", "")):
		"prologue":
			var n: int = (p.get("subjects", []) as Array).size()
			return "%d명 데려오기" % n if n > 0 else "데려오기"
		"skip_dispatch":
			return "%s 파견 제외" % comm_name(made_to)
		"research_pick":
			return "%s 연구 우선" % comm_name(made_to)
	return String(p.get("label", ""))


## The field's one line of promises (「약속: 서막 ○○ / 교대 ○○」), "" for none.
static func promise_line(promises: Array) -> String:
	var parts: Array = []
	for p in promises:
		if not p is Dictionary:
			continue
		var kind: String = String(p.get("kind", ""))
		var said: String = promise_state(p)
		parts.append((String(PROMISE_NAMES.get(kind, kind)) + " " + said).strip_edges())
	return "" if parts.is_empty() else "약속: " + " / ".join(parts)


## "D1 10:30" → "1일째 10:30".
static func _day_time(t: String) -> String:
	var bits: PackedStringArray = t.split(" ", false, 1)
	if bits.size() == 2 and bits[0].begins_with("D") and bits[0].substr(1).is_valid_int():
		return "%s일째 %s" % [bits[0].substr(1), bits[1]]
	return t


## The lines under the columns: each promise seen, and the symbol carried.
static func seen_lines(r: Dictionary) -> Array:
	var out: Array = []
	for fp in r.get("fieldPromises", []):
		if not fp is Dictionary:
			continue
		var kind: String = String(fp.get("kind", ""))
		var heard: Array = []
		for g in fp.get("heardBy", []):
			heard.append(comm_name(String(g)))
		var line: String = "약속 %s · 본 사람 %d" % [PROMISE_NAMES.get(kind, kind), (fp.get("witnesses", []) as Array).size()]
		if not heard.is_empty():
			line += " · %s 들음" % ", ".join(heard)
		out.append(line)
	# The old promise shape (receipt.gd promise): a leader's word and whether it held.
	for p in r.get("promises", []):
		if p is Dictionary:
			out.append("약속 %s · %s" % [p.get("condition", "?"), "지킴" if p.get("kept", false) else "어김"])
	var sym = r.get("symbol", null)
	if sym is Dictionary and not (sym as Dictionary).is_empty():
		var line: String = "상징물 · %s의 것" % comm_name(String(sym.get("groupId", "")))
		if String(sym.get("carriedBy", "")) != "":
			line += " · 든 사람 있음"
		out.append(line)
	return out


## What the slip says, for the card and the tests alike.
static func rows(result: Dictionary) -> Dictionary:
	var r: Dictionary = result.get("receipt", {})
	var time: Dictionary = r.get("time", {})
	var when: String = ""
	if time.has("arrive") and time.has("depart"):
		var depart: String = _day_time(String(time["depart"]))
		var arrive: String = _day_time(String(time["arrive"]))
		# The same day once: 「1일째 10:30 → 13:10」.
		var day: String = arrive.get_slice(" ", 0)
		if depart.begins_with(day + " "):
			depart = depart.trim_prefix(day + " ")
		when = "%s → %s" % [arrive, depart]
	var reason: String = String(result.get("reason", ""))
	return {
		"place": PLACE_NAME,
		"stamp": String(REASONS.get(reason, reason)),
		"when": when,
		"head": LeaveScene.head(result),
		"columns": LeaveScene.columns(result),
		"seen": seen_lines(r),
	}


## The paper's ink: a serif where the phone has one (the train's documents), the
## UI's own face where it does not.
static func _ink_font(weight: int = 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Serif CJK KR", "Noto Serif KR", "Batang", "serif"])
	f.font_weight = weight
	return f


static func _ink(text: String, px: int, color: Color = HudSkin.PAPER_INK, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _ink_font(weight))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A dashed rule in soft ink, where the slip would be folded.
static func _rule() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 14)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		c.draw_dashed_line(Vector2(0, 7), Vector2(c.size.x, 7), Color(INK_SIDE.r, INK_SIDE.g, INK_SIDE.b, 0.35), 2.0, 7.0))
	return c


## The torn foot of the slip: teeth of paper under its last line.
static func _tear() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, TEAR_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(c.size.x, 0)])
		var x: float = c.size.x
		var down: bool = true
		while x > 0.0:
			x = maxf(0.0, x - TEAR_STEP * 0.5)
			pts.append(Vector2(x, TEAR_H if down else 0.0))
			down = not down
		c.draw_colored_polygon(pts, HudSkin.PAPER))
	return c


## The end, stamped: a ring of stamp ink, a little askew.
static func _stamp(word: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(STAMP.r, STAMP.g, STAMP.b, 0.06)
	sb.border_color = Color(STAMP.r, STAMP.g, STAMP.b, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_ink(word, 24, Color(STAMP.r, STAMP.g, STAMP.b, 0.9), 700))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.name = "Stamp"
	# A container puts its children straight, so the stamp leans inside a
	# plain holder of its size.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(p)
	var fit := func() -> void:
		var m: Vector2 = p.get_combined_minimum_size()
		holder.custom_minimum_size = m
		p.size = m
		p.pivot_offset = m * 0.5
	p.minimum_size_changed.connect(fit)
	fit.call()
	p.rotation = deg_to_rad(-7.0)
	return holder


## The slip itself: place and stamp, the head lines, four columns, what was
## seen, then `notes` (the held train's lines, the stop's choices) in side ink.
static func build(result: Dictionary, notes: Array = []) -> Control:
	var d: Dictionary = rows(result)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.custom_minimum_size = Vector2(PAPER_W, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := PanelContainer.new()
	var sb: StyleBoxFlat = HudSkin.paper(30.0, 22.0)
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.border_width_top = 6
	sb.border_color = PAPER_SHADE
	paper.add_theme_stylebox_override("panel", sb)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(paper)
	box.add_child(_tear())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(v)
	# The slip's top line: what it is, where, when; the end stamped at its right.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 0)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(name_col)
	name_col.add_child(_ink("귀환 영수증", 16, INK_SIDE, 600))
	var where := _ink(String(d["place"]), 30, HudSkin.PAPER_INK, 700)
	where.name = "Place"
	name_col.add_child(where)
	if String(d["when"]) != "":
		name_col.add_child(_ink(String(d["when"]), 17, INK_SIDE))
	if String(d["stamp"]) != "":
		top.add_child(_stamp(String(d["stamp"])))
	v.add_child(_rule())
	var head: Array = d["head"]
	var big := _ink(String(head[0]), 26, HudSkin.PAPER_INK, 600)
	big.name = "Head"
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(big)
	if head.size() > 1:
		v.add_child(_ink(String(head[1]), 18, INK_SIDE))
	v.add_child(_rule())
	var cols := HBoxContainer.new()
	cols.name = "Columns"
	cols.add_theme_constant_override("separation", 18)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cols)
	for column: Array in d["columns"]:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 2)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cols.add_child(c)
		c.add_child(_ink(String(column[0]), 15, INK_SIDE, 600))
		for row in column[1]:
			var l := _ink(String(row), 19)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c.add_child(l)
	var seen: Array = d["seen"]
	if not seen.is_empty():
		v.add_child(_rule())
		var s := VBoxContainer.new()
		s.name = "Seen"
		s.add_theme_constant_override("separation", 2)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)
		for line in seen:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mark := TextureRect.new()
			mark.texture = HudIcons.texture("promise" if String(line).begins_with("약속") else "inv", 18, INK_SIDE)
			mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			mark.custom_minimum_size = Vector2(20, 20)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(mark)
			row.add_child(_ink(String(line), 18))
			s.add_child(row)
		if seen.any(func(t) -> bool: return String(t).begins_with("약속 ") and not (String(t).ends_with("지킴") or String(t).ends_with("어김"))):
			s.add_child(_ink("지켰는지는 열차에서 · 돌아온 사람이 본 대로", 15, INK_SIDE))
	if not notes.is_empty():
		v.add_child(_rule())
		var n := _ink("\n".join(notes), 16, INK_SIDE)
		n.name = "Notes"
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(n)
	return box
