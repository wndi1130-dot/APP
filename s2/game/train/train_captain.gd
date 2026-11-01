extends PanelContainer
## The captain's board: one figure cut into its six parts, a line on where the
## captain is and how the body is, what is in the hands, and the wounds one a
## line. It shows the rules' captain and changes nothing.
##
## The figure is the field body window's (its outlines and colours are read
## from field_hud.gd), drawn here for show only: no part is a key. The body in
## a word and the wound lines are the field's own words too (body_state.gd,
## treatment.gd). There are no gauges for hunger, soreness or tiredness
## (2026-10-12: they come when the values do).

const Hud = preload("res://game/ui/field_hud.gd")
const BodyState = preload("res://game/sim/body_state.gd")
const Treatment = preload("res://game/sim/treatment.gd")
const W = preload("res://game/sim/weapons.gd")
const Carry = preload("res://game/sim/carry.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const Rules = preload("res://game/train/train_rules.gd")

const WOUND_FLAGS: Array = ["bandaged", "disinfected", "splinted", "festering", "pulled", "sutured"]
## The fills of a sound part and of a hurt one that does not bleed, as the
## field body window paints them (field_hud.gd body_looks).
const FILL_SOUND := Color(0.2, 0.2, 0.2, 0.95)
const FILL_HURT := Color(0.3, 0.29, 0.26, 0.95)
const RIM_W: float = 1.5
const RIM_W_FESTER: float = 3.0
const HAND_NAMES: Dictionary = {"weapon": "무기", "tool": "도구"}
const NOTHING := "없음"
const NO_WOUND := "상처 없음"
const TEXT_W: float = 280.0
const BACK_ALPHA: float = 0.92           # the board lies over the cars: its words must read on any of them

var figure: Control
var line_label: Label
var weapon_label: Label
var tool_label: Label
var wound_box: VBoxContainer
var foot: HBoxContainer                 # left empty: the hand panel hangs its test key here
var looks: Dictionary = {}
var wound_lines: PackedStringArray = PackedStringArray()


## The captain's body as the field keeps one: the rules' wounds put on a fresh
## body. Nothing else is set, so tiredness and cold stay out of the word.
static func body_of(captain: Dictionary) -> BodyState:
	var body := BodyState.new()
	var list = captain.get("wounds", [])
	for w in (list if list is Array else []):
		if not (w is Dictionary) or not BodyState.PARTS.has(w.get("part")) or not BodyState.KINDS.has(w.get("kind")):
			continue
		var i := body.add_wound(String(w["part"]), String(w["kind"]), 0.0, float(w.get("blood", -1.0)))
		for key in WOUND_FLAGS:
			if w.has(key):
				body.wounds[i][key] = bool(w[key])
	return body


## Where the captain is and what they do, the body in a word, and the
## stretches left when there are any: "열차장실 · 멀쩡함", "의무칸 침상 · 피가 남 · 3구간".
static func line(captain: Dictionary, cars: Array, word: String) -> String:
	var parts: Array = []
	var at := String(captain.get("at", ""))
	var doing := String(captain.get("doing", ""))
	var out := at == Rules.CAPTAIN_OUT
	if out:
		parts.append("밖에 나감")
	elif at != "":
		var place := at
		for car in cars:
			if String(car.get("id", "")) == at:
				place = String(car.get("name", at))
		parts.append("%s 침상" % place if doing == "bed" else place)
	if doing == "rest" and not out:
		parts.append("쉬는 중")
	parts.append(word)
	if int(captain.get("left", 0)) > 0:
		parts.append("%d구간" % int(captain["left"]))
	return " · ".join(parts)


## What the figure shows of each part: {"fill", "rim", "rim_w", "cracked",
## "kinds", "festering"}. A part that bleeds is dark brown (no red, nothing
## gory), a festering one wears a sallow rim, a broken one a crack.
static func part_looks(body: BodyState) -> Dictionary:
	var out: Dictionary = {}
	for part: String in BodyState.PARTS:
		var kinds: Array = []
		var blood := 0.0
		var festering := false
		var cracked := false
		for w: Dictionary in body.wounds:
			if w["part"] == part:
				blood += float(w["blood"])
				festering = festering or bool(w["festering"])
				cracked = cracked or String(w["kind"]) == "fracture"
				var k: String = Treatment.KIND_NAMES[w["kind"]]
				if not kinds.has(k):
					kinds.append(k)
		out[part] = {
			"fill": Hud.BLOOD_BROWN if blood > 0.0 else (FILL_SOUND if kinds.is_empty() else FILL_HURT),
			"rim": Hud.FESTER_RIM if festering else Color(Hud.INK, 0.55),
			"rim_w": RIM_W_FESTER if festering else RIM_W,
			"cracked": cracked, "kinds": kinds, "festering": festering,
		}
	return out


## One hand in a line: "무기 · 손도끼", "도구 · 없음".
static func hand_text(captain: Dictionary, hand: String) -> String:
	var hands = captain.get("hands", {})
	var held := held_name(String(hands.get(hand, ""))) if hands is Dictionary else ""
	return "%s · %s" % [HAND_NAMES[hand], NOTHING if held == "" else held]


## The name of what a hand holds, as the field names it ("" for an empty hand).
static func held_name(id: String) -> String:
	if id == "":
		return ""
	return String(Carry.ITEM_NAMES.get(id, W.get_data(id).get("name", id)))


func _init() -> void:
	theme = UiTheme.make(20)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(Hud.PANEL_BG, BACK_ALPHA)
	back.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", back)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	add_child(pad)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	pad.add_child(h)
	figure = Control.new()
	figure.custom_minimum_size = Hud.BODY_SIZE * Hud.BODY_SCALE
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.draw.connect(_draw_figure)
	h.add_child(figure)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(TEXT_W, 0)
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	var head := Label.new()
	head.text = "열차장"
	head.add_theme_color_override("font_color", Hud.BRASS)
	v.add_child(head)
	line_label = _text(v, 20, Hud.INK)
	weapon_label = _text(v, 18, Hud.INK)
	tool_label = _text(v, 18, Hud.INK)
	wound_box = VBoxContainer.new()
	wound_box.add_theme_constant_override("separation", 2)
	v.add_child(wound_box)
	foot = HBoxContainer.new()
	foot.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	v.add_child(foot)
	show_captain({}, [])


## Put a captain on the board ({} is a sound captain nowhere, with empty hands).
func show_captain(captain: Dictionary, cars: Array) -> void:
	var body := body_of(captain)
	looks = part_looks(body)
	line_label.text = UiFonts.keep_all(line(captain, cars, body.status_words()))
	weapon_label.text = UiFonts.keep_all(hand_text(captain, "weapon"))
	tool_label.text = UiFonts.keep_all(hand_text(captain, "tool"))
	for l: Label in [weapon_label, tool_label]:
		l.add_theme_color_override("font_color", Hud.DIM if l.text.replace(UiFonts.WORD_JOINER, "").ends_with(NOTHING) else Hud.INK)
	wound_lines = PackedStringArray()
	for w: Dictionary in body.wounds:
		wound_lines.append(Treatment.wound_text(w))
	for old in wound_box.get_children():
		wound_box.remove_child(old)
		old.queue_free()
	if wound_lines.is_empty():
		_text(wound_box, 16, Hud.DIM).text = UiFonts.keep_all(NO_WOUND)
	for text in wound_lines:
		_text(wound_box, 16, Hud.INK).text = UiFonts.keep_all(text)
	figure.queue_redraw()


func _draw_figure() -> void:
	for part: String in Hud.BODY_SHAPES:
		var look: Dictionary = looks.get(part, {})
		if look.is_empty():
			continue
		var pts := PackedVector2Array()
		for v: Vector2 in Hud.BODY_SHAPES[part]:
			pts.append(v * Hud.BODY_SCALE)
		figure.draw_colored_polygon(pts, look["fill"])
		pts.append(pts[0])
		figure.draw_polyline(pts, look["rim"], float(look["rim_w"]), true)
		var r := Rect2(pts[0], Vector2.ZERO)
		for v in pts:
			r = r.expand(v)
		var c: Vector2 = r.get_center()
		if look["cracked"]:
			# A broken bone: a crack across the part, above its word.
			var half: float = minf(r.size.x, 40.0) * 0.3
			var at: Vector2 = c + Vector2(0, -22)
			figure.draw_polyline(PackedVector2Array([at + Vector2(-half, -5), at + Vector2(-half * 0.3, 4), at + Vector2(half * 0.3, -4), at + Vector2(half, 5)]), Hud.INK, 2.0, true)
		# The first kind of wound there, in a word (the rest is in the lines).
		var words: Array = look["kinds"].slice(0, 1)
		if look["festering"]:
			words.append("곪음")
		var font: Font = figure.get_theme_default_font()
		for i in words.size():
			var w: float = font.get_string_size(words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.BODY_WORD_FONT).x
			figure.draw_string(font, c + Vector2(-w * 0.5, 4.0 + i * (Hud.BODY_WORD_FONT + 2.0)), words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.BODY_WORD_FONT, Hud.INK)


func _text(parent: Control, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_W, 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
