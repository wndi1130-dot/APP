extends Control
## A carriage's pane (UI 3단계 시안 2차 .pane--car, B1 「성에 낀 계기」): smoked
## glass frosting in from the right of the screen when a carriage is picked,
## its left edge melting away (tex/pane_glass.png, the mockup's own canvas).
## On it: the car's name, its people and how they stand to the captain; a paper
## tag and a line when it is cold; its warmth as an upright thermometer against
## the threshold of 45; ration, crowding and exposure as bars with their marks;
## the heating and ration levers, five steps each, with what the step burns in
## a stretch and a word for whether it is enough. Measured part by part (the
## mockup's px × ui_fonts.gd K).
##
## Every number is the train's own (train_state.gd situation, the state's
## levers and people); the pane only reads and draws. Moving a lever asks for
## it (lever_set) and whoever holds the state sets it (train_turn.gd set_lever)
## and calls refresh; the knob then slides and the warmth rises or falls.

signal lever_set(comm: String, which: String, step: int)
signal folded
signal decor_pressed(car_id: String)

const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const UiBake = preload("res://game/ui/ui_bake.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const TrainGauges = preload("res://game/ui/train_gauges.gd")
const St = preload("res://game/train/train_state.gd")
const TrainHands = preload("res://game/train/train_hands.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const TrainMods = preload("res://game/train/train_mods.gd")
const TrainDecor = preload("res://game/train/train_decor.gd")
const DecorUiData = preload("res://game/ui/decor_ui_data.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")
const GLASS := preload("res://game/ui/tex/pane_glass.png")

const CSS_SIZE := Vector2(330, 286)
const SMALL_PANE := Vector2(330, 76)
## The car's warmth threshold (k3_views.js carStat, s1 ui/home.ts): below it the car is cold.
const COLD: float = 45.0
## The bars: word, situation index, mark, and whether below the mark is the
## bad side (s1 ui/home.ts carPopover: ration under 45, crowding over 60,
## exposure over 50).
const STATS: Array = [["배급", 1, 45.0, true], ["과밀", 2, 60.0, false], ["노출", 3, 50.0, false]]
## The levers: id, word, what a step burns.
const LEVERS: Array = [["heat", "난방", "석탄"], ["ration", "배급", "식량"]]
## J12: a community that lives in more cars than this one says how many after
## its people, so the count, the bars and the levers read as theirs, not this
## car's alone (the tail's three, S1 COMM_CARS).
const SPAN_WORDS: Dictionary = {2: "두 칸", 3: "세 칸", 4: "네 칸"}
const STEPS: int = 5
## 디자인 토큰 2차.
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)
const INK3 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.54)
const HAIR := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.16)
const WELL := Color(0, 0, 0, 0.6)
const FILL := Color("e4dfd2")
const ACCENT := Color("f2a63c")
const RED := Color("e2604b")
const COLDZ := Color("c2ccd4")
const LAMP3 := Color("94511a")
const BRASS: Array = [[0.0, Color("7b5b26")], [0.34, Color("f7e6b4")], [0.6, Color("caa45c")], [1.0, Color("3a2a11")]]
const SOOT_CUT := Color("10151a")
## How long the knob slides and the thermometer rises (c1.css transitions).
const KNOB_S: float = 0.16
const WARM_S: float = 0.52

var g: Dictionary = {}
var t: Dictionary = {}
## The picked carriage: its id, comm and name (train_rules.json cars).
var car: Dictionary = {}
var _parts: Control
var decor_block: String = ""
var choosing_paper: bool = true
## The lever just moved and the step it left, so its knob slides from there.
var _moved: Array = []
## The warmth last drawn per comm, so the thermometer rises from it.
var _warm_was: Dictionary = {}


