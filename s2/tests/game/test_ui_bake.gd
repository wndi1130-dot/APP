extends "res://addons/gut/test.gd"
## Geometry and interaction regressions for the UI draw-call reduction.

const UiBake = preload("res://game/ui/ui_bake.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const CarPane = preload("res://game/ui/car_pane.gd")
const TrainGauges = preload("res://game/ui/train_gauges.gd")
const HomeBar = preload("res://game/ui/home_bar.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
const TAIL := {"id": "tail1", "comm": "tail", "name": "꼬리칸 1"}


func test_both_levers_finish_at_the_requested_knob_and_fill_positions() -> void:
	var sample: Array = StopPickCard.sample()
	var state: Dictionary = sample[0]
	var tables: Dictionary = sample[1]
	state["comms"]["tail"]["heat"] = 0
	state["comms"]["tail"]["ration"] = 0
	var pane = CarPane.new()
	add_child_autofree(pane)
	pane.show_car(TAIL, state, tables)
	for lever: String in ["heat", "ration"]:
		for target: int in [4, 1, 3, 0]:
			var slot: Control = pane.find_child("Slot_" + lever, true, false)
			var previous: float = float(state["comms"]["tail"][lever])
			(slot.get_node("Step%d" % target) as Button).pressed.emit()
			state["comms"]["tail"][lever] = target
			var before: Array[Tween] = get_tree().get_processed_tweens()
			pane.refresh(state, tables)
			slot = pane.find_child("Slot_" + lever, true, false)
			assert_true(slot.has_meta("at"))
			assert_eq(float(slot.get_meta("at")), previous, "starts where the old knob was")
			# Advance the real Tween, not wall time (busy hosts can clamp frame delta).
			for tween: Tween in get_tree().get_processed_tweens():
				if not before.has(tween):
					tween.custom_step(CarPane.WARM_S + CarPane.KNOB_S)
			var at: float = float(slot.get_meta("at"))
			assert_almost_eq(at, float(target), 0.0001)
			var shape: Dictionary = CarPane.slot_geometry(slot.size.x, at)
			var cell: float = slot.size.x / 5.0
			assert_almost_eq((shape["knob"] as Rect2).position.x, cell * (target + 0.5) - 13.0 * UiFonts.K, 0.0001)
			assert_almost_eq((shape["fill"] as Rect2).size.x, cell * (target + 0.5) - 4.0 * UiFonts.K, 0.0001)
			assert_eq((slot.get_node("Step0") as Control).size, Vector2(cell, slot.size.y), "same touch area")
			await wait_process_frames(1)


func test_the_thermometer_still_finishes_its_warmth_tween() -> void:
	var sample: Array = StopPickCard.sample()
	var state: Dictionary = sample[0]
	state["comms"]["tail"]["heat"] = 0
	var pane = CarPane.new()
	add_child_autofree(pane)
	pane.show_car(TAIL, state, sample[1])
	var from: float = float(CarPane.model(state, sample[1], TAIL)["warm"])
	state["comms"]["tail"]["heat"] = 4
	var before: Array[Tween] = get_tree().get_processed_tweens()
	pane.refresh(state, sample[1])
	var thermo: Control = pane.find_child("Thermo", true, false)
	assert_eq(float(thermo.get_meta("warm")), from)
	for tween: Tween in get_tree().get_processed_tweens():
		if not before.has(tween):
			tween.custom_step(CarPane.WARM_S + 0.08)
	assert_almost_eq(float(thermo.get_meta("warm")), float(CarPane.model(state, sample[1], TAIL)["warm"]), 0.0001)
	await wait_process_frames(1)


func test_car_stats_and_both_top_meters_keep_value_dependent_fill_widths() -> void:
	var k: float = UiFonts.K
	for _stat in CarPane.STATS:
		for value: float in [0.0, 1.0, 27.0, 71.0, 100.0]:
			var fill: Rect2 = CarPane.stat_fill_rect(Vector2(116, 6) * k, value)
			assert_almost_eq(fill.size.x, 0.0 if value == 0.0 else maxf(116.0 * k * value / 100.0, 6.0 * k), 0.0001)
	for width: float in [TrainGauges.METER_W, TrainGauges.METER_W_NARROW]:
		for _key: String in ["trust", "tension"]:
			for value: float in [0.0, 10.0, 50.0, 100.0]:
				var fill: Rect2 = TrainGauges.meter_fill_rect(width * k, value)
				assert_almost_eq(fill.size.x, 0.0 if value == 0.0 else maxf(width * k * value / 100.0, 8.0 * k), 0.0001)


func test_standing_fills_keep_seat_shares_and_the_two_gaps() -> void:
	var size_px: Vector2 = Vector2(112, 8) * UiFonts.K
	var gap: float = 2.0 * UiFonts.K
	for shares: Vector3i in [Vector3i(20, 50, 30), Vector3i(60, 10, 30), Vector3i(0, 0, 100)]:
		var fills: Array[Rect2] = TrainGauges.standing_fills(size_px, shares.x, shares.y, shares.z)
		var room: float = size_px.x - gap * 2.0
		assert_almost_eq(fills[0].size.x, room * shares.x / 100.0, 0.0001)
		assert_almost_eq(fills[1].size.x, room * shares.y / 100.0, 0.0001)
		assert_almost_eq(fills[2].size.x, room * shares.z / 100.0, 0.0001)
		assert_almost_eq(fills[1].position.x - fills[0].end.x, gap, 0.0001)
		assert_almost_eq(fills[2].position.x - fills[1].end.x, gap, 0.0001)


func test_lamp_gradient_stretches_while_heat_gradient_stays_on_the_full_bar() -> void:
	for width: float in [30.0, 90.0, 160.0]:
		var box := Rect2(0, 0, width, 12)
		var lamp := UiBake.Batch.new()
		GlassParts.gradient(lamp, box, 6.0, [[0.0, CarPane.LAMP3], [1.0, CarPane.ACCENT]])
		# The body vertices precede its feather and retain the original stop colours.
		assert_eq(lamp.colors[0], CarPane.LAMP3)
		var end: Color = GlassParts.grad_at([[0.0, CarPane.LAMP3], [1.0, CarPane.ACCENT]], 1.0)
		assert_true(end.is_equal_approx(CarPane.ACCENT), "the original float interpolation reaches ACCENT")
		assert_true(lamp.colors.has(end), "the lit end retains that exact interpolated colour")
		var heat: UiBake.Batch = TrainGauges.heat_geometry(box, 200.0, 6.0, false)
		assert_true(heat.colors.has(TrainGauges._heat_at(width / 200.0)))
		assert_false(heat.colors.has(TrainGauges._heat_at(1.0)), "partial heat never stretches to the full-bar end colour")


func test_static_cache_keys_separate_pixel_size_dim_and_every_colour() -> void:
	var ink := PackedColorArray([Color(0, 0, 0, 0.08), Color(0, 0, 0, 0.13), Color(0, 0, 0, 0.18),
		GlassParts.MEDAL_TOP, GlassParts.MEDAL_BOT, GlassParts.RING])
	var size_px := Vector2(80, 80)
	var first: UiBake.Batch = UiBake.medal(size_px, 35.0, UiFonts.K, false, ink)
	assert_same(first, UiBake.medal(size_px, 35.0, UiFonts.K, false, ink))
	assert_ne(UiBake.medal_key(size_px, 35.0, UiFonts.K, false, ink), UiBake.medal_key(size_px + Vector2(0.01, 0), 35.0, UiFonts.K, false, ink))
	assert_ne(UiBake.medal_key(size_px, 35.0, UiFonts.K, false, ink), UiBake.medal_key(size_px, 35.0, UiFonts.K, true, ink))
	var changed := ink.duplicate()
	changed[5] = Color.RED
	assert_ne(UiBake.medal_key(size_px, 35.0, UiFonts.K, false, ink), UiBake.medal_key(size_px, 35.0, UiFonts.K, false, changed))
	var icon: Texture2D = HudIcons.texture("fist", 32, Color.WHITE)
	assert_same(icon, HudIcons.texture("fist", 32, Color.WHITE))
	assert_eq(icon.get_size(), Vector2(64, 64), "the existing twice-pixel icon is retained")
	assert_ne(icon, HudIcons.texture("fist", 33, Color.WHITE))
	assert_ne(icon, HudIcons.texture("fist", 32, GlassParts.tone(Color.WHITE, true)))
	assert_ne(icon, HudIcons.texture("fist", 32, Color.RED))


func test_redrawing_changed_values_does_not_create_static_shapes_or_textures() -> void:
	var sample: Array = StopPickCard.sample()
	var state: Dictionary = sample[0]
	var pane = CarPane.new()
	add_child_autofree(pane)
	pane.show_car(TAIL, state, sample[1])
	var strip = TrainGauges.new()
	strip.g = state
	strip.t = sample[1]
	add_child_autofree(strip)
	await wait_process_frames(2)
	var icons: int = HudIcons._made.size()
	var shapes: int = UiBake._medals.size()
	for value: int in [51, 57, 63]:
		state["trust"] = value
		state["tension"] = 20 + value % 5
		state["comms"]["tail"]["heat"] = 2 + value % 2
		state["comms"]["tail"]["ration"] = 2 + value % 2
		pane.refresh(state, sample[1])
		strip.refresh(state, sample[1])
		await wait_process_frames(2)
		assert_eq(HudIcons._made.size(), icons, "values are not texture keys")
		assert_eq(UiBake._medals.size(), shapes, "values are not decoration keys")


func test_pressed_medal_still_sinks_two_pixels_and_brightens() -> void:
	var bar = HomeBar.new()
	add_child_autofree(bar)
	for key: String in ["Key_menu", "Room_gear"]:
		var button: Button = bar.get_node(key)
		var medal: Control = button.find_child("Medal_*", false, false)
		var original: Vector2 = medal.position
		var mark: TextureRect = medal.get_node("Mark")
		var texture: Texture2D = mark.texture
		button.button_down.emit()
		assert_eq(medal.position, original + Vector2(0, 2.0 * UiFonts.K))
		assert_eq(medal.modulate, Color(1.25, 1.25, 1.25))
		assert_same(mark.texture, texture)
		button.button_up.emit()
		assert_almost_eq(medal.position.distance_to(original), 0.0, 0.0001)
		assert_eq(medal.modulate, Color.WHITE)
