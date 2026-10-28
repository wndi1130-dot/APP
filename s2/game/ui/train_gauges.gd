extends Control
## The train's gauges along the top (UI 3단계 시안 2차 위 띠 .hud--top, B1 「성에
## 낀 계기」), measured part by part (the mockup's px × ui_fonts.gd K): trust and
## tension at the left as bars with their 조심 구간 under them, unrest | support
## in the middle between two matte medals, then coal, food, medicine and luxury
## at the right with what a stretch costs and how many stretches it lasts.
## Every number is the train's own (train_turn.gd forecast and standings, the
## state's stock); the strip only reads and draws. It sits on the soot that
## smokes down from the top of the screen (tex/edge_top.png).
##
## The bars (디자인 토큰 2차 「계기 빛 둘」, user 2026-10-17): trust is a living
## grass bar whose lost share is dry earth with fine cracks, drier as it falls;
## tension glows from coal to fire along the gauge's width and the glass over
## it cracks once more past 30, 50 and 70. 주의 · 위험 (토큰 2차 「상태」): tension
## above 50 · 70, trust below 45 · 30, with a lamp tag by the number.
## After tension the outside thermometer (시안 2차 ② .otemp) reads the train's
## climate (train_climate.gd outside_view): the stage's name and the shown
## temperature, a column in a glass tube with a tick at each stage, frost on the
## glass as the stages get colder, a snow mark while the track is frozen. A
## board with climate off has none.
##
## While a sheet is up only what it is about stays lit (`focus`); the rest
## fades to a third and loses most of its colour (.hud--top .is-dim).
##
## Coal and food are keys: a press asks for what a stretch costs and why
## (`stock_pressed`, the slice opens cost_pane.gd; J12). Nothing else takes a
## press.

## A stock among TAPPABLE pressed: "coal" or "food".
signal stock_pressed(id: String)

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")
const EDGE_TOP := preload("res://game/ui/tex/edge_top.png")

## The band (48) and how far its soot smokes down (92), in game px.
const BAND_H: float = 48.0 * 720.0 / 390.0
const SOOT_H: float = 92.0 * 720.0 / 390.0
## 디자인 토큰 2차.
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const INK3 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.54)
const WELL := Color(0, 0, 0, 0.6)
const MID := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.22)
const RED := Color("e2604b")
const RED_L := Color("f29078")
const SKY := Color("8bd0f2")
const SKY_L := Color("c0e7f9")
const WARN := Color("f2a63c")
const AMBER_L := Color("ffc66c")
const TAG_INK := Color("1a1208")
const TRUST := Color("a9c08e")
const DRY := Color("8a7655")
const CRACK_TILE := Color(162 / 255.0, 140 / 255.0, 100 / 255.0, 0.8)
const CRACK_DARK := Color(58 / 255.0, 46 / 255.0, 28 / 255.0, 0.7)
const HEAT: Array = [[0.0, Color("6a3519")], [0.34, Color("a2491f")], [0.62, Color("e47b3c")], [1.0, Color("ffc488")]]
const SOOT_CUT := Color("10151a")
## 조심 구간 (k2_parts.js MT): trust is in danger low, tension high.
const ZONES: Dictionary = {"trust": {"low": true, "warn": 45, "bad": 30}, "tension": {"low": false, "warn": 50, "bad": 70}}
## A stock that lasts this many stretches or fewer is short (red, underlined).
const SHORT_LEFT: int = 3
const STOCKS: Array = [["coal", "coal", "석탄"], ["food", "food", "식량"], ["med", "med", "의약품"], ["lux", "lux", "사치품"]]
## The stocks whose press opens what a stretch costs (cost_pane.gd).
const TAPPABLE: Array = ["coal", "food"]
## The trust well's cracks: one 24 × 8 tile, repeated (c9.css).
const TILE_CRACKS: Array = [
	[Vector2(0, 3.4), Vector2(3.6, 2.5), Vector2(6.4, 4.7), Vector2(10.2, 3.9), Vector2(13.4, 1.3), Vector2(17, 3.7), Vector2(21, 2.9), Vector2(24, 3.4)],
	[Vector2(6.4, 4.7), Vector2(7.5, 8)], [Vector2(3.1, 0), Vector2(3.6, 2.5)],
	[Vector2(17, 3.7), Vector2(18.3, 6.5), Vector2(21.6, 7.4)], [Vector2(10.2, 3.9), Vector2(11.6, 6.2)],
]
## The tension glass's cracks (k3g_fx.js): past 30, 50 and 70 one more layer,
## each [angle (0 right, −90 up), length, branches]; drawn from a fixed seed.
const CK_W: float = 104.0
const CK_Y: float = 40.0
const CK_TH: Array = [30, 50, 70]
const CK_SET: Array = [[[-128, 12, 1]], [[-60, 17, 1], [24, 6, 0]], [[-100, 25, 2], [-166, 22, 1], [148, 9, 0]]]