## What the pane says for carriage `car0` in state `g0` (tests read this; the
## pane draws it). Empty when the carriage has no people of its own.
static func model(g0: Dictionary, t0: Dictionary, car0: Dictionary) -> Dictionary:
	var c: String = String(car0.get("comm", ""))
	var id: String = String(car0.get("id", ""))
	if id in ["captain", "dining"] and not g0.is_empty():
		return {"name": String(car0.get("name", TrainMods.CAR_NAME[id])), "small": true,
			"decor": true, "percent": DecorUiData.percent(g0, id), "lock": DecorUiData.lock_reason(g0)}
	if g0.is_empty() or t0.is_empty() or c == "" or not (g0.get("comms", {}) as Dictionary).has(c):
		return {}
	var s: Dictionary = g0["comms"][c]
	var sit: Array = St.situation(g0, t0, c)
	var p: Dictionary = t0["P"]
	var pop: int = int(s["pop"])
	var heat: int = int(s["heat"])
	var ration: int = int(s["ration"])
	var cold: bool = float(sit[0]) < COLD
	var stats: Array = []
	for row: Array in STATS:
		var v: float = float(sit[int(row[1])])
		var bad: bool = v < float(row[2]) if bool(row[3]) else v > float(row[2])
		stats.append({"word": row[0], "n": int(round(v)), "mark": float(row[2]), "bad": bad})
	# What this car's step burns in a stretch: its own share of train_turn.gd
	# heat_cost (insulation, the outside's stage and the laws' heat multiplier
	# with it) and food_cost.
	var coal: float = TrainTurn.comm_heat(g0, c) * float(p["coalHeatPerLever"]) * TrainClimate.temp_mult(g0, t0) * St.law_mult(g0, t0, "heatMult")
	var dom: Dictionary = g0.get("dom", {}) if g0.get("dom") is Dictionary else {}
	var food: float = float(pop) * float(ration) * float(p["foodPerPersonLever"])
	var names: Dictionary = t0.get("COMM_NAME", {})
	return {
		"small": false, "decor": TrainDecor.DECOR_CARS.has(id),
		"percent": DecorUiData.percent(g0, id) if TrainDecor.DECOR_CARS.has(id) else 0,
		"lock": DecorUiData.lock_reason(g0),
		"name": String(car0.get("name", names.get(c, c))),
		"furnish": TrainMods.FURNISH_NAMES[int(TrainMods.furnish_of(g0, String(car0.get("id", "")))["tier"])] if TrainMods.FURNISH_CARS.has(String(car0.get("id", ""))) else "",
		"comm": c,
		"pop": pop,
		"hands_line": TrainHands.shortage_line(g0, t0, true),
		"stage": String(St.stage_of(float(s["rel"]), t0).get("name", "")),
		# An insulated car says so after its stage; what it gains is already in
		# the warmth, the crowding and the heat lever's coal (train_mods.gd, PR 4).
		"insulated": (dom.get("insulated", []) as Array).has(String(car0.get("id", ""))),
		"span": int(TrainMods.COMM_CARS.get(c, 1)),
		"warm": int(round(float(sit[0]))),
		"cold": cold,
		# Only the cold says a line: what the night does to them (결정 417).
		"stats": stats,
		"levers": [
			{"id": "heat", "word": "난방", "cost": "−" + TrainGauges._num(snappedf(coal, 0.1)), "cost_icon": "coal", "step": heat,
				"floor": int(St.law_floor(g0, t0, "heatFloor")), "need": need_of(float(sit[0]))},
			{"id": "ration", "word": "배급", "cost": "−" + TrainGauges._num(snappedf(food, 0.1)), "cost_icon": "food", "step": ration,
				"floor": int(St.law_floor(g0, t0, "rationFloor")), "need": need_of(float(sit[1]))},
		],
	}


## Whether a lever's step is enough for value `v`: s1 ui/widgets.ts gaugeValue
## (−1 short … 0 enough … 1 over, past 45 and 70 over 25) read as the mockup's
## word (k2_parts.js needTag: past ∓.3).
static func need_of(v: float) -> String:
	var gv: float = 0.0
	if v < 45.0:
		gv = maxf(-1.0, (v - 45.0) / 25.0)
	elif v > 70.0:
		gv = minf(1.0, (v - 70.0) / 25.0)
	return "부족" if gv < -0.3 else ("여유" if gv > 0.3 else "적정")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var glass := TextureRect.new()
	glass.name = "Glass"
	glass.texture = GLASS
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.stretch_mode = TextureRect.STRETCH_SCALE
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(glass)
	_parts = Control.new()
	_parts.name = "Parts"
	_parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_parts)
	_draw_all()


