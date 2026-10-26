extends Control
## The special session (UI 3단계 시안 2차 k3c_views.js vCouncil, c3.css, B1; 05
## 의회): the dining car behind, softened and darkened; at the left the bill on a
## loose slip of paper (the agenda, what it needs, what it changes, and a pick
## between the agendas on the table); in the middle the seats
## (council_board.gd); at the right the groups on smoked glass, as a list of
## their yes · undecided · no or as the one picked (its leader, how it stands,
## its cohesion, what this agenda does to it). Along the bottom the way the
## train goes and the lever that calls the vote. Once pulled the stones turn,
## the verdict is stamped, the list shows each group's yes and no, and the lever
## stays down on 「확인」, which closes the session.
##
## Every number is the politics port's own, off the state it is given
## (council_vote.gd blocs · expected · agenda_need · agenda_title · cast_vote ·
## tool_status · make_deal, field_council.gd leave_special_council). The card
## changes its state only by the deals made on it (결정 426 PR 7): the picked
## group's pane has the mockup's tools in a row (six: 결정 433 adds 설득), the
## tool picked with its cost and why not or what it does, and 거래; 공개 협상
## asks which of its three conditions (and for 「칼질」 which car), and the
## seats a deal would bring ring on the board before it is made. The bill counts
## 「거래 n/3」 and holds its agenda once a deal is made. Tables without the
## deal tables (the field sample's) draw no tools.

signal left(g: Dictionary)

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const CouncilBoard = preload("res://game/ui/council_board.gd")
const HomeBar = preload("res://game/ui/home_bar.gd")
const CouncilVote = preload("res://game/politics/council_vote.gd")
const CouncilMath = preload("res://game/politics/council_math.gd")
const FieldCouncil = preload("res://game/politics/field_council.gd")
const PANE_TEX := preload("res://game/ui/tex/council_pane.png")
const BUSTS := preload("res://game/ui/tex/busts.png")
const PAPER_TEX := preload("res://game/ui/tex/paper.png")
const SHEET := preload("res://game/ui/paper_sheet.gdshader")
const BACK := preload("res://game/ui/council_back.gdshader")

## The mockup's frame (844 × 390) and where its parts stand in it: the bill off
## the left edge, the seats in the middle, the pane off the right edge.
const FRAME := Vector2(844, 390)
const BILL_AT := Vector2(8, 58)
const BILL_SIZE := Vector2(180, 268)
const BILL_TILT: float = -0.7
const BOARD_AT := Vector2(190, 52)
const PANE_SIZE := Vector2(256, 286)
const PANE_TOP: float = 48.0
## The middle of the space between the bands, where a narrow screen's smaller
## frame is centred.
const MID_Y: float = 192.0
## The bill's padding (7 12 8 16) and its title's room between the arrows.
const BILL_X0: float = 16.0
const BILL_X1: float = 168.0
const TITLE_X0: float = 46.0
const TITLE_X1: float = 136.0
## The title in the hand at 27 as the mockup's, smaller on one line, then on
## two, then three: [size, most lines] in the order tried.
const TITLE_FITS: Array = [[27, 1], [25, 1], [23, 1], [21, 1], [19, 1], [23, 2], [21, 2], [19, 2], [17, 2], [17, 3]]
## The most the bill grows to: down to the bottom band (336 in the frame).
const BILL_MAX_H: float = 274.0
## The pane's columns (their right ends, pane px) before and after the vote.
const COLS_BEFORE: Array = [182.0, 212.0, 242.0]
const COLS_AFTER: Array = [204.0, 242.0]
const PANE_X0: float = 30.0
const PANE_X1: float = 250.0

## s1/src/game/data.ts REP_ROLE · TRAIT_NAME; the relation words of the
## mockup's RELW (결정 293 ③: words, no 「~한다」).
const REP_ROLE: Dictionary = {"tail": "꼬리칸 대표", "medtech": "의무장", "guard": "경비대장", "front": "앞칸 대표", "engine": "수석 기관사"}
const TRAIT_NAME: Dictionary = {"greed": "탐욕", "ideal": "이상주의", "family": "가족", "fear": "겁", "ambition": "야심"}
const RELW: Dictionary = {
	"헌신": "열차장이 가는 곳이면 어디든", "지지": "열차장을 믿고 따름", "호의": "열차장에게 호의적, 아직은",
	"중립": "열차장을 지켜보는 중", "의심": "열차장에게 불만", "반대": "불만이 커져 대놓고 반대", "적대": "끌어내릴 틈만 보는 중",
}
## A group's situation in the order a law's mats change it (train_state.gd situation).
const STAT_WORD: Array = ["온기", "배급", "과밀", "노출"]
## The deal tools in the mockup's order (s1 ui/council.ts TOOLS; 설득 last, 결정
## 433): [id, the word under its medal, its name on the deal line].
const TOOLS: Array = [["open", "협상", "공개 협상"], ["favor", "부탁", "사적 부탁"], ["fetch", "조달", "현장 조달"],
	["bribe", "뇌물", "뇌물"], ["blackmail", "협박", "협박"], ["persuade", "설득", "설득"]]
## The tools' row (.tools: 6 under the cohesion, 54 high) and the deal line under it.
const TOOLS_Y: float = 148.0
const TOOL_H: float = 54.0
const DEAL_Y: float = 205.0
## What the pane asks after 거래 on 공개 협상: its conditions, then the car to cut.
enum Ask { TOOLS, CONDITIONS, CUT }

const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const INK3 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.54)
const HAIR := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.16)
const SKY := Color("8bd0f2")
const RED := Color("e2604b")
const AMBER := Color("f2a63c")
const FILL := Color("e4dfd2")
const PAPER := Color("cdc2a8")
const PINK := Color("231a12")
const PINK2 := Color(35 / 255.0, 26 / 255.0, 18 / 255.0, 0.72)
const RULE := Color(42 / 255.0, 32 / 255.0, 24 / 255.0, 0.16)
const PRESS := Color(242 / 255.0, 166 / 255.0, 60 / 255.0, 0.14)
const SOOT_CUT := Color("10151a")
## The picked tool's lamp (c1.css --lamp1..3), the ink on it, the 거래 pill (--fill, --face).
const LAMP: Array = [[0.0, Color("ffe2a0")], [0.6, Color("f6ab40")], [1.0, Color("c26f18")]]
const ON_INK := Color("2a1804")
const FACE := Color("1b2128")
const CHIP_Y: Array = [[0.0, Color("7db6ee")], [1.0, Color("3f86d4")]]
const CHIP_N: Array = [[0.0, Color("ec8371")], [1.0, Color("c94632")]]
## The room's dark before the vote and after it (c3.css .cnshade, #stage[data-res] .cnshade).
const SHADE_BEFORE: Dictionary = {"at": Vector2(0.47, 0.66), "radius": Vector2(0.64, 0.86), "mid": 0.62,
	"c0": Color(5 / 255.0, 7 / 255.0, 10 / 255.0, 0.6), "c1": Color(5 / 255.0, 7 / 255.0, 10 / 255.0, 0.5), "c2": Color(3 / 255.0, 4 / 255.0, 6 / 255.0, 0.9)}
const SHADE_AFTER: Dictionary = {"at": Vector2(0.46, 0.60), "radius": Vector2(0.54, 0.80), "mid": 0.58,
	"c0": Color(4 / 255.0, 6 / 255.0, 8 / 255.0, 0.42), "c1": Color(4 / 255.0, 6 / 255.0, 8 / 255.0, 0.74), "c2": Color(2 / 255.0, 3 / 255.0, 5 / 255.0, 0.93)}

var g: Dictionary = {}
var t: Dictionary = {}
## The agenda on the bill, the group picked in the pane (-1: the list).
var idx: int = 0
var sel: int = -1
## What the card shows now (model below), the count once cast and the state after it.
var m: Dictionary = {}
var result: Dictionary = {}
var voted: Dictionary = {}
var board: Control
var bar: Control
var frame: Control
var bill: Control
var pane: Control
## Where the bill's last row ends (bill px), for its paper to hold; how far
## its rows are scrolled when they are more than it holds, and the most.
var bill_bottom: float = 0.0
var bill_scroll: float = 0.0
var bill_scroll_max: float = 0.0
var _bill_parts: Control
## Where the bill's parts go (its rows while they are laid), the rows' window
## and the rows in it, where they start (bill px), and whether the rows are tight.
var _into: Control
var _rows_clip: Control
var _rows: Control
var _rows_top: float = 0.0
var _tight: bool = false
var _bill_reach: float = 0.0
var _pane_parts: Control
var _shade: ShaderMaterial
var _revealed: bool = false
## The tool picked in the pane, what the pane asks, the condition picked (for
## 「칼질」), and the last deal's word a group (make_deal's text).
var tool: String = ""
var ask: int = Ask.TOOLS
var cond_at: int = 0
var said: Dictionary = {}


