extends Control
## The way the train goes, in the middle of the bottom band (UI 3단계 시안 2차
## k2_parts.js route, c1.css .route, B1): over a line of the run's stretches,
## the stretch it is on (6 /24 구간) with the five phases of a stretch as dots,
## the one it is in lit and named, and how far the next station is; on the
## line the stretches gone by lit, the train a lamp dot, the next station a
## ring. 488 × 36 in the mockup; it stretches with the band.
##
## The horde behind (「무리 2.1km 뒤」 and its mark on the line) is the mockup's
## own sample number; the train keeps no such distance yet, so it is left out.

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")

const CSS_H: float = 36.0
## The five phases of a stretch (k2_parts.js PHASES).
const PHASES: Array = ["운영", "이동", "정차", "의회", "정산"]
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const INK3 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.54)
const AMBER := Color("f2a63c")
const PANE := Color(8 / 255.0, 11 / 255.0, 15 / 255.0, 0.9)
## The words' row, the line under it (route padding 2, the row 16, a gap of 6).
const TOP_Y: float = 2.0
const ROW_H: float = 16.0
const LINE_Y: float = 24.0

var seg: int = 1
var total: int = 24
var phase: String = "이동"
## km to the next station; below zero, not known (not shown).
var next_km: float = -1.0

var _seg_l: Array = []        # the stretch's labels, laid together in the middle
var _next_l: Array = []
var _pips_x: float = 0.0      # where the dots start, game px


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seg_l = [
		UiFonts.label(str(seg), UiFonts.NUMBER, 500, 15.0, INK, 0.45),
		UiFonts.label("/%d" % total, UiFonts.NUMBER, 400, 15.0, INK2, 0.45),
		# The stretch as 6/24 with its ticks on the line under it, no 「구간」 (결정 417).
		UiFonts.label("", UiFonts.WORD, 400, 12.0, INK2, 0.72),
		UiFonts.label(phase, UiFonts.WORD, 500, 12.0, INK, 0.72),
	]
	for l: Label in _seg_l:
		add_child(l)
	if next_km >= 0.0:
		# The km alone at the row's right, over the line it runs along (no 「다음 역」).
		_next_l = [
			UiFonts.label("", UiFonts.WORD, 400, 12.0, INK2, 0.72),
			UiFonts.label("%skm" % _km(next_km), UiFonts.NUMBER, 500, 15.0, INK, 0.45),
		]
		for l: Label in _next_l:
			add_child(l)
	resized.connect(_lay_out)
	_lay_out()


static func _km(v: float) -> String:
	return str(int(round(v))) if absf(v - round(v)) < 0.05 else "%.1f" % v


## The labels on one baseline in the row (line box 16), 4 apart (flex gap),
## the dots 8 after 「구간」 and 5 before the phase.
func _lay_out() -> void:
	var k: float = UiFonts.K
	var gap: float = 4.0 * k
	var widths: Array = []
	for l: Label in _seg_l:
		GlassParts.put(l, 0.0, TOP_Y, ROW_H)
		widths.append(GlassParts.text_w(l))
	var pips_w: float = (5.0 * 5.0 + 3.0 * 4.0) * k
	var run: float = widths[0] + gap + widths[1] + gap + widths[2] + gap + 8.0 * k + pips_w + 5.0 * k + gap + widths[3]
	var x: float = (size.x - run) * 0.5
	for i in 3:
		(_seg_l[i] as Label).position.x = x
		x += float(widths[i]) + gap
	x += 8.0 * k
	_pips_x = x
	x += pips_w + 5.0 * k + gap
	(_seg_l[3] as Label).position.x = x
	if not _next_l.is_empty():
		var w0: float = GlassParts.text_w(_next_l[0])
		var w1: float = GlassParts.text_w(_next_l[1])
		GlassParts.put(_next_l[0], 0.0, TOP_Y, ROW_H)
		GlassParts.put(_next_l[1], 0.0, TOP_Y, ROW_H)
		(_next_l[1] as Label).position.x = size.x - w1
		(_next_l[0] as Label).position.x = size.x - w1 - gap - w0
	queue_redraw()


func _draw() -> void:
	var k: float = UiFonts.K
	var w: float = size.x
	# The phase dots (.pips): 5 across, 3 apart; the one it is in lamp-lit.
	var on: int = PHASES.find(phase)
	var cy: float = (TOP_Y + ROW_H * 0.5) * k
	for i in PHASES.size():
		var c := Vector2(_pips_x + (2.5 + 8.0 * i) * k, cy)
		if i == on:
			GlassParts.glow_ring(self, c, 2.5 * k, 5.0 * k, Color(AMBER, 0.8))
			draw_circle(c, 2.5 * k, AMBER, true, -1.0, true)
		else:
			draw_circle(c, 2.5 * k, INK3, true, -1.0, true)
	# The line (.route__line): its bed, a tick a stretch (taller every 6), the
	# stretches gone by lit, the train, the next station.
	var y0: float = LINE_Y * k
	var at := func(i: float) -> float: return w * i / float(maxi(1, total))
	GlassParts.round_rect(self, Rect2(0.0, y0 + 5.0 * k, w, 2.0 * k), 1.0 * k, INK3)
	for i in total + 1:
		var maj: bool = i % 6 == 0
		var col: Color = INK if i <= seg else INK3
		var tr := Rect2(at.call(float(i)) - 1.0 * k, y0 + (1.0 if maj else 3.0) * k, 2.0 * k, (10.0 if maj else 6.0) * k)
		GlassParts.round_rect(self, tr, 1.0 * k, col)
	GlassParts.round_rect(self, Rect2(0.0, y0 + 5.0 * k, at.call(float(seg)), 2.0 * k), 1.0 * k, INK)
	var me := Vector2(at.call(float(seg)), y0 + 6.0 * k)
	GlassParts.glow_ring(self, me, 6.0 * k, 10.0 * k, Color(AMBER, 0.8))
	draw_circle(me, 8.0 * k, PANE, true, -1.0, true)
	draw_circle(me, 6.0 * k, AMBER, true, -1.0, true)
	if seg < total:
		var nx := Vector2(at.call(float(seg + 1)), y0 + 6.0 * k)
		draw_circle(nx, 5.0 * k, INK, true, -1.0, true)
		draw_circle(nx, 3.0 * k, PANE, true, -1.0, true)