## At the right of the screen under a band `top` game px high.
func pin(top: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var s: Vector2 = CSS_SIZE * UiFonts.K
	offset_left = -s.x
	offset_right = 0.0
	offset_top = top
	offset_bottom = top + s.y


## Show carriage `car0` (or draw again) for state `g0`.
func show_car(car0: Dictionary, g0: Dictionary, t0: Dictionary) -> void:
	car = car0
	refresh(g0, t0)


func refresh(g0: Dictionary, t0: Dictionary) -> void:
	g = g0
	t = t0
	_draw_all()
	offset_bottom = offset_top + (SMALL_PANE.y if car.get("id", "") in ["captain", "dining"] else CSS_SIZE.y) * UiFonts.K


func _draw_all() -> void:
	if _parts == null:
		return
	for c in _parts.get_children():
		_parts.remove_child(c)
		c.queue_free()
	var m: Dictionary = model(g, t, car)
	if m.is_empty():
		return
	m["lock"] = DecorUiData.lock_reason(g, choosing_paper)
	if bool(m["small"]):
		var name_label := UiFonts.label(String(m["name"]), UiFonts.WORD, 500, 18.0, INK, 2.16)
		name_label.name = "Name"
		_text(name_label, 44.0, 27.0)
		_decor_head(m, 44.0)
		return
	_head(m)
	if bool(m["decor"]):
		_decor_head(m, 157.0)
	_thermo(m)
	_stats(m)
	for i in 2:
		_lever(m["levers"][i], 162.0 + 62.0 * i, String(m["comm"]))
	_warm_was[m["comm"]] = int(m["warm"])
	_moved = []


func _add(c: Control) -> Control:
	_parts.add_child(c)
	return c


## Set `l` with its left at `x_css` and its baseline at `base_css`: the pane's
## words sit on the baselines measured off the mockup (pane px), whatever the
## faces' own heights.
func _text(l: Label, x_css: float, base_css: float) -> void:
	_add(l)
	GlassParts.put_on(l, x_css * UiFonts.K, base_css * UiFonts.K)


## The name (h3 at 44, 10), the people and their stage under it on one
## baseline, and 접기 at the top right (.word: its arrow 6 from the right).
func _head(m: Dictionary) -> void:
	var k: float = UiFonts.K
	var name := UiFonts.label(String(m["name"]), UiFonts.WORD, 500, 18.0, INK, 2.16)
	name.name = "Name"
	_text(name, 44.0, 27.0)
	if String(m["furnish"]) != "":
		var tier := UiFonts.label(String(m["furnish"]), UiFonts.WORD, 400, 12.0, INK2, 0.52)
		tier.name = "Furnish"
		_add(tier)
		GlassParts.put_on(tier, name.position.x + GlassParts.text_w(name) + 10.0 * k, 27.0 * k)
	# The people as their mark and count, then the stage (결정 417: no 「명 · 관계」).
	_add(_mark("people", 14.0, Vector2(44.0, 33.0), INK2))
	var pop := UiFonts.label(str(m["pop"]), UiFonts.NUMBER, 400, 15.0, INK, 0.225)
	pop.name = "People"
	_text(pop, 62.0, 45.0)
	var span: String = String(SPAN_WORDS.get(int(m["span"]), "")) if int(m["span"]) > 1 else ""
	var stage := UiFonts.label((" · " + span if span != "" else "") + " · " + String(m["stage"]) + (" · 단열" if bool(m["insulated"]) else ""), UiFonts.WORD, 400, 12.0, INK2, 0.72)
	stage.name = "Stage"
	_add(stage)
	GlassParts.put_on(stage, pop.position.x + GlassParts.text_w(pop), GlassParts.base_of(pop))
	if bool(m["decor"]):
		stage.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stage.clip_text = true
		stage.size.x = maxf(1.0, 153.0 * k - stage.position.x)
	if not String(m["hands_line"]).is_empty() and String(m["lock"]) == "" and decor_block == "":
		var hands := UiFonts.label(String(m["hands_line"]), UiFonts.WORD, 400, 11.0, INK2, 0.0)
		hands.name = "HandsShortage"
		hands.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_text(hands, 44.0, 64.0)
	var fold := Button.new()
	fold.name = "Fold"
	fold.flat = true
	fold.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		fold.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	fold.position = Vector2(266.0, 0.0) * k
	fold.size = Vector2(56.0, 44.0) * k
	fold.pressed.connect(func() -> void: folded.emit())
	_add(fold)
	var mark := TextureRect.new()
	var px: int = int(round(14.0 * k))
	mark.texture = HudIcons.texture("fwd", px, INK2, 2.0, SOOT_CUT)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2(px, px)
	mark.position = Vector2(36.0, 15.0) * k
	fold.add_child(mark)
	var word := UiFonts.label("접기", UiFonts.WORD, 400, 13.0, INK2, 1.3)
	fold.add_child(word)
	# On the line its ink sits on in the mockup, 26.5 down.
	GlassParts.put_on(word, mark.position.x - 3.0 * k - GlassParts.text_w(word), 26.5 * k)


func _decor_head(m: Dictionary, x: float) -> void:
	var k: float = UiFonts.K
	var percent := UiFonts.label("꾸밈 %d%%" % int(m["percent"]), UiFonts.NUMBER, 500, 12.0, INK2)
	percent.name = "DecorPercent"
	_text(percent, x, 46.0)
	var why: String = decor_block if decor_block != "" else String(m["lock"])
	var button := Button.new()
	button.name = "DecorButton"
	button.text = "꾸미기"
	button.position = Vector2(236.0, 33.0) * k
	button.size = Vector2(74.0, 21.0) * k
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = why != ""
	UiFonts.style(button, UiFonts.WORD, 500, 11.5, Color("f7e6b4"), 0.46)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("2a200f")
	box.border_color = Color("caa45c")
	box.set_border_width_all(int(round(1.5 * k)))
	box.set_corner_radius_all(int(round(11.0 * k)))
	box.content_margin_left = 25.0 * k
	box.content_margin_right = 8.0 * k
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	button.modulate.a = 0.45 if button.disabled else 1.0
	button.pressed.connect(func() -> void:
		if not button.disabled:
			decor_pressed.emit(String(car["id"])))
	_add(button)
	var house := UiBake.Batch.new()
	for stroke: Array in [
		[Vector2(2, 14), Vector2(14, 14)],
		[Vector2(4, 14), Vector2(4, 8), Vector2(8, 4), Vector2(12, 8), Vector2(12, 14)],
		[Vector2(7, 14), Vector2(7, 11), Vector2(9, 11), Vector2(9, 14)],
	]:
		var line := PackedVector2Array()
		for point: Vector2 in stroke: line.append((point + Vector2(7, 1.5)) * k)
		house.polyline(line, PackedColorArray([Color("f7e6b4")]), 1.5 * k)
	button.draw.connect(func() -> void: house.draw(button))
	if why != "":
		var reason := UiFonts.label(why, UiFonts.WORD, 400, 10.0, INK2)
		reason.name = "DecorLock"
		_text(reason, 44.0, 69.0 if bool(m["small"]) else 64.0)


## The thermometer (.thermo 74 × 78 at 44, 75): a well 12 wide with the cold
## stretch marked beside it below 45, the warmth filling it from the bulb, the
## threshold across at 45; cold, the fill and the bulb go frost blue and glow.
## The warmth's number beside it; the threshold's 45 at the end of its line.
func _thermo(m: Dictionary) -> void:
	var k: float = UiFonts.K
	var warm: int = int(m["warm"])
	var cold: bool = bool(m["cold"])
	var c := Control.new()
	c.name = "Thermo"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(44.0, 75.0) * k
	c.size = Vector2(74.0, 78.0) * k
	c.set_meta("warm", float(_warm_was.get(m["comm"], warm)))
	c.draw.connect(func() -> void:
		var w: float = clampf(float(c.get_meta("warm")), 0.0, 100.0)
		var tube := Rect2(31.0 * k, 1.0 * k, 12.0 * k, 62.0 * k)
		var sb := StyleBoxFlat.new()
		sb.bg_color = WELL
		sb.corner_radius_top_left = int(round(6.0 * k))
		sb.corner_radius_top_right = int(round(6.0 * k))
		sb.corner_detail = 8
		sb.anti_aliasing_size = 0.7
		c.draw_style_box(sb, tube)
		# inset 0 1px 2px rgba(0,0,0,.45)
		c.draw_rect(Rect2(tube.position.x + 4.0 * k, tube.position.y + 0.5 * k, tube.size.x - 8.0 * k, 1.0 * k), Color(0, 0, 0, 0.35))
		var zone_h: float = 62.0 * k * COLD / 100.0
		GlassParts.round_rect(c, Rect2(24.0 * k, tube.end.y - zone_h, 3.0 * k, zone_h), 2.0 * k, Color(COLDZ.r, COLDZ.g, COLDZ.b, 0.55))
		var fill: Color = COLDZ if cold else FILL
		var fh: float = 62.0 * k * w / 100.0
		if fh > 0.5:
			var fsb := StyleBoxFlat.new()
			fsb.bg_color = fill
			fsb.corner_radius_top_left = int(round(3.0 * k))
			fsb.corner_radius_top_right = int(round(3.0 * k))
			fsb.anti_aliasing_size = 0.6
			c.draw_style_box(fsb, Rect2(34.0 * k, tube.end.y - fh, 6.0 * k, fh))
		GlassParts.round_rect(c, Rect2(22.0 * k, tube.end.y - zone_h - 1.0 * k, 30.0 * k, 2.0 * k), 1.0 * k, COLDZ)
		var bulb := Vector2(37.0, 67.0) * k
		if cold:
			# 0 0 8px rgba(194,204,212,.45), round the bulb's edge.
			GlassParts.glow_ring(c, bulb, 11.0 * k, 8.0 * k, Color(COLDZ, 0.45))
		var circles := UiBake.Batch.new()
		circles.circle(bulb, 11.0 * k, WELL)
		circles.circle(bulb, 7.0 * k, fill)
		circles.draw(c))
	_add(c)
	var was: float = float(c.get_meta("warm"))
	if not is_equal_approx(was, float(warm)):
		var tw := c.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float) -> void:
			c.set_meta("warm", v)
			c.queue_redraw(), was, float(warm), WARM_S)
	else:
		c.set_meta("warm", float(warm))
	# The warmth's number beside the glass; the thermometer is its word (결정 417).
	var num := UiFonts.label(str(warm), UiFonts.NUMBER, 600, 28.0, INK, 0.42)
	num.name = "Warmth"
	_text(num, 132.0, 95.0)
	# 45 at the end of the threshold's line across the glass, so the line says
	# what it is (no 「문턱」).
	var th := UiFonts.label(str(int(COLD)), UiFonts.NUMBER, 400, 14.0, INK3, 0.21)
	th.name = "Threshold"
	_text(th, 44.0 + 55.0, 75.0 + 63.0 - 62.0 * COLD / 100.0 + 5.0)