## What the card says for agenda `at` of the session open in `g0` (tests read
## this; the card draws it). Empty when no session is open.
static func model(g0: Dictionary, t0: Dictionary, at: int) -> Dictionary:
	var council: Variant = g0.get("council")
	if t0.is_empty() or not council is Dictionary or (council.get("options", []) as Array).is_empty():
		return {}
	var options: Array = council["options"]
	var i: int = clampi(at, 0, options.size() - 1)
	var agenda: Dictionary = options[i]
	# The deals made stand on the council's own agenda (the bill holds it once one is made).
	var deals: Array = council.get("deals", []) if i == int(council.get("idx", 0)) else []
	var map: Dictionary = CouncilVote.blocs(g0, t0, agenda, deals)
	var ex: Dictionary = CouncilVote.expected(map, t0)
	var comms: Array = []
	var total: int = 0
	for c: String in t0["COMMS"]:
		var b: Dictionary = map[c]
		var s: Dictionary = g0["comms"][c]
		var lead: Dictionary = s.get("leader") if s.get("leader") is Dictionary else {}
		var stage: String = String(CouncilMath.stage_of(float(s["rel"]), t0["STAGES"]).get("name", ""))
		comms.append({
			"id": c, "name": String(t0["COMM_NAME"].get(c, c)), "seats": int(b["seats"]), "absent": int(b["absent"]),
			"yes": int(b["yes"]), "und": int(b["und"]), "no": int(b["no"]), "hard": int(b["hard"]), "score": int(b["score"]),
			"pool": int(b["pool"]),
			"stage": stage, "relw": String(RELW.get(stage, "")), "coh": int(round(float(s.get("coh", 0.0)) * 100.0)),
			"leader": String(lead.get("name", "")), "role": String(REP_ROLE.get(c, "")), "trait": trait_of(lead),
			"bust": bust_of(lead), "stance": stance_of(int(b["score"])), "stake": stake_of(t0, agenda, c),
		})
		total += int(b["seats"])
	var law: Dictionary = {}
	if agenda.get("kind") != "motion":
		law = (t0.get("LAWS", {}) as Dictionary).get(agenda.get("law"), {})
	var need: int = CouncilVote.agenda_need(t0, agenda)
	return {
		"comms": comms, "got": int(ex["min"]), "mean": int(round(float(ex["mean"]))), "max": int(ex["max"]),
		"need": need, "total": total, "title": CouncilVote.agenda_title(t0, agenda),
		"kind": "통치" if need > 51 else "일반", "secret": (g0.get("passed", {}) as Dictionary).has("secret_ballot"),
		"tag": String(law.get("tag", "")), "changes": change_rows(t0, agenda),
		"surprise": bool(council.get("emergency", false)), "special": bool(council.get("special", false)),
		"idx": i, "count": options.size(),
		"seg": int(g0.get("seg", 1)), "segments": int((t0.get("P", {}) as Dictionary).get("segments", 24)),
		"dealing": can_deal(t0), "deals": (council.get("deals", []) as Array).size(),
		"deal_max": int((t0.get("P", {}) as Dictionary).get("maxDealsPerSession", 3)),
	}


## Whether `t0` carries what the deals read (the turn tables do; the field sample's do not).
static func can_deal(t0: Dictionary) -> bool:
	var p: Dictionary = t0.get("P", {})
	for key: String in ["CONDITIONS", "COMMON_CONDITIONS", "FETCH_WANT", "OPPOSITE"]:
		if not t0.has(key):
			return false
	return p.has("persuadeBase") and p.has("blackmailTrust") and p.has("maxDealsPerSession")


## The state with agenda `at` the council's own (deals are made on it).
static func _on_agenda(g0: Dictionary, at: int) -> Dictionary:
	var gc: Dictionary = g0.duplicate(true)
	gc["council"]["idx"] = at
	return gc


## The deal tools for group `comm` on agenda `at`: {id, word, name, ok, why,
## cost, hint, red} each (council_vote.gd tool_status; the hint is what the
## mockup's deal line says it does, `red` its part in the accent).
static func tools_of(g0: Dictionary, t0: Dictionary, at: int, comm: String) -> Array:
	var gc := _on_agenda(g0, at)
	var agenda: Dictionary = gc["council"]["options"][at]
	var b: Dictionary = CouncilVote.blocs(gc, t0, agenda, gc["council"].get("deals", []))[comm]
	var brought: int = int(b["und"]) + int(b["no"]) - int(b["hard"])
	var coh: float = float(gc["comms"][comm].get("coh", 0.0))
	var out: Array = []
	for row: Array in TOOLS:
		var id: String = row[0]
		var st: Dictionary = CouncilVote.tool_status(gc, t0, comm, id)
		var hint: String = ""
		var red: String = ""
		match id:
			"open": hint = "조건 셋 중 하나 수락"
			"favor", "bribe": hint = "설득 가능 %d → 찬성 %d" % [brought, CouncilMath.round_half_up(float(brought) * coh)]
			"fetch":
				hint = "다음 정차까지 · 어기면 "
				red = "▼▼"
			"blackmail": hint = "쥔 비밀 하나 사용"
			"persuade": hint = "먹히면 미정 전부, 아니면 관계 −1"
		out.append({"id": id, "word": row[1], "name": row[2], "ok": bool(st["ok"]), "why": String(st.get("why", "")),
				"cost": String(st.get("cost", "")), "hint": hint, "red": red})
	return out


## Each seat's kind in group `comm` were deal `tool` made on agenda `at` (the board rings them).
static func kinds_after(g0: Dictionary, t0: Dictionary, at: int, comm: String, tool_id: String) -> Array:
	var gc := _on_agenda(g0, at)
	var agenda: Dictionary = gc["council"]["options"][at]
	var deals: Array = (gc["council"].get("deals", []) as Array).duplicate()
	deals.append({"comm": comm, "tool": tool_id, "label": ""})
	var b: Dictionary = CouncilVote.blocs(gc, t0, agenda, deals)[comm]
	return CouncilBoard.kinds_before({"seats": int(b["seats"]), "yes": int(b["yes"]), "und": int(b["und"]),
			"pool": int(b["pool"]), "no": int(b["no"]), "hard": int(b["hard"])})


## The bill's lines for `agenda`: [label, word, number] each, the number "" when
## the line has none. A law's lines are its own (LAWS changes), each split where
## its number is (「기관실·경비대 배급 +10」 → 기관실·경비대 · 배급 +10; a step a
## stretch, 「+1.5/구간」, reads 구간마다 +1.5); a motion's are what passing and
## failing do (s1 field_council.ts changes, off FIELD).
static func change_rows(t0: Dictionary, agenda: Dictionary) -> Array:
	var out: Array = []
	if agenda.get("kind") == "motion":
		var f: Dictionary = t0.get("FIELD", {})
		var name: String = String((t0.get("COMM_NAME", {}) as Dictionary).get(agenda.get("subject"), "그 칸"))
		if agenda.get("motion") == "field_symbol":
			out.append(["가결", name + " 관계", sign_of(float(f.get("symbolRel", 0)))])
			out.append(["부결", name + " 관계", sign_of(-float(f.get("symbolRel", 0)))])
		elif agenda.get("verdict") == "kept":
			out.append(["가결", "신임", sign_of(float(f.get("promiseTrust", 0)))])
			out.append(["부결", "바뀌는 것 없음", ""])
		else:
			out.append(["가결", "신임", sign_of(-float(f.get("promiseTrust", 0)))])
			out.append(["가결", name + " 관계", sign_of(float(f.get("promiseRel", 0)))])
			out.append(["부결", name + " 관계", sign_of(-float(f.get("promiseRel", 0)))])
		return out
	var law: Dictionary = (t0.get("LAWS", {}) as Dictionary).get(agenda.get("law"), {})
	for line in law.get("changes", []):
		out.append(split_change(String(line)))
	return out


## One of a law's change lines as [label, word, number], split only where the
## line is one change (the mockup's bill: 「기관실·경비대 배급 +10」 → 기관실·경비대 ·
## 배급 +10, 「식량 +1.5/구간 절약」 → 식량 절약 · 구간마다 +1.5, 「식량 +30(한 번)」 →
## 식량 · 한 번 +30); any other line stays whole, [line, "", ""].
static func split_change(line: String) -> Array:
	var words: PackedStringArray = line.split(" ", false)
	var n: int = words.size()
	var change := RegEx.create_from_string("^[+\\-−×][0-9.]+%?$")
	var step := RegEx.create_from_string("^([+\\-−]?[0-9.]+)/구간$")
	var once := RegEx.create_from_string("^([+\\-−][0-9.]+)\\(한$")
	var digit := RegEx.create_from_string("[0-9]")
	var numbers: int = 0
	for w in words:
		if digit.search(w) != null:
			numbers += 1
	if numbers != 1:
		return [line, "", ""]
	if n >= 2 and change.search(words[n - 1]) != null:
		if n == 2:
			return [words[0], "", words[1]]
		return [" ".join(words.slice(0, n - 2)), words[n - 2], words[n - 1]]
	for tail in [0, 1]:
		var at: int = n - 1 - tail
		if at < 1:
			continue
		var hit: RegExMatch = step.search(words[at])
		if hit != null:
			var label: PackedStringArray = words.slice(0, at)
			if tail == 1:
				label.append(words[n - 1])
			return [" ".join(label), "구간마다", hit.get_string(1)]
	if n >= 3 and words[n - 1] == "번)":
		var hit: RegExMatch = once.search(words[n - 2])
		if hit != null:
			return [" ".join(words.slice(0, n - 2)), "한 번", hit.get_string(1)]
	return [line, "", ""]


