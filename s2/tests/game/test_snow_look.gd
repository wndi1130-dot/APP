extends "res://addons/gut/test.gd"
## Each map spreads the stop's snow its own way (사용자 11-05 「어느 맵은 싹 덮이고 어느 맵은
## 좀 녹은」): fixed by the place id, so a restored stop lies as it did, inside set ranges,
## and a map may give its own snow_look. The map view hands it to the ground shader.

const MapView = preload("res://game/world/map_view.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGame = preload("res://game/field_game.gd")


## The ranges a place id gives (narrower than what a map's own snow_look may set).
func _in_range(look: Dictionary) -> void:
	assert_between(float(look["shift"]), -0.25, 0.25, "shift")
	assert_between(float(look["melt"]), 0.45, 0.95, "melt")
	assert_between(float(look["melt_m"]), 18.0, 40.0, "melt_m")
	var phase: Vector2 = look["phase"]
	assert_between(phase.x, 0.0, 500.0, "phase x")
	assert_between(phase.y, 0.0, 500.0, "phase y")


func test_the_same_place_lies_the_same_every_time() -> void:
	var a := MapView.snow_look_for({"place_id": "houses_01"})
	var b := MapView.snow_look_for({"place_id": " Houses_01 "})
	assert_eq(a, b, "the id is trimmed and lowered, then hashed by its bytes")
	_in_range(a)


func test_places_differ_and_stay_in_range() -> void:
	var lo := 1.0
	var hi := -1.0
	var phases := {}
	for id: String in FieldMaps.ids():
		var look := MapView.snow_look_for({"place_id": id})
		_in_range(look)
		lo = minf(lo, float(look["shift"]))
		hi = maxf(hi, float(look["shift"]))
		phases[look["phase"]] = true
	assert_gt(FieldMaps.ids().size(), 10, "enough places to tell")
	assert_lt(lo, -0.15, "some maps lie more melted")
	assert_gt(hi, 0.15, "some maps lie whiter")
	assert_eq(phases.size(), FieldMaps.ids().size(), "no two maps' drifts line up")
	_in_range(MapView.snow_look_for({}))


func test_a_map_may_give_its_own_look() -> void:
	var base := MapView.snow_look_for({"place_id": "lake_01"})
	var own := MapView.snow_look_for({"place_id": "lake_01", "snow_look": {"shift": 0.2, "melt": 0.1, "melt_m": 20}})
	assert_almost_eq(float(own["shift"]), 0.2, 1e-6)
	assert_almost_eq(float(own["melt"]), 0.1, 1e-6)
	assert_almost_eq(float(own["melt_m"]), 20.0, 1e-6)
	assert_eq(own["phase"], base["phase"], "what it does not give comes from the id")


func test_a_wrong_value_falls_back_to_the_place_alone() -> void:
	var base := MapView.snow_look_for({"place_id": "lake_01"})
	var own := MapView.snow_look_for({"place_id": "lake_01", "snow_look": {"shift": 0.9, "melt": "deep", "melt_m": 30}})
	assert_eq(own["shift"], base["shift"], "out of range: the place's own")
	assert_eq(own["melt"], base["melt"], "not a number: the place's own")
	assert_almost_eq(float(own["melt_m"]), 30.0, 1e-6, "the right one still counts")
	assert_eq(MapView.snow_look_for({"place_id": "lake_01", "snow_look": "deep"}), base, "not a dictionary: the place's own")


func test_the_map_snow_mean_is_the_stop_snow_spread_by_the_shift() -> void:
	for id: String in FieldMaps.ids():
		var data := {"place_id": id}
		var shift := float(MapView.snow_look_for(data)["shift"])
		for s: float in [0.1, 0.5, 0.8]:
			assert_almost_eq(MapView.map_snow_mean(data, s), clampf(s * (1.0 + shift), 0.0, 1.0), 1e-6, "%s at %.1f" % [id, s])
		assert_eq(MapView.map_snow_mean(data, 0.0), 0.0, "%s: no stop snow, no snow" % id)
		assert_lte(MapView.map_snow_mean(data, 1.0), 1.0)
		assert_gte(MapView.map_snow_mean(data, 0.8), MapView.map_snow_mean(data, 0.5), "%s: more stop snow, never less" % id)
	var own := {"place_id": "lake_01", "snow_look": {"shift": 0.2}}
	assert_almost_eq(MapView.map_snow_mean(own, 0.5), 0.6, 1e-6, "the map's own shift counts")
	assert_almost_eq(MapView.map_snow_mean({"place_id": "lake_01", "snow_look": {"shift": -0.3}}, 0.5), 0.35, 1e-6)


func test_the_map_snow_mean_reads_a_bad_stop_snow_as_the_field_would() -> void:
	var data := {"place_id": "houses_01"}
	assert_eq(MapView.map_snow_mean(data, NAN), 0.0, "not a number: no snow")
	assert_eq(MapView.map_snow_mean(data, -0.4), 0.0, "below zero: no snow")
	assert_almost_eq(MapView.map_snow_mean(data, 1.7), MapView.map_snow_mean(data, 1.0), 1e-6, "above one: as FxState clamps it")
	assert_almost_eq(MapView.map_snow_mean({}, 0.5), clampf(0.5 * (1.0 + float(MapView.snow_look_for({})["shift"])), 0.0, 1.0), 1e-6, "no place id: the default place")


## The trees and the ground must add the snow up the same way: if world_vis changes how the
## shift spreads the stop's snow, map_snow_mean has to change with it.
func test_the_map_snow_mean_is_the_ground_shaders_sum() -> void:
	var code: String = (preload("res://game/world/world_vis.gdshader") as Shader).code
	assert_eq(code.count("local_snow = clamp(fx_snow * (1.0 + snow_shift + "), 1, "world_vis spreads fx_snow by (1 + snow_shift) before the melt field")


func test_the_map_view_hands_it_to_the_ground_shader() -> void:
	var data: Dictionary = FieldMaps.build("houses_01")
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false, "map_data": data, "place": "houses_01"}
	add_child_autofree(game)
	game.set_process(false)
	var look := MapView.snow_look_for(game.data)
	var mat: ShaderMaterial = game.view.material
	for key: String in look:
		assert_eq(mat.get_shader_parameter("snow_" + key), look[key], key)