## Ration, crowding and exposure (.stat rows at 100, 120 and 140): the word,
## a bar 116 wide with its mark, the number at the right; the bad side of the
## mark turns bar and number amber.
func _stats(m: Dictionary) -> void:
	var k: float = UiFonts.K
	for i in 3:
		var s: Dictionary = m["stats"][i]
		var top: float = 100.0 + 20.0 * i
		var bad: bool = bool(s["bad"])
		var lab := UiFonts.label(String(s["word"]), UiFonts.WORD, 400, 12.0, INK2, 0.96)
		_text(lab, 132.0, top + 13.0)
		var bar := Control.new()
		bar.name = "Bar_" + String(s["word"])
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.position = Vector2(169.0, top + 6.0) * k
		bar.size = Vector2(116.0, 6.0) * k
		var n: float = float(s["n"])
		var mark: float = float(s["mark"])
		bar.draw.connect(func() -> void:
			var r: float = 3.0 * k
			GlassParts.round_rect(bar, Rect2(Vector2.ZERO, bar.size), r, WELL)
			var fill: Rect2 = stat_fill_rect(bar.size, n)
			if fill.size.x > 0.5:
				GlassParts.round_rect(bar, fill, r, ACCENT if bad else FILL)
			GlassParts.round_rect(bar, Rect2(bar.size.x * mark / 100.0 - 1.0 * k, -4.0 * k, 2.0 * k, 14.0 * k), 1.0 * k, ACCENT))
		_add(bar)
		var num := UiFonts.label(str(s["n"]), UiFonts.NUMBER, 500, 17.0, ACCENT if bad else INK, 0.255)
		num.name = "Value_" + String(s["word"])
		_text(num, 0.0, top + 15.5)
		num.position.x = 316.0 * k - GlassParts.text_w(num)