## What agenda `agenda` does to group `comm` itself: [when, what] rows (a law's
## mats and rels for it; a motion's relation for the group it names).
static func stake_of(t0: Dictionary, agenda: Dictionary, comm: String) -> Array:
	var f: Dictionary = t0.get("FIELD", {})
	if agenda.get("kind") == "motion":
		if agenda.get("subject") != comm:
			return []
		if agenda.get("motion") == "field_symbol":
			return [["가결되면", "관계 " + sign_of(float(f.get("symbolRel", 0)))], ["부결되면", "관계 " + sign_of(-float(f.get("symbolRel", 0)))]]
		if agenda.get("verdict") == "kept":
			return []
		return [["가결되면", "관계 " + sign_of(float(f.get("promiseRel", 0)))], ["부결되면", "관계 " + sign_of(-float(f.get("promiseRel", 0)))]]
	var law: Dictionary = (t0.get("LAWS", {}) as Dictionary).get(agenda.get("law"), {})
	var parts: PackedStringArray = []
	var mats: Variant = (law.get("mats", {}) as Dictionary).get(comm)
	if mats is Array:
		for i in mini(4, (mats as Array).size()):
			if float(mats[i]) != 0.0:
				parts.append("%s %s" % [STAT_WORD[i], sign_of(float(mats[i]))])
	var rel: Variant = (law.get("rels", {}) as Dictionary).get(comm)
	if rel != null and float(rel) != 0.0:
		parts.append("관계 " + sign_of(float(rel)))
	return [["가결되면", " · ".join(parts)]] if not parts.is_empty() else []


## How a stance score reads (s1 ui/names.ts agendaLine's steps; the mockup's
## STANCE words): [y | n | "", word].
static func stance_of(score: int) -> Array:
	if score >= 2:
		return ["y", "찬성"]
	if score >= 1:
		return ["y", "찬성 쪽"]
	if score <= -2:
		return ["n", "반대"]
	if score <= -1:
		return ["n", "반대 쪽"]
	return ["", "망설임"]


## A leader's nature as far as it shows (s1 ui/council.ts): hidden, a guess, or known.
static func trait_of(lead: Dictionary) -> String:
	var shown: int = int(lead.get("traitShown", 0))
	var word: String = String(TRAIT_NAME.get(lead.get("trait", ""), ""))
	if shown <= 0 or word == "":
		return "성향 가려짐"
	return "아마 " + word if shown == 1 else word


## Which of the six ink busts (tex/busts.png, the mockup's inkBust heads) a
## leader wears, off their person's id so it stays the same.
static func bust_of(lead: Dictionary) -> int:
	var id: String = String(lead.get("personId", lead.get("name", "")))
	var n: int = 0
	for i in id.length():
		n += id.unicode_at(i)
	return n % 6


## A change as the bill writes it: +5, −5 (a true minus), +1.5.
static func sign_of(v: float) -> String:
	var a: float = absf(v)
	var s: String = str(int(a)) if is_equal_approx(a, roundf(a)) else str(snappedf(a, 0.1))
	return ("+" if v >= 0.0 else "−") + s


func _ready() -> void:
	name = "CouncilCard" if name == "" else name
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_back()
	frame = Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_build_bill()
	board = CouncilBoard.new()
	board.name = "Board"
	board.picked.connect(_pick)
	board.revealed.connect(_on_revealed)
	frame.add_child(board)
	_build_pane()
	bar = HomeBar.new()
	bar.name = "HomeBar"
	bar.g = {}
	bar.lever = true
	# The lever's own shape and pull say how (결정 417: no 「당겨 내리기」).
	bar.lever_small = ""
	bar.main_word = "표결"
	bar.main_pressed.connect(_on_main)
	m = model(g, t, idx)
	bar.route = {"seg": int(m.get("seg", 1)), "total": int(m.get("segments", 24)), "phase": "의회", "km": -1.0}
	add_child(bar)
	resized.connect(_lay_out)
	_show()
	_lay_out()


## The dining car behind, softened and darkened, in a layer of its own under
## the screen's keys so it reads only the train (council_back.gdshader).
func _build_back() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Back"
	layer.layer = 39
	add_child(layer)
	var r := ColorRect.new()
	r.name = "Shade"
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade = ShaderMaterial.new()
	_shade.shader = BACK
	_set_shade(SHADE_BEFORE)
	r.material = _shade
	layer.add_child(r)


func _set_shade(s: Dictionary) -> void:
	for key in ["at", "radius", "mid"]:
		_shade.set_shader_parameter(key, s[key])
	for key in ["c0", "c1", "c2"]:
		var c: Color = s[key]
		_shade.set_shader_parameter(key, Vector4(c.r, c.g, c.b, c.a))


## The frame at the mockup's size, smaller on a screen narrower than it (centred
## between the bands); on a wider one the pane keeps to the right edge and the
## seats to the middle.
func _lay_out() -> void:
	if frame == null:
		return
	var k: float = UiFonts.K
	var w: float = size.x / k
	var s: float = minf(1.0, w / FRAME.x)
	var extra: float = maxf(0.0, w - FRAME.x)
	frame.scale = Vector2(s, s)
	frame.position = Vector2(0.0, MID_Y * (1.0 - s)) * k
	frame.size = Vector2(FRAME.x + extra, FRAME.y) * k
	bill.position = BILL_AT * k
	board.position = Vector2(BOARD_AT.x + extra * 0.5, BOARD_AT.y) * k
	pane.position = Vector2(FRAME.x + extra - PANE_SIZE.x, PANE_TOP) * k


## Draw the session as it stands: the bill, the seats, the pane.
func _show() -> void:
	m = model(g, t, idx)
	if m.is_empty():
		return
	_fill_bill()
	board.show_model(m)
	board.select(sel)
	_fill_pane()


## Another agenda on the bill (the arrows), before the vote and before any deal.
func turn(step: int) -> void:
	if not result.is_empty() or m.is_empty() or int(m.get("deals", 0)) > 0:
		return
	var to: int = clampi(idx + step, 0, int(m["count"]) - 1)
	if to == idx:
		return
	idx = to
	bill_scroll = 0.0
	_show()


## Pick group `gi` (-1: back to the list), before the vote: its tools open on
## the first it can use.
func _pick(gi: int) -> void:
	if not result.is_empty():
		return
	sel = gi
	ask = Ask.TOOLS
	tool = ""
	if sel >= 0 and bool(m.get("dealing", false)):
		var tools: Array = tools_of(g, t, idx, String(m["comms"][sel]["id"]))
		tool = String(tools[0]["id"])
		for tl: Dictionary in tools:
			if bool(tl["ok"]):
				tool = String(tl["id"])
				break
	board.select(sel)
	_fill_pane()


## A tool picked in the pane: its line and the seats it would bring.
func _pick_tool(id: String) -> void:
	tool = id
	ask = Ask.TOOLS
	_fill_pane()


## 거래: a 공개 협상 asks its condition first; any other is made now.
func _deal_pressed() -> void:
	if sel < 0 or not result.is_empty():
		return
	if tool == "open":
		ask = Ask.CONDITIONS
		_fill_pane()
	else:
		_make(tool, 0, "")


## A condition of the 공개 협상 picked: 「칼질」 asks which car, the rest are made.
func _cond_pressed(i: int) -> void:
	var conds: Array = CouncilVote.open_conditions(_on_agenda(g, idx), t, String(m["comms"][sel]["id"]))
	if i < conds.size() and conds[i]["kind"] == "cut":
		cond_at = i
		ask = Ask.CUT
		_fill_pane()
	else:
		_make("open", i, "")


func _cut_pressed(target: String) -> void:
	_make("open", cond_at, target)


## Make the deal on the agenda on the bill (make_deal off the state as given)
## and draw the session again.
func _make(tool_id: String, cond_index: int, cut_target: String) -> void:
	var comm: String = String(m["comms"][sel]["id"])
	var r: Dictionary = CouncilVote.make_deal(_on_agenda(g, idx), t, comm, tool_id, cond_index, cut_target)
	g = r["g"]
	said[comm] = String(r["text"])
	ask = Ask.TOOLS
	_show()


## 접기: from a condition back to the tools, from the tools back to the list.
func _fold_pressed() -> void:
	if ask != Ask.TOOLS:
		ask = Ask.TOOLS
		_fill_pane()
	else:
		_pick(-1)


## The lever: pulled, the vote is cast; down on 「확인」, the session closes.
func _on_main() -> void:
	if result.is_empty():
		cast()
	else:
		close()


## Cast the vote on the agenda on the bill (cast_vote off the state as given).
func cast() -> void:
	if not result.is_empty() or m.is_empty():
		return
	var gi: Dictionary = g.duplicate(true)
	gi["council"]["idx"] = idx
	var out: Dictionary = CouncilVote.cast_vote(gi, t)
	if not out.get("result") is Dictionary:
		return
	result = out["result"]
	voted = out["g"]
	sel = -1
	_revealed = false
	board.play(result)
	_set_shade(SHADE_AFTER)
	# The bill steps back while the room counts (#stage[data-res] .bill: opacity .5, saturate .5, brightness .8).
	bill.modulate = Color(0.8, 0.79, 0.77, 0.5)
	bar.set_main("확인", "", true)
	_fill_bill()
	_fill_pane()


## Close the session (field_council.gd leave_special_council) and hand on the state it leaves.
func close() -> void:
	if result.is_empty():
		return
	if board.revealing():
		board.finish_reveal()
	var out: Dictionary = FieldCouncil.leave_special_council(voted, t)
	left.emit(out["g"])


