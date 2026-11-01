extends "res://addons/gut/test.gd"
## Run by the lead through the Godot gate. No screenshot or runtime result is implied by this file.
const Gauges = preload("res://game/ui/train_gauges.gd")
const Fonts = preload("res://game/ui/ui_fonts.gd")
const Icons = preload("res://game/ui/hud_icons.gd")
const Costs = preload("res://game/ui/cost_pane.gd")
const PATH: String = "res://tests/fixtures/train/supplies_vectors.json"

var _g: Dictionary = {}
var _t: Dictionary = {}


func before_all() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_g = data["runs"][2]["initial"]
	_t = data["tables"]
	_g["climate"] = true


func test_supplies_stock_is_after_luxury_zero_visible_and_off_has_no_width() -> void:
	var g: Dictionary = _g.duplicate(true)
	g["sup"] = 0
	var model: Dictionary = Gauges.model(g, _t)
	assert_eq(model["stocks"].size(), 5)
	assert_eq(model["stocks"][3]["id"], "lux")
	assert_eq(model["stocks"][4]["id"], "sup")
	assert_eq(model["stocks"][4]["n"], 0)
	assert_true(Icons.PATHS.has("sup"))
	var strip: Gauges = Gauges.new()
	strip.g = g
	strip.t = _t
	add_child_autofree(strip)
	strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	strip.size = Vector2(1280, Gauges.BAND_H)
	strip._lay_out()
	var on_stocks: Control = strip.find_child("Stocks", true, false)
	var on_width: float = on_stocks.size.x
	g["supOn"] = false
	strip.refresh(g, _t)
	assert_eq(Gauges.model(g, _t)["stocks"].size(), 4)
	assert_null(strip.find_child("Stock_sup", true, false))
	var off_stocks: Control = strip.find_child("Stocks", true, false)
	assert_lt(off_stocks.size.x, on_width)
	assert_eq(Costs.WHY_NAME["sup"], "생필품 배급")
	assert_eq(Costs.WHY_NAME["sup.use"], "생필품 사용")
	assert_eq(Costs.WHY_NAME["sup.search"], "맡긴 수색의 생필품 덤")
	assert_false(Gauges.METER_SETTLE.has("sup"), "sup is not a direct trust/tension cause")


func _temperature_extremes(strip: Control, outside: Control) -> Array[String]:
	var label: Label = outside.get_node("Temp")
	var face: Font = label.get_theme_font("font")
	var px: int = label.get_theme_font_size("font_size")
	var low: float = 0.0
	var high: float = 0.0
	for value: Variant in _t["CL"]["segTemp"]:
		for weather: Variant in preload("res://game/train/train_climate.gd").WEATHER_TEMP.values():
			low = minf(low, float(value) + float(weather))
			high = maxf(high, float(value) + float(weather))
	var shortest: String = ""
	var longest: String = ""
	var min_width: float = INF
	var max_width: float = -1.0
	for value: int in range(int(floor(low)), int(ceil(high)) + 1):
		var word: String = Gauges.deg(float(value))
		var width: float = face.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if width < min_width:
			min_width = width
			shortest = word
		if width > max_width:
			max_width = width
			longest = word
	assert_gt(strip.size.x, 0.0)
	return [shortest, longest, "−9°", "−10°"]


func test_supplies_seventh_stock_fits_phone_widths() -> void:
	# canvas_items / expand: logical height 720, then uniformly scale to the physical height.
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(2316, 1080), Vector2i(1688, 780)]:
		for stock: int in [0, 8, 999]:
			var g: Dictionary = _g.duplicate(true)
			g["sup"] = stock
			var strip: Gauges = Gauges.new()
			strip.g = g
			strip.t = _t
			add_child_autofree(strip)
			strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
			strip.size = Vector2(float(resolution.x) * 720.0 / float(resolution.y), Gauges.BAND_H)
			strip._lay_out()
			var outside: Control = strip.find_child("Outside", true, false)
			var mood: Control = strip.find_child("Standing", true, false)
			var stocks: Control = strip.find_child("Stocks", true, false)
			var reserved: float = outside.size.x
			var position: float = mood.position.x
			for word: String in _temperature_extremes(strip, outside):
				var state: Dictionary = strip._ot_state(Time.get_ticks_msec())
				state["text"] = word
				strip._ot_apply(outside, state)
				var at: String = "%dx%d sup=%d temp=%s" % [resolution.x, resolution.y, stock, word]
				assert_almost_eq(outside.size.x, reserved, 0.001, at + " stable thermometer")
				assert_almost_eq(mood.position.x, position, 0.001, at + " stable standing")
				var label: Label = outside.get_node("Temp")
				assert_lte(label.position.x + strip._text_w(label) * Fonts.K, reserved + 0.01, at + " temperature fits")
				var bounds: Dictionary = mood.get_meta("band_layout", {})
				assert_true(bool(bounds.get("fits", false)), at + " readable minimum")
				assert_gte(mood.position.x, outside.position.x + outside.size.x + Gauges.BAND_GAP * Fonts.K - 0.01, at + " left gap")
				assert_lte(mood.position.x + mood.size.x, stocks.position.x - Gauges.BAND_GAP * Fonts.K + 0.01, at + " right gap")
				var ratio: float = float(bounds["scale"])
				assert_gte(ratio, Gauges.STANDING_MIN / Gauges.STANDING_W - 0.0001)
				var bar: Control = mood.get_node("Bar")
				assert_almost_eq(bar.position.x, 47.0 * Fonts.K * ratio, 0.01, at + " bar x")
				assert_almost_eq(bar.size.x * bar.scale.x, 112.0 * Fonts.K * ratio, 0.01, at + " bar width")
				var medal: Control = mood.get_child(1)
				assert_almost_eq(medal.position.x, 162.0 * Fonts.K * ratio, 0.01, at + " medal x")
				var support: Label = mood.get_node("Support")
				assert_almost_eq(support.position.x + strip._text_w(support) * Fonts.K * support.scale.x, 159.0 * Fonts.K * ratio, 0.01, at + " digit right")


func test_four_digit_stocks_read_in_thousands_and_the_band_still_fits() -> void:
	for pair: Array in [[999, "999"], [1000, "1K"], [1999, "1K"], [9999, "9K"], [10000, "10K"], [99999, "99K"], [100000, "99K"], [5000000, "99K"]]:
		assert_eq(Gauges.count_word(pair[0]), pair[1])
	# 1280×720, 2316×1080 and 1688×780 as canvas_items/expand lays them out (height 720).
	for width: float in [1280.0, 2316.0 * 720.0 / 1080.0, 1688.0 * 720.0 / 780.0]:
		for case: Array in [[9999, false], [99999, false], [9999, true], [99999, true]]:
			var every: bool = case[1]
			var g: Dictionary = _g.duplicate(true)
			g["sup"] = case[0]
			if every:
				for id: String in ["coal", "food", "med", "lux"]:
					g[id] = case[0]
			var strip: Gauges = Gauges.new()
			strip.g = g
			strip.t = _t
			add_child_autofree(strip)
			strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
			strip.size = Vector2(width, Gauges.BAND_H)
			strip._lay_out()
			var at: String = "width %d, %d, every stock %s" % [int(width), int(case[0]), str(every)]
			var count: Label = strip.find_child("Stock_sup", true, false).get_node("Count")
			assert_eq(count.text.replace(Fonts.WORD_JOINER, ""), Gauges.count_word(case[0]), at)
			var bounds: Dictionary = strip.find_child("Standing", true, false).get_meta("band_layout", {})
			assert_true(bool(bounds.get("fits", false)), at + " readable minimum")
