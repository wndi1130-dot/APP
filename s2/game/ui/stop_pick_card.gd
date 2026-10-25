extends Control
## Choosing the stop on paper (UI 3단계 시안 2차 03 「정차 · 승강장 가」, B1): what
## to go for, how long, which carriage and how many, the crew's exposure and
## names, then send them, scout first, or pass the stop by. The numbers are the
## train's own (train_stop.gd, ported from S1): the card reads a state and the
## tables and shows what crew_preview and stop_risk say; a pick goes through
## set_stop. It sets no game value of its own.
##
## The look is the mockup's, measured part by part (its px × ui_fonts.gd K):
## the sheet (paper_sheet.gd) comes in from the left at (−10, 50), 446 × 346,
## leaning −0.45°; inside it the head (50), the scene line (26), three rows of
## 46, the crew line (22), the promise line (24) and the keys (48) at the foot.
##
## The slice (slice_flow.gd) hands it the train-vectors sample till the train
## stream hands it the live state.

signal sent(g: Dictionary)
signal passed_by
## 정찰 먼저 was pressed. The train has no scouting yet, so the key says so
## (ui_deny.gd) and only tells whoever listens.
signal scout_asked

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const Paper = preload("res://game/ui/paper_parts.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const TypeLine = preload("res://game/ui/type_line.gd")
const TrainStop = preload("res://game/train/train_stop.gd")
const ReceiptCard = preload("res://game/ui/receipt_card.gd")

const SAMPLE := "res://tests/fixtures/train/train_vectors.json"
## The first stretch's stop in the sample (phase stop, seg 1). The v2 points add
## a hands variant after each step, which put it at 6.
const SAMPLE_POINT: int = 6
## Where the mockup lays the sheet on its 844 × 390 stage.
const SHEET_AT := Vector2(-10, 50)

## S1 data.ts: the places and what is worth carrying back.
const PLACE_NAMES: Dictionary = {"freight": "화물역", "houses": "주택가", "hospital": "병원", "factory": "공장", "church": "교회", "office": "관청"}
const TARGETS: Array = [["coal", "석탄"], ["food", "식량"], ["medicine", "의약품"], ["luxury", "사치품"]]
const RISK_WORDS: Dictionary = {"calm": "조용함", "light": "가벼움", "hurt": "다칠 수 있음", "dead": "죽을 수 있음"}
const COMM_SHORT: Dictionary = {"tail": "꼬리", "medtech": "의무", "guard": "경비", "front": "앞칸"}

var g: Dictionary = {}
var t: Dictionary = {}
## The stop's own name over its kind (술레후프 over 화물역), "" for the kind alone.
var stop_name: String = ""
## The promises this stop goes out with (S3 출발 명세), shown on one line.
var promises: Array = []
## Kept for callers that left room for the gauges; the sheet's place is the mockup's now.
var top_room: float = 0.0
var sheet: Control
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
	# How much of each the place is likely to still have, against what it has
	# most of (S1 card.ts target bar); −1 where the tables do not say.
	var loot: Dictionary = {}
	for p in t0.get("PLACES", []):
		if p is Dictionary and String(p.get("id", "")) == place and p.get("loot") is Dictionary:
			loot = p["loot"]
	var most: float = 0.0
	for v in loot.values():
		most = maxf(most, float(v))
	var targets: Array = []
	for row: Array in TARGETS:
		var fill: float = float(loot.get(row[0], 0.0)) / most if most > 0.0 else -1.0
		targets.append({"id": row[0], "word": row[1], "on": String(stop.get("target", "")) == row[0], "fill": fill})
	var crews: Array = []
	for id in t0.get("CREW_COMMS", []):
		crews.append({"id": id, "word": String(COMM_SHORT.get(id, comm_names.get(id, id))), "on": id == c})
	var known: bool = bool(stop.get("scout", false))
	# Returned crew sit out the session's vote (crewAwayOf) when the cost says so.
	var away: bool = false
	var crew_rule: Dictionary = t0.get("CREW", {}) if t0.get("CREW") is Dictionary else {}
	var costs: Dictionary = t0.get("CREW_COST", {}) if t0.get("CREW_COST") is Dictionary else {}
	if costs.get(String(crew_rule.get("cost", ""))) is Dictionary:
		away = float(costs[String(crew_rule["cost"])].get("away", 0.0)) > 0.0
	return {
		"place": name if name != "" else String(PLACE_NAMES.get(place, place)),
		# Under a stop's own name, the kind of place it is; what it is likely to
		# hold is the target chips' fill, not a line (결정 417).
		"hint": String(PLACE_NAMES.get(place, place)) if name != "" else "",
		"risk": String(RISK_WORDS.get(TrainStop.risk_level(risk), "?")) if known else "?",
		"targets": targets,
		"stays": stays,
		"crews": crews,
		"comm": c,
		"size": size,
		"crew_line": "노출 %d → %d · %s" % [int(pre["from"]), int(pre["to"]), who],
		"exposure": [int(pre["from"]), int(pre["to"])],
		"names": names.slice(0, 2).map(func(n): return String(n).get_slice(" ", 0)),
		"more": maxi(0, names.size() - 2),
		"away": away,
		"band": String(risk.get("band", "")),
	}


## The stamp at the promise line's end: only what the pick already settles.
## A promise to leave a car out of the work is broken by sending that car.
static func promise_stamp(promises0: Array, comm: String, t0: Dictionary) -> Dictionary:
	for p in promises0:
		if p is Dictionary and String(p.get("kind", "")) == "skip_dispatch":
			var to: String = String(p.get("madeTo", ""))
			if to == "":
				continue
			var short: Dictionary = t0.get("COMM_SHORT", COMM_SHORT) if t0.get("COMM_SHORT") is Dictionary else COMM_SHORT
			if to == comm:
				return {"text": "고른 칸 %s · 약속과 다름" % String(short.get(comm, COMM_SHORT.get(comm, comm))), "off": true}
			return {"text": "고른 것과 같음", "off": false}
	return {}


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
	_fill()


func _fill() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var m: Dictionary = model(g, t, stop_name)
	if m.is_empty():
		body.add_child(Paper.ink("정차 없음", UiFonts.HAND, 400, 31.0))
		return
	_head(m)
	_rows(m)
	_crew_line(m)
	_promise_line(m)
	var room := Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(room)
	_keys()


## The head: the place's name in pen on the risk's baseline (.sh__tl: a 28
## line in 26), then under a named stop its kind in pen (a 20 line atop 26).
## No 「N 구간 정차」 kick over it: the route line says the stretch (결정 417).
func _head(m: Dictionary) -> void:
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
	var place := Paper.ink(String(m["place"]), UiFonts.HAND, 400, 31.0)
	place.name = "Place"
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(place)
	# The risk's own word (조용함 … 죽을 수 있음, 「?」 unscouted) at the name's
	# right is the line decisions.md keeps for everyone (결정 150); no 「위험」.
	var said: String = String(m["risk"])
	title.add_child(Paper.ink(said, UiFonts.NUMBER if said == "?" else UiFonts.WORD, 600, 18.0 if said == "?" else 13.0))
	if String(m["hint"]) == "":
		return
	var scene = TypeLine.new(20.0, 26.0)
	var hint := Paper.ink(String(m["hint"]), UiFonts.HAND, 400, 18.0)
	hint.name = "Scene"
	scene.add_child(hint)
	body.add_child(scene)


## A row (.frow, 46): its chips 6 apart. The chips say what the row is (the
## stocks, the stays with their cost, the cars and the count), so no question
## heads it (결정 417: no 「무엇을 · 얼마나 · 누구를」).
func _row() -> HBoxContainer:
	var h := Paper.line_box(46.0)
	h.add_theme_constant_override("separation", int(round(UiFonts.px(6.0))))
	body.add_child(h)
	return h


func _rows(m: Dictionary) -> void:
	var what := _row()
	for row: Dictionary in m["targets"]:
		var b := Paper.target_chip(String(row["word"]), bool(row["on"]), float(row["fill"]))
		b.name = "Target_" + String(row["id"])
		b.pressed.connect(pick.bind("target", row["id"]))
		what.add_child(b)
	var long := _row()
	for row: Dictionary in m["stays"]:
		var b := Paper.chip(String(row["word"]), bool(row["on"]), String(row["cost"]))
		b.name = "Stay_" + String(row["id"])
		b.pressed.connect(pick.bind("stay", row["id"]))
		long.add_child(b)
	var who := _row()
	# Four cars to send from where the mockup drew three: the chips close up a little.
	var pad: float = 12.0 if (m["crews"] as Array).size() <= 3 else 10.0
	for row: Dictionary in m["crews"]:
		var b := Paper.chip(String(row["word"]), bool(row["on"]), "", pad)
		b.name = "Crew_" + String(row["id"])
		b.pressed.connect(pick.bind("crewComm", row["id"]))
		who.add_child(b)
	# The stepper (.stepper, margin-left auto): 44 keys either side of the
	# count, which is 38 wide at least, its number on the unit's baseline.
	var stepper := HBoxContainer.new()
	stepper.name = "Stepper"
	stepper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stepper.add_theme_constant_override("separation", 0)
	stepper.alignment = BoxContainer.ALIGNMENT_END
	stepper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(stepper)
	var size: int = int(m["size"])
	stepper.add_child(_step_key("back", "한 명 덜", pick.bind("crewSize", size - 1)))
	var count = TypeLine.new(0.0, 0.0, 1.0)
	count.alignment = BoxContainer.ALIGNMENT_CENTER
	count.custom_minimum_size = Vector2(UiFonts.px(38.0), 0)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := Paper.ink(str(size), UiFonts.NUMBER, 500, 21.0, Paper.INK, 0.315)
	n.name = "CrewSize"
	count.add_child(n)
	count.add_child(Paper.ink("명", UiFonts.WORD, 500, 14.0))
	stepper.add_child(count)
	stepper.add_child(_step_key("fwd", "한 명 더", pick.bind("crewSize", size + 1)))


func _step_key(icon: String, says: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = says
	b.custom_minimum_size = Vector2(UiFonts.px(44.0), UiFonts.px(44.0))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var px: int = int(round(UiFonts.px(18.0)))
	b.icon = Paper.HudIcons.texture(icon, px, Color.WHITE, 2.4)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", px)
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, Paper.INK)
	var rest := StyleBoxEmpty.new()
	var down := StyleBoxFlat.new()
	down.bg_color = Paper.PRESS
	down.set_corner_radius_all(int(round(UiFonts.px(22.0))))
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, rest)
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, down)
	b.pressed.connect(cb)
	return b