func _on_revealed() -> void:
	_revealed = true
	_fill_pane()


## A tap while the stones turn shows the count at once.
func _gui_input(e: InputEvent) -> void:
	var down: bool = (e is InputEventMouseButton and e.is_pressed()) or (e is InputEventScreenTouch and e.is_pressed())
	if down and is_instance_valid(board) and board.revealing():
		board.finish_reveal()
		accept_event()


# ── the bill ──────────────────────────────────────────────────────────────

## A loose slip of paper, tilted −0.7°, its drop shadow under it
## (c3.css .bill: drop-shadow(4px 6px 10px rgba(0,0,0,.62))).
func _build_bill() -> void:
	var k: float = UiFonts.K
	bill = Control.new()
	bill.name = "Bill"
	bill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bill.size = BILL_SIZE * k
	bill.pivot_offset = bill.size * 0.5
	bill.rotation = deg_to_rad(BILL_TILT)
	frame.add_child(bill)
	var sigma: float = 5.0 * k
	var reach: float = sigma * 3.0
	_bill_reach = reach
	var sh := ColorRect.new()
	sh.name = "Shadow"
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.material = _sheet_material(true, reach, sigma)
	sh.position = Vector2(4.0, 6.0) * k - Vector2(reach, reach)
	sh.size = bill.size + Vector2(reach, reach) * 2.0
	bill.add_child(sh)
	var paper := ColorRect.new()
	paper.name = "Paper"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.material = _sheet_material(false, 0.0, 0.0)
	paper.size = bill.size
	bill.add_child(paper)
	_bill_parts = Control.new()
	_bill_parts.name = "Parts"
	_bill_parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bill_parts.size = bill.size
	bill.add_child(_bill_parts)
	_into = _bill_parts


## The paper's shader as a loose slip: no side bands, no fold, no torn edge.
func _sheet_material(is_shadow: bool, reach: float, sigma: float) -> ShaderMaterial:
	var k: float = UiFonts.K
	var mat := ShaderMaterial.new()
	mat.shader = SHEET
	mat.set_shader_parameter("paper_tex", PAPER_TEX)
	mat.set_shader_parameter("sheet_size", BILL_SIZE * k)
	mat.set_shader_parameter("tile", 240.0 * k)
	mat.set_shader_parameter("cut", 0.0)
	mat.set_shader_parameter("tear", Vector2(1.0, 240.0 * k))
	mat.set_shader_parameter("paper", Vector4(PAPER.r, PAPER.g, PAPER.b, 1.0))
	mat.set_shader_parameter("bands", false)
	mat.set_shader_parameter("fold", false)
	mat.set_shader_parameter("shadow", is_shadow)
	mat.set_shader_parameter("reach", reach)
	mat.set_shader_parameter("sigma", sigma)
	mat.set_shader_parameter("shadow_alpha", 0.62)
	return mat


## The bill's words (c3.css .bill__kick · __nav · __tags · __ch); a law of
## many lines sets them tight, and the paper grows to hold them.
func _fill_bill() -> void:
	_tight = false
	_lay_bill()
	if bill_bottom + 8.0 + _foot_h() > BILL_MAX_H:
		_tight = true
		_lay_bill()
	_fit_bill()


