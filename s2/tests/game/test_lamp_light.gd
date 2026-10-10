extends "res://addons/gut/test.gd"
## Warm light (weather_fx 12장): which lights are on, which cells they reach,
## and how the field draws them (mask channel, glowing faces, two real lights).

const LampLight = preload("res://game/sim/lamp_light.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FxState = preload("res://fx/fx_state.gd")

const DUSK_ELAPSED := (960.0 - 630.0) * 60.0 / 15.0   # 16:00, after sunset


func _stop(raiders := false) -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": raiders, "auto_pause": false, "weather": ["clear"]}
	add_child_autofree(game)
	game.set_process(false)
	return game


func _light(game, kind: String) -> Dictionary:
	for l in game.data["lights"]:
		if l["kind"] == kind:
			return l
	return {}


func test_lights_come_on_by_their_own_rule() -> void:
	var window := {"id": "w", "when": "dusk", "from_min": 890}
	assert_false(LampLight.is_on(window, 889.0, false, false))
	assert_true(LampLight.is_on(window, 890.0, false, false))
	assert_true(LampLight.is_on({"id": "f", "when": "always"}, 0.0, false, false))
	var fire := {"id": "t", "when": "tower_fire"}
	assert_false(LampLight.is_on(fire, 1000.0, false, true))
	assert_true(LampLight.is_on(fire, 700.0, true, false))
	var hide := {"id": "h", "when": "raiders_dusk", "from_min": 890}
	assert_false(LampLight.is_on(hide, 1000.0, false, false), "nobody hides there")
	assert_false(LampLight.is_on(hide, 700.0, false, true), "not before dusk")
	assert_true(LampLight.is_on(hide, 900.0, false, true))
	assert_false(LampLight.is_on({"id": "x", "when": "someday"}, 900.0, true, true), "unknown rule stays off")


func test_light_fades_with_distance_and_throws_one_way() -> void:
	assert_almost_eq(LampLight.falloff(Vector2i.ZERO, Vector2i.ZERO, 0.8, 4.0), 0.8, 0.0001)
	assert_gt(LampLight.falloff(Vector2i(1, 0), Vector2i.ZERO, 1.0, 4.0), LampLight.falloff(Vector2i(3, 0), Vector2i.ZERO, 1.0, 4.0))
	assert_eq(LampLight.falloff(Vector2i(4, 0), Vector2i.ZERO, 1.0, 4.0), 0.0)
	# A car window throws onto the platform, not back into the car.
	assert_gt(LampLight.falloff(Vector2i(0, 1), Vector2i(0, 1), 0.6, 3.0), 0.0)
	assert_eq(LampLight.falloff(Vector2i(0, -1), Vector2i(0, 1), 0.6, 3.0), 0.0)
	assert_eq(LampLight.falloff(Vector2i(1, 0), Vector2i(0, 1), 0.6, 3.0), 0.0, "not along its own wall or roof")


func test_stamp_keeps_the_brighter_light_and_respects_sight() -> void:
	var cells: Dictionary = {}
	LampLight.stamp(cells, 10, 10, Vector2i(5, 5), Vector2i.ZERO, 0.5, 3.0)
	var weak: int = cells[5 * 10 + 5]
	LampLight.stamp(cells, 10, 10, Vector2i(5, 5), Vector2i.ZERO, 1.0, 3.0)
	assert_gt(int(cells[5 * 10 + 5]), weak)
	LampLight.stamp(cells, 10, 10, Vector2i(5, 5), Vector2i.ZERO, 0.2, 3.0)
	assert_eq(int(cells[5 * 10 + 5]), 255, "a weaker light never dims a cell")
	# Near the edge nothing is written outside the map.
	var edge: Dictionary = {}
	LampLight.stamp(edge, 4, 4, Vector2i(0, 0), Vector2i.ZERO, 1.0, 3.0)
	for i in edge:
		assert_true(int(i) >= 0 and int(i) < 16)
	# A lantern only lights what its carrier sees: not through a wall.
	var seen := {5 * 10 + 5: true, 5 * 10 + 6: true}
	var lit: Dictionary = {}
	LampLight.stamp(lit, 10, 10, Vector2i(5, 5), Vector2i.ZERO, 1.0, 4.0, seen)
	assert_eq(lit.size(), 2)


func test_by_day_only_the_firebox_glows() -> void:
	var game = _stop()
	game._refresh_vision()
	assert_false(game.view.light_is_on("car_window"), "dark glass before dusk")
	assert_true(game.view.light_is_on("firebox"))
	assert_false(game.view.light_is_on("hideout"))
	var cells: Dictionary = game.lamp_cells()
	var fire: Dictionary = _light(game, "firebox")
	assert_gt(int(cells.get(game.grid.index(fire["cell"] + Vector2i(0, 1)), 0)), 0)
	var window: Dictionary = _light(game, "car_window")
	var front: Vector2i = window["cell"] + Vector2i(0, 1)
	assert_eq(int(cells.get(game.grid.index(front), 0)), 0, "no pool under an unlit window")
	game._update_lantern(0.1)
	assert_false(game.lantern.visible, "no lantern by day above ground")


func test_after_sunset_windows_and_lanterns_are_lit() -> void:
	var game = _stop()
	game.clock.elapsed = DUSK_ELAPSED
	game._refresh_vision()
	assert_true(game.view.light_is_on("car_window"))
	var cells: Dictionary = game.lamp_cells()
	var window: Dictionary = _light(game, "car_window")
	var front: Vector2i = window["cell"] + Vector2i(0, 1)
	assert_gt(int(cells.get(game.grid.index(front), 0)), 0, "a pool on the platform")
	# Every mate's lantern marks where they stand, seen or not.
	for p in game.squad:
		assert_gt(int(cells.get(game.grid.index(FieldGrid.cell_of(p.position)), 0)), 0, p.pid)
	game._update_lantern(0.1)
	assert_true(game.lantern.visible)
	assert_eq(game.lantern.light_color, FxState.LAMP)
	assert_almost_eq(game.lantern.position.x, game.player.position.x, 0.001)


func test_a_lantern_that_is_out_draws_nothing() -> void:
	# The off state (lamp_lit false) must leave no light: here by having no lamp.
	var game = _stop()
	game.clock.elapsed = DUSK_ELAPSED
	var mate = game.squad[1]
	mate.position = Vector3(120.5, 0.0, 60.5)
	game._refresh_vision()
	var at: int = game.grid.index(FieldGrid.cell_of(mate.position))
	assert_gt(int(game.lamp_cells().get(at, 0)), 0)
	mate.lamp = {}
	assert_eq(int(game.lamp_cells().get(at, 0)), 0)
	game.player.lamp = {}
	game._update_lantern(0.1)
	assert_false(game.lantern.visible)


func test_the_hideout_gap_shows_only_while_someone_hides_there() -> void:
	var empty = _stop(false)
	empty.clock.elapsed = DUSK_ELAPSED
	empty._refresh_vision()
	assert_false(empty.view.light_is_on("hideout"))
	var held = _stop(true)
	held.clock.elapsed = DUSK_ELAPSED
	held._refresh_vision()
	assert_true(held.view.light_is_on("hideout"))
	# Once they have all come out, the gap goes dark.
	for r in held.raiders:
		r.position = Vector3(120.5, 0.0, 60.5)
	held._refresh_vision()
	assert_false(held.view.light_is_on("hideout"))


func test_the_mask_carries_the_lamp_channel_and_real_lights_stay_at_two() -> void:
	var game = _stop()
	game.clock.elapsed = DUSK_ELAPSED
	game._refresh_vision()
	assert_eq(game.view.vis_image.get_format(), Image.FORMAT_RGBA8)
	var window: Dictionary = _light(game, "car_window")
	var front: Vector2i = window["cell"] + Vector2i(0, 1)
	var n: int = game.grid.index(front)
	assert_gt(game.view.vis_bytes[n * 4 + 2], 0, "B is the lamp light")
	assert_eq(game.view.vis_bytes[n * 4 + 3], 255, "A is kept for cell snow")
	var omni := 0
	for child in game.get_children():
		if child is OmniLight3D:
			omni += 1
			assert_false(child.shadow_enabled)
	assert_eq(omni, 2, "the chief's lantern and the firebox")
	# 16 windows, each a five-faced box.
	assert_eq(game.view.light_nodes["car_window"].mesh.get_faces().size(), 16 * 10 * 3)


func test_the_night_sound_makes_the_lantern_dip() -> void:
	var game = _stop()
	game.clock.elapsed = DUSK_ELAPSED
	game.light_t = 0.0
	game._update_night(0.1)
	assert_eq(game.lamp_pulse, 1.0)
	game._update_lantern(0.01)
	assert_lt(game.lantern.light_energy, float(game.player.lamp["strength"]))
	game._update_lantern(5.0)
	assert_almost_eq(game.lantern.light_energy, float(game.player.lamp["strength"]), 0.0001)


func test_no_game_rule_reads_the_lamp_light() -> void:
	# Picture only: sight, the dead, mates and raiders never look at these cells.
	for path in ["res://game/field_ai.gd", "res://game/field_combat.gd", "res://game/field_actions.gd", "res://game/actors/zombies.gd", "res://game/sim/weather.gd", "res://game/sim/noise.gd", "res://game/sim/horde_director.gd"]:
		var code := FileAccess.get_file_as_string(path)
		assert_false(code.contains("lamp_cells") or code.contains("lamp_fixed") or code.contains("LampLight"), path)