## The crew line (.crewline, 22): the sent car's exposure before → after, the
## first two by their given names underlined (as the mockup's 요한, 미라), how
## many more, and that they miss the vote.
func _crew_line(m: Dictionary) -> void:
	var line := Paper.line_box(22.0)
	line.name = "CrewLine"
	line.add_theme_constant_override("separation", int(round(UiFonts.px(6.0))))
	line.add_child(Paper.mark("people", 16.0))
	var words = TypeLine.new(0.0, 22.0)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(words)
	# The car is the chip lit right over it (결정 417): no name again.
	words.add_child(_side("노출 "))
	var ex: Array = m["exposure"]
	words.add_child(_num("%d → %d" % [ex[0], ex[1]], 500, Paper.INK))
	var names: Array = m["names"]
	if not names.is_empty():
		words.add_child(_side(" · "))
		for i in names.size():
			if i > 0:
				words.add_child(_side(", "))
			words.add_child(Paper.name_word(String(names[i])))
		if int(m["more"]) > 0:
			words.add_child(_num(" +%d" % int(m["more"]), 400, Paper.INK2))
	# What sending them costs at the vote, in a word (결정 339 · 359).
	if bool(m["away"]):
		words.add_child(_side(" · 표결 빠짐"))
	body.add_child(line)