static func stat_fill_rect(bar_size: Vector2, value: float) -> Rect2:
	var width: float = bar_size.x * clampf(value / 100.0, 0.0, 1.0)
	return Rect2(0, 0, maxf(width, 6.0 * UiFonts.K), bar_size.y) if width > 0.5 else Rect2()


## An icon of `css` at `at` (pane px), in `color`; nothing for an empty id.
func _mark(icon: String, css: float, at: Vector2, color: Color) -> Control:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon == "":
		return t
	var px: int = int(round(css * UiFonts.K))
	t.texture = HudIcons.texture(icon, px, color, 2.0, SOOT_CUT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size = Vector2(px, px)
	t.position = at * UiFonts.K
	return t


## A lever (.lever, 272 × 62 at `top`): its word, what the step burns, the word
## for whether it is enough at the right (부족 in red, the only red); under them
## the slot of five steps with the lamp fill up to the brass knob.
func _lever(lv: Dictionary, top: float, comm: String) -> void:
	var k: float = UiFonts.K
	var id: String = String(lv["id"])
	var word := UiFonts.label(String(lv["word"]), UiFonts.WORD, 500, 13.0, INK, 2.08)
	_text(word, 44.0, top + 14.0)
	# What a step burns: its stock's mark and the number (결정 417: no word).
	var cost_x: float = (word.position.x + GlassParts.text_w(word)) / k + 10.0
	_add(_mark(String(lv.get("cost_icon", "")), 13.0, Vector2(cost_x, top + 3.0), INK2))
	var cost := UiFonts.label(String(lv["cost"]), UiFonts.NUMBER, 400, 13.0, INK2, 0.52)
	cost.name = "Cost_" + id
	_text(cost, 0.0, top + 14.0)
	cost.position.x = (cost_x + 16.0) * k
	var need: String = String(lv["need"])
	var low: bool = need == "부족"
	var tag := UiFonts.label(need, UiFonts.WORD, 500, 12.0, RED if low else INK2, 0.72)
	tag.name = "Need_" + id
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(RED.r, RED.g, RED.b, 0.12) if low else Color(0, 0, 0, 0)
	sb.set_border_width_all(int(round(2.0 * k)))
	sb.border_color = RED if low else HAIR
	sb.set_corner_radius_all(int(round(10.0 * k)))
	sb.corner_detail = 10
	sb.content_margin_left = 7.0 * k
	sb.content_margin_right = 7.0 * k
	tag.add_theme_stylebox_override("normal", sb)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(0, 20.0 * k)
	_add(tag)
	tag.size = tag.get_combined_minimum_size()
	tag.position = Vector2(316.0 * k - tag.size.x, (top + 1.0) * k)
	var slot := Control.new()
	slot.name = "Slot_" + id
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = Vector2(44.0, top + 18.0) * k
	slot.size = Vector2(272.0, 44.0) * k
	var step: int = int(lv["step"])
	var floor_step: int = int(lv["floor"])
	var from: float = float(step)
	if _moved.size() == 3 and _moved[0] == comm and _moved[1] == id:
		from = float(_moved[2])
	slot.set_meta("at", from)
	slot.draw.connect(_draw_slot.bind(slot, floor_step))
	_add(slot)
	for i in STEPS:
		var b := Button.new()
		b.name = "Step%d" % i
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.position = Vector2(slot.size.x * i / STEPS, 0)
		b.size = Vector2(slot.size.x / STEPS, slot.size.y)
		b.tooltip_text = "%s %d단" % [lv["word"], i + 1]
		b.pressed.connect(func() -> void:
			if i < floor_step:
				UiDeny.shake(slot)
				return
			if i == step:
				return
			_moved = [comm, id, step]
			lever_set.emit(comm, id, i))
		slot.add_child(b)
	if not is_equal_approx(from, float(step)):
		var tw := slot.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float) -> void:
			slot.set_meta("at", v)
			slot.queue_redraw(), from, float(step), KNOB_S)