## The outside thermometer's colours a stage, warmest first (.otemp data-st):
## the column's foot and head, the number. S1 has six stages to the mockup's
## five; 첫 추위 sits halfway between 늦가을 (the mockup's 풀림) and 추위.
const OT_COLS: Array = [
	[Color("a39478"), Color("d4c9b0"), INK],
	[Color("999890"), Color("cbcac2"), INK],
	[Color("8e9ca8"), Color("c2ccd4"), INK],
	[Color("7f9bb2"), Color("c6d8e5"), Color("dde6ec")],
	[Color("6f98bb"), Color("d3e5f1"), Color("d2e5f2")],
	[Color("8dbfe2"), Color("eef7fc"), Color("eaf6fd")],
]
## How thick the frost on the glass lies a stage (.otemp__fr opacity).
const OT_FROST: Array = [0.0, 0.06, 0.12, 0.26, 0.5, 0.78]
## Where the column's head stands at the warmest and the coldest stage's
## temperature (share of the tube; otH's 90 and 29), and how far it may go.
const OT_TOP: float = 0.9
const OT_LOW: float = 0.29
const OT_CLAMP: Vector2 = Vector2(0.18, 0.96)
const OT_GLASS := Color(5 / 255.0, 8 / 255.0, 11 / 255.0, 0.82)
const OT_RIM := Color(208 / 255.0, 218 / 255.0, 226 / 255.0, 0.34)
const OT_TICK := Color(214 / 255.0, 224 / 255.0, 232 / 255.0, 0.62)
const OT_FERN := Color(232 / 255.0, 242 / 255.0, 248 / 255.0)
const OT_COLD_WORD := Color("b9cfdf")
const OT_FREEZE := Color("c2ccd4")
const OT_FROST_INK := Color("1f2b36")
const OT_FROZEN_GLOW := Color(190 / 255.0, 228 / 255.0, 250 / 255.0, 0.65)

var g: Dictionary = {}
var t: Dictionary = {}
## What stays lit while a sheet is up ("trust", "tension", "mood", "coal" …); empty: all.
var focus: Array = []
var _parts: Control


## What the strip says for state `g0` (tests read this; the strip draws it).
static func model(g0: Dictionary, t0: Dictionary) -> Dictionary:
	if g0.is_empty() or t0.is_empty():
		return {}
	var cost: Dictionary = TrainTurn.forecast(g0, t0)
	var stand: Dictionary = TrainTurn.standings(g0, t0)
	var stocks: Array = []
	for s: Array in STOCKS:
		var n: int = int(round(float(g0.get(s[0], 0))))
		var entry := {"id": s[0], "icon": s[1], "word": s[2], "n": n, "line": "", "per": "", "left": -1, "short": false}
		if cost.has(s[0]) and float(cost[s[0]]) > 0.0:
			var per: float = float(cost[s[0]])
			var left: int = int(floor(float(n) / per))
			entry["per"] = "−" + _num(per)
			entry["left"] = left
			entry["line"] = "−%s · %d구간" % [_num(per), left]
			entry["short"] = left <= SHORT_LEFT
		stocks.append(entry)
	var trust: int = int(round(float(g0.get("trust", 0))))
	var tension: int = int(round(float(g0.get("tension", 0))))
	var outside: Variant = TrainClimate.outside_view(g0, t0)
	if outside is Dictionary:
		var temps: Array = t0["CL"]["temp"]
		outside["text"] = deg(float(outside["temp"]))
		outside["fill"] = ot_fill(temps, float(outside["temp"]))
		var ticks: Array = []
		for x: Variant in temps:
			ticks.append(ot_fill(temps, float(x)))
		outside["ticks"] = ticks
	return {
		"outside": outside,
		"trust": trust,
		"tension": tension,
		"trust_level": level("trust", trust),
		"tension_level": level("tension", tension),
		"unrest": int(stand["unrest"]),
		"neutral": int(stand["neutral"]),
		"support": int(stand["support"]),
		"stocks": stocks,
	}


## 0 calm, 1 주의, 2 위험 for gauge `key` at `v` (k2_parts.js mLevel).
static func level(key: String, v: int) -> int:
	var z: Dictionary = ZONES[key]
	if bool(z["low"]):
		return 2 if v < int(z["bad"]) else (1 if v < int(z["warn"]) else 0)
	return 2 if v > int(z["bad"]) else (1 if v > int(z["warn"]) else 0)


## 8.5 → "8.5", 10.0 → "10".
static func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, round(x)) else "%.1f" % x


## A temperature as the thermometer writes it: −3°, 5° (tfmt).
static func deg(x: float) -> String:
	return ("−" if x < 0.0 else "") + _num(absf(x)) + "°"


## Where the column's head stands in the tube for `temp` (0–1): the warmest
## stage's temperature at OT_TOP, the coldest's at OT_LOW, a line between.
static func ot_fill(temps: Array, temp: float) -> float:
	var hi: float = float(temps[0])
	var lo: float = float(temps[temps.size() - 1])
	return clampf(OT_TOP - (hi - temp) * (OT_TOP - OT_LOW) / maxf(hi - lo, 1.0), OT_CLAMP.x, OT_CLAMP.y)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, BAND_H)
	offset_bottom = BAND_H
	var soot := TextureRect.new()
	soot.name = "Soot"
	soot.texture = EDGE_TOP
	soot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	soot.stretch_mode = TextureRect.STRETCH_SCALE
	soot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soot.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	soot.offset_bottom = SOOT_H
	add_child(soot)
	_parts = Control.new()
	_parts.name = "Parts"
	_parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_parts)
	resized.connect(_lay_out)
	refresh(g, t)


