extends Control
## The keys along the bottom of the train (UI 3단계 시안 2차 .hud--bot, B1
## 「성에 낀 계기」), on the soot that rises from the bottom edge: the menu and
## the journal at the left as matte medals, the train's six rooms in the middle
## (research, refit, workshop, people, politics, medicine) as small medals with
## their word under them and a lamp badge when something waits there, the
## overview medal, and the screen's main key at the right. Measured from the
## mockup (px × ui_fonts.gd K); the middle stretches with the screen.
##
## A badge shows only a number the train has (medicine: the hurt and the sick);
## a room whose screen is open (`open_rooms`, by its icon) says so (room_pressed)
## and the rooms that have no screen yet answer 「준비 중」 over their key.
##
## Off the train's own screen the middle is the way the train goes instead of
## the rooms (route_line.gd, `route`), and where the main act is pulled the main
## key is a lever (lever_key.gd, `lever`), as the session's 「표결」.

signal main_pressed
signal room_pressed(icon: String)

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const LeverKey = preload("res://game/ui/lever_key.gd")
const RouteLine = preload("res://game/ui/route_line.gd")

const BAND_CSS: float = 56.0
## The six rooms: icon, word (k2_parts.js SIX).
const SIX: Array = [["papers", "연구"], ["wrench", "개조"], ["gear", "공방"], ["people", "사람·매뉴얼"], ["scale", "정치"], ["bed", "의료"]]
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const BADGE := Color("d18c32")
const BADGE_INK := Color("2a1804")
const NOTE_BG := Color(8 / 255.0, 11 / 255.0, 15 / 255.0, 0.84)
const NOTE_S: float = 1.4

var g: Dictionary = {}
var main_word: String = ""
var main_key: Button
## The middle as the way the train goes: {"seg", "total", "phase", "km"} (empty: the rooms).
var route: Dictionary = {}
## The main key as a lever, with its small line under the word.
var lever: bool = false
var lever_small: String = ""
## The rooms with a screen of their own, by icon (the workshop: "gear").
var open_rooms: Array = []
var route_line: Control = null
var _six: Array = []
var _note: Label = null


## The badge on each room for state `g0`: "" for none (tests read this).
static func badges(g0: Dictionary) -> Array:
	var hurt: int = int(g0.get("injured", 0)) + int(g0.get("sickCount", 0))
	return ["", "", "", "", "", str(hurt) if hurt > 0 else ""]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -BAND_CSS * UiFonts.K
	offset_bottom = 0.0
	_medal_key("menu", "메뉴", Vector2(12, 6))
	_medal_key("book", "일지", Vector2(64, 6))
	if route.is_empty():
		var marks: Array = badges(g)
		for i in SIX.size():
			var b := _room(String(SIX[i][0]), String(SIX[i][1]), String(marks[i]))
			add_child(b)
			_six.append(b)
	else:
		var r = RouteLine.new()
		r.name = "Route"
		r.seg = int(route.get("seg", 1))
		r.total = int(route.get("total", 24))
		r.phase = String(route.get("phase", "이동"))
		r.next_km = float(route.get("km", -1.0))
		add_child(r)
		route_line = r
	_medal_key("overview", "한눈에 보기", Vector2(-212, 6))
	if lever:
		var lk = LeverKey.new(main_word, lever_small)
		lk.pulled.connect(func() -> void: main_pressed.emit())
		lk.confirmed.connect(func() -> void: main_pressed.emit())
		main_key = lk
	else:
		main_key = LampKey.new(main_word)
		main_key.pressed.connect(func() -> void: main_pressed.emit())
	main_key.name = "Main"
	add_child(main_key)
	main_key.size = main_key.custom_minimum_size
	resized.connect(_lay_out)
	_lay_out()


## The main key's word (a lever: its small line, and whether it is down).
func set_main(word: String, small: String = "", down: bool = false) -> void:
	main_word = word
	if main_key is LeverKey:
		(main_key as LeverKey).set_word(word, small, down)
	elif main_key:
		main_key.text = word


## The middle's six spread evenly between the left keys and the right ones
## (.hud__mid from 116 to 220 short of the right, .six inside it 10 in). A main
## key wider than 148 (a lever with a long small line) pushes the right keys
## and the way's end left by as much; the six give up only what the 31 between
## the last room's medal and the overview cannot, keeping 12 there, so their
## words stay apart on a narrow screen.
func _lay_out() -> void:
	var k: float = UiFonts.K
	var w: float = size.x / k
	var wider: float = maxf(0.0, main_key.size.x / k - 148.0) if main_key else 0.0
	var x0: float = 126.0
	var x1: float = w - 230.0 - wider
	var six_end: float = w - 230.0 - maxf(0.0, wider - 19.0)
	var step: float = (six_end - x0 - 60.0) / float(maxi(1, _six.size() - 1))
	for i in _six.size():
		(_six[i] as Control).position = Vector2(x0 + step * i, 0.0) * k
	# The way the train goes fills the middle (.hud__mid 116 → 220 short of the
	# right, .route 10 in from it, 10 down the band).
	if route_line:
		route_line.position = Vector2(x0, 10.0) * k
		route_line.size = Vector2(x1 - x0, RouteLine.CSS_H) * k
	for c in get_children():
		if c is Button and c.has_meta("right"):
			(c as Control).position = Vector2((w + float(c.get_meta("right")) - wider) * k, 6.0 * k)
	if main_key:
		main_key.position = Vector2((w - 12.0 - 148.0 - wider) * k, 4.0 * k)


