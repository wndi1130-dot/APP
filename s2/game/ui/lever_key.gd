extends Button
## The main key as a lever, where a screen's main act is pulled rather than
## pressed (UI 3단계 시안 2차 c10.css .main--lever.lv-na, k2_parts.js lvBtn ·
## LVX, k5_nav.js pullLever; B1): the whole key is one iron base in a brass rim;
## at its left the lamp nameplate with the word and a small line under it, at
## its right the lever's housing rising 26 above the base: an iron plate with a
## brass guide round a slot, catch notches top and bottom, an amber lamp at the
## foot (where the lever lands), four rivets and three cut arrows pointing
## down; the rod pivots in the middle of the plate, the wooden T grip with brass
## ends rides on it with its catch bar under. 148 × 48 like any main key; with a
## small line the nameplate widens till both lines fit (`face_w`), the housing
## riding at its right.
##
## Tapped, it pulls: the catch is lifted, the grip comes down faster and faster,
## growing as it passes the middle (it comes toward the eye), and lands in the
## bottom notch with a thud at .37 s: the plate shakes, soot puffs out of the
## slot, the lamp lights, the key sinks; `pulled` at .6 s. Dragged, the grip
## follows the finger; let go past the middle it lands (`pulled` .32 s on),
## short of it it springs back. Down, it is a plain key: a press sends
## `confirmed`.

signal pulled
signal confirmed

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const SHADER := preload("res://game/ui/lever_face.gdshader")

const CSS_SIZE := Vector2(148, 48)
const INK := Color("2a1804")
## The nameplate in the key (the base's padding 5 and rim 2), and its size.
const FACE_AT := Vector2(7, 6)
const FACE_CSS := Vector2(102, 36)
## With a small line the plate is at least this wide: 「00:00 도착 · 맑은 추위」
## (the longest stop line, 120) and 7 each side.
const SMALL_FACE_W: float = 134.0
## Room each side of the words on the plate.
const FACE_PAD: float = 7.0
## The housing: 2 in from the base's right inside its rim, 26 above its top
## (its x follows the plate: 1 past its right).
const HOUSE_AT := Vector2(110, -26)
const HOUSE_CSS := Vector2(34, 72)
const REACH_CSS: float = 12.0
## The pull (.46 s), the thud (at .37 s), the act (at .6 s; dragged, .32 s after it lands).
const PULL_S: float = 0.46
const HIT_AT: float = 0.37
const DONE_AT: float = 0.6
const DROP_DONE_S: float = 0.32
## How far the grip travels each way from the middle, mockup px.
const TRAVEL: float = 25.0
## The housing's plate as the mockup draws it (LVX).
const PLATE_SVG := '<svg xmlns="http://www.w3.org/2000/svg" width="34" height="72" viewBox="0 0 34 72"><rect x=".5" y=".5" width="33" height="71" rx="4" fill="#161a1f"/><rect x="1.5" y="1.5" width="31" height="69" rx="3.5" fill="#252b31"/><rect x="10" y="6" width="14" height="60" rx="3" fill="#6a5838"/><rect x="11.5" y="7.5" width="11" height="57" rx="2.5" fill="#3a301f"/><rect x="13" y="8" width="8" height="56" rx="4" fill="#040506"/><rect x="10" y="9" width="3" height="4" fill="#040506"/><rect x="10" y="59" width="3" height="4" fill="#040506"/><rect x="25" y="6" width="5" height="10" rx="1" fill="#39404a"/><rect x="25" y="56" width="5" height="10" rx="1" fill="#8e521b"/><path d="M3.5 28h5l-2.5 3.2zM3.5 34h5l-2.5 3.2zM3.5 40h5l-2.5 3.2z" fill="#58616a"/><g fill="#4a525a"><circle cx="5" cy="5" r="1.8"/><circle cx="29" cy="5" r="1.8"/><circle cx="5" cy="67" r="1.8"/><circle cx="29" cy="67" r="1.8"/></g><g fill="#15191d"><circle cx="5" cy="5" r=".7"/><circle cx="29" cy="5" r=".7"/><circle cx="5" cy="67" r=".7"/><circle cx="29" cy="67" r=".7"/></g></svg>'
const ROD: Array = [[0.0, Color("363c43")], [0.45, Color("6a7279")], [1.0, Color("2c3238")]]
const HUB: Array = [[0.0, Color("8b7650")], [0.7, Color("4e3f26")], [1.0, Color("4e3f26")]]
const WOOD := Color("3a271a")
const BRASS := Color("7d6a44")
const CATCH := Color("5a4a2e")
const LAMP := Color("f0ae52")