## Draw the strip again for state `g0`.
func refresh(g0: Dictionary, t0: Dictionary) -> void:
	g = g0
	t = t0
	if _parts == null:
		return
	for c in _parts.get_children():
		_parts.remove_child(c)
		c.queue_free()
	var m: Dictionary = model(g, t)
	if m.is_empty():
		return
	_parts.add_child(_meter("trust", "신임", int(m["trust"]), int(m["trust_level"])))
	_parts.add_child(_meter("tension", "긴장", int(m["tension"]), int(m["tension_level"])))
	if m["outside"] is Dictionary:
		_parts.add_child(_outside(m["outside"]))
	_parts.add_child(_standing(int(m["unrest"]), int(m["neutral"]), int(m["support"])))
	var right := HBoxContainer.new()
	right.name = "Stocks"
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 0)
	for s: Dictionary in m["stocks"]:
		right.add_child(_stock(s))
	_parts.add_child(right)
	_lay_out()


## Light only `ids` (empty: all) and draw again.
func set_focus(ids: Array) -> void:
	focus = ids
	refresh(g, t)


func _dim(id: String) -> bool:
	return not focus.is_empty() and not focus.has(id)


## A colour as a dimmed part shows it: saturate(.3), then a third of its alpha.
static func tone(c: Color, dim: bool) -> Color:
	return GlassParts.tone(c, dim)


## The mockup's places: .hud__l at 12 with 10 between (trust, tension, the
## thermometer), the mood centred 8 left of the middle, .hud__r ending 12 from
## the right.
func _lay_out() -> void:
	if _parts == null:
		return
	var k: float = UiFonts.K
	var trust: Control = _parts.get_node_or_null("MeterTrust")
	var tension: Control = _parts.get_node_or_null("MeterTension")
	var outside: Control = _parts.get_node_or_null("Outside")
	var mood: Control = _parts.get_node_or_null("Standing")
	var right: Control = _parts.get_node_or_null("Stocks")
	if trust:
		trust.position = Vector2(12.0 * k, 0)
	if tension:
		tension.position = Vector2((12.0 + 104.0 + 10.0) * k, 0)
	if outside:
		outside.position = Vector2((12.0 + 104.0 + 10.0 + 104.0 + 10.0) * k, 0)
	if mood:
		mood.position = Vector2(size.x * 0.5 - 8.0 * k - mood.size.x * 0.5, 1.0 * k)
	if right:
		right.size = right.get_combined_minimum_size()
		right.position = Vector2(size.x - 12.0 * k - right.size.x, 0)


func _label(text: String, kind: int, weight: int, css_px: float, color: Color, spacing: float = 0.0) -> Label:
	return UiFonts.label(text, kind, weight, css_px, color, spacing)


## Put `l` so its baseline falls at `base_css` (mockup px from the part's top).
func _sit(l: Label, x_css: float, base_css: float) -> void:
	GlassParts.put_on(l, x_css * UiFonts.K, base_css * UiFonts.K)


## How wide `l`'s words are, in mockup px (measured off its face, so it holds
## before the label is laid out).
func _text_w(l: Label) -> float:
	var f: Font = l.get_theme_font("font")
	var px: int = l.get_theme_font_size("font_size")
	return f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / UiFonts.K


## A gauge (.meter, 104 × 48): its mark (trust · tension in the word's place:
## decisions.md 「계기는 글자 대신 아이콘과 숫자」, 결정 417) and number on one
## baseline (28.5),
## a 주의 · 위험 tag at the right when it is in a zone, the bar at 36 and the
## zones under it at 47.
func _meter(key: String, word: String, n: int, lv: int) -> Control:
	var dim: bool = _dim(key)
	var c := Control.new()
	c.name = "Meter" + ("Trust" if key == "trust" else "Tension")
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(104, 48) * UiFonts.K
	var bar := Control.new()
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(0, 0)
	bar.size = c.size
	bar.draw.connect(_draw_meter.bind(bar, key, n, lv, dim))
	c.add_child(bar)
	var mark := TextureRect.new()
	mark.name = "Mark"
	var px: int = int(round(18.0 * UiFonts.K))
	mark.texture = HudIcons.texture(key, px, tone(INK2, dim), 2.0, tone(SOOT_CUT, dim))
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2(px, px)
	mark.position = Vector2(0.0, 12.0) * UiFonts.K
	mark.tooltip_text = word
	c.add_child(mark)
	var num := _label(str(n), UiFonts.NUMBER, 500, 25.0, tone(WARN if lv > 0 else INK, dim), 0.375)
	num.name = "Value"
	c.add_child(num)
	_sit(num, 18.0 + 5.0, 28.5)
	if lv > 0:
		var tag := _label("위험" if lv > 1 else "주의", UiFonts.WORD, 600, 12.0, tone(AMBER_L if lv > 1 else TAG_INK, dim), 1.2)
		tag.name = "Tag"
		var sb := StyleBoxFlat.new()
		sb.bg_color = tone(TAG_INK if lv > 1 else WARN, dim)
		sb.set_corner_radius_all(int(round(2.0 * UiFonts.K)))
		sb.content_margin_left = 6.0 * UiFonts.K
		sb.content_margin_right = 6.0 * UiFonts.K
		if lv > 1:
			sb.set_border_width_all(int(round(2.0 * UiFonts.K)))
			sb.border_color = tone(WARN, dim)
			sb.shadow_color = tone(Color(242 / 255.0, 166 / 255.0, 60 / 255.0, 0.7), dim)
			sb.shadow_size = int(round(4.0 * UiFonts.K))
		tag.add_theme_stylebox_override("normal", sb)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.custom_minimum_size = Vector2(0, 18.0 * UiFonts.K)
		c.add_child(tag)
		tag.size = tag.get_combined_minimum_size()
		tag.position = Vector2(c.size.x - tag.size.x, (19.0 - 9.0) * UiFonts.K)
	return c