## The promise line (.promline, 24): what this stop was promised, and at its
## end the stamp when the pick already settles it.
func _promise_line(m: Dictionary) -> void:
	var said: String = ReceiptCard.promise_line(promises)
	if said == "":
		return
	var line := Paper.line_box(24.0)
	line.add_theme_constant_override("separation", int(round(UiFonts.px(6.0))))
	line.add_child(Paper.mark("promise", 16.0))
	var words = TypeLine.new(0.0, 24.0)
	words.name = "Promises"
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(words)
	# Its numbers in the number face, on the words' baseline (.promline .num).
	# The promise mark says what the line is (결정 417): no 「약속」 before it.
	for run: Array in _digit_runs(said.trim_prefix("약속: ")):
		words.add_child(_num(run[0], 400, Paper.INK) if run[1] else _side(run[0]))
	var st: Dictionary = promise_stamp(promises, String(m["comm"]), t)
	if not st.is_empty():
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(gap)
		var s := Paper.stamp(String(st["text"]), bool(st["off"]))
		s.name = "Stamp"
		line.add_child(s)
	body.add_child(line)


## The keys at the foot (.sh__act, 48): scout first and pass by as keys with
## no ring, the main key at the right.
func _keys() -> void:
	var foot := Paper.line_box(48.0)
	foot.add_theme_constant_override("separation", int(round(UiFonts.px(2.0))))
	body.add_child(foot)
	var scout := Paper.ghost("정찰 먼저", "eye")
	scout.name = "Scout"
	scout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiDeny.dim(scout, true)
	scout.pressed.connect(func() -> void:
		UiDeny.shake(scout)
		scout_asked.emit())
	foot.add_child(scout)
	var pass_key := Paper.ghost("지나치기")
	pass_key.name = "PassBy"
	pass_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pass_key.pressed.connect(func() -> void: passed_by.emit())
	foot.add_child(pass_key)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(fill)
	var go = LampKey.new("보내기")
	go.name = "Send"
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func() -> void: sent.emit(g))
	foot.add_child(go)


func _side(text: String) -> Label:
	var l := Paper.ink(text, UiFonts.WORD, 400, 12.0, Paper.INK2)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _num(text: String, weight: int, color: Color) -> Label:
	var l := Paper.ink(text, UiFonts.NUMBER, weight, 14.0, color, 0.21)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## `text` cut into runs of digits and of the rest: [[run, is_digits], …].
static func _digit_runs(text: String) -> Array:
	var out: Array = []
	var cur: String = ""
	var digits: bool = false
	for ch in text:
		var d: bool = ch >= "0" and ch <= "9"
		if cur != "" and d != digits:
			out.append([cur, digits])
			cur = ""
		cur += ch
		digits = d
	if cur != "":
		out.append([cur, digits])
	return out