func _lay_bill() -> void:
	for c in _bill_parts.get_children():
		_bill_parts.remove_child(c)
		c.queue_free()
	var k: float = UiFonts.K
	# The kick: 「특별」 when the session is a special one (결정 303), and which
	# agenda of how many by the arrows' count; the stretch and 「의회」 are on
	# the route line under it (결정 417: no 「6구간 회기」, no 「안건」).
	var of_n := _ink("%d/%d" % [int(m["idx"]) + 1, int(m["count"])], UiFonts.NUMBER, 400, 14.0, PINK, 0.28)
	_on_bill(of_n)
	GlassParts.put(of_n, BILL_X0, 7.0, 17.0)
	var base: float = GlassParts.base_of(of_n)
	of_n.position.x = BILL_X1 * k - GlassParts.text_w(of_n)
	if bool(m["special"]):
		var kick := _ink("특별", UiFonts.WORD, 400, 12.0, PINK2, 1.2)
		_on_bill(kick)
		GlassParts.put_on(kick, BILL_X0 * k, base)
	# The title between the arrows, in the hand, as large as fits in two lines
	# (three at the smallest); the row grows with it.
	var title := _ink(UiFonts.keep_all(String(m["title"])), UiFonts.HAND, 400, 27.0, PINK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var room: float = (TITLE_X1 - TITLE_X0) * k
	var lines: int = 1
	var css: float = 27.0
	for fit: Array in TITLE_FITS:
		css = float(fit[0])
		title.add_theme_font_size_override("font_size", UiFonts.size(css))
		lines = _lines_of(title, room)
		if lines <= int(fit[1]):
			break
	# The hand's own line is tall; lines of a long title sit an em apart.
	var font: Font = title.get_theme_font("font")
	var fs: int = title.get_theme_font_size("font_size")
	var line_h: float = font.get_height(fs) if lines == 1 else css * k
	if lines > 1:
		title.add_theme_constant_override("line_spacing", int(round(line_h - font.get_height(fs))))
	var nav_h: float = maxf(44.0, (line_h * float(lines)) / k + 6.0)
	title.custom_minimum_size = Vector2(room, 0.0)
	title.size = Vector2(room, line_h * float(lines))
	title.position = Vector2(TITLE_X0 * k, (24.0 + nav_h * 0.5) * k - title.size.y * 0.5)
	_on_bill(title)
	# The agenda holds once a deal is made on it (the deals stand on it).
	var after: bool = not result.is_empty() or int(m.get("deals", 0)) > 0
	_on_bill(_arrow("back", Vector2(2.0, 24.0 + nav_h * 0.5 - 22.0), -1, after or int(m["idx"]) <= 0))
	_on_bill(_arrow("fwd", Vector2(136.0, 24.0 + nav_h * 0.5 - 22.0), 1, after or int(m["idx"]) >= int(m["count"]) - 1))
	# The tags: what it needs, open or secret, the law's own word.
	var y: float = 24.0 + nav_h
	var x: float = BILL_X0
	var need_w := _ink(String(m["kind"]), UiFonts.WORD, 400, 12.0, PINK2, 0.72)
	_on_bill(need_w)
	GlassParts.put(need_w, x, y, 20.0)
	var tbase: float = GlassParts.base_of(need_w)
	x += GlassParts.text_w(need_w) / k + 3.0
	var need_n := _ink(str(int(m["need"])), UiFonts.NUMBER, 600, 15.0, PINK, 0.0)
	_on_bill(need_n)
	GlassParts.put_on(need_n, x * k, tbase)
	x += GlassParts.text_w(need_n) / k + 10.0
	var eye := _icon("secret" if bool(m["secret"]) else "eye", 14.0, PINK2)
	eye.position = Vector2(x, y + 3.0) * k
	_on_bill(eye)
	# Open or secret by its eye alone (decisions.md 의회 화면 「공개·비밀 표시」,
	# 결정 417: no word).
	x += 14.0 + 10.0
	if String(m["tag"]) != "":
		_on_bill(_chip(String(m["tag"]), Vector2(x, y)))
	var rule_y: float = y + 20.0 + 8.0
	_bill_rule(rule_y, false)
	# The changes, one a row, each on the dotted line under it, in a window of
	# their own (laid in the bill's px) that scrolls when they are more than it holds.
	_rows_top = rule_y + 2.0
	_rows_clip = Control.new()
	_rows_clip.name = "Rows"
	_rows_clip.clip_contents = true
	_rows_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_clip.position = Vector2(0.0, _rows_top) * k
	_rows_clip.gui_input.connect(_rows_input)
	_bill_parts.add_child(_rows_clip)
	_rows = Control.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_clip.add_child(_rows)
	_into = _rows
	var ry: float = _rows_top + (3.0 if _tight else 5.0)
	for row: Array in m["changes"]:
		ry = _change_row(row, ry)
	_into = _bill_parts
	bill_bottom = ry


## The paper as tall as the rows (the mockup's 268 at least, down to the band
## at most); rows past that scroll, a fade of the paper over the last.
func _fit_bill() -> void:
	var k: float = UiFonts.K
	var foot: float = _foot_h()
	var h: float = clampf(bill_bottom + 8.0 + foot, BILL_SIZE.y, BILL_MAX_H)
	var sheet := Vector2(BILL_SIZE.x, h) * k
	bill.size = sheet
	bill.pivot_offset = sheet * 0.5
	_bill_parts.size = sheet
	var paper := bill.get_node("Paper") as ColorRect
	paper.size = sheet
	(paper.material as ShaderMaterial).set_shader_parameter("sheet_size", sheet)
	var sh := bill.get_node("Shadow") as ColorRect
	sh.size = sheet + Vector2(_bill_reach, _bill_reach) * 2.0
	(sh.material as ShaderMaterial).set_shader_parameter("sheet_size", sheet)
	var view: float = h - 8.0 - foot - _rows_top
	_rows_clip.size = Vector2(BILL_SIZE.x, view) * k
	bill_scroll_max = maxf(0.0, bill_bottom - (h - 8.0 - foot))
	bill_scroll = clampf(bill_scroll, 0.0, bill_scroll_max)
	_rows_clip.mouse_filter = Control.MOUSE_FILTER_STOP if bill_scroll_max > 0.0 else Control.MOUSE_FILTER_IGNORE
	if bill_scroll_max > 0.0:
		var fade := Control.new()
		fade.name = "Fade"
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.position = Vector2(0.0, h - 8.0 - foot - 24.0) * k
		fade.size = Vector2(BILL_SIZE.x, 24.0) * k
		fade.draw.connect(func() -> void:
			var c0 := Color(PAPER, 0.0)
			var c1 := Color(PAPER, 0.94)
			fade.draw_polygon(PackedVector2Array([Vector2(BILL_X0 * k, 0.0), Vector2(BILL_X1 * k, 0.0),
					Vector2(BILL_X1 * k, fade.size.y), Vector2(BILL_X0 * k, fade.size.y)]),
					PackedColorArray([c0, c0, c1, c1]))
			# A small chevron down at its middle: there is more under it.
			var cx: float = fade.size.x * 0.5
			var cy: float = fade.size.y - 7.0 * k
			fade.draw_polyline(PackedVector2Array([Vector2(cx - 5.0 * k, cy - 3.0 * k), Vector2(cx, cy + 2.0 * k),
					Vector2(cx + 5.0 * k, cy - 3.0 * k)]), PINK2, 1.8 * k, true))
		_bill_parts.add_child(fade)
	if foot > 0.0:
		_bill_foot(h)
	_place_rows()


## Room under the rows for 「거래 n/3」 when deals are made here.
func _foot_h() -> float:
	return 26.0 if bool(m.get("dealing", false)) else 0.0


## 「거래 n/3」 at the bill's foot (.bill__foot: 16 in, 9 up; the word 12 spaced,
## the count 16 · 600, a ring 11 across a deal, filled when made).
func _bill_foot(h: float) -> void:
	var k: float = UiFonts.K
	var made: int = int(m.get("deals", 0))
	var most: int = int(m.get("deal_max", 3))
	var top: float = h - 9.0 - 20.0
	var word := _ink("거래", UiFonts.WORD, 400, 12.0, PINK2, 1.44)
	word.name = "DealsWord"
	_bill_parts.add_child(word)
	GlassParts.put(word, BILL_X0, top, 20.0)
	var n := _ink("%d/%d" % [made, most], UiFonts.NUMBER, 600, 16.0, PINK, 0.32)
	n.name = "Deals"
	_bill_parts.add_child(n)
	GlassParts.put_on(n, word.position.x + GlassParts.text_w(word) + 6.0 * k, GlassParts.base_of(word))
	var pips := Control.new()
	pips.name = "DealPips"
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.position = Vector2(BILL_X1 + 1.0 - 11.0 * float(most) - 6.0 * float(most - 1), top + 4.5) * k
	pips.size = Vector2(17.0 * float(most), 11.0) * k
	pips.draw.connect(func() -> void:
		for i in most:
			var c := Vector2((5.5 + 17.0 * float(i)) * k, 5.5 * k)
			if i < made:
				pips.draw_circle(c, 5.5 * k, PINK2, true, -1.0, true)
			pips.draw_arc(c, 4.5 * k, 0.0, TAU, 24, RULE * Color(1, 1, 1, 2.25), 2.0 * k, true))
	_bill_parts.add_child(pips)


func _place_rows() -> void:
	_rows.position = Vector2(0.0, -_rows_top - bill_scroll) * UiFonts.K
	var fade := _bill_parts.get_node_or_null("Fade") as Control
	if fade:
		fade.visible = bill_scroll < bill_scroll_max - 0.5


## A drag or the wheel over the rows scrolls them, when there are more than show.
func _rows_input(e: InputEvent) -> void:
	var dy: float = 0.0
	if e is InputEventMouseButton and e.is_pressed():
		var b := e as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dy = 24.0
		elif b.button_index == MOUSE_BUTTON_WHEEL_UP:
			dy = -24.0
	elif e is InputEventScreenDrag:
		dy = -(e as InputEventScreenDrag).relative.y / UiFonts.K
	elif e is InputEventMouseMotion and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		dy = -(e as InputEventMouseMotion).relative.y / UiFonts.K
	if dy == 0.0 or bill_scroll_max <= 0.0:
		return
	bill_scroll = clampf(bill_scroll + dy, 0.0, bill_scroll_max)
	_place_rows()
	_rows_clip.accept_event()


## One change row from `top` (bill px): its label at the left, its word and
## number at the right on one baseline; a line with no number wraps across.
## Returns where the next row starts.
func _change_row(row: Array, top: float) -> float:
	var k: float = UiFonts.K
	# Tight: the words 12 and 17 a line, 3 above and under, a row 28.
	var pad: float = 3.0 if _tight else 5.0
	var step: float = 17.0 if _tight else 22.0
	var label := _ink(String(row[0]), UiFonts.WORD, 400, 12.0 if _tight else 12.5, PINK2, 0.0)
	_on_bill(label)
	if String(row[1]) == "" and String(row[2]) == "":
		label.text = UiFonts.keep_all(String(row[0]))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var w: float = (BILL_X1 - BILL_X0) * k
		var n: int = _lines_of(label, w)
		label.custom_minimum_size = Vector2(w, 0.0)
		label.size = Vector2(w, step * k * n)
		label.add_theme_constant_override("line_spacing", int(round(step * k - label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")))))
		label.position = Vector2(BILL_X0, top + pad) * k
		var h: float = pad + step * float(n) + pad - 1.0
		_bill_rule(top + h - 2.0, true)
		return top + h
	var word := _ink(String(row[1]), UiFonts.WORD, 500, 13.0, PINK, 0.0)
	_on_bill(word)
	var has_num: bool = String(row[2]) != ""
	var num := _ink(String(row[2]), UiFonts.NUMBER, 600, 18.0, PINK, 0.0)
	if has_num:
		_on_bill(num)
	var right_w: float = GlassParts.text_w(word)
	if has_num:
		right_w += GlassParts.text_w(num) + (5.0 * k if String(row[1]) != "" else 0.0)
	var h: float = 28.0 if _tight else 31.0
	var line_top: float = top + pad
	if GlassParts.text_w(label) > (BILL_X1 - BILL_X0) * k - right_w - 6.0 * k:
		# A label too long for the row takes the row's width, the change under it at the right.
		var w: float = (BILL_X1 - BILL_X0) * k
		label.text = UiFonts.keep_all(String(row[0]))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var n: int = _lines_of(label, w)
		label.custom_minimum_size = Vector2(w, 0.0)
		var lh: float = 16.0 if _tight else 18.0
		label.size = Vector2(w, lh * k * n)
		label.add_theme_constant_override("line_spacing", int(round(lh * k - label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")))))
		label.position = Vector2(BILL_X0, top + pad + 1.0) * k
		line_top = top + pad + 1.0 + lh * float(n) - 2.0
		h = line_top + 22.0 + pad - 1.0 - top
	GlassParts.put(word, 0.0, line_top, 22.0)
	var base: float = GlassParts.base_of(word)
	var x1: float = BILL_X1 * k
	if has_num:
		GlassParts.put_on(num, x1 - GlassParts.text_w(num), base)
		x1 = num.position.x - 1.0 * k - (4.0 * k if String(row[1]) != "" else 0.0)
	else:
		num.free()
	GlassParts.put_on(word, x1 - GlassParts.text_w(word), base)
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		GlassParts.put_on(label, BILL_X0 * k, base)
	_bill_rule(top + h - 2.0, true)
	return top + h


## A rule across the bill at `y` (bill px): solid under the tags, dotted under a change.
func _bill_rule(y: float, dotted: bool) -> void:
	var k: float = UiFonts.K
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(BILL_X0, y) * k
	c.size = Vector2(BILL_X1 - BILL_X0, 2.0) * k
	c.draw.connect(func() -> void:
		if not dotted:
			c.draw_rect(Rect2(Vector2.ZERO, c.size), RULE)
			return
		# 2px dotted: round dots 2 across, 4 apart.
		var step: float = 4.0 * k
		var r: float = 1.0 * k
		var x: float = r
		while x < c.size.x:
			c.draw_circle(Vector2(x, r), r, RULE, true, -1.0, true)
			x += step)
	_on_bill(c)


## The law's word on the paper (.tg--harsh: ink ground, paper letters, 20 high, 7 in).
func _chip(word: String, at: Vector2) -> Control:
	var k: float = UiFonts.K
	var l := _ink(word, UiFonts.WORD, 500, 12.0, PAPER, 1.44)
	var w: float = GlassParts.text_w(l) / k - 1.44 + 14.0
	var c := Control.new()
	c.name = "Tag"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = at * k
	c.size = Vector2(w, 20.0) * k
	c.draw.connect(func() -> void: GlassParts.round_rect(c, Rect2(Vector2.ZERO, c.size), 2.0 * k, PINK))
	c.add_child(l)
	GlassParts.put(l, 7.0, 0.0, 20.0)
	return c


## An arrow key on the bill, 44 across (.bill__nav button: an 18 icon, 2.4 thick).
func _arrow(icon: String, at: Vector2, step: int, off: bool) -> Button:
	var k: float = UiFonts.K
	var b := Button.new()
	b.name = "Prev" if step < 0 else "Next"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.position = at * k
	b.size = Vector2(44.0, 44.0) * k
	b.disabled = off
	b.mouse_filter = Control.MOUSE_FILTER_STOP if not off else Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(turn.bind(step))
	var ic := _icon(icon, 18.0, Color(PINK2, 0.24) if off else PINK2, 2.4)
	ic.position = Vector2(13.0, 13.0) * k
	b.add_child(ic)
	return b


func _on_bill(c: Control) -> void:
	_into.add_child(c)


# ── the pane ──────────────────────────────────────────────────────────────

## The smoked glass at the right (tex/council_pane.png, the mockup's paneCanvas).
func _build_pane() -> void:
	var k: float = UiFonts.K
	pane = Control.new()
	pane.name = "Pane"
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.size = PANE_SIZE * k
	frame.add_child(pane)
	var glass := TextureRect.new()
	glass.name = "Glass"
	glass.texture = PANE_TEX
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.stretch_mode = TextureRect.STRETCH_SCALE
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.size = pane.size
	pane.add_child(glass)
	_pane_parts = Control.new()
	_pane_parts.name = "Parts"
	_pane_parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pane_parts.size = pane.size
	pane.add_child(_pane_parts)


func _fill_pane() -> void:
	for c in _pane_parts.get_children():
		_pane_parts.remove_child(c)
		c.queue_free()
	if m.is_empty():
		return
	if not result.is_empty() and _revealed:
		_results()
	elif sel >= 0 and result.is_empty():
		_detail(m["comms"][sel])
	else:
		_list(not result.is_empty())


## The groups, a row each: name and seats, then yes · undecided · no; a row
## picks its group (not while the count is on).
func _list(counting: bool) -> void:
	var k: float = UiFonts.K
	board.preview(-1)
	# The columns' words only, no 「집단별 표」 over them (결정 417).
	_head("", [["찬성", SKY], ["미정", INK2], ["반대", RED]], COLS_BEFORE)
	var comms: Array = m["comms"]
	for i in comms.size():
		var c: Dictionary = comms[i]
		var top: float = 42.0 + 44.0 * float(i)
		if not counting:
			var b := Button.new()
			b.name = "Row_" + String(c["id"])
			b.flat = true
			b.focus_mode = Control.FOCUS_NONE
			for state in ["normal", "hover", "focus", "disabled"]:
				b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			var press := StyleBoxFlat.new()
			press.bg_color = PRESS
			b.add_theme_stylebox_override("pressed", press)
			b.add_theme_stylebox_override("hover_pressed", press)
			b.position = Vector2(PANE_X0, top) * k
			b.size = Vector2(PANE_X1 - PANE_X0, 44.0) * k
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.pressed.connect(_pick.bind(i))
			_on_pane(b)
		var base: float = _row_name(c, top, 44.0)
		_num(str(int(c["yes"])), 500, SKY, COLS_BEFORE[0], base)
		_num(str(int(c["und"])), 400, INK2, COLS_BEFORE[1], base)
		_num(str(int(c["no"])), 500, RED, COLS_BEFORE[2], base)
		if i < comms.size() - 1:
			_hair(top + 44.0 - 2.0)


## After the count: each group's yes and no (cast_vote byComm), rows 36 high.
func _results() -> void:
	_head("", [["찬성", SKY], ["반대", RED]], COLS_AFTER)
	var comms: Array = m["comms"]
	var by: Dictionary = result.get("byComm", {})
	for i in comms.size():
		var c: Dictionary = comms[i]
		var r: Dictionary = by.get(c["id"], {})
		var top: float = 42.0 + 36.0 * float(i)
		var base: float = _row_name(c, top, 36.0)
		_num(str(int(r.get("yes", 0))), 500, SKY, COLS_AFTER[0], base)
		_num(str(int(r.get("no", 0))), 500, RED, COLS_AFTER[1], base)
		if i < comms.size() - 1:
			_hair(top + 36.0 - 2.0)


## The pane's head (.cl__head at 30, 12, 30 high): its words and the columns'.
func _head(words: String, cols: Array, at: Array) -> void:
	var k: float = UiFonts.K
	var l := _ink(words, UiFonts.WORD, 400, 12.0, INK2, 1.2)
	_on_pane(l)
	GlassParts.put(l, PANE_X0, 12.0, 30.0)
	var base: float = GlassParts.base_of(l)
	for i in cols.size():
		var cl := _ink(String(cols[i][0]), UiFonts.WORD, 400, 12.0, cols[i][1], 0.24)
		_on_pane(cl)
		GlassParts.put_on(cl, float(at[i]) * k - GlassParts.text_w(cl) + 0.24 * k, base)


## A row's name (.cl__n: 14 · 500); returns its baseline. The seats are on
## the group's plate on the ring already (결정 417).
func _row_name(c: Dictionary, top: float, h: float) -> float:
	var n := _ink(String(c["name"]), UiFonts.WORD, 500, 14.0, INK, 1.4)
	_on_pane(n)
	GlassParts.put(n, PANE_X0, top, h)
	return GlassParts.base_of(n)


func _num(text: String, weight: int, col: Color, right: float, base: float) -> void:
	var l := _ink(text, UiFonts.NUMBER, weight, 18.0, col, 0.0)
	_on_pane(l)
	GlassParts.put_on(l, right * UiFonts.K - GlassParts.text_w(l), base)


func _hair(y: float) -> void:
	var k: float = UiFonts.K
	var c := ColorRect.new()
	c.color = HAIR
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(PANE_X0, y) * k
	c.size = Vector2(PANE_X1 - PANE_X0, 2.0) * k
	_on_pane(c)


## The group picked (.pane--comm): its leader's ink portrait on paper, name,
## office and nature, 접기; its seats and stance on the relation scale; its
## stones; how it stands to the captain and to this agenda; its cohesion; and
## what this agenda does to it, with its seats away.
func _detail(c: Dictionary) -> void:
	var k: float = UiFonts.K
	_on_pane(_portrait(int(c["bust"])))
	var nm := _ink(String(c["leader"]) if String(c["leader"]) != "" else String(c["role"]), UiFonts.WORD, 500, 17.0, INK, 2.04)
	_on_pane(nm)
	GlassParts.put(nm, 85.0, 12.0, 23.0)
	var role := _ink(String(c["role"]), UiFonts.WORD, 400, 12.0, INK2, 0.36)
	_on_pane(role)
	GlassParts.put(role, 85.0, 35.0, 16.0)
	var nature := _ink(String(c["trait"]), UiFonts.WORD, 400, 12.0, INK2, 0.36)
	_on_pane(nature)
	GlassParts.put(nature, 85.0, 51.0, 16.0)
	# A long name ends short of 접기.
	nm.clip_text = true
	nm.size.x = minf(nm.size.x, (192.0 - 85.0) * k)
	_on_pane(_fold())
	# Its seats and its stage; at the right its stones (.cm__facts, 24 high).
	var y: float = 76.0
	var seats := _ink(str(int(c["seats"])), UiFonts.NUMBER, 500, 15.0, INK, 0.225)
	_on_pane(seats)
	var stage_l := _ink("석 · " + String(c["stage"]), UiFonts.WORD, 400, 12.0, INK2, 0.0)
	_on_pane(stage_l)
	GlassParts.put(stage_l, 0.0, y, 24.0)
	var base: float = GlassParts.base_of(stage_l)
	GlassParts.put_on(seats, PANE_X0 * k, base)
	stage_l.position.x = seats.position.x + GlassParts.text_w(seats)
	var soft: int = int(c["no"]) - int(c["hard"])
	var stones: Array = [["y", int(c["yes"]), SKY], ["u", int(c["und"]), INK]]
	if int(c.get("pool", 0)) > 0:
		# What a bribe or a debt has the leader bring, in the deal ring's amber.
		stones.append(["u", int(c["pool"]), AMBER])
	stones.append_array([["s", soft, INK], ["n", int(c["hard"]), RED]])
	_stones(stones, y, 244.0)
	# How it stands to the captain, and its stance on this agenda (.cm__rel).
	y += 24.0
	var relw := _ink(String(c["relw"]), UiFonts.WORD, 400, 12.0, INK2, 0.48)
	_on_pane(relw)
	GlassParts.put(relw, PANE_X0, y, 24.0)
	var st: Array = c["stance"]
	_on_pane(_stance_chip(String(st[0]), String(st[1]), 244.0, y + 2.0))
	# Its cohesion (.stat: the word 30, the bar, the number 24 at the right).
	y += 26.0
	var lab := _ink("결속", UiFonts.WORD, 400, 12.0, INK2, 0.96)
	_on_pane(lab)
	GlassParts.put(lab, PANE_X0, y, 16.0)
	var coh: int = clampi(int(c["coh"]), 0, 100)
	var bar_x: float = PANE_X0 + 30.0 + 7.0
	var bar_w: float = 244.0 - 24.0 - 7.0 - bar_x
	var b := Control.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = Vector2(bar_x, y + 5.0) * k
	b.size = Vector2(bar_w, 6.0) * k
	b.draw.connect(func() -> void:
		GlassParts.round_rect(b, Rect2(Vector2.ZERO, b.size), 3.0 * k, Color(0, 0, 0, 0.6))
		if coh > 0:
			GlassParts.round_rect(b, Rect2(Vector2.ZERO, Vector2(b.size.x * float(coh) / 100.0, b.size.y)), 3.0 * k, FILL)
		# Its mark at 0 (.bar u: 2 × 14, 4 above the bar, lamp amber).
		GlassParts.round_rect(b, Rect2(Vector2(-1.0, -4.0) * k, Vector2(2.0, 14.0) * k), 1.0 * k, AMBER))
	_on_pane(b)
	var cn := _ink(str(coh), UiFonts.NUMBER, 500, 17.0, INK, 0.255)
	_on_pane(cn)
	GlassParts.put_on(cn, 244.0 * k - GlassParts.text_w(cn), GlassParts.base_of(lab) + 1.0 * k)
	# What this agenda does to it (.cl__stake rows: a hair above, 24 high).
	y += 16.0 + 8.0
	var rows: Array = (c["stake"] as Array).duplicate()
	if rows.is_empty():
		rows.append(["이 안건", "바뀌는 것 없음"])
	if int(c["absent"]) > 0:
		rows.append(["부재", "%d석" % int(c["absent"])])
	if bool(m.get("dealing", false)):
		# The deal tools and their line take the rows' room; the bill says what
		# the agenda does car by car, so the first row alone stays, under them.
		_deal_part(c)
		if ask != Ask.TOOLS:
			return
		# One line under them, at the left: the lever stands up over the pane's
		# bottom right (a frame px 25 over the main key).
		var note: String = "가결되면 기습으로 기억" if bool(m.get("surprise", false)) and int(c["absent"]) > 0 and int(c["score"]) < 0 \
				else "%s %s" % [rows[0][0], rows[0][1]]
		var nl := _ink(note, UiFonts.WORD, 400, 12.0, INK2, 0.24)
		nl.name = "Stake"
		_on_pane(nl)
		GlassParts.put(nl, PANE_X0, DEAL_Y + 45.0, 20.0)
		nl.clip_text = true
		nl.size.x = minf(GlassParts.text_w(nl), (200.0 - PANE_X0) * UiFonts.K)
		return
	board.preview(-1)
	_hair(y)
	y += 2.0
	for r: Array in rows:
		var l := _ink(String(r[0]), UiFonts.WORD, 400, 12.0, INK2, 0.48)
		_on_pane(l)
		GlassParts.put(l, PANE_X0, y, 24.0)
		var v := _ink(String(r[1]), UiFonts.WORD, 500, 13.0, INK, 0.26)
		_on_pane(v)
		GlassParts.put_on(v, 244.0 * k - GlassParts.text_w(v), GlassParts.base_of(l))
		y += 24.0
	# Called while its work crew sleeps, a group against it remembers a pass as a
	# trick (council_vote.gd cast_vote: an emergency session, seats away, score < 0).
	if bool(m.get("surprise", false)) and int(c["absent"]) > 0 and int(c["score"]) < 0:
		var warn := _ink("가결되면 기습으로 기억", UiFonts.WORD, 500, 12.0, Color("f29078"), 0.48)
		_on_pane(warn)
		GlassParts.put(warn, PANE_X0, y, 20.0)


## The deal part of the picked group's pane: the tools in a row (.tools, a
## medal and its word a tool, the picked one lit), the tool's line (.deal: its
## name · cost; why not in the accent, or what it does) and 거래; or, asked,
## the 공개 협상's conditions or the car to cut.
func _deal_part(c: Dictionary) -> void:
	var comm: String = String(c["id"])
	if ask == Ask.CONDITIONS:
		board.preview(-1)
		_conditions(comm)
		return
	if ask == Ask.CUT:
		board.preview(-1)
		_cut_targets(comm)
		return
	var k: float = UiFonts.K
	var tools: Array = tools_of(g, t, idx, comm)
	var w: float = (PANE_X1 - PANE_X0) / float(tools.size())
	var cur: Dictionary = tools[0]
	for i in tools.size():
		var tl: Dictionary = tools[i]
		var id: String = String(tl["id"])
		var on: bool = id == tool
		if on:
			cur = tl
		var b := _bare_key("Tool_" + id, Vector2(PANE_X0 + w * float(i), TOOLS_Y), Vector2(w, TOOL_H))
		b.tooltip_text = String(tl["name"])
		b.pressed.connect(_pick_tool.bind(id))
		var med: Control = _tool_medal(id, on, not bool(tl["ok"]))
		med.position = Vector2((w - 34.0) * 0.5, 1.0) * k
		b.add_child(med)
		var lab := _ink(String(tl["word"]), UiFonts.WORD, 500 if on else 400, 12.0, INK if on else INK2, 0.48)
		if not bool(tl["ok"]):
			lab.modulate.a = 0.55
		b.add_child(lab)
		GlassParts.put_on(lab, (b.size.x - GlassParts.text_w(lab)) * 0.5, 49.0 * k)
		_on_pane(b)
	# The seats it would bring ring on the board.
	if bool(cur["ok"]):
		board.preview(sel, kinds_after(g, t, idx, comm, String(cur["id"])))
	else:
		board.preview(-1)
	# The deal line: what it is and costs; under it why not, what it does, or
	# what the deal already made with this group came to.
	# A deal already made with this group: its tool, whether it took, and what it came to.
	var made: String = ""
	var title: String = String(cur["name"])
	var cost_word: String = String(cur["cost"])
	var cost_col: Color = INK
	for d: Dictionary in g["council"].get("deals", []):
		if d["comm"] == comm:
			made = String(said.get(comm, d["label"]))
			for row: Array in TOOLS:
				if row[0] == d["tool"]:
					title = String(row[2])
			var took: bool = not bool(d.get("refused", false))
			cost_word = "맺음" if took else "안 됨"
			cost_col = SKY if took else RED
	var off: bool = not bool(cur["ok"])
	var nm := _ink(title, UiFonts.WORD, 500, 14.0, INK, 0.0)
	_on_pane(nm)
	GlassParts.put(nm, PANE_X0, DEAL_Y, 20.0)
	var base: float = GlassParts.base_of(nm)
	if cost_word != "":
		var dot := _ink("·", UiFonts.WORD, 400, 14.0, INK3, 0.0)
		_on_pane(dot)
		GlassParts.put_on(dot, nm.position.x + GlassParts.text_w(nm) + 6.0 * k, base)
		var cost := _ink(cost_word, UiFonts.WORD, 400, 14.0, cost_col, 0.0)
		cost.name = "DealCost"
		_on_pane(cost)
		GlassParts.put_on(cost, dot.position.x + GlassParts.text_w(dot) + 6.0 * k, base)
	var line: String = made if made != "" else (String(cur["why"]) if off else String(cur["hint"]))
	var small := _ink(line, UiFonts.WORD, 400, 12.0, AMBER if off and made == "" else INK2, 0.0)
	small.name = "DealLine"
	_on_pane(small)
	GlassParts.put(small, PANE_X0, DEAL_Y + 20.0, 17.0)
	small.clip_text = true
	small.size.x = minf(GlassParts.text_w(small), (244.0 - 64.0 - 6.0 - PANE_X0) * k)
	if not off and made == "" and String(cur["red"]) != "":
		var red := _ink(String(cur["red"]), UiFonts.WORD, 500, 12.0, RED, 0.0)
		_on_pane(red)
		GlassParts.put_on(red, small.position.x + GlassParts.text_w(small), GlassParts.base_of(small))
	_on_pane(_pill("Deal", "거래", Vector2(244.0 - 64.0, DEAL_Y + 4.0), off))


## A tool's medal (.med--s: 34, a 30 disc, an 18 mark): matte; lamp-lit when
## picked (.tool.on); faded when it cannot (.tool.is-off .med: .36).
func _tool_medal(id: String, on: bool, off: bool) -> Control:
	var k: float = UiFonts.K
	if not on:
		var med: Control = GlassParts.medal(id, INK, 34.0, 30.0, 18.0)
		if off:
			med.modulate.a = 0.36
		return med
	var c := Control.new()
	c.name = "Medal_" + id
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(34.0, 34.0) * k
	c.draw.connect(func() -> void:
		var ctr: Vector2 = c.size * 0.5
		var r: float = 15.0 * k
		for i in 3:
			c.draw_circle(ctr + Vector2(0, 1.0 * k), r + float(3 - i) * k, Color(0, 0, 0, 0.08 + 0.05 * i), true, -1.0, true)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 48:
			var a: float = TAU * float(i) / 48.0
			var p: Vector2 = ctr + Vector2(cos(a), sin(a)) * r
			pts.append(p)
			# The lamp's light from a little under the middle outwards (circle at 50% 60%).
			cols.append(GlassParts.grad_at(LAMP, clampf((p - (ctr + Vector2(0, 0.2 * r))).length() / (r * 1.2), 0.0, 1.0)))
		c.draw_polygon(pts, cols)
		c.draw_arc(ctr, r - 1.0 * k, 0.0, TAU, 64, GlassParts.RING, 2.0 * k, true))
	var mark := _icon(id, 18.0, ON_INK, 2.0)
	mark.position = (c.size - mark.size) * 0.5
	c.add_child(mark)
	return c


## The 공개 협상's three conditions (s1 ui/council.ts conds), a row each: its
## number, what it is, and when it is paid (지금 · 다음 정차 · 다음 회기까지).
func _conditions(comm: String) -> void:
	var k: float = UiFonts.K
	var conds: Array = CouncilVote.open_conditions(_on_agenda(g, idx), t, comm)
	for i in conds.size():
		var cd: Dictionary = conds[i]
		var top: float = 146.0 + 44.0 * float(i)
		var b := _bare_key("Cond_%d" % i, Vector2(PANE_X0, top), Vector2(PANE_X1 - PANE_X0, 44.0))
		b.pressed.connect(_cond_pressed.bind(i))
		_on_pane(b)
		var n := _ink(str(i + 1), UiFonts.NUMBER, 600, 15.0, AMBER, 0.0)
		_on_pane(n)
		GlassParts.put(n, PANE_X0 + 2.0, top, 44.0)
		var base: float = GlassParts.base_of(n)
		var kind: String = String(cd["kind"])
		var when: String = "지금 치른다" if bool(cd["now"]) else ("다음 정차" if kind in ["target", "skip_dispatch"] else "다음 회기까지")
		var wl := _ink(when, UiFonts.WORD, 400, 11.0, INK2, 0.0)
		_on_pane(wl)
		GlassParts.put_on(wl, 244.0 * k - GlassParts.text_w(wl), base)
		var lab := _ink(String(cd["label"]), UiFonts.WORD, 500, 13.0, INK, 0.0)
		lab.name = "CondWord_%d" % i
		_on_pane(lab)
		GlassParts.put_on(lab, (PANE_X0 + 20.0) * k, base)
		lab.clip_text = true
		lab.size.x = minf(GlassParts.text_w(lab), wl.position.x - lab.position.x - 6.0 * k)
		if i < conds.size() - 1:
			_hair(top + 44.0 - 2.0)


## Which car 「칼질」 cuts: the other four, two a row.
func _cut_targets(comm: String) -> void:
	var k: float = UiFonts.K
	var head := _ink("칼질할 칸", UiFonts.WORD, 400, 12.0, INK2, 1.2)
	_on_pane(head)
	GlassParts.put(head, PANE_X0, 146.0, 20.0)
	var j: int = 0
	for o: String in t["COMMS"]:
		if o == comm:
			continue
		var at := Vector2(PANE_X0 + 111.0 * float(j % 2), 168.0 + (48.0 if j >= 2 else 0.0))
		var b := _bare_key("Cut_" + o, at, Vector2(109.0, 44.0))
		b.pressed.connect(_cut_pressed.bind(o))
		b.draw.connect(func() -> void:
			GlassParts.round_rect(b, Rect2(Vector2(0, 2.0) * k, b.size - Vector2(0, 4.0) * k), 4.0 * k, Color(0, 0, 0, 0.36)))
		var lab := _ink(String(t["COMM_NAME"][o]), UiFonts.WORD, 500, 14.0, INK, 1.4)
		b.add_child(lab)
		GlassParts.put(lab, 0.0, 0.0, 44.0)
		lab.position.x = (b.size.x - GlassParts.text_w(lab)) * 0.5
		_on_pane(b)
		j += 1


## A bare key over the pane (its own look drawn by its parts), the press a lamp wash.
func _bare_key(key_name: String, at: Vector2, sz: Vector2) -> Button:
	var k: float = UiFonts.K
	var b := Button.new()
	b.name = key_name
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var press := StyleBoxFlat.new()
	press.bg_color = PRESS
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("hover_pressed", press)
	b.position = at * k
	b.size = sz * k
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b


## The 거래 pill (.pill--g: 36 high, radius 18, the light fill, the face's ink;
## its key 44 high round it); faded and shut when the deal cannot be made
## (.deal.is-off .pill--g: .34).
func _pill(key_name: String, word: String, at: Vector2, off: bool) -> Button:
	var k: float = UiFonts.K
	var b := _bare_key(key_name, at - Vector2(0.0, 4.0), Vector2(64.0, 44.0))
	b.disabled = off
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE if off else Control.MOUSE_FILTER_STOP
	if not off:
		b.pressed.connect(_deal_pressed)
	b.draw.connect(func() -> void:
		GlassParts.round_rect(b, Rect2(Vector2(0.0, 4.0) * k, Vector2(64.0, 36.0) * k), 18.0 * k, FILL))
	var lab := _ink(word, UiFonts.WORD, 500, 14.0, FACE, 0.0)
	b.add_child(lab)
	GlassParts.put(lab, 0.0, 4.0, 36.0)
	lab.position.x = (b.size.x - GlassParts.text_w(lab)) * 0.5
	if off:
		b.modulate.a = 0.34
	return b


## The leader's portrait (.cm__por 46 × 56 at 29, 13, tilted −2°): paper with
## its fibres, a soft shadow under it, the ink bust on it.
func _portrait(kind: int) -> Control:
	var k: float = UiFonts.K
	var p := Control.new()
	p.name = "Portrait"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = Vector2(29.0, 13.0) * k
	p.size = Vector2(46.0, 56.0) * k
	p.pivot_offset = p.size * 0.5
	p.rotation = deg_to_rad(-2.0)
	p.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, p.size)
		GlassParts.shadow(p, r, 0.0, 2.0 * k, 2.0 * k, Color(0, 0, 0, 0.5))
		p.draw_rect(r, PAPER)
		var tile: float = 240.0 * k
		p.draw_texture_rect_region(PAPER_TEX, r, Rect2(Vector2.ZERO, r.size / tile * Vector2(PAPER_TEX.get_size())))
		p.draw_texture_rect_region(BUSTS, r, Rect2(float(kind) * 92.0, 0.0, 92.0, 112.0)))
	return p


## 접기 at the top right (.word: its arrow 14 at the right, the word 3 before it).
func _fold() -> Button:
	var k: float = UiFonts.K
	var b := Button.new()
	b.name = "Fold"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.position = Vector2(195.0, 2.0) * k
	b.size = Vector2(55.0, 44.0) * k
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(_fold_pressed)
	var mark := _icon("fwd", 14.0, INK2, 2.0)
	mark.position = Vector2(35.0, 15.0) * k
	b.add_child(mark)
	var word := _ink("접기", UiFonts.WORD, 400, 13.0, INK2, 1.3)
	b.add_child(word)
	GlassParts.put_on(word, mark.position.x - 3.0 * k - GlassParts.text_w(word), 26.5 * k)
	return b


## The stones and their counts, right to left from `right` (.cm__v: a 10 stone
## 5 in, 3 between it and its number).
func _stones(items: Array, top: float, right: float) -> void:
	var k: float = UiFonts.K
	var x: float = right
	var probe := _ink("0", UiFonts.NUMBER, 500, 15.0, INK, 0.225)
	_on_pane(probe)
	GlassParts.put(probe, 0.0, top + 3.0, 18.0)
	var base: float = GlassParts.base_of(probe)
	probe.queue_free()
	for j in range(items.size() - 1, -1, -1):
		var it: Array = items[j]
		var n := _ink(str(int(it[1])), UiFonts.NUMBER, 500, 15.0, it[2], 0.225)
		_on_pane(n)
		GlassParts.put_on(n, x * k - GlassParts.text_w(n), base)
		x = n.position.x / k - 3.0 - 10.0
		var s := TextureRect.new()
		s.texture = CouncilBoard.STONES[it[0]]
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The sprite holds a 12.8 stone in 16: drawn so the stone is 10.
		var box: float = 10.0 * CouncilBoard.STONE_BOX / 12.8
		s.size = Vector2(box, box) * k
		s.position = Vector2(x + 5.0 - box * 0.5, top + 4.0 + 5.0 - box * 0.5) * k
		_on_pane(s)
		x -= 5.0 + 3.0


## The stance as the mockup's chip (.cm__st: 20 high, 9 in, round, blue or red
## from the top, white words), its right end at `right`; undecided, the word alone.
func _stance_chip(kind: String, word: String, right: float, top: float) -> Control:
	var k: float = UiFonts.K
	var l := _ink(word, UiFonts.WORD, 500, 12.0, Color.WHITE if kind != "" else INK2, 0.72)
	var w: float = GlassParts.text_w(l) / k - 0.72 + 18.0
	var c := Control.new()
	c.name = "Stance"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(right - w, top) * k
	c.size = Vector2(w, 20.0) * k
	if kind != "":
		var stops: Array = CHIP_Y if kind == "y" else CHIP_N
		c.draw.connect(func() -> void:
			var r := Rect2(Vector2.ZERO, c.size)
			GlassParts.shadow(c, r, 10.0 * k, 1.0 * k, 1.0 * k, Color(0, 0, 0, 0.4))
			GlassParts.grad_rect(c, r, 10.0 * k, stops))
	c.add_child(l)
	GlassParts.put(l, 9.0, 0.0, 20.0)
	return c


func _on_pane(c: Control) -> void:
	_pane_parts.add_child(c)


# ── parts ─────────────────────────────────────────────────────────────────

func _ink(text: String, kind: int, weight: int, css: float, col: Color, spacing: float = 0.0) -> Label:
	return UiFonts.label(text, kind, weight, css, col, spacing)


func _icon(id: String, css: float, col: Color, weight: float = 2.0) -> TextureRect:
	var k: float = UiFonts.K
	var px: int = int(round(css * k))
	var r := TextureRect.new()
	r.texture = HudIcons.texture(id, px, col, weight, PAPER if col.r < 0.5 else SOOT_CUT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(px, px)
	return r


## How many lines `l`'s words take wrapped at `width` game px.
func _lines_of(l: Label, width: float) -> int:
	var f: Font = l.get_theme_font("font")
	var s: int = l.get_theme_font_size("font_size")
	var para := TextParagraph.new()
	para.width = width
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.add_string(l.text, f, s)
	return maxi(1, para.get_line_count())