func _draw_meter(ci: Control, key: String, n: int, lv: int, dim: bool) -> void:
	var k: float = UiFonts.K
	var w: float = 104.0 * k
	var bar := Rect2(0, 36.0 * k, w, 8.0 * k)
	var r: float = 4.0 * k
	# The zones under the bar (.mz, 3 high at 47; the stronger at .9, the other .38).
	var z: Dictionary = ZONES[key]
	var spans: Array = []
	if bool(z["low"]):
		spans = [[0, int(z["bad"]), 0.9], [int(z["bad"]), int(z["warn"]), 0.38]]
	else:
		spans = [[int(z["warn"]), int(z["bad"]), 0.38], [int(z["bad"]), 100, 0.9]]
	for sp: Array in spans:
		var col := Color(WARN.r, WARN.g, WARN.b, float(sp[2]))
		ci.draw_rect(Rect2(w * sp[0] / 100.0, 47.0 * k, w * (sp[1] - sp[0]) / 100.0, 3.0 * k), tone(col, dim))
	# The well, with its inset shade along the top.
	_round_rect(ci, bar, r, tone(WELL, dim))
	ci.draw_rect(Rect2(bar.position.x + r, bar.position.y, bar.size.x - r * 2.0, 1.0 * k), tone(Color(0, 0, 0, 0.3), dim))
	var at: float = w * clampf(n / 100.0, 0.0, 1.0)
	if key == "trust":
		# Dry earth's fine cracks along the whole well; the grass over its share.
		_tile_cracks(ci, bar, tone(CRACK_TILE, dim))
		var grass: Color = TRUST
		if lv == 1:
			grass = TRUST.lerp(DRY, 0.48)
		elif lv == 2:
			grass = TRUST.lerp(DRY, 0.76)
		if at > 0.5:
			_round_rect(ci, Rect2(bar.position, Vector2(maxf(at, r * 2.0), bar.size.y)), r, tone(grass, dim))
			if lv == 2:
				_tile_cracks(ci, Rect2(bar.position, Vector2(at, bar.size.y)), tone(CRACK_DARK, dim))
	else:
		# Coal to fire across the gauge's width, lit up to the value.
		if at > 0.5:
			_heat_rect(ci, Rect2(bar.position, Vector2(maxf(at, r * 2.0), bar.size.y)), w, r, dim, lv == 2)
		_glass_cracks(ci, n, lv, dim)


## A rounded rect with soft edges.
func _round_rect(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(round(radius)))
	sb.corner_detail = 8
	sb.anti_aliasing_size = 0.7
	ci.draw_style_box(sb, rect)


