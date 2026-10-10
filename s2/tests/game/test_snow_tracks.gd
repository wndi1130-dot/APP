extends "res://addons/gut/test.gd"
## Footprints in snow (weather_fx 15장): marks deepen where people pass, falling
## snow fills them, and nothing but the picture reads them.

const SnowTracks = preload("res://game/sim/snow_tracks.gd")
const SnowCover = preload("res://game/sim/snow_cover.gd")
const MapView = preload("res://game/world/map_view.gd")
const SulehufMap = preload("res://game/world/sulehuf_map.gd")


func test_snow_starts_untouched() -> void:
	var t := SnowTracks.new(12)
	assert_eq(t.cells.size(), 12)
	for i in range(12):
		assert_eq(t.value(i), 1.0)
	assert_eq(t.take_changed().size(), 0)
	assert_eq(t.value(99), 1.0, "outside the map reads as fresh")


func test_running_and_dragging_mark_deeper_than_walking() -> void:
	var t := SnowTracks.new(4)
	assert_true(t.press(0, "walk"))
	assert_true(t.press(1, "run"))
	assert_true(t.press(2, "drag"))
	assert_almost_eq(t.value(0), 0.5, 0.01)
	assert_almost_eq(t.value(1), 0.3, 0.01)
	assert_almost_eq(t.value(2), 0.1, 0.01)
	assert_true(t.press(3, "crawl"), "unknown kinds count as walking")
	assert_almost_eq(t.value(3), 0.5, 0.01)
	assert_false(t.press(-1))
	assert_false(t.press(4))


func test_a_trodden_path_bottoms_out() -> void:
	var t := SnowTracks.new(1)
	t.press(0, "walk")
	t.press(0, "walk")
	assert_almost_eq(t.value(0), SnowTracks.FLOOR, 0.01)
	assert_false(t.press(0, "drag"), "packed snow cannot go lower")
	assert_almost_eq(t.value(0), SnowTracks.FLOOR, 0.01)


func test_snowfall_fills_marks_and_clear_weather_keeps_them() -> void:
	var t := SnowTracks.new(3)
	t.press(0, "drag")
	t.press(1, "walk")
	t.take_changed()
	assert_eq(t.refill(60.0, 0.0), 0, "clear: marks stay to the end")
	assert_eq(t.refill(60.0, -2.0), 0, "rain and thaw do not fill marks")
	assert_eq(t.refill(0.0, 3.0), 0)
	# One game hour of blizzard (3 cm an hour) fills a 3 cm mark.
	assert_eq(t.refill(60.0, 3.0), 2)
	assert_eq(t.value(0), 1.0)
	assert_eq(t.value(1), 1.0)
	assert_true(t.marked.is_empty())
	assert_eq(t.take_changed().size(), 2)
	assert_eq(t.refill(60.0, 3.0), 0, "nothing left to fill")


func test_fill_times_match_the_brief() -> void:
	# Real minutes = game minutes / 15: fine snow 12 real minutes, a blizzard 4.
	assert_almost_eq(SnowTracks.minutes_to_fill(SnowCover.rate_cm_h(["snow"], -14.0)) / 15.0, 12.0, 0.01)
	assert_almost_eq(SnowTracks.minutes_to_fill(SnowCover.rate_cm_h(["blizzard"], -14.0)) / 15.0, 4.0, 0.01)
	assert_eq(SnowTracks.minutes_to_fill(SnowCover.rate_cm_h(["clear"], -14.0)), INF)
	# Fine snow, minute by minute: half filled after 90 game minutes.
	var t := SnowTracks.new(1)
	t.press(0, "drag")
	for m in range(90):
		t.refill(1.0, 1.0)
	assert_almost_eq(t.value(0), 0.1 + 0.5, 0.03)


func test_changes_are_handed_over_once() -> void:
	var t := SnowTracks.new(5)
	t.press(2, "run")
	var first := t.take_changed()
	assert_eq(first.size(), 1)
	assert_eq(int(first[2]), int(t.cells[2]))
	assert_eq(t.take_changed().size(), 0)


func test_the_view_writes_tracks_to_the_a_channel() -> void:
	var view = MapView.new()
	add_child_autofree(view)
	view.setup(SulehufMap.build())
	var n: int = view.grid.width * view.grid.height
	var cell := Vector2i(60, 30)
	var i: int = view.grid.index(cell)
	# Handed over before the first sight update: kept and applied then.
	view.update_tracks({i: 128})
	view.update_vis({}, PackedByteArray())
	assert_eq(view.vis_bytes.size(), n * 4)
	assert_eq(view.vis_bytes[i * 4 + 3], 128)
	assert_eq(view.vis_bytes[(i + 1) * 4 + 3], 255, "other cells stay fresh")
	view.update_tracks({i: 255})
	view.update_vis({}, PackedByteArray())
	assert_eq(view.vis_bytes[i * 4 + 3], 255)
	# Sight and lamp channels are left alone.
	assert_eq(view.vis_bytes[i * 4 + 2], 0)


func test_world_shader_reads_tracks_only_where_snow_can_lie() -> void:
	var path := "res://game/world/world_vis.gdshader"
	var s: Shader = load(path)
	assert_gt(s.get_shader_uniform_list().size(), 0, "parses")
	var code := FileAccess.get_file_as_string(path)
	assert_true(code.contains("cell.a"), "tracks come from the A channel")
	assert_true(code.contains("COLOR.a"), "roof rule kept")
	assert_false(code.contains("hint_screen_texture"))
	assert_false(code.contains("hint_depth_texture"))


func test_no_game_rule_reads_the_tracks() -> void:
	# Picture only (user 2026-10-10): the dead, mates, raiders and sound never read marks.
	for path in ["res://game/field_ai.gd", "res://game/field_combat.gd", "res://game/field_actions.gd", "res://game/actors/zombies.gd", "res://game/actors/person.gd", "res://game/sim/weather.gd", "res://game/sim/noise.gd", "res://game/sim/horde_director.gd", "res://game/world/field_grid.gd"]:
		var code := FileAccess.get_file_as_string(path)
		assert_false(code.contains("SnowTracks") or code.contains("snow_tracks"), path)