## The slot (.lever__slot): a sunk groove, a dot at each step (dim under a
## law's floor), the lamp fill from the left to the knob, the brass knob with
## its grip lines.
static func slot_geometry(width: float, at: float) -> Dictionary:
	var k: float = UiFonts.K
	var cell: float = width / STEPS
	return {"cell": cell,
		"fill": Rect2(4.0 * k, 19.0 * k, (at + 0.5) * cell - 4.0 * k, 6.0 * k),
		"knob": Rect2(cell * (at + 0.5) - 13.0 * k, 5.0 * k, 26.0 * k, 34.0 * k)}


func _draw_slot(slot: Control, floor_step: int) -> void:
	var k: float = UiFonts.K
	var w: float = slot.size.x
	var at: float = float(slot.get_meta("at"))
	var geometry: Dictionary = slot_geometry(w, at)
	var groove := Rect2(2.0 * k, 17.0 * k, w - 4.0 * k, 10.0 * k)
	GlassParts.round_rect(slot, groove, 5.0 * k, WELL)
	var base := UiBake.Batch.new()
	# inset 0 1px 3px rgba(0,0,0,.55), 0 1px 0 rgba(255,255,255,.12)
	base.rect(Rect2(groove.position.x + 5.0 * k, groove.position.y + 0.5 * k, groove.size.x - 10.0 * k, 1.5 * k), Color(0, 0, 0, 0.3))
	# The light hair (0 1px 0) along the groove's foot, round its ends.
	var rim := PackedVector2Array()
	var rr: float = groove.size.y * 0.5
	var cy: float = groove.position.y + rr + 0.5 * k
	for j in 7:
		var a: float = lerpf(PI * 0.85, PI * 0.5, float(j) / 6.0)
		rim.append(Vector2(groove.position.x + rr, cy) + Vector2(cos(a), sin(a)) * rr)
	for j in 7:
		var a: float = lerpf(PI * 0.5, PI * 0.15, float(j) / 6.0)
		rim.append(Vector2(groove.end.x - rr, cy) + Vector2(cos(a), sin(a)) * rr)
	base.polyline(rim, PackedColorArray([Color(1, 1, 1, 0.12)]), 1.0 * k)
	var cell: float = float(geometry["cell"])
	var fill: Rect2 = geometry["fill"]
	if fill.size.x > 0.5:
		GlassParts.gradient(base, fill, 3.0 * k, [[0.0, LAMP3], [1.0, ACCENT]])
	# The steps' dots come after the fill in the slot, so they show on it.
	for i in STEPS:
		var dot: Color = INK3 if i >= floor_step else Color(INK3.r, INK3.g, INK3.b, INK3.a * 0.36)
		base.circle(Vector2(cell * (i + 0.5), 22.0 * k), 3.0 * k, dot)
	base.draw(slot)
	var knob: Rect2 = geometry["knob"]
	# 0 3px 6px rgba(0,0,0,.7)
	GlassParts.shadow(slot, knob, 5.0 * k, 3.0 * k, 6.0 * k * 0.6, Color(0, 0, 0, 0.55))
	var metal := UiBake.Batch.new()
	GlassParts.gradient(metal, knob, 5.0 * k, BRASS)
	# The grip: 1 px of shade every 4 px over 18 px from 9 down.
	var y: float = knob.position.y + 27.0 * k - 1.0 * k
	while y >= knob.position.y + 9.0 * k:
		metal.rect(Rect2(knob.position.x + 1.0 * k, y, knob.size.x - 2.0 * k, 1.0 * k), Color(0, 0, 0, 0.2))
		y -= 4.0 * k
	# inset 0 1px 0 rgba(255,255,255,.5), inset 0 -2px 0 rgba(0,0,0,.3)
	metal.rect(Rect2(knob.position.x + 3.0 * k, knob.position.y, knob.size.x - 6.0 * k, 1.0 * k), Color(1, 1, 1, 0.5))
	metal.rect(Rect2(knob.position.x + 3.0 * k, knob.end.y - 2.0 * k, knob.size.x - 6.0 * k, 2.0 * k), Color(0, 0, 0, 0.3))
	metal.draw(slot)