func _tile_cracks(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	var k: float = UiFonts.K
	var x0: float = rect.position.x
	while x0 < rect.end.x:
		for path: Array in TILE_CRACKS:
			var pts := PackedVector2Array()
			for p: Vector2 in path:
				pts.append(Vector2(minf(x0 + p.x * k, rect.end.x), rect.position.y + p.y * k))
			ci.draw_polyline(pts, col, 0.9 * k * 0.6, true)
		x0 += 24.0 * k


## The heat's gradient over the gauge's whole width, clipped to the lit share.
func _heat_rect(ci: CanvasItem, rect: Rect2, full_w: float, radius: float, dim: bool, glow: bool) -> void:
	if glow:
		var halo := StyleBoxFlat.new()
		halo.bg_color = Color(0, 0, 0, 0)
		halo.shadow_color = tone(Color(228 / 255.0, 123 / 255.0, 60 / 255.0, 0.85), dim)
		halo.shadow_size = int(round(7.0 * UiFonts.K * 0.6))
		halo.set_corner_radius_all(int(round(radius)))
		ci.draw_style_box(halo, rect)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	# Top edge left → right, then bottom edge right → left, rounding both ends.
	var outline: Array = _pill_outline(rect, radius)
	for p: Vector2 in outline:
		pts.append(p)
		cols.append(tone(_heat_at(p.x / full_w), dim))
	ci.draw_polygon(pts, cols)
	pts.append(pts[0])
	cols.append(cols[0])
	ci.draw_polyline_colors(pts, cols, 1.0, true)


static func _heat_at(f: float) -> Color:
	f = clampf(f, 0.0, 1.0)
	for i in range(1, HEAT.size()):
		var a: Array = HEAT[i - 1]
		var b: Array = HEAT[i]
		if f <= float(b[0]):
			return (a[1] as Color).lerp(b[1], (f - float(a[0])) / (float(b[0]) - float(a[0])))
	return HEAT[HEAT.size() - 1][1]


## The outline of a rect with round ends, many points along its long edges so
## a colour per point follows the gradient.
static func _pill_outline(rect: Rect2, radius: float) -> Array:
	var out: Array = []
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var n: int = 6
	var x0: float = rect.position.x + r
	var x1: float = rect.end.x - r
	var cy: float = rect.position.y + rect.size.y * 0.5
	var step: float = 3.0
	var x: float = x0
	while x < x1:
		out.append(Vector2(x, rect.position.y))
		x += step
	for i in n + 1:
		var a: float = -PI * 0.5 + PI * float(i) / float(n)
		out.append(Vector2(x1 + cos(a) * r, cy + sin(a) * r * (rect.size.y * 0.5) / r))
	x = x1
	while x > x0:
		out.append(Vector2(x, rect.end.y))
		x -= step
	for i in n + 1:
		var a: float = PI * 0.5 + PI * float(i) / float(n)
		out.append(Vector2(x0 + cos(a) * r, cy + sin(a) * r * (rect.size.y * 0.5) / r))
	return out


## The glass over the tension bar: one more layer of cracks past each of 30,
## 50 and 70, from the bar's middle (y 40 of a 48 box whose top is 36 above
## the bar). A white hairline over a dark shade; in danger an ember glow under.
func _glass_cracks(ci: CanvasItem, n: int, lv: int, dim: bool) -> void:
	var tiers: int = 3 if n >= 70 else (2 if n >= 50 else (1 if n >= 30 else 0))
	var k: float = UiFonts.K
	var origin := Vector2(0, 0)
	for tier in range(1, tiers + 1):
		for path: Array in _tier_paths(tier):
			var pts := PackedVector2Array()
			for p: Vector2 in path:
				pts.append(origin + p * k)
			if lv == 2:
				ci.draw_polyline(pts, tone(Color(228 / 255.0, 123 / 255.0, 60 / 255.0, 0.36), dim), 2.6 * k * 0.7, true)
			var shade := PackedVector2Array()
			for p: Vector2 in pts:
				shade.append(p + Vector2(0.7, 0.7) * k)
			ci.draw_polyline(shade, tone(Color(0, 0, 0, 0.6), dim), 1.2 * k * 0.6, true)
			ci.draw_polyline(pts, tone(Color(232 / 255.0, 240 / 255.0, 245 / 255.0, 0.66), dim), 0.9 * k * 0.6, true)
		if tier == 3:
			var x: float = 70.0 / 100.0 * CK_W
			var chip := PackedVector2Array([Vector2(x - 2, CK_Y - 1), Vector2(x + 1.5, CK_Y - 3.5), Vector2(x + 2.5, CK_Y + 0.5)])
			for i in chip.size():
				chip[i] = origin + chip[i] * k
			ci.draw_colored_polygon(chip, tone(Color(232 / 255.0, 240 / 255.0, 245 / 255.0, 0.18), dim))


## The cracks of one layer (k3g_fx.js ckTierPaths): the same seeded walk as the
## mockup, so the glass breaks in the same places.
static func _tier_paths(tier: int) -> Array:
	var rng := [((7 * 31 + (tier - 1) * 977) & 0xFFFFFFFF)]
	var x: float = float(CK_TH[tier - 1]) / 100.0 * CK_W
	var out: Array = []
	for layer: Array in CK_SET[tier - 1]:
		out.append_array(_crack_line(rng, x, CK_Y, float(layer[0]), float(layer[1]), int(layer[2])))
	return out


static func _rand(rng: Array) -> float:
	rng[0] = (int(rng[0]) * 1664525 + 1013904223) & 0xFFFFFFFF
	return float(rng[0]) / 4294967296.0


static func _crack_line(rng: Array, x: float, y: float, a: float, length: float, branches: int) -> Array:
	var pts: Array = [Vector2(x, y)]
	var d: float = 0.0
	var ang: float = a
	while d < length:
		var s: float = 2.6 + _rand(rng) * 2.4
		ang = a + (ang - a) * 0.6 + (_rand(rng) - 0.5) * 48.0
		var last: Vector2 = pts[pts.size() - 1]
		var rad: float = deg_to_rad(ang)
		pts.append(Vector2(last.x + cos(rad) * s, maxf(2.0, last.y + sin(rad) * s)))
		d += s
	var out: Array = [pts]
	for kk in branches:
		var i: int = maxi(1, int(floor(pts.size() * (0.35 + _rand(rng) * 0.3))))
		var side: float = 1.0 if kk % 2 == 1 else -1.0
		var p: Vector2 = pts[i]
		out.append_array(_crack_line(rng, p.x, p.y, a + side * (32.0 + _rand(rng) * 22.0), length * 0.4, 0))
	return out


## Unrest | support (.mood, 206 × 50): a medal each side (44), between them
## the seats in numbers over one bar split three ways with the half marked.
func _standing(unrest: int, neutral: int, support: int) -> Control:
	var dim: bool = _dim("mood")
	var k: float = UiFonts.K
	var c := Control.new()
	c.name = "Standing"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(206, 50) * k
	c.add_child(_medal("fist", RED, Vector2(0, 3), dim))
	c.add_child(_medal("hand", SKY, Vector2(162, 3), dim))
	var x0: float = 47.0
	var u := _label(str(unrest), UiFonts.NUMBER, 500, 21.0, tone(RED, dim), 0.315)
	u.name = "Unrest"
	c.add_child(u)
	_sit(u, x0, 27.0)
	var s := _label(str(support), UiFonts.NUMBER, 500, 21.0, tone(SKY, dim), 0.315)
	s.name = "Support"
	c.add_child(s)
	_sit(s, x0 + 112.0 - _text_w(s), 27.0)
	var bar := Control.new()
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(x0, 33.0) * k
	bar.size = Vector2(112, 8) * k
	var total: float = float(maxi(1, unrest + neutral + support))
	bar.draw.connect(func() -> void:
		var w: float = bar.size.x
		var h: float = bar.size.y
		var gap: float = 2.0 * k
		var room: float = w - gap * 2.0
		var a: float = room * unrest / total
		var b: float = room * support / total
		var m: float = room - a - b
		var rr: float = 4.0 * k
		# A faint drop under the three (0 1px 2px .4), then each with its light along the top.
		_split_round(bar, Rect2(0, 1.0 * k, w, h), rr, tone(Color(0, 0, 0, 0.3), dim), true, true)
		if a > 0.5:
			_v_grad(bar, Rect2(0, 0, a, h), rr, true, false, tone(RED_L, dim), tone(RED, dim))
		if m > 0.5:
			_split_round(bar, Rect2(a + gap, 0, m, h), rr, tone(MID, dim), false, false)
		if b > 0.5:
			_v_grad(bar, Rect2(w - b, 0, b, h), rr, false, true, tone(SKY_L, dim), tone(SKY, dim))
		bar.draw_rect(Rect2(rr, 0, w - rr * 2.0, 1.0 * k * 0.6), tone(Color(1, 1, 1, 0.25), dim))
		# The half mark: a majority is past it.
		var mark := StyleBoxFlat.new()
		mark.bg_color = tone(Color(INK.r, INK.g, INK.b, 0.85), dim)
		mark.set_corner_radius_all(int(round(1.0 * k)))
		bar.draw_style_box(mark, Rect2(w * 0.5 - 1.0 * k, -3.0 * k, 2.0 * k, 14.0 * k)))
	c.add_child(bar)
	return c


## A rect rounded only at the ends asked for.
func _split_round(ci: CanvasItem, rect: Rect2, r: float, col: Color, left: bool, right: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	var rr: int = int(round(r))
	sb.corner_radius_top_left = rr if left else 0
	sb.corner_radius_bottom_left = rr if left else 0
	sb.corner_radius_top_right = rr if right else 0
	sb.corner_radius_bottom_right = rr if right else 0
	sb.corner_detail = 8
	sb.anti_aliasing_size = 0.7
	ci.draw_style_box(sb, rect)


## A rect with a top-to-bottom gradient, rounded at the ends asked for.
func _v_grad(ci: CanvasItem, rect: Rect2, r: float, left: bool, right: bool, top: Color, bot: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n: int = 6
	var rr: float = minf(r, rect.size.y * 0.5)
	var corners: Array = [
		[Vector2(rect.position.x + rr, rect.position.y + rr), PI, left],
		[Vector2(rect.end.x - rr, rect.position.y + rr), PI * 1.5, right],
		[Vector2(rect.end.x - rr, rect.end.y - rr), 0.0, right],
		[Vector2(rect.position.x + rr, rect.end.y - rr), PI * 0.5, left],
	]
	var sharp: Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var cn: Array = corners[i]
		if bool(cn[2]):
			for j in n + 1:
				var a: float = float(cn[1]) + PI * 0.5 * float(j) / float(n)
				pts.append(cn[0] + Vector2(cos(a), sin(a)) * rr)
		else:
			pts.append(sharp[i])
	for p in pts:
		cols.append(top.lerp(bot, (p.y - rect.position.y) / maxf(rect.size.y, 0.001)))
	ci.draw_polygon(pts, cols)
	var ring := pts.duplicate()
	var ring_c := cols.duplicate()
	ring.append(pts[0])
	ring_c.append(cols[0])
	ci.draw_polyline_colors(ring, ring_c, 1.0, true)


## A matte medal (.med, 44): a disc 38 across, its mark at 22 in the 2판 (glass_parts.gd).
func _medal(icon: String, color: Color, at_css: Vector2, dim: bool) -> Control:
	var m: Control = GlassParts.medal(icon, color, 44.0, 38.0, 22.0, dim)
	m.position = at_css * UiFonts.K
	return m


## The outside thermometer (.otemp, 48 high): the glass at the left (a tube
## 10 × 32 from 5 down with its bulb, frost round it on a 28 × 50 board), the
## temperature on a baseline at 25 and the stage's name at 40 from 23 in, a
## snow mark on the bulb, glowing cold, while the track is frozen. It only shows.
func _outside(o: Dictionary) -> Control:
	var dim: bool = _dim("outside")
	var k: float = UiFonts.K
	var st: int = clampi(int(o["stage"]), 0, OT_COLS.size() - 1)
	var c := Control.new()
	c.name = "Outside"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.tooltip_text = "바깥 기온"
	var glass := Control.new()
	glass.name = "Glass"
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.position = Vector2(-4.0, 0.0) * k
	glass.size = Vector2(28.0, 50.0) * k
	glass.draw.connect(_draw_outside.bind(glass, o, st, dim))
	c.add_child(glass)
	var num := _label(String(o["text"]), UiFonts.NUMBER, 500, 22.0, tone(OT_COLS[st][2], dim), 0.33)
	num.name = "Temp"
	c.add_child(num)
	_sit(num, 23.0, 25.0)
	var word := _label(String(o["name"]), UiFonts.WORD, 400, 12.0, tone(OT_COLD_WORD if st >= 4 else INK2, dim), 0.96)
	word.name = "Stage"
	c.add_child(word)
	_sit(word, 23.0, 40.0)
	if bool(o["freezing"]):
		# On the bulb, so a long stage name with it still clears the mood.
		var mark := TextureRect.new()
		mark.name = "Frozen"
		var px: int = int(round(11.0 * k))
		mark.texture = HudIcons.texture("snow", px, tone(OT_FROST_INK, dim), 2.2, tone(OT_FREEZE, dim))
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.size = Vector2(px, px)
		mark.position = Vector2(10.0 - 5.5, 37.0 - 5.5) * k
		mark.tooltip_text = "선로 결빙"
		c.add_child(mark)
	c.custom_minimum_size = Vector2(maxf(23.0 + maxf(_text_w(num), _text_w(word)) + 2.0, 58.0), 48.0) * k
	c.size = c.custom_minimum_size
	return c


func _draw_outside(ci: Control, o: Dictionary, st: int, dim: bool) -> void:
	var k: float = UiFonts.K
	var cols: Array = OT_COLS[st]
	var foot: Color = tone(cols[0], dim)
	var head: Color = tone(cols[1], dim)
	var tube := Rect2(9.0 * k, 5.0 * k, 10.0 * k, 32.0 * k)
	# The glass: dark, lit down its left and shaded down its right, a rim.
	var sb := StyleBoxFlat.new()
	sb.bg_color = tone(OT_GLASS, dim)
	sb.corner_radius_top_left = int(round(5.0 * k))
	sb.corner_radius_top_right = int(round(5.0 * k))
	sb.corner_radius_bottom_left = int(round(3.0 * k))
	sb.corner_radius_bottom_right = int(round(3.0 * k))
	sb.corner_detail = 8
	sb.anti_aliasing_size = 0.7
	sb.set_border_width_all(int(round(1.5 * k)))
	sb.border_color = tone(OT_RIM, dim)
	ci.draw_style_box(sb, tube)
	GlassParts.grad_rect(ci, tube.grow(-1.5 * k), 3.0 * k, [[0.0, tone(Color(1, 1, 1, 0.08), dim)], [0.45, Color(1, 1, 1, 0)], [1.0, tone(Color(0, 0, 0, 0.28), dim)]])
	# The column, foot to head, round at the top.
	var h: float = tube.size.y * float(o["fill"])
	var r: float = 2.5 * k
	var col := Rect2(tube.position.x + 2.5 * k, tube.end.y - h, 5.0 * k, h)
	ci.draw_polygon(PackedVector2Array([Vector2(col.position.x, col.position.y + r), Vector2(col.end.x, col.position.y + r), col.end, Vector2(col.position.x, col.end.y)]),
		PackedColorArray([head, head, foot, foot]))
	ci.draw_circle(Vector2(col.get_center().x, col.position.y + r), r, head, true, -1.0, true)
	# The bulb over the column's foot: a drop shade, the rim, its colour lit up and left.
	var bulb := Vector2(14.0 * k, 37.0 * k)
	if bool(o["freezing"]):
		GlassParts.glow_ring(ci, bulb, 8.5 * k, 6.0 * k, tone(OT_FROZEN_GLOW, dim))
	ci.draw_circle(bulb + Vector2(0.0, 1.0) * k, 8.5 * k, tone(Color(0, 0, 0, 0.35), dim), true, -1.0, true)
	ci.draw_circle(bulb, 8.5 * k, tone(OT_RIM, dim), true, -1.0, true)
	var lit := bulb + Vector2(-1.4, -1.96) * k
	for i in 7:
		var f: float = float(i) / 6.0
		ci.draw_circle(bulb.lerp(lit, f), 7.0 * k * (1.0 - f * 0.85), foot.lerp(head, f), true, -1.0, true)
	# A tick at each stage's temperature, long and short by turns ending long at the coldest.
	var ticks: Array = o["ticks"]
	for i in ticks.size():
		var y: float = tube.position.y + (1.0 - float(ticks[i])) * tube.size.y
		var long: bool = (ticks.size() - 1 - i) % 2 == 0
		ci.draw_rect(Rect2(20.0 * k, y - 0.75 * k, (4.0 if long else 3.0) * k, 1.5 * k), tone(OT_TICK, dim))
	var a: float = float(OT_FROST[st])
	if a > 0.0:
		_frost(ci, tone(Color(OT_FERN, 0.85 * a), dim))


## Frost round the tube (otTex's ferns, the same seed): from its two sides and
## the bulb's foot outwards, and a few short twigs on the glass.
func _frost(ci: Control, col: Color) -> void:
	var k: float = UiFonts.K
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var pts: Array = []
	for i in 7:
		pts.append([9.0, 7.0 + rng.randf() * 30.0, PI + (rng.randf() - 0.5) * 1.3, 4.0 + rng.randf() * 5.0])
	for i in 7:
		pts.append([19.0, 7.0 + rng.randf() * 30.0, (rng.randf() - 0.5) * 1.3, 4.0 + rng.randf() * 5.0])
	for i in 5:
		pts.append([14.0 + (rng.randf() - 0.5) * 8.0, 44.0, PI * 0.5 + (rng.randf() - 0.5) * 2.2, 3.0 + rng.randf() * 4.0])
	for i in 4:
		pts.append([10.0 + rng.randf() * 8.0, 8.0 + rng.randf() * 26.0, -PI * 0.5 + (rng.randf() - 0.5) * 1.6, 2.5 + rng.randf() * 2.5])
	for p: Array in pts:
		_fern(ci, Vector2(float(p[0]), float(p[1])) * k, float(p[2]), float(p[3]) * k, col, 1)


func _fern(ci: Control, from: Vector2, ang: float, length: float, col: Color, depth: int) -> void:
	var to: Vector2 = from + Vector2(cos(ang), sin(ang)) * length
	ci.draw_line(from, to, col, 0.6 * UiFonts.K, true)
	if depth <= 0:
		return
	for f: float in [0.4, 0.7]:
		var at: Vector2 = from.lerp(to, f)
		_fern(ci, at, ang + 0.7, length * 0.4, col, depth - 1)
		_fern(ci, at, ang - 0.7, length * 0.4, col, depth - 1)


## A stock (.res, 48 high): its mark at 20, the count on a baseline at 25, and
## under it what a stretch costs · how many stretches that lasts, red and
## underlined when it is short.
func _stock(s: Dictionary) -> Control:
	var id: String = String(s["id"])
	var dim: bool = _dim(id)
	var k: float = UiFonts.K
	var short: bool = bool(s["short"])
	var side: Color = tone(RED if short else INK3, dim)
	var c := Control.new()
	c.name = "Stock_" + id
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.tooltip_text = String(s["word"])
	var mark := TextureRect.new()
	var px: int = int(round(20.0 * k))
	mark.texture = HudIcons.texture(String(s["icon"]), px, tone(RED if short else INK2, dim), 2.0, tone(SOOT_CUT, dim))
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2(px, px)
	mark.position = Vector2(6.0, 14.0) * k
	c.add_child(mark)
	var n := _label(str(s["n"]), UiFonts.NUMBER, 500, 22.0, tone(INK, dim), 0.33)
	n.name = "Count"
	c.add_child(n)
	_sit(n, 30.0, 25.0)
	var text_w: float = _text_w(n)
	if String(s["per"]) != "" and int(s["left"]) >= 0:
		# How many stretches it lasts; the burn per stretch was a second
		# figure for the same thing (결정 417).
		var parts: Array = [_label(str(s["left"]), UiFonts.NUMBER, 400, 13.0, side, 0.195)]
		parts.append(_label("구간", UiFonts.WORD, 400, 12.0, side, 0.24))
		var x: float = 30.0
		for l: Label in parts:
			c.add_child(l)
			_sit(l, x, 39.5)
			x += _text_w(l)
		(parts[0] as Label).name = "Line"
		text_w = maxf(text_w, x - 30.0)
	var w_css: float = 30.0 + maxf(text_w, 24.0) + 4.0
	c.custom_minimum_size = Vector2(w_css * k, 48.0 * k)
	c.size = c.custom_minimum_size
	if TAPPABLE.has(id):
		# The whole stock, 48 high, is the key (field_hud.gd MIN_TOUCH).
		var tap := Button.new()
		tap.name = "Tap_" + id
		tap.flat = true
		tap.focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
			tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tap.pressed.connect(func() -> void: stock_pressed.emit(id))
		c.add_child(tap)
	if short:
		# .res.is-low::after: a red line under the words, 30 in from the left, 4 from the right.
		c.draw.connect(func() -> void:
			var sb := StyleBoxFlat.new()
			sb.bg_color = tone(RED, dim)
			sb.set_corner_radius_all(int(round(1.0 * k)))
			c.draw_style_box(sb, Rect2(30.0 * k, (48.0 - 4.0 - 2.0) * k, (w_css - 34.0) * k, 2.0 * k)))
	return c