var word: String = ""
var small: String = ""
var down: bool = false
## The nameplate's width, mockup px (FACE_CSS.x, or wider for a small line).
var face_w: float = FACE_CSS.x
## The lever: 1 up … 0 toward the eye … −1 down.
var k: float = 1.0

var _body: Control
var _base: ColorRect
var _face: ColorRect
var _house: Control
var _word_l: Label
var _small_l: Label
var _plate_tex: Texture2D
var _pull_t: float = -1.0     # seconds into the pull (−1: none)
var _hit_t: float = -1.0      # seconds since the thud
var _done_in: float = -1.0    # seconds till `pulled`
var _spring: Tween = null
var _drag: Dictionary = {}    # while held: {"y0": px, "moved": bool}
var _dragged: bool = false    # the press that ends a drag is not a tap
var _sink: float = 0.0


func _init(word0: String = "", small0: String = "") -> void:
	word = word0
	small = small0
	focus_mode = Control.FOCUS_NONE
	_word_l = UiFonts.label("", UiFonts.WORD, 600, 16.0, INK, 4.48)
	_word_l.name = "Word"
	_small_l = UiFonts.label("", UiFonts.WORD, 500, 12.0, Color(INK, 0.8), 0.48)
	_small_l.name = "Small"
	face_w = fit_face_w(word, small)
	var css := key_css()
	custom_minimum_size = css * UiFonts.K
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var img := Image.new()
	if img.load_svg_from_string(PLATE_SVG, UiFonts.K * 2.0) == OK:
		_plate_tex = ImageTexture.create_from_image(img)
	_body = Control.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	var reach: float = UiFonts.px(REACH_CSS)
	_base = _part(false, css, Vector4(12, 8, 8, 12))
	_base.name = "Base"
	_base.position = -Vector2(reach, reach)
	_body.add_child(_base)
	_face = _part(true, Vector2(face_w, FACE_CSS.y), Vector4(8, 8, 8, 8))
	_face.name = "Face"
	_face.position = FACE_AT * UiFonts.K - Vector2(reach, reach)
	_body.add_child(_face)
	_body.add_child(_word_l)
	_body.add_child(_small_l)
	_house = Control.new()
	_house.name = "Lever"
	_house.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_house.position = house_at() * UiFonts.K
	_house.size = HOUSE_CSS * UiFonts.K
	_house.draw.connect(_draw_house)
	_body.add_child(_house)
	button_down.connect(_press.bind(true))
	button_up.connect(_press.bind(false))
	pressed.connect(_tap)
	set_word(word, small, false)


## The words on the plate and whether the lever is down (after the act it
## stays down and the key is a plain one: 「확인」, no small line).
func set_word(word0: String, small0: String = "", down0: bool = false) -> void:
	word = word0
	small = small0
	down = down0
	k = -1.0 if down else 1.0
	_pull_t = -1.0
	_done_in = -1.0
	_word_l.text = word
	_small_l.text = small
	_small_l.visible = small != ""
	_lay_words()
	_house.queue_redraw()


## The plate's width for these words: as drawn (102) for a word alone, else
## wide enough for the longer line with FACE_PAD each side, SMALL_FACE_W at least.
func fit_face_w(word0: String, small0: String) -> float:
	if small0 == "":
		return FACE_CSS.x
	_word_l.text = word0
	_small_l.text = small0
	var need: float = maxf(ink_w(_word_l), ink_w(_small_l)) / UiFonts.K
	return maxf(SMALL_FACE_W, ceilf(need + FACE_PAD * 2.0))


## The key's size, mockup px: the plate and the 46 round it (rim, padding, housing).
func key_css() -> Vector2:
	return Vector2(face_w + CSS_SIZE.x - FACE_CSS.x, CSS_SIZE.y)


## Where the housing sits on the key, mockup px.
func house_at() -> Vector2:
	return Vector2(FACE_AT.x + face_w + 1.0, HOUSE_AT.y)


## A plate label's inked width, game px: its letter spacing kept off the last letter.
func ink_w(l: Label) -> float:
	var f: Font = l.get_theme_font("font")
	return GlassParts.text_w(l) - float(f.get_spacing(TextServer.SPACING_GLYPH))


