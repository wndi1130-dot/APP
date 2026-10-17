extends Control
## Choosing the stop on paper (UI 3단계 시안 2차 03 「정차 · 승강장 가」, B1): what
## to go for, how long, which carriage and how many, the crew's exposure and
## names, then send them, scout first, or pass the stop by. The numbers are the
## train's own (train_stop.gd, ported from S1): the card reads a state and the
## tables and shows what crew_preview and stop_risk say; a pick goes through
## set_stop. It sets no game value of its own.
##
## The slice (slice_flow.gd) hands it the train-vectors sample till the train
## stream hands it the live state.

signal sent(g: Dictionary)
signal passed_by

const HudSkin = preload("res://game/ui/hud_skin.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const TrainStop = preload("res://game/train/train_stop.gd")
const St = preload("res://game/train/train_state.gd")
const ReceiptCard = preload("res://game/ui/receipt_card.gd")

const SAMPLE := "res://tests/fixtures/train/train_vectors.json"
## The first stretch's stop in the sample (phase stop, seg 1).
const SAMPLE_POINT: int = 4

## 디자인 토큰 2차: paper, its shade, the ink and its side ink.
const PAPER_SHADE := Color("b3a78c")
const INK := Color("231a12")
const INK_SIDE := Color(35 / 255.0, 26 / 255.0, 18 / 255.0, 0.72)
const INK_FAINT := Color(35 / 255.0, 26 / 255.0, 18 / 255.0, 0.38)
const CHIP_H: float = 64.0
const SHEET_W: float = 720.0

## S1 data.ts: the places and what is worth carrying back.
const PLACE_NAMES: Dictionary = {"freight": "화물역", "houses": "주택가", "hospital": "병원", "factory": "공장", "church": "교회", "office": "관청"}
const TARGETS: Array = [["coal", "석탄"], ["food", "식량"], ["medicine", "의약품"], ["luxury", "사치품"]]
## What a place is likely to still have, by what it is richest in (S1 loot weights).
const PLACE_HINT: Dictionary = {"freight": "석탄이 남았을 만한 곳", "houses": "먹을 것이 남았을 만한 곳", "hospital": "약이 남았을 만한 곳", "factory": "석탄이 남았을 만한 곳", "church": "모일 것이 남았을 만한 곳", "office": "기록이 남았을 만한 곳"}
const RISK_WORDS: Dictionary = {"calm": "조용함", "light": "가벼움", "hurt": "다칠 수 있음", "dead": "죽을 수 있음"}
const COMM_SHORT: Dictionary = {"tail": "꼬리", "medtech": "의무", "guard": "경비", "front": "앞칸"}

var g: Dictionary = {}
var t: Dictionary = {}
## The stop's own name over its kind (술레후프 over 화물역), "" for the kind alone.
var stop_name: String = ""
## The promises this stop goes out with (S3 출발 명세), shown on one line.
var promises: Array = []
var sheet: PanelContainer
var body: VBoxContainer


## The state and tables of the sample's first stop: [g, t].
static func sample() -> Array:
	if not FileAccess.file_exists(SAMPLE):
		return [{}, {}]
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
	if not d is Dictionary:
		return [{}, {}]
	var pts: Array = d.get("points", [])
	if pts.size() <= SAMPLE_POINT:
		return [{}, {}]
	return [(pts[SAMPLE_POINT]["state"] as Dictionary).duplicate(true), d.get("tables", {})]


## What the card says for state `g0` (tests read this; the card draws it).
static func model(g0: Dictionary, t0: Dictionary, name: String = "") -> Dictionary:
	var stop: Dictionary = g0.get("stop", {}) if g0.get("stop") is Dictionary else {}
	if stop.is_empty() or t0.is_empty():
		return {}
	var place: String = String(stop.get("place", ""))
	var c: String = String(stop.get("crewComm", "tail"))
	var size: int = int(stop.get("crewSize", 4))
	var risk: Dictionary = TrainStop.stop_risk(g0, t0)
	var pre: Dictionary = TrainStop.crew_preview(g0, t0, c)
	var names: Array = TrainStop.crew_names(g0, t0, c, size)
	var who: String = ", ".join(names.slice(0, 2))
	if names.size() > 2:
		who += " 외 %d명" % (names.size() - 2)
	var comm_names: Dictionary = t0.get("COMM_NAME", {})
	var stays: Array = []
	for id in ["short", "normal", "long"]:
		var s: Dictionary = (t0.get("STAY", {}) as Dictionary).get(id, {})
		stays.append({"id": id, "word": String(s.get("name", id)), "cost": "석탄 −%d" % int(s.get("coal", 0)), "on": String(stop.get("stay", "normal")) == id})
	var targets: Array = []
	for row: Array in TARGETS:
		targets.append({"id": row[0], "word": row[1], "on": String(stop.get("target", "")) == row[0]})
	var crews: Array = []
	for id in t0.get("CREW_COMMS", []):
		crews.append({"id": id, "word": String(COMM_SHORT.get(id, comm_names.get(id, id))), "on": id == c})
	var known: bool = bool(stop.get("scout", false))
	return {
		"seg": "%d 구간 정차" % int(g0.get("seg", 1)),
		"place": name if name != "" else String(PLACE_NAMES.get(place, place)),
		"hint": ("%s · %s" % [PLACE_NAMES.get(place, place), PLACE_HINT.get(place, "")]) if name != "" else String(PLACE_HINT.get(place, "")),
		"risk": String(RISK_WORDS.get(TrainStop.risk_level(risk), "?")) if known else "?",
		"targets": targets,
		"stays": stays,
		"crews": crews,
		"size": size,
		"crew_line": "%s 노출 %d → %d · %s" % [COMM_SHORT.get(c, c), int(pre["from"]), int(pre["to"]), who],
		"band": String(risk.get("band", "")),
	}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if g.is_empty():
		var s: Array = sample()
		g = s[0]
		t = s[1]
	_build()


## Pick `key` (target, stay, crewComm, crewSize) through the train's own rule.
func pick(key: String, value: Variant) -> void:
	g = TrainStop.set_stop(g, t, {key: value})
	_fill()


func _build() -> void:
	sheet = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = HudSkin.PAPER
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(6, 0)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 34
	sb.content_margin_bottom = 28
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	sheet.custom_minimum_size = Vector2(SHEET_W, 0)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	add_child(_torn_edge())
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	sheet.add_child(body)
	_fill()


## The sheet's right side, torn off the pad: a ragged strip of paper and its
## shade, along the whole height.
func _torn_edge() -> Control:
	var e := Control.new()
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var place := func() -> void:
		e.position = Vector2(sheet.size.x, 0)
		e.size = Vector2(18, sheet.size.y)
		e.queue_redraw()
	sheet.resized.connect(place)
	e.draw.connect(func() -> void:
		var h: float = e.size.y
		var shade := PackedVector2Array([Vector2(0, 0)])
		var paper := PackedVector2Array([Vector2(0, 0)])
		var y: float = 0.0
		var i: int = 0
		while y < h:
			# A fixed ragged run, the same on every phone (no dice in the look).
			var out: float = 4.0 + float((i * 7) % 5) * 2.2
			shade.append(Vector2(out + 4.0, y))
			paper.append(Vector2(out, y))
			y += 9.0 + float((i * 3) % 4) * 3.0
			i += 1
		shade.append_array([Vector2(4.0, h), Vector2(0, h)])
		paper.append_array([Vector2(0, h)])
		e.draw_colored_polygon(shade, PAPER_SHADE)
		e.draw_colored_polygon(paper, HudSkin.PAPER))
	place.call()
	return e


## A word in ink, in the paper's serif where the phone has one.
func _ink(text: String, px: int, color: Color = INK, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Serif CJK KR", "Noto Serif KR", "Batang", "serif"])
	f.font_weight = weight
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A chip on paper (시안 11 「종이 위 · 먹빛」): an ink ring, or filled with ink
## when picked; a target picked gets the lamp's line under its word.
func _chip(text: String, on: bool, cb: Callable, underline: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, CHIP_H)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Serif CJK KR", "Noto Serif KR", "Batang", "serif"])
	f.font_weight = 600
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(999)
		sb.set_border_width_all(3)
		sb.content_margin_left = 24
		sb.content_margin_right = 24
		if on:
			sb.bg_color = INK
			sb.border_color = INK
			if underline:
				# The lamp's line under a picked target: the only border it has.
				sb.set_border_width_all(0)
				sb.border_width_bottom = 6
				sb.border_color = HudSkin.LAMP2
		else:
			sb.bg_color = Color(1, 1, 1, 0.12) if state != "pressed" else Color(0, 0, 0, 0.08)
			sb.border_color = INK_FAINT if state != "hover" else INK_SIDE
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", HudSkin.PAPER if on else INK)
	b.add_theme_color_override("font_hover_color", HudSkin.PAPER if on else INK)
	b.add_theme_color_override("font_pressed_color", HudSkin.PAPER if on else INK)
	b.pressed.connect(cb)
	return b


## A row: its question in side ink at the left, then its chips.
func _row(question: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var q := _ink(question, 20, INK_SIDE)
	q.custom_minimum_size = Vector2(96, 0)
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(q)
	body.add_child(h)
	return h


func _fill() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var m: Dictionary = model(g, t, stop_name)
	if m.is_empty():
		body.add_child(_ink("정차 없음", 24))
		return
	var head := HBoxContainer.new()
	body.add_child(head)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(_ink(String(m["seg"]), 18, INK_SIDE))
	var place := _ink(String(m["place"]), 40, INK, 700)
	place.name = "Place"
	names.add_child(place)
	names.add_child(_ink(String(m["hint"]), 18, INK_SIDE))
	var risk := _ink("위험  " + String(m["risk"]), 22, INK_SIDE, 600)
	risk.name = "Risk"
	risk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(risk)
	var what := _row("무엇을")
	for row: Dictionary in m["targets"]:
		what.add_child(_chip(String(row["word"]), bool(row["on"]), pick.bind("target", row["id"]), true))
	var long := _row("얼마나")
	for row: Dictionary in m["stays"]:
		long.add_child(_chip("%s  %s" % [row["word"], row["cost"]], bool(row["on"]), pick.bind("stay", row["id"])))
	var who := _row("누구를")
	for row: Dictionary in m["crews"]:
		who.add_child(_chip(String(row["word"]), bool(row["on"]), pick.bind("crewComm", row["id"])))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(gap)
	var size: int = int(m["size"])
	who.add_child(_count_key("‹", pick.bind("crewSize", size - 1)))
	var n := _ink("%d명" % size, 30, INK, 700)
	n.name = "CrewSize"
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who.add_child(n)
	who.add_child(_count_key("›", pick.bind("crewSize", size + 1)))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var mark := TextureRect.new()
	mark.texture = HudIcons.texture("crew", 22, INK_SIDE)
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mark.custom_minimum_size = Vector2(24, 24)
	line.add_child(mark)
	var cl := _ink(String(m["crew_line"]), 20, INK_SIDE)
	cl.name = "CrewLine"
	line.add_child(cl)
	body.add_child(line)
	var said: String = ReceiptCard.promise_line(promises)
	if said != "":
		var pl := HBoxContainer.new()
		pl.add_theme_constant_override("separation", 10)
		var seal := TextureRect.new()
		seal.texture = HudIcons.texture("promise", 22, INK_SIDE)
		seal.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		seal.custom_minimum_size = Vector2(24, 24)
		pl.add_child(seal)
		var pw := _ink("이번 정차 " + said.replace("약속: ", "약속 · "), 20, INK_SIDE)
		pw.name = "Promises"
		pl.add_child(pw)
		body.add_child(pl)
	var room := Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(room)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 22)
	body.add_child(foot)
	var pass_key := _word_key("지나치기", func() -> void: passed_by.emit())
	pass_key.name = "PassBy"
	foot.add_child(pass_key)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fill)
	var go := _send_key("보내기  ›")
	go.name = "Send"
	go.pressed.connect(func() -> void: sent.emit(g))
	foot.add_child(go)


## A key with no ring (시안 「테 없는 단추」): a word over a line of ink.
func _word_key(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, CHIP_H)
	b.add_theme_font_size_override("font_size", 24)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, INK)
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_width_bottom = 3
	under.border_color = INK_FAINT
	under.content_margin_left = 6
	under.content_margin_right = 6
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, under)
	b.pressed.connect(cb)
	return b


## The counting keys either side of the crew size, a full touch each.
func _count_key(text: String, cb: Callable) -> Button:
	var b := _word_key(text, cb)
	b.custom_minimum_size = Vector2(CHIP_H, CHIP_H)
	b.add_theme_font_size_override("font_size", 34)
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, none)
	return b


## The main key: lamp enamel in a brass rim (시안 11 「주 단추」).
func _send_key(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(280, 76)
	b.add_theme_font_size_override("font_size", 28)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, HudSkin.LAMP_INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = HudSkin.LAMP2 if state != "pressed" else HudSkin.LAMP3
		sb.set_corner_radius_all(999)
		sb.set_border_width_all(3)
		sb.border_color = HudSkin.RIM2
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3 if state != "pressed" else 1)
		b.add_theme_stylebox_override(state, sb)
	return b