## A medal key (.med 44): at `at` (a negative x is from the right).
func _medal_key(icon: String, word: String, at: Vector2) -> Button:
	var k: float = UiFonts.K
	var b := _bare(word)
	b.name = "Key_" + icon
	b.size = Vector2(44, 44) * k
	b.add_child(GlassParts.medal(icon, INK, 44.0, 38.0, 22.0))
	if at.x < 0.0:
		b.set_meta("right", at.x)
	else:
		b.position = at * k
	b.pressed.connect(_soon.bind(b))
	_press_sink(b)
	add_child(b)
	return b


## A room (.six button, 60 × 56): its small medal at 2, its word under it at
## 36, its badge at the medal's top right.
func _room(icon: String, word: String, badge: String) -> Button:
	var k: float = UiFonts.K
	var b := _bare(word)
	b.name = "Room_" + icon
	b.size = Vector2(60, 56) * k
	var m: Control = GlassParts.medal(icon, INK, 34.0, 32.0, 20.0)
	m.position = Vector2(13, 2) * k
	b.add_child(m)
	var lab := UiFonts.label(word, UiFonts.WORD, 400, 12.0, INK2, 0.48)
	lab.name = "Word"
	b.add_child(lab)
	# On the baseline measured off the mockup, 47 down the band.
	GlassParts.put_on(lab, (b.size.x - GlassParts.text_w(lab)) * 0.5, 47.0 * k)
	if badge != "":
		var em := UiFonts.label(badge, UiFonts.NUMBER, 600, 13.0, BADGE_INK, 0.195)
		em.name = "Badge"
		var sb := StyleBoxFlat.new()
		sb.bg_color = BADGE
		sb.set_corner_radius_all(int(round(8.0 * k)))
		sb.corner_detail = 8
		sb.content_margin_left = 4.0 * k
		sb.content_margin_right = 4.0 * k
		em.add_theme_stylebox_override("normal", sb)
		em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		em.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		em.custom_minimum_size = Vector2(20.0, 16.0) * k
		b.add_child(em)
		em.size = em.get_combined_minimum_size()
		em.position = Vector2(40.0, 2.0) * k
	if open_rooms.has(icon):
		b.pressed.connect(func() -> void: room_pressed.emit(icon))
	else:
		b.pressed.connect(_soon.bind(b))
	_press_sink(b)
	return b


func _bare(word: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = word
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return b


## Pressed, the medal sinks 2 px and brightens (.med:active).
func _press_sink(b: Button) -> void:
	var k: float = UiFonts.K
	b.button_down.connect(func() -> void:
		for c in b.get_children():
			if String(c.name).begins_with("Medal_"):
				(c as Control).position.y += 2.0 * k
				(c as Control).modulate = Color(1.25, 1.25, 1.25))
	b.button_up.connect(func() -> void:
		for c in b.get_children():
			if String(c.name).begins_with("Medal_"):
				(c as Control).position.y -= 2.0 * k
				(c as Control).modulate = Color.WHITE)


## A room with no screen yet: a note over its key that fades.
func _soon(b: Button) -> void:
	note("준비 중", b)


## A short note over key `b` (the main key when none) that fades after `hold_s`:
## the same note a room with no screen gets, one at a time.
func note(text: String, b: Control = null, hold_s: float = NOTE_S) -> void:
	var over: Control = b if b != null else main_key
	if over == null:
		return
	var k: float = UiFonts.K
	if is_instance_valid(_note):
		_note.queue_free()
	var l := UiFonts.label(text, UiFonts.WORD, 400, 13.0, INK2, 0.52)
	l.name = "Note"
	var sb := StyleBoxFlat.new()
	sb.bg_color = NOTE_BG
	sb.set_corner_radius_all(int(round(4.0 * k)))
	sb.content_margin_left = 10.0 * k
	sb.content_margin_right = 10.0 * k
	l.add_theme_stylebox_override("normal", sb)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 26.0 * k)
	add_child(l)
	l.size = l.get_combined_minimum_size()
	l.position = Vector2(over.position.x + (over.size.x - l.size.x) * 0.5, -l.size.y - 6.0 * k)
	l.position.x = clampf(l.position.x, 6.0 * k, size.x - l.size.x - 6.0 * k)
	_note = l
	var tw := l.create_tween()
	tw.tween_interval(hold_s * 0.6)
	tw.tween_property(l, "modulate:a", 0.0, hold_s * 0.4)
	tw.tween_callback(l.queue_free)