## Whether a pull is under way (from the tap or the drag till `pulled`).
func busy() -> bool:
	return _pull_t >= 0.0 or _done_in >= 0.0


func _part(plate: bool, css: Vector2, radii_css: Vector4) -> ColorRect:
	var reach: float = UiFonts.px(REACH_CSS)
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = css * UiFonts.K + Vector2(reach, reach) * 2.0
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("plate", plate)
	m.set_shader_parameter("part_size", css * UiFonts.K)
	m.set_shader_parameter("reach", reach)
	m.set_shader_parameter("k", UiFonts.K)
	m.set_shader_parameter("radii", radii_css * UiFonts.K)
	r.material = m
	return r


## The word and the small line centred on the plate as one column (line
## heights 1.1, the small line 3 under), letter spacing kept off the centring.
func _lay_words() -> void:
	var kk: float = UiFonts.K
	var lh_w: float = 16.0 * 1.1
	var lh_s: float = 12.0 * 1.1
	var col_h: float = lh_w + (3.0 + lh_s if small != "" else 0.0)
	var top: float = FACE_AT.y + (FACE_CSS.y - col_h) * 0.5
	var mid_x: float = (FACE_AT.x + face_w * 0.5) * kk
	var sw: float = float(UiFonts.face(UiFonts.WORD, 600, 4.48).get_spacing(TextServer.SPACING_GLYPH))
	GlassParts.put(_word_l, 0.0, top, lh_w)
	_word_l.position.x = mid_x - (GlassParts.text_w(_word_l) - sw) * 0.5
	if small != "":
		var ss: float = float(UiFonts.face(UiFonts.WORD, 500, 0.48).get_spacing(TextServer.SPACING_GLYPH))
		GlassParts.put(_small_l, 0.0, top + lh_w + 3.0, lh_s)
		_small_l.position.x = mid_x - (GlassParts.text_w(_small_l) - ss) * 0.5


## The housing above the key is the key too: its grip is what a finger takes.
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point) or Rect2(house_at() * UiFonts.K, HOUSE_CSS * UiFonts.K).has_point(point)


## Held down the key sinks 2 and brightens (.main:active).
func _press(on: bool) -> void:
	_sink = UiFonts.px(2.0) if on else 0.0
	var b: float = 1.14 if on else 1.0
	(_base.material as ShaderMaterial).set_shader_parameter("bright", b)
	(_face.material as ShaderMaterial).set_shader_parameter("bright", b)
	_body.position.y = _sink


func _tap() -> void:
	if _dragged:
		_dragged = false
		return
	if down:
		if not busy():
			confirmed.emit()
		return
	if busy():
		return
	_pull_t = 0.0
	_done_in = DONE_AT
	set_process(true)


func _gui_input(e: InputEvent) -> void:
	if down or busy():
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if e.is_pressed():
			_dragged = false
			_drag = {"y0": (e as InputEventMouseButton).position.y, "moved": false}
		elif not _drag.is_empty():
			var moved: bool = bool(_drag["moved"])
			_drag = {}
			if moved:
				_dragged = true
				_let_go()
	elif e is InputEventMouseMotion and not _drag.is_empty():
		var dy: float = ((e as InputEventMouseMotion).position.y - float(_drag["y0"])) / UiFonts.K
		if not bool(_drag["moved"]) and absf(dy) > 6.0:
			_drag["moved"] = true
			if _spring:
				_spring.kill()
		if bool(_drag["moved"]):
			k = clampf(1.0 - dy / TRAVEL, -1.0, 1.0)
			_house.queue_redraw()


## A drag let go: past the middle the lever lands, short of it it springs back.
func _let_go() -> void:
	if k < 0.0:
		k = -1.0
		down = true
		_hit()
		_done_in = DROP_DONE_S
		set_process(true)
		return
	if _spring:
		_spring.kill()
	_spring = create_tween()
	_spring.tween_method(func(v: float) -> void:
		k = v
		_house.queue_redraw(), k, 1.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hit() -> void:
	_hit_t = 0.0
	Input.vibrate_handheld(32)
	set_process(true)


func _process(delta: float) -> void:
	var live := false
	if _pull_t >= 0.0:
		var was: float = _pull_t
		_pull_t += delta
		k = _pull_k(_pull_t)
		if was < HIT_AT and _pull_t >= HIT_AT:
			down = true
			_hit()
		if _pull_t >= PULL_S:
			_pull_t = -1.0
			k = -1.0
		else:
			live = true
	if _hit_t >= 0.0:
		_hit_t += delta
		if _hit_t >= 0.8:
			_hit_t = -1.0
		else:
			live = true
	# The thud: the key down 2 at 30 % of .22 s and back.
	var thud: float = 0.0
	if _hit_t >= 0.0 and _hit_t < 0.22:
		var f: float = _hit_t / 0.22
		thud = (f / 0.3 if f < 0.3 else 1.0 - _ease_out((f - 0.3) / 0.7)) * UiFonts.px(2.0)
	_body.position.y = _sink + thud
	if _done_in >= 0.0:
		_done_in -= delta
		if _done_in <= 0.0:
			_done_in = -1.0
			pulled.emit()
		else:
			live = true
	_house.queue_redraw()
	if not live:
		set_process(false)


## The lever's place `t` seconds into the pull (@keyframes lvPull): up a hair
## by 15 %, down past the bottom by 80 % gathering speed, settling by the end.
func _pull_k(t: float) -> float:
	var f: float = t / PULL_S
	if f < 0.15:
		return lerpf(1.0, 1.05, _ease_out(f / 0.15))
	if f < 0.8:
		return lerpf(1.05, -1.1, _bezier((f - 0.15) / 0.65, 0.55, 0.0, 0.9, 0.4))
	return lerpf(-1.1, -1.0, _ease_out(clampf((f - 0.8) / 0.2, 0.0, 1.0)))


## How far the catch is lifted `t` seconds into the pull (@keyframes lvCatch).
func _catch_lift(t: float) -> float:
	var f: float = t / PULL_S
	if f < 0.0 or f >= 0.86:
		return 0.0
	if f < 0.12:
		return -2.5 * f / 0.12
	if f < 0.72:
		return -2.5
	return -2.5 * (1.0 - (f - 0.72) / 0.14)


func _draw_house() -> void:
	var kk: float = UiFonts.K
	var ci: CanvasItem = _house
	# The plate shakes as the lever lands (@keyframes lvShake, steps(4)).
	var shake := Vector2.ZERO
	if _hit_t >= 0.0 and _hit_t < 0.18:
		shake = ([Vector2.ZERO, Vector2(-1.5, 1.0), Vector2(1.5, -1.0), Vector2(-1.0, 0.5)] as Array)[mini(3, int(_hit_t / 0.045))]
	# drop-shadow(0 2px 3px rgba(0,0,0,.55)) under the housing.
	GlassParts.shadow(ci, Rect2((Vector2(0.5, 0.5) + shake) * kk, (HOUSE_CSS - Vector2.ONE) * kk), 4.0 * kk, 2.0 * kk, 3.0 * kk, Color(0, 0, 0, 0.55))
	if _plate_tex:
		ci.draw_texture_rect(_plate_tex, Rect2(shake * kk, HOUSE_CSS * kk), false)
	# The lamp at the foot: lit while the lever is down, flaring as it lands.
	var lamp_a: float = 0.85 if down else 0.0
	var glow: float = 8.0
	if _hit_t >= 0.0 and _hit_t < 0.7:
		var f: float = _ease_out(_hit_t / 0.7)
		lamp_a = lerpf(1.0, 0.85, f)
		glow = lerpf(14.0, 8.0, f)
	if lamp_a > 0.0:
		var lr := Rect2((Vector2(25, 56) + shake) * kk, Vector2(5, 10) * kk)
		for i in 4:
			var grow: float = glow * kk * float(4 - i) / 4.0 * 0.5
			GlassParts.round_rect(ci, lr.grow(grow), 1.0 * kk + grow, Color(LAMP, lamp_a * 0.12))
		GlassParts.round_rect(ci, lr, 1.0 * kk, Color(LAMP, lamp_a))
	# The rod: from the pivot (17, 36) up when the lever is up, down when it is down.
	var len_css: float = TRAVEL * absf(k)
	if len_css > 0.3:
		var top: float = 36.0 - TRAVEL * k if k > 0.0 else 36.0
		GlassParts.grad_rect(ci, Rect2(Vector2(14.5, top) * kk, Vector2(5.0, len_css) * kk), 2.5 * kk, ROD)
	_disc(ci, Vector2(17, 36) * kk, 5.0 * kk, Vector2(-1.0, -1.2) * kk, 8.63 * kk, HUB, Color(0, 0, 0, 0.6))
	# The grip rides down with the lever and grows toward the eye in the middle.
	var s: float = 1.0 + (1.0 - k * k) * 0.16
	var at := Vector2(17.0, 11.0 + (1.0 - k) * TRAVEL) * kk
	ci.draw_set_transform(at, 0.0, Vector2(s, s))
	var grip := Rect2(Vector2(-19, -7) * kk, Vector2(38, 14) * kk)
	GlassParts.shadow(ci, grip, 7.0 * kk, 3.0 * kk, 4.0 * kk, Color(0, 0, 0, 0.6))
	GlassParts.round_rect(ci, grip, 7.0 * kk, BRASS)
	ci.draw_rect(Rect2(Vector2(-13, -7) * kk, Vector2(26, 14) * kk), WOOD)
	# The grain, a dark line every 4 from the grip's left edge, under the brass ends.
	var x: float = -12.0
	while x <= 12.0:
		ci.draw_rect(Rect2(Vector2(x, -7.0) * kk, Vector2(1.0, 14.0) * kk), Color(0, 0, 0, 0.16))
		x += 4.0
	ci.draw_rect(Rect2(Vector2(-16, 4) * kk, Vector2(32, 3) * kk), Color(0, 0, 0, 0.34))
	var lift: float = _catch_lift(_pull_t) if _pull_t >= 0.0 else 0.0
	var cr := Rect2(Vector2(-9.0, 8.0 + lift) * kk, Vector2(18, 4) * kk)
	GlassParts.shadow(ci, cr, 2.0 * kk, 1.0 * kk, 2.0 * kk, Color(0, 0, 0, 0.5))
	GlassParts.round_rect(ci, cr, 2.0 * kk, CATCH)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Soot puffing out of the slot as it lands (@keyframes lvPuff).
	if _hit_t >= 0.0 and _hit_t < 0.8:
		var f: float = _ease_out(_hit_t / 0.8)
		var r: float = 16.0 * lerpf(0.3, 1.7, f) * kk
		var c := Vector2(17.0, 62.0 - 6.0 * f) * kk
		var a: float = 0.85 * (1.0 - f)
		for i in 6:
			var rr: float = r * float(6 - i) / 6.0
			ci.draw_circle(c, rr, Color(140 / 255.0, 132 / 255.0, 120 / 255.0, 0.6 * a / 6.0 * 1.6))


## A disc lit from `focus` off its centre (radial-gradient(circle at …)):
## rings of colour out to `reach` from the focus, and its shadow under it.
func _disc(ci: CanvasItem, c: Vector2, r: float, focus: Vector2, reach: float, stops: Array, shade: Color) -> void:
	ci.draw_circle(c + Vector2(0, 1.0 * UiFonts.K), r + 0.8 * UiFonts.K, Color(shade, shade.a * 0.5), true, -1.0, true)
	var rings: int = 5
	var seg: int = 28
	var f0: Vector2 = c + focus
	for j in range(rings, 0, -1):
		var rr: float = r * float(j) / float(rings)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in seg:
			var a: float = TAU * float(i) / float(seg)
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * rr
			pts.append(p)
			cols.append(GlassParts.grad_at(stops, p.distance_to(f0) / reach))
		ci.draw_polygon(pts, cols)


static func _ease_out(f: float) -> float:
	return 1.0 - pow(1.0 - clampf(f, 0.0, 1.0), 2.0)


## CSS cubic-bezier(x1, y1, x2, y2) at progress `f`.
static func _bezier(f: float, x1: float, y1: float, x2: float, y2: float) -> float:
	f = clampf(f, 0.0, 1.0)
	var u: float = f
	for i in 8:
		var x: float = 3.0 * (1.0 - u) * (1.0 - u) * u * x1 + 3.0 * (1.0 - u) * u * u * x2 + u * u * u
		var dx: float = 3.0 * (1.0 - u) * (1.0 - u) * x1 + 6.0 * (1.0 - u) * u * (x2 - x1) + 3.0 * u * u * (1.0 - x2)
		if absf(dx) < 1e-5:
			break
		u = clampf(u - (x - f) / dx, 0.0, 1.0)
	return 3.0 * (1.0 - u) * (1.0 - u) * u * y1 + 3.0 * (1.0 - u) * u * u * y2 + u * u * u
